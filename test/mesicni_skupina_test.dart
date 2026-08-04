import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renocharge/common/formatovani.dart';
import 'package:renocharge/features/nabijeni/domain/foto_metadata.dart';
import 'package:renocharge/features/nabijeni/domain/mesicni_skupina.dart';
import 'package:renocharge/features/nabijeni/domain/relace.dart';

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
