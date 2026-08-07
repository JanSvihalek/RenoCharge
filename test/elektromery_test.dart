import 'package:flutter_test/flutter_test.dart';
import 'package:renocharge/features/auth/domain/uzivatel.dart';
import 'package:renocharge/features/elektromery/domain/elektromer.dart';
import 'package:renocharge/features/elektromery/domain/pobocka.dart';
import 'package:renocharge/navigace/hlavni_shell.dart';

Elektromer _elektromer({
  String cislo = '18 342 771',
  String nazev = 'Hala B – rozvaděč R3',
  String pobocka = 'BSL',
  bool aktivni = true,
}) => Elektromer(
  id: 'e1',
  pobockaKod: pobocka,
  cislo: cislo,
  nazev: nazev,
  aktivni: aktivni,
);

void main() {
  group('Pobocka', () {
    test('kód se přeloží na pobočku', () {
      expect(Pobocka.zKodu('BSL'), Pobocka.bsl);
      expect(Pobocka.zKodu('ZLN'), Pobocka.zln);
    });

    // Elektroměry pobočky, která by se z kódu odebrala, nesmí zmizet –
    // proto se kód v modelu drží jako řetězec a převod je nepovinný.
    test('neznámý kód nespadne, jen vrátí null', () {
      expect(Pobocka.zKodu('XXX'), isNull);
      expect(Pobocka.zKodu(null), isNull);
      expect(Pobocka.zKodu('bsl'), isNull, reason: 'kódy jsou velkými');
    });

    test('kódy jsou jedinečné', () {
      final kody = Pobocka.values.map((p) => p.kod).toSet();
      expect(kody, hasLength(Pobocka.values.length));
    });

    test('popisek nese kód i název', () {
      expect(Pobocka.bsl.popisek, 'BSL – Brno-Slatina');
    });
  });

  group('hledání v seznamu', () {
    test('prázdný dotaz projde všem', () {
      expect(_elektromer().odpovidaHledani(''), isTrue);
      expect(_elektromer().odpovidaHledani('   '), isTrue);
    });

    test('hledá se v čísle i v umístění', () {
      expect(_elektromer().odpovidaHledani('rozvaděč'), isTrue);
      expect(_elektromer().odpovidaHledani('342'), isTrue);
      expect(_elektromer().odpovidaHledani('kotelna'), isFalse);
    });

    test('nezáleží na velikosti písmen', () {
      expect(_elektromer().odpovidaHledani('HALA'), isTrue);
    });

    // Číslo na štítku bývá s mezerami jinde, než ho člověk napíše.
    test('mezery v čísle se ignorují', () {
      expect(_elektromer().odpovidaHledani('18342771'), isTrue);
      expect(
        _elektromer(cislo: '18342771').odpovidaHledani('18 342 771'),
        isTrue,
      );
    });
  });

  group('normalizace čísla', () {
    test('sjednotí vícenásobné mezery a ořízne okraje', () {
      expect(Elektromer.normalizujCislo('  18   342 771 '), '18 342 771');
    });

    test('klíč pro porovnání odstraní mezery i velikost písmen', () {
      expect(Elektromer.klicCisla('18 342 771'), '18342771');
      expect(Elektromer.klicCisla('AB 12'), Elektromer.klicCisla('ab12'));
    });
  });

  group('záložky podle role', () {
    test('zaměstnanec elektroměry nevidí', () {
      final zalozky = zalozkyProRoli(Role.zamestnanec);
      expect(zalozky, isNot(contains(Zalozka.elektromery)));
      expect(zalozky, [Zalozka.nabijecky, Zalozka.historie, Zalozka.nastaveni]);
    });

    test('údržba elektroměry vidí', () {
      expect(zalozkyProRoli(Role.udrzba), contains(Zalozka.elektromery));
    });

    // IndexedStack se plní podle pořadí v tomhle seznamu, takže se
    // obrazovky nesmí rozejít se záložkami.
    test('každá záložka má obrazovku i popis', () {
      for (final role in Role.values) {
        for (final z in zalozkyProRoli(role)) {
          expect(() => obrazovkaZalozky(z), returnsNormally);
          expect(popisZalozky(z).popisek, isNotEmpty);
        }
      }
    });

    test('nabíječky jsou vždy první', () {
      for (final role in Role.values) {
        expect(zalozkyProRoli(role).first, Zalozka.nabijecky);
      }
    });
  });
}
