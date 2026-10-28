import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/colis.dart';
import 'auth_service.dart';
import 'database_service.dart';
import 'notification_service.dart';

class CurrencyAdapter {
  final ColisService _service;
  CurrencyAdapter(this._service);
  String format(num value) => _service.formatFcfa(value);
}

class DateAdapter {
  final ColisService _service;
  DateAdapter(this._service);
  String format(DateTime date) => _service.formatDate(date);
}

class ColisService extends ChangeNotifier {
  static final ColisService _instance = ColisService._internal();
  factory ColisService() => _instance;

  final DatabaseService _dbService = DatabaseService();
  final NotificationService _notifService = NotificationService();
  final AuthService _authService = AuthService();

  bool _isInitialized = false;
  bool _simulerHorsLigne = false;

  ColisService._internal() {
    _authService.addListener(_onAuthChanged);
  }

  bool get isInitialized => _isInitialized;
  bool get estHorsLigne => _simulerHorsLigne;
  bool get simulerHorsLigne => _simulerHorsLigne;
  int get nombreEnAttenteSync =>
      _colisList.where((c) => c.syncStatus == SyncStatus.pendingSync).length;
  SyncStatus get syncGlobalStatus => _simulerHorsLigne
      ? SyncStatus.pendingSync
      : SyncStatus.synced;

  void basculerModeReseau(bool horsLigne) {
    _simulerHorsLigne = horsLigne;
    notifyListeners();
  }

  void resetForTesting() {
    _isInitialized = false;
    _colisList.clear();
    _simulerHorsLigne = false;
  }

  Future<void> _onAuthChanged() async {
    await chargerColisAgenceActuelle();
  }

