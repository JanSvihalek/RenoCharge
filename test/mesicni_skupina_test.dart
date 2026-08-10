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

    // Report za červenec se dělá až v srpnu. Patří k červenci, protože
    // odpovídá na otázku „mám červenec hotový?".
    test('report se řadí podle začátku období, ne podle dne vytvoření', () {
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

    // Měsíc bez nabíjení žádnou skupinu nemá, takže report za něj nemá
    // kam patřit. Nesmí to spadnout ani vyrobit prázdný předěl.
    test('report za měsíc bez nabíjení se zahodí', () {
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
