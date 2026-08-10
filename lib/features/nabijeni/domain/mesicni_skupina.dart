import '../../reporty/domain/zaznam_exportu.dart';
import 'relace.dart';

/// Relace jednoho měsíce i s jeho součtem – podklad pro předěly
/// v historii.
class MesicniSkupina {
  const MesicniSkupina({
    required this.mesic,
    required this.relace,
    this.exporty = const [],
  });

  /// První den měsíce, ke kterému skupina patří.
  final DateTime mesic;

  /// Relace v tom pořadí, v jakém přišly z historie (od nejnovější).
  final List<Relace> relace;

  /// Reporty, jejichž období tímhle měsícem **začíná**, od nejnovějšího.
  ///
  /// Řadí se podle začátku období, ne podle dne vytvoření: report za
  /// červenec se dělá až v srpnu a odpovídá na otázku „mám červenec
  /// hotový?", ne „co jsem dělal v srpnu".
  final List<ZaznamExportu> exporty;

  /// Součet spotřeby za měsíc. Běžící relace se nezapočítává – ještě
  /// nemá koncový stav, takže by se součet po jejím ukončení změnil
  /// a mezitím by tvrdil něco, co neplatí.
  double get celkemKwh =>
      relace.fold(0, (soucet, r) => soucet + (r.spotreba ?? 0));

  int get pocetDokoncenych => relace.where((r) => !r.probiha).length;
}

/// Rozdělí historii po měsících podle času zahájení.
///
/// Pořadí skupin i relací uvnitř nich kopíruje vstup, nic se nepřerovnává –
/// historie chodí seřazená od nejnovější a předěly mají jen doplnit,
/// co už v seznamu je. Měsíc bez relací nevznikne; když někdo v srpnu
/// nenabíjel, prostě tam žádný srpen není – a report za takový měsíc se
/// v historii neukáže. Od kdy navázat příště se v tom případě dozví
/// z obrazovky exportu, která poslední report zná vždycky.
List<MesicniSkupina> seskupPoMesicich(
  List<Relace> relace, {
  List<ZaznamExportu> exporty = const [],
}) {
  // Klíčem je první den měsíce – DateTime má hodnotovou rovnost, takže
  // se dá použít přímo jako klíč mapy.
  DateTime mesicOf(DateTime cas) {
    final kdy = cas.toLocal();
    return DateTime(kdy.year, kdy.month);
  }

  final skupiny = <DateTime, List<Relace>>{};
  for (final r in relace) {
    skupiny.putIfAbsent(mesicOf(r.zahajeno), () => []).add(r);
  }

  final exportyMesice = <DateTime, List<ZaznamExportu>>{};
  for (final e in exporty) {
    final klic = mesicOf(e.obdobi.od);
    // Report za měsíc, ve kterém se nenabíjelo, nemá kam patřit.
    if (skupiny.containsKey(klic)) {
      exportyMesice.putIfAbsent(klic, () => []).add(e);
    }
  }

  return [
    for (final polozka in skupiny.entries)
      MesicniSkupina(
        mesic: polozka.key,
        relace: polozka.value,
        exporty: exportyMesice[polozka.key] ?? const [],
      ),
  ];
}
