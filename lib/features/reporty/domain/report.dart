import 'dart:typed_data';

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

  DateTime get doExkluzivne => doVcetne.add(const Duration(days: 1));

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
