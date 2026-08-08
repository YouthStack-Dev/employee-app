import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design system: "The Fluid Executive"
/// Source: Stitch project 4644986887367872692
class FxColors {
  // Brand
  static const Color primary = Color(0xFF4C40DF);
  static const Color primaryContainer = Color(0xFF9995FF);
  static const Color primaryDim = Color(0xFF4030D3);
  static const Color primaryFixed = Color(0xFF9995FF);
  static const Color primaryFixedDim = Color(0xFF8A85FF);
  static const Color onPrimary = Color(0xFFF5F1FF);
  static const Color onPrimaryContainer = Color(0xFF16007D);

  // Secondary
  static const Color secondary = Color(0xFF6448B1);
  static const Color secondaryContainer = Color(0xFFD8CAFF);
  static const Color onSecondary = Color(0xFFF7F0FF);

  // Tertiary (accent — fuchsia)
  static const Color tertiary = Color(0xFF983670);
  static const Color tertiaryContainer = Color(0xFFFE8BC9);

  // Surfaces (no-line architecture — boundaries defined by tone shifts)
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Color(0xFFF5F7FA);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFEEF1F4);
  static const Color surfaceContainer = Color(0xFFE5E8EC);
  static const Color surfaceContainerHigh = Color(0xFFDFE3E7);
  static const Color surfaceContainerHighest = Color(0xFFD9DDE1);
  static const Color surfaceDim = Color(0xFFD0D5D9);
  static const Color surfaceBright = Color(0xFFF5F7FA);
  static const Color surfaceVariant = Color(0xFFD9DDE1);
  static const Color surfaceTint = Color(0xFF4C40DF);

  // Foreground
  static const Color onSurface = Color(0xFF2C2F32);
  static const Color onSurfaceVariant = Color(0xFF595C5E);
  static const Color onBackground = Color(0xFF2C2F32);
  static const Color outline = Color(0xFF74777A);
  static const Color outlineVariant = Color(0xFFABADB0);

  // Status
  static const Color error = Color(0xFFB41340);
  static const Color errorContainer = Color(0xFFF74B6D);
  static const Color errorDim = Color(0xFFA70138);
  static const Color onError = Color(0xFFFFEFEF);
  static const Color onErrorContainer = Color(0xFF510017);

  // Soft accents
  static const Color emeraldDot = Color(0xFF10B981);
  static const Color amber = Color(0xFFF59E0B);
  static const Color success = Color(0xFF10B981);

  // Booking-status colors (mapped to the design's tonal language)
  static Color statusColor(String? status) {
    switch (status) {
      case 'Ongoing':
        return primary;
      case 'Scheduled':
        return const Color(0xFF74B9FF);
      case 'Completed':
        return const Color(0xFF00B894);
      case 'Cancelled':
        return const Color(0xFF636E72);
      case 'No-Show':
        return errorContainer;
      case 'Request':
      default:
        return const Color(0xFFFDCB6E);
    }
  }
}

class FxRadii {
  static const Radius rSm = Radius.circular(8);
  static const Radius rMd = Radius.circular(12);
  static const Radius rLg = Radius.circular(15);
  static const Radius rXl = Radius.circular(24);
  static const Radius rFull = Radius.circular(9999);

  static BorderRadius all(Radius r) => BorderRadius.all(r);

  static const BorderRadius card = BorderRadius.all(rLg);
  static const BorderRadius pill = BorderRadius.all(rFull);
  static const BorderRadius input = BorderRadius.all(rLg);
  static const BorderRadius button = BorderRadius.all(Radius.circular(16));
  static const BorderRadius topSheet = BorderRadius.vertical(top: Radius.circular(28));
}

