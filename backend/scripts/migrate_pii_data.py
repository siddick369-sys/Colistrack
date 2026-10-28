#!/usr/bin/env python3
"""Script de migration sécurisée et par lots des données personnelles (PII).

Chiffre les colonnes sensibles des tables parcels, users et payments en AES-256-GCM.

Principes stricts de sécurité :
- Nécessite impérativement le paramètre explicite --db-url (aucune valeur implicite par défaut).
- Prise en charge du mode --dry-run (simulation exhaustive sans aucune écriture).
- Traitement transactionnel par lots bornés (--batch-size).
- Mises à jour conditionnelles avec contrôle de concurrence optimiste (OCC) et vérification de rowcount == 1.
- Arrêt immédiat et sécurisé en cas d'erreur cryptographique, d'ambiguïté ou d'anomalie de concurrence.
- Strictement ZÉRO affichage de données personnelles ou de clés dans les sorties ou les journaux.
"""
import argparse
import logging
import sys
from typing import Any, Dict, List, Optional, Tuple, Union
from sqlalchemy import create_engine, text

# Configuration minimale du logging sans exposition de PII
logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s] [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("migrate_pii_data")

# Imports cryptographiques ColisTrack
try:
    from app.core.crypto import (
        CryptographicError,
        ValueClassification,
        classify_bytes_value,
        classify_text_value,
        encrypt_bytes,
        encrypt_str,
    )
except ImportError:
    logger.error("Impossible d'importer app.core.crypto. Exécutez avec PYTHONPATH=backend.")
    sys.exit(2)


class ConcurrencyConflictError(Exception):
    """Levée lorsqu'une modification concurrente est détectée lors de l'UPDATE (rowcount != 1)."""
    pass


class AmbiguousDataError(Exception):
    """Levée lorsqu'une valeur candidate ne peut pas être authentifiée auprès du registre de clés."""
    pass


def _resolve_text_col(val: Optional[str], table: str, col: str, row_id: Any) -> Optional[str]:
    """Classifie et traite une colonne textuelle PII.

    - NULL : Retourne None.
    - VALID_CIPHERTEXT : Déjà chiffrée et authentifiée avec succès -> Strictement conservée.
    - PLAINTEXT : Valeur historique en clair -> Chiffrée en AES-256-GCM.
    - INVALID_OR_AMBIGUOUS : Format suspect ou altéré -> Arrêt de sécurité.
    """
    cls = classify_text_value(val)
    if cls == ValueClassification.NULL:
        return None
    elif cls == ValueClassification.VALID_CIPHERTEXT:
        return str(val)
    elif cls == ValueClassification.PLAINTEXT:
        return encrypt_str(str(val))
    else:
        logger.critical(
            "Arrêt de sécurité : valeur candidate non authentifiable ou corrompue sur table=%s, colonne=%s, id=%s. "
            "Aucune donnée exposée.",
            table,
            col,
            row_id,
        )
        raise AmbiguousDataError(
            f"Valeur PII ambiguë non authentifiée sur {table}.{col} (id={row_id})"
        )


def _resolve_bytes_col(
    val: Optional[Union[bytes, bytearray, str]],
    table: str,
    col: str,
    row_id: Any,
) -> Optional[bytes]:
    """Classifie et traite une colonne binaire PII (CNI)."""
    cls = classify_bytes_value(val)
    if cls == ValueClassification.NULL:
        return None
    elif cls == ValueClassification.VALID_CIPHERTEXT:
        return bytes(val) if not isinstance(val, str) else val.encode("utf-8")
    elif cls == ValueClassification.PLAINTEXT:
        raw = val.encode("utf-8") if isinstance(val, str) else bytes(val)
        return encrypt_bytes(raw)
    else:
        logger.critical(
            "Arrêt de sécurité : octets CNI candidats non authentifiables ou corrompus sur table=%s, colonne=%s, id=%s. "
            "Aucune donnée exposée.",
            table,
            col,
            row_id,
        )
        raise AmbiguousDataError(
            f"Valeur CNI ambiguë non authentifiée sur {table}.{col} (id={row_id})"
        )


def migrate_users_batch(
    conn,
    batch_size: int,
) -> int:
    """Migre un lot d'utilisateurs non chiffrés en mode réel."""
    select_query = text(
        "SELECT id, full_name, phone FROM users "
        "WHERE is_pii_encrypted = FALSE ORDER BY id LIMIT :limit"
    )
    rows = conn.execute(select_query, {"limit": batch_size}).fetchall()
    if not rows:
        return 0

    count = 0
    for row in rows:
        row_id, raw_full_name, raw_phone = row[0], row[1], row[2]

        if raw_full_name is None:
            raise ValueError(f"Incohérence: full_name est NULL pour l'utilisateur id={row_id}")

        enc_full_name = _resolve_text_col(raw_full_name, "users", "full_name", row_id)
        enc_phone = (
            _resolve_text_col(raw_phone, "users", "phone", row_id)
            if raw_phone is not None
            else None
        )

        update_query = text(
            "UPDATE users SET full_name = :full_name, phone = :phone, is_pii_encrypted = TRUE "
            "WHERE id = :id AND is_pii_encrypted = FALSE "
            "AND full_name = :orig_full_name "
            "AND (phone = :orig_phone OR (phone IS NULL AND :orig_phone IS NULL))"
        )
        res = conn.execute(
            update_query,
            {
                "full_name": enc_full_name,
                "phone": enc_phone,
                "id": row_id,
                "orig_full_name": raw_full_name,
                "orig_phone": raw_phone,
            },
        )
        if res.rowcount != 1:
            raise ConcurrencyConflictError(
                f"Concurrence détectée sur users id={row_id}: rowcount={res.rowcount}"
            )

        count += 1

    return count


def migrate_parcels_batch(
    conn,
    batch_size: int,
) -> int:
    """Migre un lot de colis non chiffrés en mode réel."""
    select_query = text(
        "SELECT id, sender_name, sender_phone, recipient_name, recipient_phone, recipient_cni_encrypted "
        "FROM parcels WHERE is_pii_encrypted = FALSE ORDER BY id LIMIT :limit"
    )
    rows = conn.execute(select_query, {"limit": batch_size}).fetchall()
    if not rows:
        return 0

    count = 0
    for row in rows:
        row_id, s_name, s_phone, r_name, r_phone, r_cni = (
            row[0],
            row[1],
            row[2],
            row[3],
            row[4],
            row[5],
        )

        if any(v is None for v in (s_name, s_phone, r_name, r_phone)):
            raise ValueError(f"Incohérence: champ PII obligatoire NULL sur parcel id={row_id}")

        enc_s_name = _resolve_text_col(s_name, "parcels", "sender_name", row_id)
        enc_s_phone = _resolve_text_col(s_phone, "parcels", "sender_phone", row_id)
        enc_r_name = _resolve_text_col(r_name, "parcels", "recipient_name", row_id)
        enc_r_phone = _resolve_text_col(r_phone, "parcels", "recipient_phone", row_id)
        enc_cni = _resolve_bytes_col(r_cni, "parcels", "recipient_cni_encrypted", row_id)

        update_query = text(
            "UPDATE parcels SET sender_name = :s_name, sender_phone = :s_phone, "
            "recipient_name = :r_name, recipient_phone = :r_phone, "
            "recipient_cni_encrypted = :r_cni, is_pii_encrypted = TRUE "
            "WHERE id = :id AND is_pii_encrypted = FALSE "
            "AND sender_name = :orig_s_name AND sender_phone = :orig_s_phone "
            "AND recipient_name = :orig_r_name AND recipient_phone = :orig_r_phone "
            "AND (recipient_cni_encrypted = :orig_r_cni OR (recipient_cni_encrypted IS NULL AND :orig_r_cni IS NULL))"
        )
        res = conn.execute(
            update_query,
            {
                "s_name": enc_s_name,
                "s_phone": enc_s_phone,
                "r_name": enc_r_name,
                "r_phone": enc_r_phone,
                "r_cni": enc_cni,
                "id": row_id,
                "orig_s_name": s_name,
                "orig_s_phone": s_phone,
                "orig_r_name": r_name,
                "orig_r_phone": r_phone,
                "orig_r_cni": r_cni,
            },
        )
        if res.rowcount != 1:
            raise ConcurrencyConflictError(
                f"Concurrence détectée sur parcels id={row_id}: rowcount={res.rowcount}"
            )

        count += 1

    return count


def migrate_payments_batch(
    conn,
    batch_size: int,
) -> int:
    """Migre un lot de paiements non chiffrés en mode réel."""
    select_query = text(
        "SELECT id, customer_phone FROM payments "
        "WHERE is_pii_encrypted = FALSE ORDER BY id LIMIT :limit"
    )
    rows = conn.execute(select_query, {"limit": batch_size}).fetchall()
    if not rows:
        return 0

    count = 0
    for row in rows:
        row_id, c_phone = row[0], row[1]
        if c_phone is None:
            raise ValueError(f"Incohérence: customer_phone est NULL sur payment id={row_id}")

        enc_phone = _resolve_text_col(c_phone, "payments", "customer_phone", row_id)

        update_query = text(
            "UPDATE payments SET customer_phone = :phone, is_pii_encrypted = TRUE "
            "WHERE id = :id AND is_pii_encrypted = FALSE "
            "AND customer_phone = :orig_phone"
        )
        res = conn.execute(
            update_query,
            {
                "phone": enc_phone,
                "id": row_id,
                "orig_phone": c_phone,
            },
        )
        if res.rowcount != 1:
            raise ConcurrencyConflictError(
                f"Concurrence détectée sur payments id={row_id}: rowcount={res.rowcount}"
            )

        count += 1

    return count


def dry_run_inspect_table(conn, table: str, batch_size: int) -> Dict[str, int]:
    """Examine exhaustivement une table en mode simulation (dry-run) sans aucune écriture."""
    count_query = text(f"SELECT COUNT(*) FROM {table} WHERE is_pii_encrypted = FALSE")
    total_unmigrated = conn.execute(count_query).scalar() or 0

    stats = {
        "total_unmigrated": total_unmigrated,
        "rows_inspected": 0,
        "rows_needing_encryption": 0,
        "rows_already_valid_ciphertext": 0,
        "rows_ambiguous": 0,
    }

    if total_unmigrated == 0:
        return stats

    offset = 0
    while offset < total_unmigrated:
        if table == "users":
            q = text("SELECT id, full_name, phone FROM users WHERE is_pii_encrypted = FALSE ORDER BY id LIMIT :limit OFFSET :offset")
            rows = conn.execute(q, {"limit": batch_size, "offset": offset}).fetchall()
            for r in rows:
                stats["rows_inspected"] += 1
                c1 = classify_text_value(r[1])
                c2 = classify_text_value(r[2])
                if c1 == ValueClassification.INVALID_OR_AMBIGUOUS or c2 == ValueClassification.INVALID_OR_AMBIGUOUS:
                    stats["rows_ambiguous"] += 1
                elif c1 == ValueClassification.PLAINTEXT or c2 == ValueClassification.PLAINTEXT:
                    stats["rows_needing_encryption"] += 1
                else:
                    stats["rows_already_valid_ciphertext"] += 1

        elif table == "parcels":
            q = text("SELECT id, sender_name, sender_phone, recipient_name, recipient_phone, recipient_cni_encrypted FROM parcels WHERE is_pii_encrypted = FALSE ORDER BY id LIMIT :limit OFFSET :offset")
            rows = conn.execute(q, {"limit": batch_size, "offset": offset}).fetchall()
            for r in rows:
                stats["rows_inspected"] += 1
                classes = [
                    classify_text_value(r[1]),
                    classify_text_value(r[2]),
                    classify_text_value(r[3]),
                    classify_text_value(r[4]),
                    classify_bytes_value(r[5]),
                ]
                if any(c == ValueClassification.INVALID_OR_AMBIGUOUS for c in classes):
                    stats["rows_ambiguous"] += 1
                elif any(c == ValueClassification.PLAINTEXT for c in classes):
                    stats["rows_needing_encryption"] += 1
                else:
                    stats["rows_already_valid_ciphertext"] += 1

        elif table == "payments":
            q = text("SELECT id, customer_phone FROM payments WHERE is_pii_encrypted = FALSE ORDER BY id LIMIT :limit OFFSET :offset")
            rows = conn.execute(q, {"limit": batch_size, "offset": offset}).fetchall()
            for r in rows:
                stats["rows_inspected"] += 1
                c1 = classify_text_value(r[1])
                if c1 == ValueClassification.INVALID_OR_AMBIGUOUS:
                    stats["rows_ambiguous"] += 1
                elif c1 == ValueClassification.PLAINTEXT:
                    stats["rows_needing_encryption"] += 1
                else:
                    stats["rows_already_valid_ciphertext"] += 1

        offset += len(rows)
        if not rows:
            break

    return stats


def run_migration(
    db_url: str,
    batch_size: int = 50,
    dry_run: bool = False,
    table_filter: Optional[str] = None,
) -> int:
    """Pilote global de la migration transactionnelle par lots."""
    logger.info("Démarrage de la migration PII (dry_run=%s, batch_size=%d)", dry_run, batch_size)
    engine = create_engine(db_url, echo=False)

    total_migrated: Dict[str, int] = {"users": 0, "parcels": 0, "payments": 0}
    tables_to_run = ["users", "parcels", "payments"]
    if table_filter:
        if table_filter not in tables_to_run:
            logger.error("Table inconnue: %s. Choix possibles: %s", table_filter, tables_to_run)
            return 2
        tables_to_run = [table_filter]

    try:
        with engine.connect() as conn:
            for table in tables_to_run:
                logger.info("Traitement de la table: %s", table)

                if dry_run:
                    stats = dry_run_inspect_table(conn, table, batch_size)
                    logger.info(
                        "[DRY-RUN] Table %s : total_non_migre=%d, a_chiffrer=%d, deja_valide=%d, ambigu=%d",
                        table,
                        stats["total_unmigrated"],
                        stats["rows_needing_encryption"],
                        stats["rows_already_valid_ciphertext"],
                        stats["rows_ambiguous"],
                    )
                    total_migrated[table] = stats["rows_inspected"]
                    if stats["rows_ambiguous"] > 0:
                        logger.warning(
                            "[DRY-RUN] Détection de %d ligne(s) ambiguë(s) sur %s !",
                            stats["rows_ambiguous"],
                            table,
                        )
                else:
                    while True:
                        with conn.begin():
                            if table == "users":
                                n = migrate_users_batch(conn, batch_size)
                            elif table == "parcels":
                                n = migrate_parcels_batch(conn, batch_size)
                            elif table == "payments":
                                n = migrate_payments_batch(conn, batch_size)
                            else:
                                n = 0

                        if n == 0:
                            break

                        total_migrated[table] += n
                        logger.info(
                            "Lot de %d lignes traité sur %s (total: %d)",
                            n,
                            table,
                            total_migrated[table],
                        )

    except AmbiguousDataError as e:
        logger.critical("Arrêt de sécurité: donnée candidate ambiguë (%s)", type(e).__name__)
        return 2
    except ConcurrencyConflictError as e:
        logger.critical("Arrêt d'urgence: conflit de concurrence détecté (%s)", type(e).__name__)
        return 3
    except CryptographicError as e:
        logger.critical("Arrêt d'urgence: échec cryptographique détecté (%s)", type(e).__name__)
        return 2
    except Exception as e:
        logger.critical("Arrêt d'urgence: anomalie de migration (%s)", type(e).__name__)
        return 1

    logger.info("Migration achevée avec succès. Bilan:")
    for t, count in total_migrated.items():
        logger.info("  - %s: %d lignes traitées", t, count)

    return 0


def main():
    parser = argparse.ArgumentParser(description="Migration sécurisée des données PII en AES-256-GCM")
    parser.add_argument(
        "--db-url",
        required=True,
        help="URL de connexion synchrone à la base de données cible (ex: postgresql+psycopg2://... ou sqlite:///...)",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=50,
        help="Taille maximale des lots de traitement (défaut: 50)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Simuler la migration sans modifier la base de données",
    )
    parser.add_argument(
        "--table",
        choices=["users", "parcels", "payments"],
        default=None,
        help="Restreindre la migration à une table spécifique",
    )

    args = parser.parse_args()
    ret = run_migration(
        db_url=args.db_url,
        batch_size=args.batch_size,
        dry_run=args.dry_run,
        table_filter=args.table,
    )
    sys.exit(ret)


if __name__ == "__main__":
    main()
