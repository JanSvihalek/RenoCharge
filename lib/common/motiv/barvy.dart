import 'package:flutter/material.dart';

/// Barevné tokeny podle návrhu. Hodnoty jsou finální – neměnit bez úpravy
/// návrhové dokumentace (README v balíčku návrhu).
///
/// Akcentní barva je firemní modrá `#1B6FB8`. Ve světlém motivu se používá
/// přesně; v tmavém je na pozadí `#0A0D0B` moc tmavá (kontrast 3,8:1), proto
/// je zesvětlená při zachování odstínu i sytosti – viz [tmava].
@immutable
class AppBarvy extends ThemeExtension<AppBarvy> {
  const AppBarvy({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.textDim,
    required this.textFaint,
    required this.accent,
    required this.accentText,
    required this.accentDim,
    required this.stop,
    required this.stopText,
    required this.danger,
    required this.odznakDokoncenoBg,
    required this.odznakDokoncenoText,
    required this.odznakSchvalenoBg,
    required this.odznakSchvalenoText,
    required this.odznakProbihaBg,
    required this.odznakProbihaText,
  });

  final Color bg;
  final Color surface;
  final Color surface2;
  final Color border;
  final Color borderStrong;
  final Color text;
  final Color textDim;
  final Color textFaint;
  final Color accent;
  final Color accentText;
  final Color accentDim;
  final Color stop;
  final Color stopText;
  final Color danger;
  final Color odznakDokoncenoBg;
  final Color odznakDokoncenoText;
  final Color odznakSchvalenoBg;
  final Color odznakSchvalenoText;
  final Color odznakProbihaBg;
  final Color odznakProbihaText;

  static const AppBarvy tmava = AppBarvy(
    bg: Color(0xFF0A0D0B),
    surface: Color(0xFF151A16),
    surface2: Color(0xFF1D2420),
    border: Color(0xFF2B322C),
    borderStrong: Color(0xFF3B443C),
    text: Color(0xFFF3F5F0),
    textDim: Color(0xFFA6B0A4),
    textFaint: Color(0xFF71796F),
    // #1B6FB8 zesvětlená na HSL(208°, 74 %, 68 %) – stejný odstín i sytost,
    // ale na téměř černém pozadí drží kontrast 8,6:1 místo 3,8:1.
    accent: Color(0xFF71B1EA),
    accentText: Color(0xFF0A0D0B),
    accentDim: Color(0x2471B1EA), // rgba(113,177,234,0.14)
    stop: Color(0xFFFF7A45),
    stopText: Color(0xFF0A0D0B),
    danger: Color(0xFFFF6E5C),
    odznakDokoncenoBg: Color(0xFF20261F),
    odznakDokoncenoText: Color(0xFFA6B0A4),
    odznakSchvalenoBg: Color(0x2971B1EA), // rgba(113,177,234,0.16)
    odznakSchvalenoText: Color(0xFF71B1EA),
    odznakProbihaBg: Color(0x29FF7A45), // rgba(255,122,69,0.16)
    odznakProbihaText: Color(0xFFFF7A45),
  );

  static const AppBarvy svetla = AppBarvy(
    bg: Color(0xFFF2F3EE),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEAEBE3),
    border: Color(0xFFDCDFD4),
    borderStrong: Color(0xFFC3C7B8),
    text: Color(0xFF12150F),
    textDim: Color(0xFF5B6357),
    textFaint: Color(0xFF8A9285),
    accent: Color(0xFF1B6FB8),
    accentText: Color(0xFFFFFFFF),
    accentDim: Color(0x171B6FB8), // rgba(27,111,184,0.09)
    stop: Color(0xFFC6501F),
    stopText: Color(0xFFFFFFFF),
    danger: Color(0xFFC63B27),
    odznakDokoncenoBg: Color(0xFFEAEBE3),
    odznakDokoncenoText: Color(0xFF5B6357),
    odznakSchvalenoBg: Color(0x1A1B6FB8), // rgba(27,111,184,0.10)
    odznakSchvalenoText: Color(0xFF1B6FB8),
    odznakProbihaBg: Color(0x1FC6501F), // rgba(198,80,31,0.12)
    odznakProbihaText: Color(0xFFC6501F),
  );

  @override
  AppBarvy copyWith({
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? border,
    Color? borderStrong,
    Color? text,
    Color? textDim,
    Color? textFaint,
    Color? accent,
    Color? accentText,
    Color? accentDim,
    Color? stop,
    Color? stopText,
    Color? danger,
    Color? odznakDokoncenoBg,
    Color? odznakDokoncenoText,
    Color? odznakSchvalenoBg,
    Color? odznakSchvalenoText,
    Color? odznakProbihaBg,
    Color? odznakProbihaText,
  }) {
    return AppBarvy(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      text: text ?? this.text,
      textDim: textDim ?? this.textDim,
      textFaint: textFaint ?? this.textFaint,
      accent: accent ?? this.accent,
      accentText: accentText ?? this.accentText,
      accentDim: accentDim ?? this.accentDim,
      stop: stop ?? this.stop,
      stopText: stopText ?? this.stopText,
      danger: danger ?? this.danger,
      odznakDokoncenoBg: odznakDokoncenoBg ?? this.odznakDokoncenoBg,
      odznakDokoncenoText: odznakDokoncenoText ?? this.odznakDokoncenoText,
      odznakSchvalenoBg: odznakSchvalenoBg ?? this.odznakSchvalenoBg,
      odznakSchvalenoText: odznakSchvalenoText ?? this.odznakSchvalenoText,
      odznakProbihaBg: odznakProbihaBg ?? this.odznakProbihaBg,
      odznakProbihaText: odznakProbihaText ?? this.odznakProbihaText,
    );
  }

  @override
  AppBarvy lerp(ThemeExtension<AppBarvy>? other, double t) {
    if (other is! AppBarvy) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppBarvy(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surface2: l(surface2, other.surface2),
      border: l(border, other.border),
      borderStrong: l(borderStrong, other.borderStrong),
      text: l(text, other.text),
      textDim: l(textDim, other.textDim),
      textFaint: l(textFaint, other.textFaint),
      accent: l(accent, other.accent),
      accentText: l(accentText, other.accentText),
      accentDim: l(accentDim, other.accentDim),
      stop: l(stop, other.stop),
      stopText: l(stopText, other.stopText),
      danger: l(danger, other.danger),
      odznakDokoncenoBg: l(odznakDokoncenoBg, other.odznakDokoncenoBg),
      odznakDokoncenoText: l(odznakDokoncenoText, other.odznakDokoncenoText),
      odznakSchvalenoBg: l(odznakSchvalenoBg, other.odznakSchvalenoBg),
      odznakSchvalenoText: l(odznakSchvalenoText, other.odznakSchvalenoText),
      odznakProbihaBg: l(odznakProbihaBg, other.odznakProbihaBg),
      odznakProbihaText: l(odznakProbihaText, other.odznakProbihaText),
    );
  }
}

extension AppBarvyContext on BuildContext {
  /// Zkratka pro přístup k barevným tokenům: `context.barvy.accent`.
  AppBarvy get barvy => Theme.of(this).extension<AppBarvy>()!;
}
