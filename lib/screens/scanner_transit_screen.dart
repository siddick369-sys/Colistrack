import 'package:flutter/material.dart';
import '../models/colis.dart';
import '../services/colis_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_badges.dart';
import '../widgets/qr_widget.dart';
import 'colis_detail_screen.dart';

class ScannerTransitScreen extends StatefulWidget {
  final Function(String code) onOuvrirSuivi;

  const ScannerTransitScreen({super.key, required this.onOuvrirSuivi});

  @override
  State<ScannerTransitScreen> createState() => _ScannerTransitScreenState();
}

class _ScannerTransitScreenState extends State<ScannerTransitScreen> {
  final ColisService _service = ColisService();
  final TextEditingController _codeController = TextEditingController();
  Colis? _colisSelectionne;

  // Formulaire d'action
  final _busCtrl = TextEditingController(text: 'LT 894 CE (Buca VIP)');
  final _chauffeurCtrl = TextEditingController(text: 'M. Talla Paul');
  final _codeOtpCtrl = TextEditingController();
  final _cniCtrl = TextEditingController(text: '102938475');
  bool _cniScanValide = false;

  @override
  void dispose() {
    _codeController.dispose();
    _busCtrl.dispose();
    _chauffeurCtrl.dispose();
    _codeOtpCtrl.dispose();
    _cniCtrl.dispose();
    super.dispose();
  }

