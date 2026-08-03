import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renocharge/common/formatovani.dart';

void main() {
  // Stejná inicializace jako v main() – bez ní DateFormat české locale nezná.
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  group('parsujKwh', () {
    test('přijme čárku, tečku i oddělovače tisíců', () {
      expect(Format.parsujKwh('12486,7'), 12486.7);
      expect(Format.parsujKwh('12486.7'), 12486.7);
      expect(Format.parsujKwh('12 486,7'), 12486.7);
      expect(Format.parsujKwh('12 486,7'), 12486.7);
    });

    test('odmítne prázdný a nečíselný vstup', () {
      expect(Format.parsujKwh(null), isNull);
      expect(Format.parsujKwh(''), isNull);
      expect(Format.parsujKwh('   '), isNull);
      expect(Format.parsujKwh('12,4,5'), isNull);
      expect(Format.parsujKwh('abc'), isNull);
      expect(Format.parsujKwh('-5'), isNull);
    });
  });

  group('kwh', () {
    test('vždy jedno desetinné místo', () {
      expect(Format.kwh(27), '27,0');
      expect(Format.kwh(27.44), '27,4');
    });

    test('tisíce jsou oddělené a hodnotu jde přečíst zpátky', () {
      expect(Format.parsujKwh(Format.kwh(18342.4)), 18342.4);
    });
  });

  group('doba', () {
    test('do hodiny jen minuty', () {
      expect(Format.doba(const Duration(minutes: 45)), '45 min');
    });

    test('nad hodinu hodiny i minuty', () {
      expect(Format.doba(const Duration(hours: 5, minutes: 32)), '5 h 32 min');
      expect(Format.doba(const Duration(hours: 5, minutes: 7)), '5 h 07 min');
    });
  });

  group('rozsahCasu', () {
    test('u neukončené relace ukáže výpustku', () {
      final od = DateTime(2026, 8, 3, 7, 12);
      expect(Format.rozsahCasu(od, null), '07:12 – …');
      expect(
        Format.rozsahCasu(od, DateTime(2026, 8, 3, 12, 44)),
        '07:12 – 12:44',
      );
    });
  });
}
