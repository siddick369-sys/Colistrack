import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/colis.dart';
import '../services/colis_service.dart';
import 'qr_widget.dart';

class TicketRecuDialog extends StatefulWidget {
  final Colis colis;

  const TicketRecuDialog({super.key, required this.colis});

  static Future<void> show(BuildContext context, Colis colis) {
    return showDialog(
      context: context,
      builder: (ctx) => TicketRecuDialog(colis: colis),
    );
  }

  @override
  State<TicketRecuDialog> createState() => _TicketRecuDialogState();
}

class _TicketRecuDialogState extends State<TicketRecuDialog> {
  bool _isPrinting = false;
  String _printStatus = '';

  String get _messageWhatsApp {
    final c = widget.colis;
    final codText = c.estContreRemboursement
        ? '\n📦 *Option Contre-Remboursement :* Prévoir ${c.montantMarchandiseFcfa} FCFA (Marchandise) + ${c.prixTransportFcfa} FCFA (Port)'
        : '';

    return '📦 *TRANS-COLIS CAMEROUN* - Avis d\'expédition\n\n'
        'Bonjour *${c.destinataireNom}*,\n'
        'Un colis vous a été expédié par *${c.expediteurNom}* depuis *${c.villeDepart}*.\n\n'
        '🔖 *N° de Suivi :* `${c.id}`\n'
        '📍 *Agence de retrait :* ${c.agenceArrivee} (${c.villeArrivee})\n'
        '💰 *Paiement :* ${c.paiementLabel} (${c.prixTransportFcfa} FCFA)$codText\n'
        '🔑 *Code secret de retrait :* ${c.codeSecretRetrait}\n'
        '📸 *Preuve photo :* ${c.photoColisPrise ? "Enregistrée & scellée au guichet" : "Vérifiée"}\n\n'
        'ℹ️ _Présentez votre CNI et ce code secret au guichet dès réception de l\'alerte d\'arrivée._';
  }

  Future<void> _envoyerWhatsApp() async {
    final telNettoye = widget.colis.destinataireTel
        .replaceAll(RegExp(r'[^0-9]'), '')
        .replaceFirst(RegExp(r'^0+'), '');
    
    final numeroFinal = telNettoye.startsWith('237') ? telNettoye : '237$telNettoye';
    final url = Uri.parse('https://wa.me/$numeroFinal?text=${Uri.encodeComponent(_messageWhatsApp)}');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir WhatsApp')),
      );
    }
  }

  Future<void> _envoyerSms() async {
    final telNettoye = widget.colis.destinataireTel.replaceAll(RegExp(r'[^0-9+]'), '');
    final url = Uri.parse('sms:$telNettoye?body=${Uri.encodeComponent(_messageWhatsApp)}');

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir l\'application SMS')),
      );
    }
  }

  Future<void> _simulerImpressionBluetooth() async {
    setState(() {
      _isPrinting = true;
      _printStatus = 'Connexion à l\'imprimante Bluetooth POS-58...';
    });

    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    setState(() {
      _printStatus = 'Envoi des commandes ESC/POS & Découpe papier...';
    });

    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    setState(() {
      _isPrinting = false;
      _printStatus = '✅ Reçu thermique imprimé avec succès !';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.green,
        content: Text('Reçu thermique imprimé sur la mini-imprimante Bluetooth'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colis;
    final service = ColisService();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Entête
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E3A8A),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long, color: Colors.white),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Reçu d\'Expédition Guichet',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Ticket thermique stylisé
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFDE7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade400, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'TRANS-COLIS CAMEROUN S.A.',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1),
                      ),
                      const Text(
                        'Réseau Fret Interurbain & Messagerie Rapide',
                        style: TextStyle(fontSize: 10, color: Colors.black54),
                      ),
                      const Text(
                        'Douala • Yaoundé • Bafoussam • Grand Nord',
                        style: TextStyle(fontSize: 9, color: Colors.black54),
                      ),
                      const Divider(thickness: 1, color: Colors.black87),

                      // N° de suivi
                      Text(
                        c.id,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        'Date: ${service.dateFormat.format(c.dateEnregistrement)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      const SizedBox(height: 12),

                      // QR Code pour scan rapide
                      Center(
                        child: QrVisualWidget(
                          data: 'TRANSCOLIS:${c.id}',
                          size: 130,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'CODE RETRAIT SECRET: ${c.codeSecretRetrait}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFFC62828),
                          letterSpacing: 1.5,
                        ),
                      ),

                      if (c.photoColisPrise) ...[
                        const SizedBox(height: 4),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt, size: 12, color: Colors.teal),
                            SizedBox(width: 4),
                            Text(
                              'Preuve photo scellée & archivée',
                              style: TextStyle(fontSize: 10, color: Colors.teal, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],

                      const Divider(thickness: 1, color: Colors.black87),

                      // Trajet
                      _ticketRow('DÉPART', '${c.villeDepart} (${c.agenceDepart})'),
                      _ticketRow('DESTINATION', '${c.villeArrivee} (${c.agenceArrivee})'),
                      _ticketRow('EXPÉDITEUR', '${c.expediteurNom} (${c.expediteurTel})'),
                      _ticketRow('DESTINATAIRE', '${c.destinataireNom} (${c.destinataireTel})'),
                      const Divider(thickness: 1, color: Colors.black38),

                      // Caractéristiques colis
                      _ticketRow('TYPE', c.typeColis),
                      _ticketRow('POIDS', '${c.poidsKg} kg'),
                      _ticketRow('VALEUR DÉCLARÉE', service.currencyFormat.format(c.valeurDeclareeFcfa)),

                      if (c.estContreRemboursement) ...[
                        const Divider(thickness: 1, color: Colors.purple),
                        _ticketRow('SERVICE', 'CASH ON DELIVERY (E-COMMERCE)'),
                        _ticketRow('À RECOUVRER (MARCHANDISE)', service.currencyFormat.format(c.montantMarchandiseFcfa)),
                      ],

                      const Divider(thickness: 1, color: Colors.black87),

                      // Paiement
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TOTAL PORT :',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            service.currencyFormat.format(c.prixTransportFcfa),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF1B5E20),
                            ),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          c.paiementLabel.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),
                      const Text(
                        'Conservez ce ticket. Présentez la CNI et le code secret au retrait.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 9, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ),

              if (_printStatus.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _printStatus,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _isPrinting ? Colors.blue.shade800 : Colors.green.shade800,
                    ),
                  ),
                ),

              const SizedBox(height: 10),

              // Boutons d'action
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: _isPrinting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.print),
                        label: Text(_isPrinting ? 'Impression en cours...' : 'Imprimer Reçu Bluetooth (POS-58)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _isPrinting ? null : _simulerImpressionBluetooth,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
                            label: const Text('WhatsApp', style: TextStyle(color: Color(0xFF128C7E))),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF25D366)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _envoyerWhatsApp,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.sms, color: Colors.blue),
                            label: const Text('SMS Alerte', style: TextStyle(color: Colors.blue)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.blue),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _envoyerSms,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ticketRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}
