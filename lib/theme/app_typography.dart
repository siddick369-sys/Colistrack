import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Échelle typographique lisible et adaptée aux écrans modestes (Android d'entrée de gamme).
/// Évite les micro-textes illisibles au soleil ou en gare routière.
class AppTypography {
  static const TextStyle displayLarge = TextStyle(fontSize: 26, fontWeight: FontWeight.w900);
  static const TextStyle titleLarge = TextStyle(fontSize: 18, fontWeight: FontWeight.bold);
  static const TextStyle titleMedium = TextStyle(fontSize: 15, fontWeight: FontWeight.w600);
  static const TextStyle titleSmall = TextStyle(fontSize: 13, fontWeight: FontWeight.w600);
  static const TextStyle bodyLarge = TextStyle(fontSize: 15, fontWeight: FontWeight.normal);
  static const TextStyle bodyMedium = TextStyle(fontSize: 13, fontWeight: FontWeight.normal);
  static const TextStyle bodySmall = TextStyle(fontSize: 12, fontWeight: FontWeight.normal);

  static TextTheme textTheme(bool isDark) {
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return TextTheme(
      // Grands titres (Dashboard, Totaux financiers)
      displayLarge: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w900,
        color: textPrimary,
        letterSpacing: -0.5,
      ),
      displayMedium: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      // Titres de section
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: textPrimary,
        letterSpacing: 0.15,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleSmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      // Corps de texte principal (lisible, minimum 13px)
      bodyLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.normal,
        color: textPrimary,
        height: 1.4,
      ),
      bodyMedium: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.normal,
        color: textSecondary,
        height: 1.35,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: textSecondary,
      ),
      // Étiquettes & boutons
      labelLarge: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
      labelMedium: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.25,
      ),
      labelSmall: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }
}
