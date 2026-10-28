import 'package:flutter/material.dart';

class PushMomoDialog extends StatelessWidget {
  final int montantFcfa;
  final String telephoneClient;
  final String nomClient;
  final String operateur; // 'MTN MoMo' ou 'Orange Money'
  final VoidCallback? onPaiementReussi;
  final VoidCallback? onEnregistrerEnAttente;

  const PushMomoDialog({
    super.key,
    required this.montantFcfa,
    required this.telephoneClient,
    required this.nomClient,
    required this.operateur,
    this.onPaiementReussi,
    this.onEnregistrerEnAttente,
  });

  static Future<void> show({
    required BuildContext context,
    required int montantFcfa,
    required String telephoneClient,
    required String nomClient,
    required String operateur,
    VoidCallback? onPaiementReussi,
    VoidCallback? onEnregistrerEnAttente,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PushMomoDialog(
        montantFcfa: montantFcfa,
        telephoneClient: telephoneClient,
        nomClient: nomClient,
        operateur: operateur,
        onPaiementReussi: onPaiementReussi,
        onEnregistrerEnAttente: onEnregistrerEnAttente,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMtn = operateur.contains('MTN');
    final Color couleurOperateur = isMtn ? const Color(0xFFFFCC00) : const Color(0xFFFF6600);
    final Color couleurTexte = isMtn ? Colors.black87 : Colors.white;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Badge opérateur
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: couleurOperateur,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.phone_android, size: 18, color: couleurTexte),
                  const SizedBox(width: 8),
                  Text(
                    operateur.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: couleurTexte,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Débit Direct : $montantFcfa FCFA',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Client : $nomClient ($telephoneClient)',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),

            const SizedBox(height: 20),

            // Encadré informatif : Absence de passerelle en local
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade400, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'PASSERELLE DISTANTE DÉCONNECTÉE',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.brown),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Aucun opérateur bancaire n\'est connecté dans cet environnement prototype local. '
                    'Le paiement Mobile Money ne peut pas être débité ni validé automatiquement sans passerelle externe.',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Option recommandée : enregistrer le colis avec statut « En attente / À payer au retrait » '
                    'ou encaisser le montant de $montantFcfa FCFA en espèces au guichet.',
                    style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade800),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Boutons d'action
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.schedule_send_outlined),
                label: const Text('Enregistrer en Attente (Non encaissé)'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  onEnregistrerEnAttente?.call();
                },
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler (Choisir Espèces au guichet)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
