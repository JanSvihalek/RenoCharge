import 'dart:typed_data';

import '../../elektromery/domain/elektromer.dart';
import '../../elektromery/domain/odecet.dart';
import '../../nabijeni/domain/relace.dart';

/// Období reportu. Uživatel zadává „od–do" včetně obou dnů, dotaz do
/// Firestore ale potřebuje horní mez exkluzivní – půlnoc následujícího
/// dne. Bez toho by poslední den vypadl, protože relace zahájená
/// v 7:12 je později než půlnoc téhož dne.
class Obdobi {
  Obdobi({required DateTime od, required DateTime doVcetne})
    : od = DateTime(od.year, od.month, od.day),
      doVcetne = DateTime(doVcetne.year, doVcetne.month, doVcetne.day);

  final DateTime od;
  final DateTime doVcetne;

  /// Následující půlnoc. Počítá se přes složky data, ne přidáním
  /// 24 hodin – v den, kdy se přechází na zimní čas, má den 25 hodin
  /// a `add(Duration(days: 1))` by skončilo ve 23:00 téhož dne. Jednou
  /// za rok by tak z reportu vypadla poslední hodina.
  DateTime get doExkluzivne => nasledujiciDen(doVcetne);

  static DateTime nasledujiciDen(DateTime den) =>
      DateTime(den.year, den.month, den.day + 1);

  /// Období navazující na poslední report: ode dne po jeho konci do
  /// dneška. `null`, když poslední report došel až do dneška nebo dál –
  /// pak není co nového vyexportovat.
  static Obdobi? navazujici(DateTime posledniDoVcetne, [DateTime? ted]) {
    final dnes = ted ?? DateTime.now();
    final od = nasledujiciDen(posledniDoVcetne);
    if (od.isAfter(DateTime(dnes.year, dnes.month, dnes.day))) return null;
    return Obdobi(od: od, doVcetne: dnes);
  }

  static Obdobi tentoMesic([DateTime? ted]) {
    final dnes = ted ?? DateTime.now();
    return Obdobi(od: DateTime(dnes.year, dnes.month), doVcetne: dnes);
  }

  static Obdobi minulyMesic([DateTime? ted]) {
    final dnes = ted ?? DateTime.now();
    final prvni = DateTime(dnes.year, dnes.month - 1);
    // Nultý den následujícího měsíce = poslední den toho minulého,
    // takže se nemusí řešit délka měsíce ani přestupné roky.
    return Obdobi(
      od: prvni,
      doVcetne: DateTime(prvni.year, prvni.month + 1, 0),
    );
  }
}

/// Jedno nabíjení v reportu i s fotkami staženými ze Storage.
class PolozkaReportu {
  const PolozkaReportu({
    required this.relace,
    required this.vozidlo,
    this.fotoStart,
    this.fotoEnd,
  });

  final Relace relace;

  /// Popis vozidla v době vytvoření reportu – značka z profilu, SPZ
  /// z relace.
  final String vozidlo;

  /// `null`, když se fotka nepodařila stáhnout nebo se report dělá
  /// bez fotek.
  final Uint8List? fotoStart;
  final Uint8List? fotoEnd;

  bool get maFotky => fotoStart != null || fotoEnd != null;
}

/// Vše, co generátor PDF potřebuje. Záměrně bez závislosti na Firebase
/// i na Flutteru, aby se skládání dokumentu dalo testovat.
class PodkladReportu {
  const PodkladReportu({
    required this.jmeno,
    required this.osobniCislo,
    required this.obdobi,
    required this.polozky,
    required this.vytvorenoAt,
  });

  final String jmeno;
  final String? osobniCislo;
  final Obdobi obdobi;
  final List<PolozkaReportu> polozky;
  final DateTime vytvorenoAt;

  double get celkovaSpotreba =>
      polozky.fold(0, (soucet, p) => soucet + (p.relace.spotreba ?? 0));

  bool get maNejakeFotky => polozky.any((p) => p.maFotky);
}

/// Jeden odečet v reportu elektroměru, se spotřebou i změnou proti
/// předchozímu období.
class PolozkaOdectu {
  const PolozkaOdectu({
    required this.odecet,
    this.spotreba,
    this.zmenaProcent,
    this.foto,
  });

  final Odecet odecet;

  /// Spotřeba od předchozího odečtu. `null` u nejstaršího a po výměně
  /// měřidla.
  final double? spotreba;

  /// O kolik procent se spotřeba liší od té předchozí. Tohle je ten údaj,
  /// kvůli kterému se odečty čtou – skokový nárůst je signál, že se něco
  /// děje.
  final double? zmenaProcent;

  final Uint8List? foto;
}

/// Vše, co generátor PDF potřebuje pro report jednoho elektroměru.
class PodkladElektromeru {
  const PodkladElektromeru({
    required this.elektromer,
    required this.obdobi,
    required this.polozky,
    required this.vytvorenoAt,
  });

  final Elektromer elektromer;
  final Obdobi obdobi;

  /// Od nejstaršího – u vývoje spotřeby se čte odshora dolů v čase.
  final List<PolozkaOdectu> polozky;

  final DateTime vytvorenoAt;

  double get celkovaSpotreba =>
      polozky.fold(0, (soucet, p) => soucet + (p.spotreba ?? 0));

  bool get maNejakeFotky => polozky.any((p) => p.foto != null);
}

/// Doplní ke každému odečtu spotřebu a změnu proti předchozímu období.
///
/// Vstup se čeká **od nejstaršího**. Spotřeba se neukládá, počítá se
/// z řady – uložená hodnota by zastarala při doplnění staršího odečtu.
List<PolozkaOdectu> slozPolozkyOdectu(
  List<Odecet> odNejstarsiho, {
  Map<String, Uint8List> fotky = const {},
}) {
  final vysledek = <PolozkaOdectu>[];
  double? predchoziSpotreba;

  for (var i = 0; i < odNejstarsiho.length; i++) {
    final o = odNejstarsiho[i];
    final predchozi = i > 0 ? odNejstarsiho[i - 1] : null;

    // Po výměně měřidla je rozdíl proti starému stavu nesmysl.
    final spotreba = (predchozi == null || o.vymenaMeridla)
        ? null
        : (o.hodnota - predchozi.hodnota).clamp(0, double.infinity).toDouble();

    final zmena =
        (spotreba != null && predchoziSpotreba != null && predchoziSpotreba > 0)
        ? (spotreba - predchoziSpotreba) / predchoziSpotreba * 100
        : null;

    vysledek.add(
      PolozkaOdectu(
        odecet: o,
        spotreba: spotreba,
        zmenaProcent: zmena,
        foto: fotky[o.id],
      ),
    );
    // Výměna měřidla řadu přeruší – další změna se počítá až od dalšího
    // úplného období.
    predchoziSpotreba = spotreba;
  }
  return vysledek;
}
