import 'package:flutter/material.dart';
import '../services/colis_service.dart';
import '../theme/app_colors.dart';

class ManifesteVoyageScreen extends StatefulWidget {
  const ManifesteVoyageScreen({super.key});

  @override
  State<ManifesteVoyageScreen> createState() => _ManifesteVoyageScreenState();
}

class _ManifesteVoyageScreenState extends State<ManifesteVoyageScreen> {
  final ColisService _service = ColisService();
  String _busSelectionne = 'LT 894 CE (Buca VIP)';
  String _villeDepart = 'Douala';
  String _villeArrivee = 'Yaoundé';
  final String _nomChauffeur = 'M. Talla Paul (Permis D n° 9821/LT)';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colisDuBus = _service.getColisParBus(_busSelectionne);
    final int totalColis = colisDuBus.length;
    final double poidsTotal = colisDuBus.fold(0.0, (sum, c) => sum + c.poidsKg);
    final int valeurTotale =
        colisDuBus.fold(0, (sum, c) => sum + c.valeurDeclareeFcfa);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feuille de Route / Manifeste Chauffeur'),
        actions: [
          IconButton(
            tooltip: 'Imprimer / Exporter',
            icon: const Icon(Icons.print_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: AppColors.successGreen,
                  content: Text(
                      'Impression du Manifeste officiel pour le contrôle de route...'),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sélecteur de Bus et Itinéraire
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
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
                      'Paramètres du Voyage Routier :',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _busSelectionne,
                      decoration: const InputDecoration(
                        labelText: 'Véhicule / Car de Ligne',
                        prefixIcon: Icon(Icons.directions_bus_outlined),
                      ),
                      items: _service.matriculesBusActifs
                          .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _busSelectionne = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _villeDepart,
                            decoration: const InputDecoration(labelText: 'Origine'),
                            items: _service.villes
                                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                                .toList(),
                            onChanged: (v) => setState(() => _villeDepart = v!),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.arrow_forward),
                        ),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _villeArrivee,
                            decoration: const InputDecoration(labelText: 'Destination'),
                            items: _service.villes
                                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                                .toList(),
                            onChanged: (v) => setState(() => _villeArrivee = v!),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Document Officiel stylisé (Manifeste de Fret)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : Colors.black87,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // En-tête officiel
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'RÉPUBLIQUE DU CAMEROUN',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 1,
                            color: isDark ? AppColors.darkTextPrimary : Colors.black,
                          ),
                        ),
                        Text(
                          'Paix - Travail - Patrie\nMINISTÈRE DES TRANSPORTS',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.headerNavy,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'MANIFESTE OFFICIEL DE FRET ROUTIER (BORDEREAU DE SOUTE)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Date d\'émission : ${_service.dateFormat.format(DateTime.now())}',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(thickness: 1.5),

                  // Infos Chauffeur & Bus
                  _infoRow('COMPAGNIE', 'TRANS-COLIS CAMEROUN S.A.', isDark),
                  _infoRow('BUS MATRICULE', _busSelectionne, isDark),
                  _infoRow('CONDUCTEUR', _nomChauffeur, isDark),
                  _infoRow('TRAJET',
                      '$_villeDepart ➔ $_villeArrivee (Axe Lourd N3)', isDark),
                  const Divider(thickness: 1),

                  // Résumé Quantitatif pour Douane / Gendarmerie
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkBackground
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _resumeItem('TOTAL COLIS', '$totalColis colis',
                            Icons.inventory_2_outlined, isDark),
                        _resumeItem('POIDS EN SOUTE',
                            '${poidsTotal.toStringAsFixed(1)} kg',
                            Icons.scale_outlined, isDark),
                        _resumeItem('VALEUR DÉCLARÉE',
                            _service.currencyFormat.format(valeurTotale),
                            Icons.shield_outlined, isDark),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),
                  Text(
                    'DÉTAIL DES COLIS ENREGISTRÉS EN SOUTE :',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextPrimary : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Table des colis
                  if (colisDuBus.isEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          'Aucun colis rattaché à ce bus pour l\'instant.\nScannez des colis pour les affecter à ce car.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : Colors.black54,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    Table(
                      border: TableBorder.all(
                        color: isDark ? AppColors.darkBorder : Colors.grey.shade400,
                      ),
                      columnWidths: const {
                        0: FlexColumnWidth(2.5),
                        1: FlexColumnWidth(3),
                        2: FlexColumnWidth(1.5),
                        3: FlexColumnWidth(2),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkBorder
                                : const Color(0xFFECEFF1),
                          ),
                          children: const [
                            Padding(
                                padding: EdgeInsets.all(6),
                                child: Text('N° SUIVI',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 10))),
                            Padding(
                                padding: EdgeInsets.all(6),
                                child: Text('NATURE / CONTENU',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 10))),
                            Padding(
                                padding: EdgeInsets.all(6),
                                child: Text('POIDS',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 10))),
                            Padding(
                                padding: EdgeInsets.all(6),
                                child: Text('DESTINATAIRE',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 10))),
                          ],
                        ),
                        ...colisDuBus.map((c) => TableRow(
                              children: [
                                Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Text(c.id,
                                        style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'monospace'))),
                                Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Text(c.typeColis,
                                        style: const TextStyle(fontSize: 9))),
                                Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Text('${c.poidsKg} kg',
                                        style: const TextStyle(fontSize: 9))),
                                Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Text(c.destinataireNom,
                                        style: const TextStyle(fontSize: 9))),
                              ],
                            )),
                      ],
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Blocs de Cachets pour Contrôle Mixte
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 75,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : Colors.grey.shade400,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Visa Chef d\'Agence Départ :',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : Colors.black87,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Cachet & Signature',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: isDark
                                      ? AppColors.darkTextMuted
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 75,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : Colors.grey.shade400,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Visa Poste Mixte Contrôle (Édéa) :',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : Colors.black87,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Police / Gendarmerie / Douane',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: isDark
                                      ? AppColors.darkTextMuted
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Boutons d'exportation
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Partager au Chauffeur (WhatsApp)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Manifeste préparé pour le partage WhatsApp du chauffeur.')),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label :',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 10,
                color: isDark ? AppColors.darkTextPrimary : Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? AppColors.darkTextSecondary : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resumeItem(
      String label, String value, IconData icon, bool isDark) {
    return Column(
      children: [
        Icon(icon, size: 16, color: AppColors.primaryBlue),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
            color: isDark ? AppColors.darkTextPrimary : Colors.black,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            color: isDark ? AppColors.darkTextMuted : Colors.black54,
          ),
        ),
      ],
    );
  }
}
