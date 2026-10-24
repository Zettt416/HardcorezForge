import 'package:flutter/material.dart';
import '../models/document_model.dart';

class AppTheme {
  // Brand & Signature Accent Colors
  static const Color brandRed = Color(0xFFDC2626);
  static const Color brandCrimson = Color(0xFFE11D48);
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color accentBlue = Color(0xFF3B82F6);

  // Document Module Colors
  static const Color docBlue = Color(0xFF2563EB); // Word / Doc
  static const Color docBlueLight = Color(0xFFEEF2FF);
  static const Color sheetGreen = Color(0xFF059669); // Sheet / Excel
  static const Color sheetGreenLight = Color(0xFFECFDF5);
  static const Color pptOrange = Color(0xFFEA580C); // Presentation
  static const Color pptOrangeLight = Color(0xFFFFF7ED);
  static const Color pdfRed = Color(0xFFE11D48); // PDF & Sign
  static const Color pdfRedLight = Color(0xFFFEF2F2);

  // Neutral Colors (Dark Mode - Deep Obsidian)
  static const Color darkBg = Color(0xFF0A0E17);
  static const Color darkSurface = Color(0xFF111726);
  static const Color darkCard = Color(0xFF161F33);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkBorder = Color(0xFF1E293B);

  // Neutral Colors (Light Mode - Clean Porcelain)
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightSurface = Colors.white;
  static const Color lightCard = Colors.white;
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightBorder = Color(0xFFE2E8F0);

  static Color getDocColor(DocType type) {
    switch (type) {
      case DocType.word:
        return docBlue;
      case DocType.sheet:
        return sheetGreen;
      case DocType.presentation:
        return pptOrange;
      case DocType.pdf:
        return pdfRed;
    }
  }

  static Color getDocLightColor(DocType type) {
    switch (type) {
      case DocType.word:
        return docBlueLight;
      case DocType.sheet:
        return sheetGreenLight;
      case DocType.presentation:
        return pptOrangeLight;
      case DocType.pdf:
        return pdfRedLight;
    }
  }

  static IconData getDocIcon(DocType type) {
    switch (type) {
      case DocType.word:
        return Icons.article_rounded;
      case DocType.sheet:
        return Icons.table_chart_rounded;
      case DocType.presentation:
        return Icons.slideshow_rounded;
      case DocType.pdf:
        return Icons.picture_as_pdf_rounded;
    }
  }

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBg,
    colorScheme: const ColorScheme.dark(
      primary: accentBlue,
      secondary: sheetGreen,
      surface: darkSurface,
      onSurface: darkTextPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: darkBg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: darkTextPrimary,
      ),
      iconTheme: IconThemeData(color: darkTextPrimary),
    ),
    cardTheme: CardThemeData(
      color: darkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: darkBorder, width: 1),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: darkBorder,
      thickness: 1,
    ),
  );

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: lightBg,
    colorScheme: const ColorScheme.light(
      primary: primaryBlue,
      secondary: sheetGreen,
      surface: lightSurface,
      onSurface: lightTextPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: lightBg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: lightTextPrimary,
      ),
      iconTheme: IconThemeData(color: lightTextPrimary),
    ),
    cardTheme: CardThemeData(
      color: lightCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: lightBorder, width: 1),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: lightBorder,
      thickness: 1,
    ),
  );
}
