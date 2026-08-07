import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renocharge/features/elektromery/domain/elektromer.dart';
import 'package:renocharge/features/elektromery/domain/odecet.dart';
import 'package:renocharge/features/nabijeni/domain/foto_metadata.dart';
import 'package:renocharge/features/nabijeni/domain/relace.dart';
import 'package:renocharge/features/reporty/application/report_controller.dart';
import 'package:renocharge/features/reporty/application/report_pdf.dart';
import 'package:renocharge/features/reporty/domain/report.dart';

FotoMetadata _foto(String path) => FotoMetadata(
  path: path,
  sha256: 'x' * 64,
  porizenoAt: DateTime(2026, 7, 3),
);

Relace _relace({
  required String id,
  required DateTime zahajeno,
  required double kwhStart,
  required double kwhEnd,
}) => Relace(
  id: id,
  uid: 'u1',
  spz: '2AB 3344',
  vozidloId: 'v1',
  kwhStart: kwhStart,
  kwhEnd: kwhEnd,
  zahajeno: zahajeno,
  ukonceno: zahajeno.add(const Duration(hours: 5, minutes: 32)),
  fotoStart: _foto('nabijeni/$id/start.jpg'),
  fotoEnd: _foto('nabijeni/$id/end.jpg'),
  stav: StavRelace.dokonceno,
);

PodkladReportu _podklad({List<PolozkaReportu>? polozky}) => PodkladReportu(
  jmeno: 'Jan Švihálek',
  osobniCislo: '12345',
  obdobi: Obdobi(od: DateTime(2026, 7), doVcetne: DateTime(2026, 7, 31)),
  polozky:
      polozky ??
      [
        PolozkaReportu(
          relace: _relace(
            id: 'r1',
            zahajeno: DateTime(2026, 7, 3, 7, 12),
            kwhStart: 11484.81,
            kwhEnd: 11512.30,
          ),
          vozidlo: 'Škoda Enyaq · 2AB 3344',
        ),
        PolozkaReportu(
          relace: _relace(
            id: 'r2',
            zahajeno: DateTime(2026, 7, 8, 6, 58),
            kwhStart: 11512.30,
            kwhEnd: 11538.02,
          ),
          vozidlo: 'Škoda Enyaq · 2AB 3344',
        ),
      ],
  vytvorenoAt: DateTime(2026, 8, 1, 9, 30),
);

