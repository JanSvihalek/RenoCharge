import 'package:intl/intl.dart';

/// Formátování a parsování hodnot zobrazovaných v UI. Vše v české lokalizaci.
abstract final class Format {
  /// Dvě desetinná místa schválně: počítadla nabíječek je tak ukazují
  /// a na jedno by se `27,49` zobrazilo jako `27,5`. Zaokrouhlení nahoru
  /// u podkladu k fakturaci nikdo vidět nechce, i když se počítá vždycky
  /// z přesné hodnoty a ne z té zobrazené.
  static final NumberFormat _kwh = NumberFormat('#,##0.00', 'cs_CZ');
  static final NumberFormat _castka = NumberFormat('#,##0.00', 'cs_CZ');
  static final NumberFormat _sazba = NumberFormat('#,##0.00', 'cs_CZ');
  static final DateFormat _datum = DateFormat('d. M. y', 'cs_CZ');
  static final DateFormat _mesic = DateFormat('LLLL y', 'cs_CZ');
  static final DateFormat _cas = DateFormat('HH:mm', 'cs_CZ');

  /// Stav počítadla nebo spotřeba: `18 342,4`.
  static String kwh(num hodnota) => _kwh.format(hodnota);

  /// Orientační částka: `178,50 Kč`. Na haléře, protože sazba je taky
  /// na haléře a zaokrouhlení nahoru by u malých odběrů mátlo.
  static String castka(num hodnota) => '${_castka.format(hodnota)} Kč';

  /// Sazba za kilowatthodinu: `6,50 Kč/kWh`.
  static String sazba(num hodnota) => '${_sazba.format(hodnota)} Kč/kWh';

  /// `1. 8. 2026`
  static String datum(DateTime cas) => _datum.format(cas.toLocal());

  /// `Červenec 2026` – pro předěly mezi měsíci v historii.
  ///
  /// `LLLL` je samostatný tvar názvu měsíce („červenec"), zatímco `MMMM`
  /// dává druhý pád („července"), který dává smysl jen uvnitř data.
  static String mesicARok(DateTime cas) {
    final text = _mesic.format(cas.toLocal());
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

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
