import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/colis.dart';
import '../services/auth_service.dart';
import '../services/colis_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_badges.dart';
import '../widgets/qr_widget.dart';
import '../widgets/ticket_recu_dialog.dart';
import 'tracking_client_screen.dart';

/// Écran universel de détail et de transition d'état d'un colis
/// Présente l'état courant, l'historique et uniquement la PROCHAINE action autorisée.
class ColisDetailScreen extends StatefulWidget {
  final String colisCode;

  const ColisDetailScreen({super.key, required this.colisCode});

  @override
  State<ColisDetailScreen> createState() => _ColisDetailScreenState();
}

class _ColisDetailScreenState extends State<ColisDetailScreen> {
  final ColisService _service = ColisService();
  final AuthService _auth = AuthService();
  Colis? _colis;

  // Contrôleurs pour les actions d'embarquement / retrait
  final _busCtrl = TextEditingController(text: 'LT 894 CE (Buca VIP)');
  final _chauffeurCtrl = TextEditingController(text: 'M. Talla Paul');
  final _otpCtrl = TextEditingController();
  final _cniCtrl = TextEditingController(text: '102938475');
  bool _cniScanValide = false;

  @override
  void initState() {
    super.initState();
    _chargerColis();
    _service.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceUpdate);
    _busCtrl.dispose();
    _chauffeurCtrl.dispose();
    _otpCtrl.dispose();
    _cniCtrl.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) _chargerColis();
  }

  void _chargerColis() {
    setState(() {
      _colis = _service.trouverParCode(widget.colisCode);
      if (_colis != null) {
        if (_colis!.matriculeBus != null) _busCtrl.text = _colis!.matriculeBus!;
        if (_colis!.chauffeurNom != null) _chauffeurCtrl.text = _colis!.chauffeurNom!;
        if (_colis!.cniDestinataireNumero != null) _cniCtrl.text = _colis!.cniDestinataireNumero!;
        _cniScanValide = _colis!.cniScanEffectue;
      }
    });
  }

  Future<void> _copierTexte(String texte, String label) async {
    await Clipboard.setData(ClipboardData(text: texte));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primary,
          content: Text('$label copié dans le presse-papier'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _partagerWhatsApp(Colis colis) async {
    final message = '''*COLISTRACK CAMEROUN - REÇU D'EXPÉDITION*
📦 *Suivi N° :* ${colis.trackingNumber}
🏢 *Agence :* ${_auth.agencyName}
📍 *Trajet :* ${colis.villeDepart} ➔ ${colis.villeArrivee}
👤 *Destinataire :* ${colis.destinataireNom}
🔑 *Code de retrait secret :* ${colis.codeSecretRetrait}
💰 *Frais de transport :* ${_service.currencyFormat.format(colis.prixTransportFcfa)} (${colis.paiementLabel})
${colis.estContreRemboursement ? '🛍️ *Montant COD à payer au retrait :* ${_service.currencyFormat.format(colis.montantMarchandiseFcfa)}\n' : ''}
🔗 *Suivre en ligne :* https://colisTrack.cm/track/${colis.trackingNumber}
''';

    final uri = Uri.parse(
        'whatsapp://send?phone=${colis.destinataireTel.replaceAll(RegExp(r'[^0-9+]'), '')}&text=${Uri.encodeComponent(message)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await _copierTexte(message, 'Message de reçu');
      }
    } catch (_) {
      await _copierTexte(message, 'Message de reçu');
    }
  }

  Future<void> _partagerSms(Colis colis) async {
    final message =
        'ColisTrack: Colis ${colis.trackingNumber} (${colis.statutLabel}). Retrait au ${colis.guichetRetrait} (${colis.agenceArrivee}). Code secret: ${colis.codeSecretRetrait}.';
    final uri = Uri.parse(
        'sms:${colis.destinataireTel.replaceAll(RegExp(r'[^0-9+]'), '')}?body=${Uri.encodeComponent(message)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await _copierTexte(message, 'Message SMS');
      }
    } catch (_) {
      await _copierTexte(message, 'Message SMS');
    }
  }

  void _dialogEmbarquement(Colis colis) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.directions_bus, color: AppColors.warningOrange),
            SizedBox(width: 8),
            Text('Embarquer dans le car'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _busCtrl,
              decoration: const InputDecoration(
                labelText: 'Matricule & Ligne du Bus',
                prefixIcon: Icon(Icons.confirmation_number_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _chauffeurCtrl,
              decoration: const InputDecoration(
                labelText: 'Nom du Chauffeur / Responsable',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Confirmer l\'embarquement'),
            onPressed: () async {
              Navigator.pop(ctx);
              await _service.mettreAJourStatut(
                colisId: colis.id,
                nouveauStatut: StatutColis.chargeBus,
                matriculeBus: _busCtrl.text.trim(),
                chauffeurNom: _chauffeurCtrl.text.trim(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _dialogRetrait(Colis colis) {
    _otpCtrl.clear();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.how_to_reg, color: AppColors.successGreen),
              SizedBox(width: 8),
              Text('Délivrance au Destinataire'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (colis.estContreRemboursement) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.codPurple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.codPurple.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.monetization_on, color: AppColors.codPurple),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Paiement COD à percevoir : ${_service.currencyFormat.format(colis.montantMarchandiseFcfa)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                const Text(
                  '1. Code Secret Client (4 chiffres) *',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 8),
                  decoration: const InputDecoration(
                    hintText: '••••',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  '2. Pièce d\'Identité (CNI / Passeport / Récépissé) *',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _cniCtrl,
                        decoration: const InputDecoration(
                          hintText: 'N° de CNI',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Scanner la CNI par OCR',
                      icon: Icon(_cniScanValide ? Icons.verified : Icons.document_scanner),
                      onPressed: () {
                        setModalState(() {
                          _cniScanValide = true;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: AppColors.trackingTeal,
                            content: Text('🛂 CNI scannée & validée par OCR !'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Valider le Retrait'),
              onPressed: () async {
                final codeSaisi = _otpCtrl.text.trim();
                if (codeSaisi != colis.codeSecretRetrait) {
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
                      content: Text('⚠️ Numéro de CNI obligatoire pour l\'archivage légal.'),
                    ),
                  );
                  return;
                }
                final navigator = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                navigator.pop();
                final succes = await _service.mettreAJourStatut(
                  colisId: colis.id,
                  nouveauStatut: StatutColis.retire,
                  cniNumero: _cniCtrl.text.trim(),
                  cniScanEffectue: _cniScanValide,
                  codeOtp: codeSaisi,
                );
                if (mounted) {
                  if (succes) {
                    messenger.showSnackBar(
                      const SnackBar(
                        backgroundColor: AppColors.successGreen,
                        content: Text('🎉 Colis retiré avec succès et CNI archivée !'),
                      ),
                    );
                  } else {
                    messenger.showSnackBar(
                      const SnackBar(
                        backgroundColor: AppColors.dangerRed,
                        content: Text('❌ Retrait refusé : code secret invalide ou colis non prêt au retrait.'),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextActionButton(Colis colis) {
    switch (colis.statut) {
      case StatutColis.enregistre:
        return FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.warningOrange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: const Icon(Icons.directions_bus),
          label: const Text(
            '1. Embarquer dans le car',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          onPressed: () => _dialogEmbarquement(colis),
        );

      case StatutColis.chargeBus:
        return FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.trackingTeal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: const Icon(Icons.alt_route),
          label: const Text(
            '2. Confirmer le départ en transit',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          onPressed: () async {
            await _service.mettreAJourStatut(
              colisId: colis.id,
              nouveauStatut: StatutColis.enTransit,
              note: 'Car en route vers ${colis.villeArrivee}',
            );
          },
        );

      case StatutColis.enTransit:
        return FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: const Icon(Icons.warehouse),
          label: const Text(
            '3. Réceptionner à l\'agence d\'arrivée',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          onPressed: () async {
            await _service.mettreAJourStatut(
              colisId: colis.id,
              nouveauStatut: StatutColis.arriveDestination,
              note: 'Colis disponible au ${colis.guichetRetrait}',
            );
          },
        );

      case StatutColis.arriveDestination:
        return FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.successGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: const Icon(Icons.how_to_reg),
          label: const Text(
            '4. Valider le Retrait Client (Code OTP + CNI)',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          onPressed: () => _dialogRetrait(colis),
        );

      case StatutColis.retire:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.successGreen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.successGreen.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified, color: AppColors.successGreen, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Colis Clôturé & Livré',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.successGreen,
                      ),
                    ),
                    Text(
                      'CNI Archivée : ${colis.cniDestinataireNumero ?? 'Vérifiée'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colis = _colis;

    if (colis == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Colis introuvable')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text('Aucun colis avec le code "${widget.colisCode}"'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Retour'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(colis.trackingNumber),
        actions: [
          IconButton(
            tooltip: 'Imprimer / Reçu Thermique',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => TicketRecuDialog.show(context, colis),
          ),
          IconButton(
            tooltip: 'Vue Suivi Public Client',
            icon: const Icon(Icons.remove_red_eye_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TrackingClientScreen(initialCode: colis.trackingNumber),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // CARTE PRINCIPALE : EN-TÊTE DU COLIS
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    colis.trackingNumber,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy, size: 16),
                                    tooltip: 'Copier le numéro de suivi',
                                    onPressed: () =>
                                        _copierTexte(colis.trackingNumber, 'Numéro de suivi'),
                                  ),
                                ],
                              ),
                              Text(
                                'Réf interne : ${colis.id}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        QrVisualWidget(
                          data: 'TRANSCOLIS:${colis.trackingNumber}',
                          size: 64,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ColisStatusBadge(statut: colis.statut),
                        SyncStatusBadge(status: colis.syncStatus),
                        if (colis.photoColisPrise)
                          const LogisticsFeatureBadge(
                            icon: Icons.camera_alt_outlined,
                            label: 'Photo Scellée',
                            color: AppColors.trackingTeal,
                          ),
                        if (colis.estContreRemboursement)
                          LogisticsFeatureBadge(
                            icon: Icons.shopping_bag_outlined,
                            label: 'COD (${_service.currencyFormat.format(colis.montantMarchandiseFcfa)})',
                            color: AppColors.codPurple,
                          ),
                      ],
                    ),
                    const Divider(height: 24),

                    // ITINÉRAIRE
                    Row(
                      children: [
                        const Icon(Icons.circle, size: 12, color: AppColors.primaryBlue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${colis.villeDepart} (${colis.agenceDepart})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 5, top: 2, bottom: 2),
                      child: Container(
                        width: 2,
                        height: 18,
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 14, color: AppColors.dangerRed),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${colis.villeArrivee} (${colis.agenceArrivee})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // BOUTON ACTION RAPIDE ÉTAPE SUIVANTE
            _buildNextActionButton(colis),

            const SizedBox(height: 16),

            // CONTACTS & SÉCURITÉ
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
                    const Text(
                      'Acteurs & Contacts',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 16,
                          child: Icon(Icons.person, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Destinataire : ${colis.destinataireNom}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              Text(
                                colis.destinataireTel,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.transparent,
                          child: Icon(Icons.outbox, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Expéditeur : ${colis.expediteurNom}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              Text(
                                colis.expediteurTel,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Code Secret Retrait', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            Text(
                              colis.codeSecretRetrait,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Frais de Transport', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            Text(
                              _service.currencyFormat.format(colis.prixTransportFcfa),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.successGreen,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // BARRE D'ACTIONS DE PARTAGE (WhatsApp / SMS / Reçu)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFF25D366)),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF25D366)),
                    label: const Text('WhatsApp', style: TextStyle(color: Color(0xFF25D366))),
                    onPressed: () => _partagerWhatsApp(colis),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.sms_outlined),
                    label: const Text('SMS'),
                    onPressed: () => _partagerSms(colis),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // HISTORIQUE CHRONOLOGIQUE
            const Text(
              'Historique d\'Expédition & Traçabilité',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: colis.historique.length,
              itemBuilder: (context, index) {
                final etape = colis.historique[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          if (index < colis.historique.length - 1)
                            Container(
                              width: 2,
                              height: 48,
                              color: Colors.grey.withValues(alpha: 0.3),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  etape.titre,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(
                                  _service.dateFormat.format(etape.date),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              etape.description,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                            if (etape.lieu.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  '📍 ${etape.lieu}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.primaryBlue),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
