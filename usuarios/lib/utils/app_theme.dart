import 'package:flutter/material.dart';

/// Tema estilizado en tonos morados pasteles modernos con soporte completo para Modo Oscuro y Claro
class AppTheme {
  // Paleta de colores primarios pasteles
  static const Color primaryPurple = Color(0xFF7E57C2);       // Púrpura suave principal
  static const Color primaryLight = Color(0xFFD1C4E9);        // Lavanda claro
  static const Color primaryExtraLight = Color(0xFFEDE7F6);   // Fondo lila muy claro
  static const Color deepPurple = Color(0xFF512DA8);          // Púrpura oscuro para textos destacados
  
  // Colores secundarios y acentos pasteles
  static const Color pastelLavender = Color(0xFFE8DEF8);      // Lavanda pastel
  static const Color pastelMauve = Color(0xFFCE93D8);         // Malva pastel
  static const Color pastelPink = Color(0xFFF48FB1);          // Rosa suave
  static const Color softLilac = Color(0xFFF3E5F5);           // Fondo lila suave
  
  // Fondos y superficies (Modo Claro)
  static const Color scaffoldBg = Color(0xFFF9F7FD);          // Fondo general con sutil matiz lila
  static const Color surfaceCard = Color(0xFFFFFFFF);         // Fondo blanco puro para tarjetas
  static const Color inputFill = Color(0xFFF5F2FA);           // Relleno de inputs
  
  // Textos (Modo Claro)
  static const Color textMain = Color(0xFF2D2140);            // Texto principal oscuro con matiz morado
  static const Color textMuted = Color(0xFF796F85);           // Texto secundario grisáceo
  static const Color textLight = Color(0xFF9E94AB);           // Texto atenuado
  
  // Colores temáticos por rol
  static const Color roleAdminBg = Color(0xFFE8DAFF);         // Fondo badge admin
  static const Color roleAdminText = Color(0xFF6200EE);       // Texto badge admin
  
  static const Color roleEditorBg = Color(0xFFF3E5F5);        // Fondo badge editor
  static const Color roleEditorText = Color(0xFF8E24AA);       // Texto badge editor
  
  static const Color roleLectorBg = Color(0xFFE8EAF6);        // Fondo badge lector
  static const Color roleLectorText = Color(0xFF3949AB);       // Texto badge lector
  
  // Estados
  static const Color successColor = Color(0xFF81C784);        // Verde suave pastel
  static const Color errorColor = Color(0xFFE57373);          // Rojo pastel suave
  static const Color warningColor = Color(0xFFFFB74D);        // Ámbar suave

  // Helpers dinámicos para modo Claro / Oscuro
  static Color getScaffoldBg(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF121118)
        : scaffoldBg;
  }

  static Color getSurfaceCard(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1E1C24)
        : surfaceCard;
  }

  static Color getTextMain(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFE6E1E5)
        : textMain;
  }

  static Color getInputFill(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF282533)
        : inputFill;
  }

  /// Configuración del ThemeData MODO CLARO
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryPurple,
        primary: primaryPurple,
        onPrimary: Colors.white,
        primaryContainer: primaryLight,
        onPrimaryContainer: deepPurple,
        secondary: pastelMauve,
        onSecondary: Colors.white,
        secondaryContainer: pastelLavender,
        surface: surfaceCard,
        onSurface: textMain,
        error: errorColor,
        onError: Colors.white,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: scaffoldBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: textMain,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: textMain),
      ),
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFEDE7F6), width: 1.2),
        ),
        shadowColor: const Color(0x147E57C2),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: const Color(0x597E57C2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryPurple,
          side: const BorderSide(color: primaryLight, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryPurple,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        labelStyle: const TextStyle(color: textMuted, fontSize: 14),
        hintStyle: const TextStyle(color: textLight, fontSize: 14),
        prefixIconColor: primaryPurple,
        suffixIconColor: textMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE8DEF8), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryPurple, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: errorColor, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryPurple,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceCard,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titleTextStyle: const TextStyle(
          color: textMain,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        backgroundColor: textMain,
      ),
    );
  }

  /// Configuración del ThemeData MODO OSCURO
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryPurple,
        primary: primaryPurple,
        onPrimary: Colors.white,
        surface: const Color(0xFF1E1C24),
        onSurface: const Color(0xFFE6E1E5),
        error: errorColor,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF121118),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1C24),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF2E2B38), width: 1.2),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF282533),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        labelStyle: const TextStyle(color: Color(0xFFAAA3B8), fontSize: 14),
        hintStyle: const TextStyle(color: Color(0xFF7A7488), fontSize: 14),
        prefixIconColor: primaryLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF383347), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryPurple, width: 2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1E1C24),
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
