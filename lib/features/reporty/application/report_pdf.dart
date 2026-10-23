import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../common/formatovani.dart';
import '../../elektromery/domain/elektromer.dart';
import '../../elektromery/domain/identifikace.dart';
import '../domain/report.dart';

/// Sestavení PDF reportu.
///
/// Rozvržení: nejdřív tabulka všech nabíjení se součtem, za ní oddíl
/// s fotkami po dvojicích. Kdo řeší jen čísla, dál nelistuje.
class ReportPdf {
  const ReportPdf({required this.zakladni, required this.tucne});

  final pw.Font zakladni;
  final pw.Font tucne;

  /// Vestavěné fonty balíčku `pdf` (Helvetica) neumí háčky ani čárky –
  /// „Švihálek" by se vysázel jako „Svihlek". Font se proto vkládá do
  /// dokumentu z assetů; přibalený Roboto je i offline.
  static Future<ReportPdf> nacti() async {
    final zakladni = await rootBundle.load('assets/fonty/Roboto-Regular.ttf');
    final tucne = await rootBundle.load('assets/fonty/Roboto-Bold.ttf');
    return ReportPdf(
      zakladni: pw.Font.ttf(zakladni),
      tucne: pw.Font.ttf(tucne),
    );
  }

  static const _seda = PdfColor.fromInt(0xFF6B7280);
  static const _linka = PdfColor.fromInt(0xFFD1D5DB);
  static const _zahlavi = PdfColor.fromInt(0xFFF3F4F6);

