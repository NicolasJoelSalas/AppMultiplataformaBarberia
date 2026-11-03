import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF284B70))
        .copyWith(
          primary: const Color(0xFF284B70),
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFB9CEE3),
          onPrimaryContainer: const Color(0xFF15324F),
          secondary: const Color(0xFF4D6175),
          secondaryContainer: const Color(0xFFCAD7E3),
          tertiary: const Color(0xFF23675E),
          surface: const Color(0xFFE5EBF1),
          onSurface: const Color(0xFF1D2935),
          onSurfaceVariant: const Color(0xFF374B5E),
          surfaceContainerLow: const Color(0xFFE1E8EF),
          outline: const Color(0xFF586D81),
          outlineVariant: const Color(0xFF8497AA),
          error: const Color(0xFFAD302B),
          errorContainer: const Color(0xFFFFE3DF),
          onErrorContainer: const Color(0xFF721D19),
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFD8E1EA),
    );
  }

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFD0BCFF),
      brightness: Brightness.dark,
    ),
  );
}
