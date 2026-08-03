import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'barvy.dart';
import 'rozmery.dart';

/// Sestavení světlého a tmavého motivu z návrhových tokenů.
///
/// Písma: Space Grotesk pro nadpisy, velká čísla a tlačítka, Inter pro běžný
/// text (viz [textovyMotiv]). Hodnota z počítadla se sází monospacem – to řeší
/// přímo obrazovka focení.
abstract final class Motiv {
  static ThemeData svetly() => _sestav(AppBarvy.svetla, Brightness.light);

  static ThemeData tmavy() => _sestav(AppBarvy.tmava, Brightness.dark);

  static ThemeData _sestav(AppBarvy b, Brightness jas) {
    final text = textovyMotiv(b);
    return ThemeData(
      useMaterial3: true,
      brightness: jas,
      scaffoldBackgroundColor: b.bg,
      canvasColor: b.bg,
      dividerColor: b.border,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      colorScheme: ColorScheme.fromSeed(seedColor: b.accent, brightness: jas)
          .copyWith(
            surface: b.surface,
            onSurface: b.text,
            primary: b.accent,
            onPrimary: b.accentText,
            error: b.danger,
          ),
      textTheme: text,
      extensions: <ThemeExtension<dynamic>>[b],
      snackBarTheme: SnackBarThemeData(
        backgroundColor: b.surface2,
        contentTextStyle: text.bodyLarge?.copyWith(color: b.text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Rozmery.radiusMale),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: b.surface2,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        hintStyle: text.bodyLarge?.copyWith(color: b.textFaint),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Rozmery.radiusMale),
          borderSide: BorderSide(color: b.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Rozmery.radiusMale),
          borderSide: BorderSide(color: b.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Rozmery.radiusMale),
          borderSide: BorderSide(color: b.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Rozmery.radiusMale),
          borderSide: BorderSide(color: b.danger, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Rozmery.radiusMale),
          borderSide: BorderSide(color: b.danger, width: 2),
        ),
      ),
    );
  }

  static TextTheme textovyMotiv(AppBarvy b) {
    TextStyle nadpis(double velikost, {FontWeight vaha = FontWeight.w700}) =>
        GoogleFonts.spaceGrotesk(
          fontSize: velikost,
          fontWeight: vaha,
          color: b.text,
          height: 1.2,
        );
    TextStyle telo(
      double velikost, {
      FontWeight vaha = FontWeight.w400,
      Color? barva,
    }) => GoogleFonts.inter(
      fontSize: velikost,
      fontWeight: vaha,
      color: barva ?? b.text,
      height: 1.4,
    );

    return TextTheme(
      // Velké číslo spotřeby.
      displaySmall: nadpis(34),
      // Nadpis přihlašovací obrazovky.
      headlineMedium: nadpis(30),
      // Nadpisy sekcí typu „Historie“, „Moje vozidla“.
      headlineSmall: nadpis(28),
      // Pozdrav na domovské obrazovce.
      titleLarge: nadpis(24),
      // Název vozidla v kartě aktivní relace.
      titleMedium: nadpis(20),
      // Titulek v hlavičce toku.
      titleSmall: nadpis(18),
      // Hodnota v seznamech a kartách.
      bodyLarge: telo(15.5, vaha: FontWeight.w600),
      bodyMedium: telo(15),
      // Popisek nad hodnotou.
      bodySmall: telo(12.5, barva: b.textDim),
      // Text tlačítek.
      labelLarge: nadpis(17),
      // Nadpis sekce (verzálky).
      labelMedium: telo(
        13,
        vaha: FontWeight.w700,
        barva: b.textFaint,
      ).copyWith(letterSpacing: 0.4),
      // Text odznaku stavu.
      labelSmall: telo(11, vaha: FontWeight.w700).copyWith(letterSpacing: 0.4),
    );
  }

  /// Styl pro číslo z počítadla – monospace, aby se číslice nerozjížděly.
  static TextStyle pocitadlo(AppBarvy b) => GoogleFonts.robotoMono(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: b.text,
  );
}
