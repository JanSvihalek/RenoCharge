import 'package:flutter_test/flutter_test.dart';
import 'package:renocharge/features/elektromery/domain/elektromer.dart';
import 'package:renocharge/features/elektromery/domain/identifikace.dart';

Elektromer _e(String id, String cislo) =>
    Elektromer(id: id, pobockaKod: 'BSL', cislo: cislo, nazev: 'Kotelna');

final _evidence = [
  _e('e1', '18 342 771'),
  _e('e2', '18342802'),
  _e('e3', 'A-9911'),
];

void main() {
  group('QR kód', () {
    test('najde elektroměr podle ID', () {
      final n = najdiPodleQr(obsahQr(_evidence[0]), _evidence);
      expect(n?.elektromer.id, 'e1');
      expect(n?.zpusob, ZpusobNalezeni.qrKod);
    });

    // Bez předpony by aplikace reagovala na každý QR, který jí přijde
    // pod ruku – na parkovacím lístku i na obalu.
    test('cizí QR se ignoruje', () {
      expect(najdiPodleQr('https://example.com', _evidence), isNull);
      expect(najdiPodleQr('e1', _evidence), isNull);
    });

    test('náš QR na neznámý elektroměr nic nenajde', () {
      expect(najdiPodleQr('${predponaQr}neexistuje', _evidence), isNull);
    });

    test('okolní mezery nevadí', () {
      expect(
        najdiPodleQr('  ${obsahQr(_evidence[1])} \n', _evidence)?.elektromer.id,
        'e2',
      );
    });

    test('QR s holým číslem funguje jako štítek', () {
      final n = najdiPodleQr('18342771', _evidence);
      expect(n?.elektromer.id, 'e1');
      expect(n?.zpusob, ZpusobNalezeni.cisloZeStitku);
    });
  });

  group('číslo ze štítku', () {
    test('najde i když se mezery liší', () {
      expect(najdiPodleCisla('18342771', _evidence)?.elektromer.id, 'e1');
      expect(najdiPodleCisla('18 342 802', _evidence)?.elektromer.id, 'e2');
    });

    // OCR vrací celý štítek včetně typu, výrobce a roku výroby.
    test('vytáhne číslo z celého štítku', () {
      const stitek = '''
ELEKTROMĚR ED310
Typ: 3f 5(80)A
Výr. č. 18 342 771
Rok výroby 2024
''';
      expect(najdiPodleCisla(stitek, _evidence)?.elektromer.id, 'e1');
    });

    test('rok výroby se nespojí s ničím jiným', () {
      expect(najdiPodleCisla('Rok 2024, typ 3f', _evidence), isNull);
    });

    test('neznámé číslo nic nenajde', () {
      expect(najdiPodleCisla('99 999 999', _evidence), isNull);
    });
  });

  group('čísla z textu', () {
    test('krátké shluky se přeskočí', () {
      expect(cislaZTextu('rok 2024 typ 3f'), isEmpty);
    });

    test('sousední skupiny oddělené mezerou se spojují', () {
      expect(cislaZTextu('18 342 771'), contains('18342771'));
    });

    // Bez tohohle omezení by z „rok 2024 typ 3f" vzniklo číslo 20243.
    test('přes slova se nespojuje', () {
      expect(cislaZTextu('rok 2024 typ 3f'), isEmpty);
      expect(cislaZTextu('2024 typ 34567'), isNot(contains('202434567')));
    });

    // Když za výrobním číslem následuje rok, musí být kandidátem
    // i samotné číslo, ne jen celý úsek slepený dohromady.
    test('číslo následované rokem se najde i samostatně', () {
      expect(cislaZTextu('18 342 771 2024'), contains('18342771'));
    });

    test('nejdelší kandidát je první', () {
      final c = cislaZTextu('12345 18 342 771');
      expect(c.first.length, greaterThanOrEqualTo(c.last.length));
    });

    test('prázdný text nedá nic', () {
      expect(cislaZTextu(''), isEmpty);
      expect(cislaZTextu('bez čísel'), isEmpty);
    });
  });
}
