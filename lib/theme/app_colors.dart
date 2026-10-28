import 'package:flutter/material.dart';

/// Palette de couleurs officielle pour ColisTrack Cameroun
/// Direction artistique : confiance institutionnelle, visibilité terrain et contraste élevé.
class AppColors {
  // Couleurs principales
  static const Color primaryDark = Color(0xFF102A43);    // Bleu nuit profond (structure & navigation)
  static const Color primary = Color(0xFF2563EB);        // Bleu éclatant (actions primaires)
  static const Color primaryLight = Color(0xFF3B82F6);   // Bleu clair interactif
  
  // Couleurs d'accentuation logistique
  static const Color tracking = Color(0xFF0EA5A4);       // Turquoise (transit & acheminement)
  static const Color success = Color(0xFF16A34A);        // Vert (livraison & validation paiement)
  static const Color warning = Color(0xFFF59E0B);        // Orange vif (en attente & manutention)
  static const Color danger = Color(0xFFDC2626);         // Rouge (alerte, retard & litige)
  static const Color cod = Color(0xFF7C3AED);            // Violet (service Cash on Delivery)

  // Couleurs d'opérateurs financiers au Cameroun
  static const Color mtnMomo = Color(0xFFFFCC00);        // Jaune MTN MoMo
  static const Color orangeMoney = Color(0xFFFF6600);    // Orange Orange Money

  // Alias sémantiques (constants)
  static const Color headerNavy = primaryDark;
  static const Color primaryBlue = primary;
  static const Color trackingTeal = tracking;
  static const Color successGreen = success;
  static const Color warningOrange = warning;
  static const Color dangerRed = danger;
  static const Color codPurple = cod;
  static const Color momoYellow = mtnMomo;
  static const Color orangeMoneyOrange = orangeMoney;

  // Palette Thème Clair
  static const Color lightBackground = Color(0xFFF5F7FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF1F5F9);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // Palette Thème Sombre (Quai de nuit & faible luminosité)
  static const Color darkBackground = Color(0xFF0B132B);
  static const Color darkSurface = Color(0xFF1C2541);
  static const Color darkSurfaceVariant = Color(0xFF263252);
  static const Color darkSurfaceElevated = darkSurfaceVariant;
  static const Color darkBorder = Color(0xFF3A506B);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFFCBD5E1);
  static const Color darkTextMuted = Color(0xFF64748B);
}