void main() {
  // Sestavení PDF sahá do assetů pro font, což potřebuje inicializovanou
  // vazbu na Flutter. Data pro české formátování dat zařizuje v aplikaci
  // main(), v testu je potřeba je natáhnout ručně.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  group('Obdobi', () {
    test('horní mez je půlnoc následujícího dne', () {
      // Bez toho by relace zahájená poslední den v 7:12 z reportu vypadla.
      final obdobi = Obdobi(
        od: DateTime(2026, 7, 1),
        doVcetne: DateTime(2026, 7, 31, 23, 59),
      );
      expect(obdobi.doVcetne, DateTime(2026, 7, 31));
      expect(obdobi.doExkluzivne, DateTime(2026, 8, 1));
    });

    test('čas ve vstupu se ořízne na začátek dne', () {
      final obdobi = Obdobi(
        od: DateTime(2026, 7, 1, 18, 42),
        doVcetne: DateTime(2026, 7, 5, 3, 15),
      );
      expect(obdobi.od, DateTime(2026, 7, 1));
      expect(obdobi.doVcetne, DateTime(2026, 7, 5));
    });

    test('minulý měsíc končí jeho posledním dnem', () {
      final obdobi = Obdobi.minulyMesic(DateTime(2026, 8, 4));
      expect(obdobi.od, DateTime(2026, 7, 1));
      expect(obdobi.doVcetne, DateTime(2026, 7, 31));
    });

    test('minulý měsíc zvládne únor i přelom roku', () {
      expect(
        Obdobi.minulyMesic(DateTime(2028, 3, 10)).doVcetne,
        DateTime(2028, 2, 29),
        reason: '2028 je přestupný',
      );
      final lonsky = Obdobi.minulyMesic(DateTime(2027, 1, 15));
      expect(lonsky.od, DateTime(2026, 12, 1));
      expect(lonsky.doVcetne, DateTime(2026, 12, 31));
    });

    test('tento měsíc končí dneškem, ne koncem měsíce', () {
      final obdobi = Obdobi.tentoMesic(DateTime(2026, 8, 4));
      expect(obdobi.od, DateTime(2026, 8, 1));
      expect(obdobi.doVcetne, DateTime(2026, 8, 4));
    });
  });

  group('PodkladReportu', () {
    test('součet spotřeby sečte všechna nabíjení', () {
      expect(_podklad().celkovaSpotreba, closeTo(27.49 + 25.72, 0.001));
    });

    test('bez položek je součet nula', () {
      expect(_podklad(polozky: []).celkovaSpotreba, 0);
    });

    test('bez stažených fotek se oddíl s fotkami nevykresluje', () {
      expect(_podklad().maNejakeFotky, isFalse);
    });
  });

  group('název souboru', () {
    test('skládá se ze jména a obou dat', () {
      final obdobi = Obdobi(
        od: DateTime(2026, 7),
        doVcetne: DateTime(2026, 7, 31),
      );
      expect(
        ReportController.nazevSouboru('Jan Švihálek', obdobi),
        'report-nabijeni-jan-svihalek-2026-07-01-2026-07-31.pdf',
      );
    });

    test('jednociferný měsíc a den mají nulu', () {
      final obdobi = Obdobi(
        od: DateTime(2026, 1, 5),
        doVcetne: DateTime(2026, 2, 9),
      );
      expect(
        ReportController.nazevSouboru('Eva Nová', obdobi),
        endsWith('2026-01-05-2026-02-09.pdf'),
      );
    });

    test('diakritika i mezery zmizí, název projde přes cizí systémy', () {
      expect(
        ReportController.bezDiakritiky('Řehoř Žížala ĎÁBEL'),
        'Rehor Zizala DABEL',
      );
    });
  });

  group('sestavení PDF', () {
    test('vznikne platný dokument', () async {
      final bajty = await (await ReportPdf.nacti()).sestav(_podklad());

      expect(bajty.length, greaterThan(1000));
      expect(
        String.fromCharCodes(bajty.sublist(0, 5)),
        '%PDF-',
        reason: 'hlavička PDF',
      );
    });

    test('prázdné období nespadne, jen se to v reportu napíše', () async {
      final bajty = await (await ReportPdf.nacti()).sestav(
        _podklad(polozky: []),
      );
      expect(bajty.length, greaterThan(1000));
    });

    test('chybějící fotka jen vynechá dlaždici', () async {
      final podklad = _podklad(
        polozky: [
          PolozkaReportu(
            relace: _relace(
              id: 'r1',
              zahajeno: DateTime(2026, 7, 3, 7, 12),
              kwhStart: 11484.81,
              kwhEnd: 11512.30,
            ),
            vozidlo: '2AB 3344',
            fotoStart: _jednobarevnyJpeg(),
          ),
        ],
      );
      expect(podklad.maNejakeFotky, isTrue);

      final bajty = await (await ReportPdf.nacti()).sestav(podklad);
      expect(bajty.length, greaterThan(1000));
    });
  });

  _testyReportuElektromeru();
}

/// Nejmenší platný JPEG (1×1 px), aby se dal vložit do PDF bez
/// stahování čehokoli.
Uint8List _jednobarevnyJpeg() => Uint8List.fromList([
  0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, //
  0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
  0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09,
  0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12,
  0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20,
  0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29,
  0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32,
  0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01,
  0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xC4, 0x00, 0x14, 0x00, 0x01,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x03, 0xFF, 0xC4, 0x00, 0x14, 0x10, 0x01, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00,
  0x37, 0xFF, 0xD9,
]);

