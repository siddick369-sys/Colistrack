import 'package:flutter/material.dart';
import '../models/notification_item.dart';
import '../services/colis_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'tracking_client_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notifService = NotificationService();
  String _selectedFilter = 'toutes';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Centre de Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_outlined),
            tooltip: 'Tout marquer comme lu',
            onPressed: () async {
              await _notifService.toutMarquerCommeLu();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Toutes les notifications ont été marquées comme lues.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _notifService,
        builder: (context, _) {
          final allNotifs = _notifService.notifications;
          final filtered = allNotifs.where((n) {
            if (_selectedFilter == 'toutes') return true;
            return n.type == _selectedFilter;
          }).toList();

          return Column(
            children: [
              _buildFilterChips(isDark),
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmptyState(isDark)
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          return _buildNotificationCard(filtered[index], isDark);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChips(bool isDark) {
    final filters = [
      {'key': 'toutes', 'label': 'Toutes'},
      {'key': 'transit', 'label': 'Transit & Route'},
      {'key': 'retrait', 'label': 'Arrivées Guichet'},
      {'key': 'securite', 'label': 'Sécurité CNI'},
      {'key': 'paiement', 'label': 'Paiements COD'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Text(f['label']!),
              selectedColor: isDark ? AppColors.darkBorder : AppColors.primaryBlue.withValues(alpha: 0.15),
              checkmarkColor: isDark ? Colors.white : AppColors.primaryBlue,
              labelStyle: TextStyle(
                color: isSelected
                    ? (isDark ? Colors.white : AppColors.primaryBlue)
                    : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              onSelected: (val) {
                setState(() {
                  _selectedFilter = f['key']!;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItem item, bool isDark) {
    IconData icon;
    Color iconColor;

    switch (item.type) {
      case 'transit':
        icon = Icons.local_shipping_outlined;
        iconColor = AppColors.primaryBlue;
        break;
      case 'retrait':
        icon = Icons.store_mall_directory_outlined;
        iconColor = AppColors.trackingTeal;
        break;
      case 'securite':
        icon = Icons.verified_user_outlined;
        iconColor = AppColors.successGreen;
        break;
      case 'paiement':
        icon = Icons.payments_outlined;
        iconColor = AppColors.codPurple;
        break;
      default:
        icon = Icons.info_outline;
        iconColor = AppColors.warningOrange;
    }

    final dateStr = ColisService().dateFormat.format(item.dateCreation);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        if (!item.estLu) {
          await _notifService.marquerCommeLue(item.id);
        }
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TrackingClientScreen(colisIdInitial: item.colisId),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: item.estLu
              ? (isDark ? AppColors.darkSurface : AppColors.lightSurface)
              : (isDark
                  ? AppColors.darkSurfaceElevated
                  : AppColors.primaryBlue.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: item.estLu
                ? (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                : AppColors.primaryBlue.withValues(alpha: 0.35),
            width: item.estLu ? 1 : 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.titre,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: item.estLu ? FontWeight.w600 : FontWeight.bold,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                      ),
                      if (!item.estLu)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryBlue,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.message,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                        child: Text(
                          item.colisId,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 56,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune notification dans cette catégorie',
            style: AppTypography.titleMedium.copyWith(
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Les étapes de chargement, transit, arrivée et retrait apparaîtront ici.',
            style: AppTypography.bodySmall.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