  void _rechercherColis(String code) {
    final colis = _service.trouverParCode(code);
    setState(() {
      _colisSelectionne = colis;
      if (colis != null) {
        _busCtrl.text = colis.matriculeBus ?? 'LT 894 CE (Buca VIP)';
        _chauffeurCtrl.text = colis.chauffeurNom ?? 'M. Talla Paul';
        _cniCtrl.text = colis.cniDestinataireNumero ?? '102938475';
        _cniScanValide = colis.cniScanEffectue;
      }
    });

    if (colis == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.dangerRed,
          content: Text('Aucun colis trouvé avec le code "$code"'),
        ),
      );
    }
  }

  void _simulerScanCni() {
    setState(() {
      _cniScanValide = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.trackingTeal,
        content: Text('🛂 CNI / Récépissé scanné & extrait par OCR avec succès !'),
      ),
    );
  }

  Future<void> _appliquerNouveauStatut(StatutColis nouveauStatut) async {
    if (_colisSelectionne == null) return;

    // Si retrait, vérifier le code secret et la CNI (Contrôle légal strict)
    if (nouveauStatut == StatutColis.retire) {
      final codeSaisi = _codeOtpCtrl.text.trim();
      if (codeSaisi != _colisSelectionne!.codeSecretRetrait) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.dangerRed,
            content: Text('❌ Code secret incorrect ! Le colis ne peut pas être remis.'),
          ),
        );
        return;
      }

      if (_cniCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.warningOrange,
            content: Text(
                '⚠️ Veuillez renseigner ou scanner le numéro de CNI du destinataire (Exigence légale).'),
          ),
        );
        return;
      }
    }

    final succes = await _service.mettreAJourStatut(
      colisId: _colisSelectionne!.id,
      nouveauStatut: nouveauStatut,
      matriculeBus: _busCtrl.text.trim(),
      chauffeurNom: _chauffeurCtrl.text.trim(),
      cniNumero: _cniCtrl.text.trim(),
      cniScanEffectue: _cniScanValide,
      codeOtp: nouveauStatut == StatutColis.retire ? _codeOtpCtrl.text.trim() : null,
    );

    if (!mounted) return;

    if (succes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.successGreen,
          content: Text('Statut mis à jour : ${_colisSelectionne!.statutLabel}'),
        ),
      );

      setState(() {
        _codeOtpCtrl.clear();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.dangerRed,
          content: Text('❌ Échec de la mise à jour : transition interdite ou code OTP incorrect.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner & Gestion Opérateur'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Saisie / Scan rapide
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.qr_code_scanner_outlined,
                            color: AppColors.primaryBlue, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Scan Caméra / Saisie Code Colis',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Lecture du QR code pour chargement ou retrait',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _codeController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Code de suivi (ex: CE-DLA-YDE-8921)',
                              prefixIcon: Icon(Icons.tag_outlined),
                            ),
                            onSubmitted: _rechercherColis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.search, size: 18),
                          label: const Text('Valider'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 15),
                          ),
                          onPressed: () => _rechercherColis(_codeController.text),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Raccourcis colis récents
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _service.allColis.take(3).map((c) {
                        return ActionChip(
                          avatar: const Icon(Icons.inventory_2_outlined, size: 14),
                          label: Text(
                            c.id,
                            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                          ),
                          onPressed: () {
                            _codeController.text = c.id;
                            _rechercherColis(c.id);
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (_colisSelectionne != null) ...[
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _colisSelectionne!.trackingNumber,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_colisSelectionne!.villeDepart} ➔ ${_colisSelectionne!.villeArrivee}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          QrVisualWidget(
                            data: 'TRANSCOLIS:${_colisSelectionne!.trackingNumber}',
                            size: 65,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Bouton Fiche Universelle
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Ouvrir la fiche universelle & traçabilité'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ColisDetailScreen(
                                colisCode: _colisSelectionne!.trackingNumber,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),

                      // Badge statut
                      ColisStatusBadge(statut: _colisSelectionne!.statut),

                      // Alerte Cash on Delivery si activé
                      if (_colisSelectionne!.estContreRemboursement) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.codPurple.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.codPurple.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.shopping_bag_outlined,
                                  color: AppColors.codPurple),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'COLIS EN CONTRE-REMBOURSEMENT (E-COMMERCE)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        color: AppColors.codPurple,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Encaisser au retrait : ${_service.currencyFormat.format(_colisSelectionne!.montantTotalARecouvrer)} (Marchandise + Port)',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      'Reversement vendeur MoMo : ${_service.currencyFormat.format(_colisSelectionne!.montantAReverserVendeur)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Preuve photo affichée
                      if (_colisSelectionne!.photoColisPrise) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.check_circle_outline,
                                color: AppColors.trackingTeal, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Preuve photo guichet vérifiée : ${_colisSelectionne!.photoColisDescription ?? "Scellé"}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.trackingTeal,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const Divider(height: 24),

                      // Actions de transit
                      const Text(
                        'ACTIONS OPÉRATEUR SUR LE TERRAIN :',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 10),

                      ElevatedButton.icon(
                        icon: const Icon(Icons.directions_bus_outlined),
                        label: const Text('1. Charger dans le car'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.warningOrange,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 44),
                        ),
                        onPressed: () =>
                            _appliquerNouveauStatut(StatutColis.chargeBus),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.alt_route_outlined),
                        label: const Text('2. Confirmer "En route / Transit"'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 44),
                        ),
                        onPressed: () =>
                            _appliquerNouveauStatut(StatutColis.enTransit),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.warehouse_outlined),
                        label: const Text('3. Décharger à destination (Prêt au Retrait)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.trackingTeal,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 44),
                        ),
                        onPressed: () =>
                            _appliquerNouveauStatut(StatutColis.arriveDestination),
                      ),

                      const Divider(height: 28),

                      // RETRAIT SÉCURISÉ + CNI ARCHIVAGE (Feature 2)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurface
                              : AppColors.dangerRed.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.dangerRed.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.security, color: AppColors.dangerRed, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Validation Retrait & Archivage CNI (Légal)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppColors.dangerRed,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Code secret exigé au guichet : ${_colisSelectionne!.codeSecretRetrait}',
                              style: TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Champ CNI avec bouton scan caméra
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _cniCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'N° CNI ou Récépissé',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  icon: Icon(
                                      _cniScanValide
                                          ? Icons.check
                                          : Icons.camera_alt_outlined,
                                      size: 16),
                                  label: Text(_cniScanValide ? 'CNI OK' : 'Scan CNI'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _cniScanValide
                                        ? AppColors.successGreen
                                        : AppColors.trackingTeal,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: _simulerScanCni,
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Champ Code Secret
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _codeOtpCtrl,
                                    keyboardType: TextInputType.number,
                                    maxLength: 4,
                                    decoration: const InputDecoration(
                                      counterText: '',
                                      labelText: 'Code secret 4 chiffres',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.dangerRed,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                  ),
                                  onPressed: () =>
                                      _appliquerNouveauStatut(StatutColis.retire),
                                  child: const Text('Confirmer Retrait'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
