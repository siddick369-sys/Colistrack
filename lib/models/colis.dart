import 'package:flutter/material.dart';

enum StatutColis {
  enregistre,
  chargeBus,
  enTransit,
  arriveDestination,
  retire,
}

enum StatutPaiement {
  payeMomo,
  payeOrangeMoney,
  payeEspeces,
  aPayerAuRetrait,
}

enum SyncStatus {
  synced,
  pendingSync,
  syncError;

  String get label {
    switch (this) {
      case SyncStatus.synced:
        return 'Synchronisé';
      case SyncStatus.pendingSync:
        return 'En attente de sync';
      case SyncStatus.syncError:
        return 'Erreur de sync';
    }
  }

  Color get color {
    switch (this) {
      case SyncStatus.synced:
        return const Color(0xFF16A34A);
      case SyncStatus.pendingSync:
        return const Color(0xFFF59E0B);
      case SyncStatus.syncError:
        return const Color(0xFFDC2626);
    }
  }

  IconData get icon {
    switch (this) {
      case SyncStatus.synced:
        return Icons.cloud_done_outlined;
      case SyncStatus.pendingSync:
        return Icons.cloud_upload_outlined;
      case SyncStatus.syncError:
        return Icons.cloud_off_outlined;
    }
  }
}

class EtapeSuivi {
  final DateTime date;
  final String titre;
  final String description;
  final String lieu;
  final bool estCompletee;
  final String? actorId;

  const EtapeSuivi({
    required this.date,
    required this.titre,
    required this.description,
    required this.lieu,
    this.estCompletee = true,
    this.actorId,
  });

  Map<String, dynamic> toMap({String? colisId}) {
    return {
      'colis_id': ?colisId,
      'date': date.toIso8601String(),
      'titre': titre,
      'description': description,
      'lieu': lieu,
      'est_completee': estCompletee ? 1 : 0,
      'actor_id': ?actorId,
    };
  }

  factory EtapeSuivi.fromMap(Map<String, dynamic> map) {
    return EtapeSuivi(
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      titre: map['titre'] as String? ?? '',
      description: map['description'] as String? ?? '',
      lieu: map['lieu'] as String? ?? '',
      estCompletee: (map['est_completee'] as int? ?? 1) == 1,
      actorId: map['actor_id'] as String?,
    );
  }
}

class Colis {
  final String id; // Identifiant interne unique
  final String trackingNumber; // Numéro de suivi public (ex: TRX-8921-M4K)
  final String agencyId; // Rattaché à l'agence SaaS propriétaire
  final DateTime dateEnregistrement;
  final String expediteurNom;
  final String expediteurTel;
  final String villeDepart;
  final String agenceDepart;

  final String destinataireNom;
  final String destinataireTel;
  final String villeArrivee;
  final String agenceArrivee;
  final String guichetRetrait;

  final String typeColis; // Carton, Sac de vivres, Documents, Valise, Appareil
  final double poidsKg;
  final int valeurDeclareeFcfa;
  final int prixTransportFcfa;
  final StatutPaiement statutPaiement;
  StatutColis statut;
  final String codeSecretRetrait; // Code OTP 4 chiffres à présenter au guichet
  String? matriculeBus;
  String? chauffeurNom;
  List<EtapeSuivi> historique;

  // 1. Preuve Photo à l'Enregistrement (Anti-litige)
  final bool photoColisPrise;
  final String? photoColisDescription;

  // 2. Scan & Archivage CNI au retrait (Sécurité Gendarmerie)
  String? cniDestinataireNumero;
  bool cniScanEffectue;

  // 3. Service Cash on Delivery (Contre Remboursement e-commerce)
  final bool estContreRemboursement;
  final int montantMarchandiseFcfa;
  final int commissionAgenceFcfa;

  // 4. Synchronisation SaaS Multi-téléphones
  SyncStatus syncStatus;

