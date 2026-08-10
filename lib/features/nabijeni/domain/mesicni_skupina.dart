import '../../reporty/domain/zaznam_exportu.dart';
import 'relace.dart';

/// Jeden řádek historie: buď nabíjení, nebo stopa po vytvořeném reportu.
sealed class PolozkaHistorie {
  const PolozkaHistorie();

  /// Čas, podle kterého se položka řadí mezi ostatní.
  DateTime get kdy;
}

class PolozkaRelace extends PolozkaHistorie {
  const PolozkaRelace(this.relace);

  final Relace relace;

  @override
  DateTime get kdy => relace.zahajeno;
}

/// Report i s tím, kolik za jeho období aplikace v historii našla.
///
/// Spotřeba se k reportu **neukládá**, dopočítává se z relací – stejně
/// jako orientační částka, která se počítá z aktuální sazby. Uložené
/// číslo by po změně sazby přestalo sedět se zbytkem obrazovky.
class ExportSeSpotrebou {
  const ExportSeSpotrebou({required this.export, required this.celkemKwh});

  final ZaznamExportu export;

  /// Součet spotřeby dokončených relací, které do období spadají.
  /// Počítá se z **načtené** historie, takže u starých období nad rámec
  /// jejího limitu může být nižší – stejně jako měsíční součty.
  final double celkemKwh;
}

class PolozkaExportu extends PolozkaHistorie {
  const PolozkaExportu(this.polozka);

  final ExportSeSpotrebou polozka;

  ZaznamExportu get export => polozka.export;

  /// Řadí se **koncem** posledního zahrnutého dne, ne jeho půlnocí.
  /// Nabíjení, které toho dne v osm ráno začalo, report ještě obsahuje,
  /// takže musí zůstat pod čarou – jinak by to vypadalo, že vypadlo.
  @override
  DateTime get kdy {
    final den = export.obdobi.doVcetne;
    return DateTime(den.year, den.month, den.day, 23, 59, 59, 999);
  }
}

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

  /// Reporty, jejichž období tímhle měsícem **končí**, od nejnovějšího.
  final List<ExportSeSpotrebou> exporty;

  /// Relace i reporty v jedné řadě od nejnovějšího.
  ///
  /// Smysl toho míchání: pod řádkem reportu leží přesně ta nabíjení,
  /// která už zahrnul. Stačí se podívat, kde čára je, a ví se, kde příště
  /// navázat – kvůli tomu se stopy po reportech vedou.
  List<PolozkaHistorie> get polozky {
    final vsechny = <PolozkaHistorie>[
      for (final r in relace) PolozkaRelace(r),
      for (final e in exporty) PolozkaExportu(e),
    ];
    // Stabilní řazení: relace přišly z historie už seřazené a při shodě
    // časů se jejich vzájemné pořadí nemá měnit.
    vsechny.sort((a, b) => b.kdy.compareTo(a.kdy));
    return vsechny;
  }

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
/// nenabíjel, prostě tam žádný srpen není – a report končící v takovém
/// měsíci se v historii neukáže. Od kdy navázat příště se v tom případě
/// dozví z obrazovky exportu, která poslední report zná vždycky.
///
/// Reporty se řadí podle **konce** svého období, ne podle začátku ani
/// podle dne vytvoření. Jen tak sedí mezi relace: co je pod čarou, to
/// report zahrnul.
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

  // Součet se počítá přes **celou** historii, ne přes měsíc skupiny:
  // období reportu bývá 15. 7. – 5. 8., tedy přes předěl.
  double spotrebaZa(ZaznamExportu e) {
    var soucet = 0.0;
    for (final r in relace) {
      final kdy = r.zahajeno;
      if (!kdy.isBefore(e.obdobi.od) && kdy.isBefore(e.obdobi.doExkluzivne)) {
        soucet += r.spotreba ?? 0;
      }
    }
    return soucet;
  }

  final exportyMesice = <DateTime, List<ExportSeSpotrebou>>{};
  for (final e in exporty) {
    final klic = mesicOf(e.obdobi.doVcetne);
    // Report končící v měsíci, ve kterém se nenabíjelo, nemá kam patřit.
    if (skupiny.containsKey(klic)) {
      exportyMesice
          .putIfAbsent(klic, () => [])
          .add(ExportSeSpotrebou(export: e, celkemKwh: spotrebaZa(e)));
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
