import 'relace.dart';

/// Relace jednoho měsíce i s jeho součtem – podklad pro předěly
/// v historii.
class MesicniSkupina {
  const MesicniSkupina({required this.mesic, required this.relace});

  /// První den měsíce, ke kterému skupina patří.
  final DateTime mesic;

  /// Relace v tom pořadí, v jakém přišly z historie (od nejnovější).
  final List<Relace> relace;

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
/// nenabíjel, prostě tam žádný srpen není.
List<MesicniSkupina> seskupPoMesicich(List<Relace> relace) {
  final skupiny = <DateTime, List<Relace>>{};
  for (final r in relace) {
    final kdy = r.zahajeno.toLocal();
    // Klíčem je první den měsíce – DateTime má hodnotovou rovnost, takže
    // se dá použít přímo jako klíč mapy.
    final klic = DateTime(kdy.year, kdy.month);
    skupiny.putIfAbsent(klic, () => []).add(r);
  }
  return [
    for (final polozka in skupiny.entries)
      MesicniSkupina(mesic: polozka.key, relace: polozka.value),
  ];
}
