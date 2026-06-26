import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static TextTheme _buildTextTheme(Color bodyColor) {
    return GoogleFonts.poppinsTextTheme().apply(
      bodyColor: bodyColor,
      displayColor: bodyColor,
    );
  }

  static CardThemeData _buildCardTheme({
    required Color cardColor,
    required Color borderColor,
    required bool hasBorder,
  }) {
    return CardThemeData(
      color: cardColor,
      elevation: hasBorder ? 0 : 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: hasBorder
            ? BorderSide(color: borderColor, width: 1)
            : BorderSide.none,
      ),
    );
  }

  static InputDecorationTheme _buildInputTheme({
    required Color fillColor,
    required Color focusColor,
  }) {
    return InputDecorationTheme(
      filled: true,
      fillColor: fillColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: focusColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  static ElevatedButtonThemeData _buildButtonTheme(Color primary) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    );
  }

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: AppColors.indigoNavy,
      onPrimary: Colors.white,
      secondary: AppColors.indigoNavyLight,
      onSecondary: Colors.white,
      surface: AppColors.lightCard,
      onSurface: AppColors.lightText,
      error: AppColors.error,
    ),
    scaffoldBackgroundColor: AppColors.lightBackground,
    textTheme: _buildTextTheme(AppColors.lightText),
    cardTheme: _buildCardTheme(
      cardColor: AppColors.lightCard,
      borderColor: AppColors.lightDivider,
      hasBorder: true,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.lightBackground,
      foregroundColor: AppColors.lightText,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: GoogleFonts.poppins(
        color: AppColors.lightText,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.lightNavBar,
      selectedItemColor: AppColors.indigoNavy,
      unselectedItemColor: AppColors.lightTextSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      showUnselectedLabels: true,
    ),
    elevatedButtonTheme: _buildButtonTheme(AppColors.indigoNavy),
    inputDecorationTheme: _buildInputTheme(
      fillColor: AppColors.lightSurface,
      focusColor: AppColors.indigoNavy,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.lightDivider,
      thickness: 1,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.lightSurface,
      selectedColor: AppColors.indigoNavy,
      labelStyle: GoogleFonts.poppins(fontSize: 12, color: AppColors.lightText),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.indigoNavyLight,
      onPrimary: Colors.white,
      secondary: AppColors.indigoNavySoft,
      onSecondary: Colors.white,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkText,
      error: AppColors.error,
    ),
    scaffoldBackgroundColor: AppColors.darkBackground,
    textTheme: _buildTextTheme(AppColors.darkText),
    cardTheme: _buildCardTheme(
      cardColor: AppColors.darkCard,
      borderColor: AppColors.darkDivider,
      hasBorder: true,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.darkBackground,
      foregroundColor: AppColors.darkText,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: GoogleFonts.poppins(
        color: AppColors.darkText,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.darkNavBar,
      selectedItemColor: AppColors.indigoNavyLight,
      unselectedItemColor: AppColors.darkTextSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      showUnselectedLabels: true,
    ),
    elevatedButtonTheme: _buildButtonTheme(AppColors.indigoNavyLight),
    inputDecorationTheme: _buildInputTheme(
      fillColor: AppColors.darkSurface,
      focusColor: AppColors.indigoNavyLight,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.darkDivider,
      thickness: 1,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.darkSurface,
      selectedColor: AppColors.indigoNavyLight,
      labelStyle: GoogleFonts.poppins(fontSize: 12, color: AppColors.darkText),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}
