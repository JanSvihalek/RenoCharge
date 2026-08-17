import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renocharge/features/nabijeni/domain/foto_metadata.dart';
import 'package:renocharge/features/nabijeni/domain/relace.dart';
import 'package:renocharge/features/reporty/application/report_controller.dart';
import 'package:renocharge/features/reporty/application/report_xlsx.dart';
import 'package:renocharge/features/reporty/domain/report.dart';

PolozkaReportu _polozka({
  required DateTime zahajeno,
  required double kwhStart,
  required double kwhEnd,
  String vozidlo = 'Škoda Enyaq · 2AB 3344',
}) => PolozkaReportu(
  relace: Relace(
    id: zahajeno.toIso8601String(),
    uid: 'u1',
    spz: '2AB 3344',
    vozidloId: 'v1',
    kwhStart: kwhStart,
    kwhEnd: kwhEnd,
    zahajeno: zahajeno,
    fotoStart: FotoMetadata(path: 'a', sha256: 'x' * 64, porizenoAt: zahajeno),
    stav: StavRelace.dokonceno,
  ),
  vozidlo: vozidlo,
);

PodkladReportu _podklad(List<PolozkaReportu> polozky) => PodkladReportu(
  jmeno: 'Jan Švihálek',
  osobniCislo: '12345',
  obdobi: Obdobi(od: DateTime(2026, 8), doVcetne: DateTime(2026, 8, 31)),
  polozky: polozky,
  vytvorenoAt: DateTime(2026, 9, 1, 8, 30),
);

/// Rozbalí XLSX a vrátí obsah jednoho souboru uvnitř.
String _cast(List<int> xlsx, String cesta) {
  final archiv = ZipDecoder().decodeBytes(xlsx);
  final soubor = archiv.files.firstWhere(
    (f) => f.name == cesta,
    orElse: () => throw StateError('v archivu chybí $cesta'),
  );
  return utf8.decode(soubor.readBytes()!);
}

void main() {
  final dveNabijeni = [
    _polozka(
      zahajeno: DateTime(2026, 8, 4, 7, 12),
      kwhStart: 100,
      kwhEnd: 127.49,
    ),
    _polozka(
      zahajeno: DateTime(2026, 8, 20, 18, 40),
      kwhStart: 127.49,
      kwhEnd: 152.21,
    ),
  ];

  group('struktura sešitu', () {
    // Excel soubor bez některé z těchhle částí neotevře vůbec, nebo
    // ohlásí poškozený dokument – proto se kontroluje jejich přítomnost.
    test('archiv obsahuje všechny povinné části', () {
      final bajty = ReportXlsx.sestav(_podklad(dveNabijeni));
      final jmena = ZipDecoder()
          .decodeBytes(bajty)
          .files
          .map((f) => f.name)
          .toSet();

      expect(jmena, {
        '[Content_Types].xml',
        '_rels/.rels',
        'xl/workbook.xml',
        'xl/_rels/workbook.xml.rels',
        'xl/styles.xml',
        'xl/worksheets/sheet1.xml',
      });
    });

    test('začíná signaturou ZIP', () {
      final bajty = ReportXlsx.sestav(_podklad(dveNabijeni));
      expect(bajty.sublist(0, 2), [0x50, 0x4B]);
    });
  });

  group('obsah tabulky', () {
    test('hlavička nese všech pět sloupců', () {
      final list = _cast(
        ReportXlsx.sestav(_podklad(dveNabijeni)),
        'xl/worksheets/sheet1.xml',
      );

      for (final nadpis in [
        'Datum',
        'Vozidlo',
        'Počáteční stav (kWh)',
        'Koncový stav (kWh)',
        'Spotřeba (kWh)',
      ]) {
        expect(list, contains('<t xml:space="preserve">$nadpis</t>'));
      }
    });

    test('stavy počítadla jsou v buňkách jako čísla', () {
      final list = _cast(
        ReportXlsx.sestav(_podklad(dveNabijeni)),
        'xl/worksheets/sheet1.xml',
      );

      expect(list, contains('<v>100.0</v>'));
      expect(list, contains('<v>127.49</v>'));
      expect(list, contains('<v>152.21</v>'));
    });

    // Vzorec i hodnota: vzorec kvůli přepočtu po úpravě řádku, hodnota
    // kvůli náhledům, které vzorce nepočítají.
    test('součet je vzorec přes datové řádky i spočítaná hodnota', () {
      final list = _cast(
        ReportXlsx.sestav(_podklad(dveNabijeni)),
        'xl/worksheets/sheet1.xml',
      );

      expect(list, contains('<f>SUM(E2:E3)</f>'));
      expect(list, contains('<v>52.21</v>'), reason: '27,49 + 24,72');
      expect(list, contains('<t xml:space="preserve">Celkem</t>'));
    });

    test('datum je excelovské pořadové číslo dne', () {
      final list = _cast(
        ReportXlsx.sestav(_podklad(dveNabijeni)),
        'xl/worksheets/sheet1.xml',
      );

      // 4. 8. 2026 = 46238 dnů od 30. 12. 1899.
      final ocekavane = DateTime(
        2026,
        8,
        4,
      ).difference(DateTime(1899, 12, 30)).inDays;
      expect(list, contains('<v>$ocekavane</v>'));
    });

    test('prázdné období dá tabulku se součtem nula', () {
      final list = _cast(
        ReportXlsx.sestav(_podklad(const [])),
        'xl/worksheets/sheet1.xml',
      );

      expect(list, contains('<t xml:space="preserve">Celkem</t>'));
      expect(list, isNot(contains('<f>SUM')), reason: 'není co sčítat');
      expect(list, contains('<v>0.0</v>'));
    });

    // Ampersand v názvu vozidla by rozbil XML a Excel by soubor odmítl.
    test('speciální znaky v názvu vozidla se ošetří', () {
      final list = _cast(
        ReportXlsx.sestav(
          _podklad([
            _polozka(
              zahajeno: DateTime(2026, 8, 4),
              kwhStart: 1,
              kwhEnd: 2,
              vozidlo: 'Rolls-Royce & spol. <test>',
            ),
          ]),
        ),
        'xl/worksheets/sheet1.xml',
      );

      expect(list, contains('Rolls-Royce &amp; spol. &lt;test&gt;'));
      expect(list, isNot(contains('& spol')));
    });
  });

  group('název souboru', () {
    test('tabulka má příponu xlsx', () {
      final obdobi = Obdobi(
        od: DateTime(2026, 8),
        doVcetne: DateTime(2026, 8, 31),
      );
      expect(
        ReportController.nazevSouboru('Jan Švihálek', obdobi, pripona: 'xlsx'),
        'report-nabijeni-jan-svihalek-2026-08-01-2026-08-31.xlsx',
      );
      expect(
        ReportController.nazevSouboru('Jan Švihálek', obdobi),
        endsWith('.pdf'),
        reason: 'PDF zůstává výchozí',
      );
    });
  });
}
