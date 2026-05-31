import 'package:flutter/material.dart';

class AdminTheme {
  // Brand New Color Spec System (Dark Navy Blue + Electrolyte Yellow)
  static const Color darkBackground = Color(0xFF07162F);  // Primary Background
  static const Color secondaryBg = Color(0xFF0B1D3D);     // Secondary Background
  static const Color sidebarBg = Color(0xFF081528);       // Sidebar Background
  static const Color darkSurface = Color(0xFF10254D);     // Card Background
  static const Color darkSurfaceLight = Color(0xFF1A3769); // Border Color fallback
  static const Color borderColor = Color(0xFF1A3769);     // Border Color
  
  // Brand Accents - Upgraded to a less bright, premium mustard-gold tone
  static const Color primaryYellow = Color(0xFFC9A200);   // Deeper Premium Mustard Gold
  static const Color secondaryYellow = Color(0xFFB08C00); // Darker Gold for Gradients
  static const Color hoverYellow = Color(0xFFE5B800);     // Lighter Gold on Hover
  
  // Backward compatibility alias definitions (now cleanly mapped to the new gold tones)
  static const Color primaryColor = primaryYellow;
  static const Color accentTeal = primaryYellow;
  static const Color accentBlue = secondaryYellow;
  static const Color accentEmerald = Color(0xFF22C55E);    // Success Green
  static const Color successColor = Color(0xFF22C55E);     // Success Green
  static const Color errorColor = Color(0xFFEF4444);       // Error Red
  static const Color warningColor = Color(0xFFF59E0B);     // Warning Orange
  static const Color textPrimary = Color(0xFFFFFFFF);      // Text Primary
  static const Color textSecondary = Color(0xFFB7C3D6);    // Text Secondary

  // Standard Gradients matching specifications
  static const LinearGradient tealGradient = LinearGradient(
    colors: [primaryYellow, secondaryYellow],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient blueGradient = LinearGradient(
    colors: [secondaryYellow, hoverYellow],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient emeraldGradient = LinearGradient(
    colors: [Color(0xFF22C55E), Color(0xFF4ADE80)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGlassGradient = LinearGradient(
    colors: [Color(0x3310254D), Color(0x0A07162F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Box Decoration utility for frosted glass look
  static BoxDecoration glassBox({
    Color? customBorderColor,
    double radius = 12.0,
    double opacity = 0.15,
  }) {
    return BoxDecoration(
      color: darkSurface.withOpacity(opacity),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: customBorderColor ?? borderColor,
        width: 1.0,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 20,
          offset: const Offset(0, 4),
        )
      ]
    );
  }

  // Dark Theme Settings
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryYellow,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: primaryYellow,
        secondary: secondaryYellow,
        surface: darkSurface,
        error: errorColor,
        background: darkBackground,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
          fontFamily: 'Poppins',
          fontFamilyFallback: ['Inter', 'Roboto'],
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins',
          fontFamilyFallback: ['Inter', 'Roboto'],
        ),
        bodyLarge: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontFamily: 'Poppins',
          fontFamilyFallback: ['Inter', 'Roboto'],
        ),
        bodyMedium: TextStyle(
          color: textSecondary,
          fontSize: 14,
          fontFamily: 'Poppins',
          fontFamilyFallback: ['Inter', 'Roboto'],
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderColor, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: secondaryBg.withOpacity(0.6),
        hintStyle: const TextStyle(color: textSecondary, fontSize: 14, fontFamily: 'Poppins', fontFamilyFallback: ['Inter', 'Roboto']),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryYellow, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: errorColor),
        ),
      ),
      buttonTheme: const ButtonThemeData(
        textTheme: ButtonTextTheme.primary,
      ),
    );
  }
}
