import 'package:flutter/material.dart';
import '../models/colis.dart';
import '../theme/app_colors.dart';

/// Badge standardisé pour le statut d'un colis avec couleur sémantique
class ColisStatusBadge extends StatelessWidget {
  final StatutColis statut;

  const ColisStatusBadge({super.key, required this.statut});

  Color get _badgeColor {
    switch (statut) {
      case StatutColis.enregistre:
        return AppColors.primary;
      case StatutColis.chargeBus:
        return AppColors.warning;
      case StatutColis.enTransit:
        return AppColors.tracking;
      case StatutColis.arriveDestination:
        return AppColors.success;
      case StatutColis.retire:
        return AppColors.primaryDark;
    }
  }

  String get _label {
    switch (statut) {
      case StatutColis.enregistre:
        return 'Enregistré au guichet';
      case StatutColis.chargeBus:
        return 'Chargé dans le bus';
      case StatutColis.enTransit:
        return 'En transit';
      case StatutColis.arriveDestination:
        return 'Arrivé - Prêt au retrait';
      case StatutColis.retire:
        return 'Colis livré / Retiré';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _badgeColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mini-badge pour les caractéristiques spéciales d'un colis (Photo, COD, CNI)
class LogisticsFeatureBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const LogisticsFeatureBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  factory LogisticsFeatureBadge.photo() {
    return const LogisticsFeatureBadge(
      icon: Icons.camera_alt,
      label: 'Photo Scellée',
      color: AppColors.tracking,
    );
  }

  factory LogisticsFeatureBadge.cni() {
    return const LogisticsFeatureBadge(
      icon: Icons.verified_user,
      label: 'CNI Archivée',
      color: AppColors.success,
    );
  }

  factory LogisticsFeatureBadge.cashOnDelivery(String montantFormatte) {
    return LogisticsFeatureBadge(
      icon: Icons.shopping_bag,
      label: 'COD ($montantFormatte)',
      color: AppColors.cod,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge d'état de synchronisation cloud / multi-appareils
class SyncStatusBadge extends StatelessWidget {
  final SyncStatus status;
  final bool compact;

  const SyncStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = status.color;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: compact ? 12 : 14, color: color),
          if (!compact) ...[
            const SizedBox(width: 5),
            Text(
              status.label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pill interactif pour l'AppBar affichant l'état du réseau & de la sync
class SyncHeaderPill extends StatelessWidget {
  final bool isHorsLigne;
  final int countPending;
  final VoidCallback onTap;

  const SyncHeaderPill({
    super.key,
    required this.isHorsLigne,
    required this.countPending,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData icon;
    String label;

    if (isHorsLigne) {
      bg = Colors.red.shade900.withValues(alpha: 0.25);
      fg = const Color(0xFFFCA5A5);
      icon = Icons.wifi_off_rounded;
      label = 'Hors-ligne';
    } else if (countPending > 0) {
      bg = Colors.amber.shade900.withValues(alpha: 0.25);
      fg = const Color(0xFFFDE68A);
      icon = Icons.sync_rounded;
      label = '$countPending en attente';
    } else {
      bg = Colors.green.shade900.withValues(alpha: 0.25);
      fg = const Color(0xFF86EFAC);
      icon = Icons.cloud_done_rounded;
      label = 'Sync 🟢';
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: fg.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
