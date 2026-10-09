import 'package:flutter_test/flutter_test.dart';
import 'package:renocharge/features/auth/domain/uzivatel.dart';
import 'package:renocharge/features/elektromery/domain/elektromer.dart';
import 'package:renocharge/features/elektromery/domain/obchuzka.dart';
import 'package:renocharge/features/elektromery/domain/odecet.dart';
import 'package:renocharge/features/nabijeni/domain/foto_metadata.dart';
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
    test('běžný uživatel elektroměry nevidí', () {
      final zalozky = zalozkyProRoli(Role.uzivatel);
      expect(zalozky, isNot(contains(Zalozka.elektromery)));
      expect(zalozky, [Zalozka.nabijeni, Zalozka.nastaveni]);
    });

    test('údržba i správce elektroměry vidí', () {
      expect(zalozkyProRoli(Role.udrzba), contains(Zalozka.elektromery));
      expect(zalozkyProRoli(Role.admin), contains(Zalozka.elektromery));
    });

    test('správce vidí aspoň tolik co ostatní role', () {
      final spravce = zalozkyProRoli(Role.admin).toSet();
      for (final role in Role.values) {
        expect(spravce, containsAll(zalozkyProRoli(role)));
      }
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

    test('nabíjení je vždy první', () {
      for (final role in Role.values) {
        expect(zalozkyProRoli(role).first, Zalozka.nabijeni);
      }
    });

    // Každá záložka je jedna evidence, ne pohled na ni. Historie
    // nabíjení proto vlastní záložku nemá – bydlí v Nabíjení.
    test('údržba má dvě evidence a nastavení', () {
      expect(zalozkyProRoli(Role.udrzba), [
        Zalozka.nabijeni,
        Zalozka.elektromery,
        Zalozka.nastaveni,
      ]);
    });
  });

  _testyOdectu();
}

Odecet _odecet({
  required DateTime kdy,
  required double hodnota,
  bool vymena = false,
}) => Odecet(
  id: kdy.toIso8601String(),
  elektromerId: 'e1',
  pobockaKod: 'BSL',
  uid: 'u1',
  hodnota: hodnota,
  odectenoAt: kdy,
  foto: FotoMetadata(path: 'a', sha256: 'x' * 64, porizenoAt: kdy),
  vymenaMeridla: vymena,
);

void _testyOdectu() {
  group('dopočet spotřeby', () {
    // Spotřeba se neukládá, počítá se z řady. Vstup chodí od nejnovějšího.
    test('rozdíl proti staršímu odečtu', () {
      final rada = dopocitejSpotrebu([
        _odecet(kdy: DateTime(2026, 8, 3), hodnota: 118_512.30),
        _odecet(kdy: DateTime(2026, 7, 2), hodnota: 118_484.81),
        _odecet(kdy: DateTime(2026, 6, 1), hodnota: 118_400.00),
      ]);

      expect(rada[0].spotreba, closeTo(27.49, 0.001));
      expect(rada[1].spotreba, closeTo(84.81, 0.001));
      expect(rada[2].spotreba, isNull, reason: 'nejstarší nemá s čím');
    });

    test('jediný odečet spotřebu nemá', () {
      final rada = dopocitejSpotrebu([
        _odecet(kdy: DateTime(2026, 8, 3), hodnota: 100),
      ]);
      expect(rada.single.spotreba, isNull);
    });

    // Po výměně měřidla začíná počítadlo od nuly, takže rozdíl proti
    // starému stavu je nesmysl a nesmí se ukázat jako záporná spotřeba.
    test('po výměně měřidla se spotřeba nepočítá', () {
      final rada = dopocitejSpotrebu([
        _odecet(kdy: DateTime(2026, 8, 3), hodnota: 12.5, vymena: true),
        _odecet(kdy: DateTime(2026, 7, 2), hodnota: 118_484.81),
      ]);
      expect(rada[0].spotreba, isNull);
    });

    test('prázdná historie nespadne', () {
      expect(dopocitejSpotrebu(const []), isEmpty);
    });
  });

  group('poslední obchůzka', () {
    var poradi = 0;
    Elektromer sOdectem(DateTime? kdy, {bool aktivni = true}) => Elektromer(
      id: 'e${poradi++}',
      pobockaKod: 'BSL',
      cislo: '',
      nazev: 'Kotelna',
      aktivni: aktivni,
      posledniOdecet: kdy == null
          ? null
          : PosledniOdecet(hodnota: 100, odectenoAt: kdy, odecetId: 'o1'),
    );

    test('bez jediného odečtu žádná obchůzka není', () {
      expect(Obchuzka.posledni([sOdectem(null), sOdectem(null)]), isNull);
    });

    test('začíná prvním odečtem, který k ní patří', () {
      final obchuzka = Obchuzka.posledni([
        sOdectem(DateTime(2026, 10, 2)),
        sOdectem(DateTime(2026, 10, 1, 8)),
        sOdectem(DateTime(2026, 10, 3)),
      ])!;
      expect(obchuzka.od, DateTime(2026, 10, 1, 8));
    });

    // Tohle byl důvod, proč „hotovo" přestalo být podle měsíce: obchůzka
    // přes konec měsíce je pořád jedna obchůzka.
    test('obchůzka přes konec měsíce zůstane celá', () {
      final zari = sOdectem(DateTime(2026, 9, 29));
      final rijen = sOdectem(DateTime(2026, 10, 2));
      final obchuzka = Obchuzka.posledni([zari, rijen])!;

      expect(obchuzka.zahrnuje(zari), isTrue);
      expect(obchuzka.zahrnuje(rijen), isTrue);
      expect(obchuzka.od, DateTime(2026, 9, 29));
    });

    test('odečty z minulé obchůzky do nové nepatří', () {
      final minule = sOdectem(DateTime(2026, 9, 2));
      final ted = sOdectem(DateTime(2026, 10, 1));
      final obchuzka = Obchuzka.posledni([minule, ted])!;

      expect(obchuzka.zahrnuje(minule), isFalse);
      expect(obchuzka.zahrnuje(ted), isTrue);
      expect(obchuzka.od, DateTime(2026, 10, 1));
    });

    test('místo bez odečtu do obchůzky nepatří', () {
      final bez = sOdectem(null);
      final obchuzka = Obchuzka.posledni([bez, sOdectem(DateTime(2026, 10))])!;
      expect(obchuzka.zahrnuje(bez), isFalse);
    });

    // Starý odečet vyřazeného místa nesmí obchůzku natáhnout dozadu.
    test('vyřazená místa obchůzku neurčují', () {
      final obchuzka = Obchuzka.posledni([
        sOdectem(DateTime(2027), aktivni: false),
        sOdectem(DateTime(2026, 10, 1)),
      ])!;
      expect(obchuzka.od, DateTime(2026, 10, 1));
    });
  });
}
