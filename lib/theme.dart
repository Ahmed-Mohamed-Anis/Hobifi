import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);

  static const EdgeInsets horizontalXs = EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets horizontalSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets horizontalLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets horizontalXl = EdgeInsets.symmetric(horizontal: xl);

  static const EdgeInsets verticalXs = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets verticalSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets verticalLg = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets verticalXl = EdgeInsets.symmetric(vertical: xl);
}

class AppRadius {
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 28.0;
  static const double xl = 24.0;
  static const double full = 9999.0;
}

extension TextStyleContext on BuildContext {
  TextTheme get textStyles => Theme.of(this).textTheme;
}

extension TextStyleExtensions on TextStyle {
  TextStyle get bold => copyWith(fontWeight: FontWeight.bold);
  TextStyle get semiBold => copyWith(fontWeight: FontWeight.w600);
  TextStyle get medium => copyWith(fontWeight: FontWeight.w500);
  TextStyle get normal => copyWith(fontWeight: FontWeight.w400);
  TextStyle get light => copyWith(fontWeight: FontWeight.w300);
  TextStyle withColor(Color color) => copyWith(color: color);
  TextStyle withSize(double size) => copyWith(fontSize: size);
}

class AppColors {
  // Hobifi Brand Colors
  static const Color cream = Color(0xFFF5EED6);        // Secondary - Light cream
  static const Color indigo = Color(0xFF1E1B7A);       // Primary - Deep indigo/blue
  static const Color orange = Color(0xFFE88B3C);       // Secondary - Vibrant orange
  static const Color lime = Color(0xFF9BC53D);         // Primary accent - Lime green

  // Light mode (using brand colors)
  static const Color lightPrimary = indigo;
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightSecondary = orange;
  static const Color lightOnSecondary = Color(0xFFFFFFFF);
  static const Color lightAccent = lime;
  static const Color likeRed = Color(0xFFE53935);
  static const Color lightBackground = cream;
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightOnSurface = indigo;
  static const Color lightPrimaryText = indigo;
  static const Color lightSecondaryText = Color(0xFF62627A);
  static const Color lightHint = Color(0xFFA0A0B8);
  static const Color lightError = Color(0xFFFF3B30);
  static const Color lightOnError = Color(0xFFFFFFFF);
  static const Color lightSuccess = lime;
  static const Color lightDivider = Color(0xFFE0E0E0);

  // Dark mode (2026-04 palette pass — warmer base, better hierarchy)
  static const Color darkPrimary = Color(0xFF6E6AE8);
  static const Color darkOnPrimary = Color(0xFFFFFFFF);
  static const Color darkSecondary = Color(0xFFF2A15E);
  static const Color darkOnSecondary = Color(0xFF1A0F05);
  static const Color darkAccent = Color(0xFFB6D25A);
  static const Color darkBackground = Color(0xFF0F0D1A);
  static const Color darkSurface = Color(0xFF1A1825);
  static const Color darkSurfaceContainerLowest = Color(0xFF151322);
  static const Color darkSurfaceContainerLow = Color(0xFF201D2E);
  static const Color darkSurfaceContainer = Color(0xFF26223A);
  static const Color darkSurfaceContainerHigh = Color(0xFF2D2947);
  static const Color darkSurfaceContainerHighest = Color(0xFF353055);
  static const Color darkOnSurface = Color(0xFFF0EEFF);
  static const Color darkPrimaryText = Color(0xFFF0EEFF);
  static const Color darkSecondaryText = Color(0xFFA39DBD);
  static const Color darkHint = Color(0xFF6B6690);
  static const Color darkError = Color(0xFFFF6B5F);
  static const Color darkOnError = Color(0xFFFFFFFF);
  static const Color darkSuccess = lime;
  static const Color darkDivider = Color(0xFF3A3750);
  static const Color darkOutline = Color(0xFF3A3750);
}

ThemeData get lightTheme => ThemeData(
  useMaterial3: true,
  colorScheme: const ColorScheme.light(
    primary: AppColors.lightPrimary,
    onPrimary: AppColors.lightOnPrimary,
    secondary: AppColors.lightSecondary,
    onSecondary: AppColors.lightOnSecondary,
    tertiary: AppColors.lightAccent,
    error: AppColors.lightError,
    onError: AppColors.lightOnError,
    surface: AppColors.lightSurface,
    onSurface: AppColors.lightOnSurface,
  ),
  brightness: Brightness.light,
  scaffoldBackgroundColor: AppColors.lightBackground,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: AppColors.lightPrimaryText,
    elevation: 0,
    scrolledUnderElevation: 0,
  ),
  textTheme: _buildTextTheme(Brightness.light),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.lightSurface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: const BorderSide(color: AppColors.lightPrimary, width: 2),
    ),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: AppColors.lightPrimary,
    foregroundColor: AppColors.lightOnPrimary,
  ),
);

ThemeData get darkTheme => ThemeData(
  useMaterial3: true,
  colorScheme: const ColorScheme.dark(
    primary: AppColors.darkPrimary,
    onPrimary: AppColors.darkOnPrimary,
    secondary: AppColors.darkSecondary,
    onSecondary: AppColors.darkOnSecondary,
    tertiary: AppColors.darkAccent,
    onTertiary: AppColors.darkOnPrimary,
    error: AppColors.darkError,
    onError: AppColors.darkOnError,
    surface: AppColors.darkSurface,
    onSurface: AppColors.darkOnSurface,
    surfaceContainerLowest: AppColors.darkSurfaceContainerLowest,
    surfaceContainerLow: AppColors.darkSurfaceContainerLow,
    surfaceContainer: AppColors.darkSurfaceContainer,
    surfaceContainerHigh: AppColors.darkSurfaceContainerHigh,
    surfaceContainerHighest: AppColors.darkSurfaceContainerHighest,
    outline: AppColors.darkOutline,
    outlineVariant: AppColors.darkDivider,
  ),
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.darkBackground,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: AppColors.darkPrimaryText,
    elevation: 0,
    scrolledUnderElevation: 0,
  ),
  textTheme: _buildTextTheme(Brightness.dark),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.darkSurface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: const BorderSide(color: AppColors.darkPrimary, width: 2),
    ),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: AppColors.darkPrimary,
    foregroundColor: AppColors.darkOnPrimary,
  ),
);

TextTheme _buildTextTheme(Brightness brightness) {
  return TextTheme(
    displayLarge: GoogleFonts.poppins(fontSize: 34, fontWeight: FontWeight.w800, height: 1.1),
    displayMedium: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700, height: 1.2),
    displaySmall: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, height: 1.2),
    headlineLarge: GoogleFonts.poppins(fontSize: 34, fontWeight: FontWeight.w800, height: 1.1),
    headlineMedium: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700, height: 1.2),
    headlineSmall: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, height: 1.2),
    titleLarge: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, height: 1.2),
    titleMedium: GoogleFonts.urbanist(fontSize: 17, fontWeight: FontWeight.w700, height: 1.3),
    titleSmall: GoogleFonts.urbanist(fontSize: 15, fontWeight: FontWeight.w700, height: 1.3),
    bodyLarge: GoogleFonts.urbanist(fontSize: 17, fontWeight: FontWeight.w400, height: 1.5),
    bodyMedium: GoogleFonts.urbanist(fontSize: 15, fontWeight: FontWeight.w400, height: 1.5),
    bodySmall: GoogleFonts.urbanist(fontSize: 13, fontWeight: FontWeight.w400, height: 1.4),
    labelLarge: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, height: 1.3),
    labelMedium: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, height: 1.3),
    labelSmall: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, height: 1.2),
  );
}
