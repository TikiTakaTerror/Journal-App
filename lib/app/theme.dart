import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF006B5B),
      brightness: Brightness.light,
    );

    return _build(
      brightness: Brightness.light,
      scheme: scheme,
      scaffoldGradientEnd: const Color(0xFFF5F8F7),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2FAE94),
      brightness: Brightness.dark,
    );

    return _build(
      brightness: Brightness.dark,
      scheme: scheme,
      scaffoldGradientEnd: const Color(0xFF101715),
    );
  }

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required Color scaffoldGradientEnd,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
    );

    final textTheme = base.textTheme.copyWith(
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.4),
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: scheme.outlineVariant),
    );

    return base.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        clipBehavior: Clip.hardEdge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        color: Color.alphaBlend(
          scheme.primary.withValues(alpha: 0.03),
          scheme.surface,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Color.alphaBlend(
          scheme.primary.withValues(alpha: 0.04),
          scheme.surface,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          minimumSize: const Size(0, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          minimumSize: const Size(0, 44),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
      extensions: <ThemeExtension<dynamic>>[
        _GradientSurfaceTheme(scaffoldGradientEnd: scaffoldGradientEnd),
      ],
    );
  }
}

class _GradientSurfaceTheme extends ThemeExtension<_GradientSurfaceTheme> {
  const _GradientSurfaceTheme({required this.scaffoldGradientEnd});

  final Color scaffoldGradientEnd;

  @override
  _GradientSurfaceTheme copyWith({Color? scaffoldGradientEnd}) {
    return _GradientSurfaceTheme(
      scaffoldGradientEnd: scaffoldGradientEnd ?? this.scaffoldGradientEnd,
    );
  }

  @override
  _GradientSurfaceTheme lerp(
    ThemeExtension<_GradientSurfaceTheme>? other,
    double t,
  ) {
    if (other is! _GradientSurfaceTheme) {
      return this;
    }

    return _GradientSurfaceTheme(
      scaffoldGradientEnd:
          Color.lerp(scaffoldGradientEnd, other.scaffoldGradientEnd, t) ??
          scaffoldGradientEnd,
    );
  }
}
