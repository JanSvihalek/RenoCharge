import 'druh_mista.dart';
import 'pobocka.dart';

/// Jedno odběrné místo z výchozího seznamu.
class VychoziMisto {
  const VychoziMisto(this.pobocka, this.druh, this.nazev);

  final Pobocka pobocka;
  final DruhMista druh;
  final String nazev;

  /// Pevné ID dokumentu, např. `bsl-plyn-hp-ripska`.
  ///
  /// Pevné, ne náhodné, aby šlo založení spustit znovu bez duplicit:
  /// když se napoprvé povede jen část, druhý pokus doplní jen to, co
  /// chybí. A přejmenování místa v aplikaci na ID nic nemění, takže se
  /// nezaloží podruhé pod starým názvem.
  String get id => [pobocka.kod, druh.klic, nazev].map(_slug).join('-');

  static String _slug(String text) {
    const s = 'áčďéěíňóřšťúůýžÁČĎÉĚÍŇÓŘŠŤÚŮÝŽ';
    const bez = 'acdeeinorstuuyzACDEEINORSTUUYZ';
    final buffer = StringBuffer();
    for (final znak in text.split('')) {
      final i = s.indexOf(znak);
      buffer.write(i >= 0 ? bez[i] : znak);
    }
    return buffer
        .toString()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }
}

