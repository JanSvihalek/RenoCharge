import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renocharge/common/formatovani.dart';
import 'package:renocharge/features/nabijeni/domain/foto_metadata.dart';
import 'package:renocharge/features/nabijeni/domain/mesicni_skupina.dart';
import 'package:renocharge/features/nabijeni/domain/relace.dart';
import 'package:renocharge/features/reporty/domain/report.dart';
import 'package:renocharge/features/reporty/domain/zaznam_exportu.dart';

ZaznamExportu _export({
  required DateTime od,
  required DateTime doVcetne,
  DateTime? vytvoreno,
  int pocet = 3,
}) => ZaznamExportu(
  id: od.toIso8601String(),
  uid: 'u1',
  obdobi: Obdobi(od: od, doVcetne: doVcetne),
  pocetZaznamu: pocet,
  sFotkami: true,
  vytvorenoAt: vytvoreno ?? doVcetne,
);

Relace _relace({
  required DateTime zahajeno,
  double? kwhEnd,
  double kwhStart = 100,
}) => Relace(
  id: zahajeno.toIso8601String(),
  uid: 'u1',
  spz: '2AB 3344',
  vozidloId: 'v1',
  kwhStart: kwhStart,
  kwhEnd: kwhEnd,
  zahajeno: zahajeno,
  fotoStart: FotoMetadata(path: 'a', sha256: 'x' * 64, porizenoAt: zahajeno),
  stav: kwhEnd == null ? StavRelace.probiha : StavRelace.dokonceno,
);

