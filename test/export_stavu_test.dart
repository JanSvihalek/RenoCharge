import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renocharge/features/elektromery/domain/druh_mista.dart';
import 'package:renocharge/features/elektromery/domain/elektromer.dart';
import 'package:renocharge/features/elektromery/domain/odecet.dart';
import 'package:renocharge/features/elektromery/domain/pobocka.dart';
import 'package:renocharge/features/nabijeni/domain/foto_metadata.dart';
import 'package:renocharge/features/reporty/application/report_xlsx.dart';
import 'package:renocharge/features/reporty/domain/report.dart';

Elektromer _misto(
  String id, {
  String nazev = 'Kotelna',
  DruhMista druh = DruhMista.plyn,
  bool aktivni = true,
}) => Elektromer(
  id: id,
  pobockaKod: 'BSL',
  cislo: '',
  nazev: nazev,
  druh: druh,
  aktivni: aktivni,
);

Odecet _odecet(
  String mistoId,
  DateTime kdy,
  double hodnota, {
  bool vymena = false,
}) => Odecet(
  id: '$mistoId-${kdy.millisecondsSinceEpoch}',
  elektromerId: mistoId,
  pobockaKod: 'BSL',
  uid: 'u1',
  hodnota: hodnota,
  odectenoAt: kdy,
  foto: FotoMetadata(path: 'x', sha256: 'x' * 64, porizenoAt: kdy),
  vymenaMeridla: vymena,
);

/// Řádky jednoho místa: dva odečty před obdobím, zbytek v něm.
List<RadekStavu> _slozJedno(
  Elektromer misto, {
  List<Odecet> pred = const [],
  List<Odecet> behem = const [],
}) => slozPrehledStavu(
  mista: [misto],
  predObdobim: {misto.id: pred},
  vObdobi: {misto.id: behem},
);

