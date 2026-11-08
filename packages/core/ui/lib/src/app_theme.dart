import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF284B70))
        .copyWith(
          primary: const Color(0xFF284B70),
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFB9CEE3),
          onPrimaryContainer: const Color(0xFF15324F),
          inversePrimary: const Color(0xFFAACBEF),
          secondary: const Color(0xFF4D6175),
          onSecondary: Colors.white,
          secondaryContainer: const Color(0xFFCAD7E3),
          onSecondaryContainer: const Color(0xFF253A4D),
          tertiary: const Color(0xFF23675E),
          onTertiary: Colors.white,
          tertiaryContainer: const Color(0xFFB8D8CC),
          onTertiaryContainer: const Color(0xFF12483F),
          surface: const Color(0xFFE5EBF1),
          onSurface: const Color(0xFF1D2935),
          onSurfaceVariant: const Color(0xFF374B5E),
          surfaceDim: const Color(0xFFC4D0DD),
          surfaceBright: const Color(0xFFEDF2F6),
          surfaceContainerLowest: const Color(0xFFEDF2F6),
          surfaceContainerLow: const Color(0xFFE1E8EF),
          surfaceContainer: const Color(0xFFEDF2F6),
          surfaceContainerHigh: const Color(0xFFD2DEE9),
          surfaceContainerHighest: const Color(0xFFC4D3E1),
          outline: const Color(0xFF586D81),
          outlineVariant: const Color(0xFF8497AA),
          inverseSurface: const Color(0xFF293643),
          onInverseSurface: const Color(0xFFF1F5F9),
          error: const Color(0xFFAD302B),
          onError: Colors.white,
          errorContainer: const Color(0xFFFFE3DF),
          onErrorContainer: const Color(0xFF721D19),
          scrim: const Color(0xFF101C29),
        );
    return _withTypography(scheme)
        .copyWith(scaffoldBackgroundColor: const Color(0xFFD8E1EA));
  }

  static ThemeData get dark => _withTypography(
    ColorScheme.fromSeed(
      seedColor: const Color(0xFFD0BCFF),
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFFD0BCFF),
      secondary: const Color(0xFFCCC2DC),
      tertiary: const Color(0xFFEFB8C8),
    ),
  );

  static ThemeData _withTypography(ColorScheme scheme) {
    final theme = ThemeData(useMaterial3: true, colorScheme: scheme);
    return theme.copyWith(
      textTheme: theme.textTheme.copyWith(
        titleLarge: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: theme.textTheme.headlineMedium?.copyWith(
          fontSize: 24,
          height: 32 / 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
