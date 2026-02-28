import 'package:flutter/material.dart';

class AppTypography {
  const AppTypography._();

  static const String bodyFontFamily = 'Manrope';
  static const String displayFontFamily = 'Newsreader';

  static TextTheme build(TextTheme base) {
    final seededBase = base.apply(fontFamily: bodyFontFamily);
    TextStyle themed(TextStyle? style, {
      FontWeight? weight,
      double? letterSpacing,
      double? height,
      String? fontFamily,
    }) {
      return (style ?? const TextStyle()).copyWith(
        fontWeight: weight ?? style?.fontWeight,
        letterSpacing: letterSpacing ?? style?.letterSpacing,
        height: height ?? style?.height,
        fontFamily: fontFamily ?? style?.fontFamily,
      );
    }

    return seededBase.copyWith(
      displaySmall: themed(
        seededBase.displaySmall,
        weight: FontWeight.w700,
        letterSpacing: -0.8,
        height: 1.02,
        fontFamily: displayFontFamily,
      ),
      headlineLarge: themed(
        seededBase.headlineLarge,
        weight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.08,
        fontFamily: displayFontFamily,
      ),
      headlineMedium: themed(
        seededBase.headlineMedium,
        weight: FontWeight.w700,
        letterSpacing: -0.35,
        height: 1.1,
        fontFamily: displayFontFamily,
      ),
      headlineSmall: themed(
        seededBase.headlineSmall,
        weight: FontWeight.w700,
        letterSpacing: -0.2,
        height: 1.14,
        fontFamily: displayFontFamily,
      ),
      titleLarge: themed(
        seededBase.titleLarge,
        weight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: themed(
        seededBase.titleMedium,
        weight: FontWeight.w600,
      ),
      titleSmall: themed(
        seededBase.titleSmall,
        weight: FontWeight.w600,
      ),
      bodyLarge: themed(seededBase.bodyLarge, height: 1.5),
      bodyMedium: themed(seededBase.bodyMedium, height: 1.48),
      bodySmall: themed(seededBase.bodySmall, height: 1.35),
      labelLarge: themed(seededBase.labelLarge, weight: FontWeight.w600),
      labelMedium: themed(seededBase.labelMedium, weight: FontWeight.w600),
    );
  }
}
