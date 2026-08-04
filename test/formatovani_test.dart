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
      expect(Format.parsujKwh('12\u00a0486,7'), 12486.7);
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
    test('vždy dvě desetinná místa', () {
      expect(Format.kwh(27), '27,00');
      expect(Format.kwh(27.4), '27,40');
    });

    // Na jedno desetinné místo se 27,49 zobrazilo jako 27,5 – tedy víc,
    // než se opravdu nabilo. U podkladu k fakturaci to vadí.
    test('setiny se nezaokrouhlují nahoru', () {
      expect(Format.kwh(27.49), '27,49');
      // Čeština odděluje tisíce nedělitelnou mezerou, ne obyčejnou –
      // zapsané escapem, aby to nebylo v testu neviditelné.
      expect(Format.kwh(11484.81), '11\u00a0484,81');
    });

    test('tisíce jsou oddělené a hodnotu jde přečíst zpátky', () {
      expect(Format.parsujKwh(Format.kwh(18342.45)), 18342.45);
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

  group('castka a sazba', () {
    test('částka je na haléře s měnou', () {
      expect(Format.castka(178.1), '178,10 Kč');
      expect(Format.castka(1234.5), '1\u00a0234,50 Kč');
    });

    test('sazba nese jednotku za kWh', () {
      expect(Format.sazba(6.5), '6,50 Kč/kWh');
    });

    test('nula se zobrazí, ne vynechá', () {
      expect(Format.castka(0), '0,00 Kč');
    });
  });
}
