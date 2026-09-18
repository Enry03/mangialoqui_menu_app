import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFFF5F7FB);
  static const backgroundTint = Color(0xFFF8FBFF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF0F4FA);
  static const surfaceSoft = Color(0xFFE8EEF8);

  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF475569);
  static const textMuted = Color(0xFF94A3B8);

  static const border = Color(0xFFD9E2F0);
  static const divider = Color(0xFFE5ECF5);

  static const primary = Color(0xFF1E3A8A);
  static const primaryDark = Color(0xFF0F2F5D);
  static const primarySoft = Color(0xFFE8F0FB);
  static const primaryGlow = Color(0xFF2A5CAA);

  // Terzo colore, per dettagli: badge, prezzi in evidenza, CTA secondarie, tab attiva.
  static const accent = Color(0xFFE0A030);
  static const accentDark = Color(0xFFB97D18);
  static const accentSoft = Color(0xFFFBF0DC);

  static const success = Color(0xFF15803D);
  static const warning = Color(0xFFD97706);
  static const error = Color(0xFFDC2626);

  static const white = Colors.white;
  static const black = Colors.black;

  // --- Restyling 2026: gradienti e superfici "vetro" -----------------------
  // Riservati a superfici hero/firma (card di benvenuto, badge icona,
  // stati vuoti importanti). I componenti standard (bottoni, input, liste)
  // restano su tinte piatte: il gradiente resta raro apposta.

  /// Gradiente navy principale: più ricco del vecchio primary→primaryDark,
  /// con uno stop centrale più vivo per dare profondità reale, non un banale
  /// due-toni.
  static const heroGradient = [
    Color(0xFF1E3A8A),
    Color(0xFF15396E),
    Color(0xFF0A2249),
  ];

  /// Velo chiaro in alto a sinistra sulle superfici hero, per simulare un
  /// riflesso "vetro" morbido senza usare blur costosi.
  static const glassHighlight = Color(0x33FFFFFF);
  static const glassHighlightSoft = Color(0x14FFFFFF);

  /// Gradiente ambra, per badge/prezzi in evidenza quando serve più
  /// presenza di un semplice fill piatto (es. stato "pubblicato").
  static const accentGradient = [Color(0xFFF3B94E), Color(0xFFD98E1E)];

  /// Tinta di sfondo per icone/badge in stile "glass tint" (più profondità
  /// del vecchio primarySoft piatto).
  static const primaryTintStart = Color(0xFFEAF1FC);
  static const primaryTintEnd = Color(0xFFDCE8FA);
}
