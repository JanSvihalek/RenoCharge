import 'package:intl/intl.dart';

/// Formátování a parsování hodnot zobrazovaných v UI. Vše v české lokalizaci.
abstract final class Format {
  static final NumberFormat _kwh = NumberFormat('#,##0.0', 'cs_CZ');
  static final DateFormat _datum = DateFormat('d. M. y', 'cs_CZ');
  static final DateFormat _cas = DateFormat('HH:mm', 'cs_CZ');

  /// Stav počítadla nebo spotřeba: `18 342,4`.
  static String kwh(num hodnota) => _kwh.format(hodnota);

  /// `1. 8. 2026`
  static String datum(DateTime cas) => _datum.format(cas.toLocal());

  /// `07:12`
  static String cas(DateTime cas) => _cas.format(cas.toLocal());

  /// `07:12 – 12:44`, u neukončené relace `07:12 – …`.
  static String rozsahCasu(DateTime od, DateTime? do_) =>
      '${cas(od)} – ${do_ == null ? '…' : cas(do_)}';

  /// `5 h 32 min`, pro krátké relace `45 min`.
  static String doba(Duration d) {
    final minuty = d.inMinutes;
    if (minuty < 60) return '$minuty min';
    final h = minuty ~/ 60;
    final m = minuty % 60;
    return '$h h ${m.toString().padLeft(2, '0')} min';
  }

  /// Převede text z pole na číslo. Přijímá desetinnou čárku i tečku,
  /// mezery i pevné mezery jako oddělovač tisíců. Vrací `null`, pokud
  /// hodnota nedává smysl.
  static double? parsujKwh(String? vstup) {
    if (vstup == null) return null;
    final ocisteny = vstup
        .replaceAll(RegExp(r'[\s  ]'), '')
        .replaceAll(',', '.');
    if (ocisteny.isEmpty) return null;
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(ocisteny)) return null;
    final hodnota = double.tryParse(ocisteny);
    if (hodnota == null || !hodnota.isFinite || hodnota < 0) return null;
    return hodnota;
  }
}
