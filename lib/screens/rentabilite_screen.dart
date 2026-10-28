import 'package:flutter/material.dart';
import '../services/colis_service.dart';
import '../theme/app_colors.dart';

class RentabiliteScreen extends StatefulWidget {
  const RentabiliteScreen({super.key});

  @override
  State<RentabiliteScreen> createState() => _RentabiliteScreenState();
}

class _RentabiliteScreenState extends State<RentabiliteScreen> {
  final ColisService _service = ColisService();

  double _colisParJour = 80;
  double _prixMoyenColis = 2500;
  final double _coutSaaSParMois = 35000; // 35 000 FCFA / agence / mois

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double recettesMensuelles = _colisParJour * _prixMoyenColis * 30;
    final double coutLogiciel = _coutSaaSParMois;
    final double rentabiliteRatio = recettesMensuelles / coutLogiciel;
    final double gainPertesEvitees =
        recettesMensuelles * 0.08; // 8% de pertes/vols évités grâce au QR code + OTP

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modèle Économique & Rentabilité SaaS'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Carte synthèse
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [AppColors.darkSurfaceElevated, AppColors.darkSurface]
                      : [AppColors.headerNavy, const Color(0xFF1E40AF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.monetization_on_outlined, color: AppColors.momoYellow),
                      SizedBox(width: 8),
                      Text(
                        'BUSINESS MODEL B2B CAMEROUN',
                        style: TextStyle(
                          color: AppColors.momoYellow,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Comment monétiser cette solution auprès des agences de voyages ?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Les agences de voyage (Buca, Général, Touristique, etc.) perdent chaque mois des clients à cause des colis volés ou égarés.',
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextSecondary : Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Simulateur Interactif
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
                      'Simulateur de Gains pour 1 Agence (ex: Douala Bassa)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const Divider(height: 20),

                    // Slider Colis / jour
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Colis expédiés par jour :'),
                        Text(
                          '${_colisParJour.round()} colis/j',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _colisParJour,
                      min: 20,
                      max: 300,
                      divisions: 28,
                      activeColor: AppColors.primaryBlue,
                      onChanged: (v) => setState(() => _colisParJour = v),
                    ),

                    // Slider Prix Moyen
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tarif moyen par colis :'),
                        Text(
                          _service.currencyFormat.format(_prixMoyenColis),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.successGreen,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _prixMoyenColis,
                      min: 1500,
                      max: 5000,
                      divisions: 7,
                      activeColor: AppColors.successGreen,
                      onChanged: (v) => setState(() => _prixMoyenColis = v),
                    ),

                    const Divider(height: 24),

                    // Résultats chiffrés
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurface
                            : AppColors.successGreen.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.successGreen.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          _resultRow(
                            'Chiffre d\'Affaires Fret Mensuel :',
                            _service.currencyFormat.format(recettesMensuelles),
                            isDark: isDark,
                            isBold: true,
                          ),
                          const SizedBox(height: 6),
                          _resultRow(
                            'Économie Pertes / Vols évités (8%) :',
                            '+ ${_service.currencyFormat.format(gainPertesEvitees)}',
                            isDark: isDark,
                            color: AppColors.successGreen,
                          ),
                          const Divider(height: 16),
                          _resultRow(
                            'Votre Abonnement SaaS facturé :',
                            _service.currencyFormat.format(coutLogiciel),
                            isDark: isDark,
                            isBold: true,
                            color: AppColors.primaryBlue,
                          ),
                          const SizedBox(height: 6),
                          _resultRow(
                            'Retour sur investissement (ROI) :',
                            'x ${rentabiliteRatio.toStringAsFixed(0)} pour l\'agence',
                            isDark: isDark,
                            isBold: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 3 Offres de facturation
            const Text(
              '3 MODÈLES DE MONÉTISATION AU CHOIX :',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),

            _offreCard(
              titre: '1. Abonnement SaaS Mensuel Fixe',
              tarif: '25 000 à 45 000 FCFA / agence / mois',
              description:
                  'Idéal pour sécuriser un revenu récurrent prévisible. Avec 10 agences clientes (Douala, Yaoundé, Bafoussam), vous générez 350 000 FCFA/mois de cashflow passif.',
              icon: Icons.calendar_today_outlined,
              color: AppColors.primaryBlue,
              isDark: isDark,
            ),
            const SizedBox(height: 10),

            _offreCard(
              titre: '2. Tarification à l\'Usage (Pay-per-parcel)',
              tarif: '25 à 50 FCFA par colis enregistré',
              description:
                  'Très facile à vendre : l\'agence ne paie que si elle expédie. Pour 2 400 colis/mois, vous encaissez entre 60 000 et 120 000 FCFA par guichet.',
              icon: Icons.local_offer_outlined,
              color: AppColors.warningOrange,
              isDark: isDark,
            ),
            const SizedBox(height: 10),

            _offreCard(
              titre: '3. Pack Clé en Main Matériel + Logiciel',
              tarif: '150 000 FCFA à l\'installation + 20 000 FCFA/mois',
              description:
                  'Vous fournissez la mini-imprimante Bluetooth POS-58 (achetée 18 000 FCFA sur le marché local ou Alibaba), le rouleau de papier thermique, la configuration et la formation.',
              icon: Icons.print_outlined,
              color: AppColors.codPurple,
              isDark: isDark,
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(String label, String value,
      {required bool isDark, bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color ??
                (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
          ),
        ),
      ],
    );
  }

  Widget _offreCard({
    required String titre,
    required String tarif,
    required String description,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titre,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(tarif,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: color, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    description,
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
    );
  }
}