  Future<void> init() async {
    try {
      final agences = await _dbService.getAllAgencies();
      if (agences.isEmpty) {
        await _authService.init();
      }

      final tousColis = await _dbService.getAllColis();
      if (tousColis.isEmpty) {
        _initDemoData();
        final listToInsert = List<Colis>.from(_colisList);
        for (final c in listToInsert) {
          await _dbService.insertColis(c);
        }
      }

      await chargerColisAgenceActuelle();
      await _notifService.init();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[ColisService] Init fallback: $e');
      if (_colisList.isEmpty) {
        _initDemoData();
      }
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> chargerColisAgenceActuelle() async {
    try {
      final agencyId = _authService.agencyId;
      final colis = await _dbService.getColisByAgency(agencyId);
      _colisList.clear();
      _colisList.addAll(colis);
      notifyListeners();
    } catch (e) {
      debugPrint('[ColisService] Erreur chargement colis agence: $e');
    }
  }

  String formatFcfa(num montant) {
    final intVal = montant.round();
    final str = intVal.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(str[i]);
    }
    return '${buffer.toString()} FCFA';
  }

  String formatDate(DateTime d) {
    final jour = d.day.toString().padLeft(2, '0');
    final mois = d.month.toString().padLeft(2, '0');
    final annee = d.year;
    final heure = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '$jour/$mois/$annee à $heure:$minute';
  }

  CurrencyAdapter get currencyFormat => CurrencyAdapter(this);
  DateAdapter get dateFormat => DateAdapter(this);

  final List<String> villes = [
    'Douala',
    'Yaoundé',
    'Bafoussam',
    'Bamenda',
    'Garoua',
    'Maroua',
    'Ngaoundéré',
    'Kribi',
    'Bertoua',
  ];

  final Map<String, List<String>> agencesParVille = {
    'Douala': ['Agence Bassa (Zone Industrielle)', 'Agence Akwa (Centre)', 'Agence Bonabéri'],
    'Yaoundé': ['Agence Mvan (Gare Routière)', 'Agence Biyem-Assi', 'Agence Tongolo'],
    'Bafoussam': ['Agence Marché B', 'Agence Djeleng'],
    'Bamenda': ['Agence Commercial Avenue'],
    'Garoua': ['Agence Roumdé Adjia'],
    'Maroua': ['Agence Domayo'],
    'Ngaoundéré': ['Agence Gare Ferroviaire'],
    'Kribi': ['Agence Plage / Centre'],
    'Bertoua': ['Agence Enia'],
  };

  final List<String> typesColis = [
    'Carton Marchandises Diverses',
    'Sac de Vivres Frais / Poissons',
    'Appareil Électronique / Téléphone',
    'Valise / Sac de Voyage',
    'Courrier / Documents Officiels',
    'Pièces Détachées Mécaniques',
  ];

  final List<Colis> _colisList = [];

  List<Colis> get allColis => List.unmodifiable(_colisList);

  void _initDemoData() {
    final now = DateTime.now();

    // Colis pour Agence Buca Voyages
    _colisList.addAll([
      Colis(
        id: 'CE-DLA-YDE-8921',
        trackingNumber: 'TRX-8921-M4K',
        agencyId: 'agency-buca-001',
        dateEnregistrement: now.subtract(const Duration(hours: 4, minutes: 15)),
        expediteurNom: 'M. Mbarga Emmanuel',
        expediteurTel: '+237 699 45 12 80',
        villeDepart: 'Douala',
        agenceDepart: 'Agence Bassa (Zone Industrielle)',
        destinataireNom: 'Mme Ngo Biyong Jeanne',
        destinataireTel: '+237 677 22 90 14',
        villeArrivee: 'Yaoundé',
        agenceArrivee: 'Agence Mvan (Gare Routière)',
        guichetRetrait: 'Guichet 2 (Colis Lourds)',
        typeColis: 'Appareil Électronique / Téléphone',
        poidsKg: 18.5,
        valeurDeclareeFcfa: 150000,
        prixTransportFcfa: 4500,
        statutPaiement: StatutPaiement.payeMomo,
        statut: StatutColis.enTransit,
        codeSecretRetrait: '4829',
        matriculeBus: 'LT 894 CE (Buca VIP)',
        chauffeurNom: 'M. Talla Paul',
        photoColisPrise: true,
        photoColisDescription:
            'Carton TV LED scellé avec scotch sécurité vert et film plastique.',
        estContreRemboursement: true,
        montantMarchandiseFcfa: 85000,
        commissionAgenceFcfa: 2500,
        syncStatus: SyncStatus.synced,
        historique: [
          EtapeSuivi(
            date: now.subtract(const Duration(hours: 4, minutes: 15)),
            titre: 'Enregistrement & Preuve Photo Horodatée',
            description:
                'Colis photographié et scellé. Envoi en Cash on Delivery (85 000 FCFA à recouvrer).',
            lieu: 'Douala Bassa',
          ),
          EtapeSuivi(
            date: now.subtract(const Duration(hours: 3)),
            titre: 'Embarquement dans le Car',
            description: 'Chargé en soute du bus LT 894 CE.',
            lieu: 'Douala Bassa',
          ),
          EtapeSuivi(
            date: now.subtract(const Duration(minutes: 45)),
            titre: 'Contrôle en Route',
            description: 'Passage du péage d\'Édéa - Circulation fluide.',
            lieu: 'Édéa (Axe Lourd N3)',
          ),
        ],
      ),
      Colis(
        id: 'CE-DLA-BAF-4102',
        trackingNumber: 'TRX-4102-W8P',
        agencyId: 'agency-buca-001',
        dateEnregistrement: now.subtract(const Duration(hours: 7)),
        expediteurNom: 'Mme Fotso Carine',
        expediteurTel: '+237 694 11 33 55',
        villeDepart: 'Douala',
        agenceDepart: 'Agence Akwa (Centre)',
        destinataireNom: 'M. Kamdem Lucas',
        destinataireTel: '+237 651 88 00 23',
        villeArrivee: 'Bafoussam',
        agenceArrivee: 'Agence Marché B',
        guichetRetrait: 'Guichet 1 (Vivres & Périssables)',
        typeColis: 'Sac de Vivres Frais / Poissons',
        poidsKg: 25.0,
        valeurDeclareeFcfa: 80000,
        prixTransportFcfa: 3500,
        statutPaiement: StatutPaiement.payeOrangeMoney,
        statut: StatutColis.arriveDestination,
        codeSecretRetrait: '1974',
        matriculeBus: 'OU 212 BB (Buca Express)',
        chauffeurNom: 'M. Wamba Jean',
        photoColisPrise: true,
        photoColisDescription:
            'Sac de vivres ficelé double nœud, étiquette waterproof.',
        syncStatus: SyncStatus.synced,
        historique: [
          EtapeSuivi(
            date: now.subtract(const Duration(hours: 7)),
            titre: 'Dépôt au Guichet Akwa',
            description:
                'Photo prise. Sac étiqueté frais et priorité route de l\'Ouest.',
            lieu: 'Douala Akwa',
          ),
          EtapeSuivi(
            date: now.subtract(const Duration(hours: 5, minutes: 30)),
            titre: 'Départ du Car',
            description: 'Bus parti de Douala direction Bafoussam.',
            lieu: 'Douala',
          ),
          EtapeSuivi(
            date: now.subtract(const Duration(minutes: 30)),
            titre: 'Arrivé à destination',
            description:
                'Déchargé et stocké au Guichet 1. Notification automatique transmise.',
            lieu: 'Bafoussam Marché B',
          ),
        ],
      ),
      Colis(
        id: 'CE-YDE-DLA-1108',
        trackingNumber: 'TRX-1108-Z2N',
        agencyId: 'agency-buca-001',
        dateEnregistrement: now.subtract(const Duration(days: 1, hours: 2)),
        expediteurNom: 'Cabinet Me Atangana',
        expediteurTel: '+237 671 00 11 22',
        villeDepart: 'Yaoundé',
        agenceDepart: 'Agence Biyem-Assi',
        destinataireNom: 'M. Ewane Roger',
        destinataireTel: '+237 698 77 44 11',
        villeArrivee: 'Douala',
        agenceArrivee: 'Agence Bonabéri',
        guichetRetrait: 'Guichet Express Courrier',
        typeColis: 'Courrier / Documents Officiels',
        poidsKg: 0.8,
        valeurDeclareeFcfa: 50000,
        prixTransportFcfa: 1500,
        statutPaiement: StatutPaiement.payeEspeces,
        statut: StatutColis.retire,
        codeSecretRetrait: '8520',
        matriculeBus: 'LT 894 CE (Buca VIP)',
        chauffeurNom: 'M. Talla Paul',
        photoColisPrise: true,
        photoColisDescription: 'Enveloppe scellée avec cachet de cire.',
        cniDestinataireNumero: 'CNI-SYNTH-TEST-001',
        cniScanEffectue: true,
        syncStatus: SyncStatus.synced,
        historique: [
          EtapeSuivi(
            date: now.subtract(const Duration(days: 1, hours: 2)),
            titre: 'Dépôt enveloppe scellée',
            description: 'Photo du pli enregistrée.',
            lieu: 'Yaoundé Biyem-Assi',
          ),
          EtapeSuivi(
            date: now.subtract(const Duration(hours: 18)),
            titre: 'Arrivé à destination',
            description: 'Disponible pour retrait.',
            lieu: 'Douala Bonabéri',
          ),
          EtapeSuivi(
            date: now.subtract(const Duration(hours: 2)),
            titre: 'Retiré par le Destinataire (CNI Archivée)',
            description:
                'CNI n° CNI-SYNTH-TEST-001 scannée et archivée. Code secret 8520 validé.',
            lieu: 'Douala Bonabéri',
          ),
        ],
      ),
      // Colis Agence Concurrente (Général Express) pour tester l'isolation stricte
      Colis(
        id: 'GEN-DLA-YDE-9901',
        trackingNumber: 'TRX-9901-GEN',
        agencyId: 'agency-general-002',
        dateEnregistrement: now.subtract(const Duration(hours: 2)),
        expediteurNom: 'Société Africaine de Commerce',
        expediteurTel: '+237 670 11 22 33',
        villeDepart: 'Douala',
        agenceDepart: 'Agence Bassa',
        destinataireNom: 'Quincaillerie Centrale',
        destinataireTel: '+237 690 99 88 77',
        villeArrivee: 'Yaoundé',
        agenceArrivee: 'Agence Mvan',
        guichetRetrait: 'Guichet Fret Lourd',
        typeColis: 'Pièces Détachées Mécaniques',
        poidsKg: 45.0,
        valeurDeclareeFcfa: 450000,
        prixTransportFcfa: 8000,
        statutPaiement: StatutPaiement.payeMomo,
        statut: StatutColis.chargeBus,
        codeSecretRetrait: '3310',
        matriculeBus: 'CE 554 BB',
        chauffeurNom: 'M. Bikélé Thomas',
        syncStatus: SyncStatus.synced,
        historique: [
          EtapeSuivi(
            date: now.subtract(const Duration(hours: 2)),
            titre: 'Enregistrement chez Général Express',
            description: 'Colis enregistré en compte entreprise.',
            lieu: 'Douala Bassa',
          ),
        ],
      ),
    ]);
  }

  // KPIs de l'agence active
  int get totalColis => _colisList.length;
  int get colisEnTransit => _colisList
      .where((c) =>
          c.statut == StatutColis.enTransit || c.statut == StatutColis.chargeBus)
      .length;
  int get colisEnAttenteRetrait =>
      _colisList.where((c) => c.statut == StatutColis.arriveDestination).length;
  int get colisLivres =>
      _colisList.where((c) => c.statut == StatutColis.retire).length;
  int get colisCashOnDelivery =>
      _colisList.where((c) => c.estContreRemboursement).length;

  int get totalRecettesFcfa => _colisList.fold(
      0, (sum, c) => sum + c.prixTransportFcfa + c.commissionAgenceFcfa);
  int get recettesMomoFcfa => _colisList
      .where((c) =>
          c.statutPaiement == StatutPaiement.payeMomo ||
          c.statutPaiement == StatutPaiement.payeOrangeMoney)
      .fold(0, (sum, c) => sum + c.prixTransportFcfa);
  int get recettesEspecesFcfa => _colisList
      .where((c) => c.statutPaiement == StatutPaiement.payeEspeces)
      .fold(0, (sum, c) => sum + c.prixTransportFcfa);

  List<String> get matriculesBusActifs => [
    'LT 894 CE (Buca VIP)',
    'OU 212 BB (Général Express)',
    'LT 521 CC (Touristique Express)',
    'CE 401 AA (Finexs Voyage)',
  ];

  List<Colis> getColisParBus(String matricule) {
    return _colisList.where((c) => c.matriculeBus == matricule).toList();
  }

  Colis? trouverParCode(String code) {
    final clean = code.trim().toUpperCase();
    try {
      return _colisList.firstWhere((c) =>
          c.id.toUpperCase() == clean ||
          c.trackingNumber.toUpperCase() == clean);
    } catch (_) {
      return null;
    }
  }

  List<Colis> rechercher(String query) {
    if (query.trim().isEmpty) return allColis;
    final q = query.trim().toLowerCase();
    return _colisList.where((c) {
      return c.id.toLowerCase().contains(q) ||
          c.trackingNumber.toLowerCase().contains(q) ||
          c.destinataireNom.toLowerCase().contains(q) ||
          c.destinataireTel.contains(q) ||
          c.expediteurNom.toLowerCase().contains(q) ||
          c.villeDepart.toLowerCase().contains(q) ||
          c.villeArrivee.toLowerCase().contains(q);
    }).toList();
  }

  /// Génération d'un numéro de suivi public à haute entropie (60.0 bits, anti-énumération)
  /// Alphabet Base32 non ambigu (32 symboles : sans 0/O, 1/I)
  /// Entropie calculée : 12 caractères * log2(32) = 12 * 5 = 60.0 bits
  String genererTrackingNumberSecurise() {
    final rand = Random.secure();
    const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    final b1 = List.generate(4, (_) => chars[rand.nextInt(chars.length)]).join();
    final b2 = List.generate(4, (_) => chars[rand.nextInt(chars.length)]).join();
    final b3 = List.generate(4, (_) => chars[rand.nextInt(chars.length)]).join();
    return 'TRX-$b1-$b2-$b3';
  }

  /// Génération sécurisée d'un code OTP à 4 chiffres avec préservation des zéros initiaux
  String genererOtpSecurise() {
    final rand = Random.secure();
    final code = rand.nextInt(10000);
    return code.toString().padLeft(4, '0');
  }

  Future<Colis> enregistrerNouveauColis({
    required String expediteurNom,
    required String expediteurTel,
    required String villeDepart,
    required String agenceDepart,
    required String destinataireNom,
    required String destinataireTel,
    required String villeArrivee,
    required String agenceArrivee,
    required String typeColis,
    required double poidsKg,
    required int valeurDeclareeFcfa,
    required int prixTransportFcfa,
    required StatutPaiement statutPaiement,
    bool photoColisPrise = false,
    String? photoColisDescription,
    bool estContreRemboursement = false,
    int montantMarchandiseFcfa = 0,
    String? agencyId,
  }) async {
    final rand = Random.secure();
    final currentAgencyId = agencyId ?? _authService.agencyId;
    
    // Détection défensive de collision locale SQLite (p < 2^-60)
    String trackingNumber = genererTrackingNumberSecurise();
    int tentatives = 0;
    while (await _dbService.getColisByTrackingNumber(trackingNumber) != null && tentatives < 5) {
      trackingNumber = genererTrackingNumberSecurise();
      tentatives++;
    }

    final internalId = 'PKG-${DateTime.now().millisecondsSinceEpoch}-${rand.nextInt(999).toString().padLeft(3, '0')}';
    final codeSecret = genererOtpSecurise();

    final commissionAgence =
        estContreRemboursement ? (montantMarchandiseFcfa * 0.025).round() : 0;

    final initialSync =
        _simulerHorsLigne ? SyncStatus.pendingSync : SyncStatus.synced;

    final nouveauColis = Colis(
      id: internalId,
      trackingNumber: trackingNumber,
      agencyId: currentAgencyId,
      dateEnregistrement: DateTime.now(),
      expediteurNom: expediteurNom,
      expediteurTel: expediteurTel,
      villeDepart: villeDepart,
      agenceDepart: agenceDepart,
      destinataireNom: destinataireNom,
      destinataireTel: destinataireTel,
      villeArrivee: villeArrivee,
      agenceArrivee: agenceArrivee,
      guichetRetrait: 'Guichet 1 (Principal)',
      typeColis: typeColis,
      poidsKg: poidsKg,
      valeurDeclareeFcfa: valeurDeclareeFcfa,
      prixTransportFcfa: prixTransportFcfa,
      statutPaiement: statutPaiement,
      statut: StatutColis.enregistre,
      codeSecretRetrait: codeSecret,
      photoColisPrise: photoColisPrise,
      photoColisDescription:
          photoColisDescription ?? 'Photo d\'inspection au guichet enregistrée.',
      estContreRemboursement: estContreRemboursement,
      montantMarchandiseFcfa: montantMarchandiseFcfa,
      commissionAgenceFcfa: commissionAgence,
      syncStatus: initialSync,
      historique: [
        EtapeSuivi(
          date: DateTime.now(),
          titre: 'Enregistrement au Guichet & Photo',
          description: estContreRemboursement
              ? 'Colis scellé et photographié. Option Cash on Delivery ($montantMarchandiseFcfa FCFA à reverser).'
              : 'Colis photographié et scellé à l\'agence $agenceDepart.',
          lieu: '$villeDepart - $agenceDepart',
          actorId: _authService.currentMember?.userId,
        ),
      ],
    );

    _colisList.insert(0, nouveauColis);

    // Persistance SQLite
    await _dbService.insertColis(nouveauColis);

    // Notification idempotente
    await _notifService.notifierChangementStatut(
      colis: nouveauColis,
      ancienStatut: StatutColis.retire,
      nouveauStatut: StatutColis.enregistre,
    );

    notifyListeners();
    return nouveauColis;
  }

  Future<bool> mettreAJourStatut({
    required String colisId,
    required StatutColis nouveauStatut,
    String? matriculeBus,
    String? chauffeurNom,
    String? lieu,
    String? note,
    String? cniNumero,
    bool cniScanEffectue = false,
    String? codeOtp,
  }) async {
    final colis = trouverParCode(colisId);
    if (colis == null) return false;

    // Règle 1 : Protection contre les retraits répétés et modifications d'un colis déjà retiré
    if (colis.statut == StatutColis.retire) {
      return false;
    }

    // Règle 2 : Le passage à 'retire' exige impérativement que le colis soit arrivé à destination
    // et que le code OTP fourni corresponde exactement au code secret de retrait
    if (nouveauStatut == StatutColis.retire) {
      if (colis.statut != StatutColis.arriveDestination) {
        return false;
      }
      if (codeOtp == null || codeOtp.trim().isEmpty || codeOtp.trim() != colis.codeSecretRetrait.trim()) {
        return false;
      }
    }

    final ancienStatut = colis.statut;
    colis.statut = nouveauStatut;
    if (matriculeBus != null) colis.matriculeBus = matriculeBus;
    if (chauffeurNom != null) colis.chauffeurNom = chauffeurNom;
    if (cniNumero != null) {
      colis.cniDestinataireNumero = cniNumero;
      colis.cniScanEffectue = cniScanEffectue;
    }

    colis.syncStatus =
        _simulerHorsLigne ? SyncStatus.pendingSync : SyncStatus.synced;

    String titre;
    String description;
    String localisation = lieu ?? colis.villeDepart;

    switch (nouveauStatut) {
      case StatutColis.enregistre:
        titre = 'Réenregistré au guichet';
        description = note ?? 'Colis en attente de chargement.';
        break;
      case StatutColis.chargeBus:
        titre = 'Chargé dans le bus';
        description = 'Embarqué dans le car ${colis.matriculeBus ?? 'de ligne'}.';
        break;
      case StatutColis.enTransit:
        titre = 'En transit routier';
        description = note ?? 'Le bus roule actuellement vers ${colis.villeArrivee}.';
        break;
      case StatutColis.arriveDestination:
        titre = 'Arrivé à destination (Prêt au Retrait)';
        description =
            note ?? 'Disponible au ${colis.guichetRetrait}. Destinataire avisé.';
        localisation = '${colis.villeArrivee} - ${colis.agenceArrivee}';
        break;
      case StatutColis.retire:
        titre = 'Colis Retiré & CNI Archivée';
        description = colis.estContreRemboursement
            ? 'Retrait effectué après vérification d\'identité. Contre-remboursement (${colis.montantMarchandiseFcfa} FCFA) traité selon le statut enregistré.'
            : 'Colis remis au destinataire après vérification d\'identité.';
        localisation = '${colis.villeArrivee} - ${colis.agenceArrivee}';
        break;
    }

    colis.historique.add(EtapeSuivi(
      date: DateTime.now(),
      titre: titre,
      description: description,
      lieu: localisation,
      actorId: _authService.currentMember?.userId,
    ));

    // Persistance SQLite
    await _dbService.updateColis(colis);

    // Notification idempotente
    await _notifService.notifierChangementStatut(
      colis: colis,
      ancienStatut: ancienStatut,
      nouveauStatut: nouveauStatut,
      note: note,
    );

    notifyListeners();
    return true;
  }

  /// Suivi Public sans compte (Sécurisé & Anti-fuite)
  Future<ColisPublicView?> consulterSuiviPublic(String trackingNumber) async {
    return await _dbService.getPublicTracking(trackingNumber);
  }

  /// Synchronise les colis enregistrés hors ligne dès rétablissement du réseau
  Future<int> synchroniserFileAttente() async {
    final enAttente = await _dbService.getPendingSyncColis();
    int succes = 0;
    for (final c in enAttente) {
      c.syncStatus = SyncStatus.synced;
      await _dbService.updateColis(c);
      final inMemory = trouverParCode(c.id);
      if (inMemory != null) {
        inMemory.syncStatus = SyncStatus.synced;
      }
      succes++;
    }
    await chargerColisAgenceActuelle();
    return succes;
  }
}
