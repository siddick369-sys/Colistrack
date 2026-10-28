import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/agency.dart';
import '../models/colis.dart';
import '../models/notification_item.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Permet d'injecter une base en mémoire pour les tests
  void setDatabaseForTesting(Database db) {
    _database = db;
  }

  Future<Database> _initDatabase() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'colisTrack_v2.db');

    final db = await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    await assainirHistoriqueSensible(db);
    return db;
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Table des Agences (Tenants SaaS)
    await db.execute('''
      CREATE TABLE agencies (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        code TEXT NOT NULL UNIQUE,
        phone TEXT,
        city_headquarters TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // 2. Membres d'agence
    await db.execute('''
      CREATE TABLE agency_members (
        id TEXT PRIMARY KEY,
        agency_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        full_name TEXT NOT NULL,
        role TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        FOREIGN KEY (agency_id) REFERENCES agencies (id) ON DELETE CASCADE
      )
    ''');

    // 3. Table des Colis avec agency_id et tracking_number sécurisé
    await db.execute('''
      CREATE TABLE colis (
        id TEXT PRIMARY KEY,
        tracking_number TEXT NOT NULL,
        agency_id TEXT NOT NULL DEFAULT 'buca-voyages-default',
        date_enregistrement TEXT NOT NULL,
        expediteur_nom TEXT NOT NULL,
        expediteur_tel TEXT NOT NULL,
        ville_depart TEXT NOT NULL,
        agence_depart TEXT NOT NULL,
        destinataire_nom TEXT NOT NULL,
        destinataire_tel TEXT NOT NULL,
        ville_arrivee TEXT NOT NULL,
        agence_arrivee TEXT NOT NULL,
        guichet_retrait TEXT NOT NULL,
        type_colis TEXT NOT NULL,
        poids_kg REAL NOT NULL,
        valeur_declaree_fcfa INTEGER NOT NULL,
        prix_transport_fcfa INTEGER NOT NULL,
        statut_paiement TEXT NOT NULL,
        statut TEXT NOT NULL,
        code_secret_retrait TEXT NOT NULL,
        matricule_bus TEXT,
        chauffeur_nom TEXT,
        photo_colis_prise INTEGER NOT NULL DEFAULT 0,
        photo_colis_description TEXT,
        cni_destinataire_numero TEXT,
        cni_scan_effectue INTEGER NOT NULL DEFAULT 0,
        est_contre_remboursement INTEGER NOT NULL DEFAULT 0,
        montant_marchandise_fcfa INTEGER NOT NULL DEFAULT 0,
        commission_agence_fcfa INTEGER NOT NULL DEFAULT 0,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        FOREIGN KEY (agency_id) REFERENCES agencies (id) ON DELETE RESTRICT
      )
    ''');

    // 4. Étapes de suivi avec traçabilité d'acteur
    await db.execute('''
      CREATE TABLE etapes_suivi (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        colis_id TEXT NOT NULL,
        date TEXT NOT NULL,
        titre TEXT NOT NULL,
        description TEXT NOT NULL,
        lieu TEXT NOT NULL,
        est_completee INTEGER NOT NULL DEFAULT 1,
        actor_id TEXT,
        FOREIGN KEY (colis_id) REFERENCES colis (id) ON DELETE CASCADE
      )
    ''');

    // 5. Notifications locales
    await db.execute('''
      CREATE TABLE notifications (
        id TEXT PRIMARY KEY,
        colis_id TEXT NOT NULL,
        agency_id TEXT,
        titre TEXT NOT NULL,
        message TEXT NOT NULL,
        type TEXT NOT NULL,
        date_creation TEXT NOT NULL,
        est_lu INTEGER NOT NULL DEFAULT 0,
        priorite TEXT NOT NULL DEFAULT 'normale',
        statut_declencheur TEXT NOT NULL,
        FOREIGN KEY (colis_id) REFERENCES colis (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('CREATE INDEX idx_colis_agency ON colis (agency_id)');
    await db.execute('CREATE INDEX idx_colis_tracking ON colis (tracking_number)');
    await db.execute('CREATE INDEX idx_etapes_colis ON etapes_suivi (colis_id)');
    await db.execute('CREATE INDEX idx_notifs_agency ON notifications (agency_id)');
    await db.execute('CREATE INDEX idx_notifs_date ON notifications (date_creation DESC)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS agencies (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          code TEXT NOT NULL UNIQUE,
          phone TEXT,
          city_headquarters TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS agency_members (
          id TEXT PRIMARY KEY,
          agency_id TEXT NOT NULL,
          user_id TEXT NOT NULL,
          full_name TEXT NOT NULL,
          role TEXT NOT NULL,
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL,
          FOREIGN KEY (agency_id) REFERENCES agencies (id) ON DELETE CASCADE
        )
      ''');

      try {
        await db.execute(
            "ALTER TABLE colis ADD COLUMN tracking_number TEXT;");
        await db.execute(
            "ALTER TABLE colis ADD COLUMN agency_id TEXT NOT NULL DEFAULT 'buca-voyages-default';");
        await db.execute(
            "ALTER TABLE colis ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'synced';");
        await db.execute(
            "UPDATE colis SET tracking_number = id WHERE tracking_number IS NULL;");
      } catch (_) {}

      try {
        await db.execute("ALTER TABLE etapes_suivi ADD COLUMN actor_id TEXT;");
      } catch (_) {}

      try {
        await db.execute("ALTER TABLE notifications ADD COLUMN agency_id TEXT;");
      } catch (_) {}
    }
  }

  // --- GESTION AGENCES (Multi-tenancy) ---

  Future<void> insertAgency(Agency agency) async {
    final db = await database;
    await db.insert(
      'agencies',
      agency.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Agency>> getAllAgencies() async {
    final db = await database;
    final maps = await db.query('agencies', orderBy: 'name ASC');
    return maps.map((m) => Agency.fromMap(m)).toList();
  }

  Future<Agency?> getAgencyById(String agencyId) async {
    final db = await database;
    final maps = await db.query(
      'agencies',
      where: 'id = ?',
      whereArgs: [agencyId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Agency.fromMap(maps.first);
  }

  Future<void> insertMember(AgencyMember member) async {
    final db = await database;
    await db.insert(
      'agency_members',
      member.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<AgencyMember>> getMembersByAgency(String agencyId) async {
    final db = await database;
    final maps = await db.query(
      'agency_members',
      where: 'agency_id = ?',
      whereArgs: [agencyId],
      orderBy: 'full_name ASC',
    );
    return maps.map((m) => AgencyMember.fromMap(m)).toList();
  }

  // --- CRUD COLIS & ISOLATION PAR AGENCE ---

  Future<void> insertColis(Colis colis) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert(
        'colis',
        colis.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await txn.delete('etapes_suivi', where: 'colis_id = ?', whereArgs: [colis.id]);

      for (final etape in colis.historique) {
        await txn.insert(
          'etapes_suivi',
          etape.toMap(colisId: colis.id),
        );
      }
    });
  }

  Future<void> updateColis(Colis colis) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'colis',
        colis.toMap(),
        where: 'id = ?',
        whereArgs: [colis.id],
      );

      await txn.delete('etapes_suivi', where: 'colis_id = ?', whereArgs: [colis.id]);
      for (final etape in colis.historique) {
        await txn.insert('etapes_suivi', etape.toMap(colisId: colis.id));
      }
    });
  }

  /// Récupère exclusivement les colis de l'agence spécifiée (Isolation stricte)
  Future<List<Colis>> getColisByAgency(String agencyId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'colis',
      where: 'agency_id = ?',
      whereArgs: [agencyId],
      orderBy: 'date_enregistrement DESC',
    );

    final List<Colis> resultat = [];
    for (final map in maps) {
      final colisId = map['id'] as String;
      final etapesMap = await db.query(
        'etapes_suivi',
        where: 'colis_id = ?',
        whereArgs: [colisId],
        orderBy: 'date ASC',
      );

      final historique = etapesMap.map((e) => EtapeSuivi.fromMap(e)).toList();
      resultat.add(Colis.fromMap(map, historique: historique));
    }
    return resultat;
  }

  Future<List<Colis>> getAllColis() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'colis',
      orderBy: 'date_enregistrement DESC',
    );

    final List<Colis> resultat = [];
    for (final map in maps) {
      final colisId = map['id'] as String;
      final etapesMap = await db.query(
        'etapes_suivi',
        where: 'colis_id = ?',
        whereArgs: [colisId],
        orderBy: 'date ASC',
      );

      final historique = etapesMap.map((e) => EtapeSuivi.fromMap(e)).toList();
      resultat.add(Colis.fromMap(map, historique: historique));
    }
    return resultat;
  }

  Future<Colis?> getColisById(String id) async {
    final db = await database;
    final maps = await db.query(
      'colis',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;

    final etapesMap = await db.query(
      'etapes_suivi',
      where: 'colis_id = ?',
      whereArgs: [id],
      orderBy: 'date ASC',
    );

    final historique = etapesMap.map((e) => EtapeSuivi.fromMap(e)).toList();
    return Colis.fromMap(maps.first, historique: historique);
  }

  Future<Colis?> getColisByTrackingNumber(String trackingNumber) async {
    final db = await database;
    final clean = trackingNumber.trim().toUpperCase();
    final maps = await db.query(
      'colis',
      where: 'UPPER(tracking_number) = ? OR UPPER(id) = ?',
      whereArgs: [clean, clean],
      limit: 1,
    );

    if (maps.isEmpty) return null;

    final colisId = maps.first['id'] as String;
    final etapesMap = await db.query(
      'etapes_suivi',
      where: 'colis_id = ?',
      whereArgs: [colisId],
      orderBy: 'date ASC',
    );

    final historique = etapesMap.map((e) => EtapeSuivi.fromMap(e)).toList();
    return Colis.fromMap(maps.first, historique: historique);
  }

  /// Suivi Public Sécurisé : renvoie uniquement le DTO public sans divulguer de données privées
  Future<ColisPublicView?> getPublicTracking(String trackingNumber) async {
    final colis = await getColisByTrackingNumber(trackingNumber);
    if (colis == null) return null;

    final agency = await getAgencyById(colis.agencyId);
    return ColisPublicView.fromColis(
      colis,
      agencyName: agency?.name ?? 'Compagnie de Voyage Partenaire',
    );
  }

  Future<void> markColisSyncStatus(String colisId, SyncStatus status) async {
    final db = await database;
    await db.update(
      'colis',
      {'sync_status': status.name},
      where: 'id = ?',
      whereArgs: [colisId],
    );
  }

  Future<List<Colis>> getPendingSyncColis() async {
    final db = await database;
    final maps = await db.query(
      'colis',
      where: 'sync_status = ?',
      whereArgs: [SyncStatus.pendingSync.name],
    );

    final List<Colis> resultat = [];
    for (final map in maps) {
      final colisId = map['id'] as String;
      final etapesMap = await db.query(
        'etapes_suivi',
        where: 'colis_id = ?',
        whereArgs: [colisId],
        orderBy: 'date ASC',
      );
      final historique = etapesMap.map((e) => EtapeSuivi.fromMap(e)).toList();
      resultat.add(Colis.fromMap(map, historique: historique));
    }
    return resultat;
  }

  // --- NOTIFICATIONS LOCALES IDEMPOTENTES ---

  Future<bool> insertNotification(NotificationItem item, {String? agencyId}) async {
    final db = await database;
    final map = item.toMap();
    if (agencyId != null) map['agency_id'] = agencyId;

    final rowId = await db.insert(
      'notifications',
      map,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return rowId > 0;
  }

  Future<List<NotificationItem>> getNotifications({String? agencyId}) async {
    final db = await database;
    final maps = await db.query(
      'notifications',
      where: agencyId != null ? 'agency_id = ? OR agency_id IS NULL' : null,
      whereArgs: agencyId != null ? [agencyId] : null,
      orderBy: 'date_creation DESC',
    );
    return maps.map((m) => NotificationItem.fromMap(m)).toList();
  }

  Future<int> getUnreadNotificationCount({String? agencyId}) async {
    final db = await database;
    final res = await db.rawQuery(
      'SELECT COUNT(*) as count FROM notifications WHERE est_lu = 0'
      '${agencyId != null ? ' AND (agency_id = "$agencyId" OR agency_id IS NULL)' : ''}',
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  Future<void> markNotificationAsRead(String id) async {
    final db = await database;
    await db.update(
      'notifications',
      {'est_lu': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markAllNotificationsAsRead() async {
    final db = await database;
    await db.update('notifications', {'est_lu': 1});
  }

  /// Assainissement transactionnel et idempotent de l'historique SQLite
  /// Nettoie les descriptions sensibles contenant des numéros de pièces d'identité (CNI)
  /// sans altérer les autres informations métier utiles
  Future<int> assainirHistoriqueSensible([Database? dbInstance]) async {
    final db = dbInstance ?? await database;
    int lignesAssainies = 0;

    await db.transaction((txn) async {
      final rows = await txn.rawQuery('''
        SELECT id, titre, description 
        FROM etapes_suivi 
        WHERE description LIKE '%CNI%' 
           OR description LIKE '%Carte d%' 
           OR description LIKE '%Récépissé%'
      ''');

      final regexSensible = RegExp(
        r"(cni|carte\s+d['’]identit[eé]|r[eé]c[eé]piss[eé]|passeport)",
        caseSensitive: false,
      );

      for (final row in rows) {
        final id = row['id'] as int;
        final description = row['description'] as String? ?? '';

        if (regexSensible.hasMatch(description)) {
          String nouvelleDesc;
          if (description.contains('remboursement') || description.contains('FCFA')) {
            nouvelleDesc = 'Retrait effectué après vérification d\'identité. Contre-remboursement traité selon le statut enregistré.';
          } else {
            nouvelleDesc = 'Colis remis au destinataire après vérification d\'identité.';
          }

          if (nouvelleDesc != description) {
            await txn.rawUpdate(
              'UPDATE etapes_suivi SET description = ? WHERE id = ?',
              [nouvelleDesc, id],
            );
            lignesAssainies++;
          }
        }
      }
    });

    return lignesAssainies;
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('etapes_suivi');
    await db.delete('notifications');
    await db.delete('colis');
    try {
      await db.delete('agency_members');
      await db.delete('agencies');
    } catch (_) {}
  }
}
