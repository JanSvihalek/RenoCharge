import 'package:flutter_test/flutter_test.dart';
import 'package:renocharge/features/elektromery/domain/druh_mista.dart';
import 'package:renocharge/features/elektromery/domain/elektromer.dart';
import 'package:renocharge/features/elektromery/domain/identifikace.dart';
import 'package:renocharge/features/elektromery/domain/pobocka.dart';
import 'package:renocharge/features/elektromery/domain/vychozi_mista.dart';

Elektromer _misto({
  String id = 'm1',
  String cislo = '',
  String nazev = 'Kotelna',
  DruhMista druh = DruhMista.plyn,
}) => Elektromer(
  id: id,
  pobockaKod: 'BSL',
  cislo: cislo,
  nazev: nazev,
  druh: druh,
);

void main() {
  group('DruhMista', () {
    test('zná klíče z Firestore', () {
      for (final d in DruhMista.values) {
        expect(DruhMista.zKlice(d.klic), d);
      }
    });

    // Dokumenty z doby, kdy evidence uměla jen elektroměry, pole nemají.
    test('chybějící nebo neznámý druh je elektřina', () {
      expect(DruhMista.zKlice(null), DruhMista.elektrina);
      expect(DruhMista.zKlice('voda'), DruhMista.elektrina);
    });

    test('plyn se odečítá v m³, ostatní v kWh', () {
      expect(DruhMista.plyn.jednotka, 'm³');
      expect(DruhMista.elektrina.jednotka, 'kWh');
      expect(DruhMista.klimatizace.jednotka, 'kWh');
      expect(DruhMista.nabijecka.jednotka, 'kWh');
    });

    test('místo bez druhu je elektřina', () {
      const misto = Elektromer(
        id: 'e1',
        pobockaKod: 'BSL',
        cislo: '18 342 771',
        nazev: 'Hala B',
      );
      expect(misto.druh, DruhMista.elektrina);
    });
  });

  group('odběrné místo bez výrobního čísla', () {
    test('se pozná podle prázdného čísla', () {
      expect(_misto().maCislo, isFalse);
      expect(_misto(cislo: '18 342 771').maCislo, isTrue);
    });

    // Výchozí seznam čísla nemá. Prázdné číslo nesmí „sedět" na
    // cokoli přečteného ze štítku.
    test('se číslem ze štítku nenajde', () {
      expect(najdiPodleCisla('18 342 771', [_misto()]), isNull);
    });

    test('se najde podle QR', () {
      final misto = _misto(id: 'bsl-plyn-kotelna');
      final nalez = najdiPodleQr(obsahQr(misto), [misto]);
      expect(nalez?.elektromer.id, 'bsl-plyn-kotelna');
    });
  });

  group('hledání podle druhu', () {
    test('název druhu je mezi hledanými slovy', () {
      expect(_misto().odpovidaHledani('plyn'), isTrue);
      expect(_misto().odpovidaHledani('nabíječky'), isFalse);
    });
  });

  group('výchozí seznam míst', () {
    test('má všech 76 míst z tabulky zadavatele', () {
      int pocet(DruhMista d) => vychoziMista.where((m) => m.druh == d).length;
      expect(pocet(DruhMista.plyn), 17);
      expect(
        pocet(DruhMista.elektrina),
        23,
        reason: '24 řádků bez zdvojeného BDC, Moto',
      );
      expect(pocet(DruhMista.klimatizace), 18);
      expect(pocet(DruhMista.nabijecka), 18);
      expect(vychoziMista, hasLength(76));
    });

    test('všechna jsou v Brně', () {
      expect(vychoziMista.every((m) => m.pobocka == Pobocka.bsl), isTrue);
    });

    // Pevné ID je to, co brání duplicitám při opakovaném založení.
    // Dvě místa se stejným ID by se navzájem přepsala.
    test('ID jsou jedinečná', () {
      final idcka = vychoziMista.map((m) => m.id).toSet();
      expect(idcka, hasLength(vychoziMista.length));
    });

    test('ID je čitelné, bez diakritiky a mezer', () {
      String id(DruhMista d, String nazev) =>
          VychoziMisto(Pobocka.bsl, d, nazev).id;

      expect(id(DruhMista.plyn, 'HP Řípská'), 'bsl-plyn-hp-ripska');
      expect(id(DruhMista.elektrina, 'BDC, Moto'), 'bsl-elektrina-bdc-moto');
      expect(
        id(DruhMista.elektrina, 'Venkovní osv.'),
        'bsl-elektrina-venkovni-osv',
      );
      expect(id(DruhMista.nabijecka, 'ČEZ Brno'), 'bsl-nabijecka-cez-brno');
    });

    // Firestore nedovolí v ID lomítko a ID se vkládá do QR kódu.
    test('ID obsahují jen malá písmena, číslice a pomlčky', () {
      for (final m in vychoziMista) {
        expect(
          m.id,
          matches(RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$')),
          reason: m.nazev,
        );
      }
    });

    test('„BDC, Moto" je u elektřiny jen jednou', () {
      final bdc = vychoziMista.where(
        (m) => m.druh == DruhMista.elektrina && m.nazev == 'BDC, Moto',
      );
      expect(bdc, hasLength(1));
    });
  });
}