  Colis({
    required this.id,
    String? trackingNumber,
    this.agencyId = 'buca-voyages-default',
    required this.dateEnregistrement,
    required this.expediteurNom,
    required this.expediteurTel,
    required this.villeDepart,
    required this.agenceDepart,
    required this.destinataireNom,
    required this.destinataireTel,
    required this.villeArrivee,
    required this.agenceArrivee,
    required this.guichetRetrait,
    required this.typeColis,
    required this.poidsKg,
    required this.valeurDeclareeFcfa,
    required this.prixTransportFcfa,
    required this.statutPaiement,
    required this.statut,
    required this.codeSecretRetrait,
    this.matriculeBus,
    this.chauffeurNom,
    required this.historique,
    this.photoColisPrise = false,
    this.photoColisDescription,
    this.cniDestinataireNumero,
    this.cniScanEffectue = false,
    this.estContreRemboursement = false,
    this.montantMarchandiseFcfa = 0,
    this.commissionAgenceFcfa = 0,
    this.syncStatus = SyncStatus.synced,
  }) : trackingNumber = trackingNumber ?? id;

  int get montantTotalARecouvrer =>
      prixTransportFcfa + (estContreRemboursement ? montantMarchandiseFcfa : 0);
  int get montantAReverserVendeur =>
      estContreRemboursement ? (montantMarchandiseFcfa - commissionAgenceFcfa) : 0;

  String get statutLabel {
    switch (statut) {
      case StatutColis.enregistre:
        return 'Enregistré au guichet';
      case StatutColis.chargeBus:
        return 'Chargé dans le bus';
      case StatutColis.enTransit:
        return 'En transit interurbain';
      case StatutColis.arriveDestination:
        return 'Arrivé - Prêt au retrait';
      case StatutColis.retire:
        return 'Colis livré / Retiré';
    }
  }

  Color get statutColor {
    switch (statut) {
      case StatutColis.enregistre:
        return const Color(0xFF1976D2);
      case StatutColis.chargeBus:
        return const Color(0xFFF57C00);
      case StatutColis.enTransit:
        return const Color(0xFFE65100);
      case StatutColis.arriveDestination:
        return const Color(0xFF2E7D32);
      case StatutColis.retire:
        return const Color(0xFF455A64);
    }
  }

  String get paiementLabel {
    switch (statutPaiement) {
      case StatutPaiement.payeMomo:
        return 'Payé MTN MoMo';
      case StatutPaiement.payeOrangeMoney:
        return 'Payé Orange Money';
      case StatutPaiement.payeEspeces:
        return 'Payé en Espèces';
      case StatutPaiement.aPayerAuRetrait:
        return 'À payer au retrait';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tracking_number': trackingNumber,
      'agency_id': agencyId,
      'date_enregistrement': dateEnregistrement.toIso8601String(),
      'expediteur_nom': expediteurNom,
      'expediteur_tel': expediteurTel,
      'ville_depart': villeDepart,
      'agence_depart': agenceDepart,
      'destinataire_nom': destinataireNom,
      'destinataire_tel': destinataireTel,
      'ville_arrivee': villeArrivee,
      'agence_arrivee': agenceArrivee,
      'guichet_retrait': guichetRetrait,
      'type_colis': typeColis,
      'poids_kg': poidsKg,
      'valeur_declaree_fcfa': valeurDeclareeFcfa,
      'prix_transport_fcfa': prixTransportFcfa,
      'statut_paiement': statutPaiement.name,
      'statut': statut.name,
      'code_secret_retrait': codeSecretRetrait,
      'matricule_bus': matriculeBus,
      'chauffeur_nom': chauffeurNom,
      'photo_colis_prise': photoColisPrise ? 1 : 0,
      'photo_colis_description': photoColisDescription,
      'cni_destinataire_numero': cniDestinataireNumero,
      'cni_scan_effectue': cniScanEffectue ? 1 : 0,
      'est_contre_remboursement': estContreRemboursement ? 1 : 0,
      'montant_marchandise_fcfa': montantMarchandiseFcfa,
      'commission_agence_fcfa': commissionAgenceFcfa,
      'sync_status': syncStatus.name,
    };
  }