String _list(PodkladStavu podklad) {
  final archiv = ZipDecoder().decodeBytes(ReportXlsx.sestavStavy(podklad));
  return utf8.decode(
    archiv.files
        .firstWhere((f) => f.name == 'xl/worksheets/sheet1.xml')
        .readBytes()!,
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  final zari1 = DateTime(2026, 8, 3);
  final zari2 = DateTime(2026, 9, 2);
  final rijen = DateTime(2026, 10, 4);

  group('řádky přehledu stavů', () {
    test('spotřeba je rozdíl proti poslednímu stavu před obdobím', () {
      final r = _slozJedno(
        _misto('m1'),
        pred: [_odecet('m1', zari1, 1000), _odecet('m1', zari2, 1100)],
        behem: [_odecet('m1', rijen, 1250)],
      ).single;

      expect(r.minuly?.hodnota, 1100);
      expect(r.posledni?.hodnota, 1250);
      expect(r.spotreba, closeTo(150, 0.001));
    });

    // Skok proti minulému období je to, kvůli čemu se odečty čtou.
    test('změna se počítá proti spotřebě minulého období', () {
      final r = _slozJedno(
        _misto('m1'),
        pred: [_odecet('m1', zari1, 1000), _odecet('m1', zari2, 1100)],
        behem: [_odecet('m1', rijen, 1250)],
      ).single;

      expect(r.zmenaProcent, closeTo(50, 0.001), reason: '150 proti 100');
    });

    test('víc odečtů v období se sečte, platí poslední stav', () {
      final r = _slozJedno(
        _misto('m1'),
        pred: [_odecet('m1', zari2, 1100)],
        behem: [
          _odecet('m1', DateTime(2026, 10, 2), 1150),
          _odecet('m1', DateTime(2026, 10, 20), 1230),
        ],
      ).single;

      expect(r.posledni?.hodnota, 1230);
      expect(r.spotreba, closeTo(130, 0.001));
      expect(r.zmenaProcent, isNull, reason: 'minulé období neznámé');
    });

    test('místo bez odečtu v období v přehledu zůstane', () {
      final r = _slozJedno(
        _misto('m1'),
        pred: [_odecet('m1', zari2, 1100)],
      ).single;

      expect(r.minuly?.hodnota, 1100);
      expect(r.posledni, isNull);
      expect(r.spotreba, isNull);
    });

    test('první odečet vůbec spotřebu nemá', () {
      final r = _slozJedno(
        _misto('m1'),
        behem: [_odecet('m1', rijen, 500)],
      ).single;

      expect(r.minuly, isNull);
      expect(r.spotreba, isNull);
    });

    test('výměna měřidla se přizná a rozdíl přes ni se nepočítá', () {
      final r = _slozJedno(
        _misto('m1'),
        pred: [_odecet('m1', zari2, 1100)],
        behem: [_odecet('m1', rijen, 20, vymena: true)],
      ).single;

      expect(r.vymenaMeridla, isTrue);
      expect(r.spotreba, isNull);
    });

    test('vyřazené místo jen tehdy, když má odečet v období', () {
      final vyrazene = _misto('m1', aktivni: false);
      expect(_slozJedno(vyrazene, pred: [_odecet('m1', zari2, 1)]), isEmpty);
      expect(
        _slozJedno(vyrazene, behem: [_odecet('m1', rijen, 1)]),
        hasLength(1),
      );
    });

    test('řadí se podle druhu, pak podle umístění', () {
      final radky = slozPrehledStavu(
        mista: [
          _misto('a', nazev: 'Servis', druh: DruhMista.nabijecka),
          _misto('b', nazev: 'Účtárna', druh: DruhMista.plyn),
          _misto('c', nazev: 'BDC', druh: DruhMista.plyn),
          _misto('d', nazev: 'Servis', druh: DruhMista.elektrina),
        ],
        predObdobim: const {},
        vObdobi: const {},
      );

      expect(radky.map((r) => r.misto.id), ['d', 'c', 'b', 'a']);
    });
  });

  group('tabulka stavů do Excelu', () {
    PodkladStavu podklad() => PodkladStavu(
      pobocka: Pobocka.bsl,
      druh: null,
      obdobi: Obdobi(od: DateTime(2026, 10), doVcetne: DateTime(2026, 10, 31)),
      radky: slozPrehledStavu(
        mista: [
          _misto('p', nazev: 'Kotelna', druh: DruhMista.plyn),
          _misto('e', nazev: 'Servis', druh: DruhMista.elektrina),
          _misto('n', nazev: 'Parkoviště 1', druh: DruhMista.nabijecka),
        ],
        predObdobim: {
          'p': [_odecet('p', zari2, 100)],
          'e': [_odecet('e', zari2, 5000)],
        },
        vObdobi: {
          'p': [_odecet('p', rijen, 112.5)],
          'e': [_odecet('e', rijen, 5300)],
        },
      ),
      vytvorenoAt: DateTime(2026, 11, 1),
    );

    test('má hlavičku a jednotku u každého místa', () {
      final list = _list(podklad());
      for (final nadpis in ['Minulý stav', 'Nový stav', 'Spotřeba', 'Změna']) {
        expect(list, contains('<t xml:space="preserve">$nadpis</t>'));
      }
      expect(list, contains('<t xml:space="preserve">m³</t>'));
      expect(list, contains('<t xml:space="preserve">kWh</t>'));
    });

    test('spotřeba je v buňce jako číslo', () {
      final list = _list(podklad());
      expect(list, contains('<v>12.5</v>'));
      expect(list, contains('<v>300.0</v>'));
    });

    test('místo bez odečtu nese poznámku', () {
      expect(
        _list(podklad()),
        contains('<t xml:space="preserve">bez odečtu v období</t>'),
      );
    });

    // kWh a m³ se sečíst nedají – součet je zvlášť za každý druh.
    test('součty jsou po druzích, ne dohromady', () {
      final list = _list(podklad());
      expect(list, contains('Celkem plyn (m³)'));
      expect(list, contains('Celkem elektřina (kWh)'));
      expect(list, contains('Celkem nabíječky (kWh)'));
      expect(list, contains('<f>SUMIF(A2:A4,"Plyn",I2:I4)</f>'));
    });

    test('list se jmenuje Stavy', () {
      final archiv = ZipDecoder().decodeBytes(
        ReportXlsx.sestavStavy(podklad()),
      );
      final sesit = utf8.decode(
        archiv.files
            .firstWhere((f) => f.name == 'xl/workbook.xml')
            .readBytes()!,
      );
      expect(sesit, contains('<sheet name="Stavy"'));
    });

    test('prázdný přehled nespadne', () {
      final prazdny = PodkladStavu(
        pobocka: Pobocka.bsl,
        druh: DruhMista.plyn,
        obdobi: Obdobi(
          od: DateTime(2026, 10),
          doVcetne: DateTime(2026, 10, 31),
        ),
        radky: const [],
        vytvorenoAt: DateTime(2026, 11, 1),
      );
      expect(_list(prazdny), contains('<sheetData>'));
    });
  });
}