Odecet _odecetR({
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
  foto: _foto('odecty/u1/${kdy.millisecondsSinceEpoch}.jpg'),
  vymenaMeridla: vymena,
);

Elektromer get _e1 => const Elektromer(
  id: 'e1',
  pobockaKod: 'BSL',
  cislo: '18 342 771',
  nazev: 'Hala B – rozvaděč R3',
);

void _testyReportuElektromeru() {
  group('položky odečtů pro report', () {
    // Vstup je od nejstaršího – v reportu se čte odshora dolů v čase.
    test('spotřeba je rozdíl proti předchozímu odečtu', () {
      final p = slozPolozkyOdectu([
        _odecetR(kdy: DateTime(2026, 6, 1), hodnota: 100),
        _odecetR(kdy: DateTime(2026, 7, 1), hodnota: 130),
        _odecetR(kdy: DateTime(2026, 8, 1), hodnota: 175),
      ]);

      expect(p[0].spotreba, isNull, reason: 'nejstarší nemá s čím');
      expect(p[1].spotreba, closeTo(30, 0.001));
      expect(p[2].spotreba, closeTo(45, 0.001));
    });

    // Skokový nárůst je ten signál, kvůli kterému se odečty čtou.
    test('změna v procentech se počítá proti minulé spotřebě', () {
      final p = slozPolozkyOdectu([
        _odecetR(kdy: DateTime(2026, 6, 1), hodnota: 100),
        _odecetR(kdy: DateTime(2026, 7, 1), hodnota: 130),
        _odecetR(kdy: DateTime(2026, 8, 1), hodnota: 175),
      ]);

      expect(p[1].zmenaProcent, isNull, reason: 'není s čím porovnat');
      expect(p[2].zmenaProcent, closeTo(50, 0.001), reason: '30 → 45 kWh');
    });

    test('pokles se pozná záporným číslem', () {
      final p = slozPolozkyOdectu([
        _odecetR(kdy: DateTime(2026, 6, 1), hodnota: 100),
        _odecetR(kdy: DateTime(2026, 7, 1), hodnota: 140),
        _odecetR(kdy: DateTime(2026, 8, 1), hodnota: 160),
      ]);
      expect(p[2].zmenaProcent, closeTo(-50, 0.001), reason: '40 → 20 kWh');
    });

    test('po výměně měřidla se spotřeba ani změna nepočítá', () {
      final p = slozPolozkyOdectu([
        _odecetR(kdy: DateTime(2026, 6, 1), hodnota: 118000),
        _odecetR(kdy: DateTime(2026, 7, 1), hodnota: 12.5, vymena: true),
        _odecetR(kdy: DateTime(2026, 8, 1), hodnota: 40),
      ]);

      expect(p[1].spotreba, isNull);
      expect(p[1].zmenaProcent, isNull);
      expect(p[2].spotreba, closeTo(27.5, 0.001), reason: 'nové měřidlo běží');
      expect(p[2].zmenaProcent, isNull, reason: 'řada se výměnou přerušila');
    });

    test('součet za období sečte jen dopočítané spotřeby', () {
      final podklad = PodkladElektromeru(
        elektromer: _e1,
        obdobi: Obdobi(od: DateTime(2026, 6), doVcetne: DateTime(2026, 8, 31)),
        polozky: slozPolozkyOdectu([
          _odecetR(kdy: DateTime(2026, 6, 1), hodnota: 100),
          _odecetR(kdy: DateTime(2026, 7, 1), hodnota: 130),
          _odecetR(kdy: DateTime(2026, 8, 1), hodnota: 175),
        ]),
        vytvorenoAt: DateTime(2026, 9, 1),
      );
      expect(podklad.celkovaSpotreba, closeTo(75, 0.001));
    });

    test('prázdné období nespadne', () {
      expect(slozPolozkyOdectu(const []), isEmpty);
    });
  });

  group('sestavení PDF elektroměru', () {
    test('vznikne platný dokument', () async {
      final bajty = await (await ReportPdf.nacti()).sestavElektromer(
        PodkladElektromeru(
          elektromer: _e1,
          obdobi: Obdobi(
            od: DateTime(2026, 6),
            doVcetne: DateTime(2026, 8, 31),
          ),
          polozky: slozPolozkyOdectu([
            _odecetR(kdy: DateTime(2026, 6, 1), hodnota: 118400),
            _odecetR(kdy: DateTime(2026, 7, 1), hodnota: 118484.81),
            _odecetR(kdy: DateTime(2026, 8, 1), hodnota: 118512.30),
          ]),
          vytvorenoAt: DateTime(2026, 9, 1, 8),
        ),
      );

      expect(bajty.length, greaterThan(1000));
      expect(String.fromCharCodes(bajty.sublist(0, 5)), '%PDF-');
    });

    test('elektroměr bez odečtů dá dokument s vysvětlením', () async {
      final bajty = await (await ReportPdf.nacti()).sestavElektromer(
        PodkladElektromeru(
          elektromer: _e1,
          obdobi: Obdobi(
            od: DateTime(2026, 8),
            doVcetne: DateTime(2026, 8, 31),
          ),
          polozky: const [],
          vytvorenoAt: DateTime(2026, 9, 1),
        ),
      );
      expect(bajty.length, greaterThan(1000));
    });
  });

  test('název souboru reportu elektroměru nese předponu i číslo', () {
    final obdobi = Obdobi(
      od: DateTime(2026, 8),
      doVcetne: DateTime(2026, 8, 31),
    );
    expect(
      ReportController.nazevSouboru(
        'elektromer 18 342 771',
        obdobi,
        predpona: 'report-elektromer',
      ),
      'report-elektromer-elektromer-18-342-771-2026-08-01-2026-08-31.pdf',
    );
  });
}