void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  group('seskupPoMesicich', () {
    test('rozdělí relace podle měsíce zahájení', () {
      final skupiny = seskupPoMesicich([
        _relace(zahajeno: DateTime(2026, 8, 4), kwhEnd: 110),
        _relace(zahajeno: DateTime(2026, 8, 1), kwhEnd: 120),
        _relace(zahajeno: DateTime(2026, 7, 28), kwhEnd: 130),
      ]);

      expect(skupiny.map((s) => s.mesic), [
        DateTime(2026, 8),
        DateTime(2026, 7),
      ]);
      expect(skupiny.first.relace, hasLength(2));
      expect(skupiny.last.relace, hasLength(1));
    });

    test('zachovává pořadí vstupu, nepřerovnává', () {
      final skupiny = seskupPoMesicich([
        _relace(zahajeno: DateTime(2026, 8, 4), kwhEnd: 110),
        _relace(zahajeno: DateTime(2026, 8, 20), kwhEnd: 120),
      ]);
      expect(skupiny.single.relace.first.zahajeno, DateTime(2026, 8, 4));
    });

    test('stejný měsíc jiného roku je jiná skupina', () {
      final skupiny = seskupPoMesicich([
        _relace(zahajeno: DateTime(2027, 1, 5), kwhEnd: 110),
        _relace(zahajeno: DateTime(2026, 1, 5), kwhEnd: 120),
      ]);
      expect(skupiny, hasLength(2));
    });

    test('prázdná historie nedá žádnou skupinu', () {
      expect(seskupPoMesicich(const []), isEmpty);
    });
  });

  group('stopy po exportech v historii', () {
    final srpen = _relace(zahajeno: DateTime(2026, 8, 4), kwhEnd: 110);
    final cervenec = _relace(zahajeno: DateTime(2026, 7, 28), kwhEnd: 130);

    // Report za červenec se dělá až v srpnu. Řadí se podle konce období,
    // protože jen tak sedí mezi relace: co je pod ním, to už zahrnul.
    test('report se řadí podle konce období, ne podle dne vytvoření', () {
      final skupiny = seskupPoMesicich(
        [srpen, cervenec],
        exporty: [
          _export(
            od: DateTime(2026, 7),
            doVcetne: DateTime(2026, 7, 31),
            vytvoreno: DateTime(2026, 8, 4),
          ),
        ],
      );

      expect(skupiny.first.mesic, DateTime(2026, 8));
      expect(skupiny.first.exporty, isEmpty);
      expect(skupiny.last.exporty, hasLength(1));
    });

    test('bez exportů zůstávají skupiny prázdné', () {
      expect(seskupPoMesicich([srpen]).single.exporty, isEmpty);
    });

    // Měsíc bez nabíjení žádnou skupinu nemá, takže report končící v něm
    // nemá kam patřit. Nesmí to spadnout ani vyrobit prázdný předěl.
    test('report končící v měsíci bez nabíjení se zahodí', () {
      final skupiny = seskupPoMesicich(
        [srpen],
        exporty: [
          _export(od: DateTime(2026, 5), doVcetne: DateTime(2026, 5, 31)),
        ],
      );

      expect(skupiny, hasLength(1));
      expect(skupiny.single.exporty, isEmpty);
    });

    test('víc reportů za tentýž měsíc zůstane pohromadě', () {
      final skupiny = seskupPoMesicich(
        [cervenec],
        exporty: [
          _export(od: DateTime(2026, 7), doVcetne: DateTime(2026, 7, 31)),
          _export(od: DateTime(2026, 7), doVcetne: DateTime(2026, 7, 15)),
        ],
      );
      expect(skupiny.single.exporty, hasLength(2));
    });
  });

  group('pořadí položek v měsíci', () {
    DateTime? kdyExportu(MesicniSkupina s) {
      for (final p in s.polozky) {
        if (p case PolozkaExportu(:final export)) return export.obdobi.doVcetne;
      }
      return null;
    }

    List<Object> tvary(MesicniSkupina s) => [
      for (final p in s.polozky)
        switch (p) {
          PolozkaRelace(:final relace) => relace.zahajeno,
          PolozkaExportu() => 'report',
        },
    ];

    // Tohle je celý smysl té značky: pod ní leží přesně ta nabíjení,
    // která report zahrnul, nad ní ta, co čekají na příští.
    test('report leží mezi relacemi podle konce svého období', () {
      final skupina = seskupPoMesicich(
        [
          _relace(zahajeno: DateTime(2026, 8, 20), kwhEnd: 110),
          _relace(zahajeno: DateTime(2026, 8, 10), kwhEnd: 110),
          _relace(zahajeno: DateTime(2026, 8, 2), kwhEnd: 110),
        ],
        exporty: [
          _export(od: DateTime(2026, 8), doVcetne: DateTime(2026, 8, 15)),
        ],
      ).single;

      expect(tvary(skupina), [
        DateTime(2026, 8, 20),
        'report',
        DateTime(2026, 8, 10),
        DateTime(2026, 8, 2),
      ]);
      expect(kdyExportu(skupina), DateTime(2026, 8, 15));
    });

    // Nabíjení, které v poslední den období v osm ráno začalo, report
    // ještě obsahuje – nesmí tedy skončit nad čarou.
    test('nabíjení z posledního dne období zůstane pod reportem', () {
      final skupina = seskupPoMesicich(
        [_relace(zahajeno: DateTime(2026, 8, 15, 8, 7), kwhEnd: 110)],
        exporty: [
          _export(od: DateTime(2026, 8), doVcetne: DateTime(2026, 8, 15)),
        ],
      ).single;

      expect(tvary(skupina), ['report', DateTime(2026, 8, 15, 8, 7)]);
    });

    test('bez exportů jsou položky jen relace v původním pořadí', () {
      final skupina = seskupPoMesicich([
        _relace(zahajeno: DateTime(2026, 8, 20), kwhEnd: 110),
        _relace(zahajeno: DateTime(2026, 8, 2), kwhEnd: 110),
      ]).single;

      expect(skupina.polozky, everyElement(isA<PolozkaRelace>()));
      expect(skupina.polozky, hasLength(2));
    });
  });

  group('spotřeba za období reportu', () {
    // Období reportu bývá přes předěl měsíce (15. 7. – 5. 8.), takže se
    // součet musí počítat z celé historie, ne ze skupiny.
    test('sečte relace přes hranici měsíce', () {
      final skupiny = seskupPoMesicich(
        [
          _relace(zahajeno: DateTime(2026, 8, 4), kwhStart: 100, kwhEnd: 110),
          _relace(zahajeno: DateTime(2026, 7, 20), kwhStart: 200, kwhEnd: 225),
        ],
        exporty: [
          _export(od: DateTime(2026, 7, 15), doVcetne: DateTime(2026, 8, 5)),
        ],
      );

      final export = skupiny.first.exporty.single;
      expect(export.celkemKwh, closeTo(10 + 25, 0.001));
    });

    test('relace mimo období se nepočítají', () {
      final skupiny = seskupPoMesicich(
        [
          _relace(zahajeno: DateTime(2026, 8, 20), kwhStart: 100, kwhEnd: 110),
          _relace(zahajeno: DateTime(2026, 8, 2), kwhStart: 200, kwhEnd: 225),
        ],
        exporty: [
          _export(od: DateTime(2026, 8), doVcetne: DateTime(2026, 8, 15)),
        ],
      );

      expect(skupiny.single.exporty.single.celkemKwh, closeTo(25, 0.001));
    });

    // Poslední den je včetně, takže nabíjení z jeho rána i večera patří
    // dovnitř – hranice se počítá z půlnoci dne následujícího.
    test('poslední den období je celý uvnitř', () {
      final skupiny = seskupPoMesicich(
        [
          _relace(
            zahajeno: DateTime(2026, 8, 15, 23, 40),
            kwhStart: 100,
            kwhEnd: 110,
          ),
        ],
        exporty: [
          _export(od: DateTime(2026, 8), doVcetne: DateTime(2026, 8, 15)),
        ],
      );

      expect(skupiny.single.exporty.single.celkemKwh, closeTo(10, 0.001));
    });

    test('běžící relace do součtu nepřispěje', () {
      final skupiny = seskupPoMesicich(
        [_relace(zahajeno: DateTime(2026, 8, 4))],
        exporty: [
          _export(od: DateTime(2026, 8), doVcetne: DateTime(2026, 8, 15)),
        ],
      );

      expect(skupiny.single.exporty.single.celkemKwh, 0);
    });
  });

  group('navazující období', () {
    test('začíná dnem po konci posledního reportu', () {
      final obdobi = Obdobi.navazujici(
        DateTime(2026, 7, 31),
        DateTime(2026, 8, 4),
      );

      expect(obdobi!.od, DateTime(2026, 8));
      expect(obdobi.doVcetne, DateTime(2026, 8, 4));
    });

    // Když poslední report došel až do dneška, není co exportovat
    // a nabídka „navázat" nedává smysl.
    test('nic nevrátí, když report pokrývá dnešek', () {
      expect(
        Obdobi.navazujici(DateTime(2026, 8, 4), DateTime(2026, 8, 4)),
        isNull,
      );
      expect(
        Obdobi.navazujici(DateTime(2026, 8, 20), DateTime(2026, 8, 4)),
        isNull,
      );
    });

    test('přes konec měsíce i roku', () {
      expect(
        Obdobi.navazujici(DateTime(2026, 12, 31), DateTime(2027, 1, 5))!.od,
        DateTime(2027),
      );
    });

    // Den přechodu na zimní čas má 25 hodin. Přičtení 24 hodin by
    // skončilo ve 23:00 téhož dne a report by přišel o poslední hodinu.
    test('přechod na zimní čas nerozhodí následující den', () {
      expect(
        Obdobi.nasledujiciDen(DateTime(2026, 10, 25)),
        DateTime(2026, 10, 26),
      );
      expect(
        Obdobi(
          od: DateTime(2026, 10, 1),
          doVcetne: DateTime(2026, 10, 25),
        ).doExkluzivne,
        DateTime(2026, 10, 26),
      );
    });
  });

  group('součet měsíce', () {
    test('sečte spotřebu dokončených relací', () {
      final skupina = seskupPoMesicich([
        _relace(zahajeno: DateTime(2026, 8, 4), kwhStart: 100, kwhEnd: 127.49),
        _relace(zahajeno: DateTime(2026, 8, 1), kwhStart: 200, kwhEnd: 225.72),
      ]).single;

      expect(skupina.celkemKwh, closeTo(27.49 + 25.72, 0.001));
      expect(skupina.pocetDokoncenych, 2);
    });

    // Běžící relace ještě nemá koncový stav. Kdyby se do součtu počítala,
    // tvrdil by měsíc něco, co se po ukončení změní.
    test('běžící relace se do součtu nepočítá', () {
      final skupina = seskupPoMesicich([
        _relace(zahajeno: DateTime(2026, 8, 4)),
        _relace(zahajeno: DateTime(2026, 8, 1), kwhStart: 200, kwhEnd: 225.72),
      ]).single;

      expect(skupina.relace, hasLength(2), reason: 'v seznamu zůstává');
      expect(skupina.celkemKwh, closeTo(25.72, 0.001));
      expect(skupina.pocetDokoncenych, 1);
    });

    test('měsíc jen s běžící relací má nulový součet', () {
      final skupina = seskupPoMesicich([
        _relace(zahajeno: DateTime(2026, 8, 4)),
      ]).single;
      expect(skupina.celkemKwh, 0);
    });
  });

  group('mesicARok', () {
    // Čeština má u měsíců dva tvary. Do nadpisu patří první pád
    // („Červenec 2026"), ne druhý („července 2026") z formátu data.
    test('používá první pád s velkým písmenem', () {
      expect(Format.mesicARok(DateTime(2026, 7, 15)), 'Červenec 2026');
      expect(Format.mesicARok(DateTime(2026, 1, 1)), 'Leden 2026');
      expect(Format.mesicARok(DateTime(2026, 5, 31)), 'Květen 2026');
    });
  });
}
