import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/colis.dart';
import '../services/colis_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_badges.dart';
import '../widgets/qr_widget.dart';

/// Écran de suivi public d'un colis (accessible aux clients sans compte)
/// Conçu selon le principe de zéro fuite de données personnelles :
/// - Pas d'OTP de retrait
/// - Pas de numéro de CNI
/// - Pas de commission agence
/// - Numéros de téléphone masqués
class TrackingClientScreen extends StatefulWidget {
  final String? initialCode;

  const TrackingClientScreen({
    super.key,
    String? initialCode,
    String? colisIdInitial,
  }) : initialCode = initialCode ?? colisIdInitial;

  @override
  State<TrackingClientScreen> createState() => _TrackingClientScreenState();
}

class _TrackingClientScreenState extends State<TrackingClientScreen> {
  final ColisService _service = ColisService();
  late TextEditingController _searchController;
  ColisPublicView? _publicView;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final defaultCode = widget.initialCode ??
        (_service.allColis.isNotEmpty
            ? _service.allColis.first.trackingNumber
            : 'TRX-8921-M4K');
    _searchController = TextEditingController(text: defaultCode);
    _chercher(defaultCode);
    _service.addListener(_onServiceUpdate);
  }

  @override
  void didUpdateWidget(covariant TrackingClientScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCode != null && widget.initialCode != oldWidget.initialCode) {
      _searchController.text = widget.initialCode!;
      _chercher(widget.initialCode!);
    }
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceUpdate);
    _searchController.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted && _publicView != null) {
      _chercher(_publicView!.trackingNumber);
    }
  }

  Future<void> _chercher(String code) async {
    final query = code.trim().toUpperCase();
    if (query.isEmpty) return;

    setState(() => _isLoading = true);
    final res = await _service.consulterSuiviPublic(query);
    if (mounted) {
      setState(() {
        _publicView = res;
        _isLoading = false;
      });
    }
  }

  Future<void> _copierLien(String code) async {
    final link = 'https://colisTrack.cm/track/$code';
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.primary,
          content: Text('Lien de suivi copié dans le presse-papier'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _partagerParSms(ColisPublicView view) async {
    final message =
        'Suivi ColisTrack : Votre colis ${view.trackingNumber} est "${view.statusLabel}". Retrait prévu : ${view.destinationCity} (${view.destinationBranch}). Suivre : https://colisTrack.cm/track/${view.trackingNumber}';
    final uri = Uri.parse('sms:?body=${Uri.encodeComponent(message)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await _copierLien(view.trackingNumber);
      }
    } catch (_) {
      await _copierLien(view.trackingNumber);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final view = _publicView;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Suivi en Ligne du Colis'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // BANDEAU DE RECHERCHE CLIENT
            Container(
              padding: const EdgeInsets.all(16),
              color: isDark ? AppColors.darkSurface : AppColors.headerNavy,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Entrez le numéro de suivi du récépissé :',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                            fontFamily: 'monospace',
                          ),
                          decoration: InputDecoration(
                            hintText: 'Ex: TRX-8921-M4K',
                            filled: true,
                            fillColor: isDark ? AppColors.darkBackground : Colors.white,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: _chercher,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.momoYellow,
                          foregroundColor: Colors.black87,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => _chercher(_searchController.text),
                        child: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Suivre',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (view != null) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // CARTE RÉSUMÉ DU COLIS
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      view.trackingNumber,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.2,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${view.agencyName} • ${view.parcelType}',
                                      style: TextStyle(
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.lightTextSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                QrVisualWidget(
                                  data: 'TRANSCOLIS:${view.trackingNumber}',
                                  size: 60,
                                ),
                              ],
                            ),
                            const Divider(height: 20),

                            // STATUT COURANT
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 14),
                              decoration: BoxDecoration(
                                color: view.statusColor.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: view.statusColor.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.radar, color: view.statusColor),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'STATUT EN DIRECT',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? AppColors.darkTextMuted
                                                : AppColors.lightTextMuted,
                                          ),
                                        ),
                                        Text(
                                          view.statusLabel,
                                          style: TextStyle(
                                            color: view.statusColor,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ColisStatusBadge(statut: view.status),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // ITINÉRAIRE & GUICHET DE RETRAIT
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'DÉPART',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? AppColors.darkTextMuted
                                              : AppColors.lightTextMuted,
                                        ),
                                      ),
                                      Text(
                                        view.originCity,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        view.originBranch,
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
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Icon(
                                    Icons.arrow_forward,
                                    color: isDark
                                        ? AppColors.darkTextMuted
                                        : AppColors.lightTextMuted,
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'DESTINATION / RETRAIT',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? AppColors.darkTextMuted
                                              : AppColors.lightTextMuted,
                                        ),
                                      ),
                                      Text(
                                        view.destinationCity,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        view.destinationBranch,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark
                                              ? AppColors.darkTextSecondary
                                              : AppColors.lightTextSecondary,
                                        ),
                                        textAlign: TextAlign.end,
                                      ),
                                      Text(
                                        view.pickupCounter,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.end,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const Divider(height: 24),

                            // BOUTONS DE PARTAGE SÉCURISÉ
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton.icon(
                                  icon: const Icon(Icons.copy, size: 16),
                                  label: const Text('Copier le lien', style: TextStyle(fontSize: 12)),
                                  onPressed: () => _copierLien(view.trackingNumber),
                                ),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.share, size: 16),
                                  label: const Text('Partager', style: TextStyle(fontSize: 12)),
                                  onPressed: () => _partagerParSms(view),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // HISTORIQUE SÉCURISÉ DES ÉTAPES
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Historique d\'Acheminement (${view.events.length} étapes)',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),

                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: view.events.length,
                      itemBuilder: (context, index) {
                        final etape = view.events[index];
                        final isLast = index == view.events.length - 1;

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: isLast
                                        ? AppColors.primary
                                        : AppColors.successGreen,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check,
                                      size: 12, color: Colors.white),
                                ),
                                if (index < view.events.length - 1)
                                  Container(
                                    width: 2,
                                    height: 50,
                                    color: AppColors.successGreen.withValues(alpha: 0.35),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            etape.titre,
                                            style: TextStyle(
                                              fontWeight: isLast
                                                  ? FontWeight.w900
                                                  : FontWeight.bold,
                                              fontSize: 13,
                                              color: isLast
                                                  ? (isDark
                                                      ? Colors.white
                                                      : AppColors.primary)
                                                  : (isDark
                                                      ? AppColors.darkTextPrimary
                                                      : AppColors.lightTextPrimary),
                                            ),
                                          ),
                                        ),
                                        Text(
                                          _service.dateFormat.format(etape.date),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isDark
                                                ? AppColors.darkTextMuted
                                                : AppColors.lightTextMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      etape.description,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                    if (etape.lieu.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          '📍 ${etape.lieu}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.primary,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off_outlined,
                      size: 56,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Aucun colis trouvé avec le numéro "${_searchController.text}".\n'
                      'Vérifiez le numéro de suivi inscrit sur votre reçu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
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
