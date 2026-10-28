import 'package:flutter/material.dart';
import '../main.dart';
import '../models/colis.dart';
import '../services/auth_service.dart';
import '../services/colis_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_badges.dart';
import '../widgets/notification_bell_button.dart';
import 'colis_detail_screen.dart';
import 'manifeste_voyage_screen.dart';
import 'rentabilite_screen.dart';
import 'scanner_transit_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onNouveauColis;
  final Function(String code) onSuivreColis;

  const DashboardScreen({
    super.key,
    required this.onNouveauColis,
    required this.onSuivreColis,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ColisService _colisService = ColisService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  String _filtreStatut = 'TOUS';

  @override
  void initState() {
    super.initState();
    _colisService.addListener(_onServiceUpdate);
    _authService.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _colisService.removeListener(_onServiceUpdate);
    _authService.removeListener(_onServiceUpdate);
    _searchController.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  List<Colis> get _colisFiltres {
    var liste = _colisService.rechercher(_searchController.text);
    if (_filtreStatut == 'TRANSIT') {
      liste = liste
          .where((c) =>
              c.statut == StatutColis.enTransit ||
              c.statut == StatutColis.chargeBus)
          .toList();
    } else if (_filtreStatut == 'ARRIVE') {
      liste = liste
          .where((c) => c.statut == StatutColis.arriveDestination)
          .toList();
    } else if (_filtreStatut == 'LIVRE') {
      liste = liste.where((c) => c.statut == StatutColis.retire).toList();
    } else if (_filtreStatut == 'COD') {
      liste = liste.where((c) => c.estContreRemboursement).toList();
    }
    return liste;
  }

  void _dialogChangerAgence() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final agences = _authService.availableAgencies;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'Changer d\'Agence (SaaS Multi-Agences)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Mode Démo Locale (Prototype) : Ce sélecteur modifie uniquement le filtrage des données SQLite locales. '
                          'En production SaaS, l\'isolation des agences est strictement verrouillée par authentification JWT côté serveur.',
                          style: TextStyle(fontSize: 11, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                ...agences.map((agency) {
                  final isSelected = agency.id == _authService.currentAgency?.id;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isSelected
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.1),
                      child: Text(
                        agency.code,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    title: Text(agency.name,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        )),
                    subtitle: Text('${agency.cityHeadquarters} • ${agency.phone}'),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: AppColors.primary)
                        : null,
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _authService.switchAgency(agency);
                      await _colisService.chargerColisAgenceActuelle();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppColors.primary,
                            content: Text('Connecté à : ${agency.name}'),
                          ),
                        );
                      }
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _dialogGestionSync() {
    final pendingCount = _colisService.nombreEnAttenteSync;
    final isHorsLigne = _colisService.simulerHorsLigne;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.cloud_sync_outlined, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Synchronisation & Réseau'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mode réseau actuel : ${isHorsLigne ? "🔴 Hors-ligne" : "🟢 Connecté"}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Colis locaux en attente de synchronisation : $pendingCount',
                style: TextStyle(
                  color: pendingCount > 0 ? AppColors.warningOrange : AppColors.successGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Divider(height: 24),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Simuler Mode Hors-ligne', style: TextStyle(fontSize: 13)),
                subtitle: const Text('Test de résilience sans réseau', style: TextStyle(fontSize: 11)),
                value: _colisService.simulerHorsLigne,
                activeThumbColor: AppColors.warningOrange,
                onChanged: (val) {
                  _colisService.basculerModeReseau(val);
                  setModalState(() {});
                  setState(() {});
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fermer'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.sync),
              label: const Text('Synchroniser maintenant'),
              onPressed: () async {
                final navigator = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                final nb = await _colisService.synchroniserFileAttente();
                navigator.pop();
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.successGreen,
                      content: Text('$nb colis synchronisé(s) vers le cloud !'),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _dialogRechercheRapide() {
    final searchCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.search, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Retrouver un Colis'),
          ],
        ),
        content: TextField(
          controller: searchCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Code TRX, tél, nom destinataire...',
            prefixIcon: Icon(Icons.qr_code),
          ),
          onSubmitted: (code) {
            Navigator.pop(ctx);
            _ouvrirDetailColis(code);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _ouvrirDetailColis(searchCtrl.text);
            },
            child: const Text('Rechercher'),
          ),
        ],
      ),
    );
  }

  void _ouvrirDetailColis(String code) {
    if (code.trim().isEmpty) return;
    final colis = _colisService.trouverParCode(code);
    if (colis != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ColisDetailScreen(colisCode: colis.trackingNumber),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.dangerRed,
          content: Text('Aucun colis trouvé avec le code "$code"'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentAgency = _authService.currentAgency;
    final currentMember = _authService.currentMember;

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _dialogChangerAgence,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          currentAgency?.name ?? 'Trans-Colis 237',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down, size: 20),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade800,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'DÉMO LOCALE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${currentMember?.fullName ?? "Agent"} • ${currentMember?.roleLabel ?? "Guichet"}',
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          SyncHeaderPill(
            isHorsLigne: _colisService.simulerHorsLigne,
            countPending: _colisService.nombreEnAttenteSync,
            onTap: _dialogGestionSync,
          ),
          const SizedBox(width: 6),
          const NotificationBellButton(),
          const SizedBox(width: 6),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                color: AppColors.headerNavy,
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Text(
                  currentAgency?.code ?? 'TC',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              accountName: Text(
                currentAgency?.name ?? 'ColisTrack Cameroun',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              accountEmail: Text(
                '${currentMember?.fullName ?? "Agent"} (${currentMember?.roleLabel ?? "Agent"})',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz_outlined),
              title: const Text('Changer d\'Agence'),
              subtitle: Text(currentAgency?.name ?? 'Sélectionner'),
              onTap: () {
                Navigator.pop(context);
                _dialogChangerAgence();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.assignment_outlined, color: AppColors.warningOrange),
              title: const Text('Feuille de Route Chauffeur'),
              subtitle: const Text('Manifeste de voyage & bordereau'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ManifesteVoyageScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.trending_up, color: AppColors.successGreen),
              title: const Text('Simulateur Rentabilité SaaS'),
              subtitle: const Text('Gains par colis & ROI agence'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RentabiliteScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud_sync_outlined, color: AppColors.primary),
              title: const Text('Gestion Synchronisation Cloud'),
              subtitle: Text('${_colisService.nombreEnAttenteSync} colis en attente'),
              onTap: () {
                Navigator.pop(context);
                _dialogGestionSync();
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
              title: Text(isDark ? 'Passer au Mode Clair' : 'Passer au Mode Sombre'),
              onTap: () {
                TransColisApp.of(context)?.toggleTheme();
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('À propos de ColisTrack V2'),
              subtitle: const Text('Version 2.0.0 SaaS Multi-Agences'),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'ColisTrack Cameroun',
                  applicationVersion: '2.0.0',
                  applicationLegalese: '© 2026 ColisTrack - Fret & Colis Interurbains',
                );
              },
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 3 BOUTONS D'ACTIONS PRIORITAIRES (PRINCIPE NON NÉGOCIABLE)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  // Action 1 : Nouveau Colis
                  Expanded(
                    child: _buildPriorityActionCard(
                      icon: Icons.add_box_rounded,
                      color: AppColors.primary,
                      title: 'Nouveau Colis',
                      subtitle: '< 1 minute',
                      onTap: widget.onNouveauColis,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Action 2 : Retrouver Colis
                  Expanded(
                    child: _buildPriorityActionCard(
                      icon: Icons.search_rounded,
                      color: AppColors.trackingTeal,
                      title: 'Retrouver',
                      subtitle: 'Recherche TRX',
                      onTap: _dialogRechercheRapide,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Action 3 : Scanner Colis
                  Expanded(
                    child: _buildPriorityActionCard(
                      icon: Icons.qr_code_scanner_rounded,
                      color: AppColors.warningOrange,
                      title: 'Scanner',
                      subtitle: 'Embarquer/Retirer',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ScannerTransitScreen(
                              onOuvrirSuivi: (code) => _ouvrirDetailColis(code),
                            ),
                          ),
                        );
                      },
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),

            // BANDEAU RECETTES & STATISTIQUES GUICHET
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.headerNavy,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'RECETTES GUICHET EN COURS',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _colisService.currencyFormat.format(_colisService.totalRecettesFcfa),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        _miniKpi(
                          label: 'En Transit',
                          value: '${_colisService.colisEnTransit}',
                          icon: Icons.local_shipping,
                          color: AppColors.trackingTeal,
                        ),
                        const SizedBox(width: 8),
                        _miniKpi(
                          label: 'À Retirer',
                          value: '${_colisService.colisEnAttenteRetrait}',
                          icon: Icons.warehouse,
                          color: AppColors.momoYellow,
                        ),
                        const SizedBox(width: 8),
                        _miniKpi(
                          label: 'Livrés',
                          value: '${_colisService.colisLivres}',
                          icon: Icons.check_circle,
                          color: AppColors.successGreen,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // BARRE DE RECHERCHE RAPIDE EN TEMPS RÉEL
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Filtrer par TRX, nom, ville, tél...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),

            // FILTRES STATUTS
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _filterChip('Tous (${_colisService.totalColis})', 'TOUS', isDark),
                  _filterChip('En transit (${_colisService.colisEnTransit})', 'TRANSIT', isDark),
                  _filterChip('Prêts au retrait (${_colisService.colisEnAttenteRetrait})', 'ARRIVE', isDark),
                  _filterChip('Livrés (${_colisService.colisLivres})', 'LIVRE', isDark),
                  _filterChip('Cash on Deliv. (${_colisService.colisCashOnDelivery})', 'COD', isDark),
                ],
              ),
            ),

            // LISTE DES COLIS RÉCENTS
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _colisFiltres.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 52,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Aucun colis trouvé pour cette sélection.',
                              style: TextStyle(
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _colisFiltres.length,
                      itemBuilder: (context, index) {
                        final colis = _colisFiltres[index];
                        return _buildColisCard(colis, isDark);
                      },
                    ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Nouveau Colis', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: widget.onNouveauColis,
      ),
    );
  }

  Widget _buildPriorityActionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.20 : 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color,
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isDark ? Colors.white : color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniKpi({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 8),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String code, bool isDark) {
    final isSelected = _filtreStatut == code;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: isDark
            ? AppColors.darkBorder
            : AppColors.primary.withValues(alpha: 0.15),
        labelStyle: TextStyle(
          color: isSelected
              ? (isDark ? Colors.white : AppColors.primary)
              : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 11,
        ),
        checkmarkColor: isDark ? Colors.white : AppColors.primary,
        onSelected: (_) => setState(() => _filtreStatut = code),
      ),
    );
  }

  Widget _buildColisCard(Colis colis, bool isDark) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ColisDetailScreen(colisCode: colis.trackingNumber),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ligne 1 : Tracking Code + Badges
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    colis.trackingNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.8,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Row(
                    children: [
                      SyncStatusBadge(status: colis.syncStatus, compact: true),
                      const SizedBox(width: 6),
                      ColisStatusBadge(statut: colis.statut),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Trajet
              Row(
                children: [
                  const Icon(Icons.trip_origin, size: 12, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    colis.villeDepart,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      Icons.arrow_forward,
                      size: 12,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                  const Icon(Icons.location_on, size: 12, color: AppColors.dangerRed),
                  const SizedBox(width: 4),
                  Text(
                    colis.villeArrivee,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  const Spacer(),
                  Text(
                    _colisService.currencyFormat.format(colis.prixTransportFcfa),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.successGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Destinataire + Type
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Dest. : ${colis.destinataireNom} (${colis.destinataireTel})',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  if (colis.estContreRemboursement)
                    const LogisticsFeatureBadge(
                      icon: Icons.shopping_bag_outlined,
                      label: 'COD',
                      color: AppColors.codPurple,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