/// Odběrná místa, se kterými se evidence rozjíždí – přepis tabulky od
/// zadavatele (Brno, říjen 2026).
///
/// Jsou v kódu ze stejného důvodu jako pobočky a ze stejného důvodu je
/// zakládá aplikace: servisní účet pro skript zadavatel odmítl, takže
/// zapisovat do evidence umí jen přihlášená údržba. Ta je založí jedním
/// tlačítkem v seznamu, dokud některé chybí. Další místa se přidávají
/// formulářem.
///
/// V tabulce bylo „BDC, Moto" u elektřiny dvakrát – podle zadavatele
/// omylem, je tu jednou.
const List<VychoziMisto> vychoziMista = [
  // ── Plyn ──
  VychoziMisto(Pobocka.bsl, DruhMista.plyn, 'HP Řípská'),
  VychoziMisto(Pobocka.bsl, DruhMista.plyn, 'Myčka'),
  VychoziMisto(Pobocka.bsl, DruhMista.plyn, 'BDC'),
  VychoziMisto(Pobocka.bsl, DruhMista.plyn, 'Motoservis'),
  VychoziMisto(Pobocka.bsl, DruhMista.plyn, 'Premium'),
  VychoziMisto(Pobocka.bsl, DruhMista.plyn, 'Účtárna'),
  VychoziMisto(Pobocka.bsl, DruhMista.plyn, 'OMKO'),
  VychoziMisto(Pobocka.bsl, DruhMista.plyn, 'Patro jídelna'),
  VychoziMisto(Pobocka.bsl, DruhMista.plyn, 'HP Šmahova'),
  VychoziMisto(Pobocka.bsl, DruhMista.plyn, 'Servis'),
  VychoziMisto(Pobocka.bsl, DruhMista.plyn, 'Stará hala'),
  VychoziMisto(Pobocka.bsl, DruhMista.plyn, 'HP Drážní'),
  VychoziMisto(Pobocka.bsl, DruhMista.plyn, 'Kotelna'),
  VychoziMisto(Pobocka.bsl, DruhMista.plyn, 'SB.Prodejna'),
  VychoziMisto(Pobocka.bsl, DruhMista.plyn, 'SB.Sklad'),
  VychoziMisto(Pobocka.bsl, DruhMista.plyn, 'Veteráni Reno'),
  VychoziMisto(Pobocka.bsl, DruhMista.plyn, 'Reno'),

  // ── Elektřina ──
  VychoziMisto(Pobocka.bsl, DruhMista.elektrina, 'BMW Salon'),
  VychoziMisto(Pobocka.bsl, DruhMista.elektrina, 'Myčka'),
  VychoziMisto(Pobocka.bsl, DruhMista.elektrina, 'BDC, Moto'),
  VychoziMisto(Pobocka.bsl, DruhMista.elektrina, 'Servis'),
  VychoziMisto(Pobocka.bsl, DruhMista.elektrina, 'Venkovní osv.'),
  VychoziMisto(Pobocka.bsl, DruhMista.elektrina, 'Premium 1'),
  VychoziMisto(Pobocka.bsl, DruhMista.elektrina, 'Premium 2'),
  VychoziMisto(Pobocka.bsl, DruhMista.elektrina, 'Stará hala'),
  VychoziMisto(Pobocka.bsl, DruhMista.elektrina, 'Jídelna'),
  VychoziMisto(Pobocka.bsl, DruhMista.elektrina, 'Účtárna'),
  VychoziMisto(Pobocka.bsl, DruhMista.elektrina, 'Drážní x50'),
  VychoziMisto(Pobocka.bsl, DruhMista.elektrina, 'Lakovna x40'),
  VychoziMisto(Pobocka.bsl, DruhMista.elektrina, 'Nájemník Drážní Salon'),
  VychoziMisto(Pobocka.bsl, DruhMista.elektrina, 'Nájemník Drážní patro'),
  VychoziMisto(Pobocka.bsl, DruhMista.elektrina, 'SB.Comp'),
  VychoziMisto(Pobocka.bsl, DruhMista.elektrina, 'OMKO 1'),
  VychoziMisto(Pobocka.bsl, DruhMista.elektrina, 'OMKO 2'),
  VychoziMisto(Pobocka.bsl, DruhMista.elektrina, 'Patro jídelna'),
  VychoziMisto(Pobocka.bsl, DruhMista.elektrina, 'Nájemník Přístavek'),
  VychoziMisto(Pobocka.bsl, DruhMista.elektrina, 'Ostraha'),
  VychoziMisto(Pobocka.bsl, DruhMista.elektrina, 'Bistro kuchyň'),
  VychoziMisto(Pobocka.bsl, DruhMista.elektrina, 'Víno'),
  VychoziMisto(Pobocka.bsl, DruhMista.elektrina, 'Bistro bojler'),

  // ── Klimatizace ──
  VychoziMisto(Pobocka.bsl, DruhMista.klimatizace, 'BMW Salon 1'),
  VychoziMisto(Pobocka.bsl, DruhMista.klimatizace, 'BMW Salon 2'),
  VychoziMisto(Pobocka.bsl, DruhMista.klimatizace, 'BMW Salon 5x'),
  VychoziMisto(Pobocka.bsl, DruhMista.klimatizace, 'Stará hala'),
  VychoziMisto(Pobocka.bsl, DruhMista.klimatizace, 'Premium LG 1'),
  VychoziMisto(Pobocka.bsl, DruhMista.klimatizace, 'Premium LG 2'),
  VychoziMisto(Pobocka.bsl, DruhMista.klimatizace, 'Premium SINC 1'),
  VychoziMisto(Pobocka.bsl, DruhMista.klimatizace, 'Premium SINC 2'),
  VychoziMisto(Pobocka.bsl, DruhMista.klimatizace, 'Premium SINC 3'),
  VychoziMisto(Pobocka.bsl, DruhMista.klimatizace, 'Premium SINC 4'),
  VychoziMisto(Pobocka.bsl, DruhMista.klimatizace, 'Servis'),
  VychoziMisto(Pobocka.bsl, DruhMista.klimatizace, 'Isetta'),
  VychoziMisto(Pobocka.bsl, DruhMista.klimatizace, 'BMW server 1'),
  VychoziMisto(Pobocka.bsl, DruhMista.klimatizace, 'BMW server 2'),
  VychoziMisto(Pobocka.bsl, DruhMista.klimatizace, 'OMKO'),
  VychoziMisto(Pobocka.bsl, DruhMista.klimatizace, 'MINI 1'),
  VychoziMisto(Pobocka.bsl, DruhMista.klimatizace, 'MINI 2'),
  VychoziMisto(Pobocka.bsl, DruhMista.klimatizace, 'Účtárna'),

  // ── Nabíječky ──
  VychoziMisto(Pobocka.bsl, DruhMista.nabijecka, 'Parkoviště 1'),
  VychoziMisto(Pobocka.bsl, DruhMista.nabijecka, 'Parkoviště 2'),
  VychoziMisto(Pobocka.bsl, DruhMista.nabijecka, 'Parkoviště 3'),
  VychoziMisto(Pobocka.bsl, DruhMista.nabijecka, 'Parkoviště 4'),
  VychoziMisto(Pobocka.bsl, DruhMista.nabijecka, 'Parkoviště 5'),
  VychoziMisto(Pobocka.bsl, DruhMista.nabijecka, 'Parkoviště 6'),
  VychoziMisto(Pobocka.bsl, DruhMista.nabijecka, 'Parkoviště DC'),
  VychoziMisto(Pobocka.bsl, DruhMista.nabijecka, 'Přístřešek 1'),
  VychoziMisto(Pobocka.bsl, DruhMista.nabijecka, 'Přístřešek 2'),
  VychoziMisto(Pobocka.bsl, DruhMista.nabijecka, 'Přístřešek 3'),
  VychoziMisto(Pobocka.bsl, DruhMista.nabijecka, 'Přístřešek 4'),
  VychoziMisto(Pobocka.bsl, DruhMista.nabijecka, 'Přístřešek DC'),
  VychoziMisto(Pobocka.bsl, DruhMista.nabijecka, 'BMW Salon 1'),
  VychoziMisto(Pobocka.bsl, DruhMista.nabijecka, 'BMW Salon 2'),
  VychoziMisto(Pobocka.bsl, DruhMista.nabijecka, 'Servis'),
  VychoziMisto(Pobocka.bsl, DruhMista.nabijecka, 'Klempírna'),
  VychoziMisto(Pobocka.bsl, DruhMista.nabijecka, 'Předávačka'),
  VychoziMisto(Pobocka.bsl, DruhMista.nabijecka, 'ČEZ Brno'),
];
