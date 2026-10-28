import 'package:flutter/foundation.dart';
import '../models/agency.dart';
import 'database_service.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final DatabaseService _dbService = DatabaseService();

  Agency? _currentAgency;
  AgencyMember? _currentMember;
  List<Agency> _availableAgencies = [];

  Agency? get currentAgency => _currentAgency;
  AgencyMember? get currentMember => _currentMember;
  List<Agency> get availableAgencies => List.unmodifiable(_availableAgencies);

  bool get isAuthenticated => _currentMember != null && _currentAgency != null;
  bool get isManager => _currentMember?.role == UserRole.agencyManager;
  String get agencyId => _currentAgency?.id ?? 'buca-voyages-default';
  String get agencyName => _currentAgency?.name ?? 'Agence Non Connectée';

  Future<void> init() async {
    // Initialise les agences de référence
    await _initDefaultAgencies();
  }

  Future<void> _initDefaultAgencies() async {
    final existing = await _dbService.getAllAgencies();
    if (existing.isEmpty) {
      final buca = Agency(
        id: 'agency-buca-001',
        name: 'Buca Voyages VIP',
        code: 'BUCA',
        phone: '+237 699 10 20 30',
        cityHeadquarters: 'Yaoundé Mvan',
        createdAt: DateTime.now(),
      );
      final general = Agency(
        id: 'agency-general-002',
        name: 'Général Express Voyages',
        code: 'GEN',
        phone: '+237 677 40 50 60',
        cityHeadquarters: 'Douala Bassa',
        createdAt: DateTime.now(),
      );
      final finexs = Agency(
        id: 'agency-finexs-003',
        name: 'Finexs Voyages',
        code: 'FNX',
        phone: '+237 655 80 90 00',
        cityHeadquarters: 'Douala Akwa',
        createdAt: DateTime.now(),
      );

      await _dbService.insertAgency(buca);
      await _dbService.insertAgency(general);
      await _dbService.insertAgency(finexs);

      final managerBuca = AgencyMember(
        id: 'mem-001',
        agencyId: buca.id,
        userId: 'usr-buca-admin',
        fullName: 'M. Jean-Paul Mbida',
        role: UserRole.agencyManager,
        createdAt: DateTime.now(),
      );
      await _dbService.insertMember(managerBuca);

      _availableAgencies = [buca, general, finexs];
      _currentAgency = buca;
      _currentMember = managerBuca;
    } else {
      _availableAgencies = existing;
      _currentAgency = existing.first;
      final members = await _dbService.getMembersByAgency(_currentAgency!.id);
      _currentMember = members.isNotEmpty
          ? members.first
          : AgencyMember(
              id: 'mem-default',
              agencyId: _currentAgency!.id,
              userId: 'usr-default',
              fullName: 'Agent Guichet',
              role: UserRole.agencyAgent,
              createdAt: DateTime.now(),
            );
    }
    notifyListeners();
  }

  Future<void> switchAgency(Agency agency) async {
    _currentAgency = agency;
    final members = await _dbService.getMembersByAgency(agency.id);
    _currentMember = members.isNotEmpty
        ? members.first
        : AgencyMember(
            id: 'mem-${agency.code.toLowerCase()}-agent',
            agencyId: agency.id,
            userId: 'usr-${agency.code.toLowerCase()}',
            fullName: 'Agent ${agency.name}',
            role: UserRole.agencyAgent,
            createdAt: DateTime.now(),
          );
    notifyListeners();
  }

  void loginAs({
    required Agency agency,
    required UserRole role,
    required String fullName,
  }) {
    _currentAgency = agency;
    _currentMember = AgencyMember(
      id: 'mem-${DateTime.now().millisecondsSinceEpoch}',
      agencyId: agency.id,
      userId: 'usr-${agency.code.toLowerCase()}',
      fullName: fullName,
      role: role,
      createdAt: DateTime.now(),
    );
    notifyListeners();
  }
}