  factory Colis.fromMap(Map<String, dynamic> map, {List<EtapeSuivi>? historique}) {
    StatutColis parsedStatut;
    try {
      parsedStatut = StatutColis.values.byName(map['statut'] as String? ?? 'enregistre');
    } catch (_) {
      parsedStatut = StatutColis.enregistre;
    }

    StatutPaiement parsedPaiement;
    try {
      parsedPaiement =
          StatutPaiement.values.byName(map['statut_paiement'] as String? ?? 'payeEspeces');
    } catch (_) {
      parsedPaiement = StatutPaiement.payeEspeces;
    }

    SyncStatus parsedSync;
    try {
      parsedSync =
          SyncStatus.values.byName(map['sync_status'] as String? ?? 'synced');
    } catch (_) {
      parsedSync = SyncStatus.synced;
    }

    final idVal = map['id'] as String? ?? '';
    final trackingVal = map['tracking_number'] as String? ?? idVal;

    return Colis(
      id: idVal,
      trackingNumber: trackingVal,
      agencyId: map['agency_id'] as String? ?? 'buca-voyages-default',
      dateEnregistrement:
          DateTime.tryParse(map['date_enregistrement'] as String? ?? '') ?? DateTime.now(),
      expediteurNom: map['expediteur_nom'] as String? ?? '',
      expediteurTel: map['expediteur_tel'] as String? ?? '',
      villeDepart: map['ville_depart'] as String? ?? '',
      agenceDepart: map['agence_depart'] as String? ?? '',
      destinataireNom: map['destinataire_nom'] as String? ?? '',
      destinataireTel: map['destinataire_tel'] as String? ?? '',
      villeArrivee: map['ville_arrivee'] as String? ?? '',
      agenceArrivee: map['agence_arrivee'] as String? ?? '',
      guichetRetrait: map['guichet_retrait'] as String? ?? 'Guichet 1 (Principal)',
      typeColis: map['type_colis'] as String? ?? 'Carton Marchandises Diverses',
      poidsKg: (map['poids_kg'] as num? ?? 1.0).toDouble(),
      valeurDeclareeFcfa: (map['valeur_declaree_fcfa'] as num? ?? 0).toInt(),
      prixTransportFcfa: (map['prix_transport_fcfa'] as num? ?? 0).toInt(),
      statutPaiement: parsedPaiement,
      statut: parsedStatut,
      codeSecretRetrait: map['code_secret_retrait'] as String? ?? '0000',
      matriculeBus: map['matricule_bus'] as String?,
      chauffeurNom: map['chauffeur_nom'] as String?,
      historique: historique ?? [],
      photoColisPrise: (map['photo_colis_prise'] as int? ?? 0) == 1,
      photoColisDescription: map['photo_colis_description'] as String?,
      cniDestinataireNumero: map['cni_destinataire_numero'] as String?,
      cniScanEffectue: (map['cni_scan_effectue'] as int? ?? 0) == 1,
      estContreRemboursement: (map['est_contre_remboursement'] as int? ?? 0) == 1,
      montantMarchandiseFcfa: (map['montant_marchandise_fcfa'] as num? ?? 0).toInt(),
      commissionAgenceFcfa: (map['commission_agence_fcfa'] as num? ?? 0).toInt(),
      syncStatus: parsedSync,
    );
  }