  Future<Uint8List> sestav(PodkladReportu podklad) async {
    final dokument = pw.Document(
      title: 'Report nabíjení',
      author: podklad.jmeno,
    );

    dokument.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 28),
        theme: pw.ThemeData.withFont(base: zakladni, bold: tucne),
        footer: _pata,
        build: (context) => [
          _hlavicka(podklad),
          pw.SizedBox(height: 18),
          if (podklad.polozky.isEmpty)
            _prazdno()
          else ...[
            _tabulka(podklad),
            pw.SizedBox(height: 10),
            _soucet(podklad),
            if (podklad.maNejakeFotky) ..._fotky(podklad),
          ],
        ],
      ),
    );

    return dokument.save();
  }

  /// Report jednoho odběrného místa: vývoj stavu, spotřeba mezi odečty
  /// a změna proti předchozímu období. Jednotka podle druhu místa.
  Future<Uint8List> sestavElektromer(PodkladElektromeru podklad) async {
    final e = podklad.elektromer;
    final dokument = pw.Document(
      title: 'Report odběrného místa ${e.druh.nazev} – ${e.nazev}',
      author: 'RenoEnergy',
    );

    dokument.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 28),
        theme: pw.ThemeData.withFont(base: zakladni, bold: tucne),
        footer: _pata,
        build: (context) => [
          _hlavickaElektromeru(podklad),
          pw.SizedBox(height: 18),
          if (podklad.polozky.isEmpty)
            _prazdnoElektromer()
          else ...[
            _tabulkaOdectu(podklad),
            pw.SizedBox(height: 10),
            _soucetOdectu(podklad),
            if (podklad.maNejakeFotky) ..._fotkyOdectu(podklad),
          ],
        ],
      ),
    );

    return dokument.save();
  }

  pw.Widget _hlavickaElektromeru(PodkladElektromeru podklad) {
    final e = podklad.elektromer;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Report odběrného místa',
          style: pw.TextStyle(font: tucne, fontSize: 20),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          '${e.druh.nazev} · ${e.nazev}',
          style: const pw.TextStyle(fontSize: 11),
        ),
        pw.Text(
          [
            if (e.maCislo) 'č. ${e.cislo}',
            e.pobocka?.popisek ?? e.pobockaKod,
          ].join(' · '),
          style: const pw.TextStyle(fontSize: 11),
        ),
        pw.Text(
          'Období ${Format.datum(podklad.obdobi.od)} – '
          '${Format.datum(podklad.obdobi.doVcetne)}',
          style: const pw.TextStyle(fontSize: 11),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'Vytvořeno ${Format.datum(podklad.vytvorenoAt)} '
          'v ${Format.cas(podklad.vytvorenoAt)}',
          style: const pw.TextStyle(fontSize: 9, color: _seda),
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: _linka, height: 1),
      ],
    );
  }

  pw.Widget _prazdnoElektromer() => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 24),
    child: pw.Text(
      'Ve zvoleném období tu není žádný odečet.',
      style: const pw.TextStyle(fontSize: 11, color: _seda),
    ),
  );

  pw.Widget _tabulkaOdectu(PodkladElektromeru podklad) {
    final jednotka = podklad.elektromer.druh.jednotka;
    return pw.TableHelper.fromTextArray(
      headers: [
        'Datum',
        'Stav ($jednotka)',
        'Spotřeba ($jednotka)',
        'Změna',
        'Poznámka',
      ],
      data: [
        for (final p in podklad.polozky)
          [
            Format.datum(p.odecet.odectenoAt),
            Format.kwh(p.odecet.hodnota),
            p.spotreba == null ? '–' : Format.kwh(p.spotreba!),
            _zmena(p.zmenaProcent),
            p.odecet.vymenaMeridla ? 'nové měřidlo' : (p.odecet.poznamka ?? ''),
          ],
      ],
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _linka, width: 0.5),
        bottom: pw.BorderSide(color: _linka, width: 0.5),
      ),
      headerDecoration: const pw.BoxDecoration(color: _zahlavi),
      headerStyle: pw.TextStyle(font: tucne, fontSize: 9),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      headerAlignment: pw.Alignment.centerLeft,
      cellAlignments: const {
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
      },
      columnWidths: const {
        0: pw.FlexColumnWidth(1.5),
        1: pw.FlexColumnWidth(1.7),
        2: pw.FlexColumnWidth(1.5),
        3: pw.FlexColumnWidth(1.2),
        4: pw.FlexColumnWidth(2.4),
      },
    );
  }

  /// Skokový nárůst je ten signál, kvůli kterému se odečty čtou, proto
  /// se změna ukazuje se znaménkem a ne jen jako poměr.
  static String _zmena(double? procenta) {
    if (procenta == null) return '–';
    final znamenko = procenta > 0 ? '+' : '';
    return '$znamenko${procenta.toStringAsFixed(0).replaceAll('-', '−')} %';
  }

  pw.Widget _soucetOdectu(PodkladElektromeru podklad) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.end,
    children: [
      pw.Text('Celkem za období: ', style: const pw.TextStyle(fontSize: 11)),
      pw.Text(
        '${Format.kwh(podklad.celkovaSpotreba)} '
        '${podklad.elektromer.druh.jednotka}',
        style: pw.TextStyle(font: tucne, fontSize: 13),
      ),
    ],
  );

  List<pw.Widget> _fotkyOdectu(PodkladElektromeru podklad) => [
    pw.SizedBox(height: 24),
    pw.Text(
      'Fotografie počítadla',
      style: pw.TextStyle(font: tucne, fontSize: 13),
    ),
    pw.SizedBox(height: 10),
    pw.Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final p in podklad.polozky)
          if (p.foto != null)
            pw.SizedBox(
              width: 160,
              child: _snimek(
                '${Format.datum(p.odecet.odectenoAt)} · '
                '${Format.kwh(p.odecet.hodnota)} '
                '${podklad.elektromer.druh.jednotka}',
                p.foto,
              ),
            ),
      ],
    ),
  ];

  /// Arch QR štítků na samolepicí etikety **52,5 × 29,7 mm, 4 × 10 na A4**
  /// (40 kusů na arch, bez okrajů – etikety jdou až ke hraně papíru).
  ///
  /// Odběrná místa v terénu QR kód nemají, takže si ho firma nalepí.
  /// Vedle kódu je umístění, druh a číslo, aby šlo štítek nalepit na
  /// správné měřidlo a aby se dal přečíst i okem, když se kód poškrábe.
  /// Druh je tam kvůli místům, která se jmenují stejně – „Servis" je
  /// plynoměr, elektroměr, klimatizace i nabíječka.
  ///
  /// [preskocit] je počet už použitých etiket na začátku archu. Bez něj by
  /// dotisk jednoho poškozeného štítku spotřeboval nový arch, nebo by se
  /// tiskl na místo, kde etiketa už chybí. Etikety se počítají po řádcích
  /// zleva doprava.
  Future<Uint8List> sestavStitky(
    List<Elektromer> elektromery, {
    int preskocit = 0,
  }) async {
    final dokument = pw.Document(title: 'QR štítky odběrných míst');
    final stranka = PdfPageFormat.a4.copyWith(
      marginLeft: 0,
      marginTop: 0,
      marginRight: 0,
      marginBottom: 0,
    );

    final pozice = [
      for (var i = 0; i < elektromery.length; i++)
        (pozice: preskocit + i, misto: elektromery[i]),
    ];
    final pocetStran = pozice.isEmpty
        ? 1
        : (pozice.last.pozice ~/ ArchStitku.naArch) + 1;

    for (var strana = 0; strana < pocetStran; strana++) {
      dokument.addPage(
        pw.Page(
          pageFormat: stranka,
          theme: pw.ThemeData.withFont(base: zakladni, bold: tucne),
          build: (context) => pw.Stack(
            children: [
              for (final p in pozice)
                if (p.pozice ~/ ArchStitku.naArch == strana)
                  pw.Positioned(
                    left: (p.pozice % ArchStitku.sloupce) * ArchStitku.sirka,
                    top:
                        (p.pozice % ArchStitku.naArch ~/ ArchStitku.sloupce) *
                        ArchStitku.vyska,
                    child: _stitek(p.misto),
                  ),
            ],
          ),
        ),
      );
    }

    return dokument.save();
  }

  /// Jedna etiketa. Okraje uvnitř jsou větší, než by stačilo: krajní
  /// etikety sahají až ke hraně papíru a tiskárny u ní pár milimetrů
  /// netisknou – kód tak zůstane celý i na krajních etiketách.
  pw.Widget _stitek(Elektromer e) => pw.SizedBox(
    width: ArchStitku.sirka,
    height: ArchStitku.vyska,
    child: pw.Padding(
      padding: const pw.EdgeInsets.fromLTRB(
        3.5 * PdfPageFormat.mm,
        0,
        3 * PdfPageFormat.mm,
        0,
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // 20 mm: s rezervou čitelné telefonem z ruky a nahoře i dole
          // zbude skoro 5 mm, kam tiskárna u hrany papíru ještě dosáhne.
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: obsahQr(e),
            width: 20 * PdfPageFormat.mm,
            height: 20 * PdfPageFormat.mm,
            drawText: false,
          ),
          pw.SizedBox(width: 2 * PdfPageFormat.mm),
          pw.Expanded(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  e.nazev,
                  style: pw.TextStyle(font: tucne, fontSize: 8),
                  maxLines: 3,
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  '${e.druh.nazev} · ${e.pobocka?.kod ?? e.pobockaKod}',
                  style: const pw.TextStyle(fontSize: 6.5, color: _seda),
                ),
                if (e.maCislo)
                  pw.Text(
                    'č. ${e.cislo}',
                    style: const pw.TextStyle(fontSize: 6.5, color: _seda),
                    maxLines: 1,
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  pw.Widget _hlavicka(PodkladReportu podklad) {
    final osoba = [
      podklad.jmeno,
      if (podklad.osobniCislo != null) 'osobní č. ${podklad.osobniCislo}',
    ].join(' · ');

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Report nabíjení',
          style: pw.TextStyle(font: tucne, fontSize: 20),
        ),
        pw.SizedBox(height: 4),
        pw.Text(osoba, style: const pw.TextStyle(fontSize: 11)),
        pw.Text(
          'Období ${Format.datum(podklad.obdobi.od)} – '
          '${Format.datum(podklad.obdobi.doVcetne)}',
          style: const pw.TextStyle(fontSize: 11),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'Vytvořeno ${Format.datum(podklad.vytvorenoAt)} '
          'v ${Format.cas(podklad.vytvorenoAt)}',
          style: const pw.TextStyle(fontSize: 9, color: _seda),
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: _linka, height: 1),
      ],
    );
  }

  pw.Widget _prazdno() => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 24),
    child: pw.Text(
      'Ve zvoleném období není žádné dokončené nabíjení.',
      style: const pw.TextStyle(fontSize: 11, color: _seda),
    ),
  );

  pw.Widget _tabulka(PodkladReportu podklad) {
    return pw.TableHelper.fromTextArray(
      headers: const [
        'Datum',
        'Čas',
        'Vozidlo',
        'Začátek',
        'Konec',
        'Spotřeba',
      ],
      data: [
        for (final p in podklad.polozky)
          [
            Format.datum(p.relace.zahajeno),
            // U nabíječky bez počítadla je známý jen čas fotky po nabití,
            // rozsah „08:15 – 08:15" by tvrdil nabíjení na nula minut.
            if (p.relace.bezPocitadla)
              Format.cas(p.relace.zahajeno)
            else
              Format.rozsahCasu(p.relace.zahajeno, p.relace.ukonceno),
            p.vozidlo,
            // Pomlčka, ne nula: nabíječka bez počítadla stav nemá a nula
            // by vypadala jako odečtená hodnota.
            _kwhNeboPomlcka(p.relace.kwhStart),
            _kwhNeboPomlcka(p.relace.kwhEnd),
            Format.kwh(p.relace.spotreba ?? 0),
          ],
      ],
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _linka, width: 0.5),
        bottom: pw.BorderSide(color: _linka, width: 0.5),
      ),
      headerDecoration: const pw.BoxDecoration(color: _zahlavi),
      headerStyle: pw.TextStyle(font: tucne, fontSize: 9),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      headerAlignment: pw.Alignment.centerLeft,
      // Čísla doprava, ať jdou řády pod sebou.
      cellAlignments: const {
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
      },
      columnWidths: const {
        0: pw.FlexColumnWidth(1.5),
        1: pw.FlexColumnWidth(1.7),
        2: pw.FlexColumnWidth(2.4),
        3: pw.FlexColumnWidth(1.6),
        4: pw.FlexColumnWidth(1.6),
        5: pw.FlexColumnWidth(1.5),
      },
    );
  }

  pw.Widget _soucet(PodkladReportu podklad) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.end,
    children: [
      pw.Text('Celkem za období: ', style: const pw.TextStyle(fontSize: 11)),
      pw.Text(
        '${Format.kwh(podklad.celkovaSpotreba)} kWh',
        style: pw.TextStyle(font: tucne, fontSize: 13),
      ),
    ],
  );

  List<pw.Widget> _fotky(PodkladReportu podklad) => [
    pw.SizedBox(height: 24),
    pw.Text(
      'Fotografie počítadla',
      style: pw.TextStyle(font: tucne, fontSize: 13),
    ),
    pw.SizedBox(height: 2),
    pw.Text(
      'Stav počítadla před nabíjením a po něm, tak jak ho uživatel vyfotil. '
      'U nabíječky bez počítadla displej s nabitou energií.',
      style: const pw.TextStyle(fontSize: 9, color: _seda),
    ),
    pw.SizedBox(height: 10),
    for (final p in podklad.polozky)
      if (p.maFotky) _dvojiceFotek(p),
  ];

  /// Jedna dvojice fotek. `pw.Wrap` s celou dvojicí drží popisek
  /// a snímky pohromadě – MultiPage jinak umí zlomit stránku uprostřed.
  pw.Widget _dvojiceFotek(PolozkaReportu p) => pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 14),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '${Format.datum(p.relace.zahajeno)} · ${p.vozidlo} · '
          '${Format.kwh(p.relace.spotreba ?? 0)} kWh',
          style: pw.TextStyle(font: tucne, fontSize: 10),
        ),
        pw.SizedBox(height: 5),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (p.relace.bezPocitadla) ...[
              // Jediný snímek na místě levého z dvojice, ať mají všechny
              // fotky v reportu stejnou velikost.
              pw.Expanded(
                child: _snimek(
                  'Nabito · ${Format.kwh(p.relace.spotreba ?? 0)} kWh',
                  p.fotoEnd,
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(child: pw.SizedBox()),
            ] else ...[
              pw.Expanded(
                child: _snimek(
                  'Začátek · ${_kwhNeboPomlcka(p.relace.kwhStart)} kWh',
                  p.fotoStart,
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: _snimek(
                  'Konec · ${_kwhNeboPomlcka(p.relace.kwhEnd)} kWh',
                  p.fotoEnd,
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );

  pw.Widget _snimek(String popisek, Uint8List? bajty) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(popisek, style: const pw.TextStyle(fontSize: 8, color: _seda)),
      pw.SizedBox(height: 3),
      pw.Container(
        height: 150,
        width: double.infinity,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _linka, width: 0.5),
        ),
        alignment: pw.Alignment.center,
        child: bajty == null
            ? pw.Text(
                'Fotka není k dispozici',
                style: const pw.TextStyle(fontSize: 8, color: _seda),
              )
            : pw.Image(pw.MemoryImage(bajty), fit: pw.BoxFit.contain),
      ),
    ],
  );

  pw.Widget _pata(pw.Context context) => pw.Container(
    alignment: pw.Alignment.centerRight,
    margin: const pw.EdgeInsets.only(top: 8),
    child: pw.Text(
      'Strana ${context.pageNumber} z ${context.pagesCount}',
      style: const pw.TextStyle(fontSize: 8, color: _seda),
    ),
  );
}

String _kwhNeboPomlcka(double? kwh) => kwh == null ? '–' : Format.kwh(kwh);

/// Arch samolepicích etiket: 52,5 × 29,7 mm, 4 sloupce × 10 řádků na A4,
/// bez okrajů. Rozměry přesně dělí A4 (210 / 4, 297 / 10).
abstract final class ArchStitku {
  static const int sloupce = 4;
  static const int radky = 10;
  static const int naArch = sloupce * radky;

  static const double sirka = 52.5 * PdfPageFormat.mm;
  static const double vyska = 29.7 * PdfPageFormat.mm;
}
