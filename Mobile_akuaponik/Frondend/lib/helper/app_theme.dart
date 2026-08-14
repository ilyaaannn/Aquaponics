import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ------------------- BRAND -------------------
  static const Color primaryGreen = Color(0xFF2F6B4F);
  static const Color secondaryGreen = Color(0xFF5FBF88);
  static const Color accentGreen = Color(0xFF1F4D3A);

  // The fish half of the logo — an accent the old palette never used.
  static const Color aquaBlue = Color(0xFF2E6F9E);
  static const Color aquaBlueSoft = Color(0xFF7FB0CE);

  // Near-black teal used for the "instrument panel" header + readouts.
  static const Color inkDeep = Color(0xFF0B2B26);
  static const Color inkDeepAlt = Color(0xFF15413A);

  // ------------------- STATUS (good → critical) -------------------
  static const Color statusIdeal = Color(0xFF34B36B); // fresh forest
  static const Color statusOptimal = Color(0xFF3FA65B); // fresh green
  static const Color statusNormal = Color(0xFFE0A93E); // warm amber
  static const Color statusWarning = Color(0xFFE0602E); // burnt orange
  static const Color statusDanger = Color(0xFFE24545); // bright red

  // ------------------- SENSOR PARAMETERS -------------------
  static const Color paramPH = aquaBlue;
  static const Color paramTemp = Color(0xFFE0602E);
  static const Color paramTDS = Color(0xFFCB9A38);
  static const Color paramDO = Color(0xFF17A398);

  static const Color phColor = paramPH;
  static const Color tempColor = paramTemp;
  static const Color tdsColor = paramTDS;
  static const Color doColor = paramDO;

  // ------------------- SENSOR PARAMETERS (Data Desktop — 11 parameter) -------------------
  static const Color paramWaterLevel = Color(0xFF3D6FA5); // Level Air
  static const Color paramTurbidity = Color(0xFF8B6FB0); // Kekeruhan
  static const Color paramAirTemp = Color(0xFFC96A56); // Suhu Udara
  static const Color paramHumidity = Color(0xFF3FA0AE); // Kelembaban
  static const Color paramCO2 = Color(0xFF3F9E76); // CO2
  static const Color paramECO2 = Color(0xFF9C9142); // eCO2
  static const Color paramTVOC = Color(0xFFA9673D); // TVOC

  // ------------------- SIGNATURE MOTIF -------------------
  static const LinearGradient currentGradient = LinearGradient(
    colors: [primaryGreen, aquaBlue],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient panelGradient = LinearGradient(
    colors: [inkDeep, inkDeepAlt],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static BoxShadow get cardShadow => BoxShadow(
    color: inkDeep.withOpacity(0.07),
    blurRadius: 20,
    offset: const Offset(0, 8),
  );
  static BoxShadow get rowShadow => BoxShadow(
    color: inkDeep.withOpacity(0.05),
    blurRadius: 10,
    offset: const Offset(0, 3),
  );
  static const double pagePadding = 16;

  static Widget currentLine({double height = 4}) {
    return Container(
      height: height,
      decoration: const BoxDecoration(gradient: currentGradient),
    );
  }

  // ------------------- TYPE ROLES -------------------
  static TextStyle display({
    double fontSize = 22,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
    double? letterSpacing,
  }) => GoogleFonts.spaceGrotesk(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing ?? -0.3,
  );

  // Body face — unchanged from before, it was already a solid choice.
  static TextStyle body({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
  }) => GoogleFonts.inter(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
  );

  // Data/readout face — for sensor values, IP, timestamps.
  static TextStyle data({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
  }) => GoogleFonts.jetBrainsMono(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
  );

  // ------------------- TEMA TERANG (LIGHT MODE) -------------------
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primaryGreen,
      scaffoldBackgroundColor: const Color(0xFFF1F5F3),
      cardColor: Colors.white,
      dividerColor: const Color(0xFFE1E8E4),
      colorScheme: const ColorScheme.light(
        primary: primaryGreen,
        secondary: aquaBlue,
        surface: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme)
          .copyWith(
            displayLarge: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
            displayMedium: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w700,
            ),
            titleLarge: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF1F2937),
        elevation: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryGreen,
        unselectedItemColor: Color(0xFF9CA3AF),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  // ------------------- HELPER METHOD -------------------
  static Color textPrimary(BuildContext context) => const Color(0xFF1F2937);
  static Color textSecondary(BuildContext context) => const Color(0xFF6B7280);
  static Color containerBg(BuildContext context) => Colors.white;
  static Color scaffoldBg(BuildContext context) => const Color(0xFFF1F5F3);
}