  Colis copyWith({
    StatutColis? statut,
    String? matriculeBus,
    String? chauffeurNom,
    String? cniDestinataireNumero,
    bool? cniScanEffectue,
    List<EtapeSuivi>? historique,
    SyncStatus? syncStatus,
  }) {
    return Colis(
      id: id,
      trackingNumber: trackingNumber,
      agencyId: agencyId,
      dateEnregistrement: dateEnregistrement,
      expediteurNom: expediteurNom,
      expediteurTel: expediteurTel,
      villeDepart: villeDepart,
      agenceDepart: agenceDepart,
      destinataireNom: destinataireNom,
      destinataireTel: destinataireTel,
      villeArrivee: villeArrivee,
      agenceArrivee: agenceArrivee,
      guichetRetrait: guichetRetrait,
      typeColis: typeColis,
      poidsKg: poidsKg,
      valeurDeclareeFcfa: valeurDeclareeFcfa,
      prixTransportFcfa: prixTransportFcfa,
      statutPaiement: statutPaiement,
      statut: statut ?? this.statut,
      codeSecretRetrait: codeSecretRetrait,
      matriculeBus: matriculeBus ?? this.matriculeBus,
      chauffeurNom: chauffeurNom ?? this.chauffeurNom,
      historique: historique ?? List.from(this.historique),
      photoColisPrise: photoColisPrise,
      photoColisDescription: photoColisDescription,
      cniDestinataireNumero: cniDestinataireNumero ?? this.cniDestinataireNumero,
      cniScanEffectue: cniScanEffectue ?? this.cniScanEffectue,
      estContreRemboursement: estContreRemboursement,
      montantMarchandiseFcfa: montantMarchandiseFcfa,
      commissionAgenceFcfa: commissionAgenceFcfa,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

/// DTO public pour le suivi client sans compte
/// Ne divulgue JAMAIS de données privées (CNI, téléphones complets, OTP, commissions)
class ColisPublicView {
  final String trackingNumber;
  final String agencyName;
  final StatutColis status;
  final String statusLabel;
  final Color statusColor;
  final String originCity;
  final String originBranch;
  final String destinationCity;
  final String destinationBranch;
  final String pickupCounter;
  final String parcelType;
  final DateTime lastUpdated;
  final List<EtapeSuivi> events;

  const ColisPublicView({
    required this.trackingNumber,
    required this.agencyName,
    required this.status,
    required this.statusLabel,
    required this.statusColor,
    required this.originCity,
    required this.originBranch,
    required this.destinationCity,
    required this.destinationBranch,
    required this.pickupCounter,
    required this.parcelType,
    required this.lastUpdated,
    required this.events,
  });

  /// Assainissement défensif de la description d'un événement public (Protection Zéro-Fuite)
  /// Empêche la divulgation de CNI, récépissé, passeport ou matricule interne
  static String _assainirDescriptionPublique(String description) {
    if (description.isEmpty) return description;

    // Détection multi-variantes de mentions d'identité (ex: "CNI : 123456", "CNI : Vérifiée", etc.)
    final regexSensible = RegExp(
      r"(cni|carte\s+d['’]identit[eé]|r[eé]c[eé]piss[eé]|passeport)",
      caseSensitive: false,
    );

    if (regexSensible.hasMatch(description)) {
      return 'Colis remis au destinataire après vérification d\'identité.';
    }

    return description;
  }

  factory ColisPublicView.fromColis(Colis colis, {String agencyName = 'Agence de Transport'}) {
    return ColisPublicView(
      trackingNumber: colis.trackingNumber,
      agencyName: agencyName,
      status: colis.statut,
      statusLabel: colis.statutLabel,
      statusColor: colis.statutColor,
      originCity: colis.villeDepart,
      originBranch: colis.agenceDepart,
      destinationCity: colis.villeArrivee,
      destinationBranch: colis.agenceArrivee,
      pickupCounter: colis.guichetRetrait,
      parcelType: colis.typeColis,
      lastUpdated: colis.historique.isNotEmpty
          ? colis.historique.last.date
          : colis.dateEnregistrement,
      events: List.unmodifiable(colis.historique.map((e) {
        final descPropre = _assainirDescriptionPublique(e.description);
        return EtapeSuivi(
          date: e.date,
          titre: e.titre,
          description: descPropre,
          lieu: e.lieu,
          estCompletee: e.estCompletee,
          actorId: null, // Cloisonnement strict : aucun identifiant interne exposé
        );
      })),
    );
  }
}