class FxShadows {
  /// Branded soft shadow — the only shadow we use for cards.
  /// `0 4px 20px rgba(76,64,223,0.05)` from the design system.
  static const List<BoxShadow> soft = [
    BoxShadow(
      color: Color(0x0D4C40DF),
      blurRadius: 20,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> button = [
    BoxShadow(
      color: Color(0x334C40DF),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> bottomNav = [
    BoxShadow(
      color: Color(0x144C40DF),
      blurRadius: 20,
      offset: Offset(0, -4),
    ),
  ];

  static const List<BoxShadow> sosButton = [
    BoxShadow(
      color: Color(0x33B41340),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];
}

class FxGradients {
  /// Signature indigo gradient used for primary CTAs and accent rails.
  static const LinearGradient indigo = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [FxColors.primary, FxColors.primaryContainer],
  );

  /// Horizontal version for accent bars (top of active card, bottom footer).
  static const LinearGradient indigoH = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [FxColors.primary, FxColors.primaryContainer],
  );

  static const LinearGradient indigoFooter = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [FxColors.primary, FxColors.primaryContainer, FxColors.secondary],
  );
}

/// Typography — Manrope for headlines (extra-bold), Inter for body/label.
/// Letter spacing `-0.02em` on headlines mirrors the Stitch tokens.
class FxText {
  static TextStyle _manrope({
    required double size,
    required FontWeight weight,
    Color color = FxColors.onSurface,
    double letterSpacing = 0,
    double? height,
  }) =>
      GoogleFonts.manrope(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  static TextStyle _inter({
    required double size,
    required FontWeight weight,
    Color color = FxColors.onSurface,
    double letterSpacing = 0,
    double? height,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  // Headlines — Manrope ExtraBold/Black with tight tracking
  static TextStyle displayLg({Color color = FxColors.onSurface}) =>
      _manrope(size: 56, weight: FontWeight.w900, color: color, letterSpacing: 6);
  static TextStyle displaySm({Color color = FxColors.onSurface}) =>
      _manrope(size: 28, weight: FontWeight.w800, color: color, letterSpacing: -0.6);
  static TextStyle headlineLg({Color color = FxColors.onSurface}) =>
      _manrope(size: 22, weight: FontWeight.w800, color: color, letterSpacing: -0.48);
  static TextStyle headlineMd({Color color = FxColors.onSurface}) =>
      _manrope(size: 18, weight: FontWeight.w800, color: color, letterSpacing: -0.4);
  static TextStyle headlineSm({Color color = FxColors.onSurface}) =>
      _manrope(size: 16, weight: FontWeight.w700, color: color, letterSpacing: -0.36);
  static TextStyle title({Color color = FxColors.onSurface}) =>
      _manrope(size: 15, weight: FontWeight.w700, color: color, letterSpacing: -0.32);
  static TextStyle titleSm({Color color = FxColors.onSurface}) =>
      _manrope(size: 13, weight: FontWeight.w700, color: color);

  // Body — Inter regular/medium
  static TextStyle bodyLg({Color color = FxColors.onSurface}) =>
      _inter(size: 15, weight: FontWeight.w500, color: color, height: 1.4);
  static TextStyle body({Color color = FxColors.onSurface}) =>
      _inter(size: 13, weight: FontWeight.w400, color: color, height: 1.4);
  static TextStyle bodySm({Color color = FxColors.onSurfaceVariant}) =>
      _inter(size: 11, weight: FontWeight.w400, color: color, height: 1.4);

  // Labels — Inter all-caps with wide tracking for metadata
  static TextStyle label({Color color = FxColors.onSurfaceVariant}) =>
      _inter(size: 11, weight: FontWeight.w500, color: color, letterSpacing: 0.8);
  static TextStyle labelSm({Color color = FxColors.onSurfaceVariant}) =>
      _inter(size: 9, weight: FontWeight.w500, color: color, letterSpacing: 1.5);
  static TextStyle labelXs({Color color = FxColors.outline}) =>
      _inter(size: 8, weight: FontWeight.w500, color: color, letterSpacing: 1.8);
}

/// MaterialApp ThemeData tuned to the Fluid Executive system.
ThemeData buildFxTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: FxColors.background,
    primaryColor: FxColors.primary,
    colorScheme: const ColorScheme.light(
      primary: FxColors.primary,
      onPrimary: FxColors.onPrimary,
      primaryContainer: FxColors.primaryContainer,
      onPrimaryContainer: FxColors.onPrimaryContainer,
      secondary: FxColors.secondary,
      onSecondary: FxColors.onSecondary,
      secondaryContainer: FxColors.secondaryContainer,
      tertiary: FxColors.tertiary,
      tertiaryContainer: FxColors.tertiaryContainer,
      error: FxColors.error,
      onError: FxColors.onError,
      surface: FxColors.surface,
      onSurface: FxColors.onSurface,
      surfaceContainerLowest: FxColors.surfaceContainerLowest,
      surfaceContainerLow: FxColors.surfaceContainerLow,
      surfaceContainer: FxColors.surfaceContainer,
      surfaceContainerHigh: FxColors.surfaceContainerHigh,
      surfaceContainerHighest: FxColors.surfaceContainerHighest,
      outline: FxColors.outline,
      outlineVariant: FxColors.outlineVariant,
    ),
    textTheme: GoogleFonts.interTextTheme().apply(
      bodyColor: FxColors.onSurface,
      displayColor: FxColors.onSurface,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: FxColors.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: null,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: FxColors.surfaceContainerLowest,
      selectedItemColor: FxColors.primary,
      unselectedItemColor: FxColors.outline,
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
