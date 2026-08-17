import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../domain/report.dart';

/// Tabulka nabíjení pro Excel.
///
/// Soubor se skládá ručně, ne knihovnou: jediný balíček, který XLSX umí
/// zapisovat, stojí na `archive 3`, zatímco `image` (zmenšování fotek
/// a snímky v PDF) potřebuje `archive 4`. Formát je přitom ZIP s pár
/// XML soubory a tahle tabulka má pět sloupců bez jediného sloučeného
/// pole – vlastní zapisovač vyjde levněji než výměna knihovny na fotky.
///
/// Fotky v tabulce nejsou schválně. Kdo chce snímky počítadel, vezme si
/// PDF; XLSX je na počítání.
abstract final class ReportXlsx {
  /// Pořadí sloupců odpovídá tomu, jak se čísla čtou: co bylo na začátku,
  /// co na konci, kolik z toho vyšlo.
  static const _hlavicka = [
    'Datum',
    'Vozidlo',
    'Počáteční stav (kWh)',
    'Koncový stav (kWh)',
    'Spotřeba (kWh)',
  ];

  /// Šířky sloupců v znacích. Bez nich by se dlouhé nadpisy schovaly
  /// pod sousední buňku a uživatel by je musel roztahovat ručně.
  static const _sirky = [12.0, 26.0, 20.0, 20.0, 18.0];

  static Uint8List sestav(PodkladReportu podklad) {
    final archiv = Archive();

    void pridej(String cesta, String obsah) {
      final bajty = utf8.encode(obsah);
      archiv.add(ArchiveFile.bytes(cesta, bajty));
    }

    pridej('[Content_Types].xml', _typyObsahu);
    pridej('_rels/.rels', _korenoveVztahy);
    pridej('xl/workbook.xml', _sesit);
    pridej('xl/_rels/workbook.xml.rels', _vztahySesitu);
    pridej('xl/styles.xml', _styly);
    pridej('xl/worksheets/sheet1.xml', _list(podklad));

    final zip = ZipEncoder().encodeBytes(archiv);
    return Uint8List.fromList(zip);
  }

  static String _list(PodkladReportu podklad) {
    final radky = StringBuffer();
    var cislo = 1;

    // Hlavička
    radky.write('<row r="$cislo">');
    for (var i = 0; i < _hlavicka.length; i++) {
      radky.write(_text(_adresa(i, cislo), _hlavicka[i], styl: _stylNadpis));
    }
    radky.write('</row>');

    final prvniDatovy = cislo + 1;
    for (final polozka in podklad.polozky) {
      cislo++;
      final r = polozka.relace;
      radky
        ..write('<row r="$cislo">')
        ..write(_datum(_adresa(0, cislo), r.zahajeno))
        ..write(_text(_adresa(1, cislo), polozka.vozidlo))
        ..write(_cislo(_adresa(2, cislo), r.kwhStart))
        ..write(_cislo(_adresa(3, cislo), r.kwhEnd))
        ..write(_cislo(_adresa(4, cislo), r.spotreba))
        ..write('</row>');
    }
    final posledniDatovy = cislo;

    // Součtový řádek. Vzorec i spočítaná hodnota schválně obojí:
    // vzorec kvůli tomu, aby se součet přepočítal po úpravě řádku,
    // hodnota kvůli náhledům, které vzorce nepočítají.
    cislo++;
    radky
      ..write('<row r="$cislo">')
      ..write(_text(_adresa(0, cislo), 'Celkem', styl: _stylNadpis));
    if (podklad.polozky.isEmpty) {
      radky.write(_cislo(_adresa(4, cislo), 0, styl: _stylSoucet));
    } else {
      final rozsah = 'E$prvniDatovy:E$posledniDatovy';
      radky.write(
        '<c r="${_adresa(4, cislo)}" s="$_stylSoucet">'
        '<f>SUM($rozsah)</f>'
        '<v>${_zapisCislo(podklad.celkovaSpotreba)}</v>'
        '</c>',
      );
    }
    radky.write('</row>');

    final sloupce = StringBuffer('<cols>');
    for (var i = 0; i < _sirky.length; i++) {
      sloupce.write(
        '<col min="${i + 1}" max="${i + 1}" '
        'width="${_sirky[i]}" customWidth="1"/>',
      );
    }
    sloupce.write('</cols>');

    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<worksheet xmlns="$_jmennyProstor">'
        // Zmrazený první řádek: u delšího období odjede hlavička nahoru
        // a čísla ve sloupcích pak nikdo nerozliší.
        '<sheetViews><sheetView workbookViewId="0">'
        '<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" '
        'state="frozen"/>'
        '</sheetView></sheetViews>'
        '$sloupce'
        '<sheetData>$radky</sheetData>'
        '</worksheet>';
  }

  /// `A1`, `B7` – sloupců je pět, takže se dvoupísmenná adresa neřeší.
  static String _adresa(int sloupec, int radek) =>
      '${String.fromCharCode(65 + sloupec)}$radek';

  static String _text(String adresa, String hodnota, {int styl = 0}) =>
      '<c r="$adresa" t="inlineStr" s="$styl">'
      '<is><t xml:space="preserve">${_escape(hodnota)}</t></is>'
      '</c>';

  static String _cislo(String adresa, double? hodnota, {int? styl}) {
    if (hodnota == null) return '';
    return '<c r="$adresa" s="${styl ?? _stylCislo}">'
        '<v>${_zapisCislo(hodnota)}</v></c>';
  }

  static String _datum(String adresa, DateTime kdy) =>
      '<c r="$adresa" s="$_stylDatum"><v>${_serioveDatum(kdy)}</v></c>';

  /// Excel počítá dny od 30. 12. 1899 – posun o dva dny oproti intuici
  /// je dědictví chyby v Lotusu 1-2-3, kterou Excel schválně zopakoval.
  ///
  /// Počítá se přes rozdíl kalendářních dnů, ne přes hodiny: v den
  /// přechodu na zimní čas má den 25 hodin a dělením by vyšel o den míň.
  static int _serioveDatum(DateTime kdy) {
    final den = DateTime(kdy.toLocal().year, kdy.toLocal().month, kdy.day);
    return den.difference(DateTime(1899, 12, 30)).inDays;
  }

  /// Do XML jde číslo vždy s desetinnou tečkou bez ohledu na národní
  /// prostředí. Jak se zobrazí, si Excel rozhodne sám podle formátu.
  static String _zapisCislo(double hodnota) {
    final zaokrouhlene = (hodnota * 100).round() / 100;
    return zaokrouhlene.toString();
  }

  static String _escape(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  static const _jmennyProstor =
      'http://schemas.openxmlformats.org/spreadsheetml/2006/main';

  // Indexy do <cellXfs> ve stylech níž.
  static const int _stylNadpis = 1;
  static const int _stylCislo = 2;
  static const int _stylSoucet = 3;
  static const int _stylDatum = 4;

  static const _typyObsahu =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" '
      'ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.'
      'openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/'
      'vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
      '<Override PartName="/xl/styles.xml" ContentType="application/vnd.'
      'openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
      '</Types>';

  static const _korenoveVztahy =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/'
      'officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
      '</Relationships>';

  static const _sesit =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<workbook xmlns="$_jmennyProstor" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
      '<sheets><sheet name="Nabíjení" sheetId="1" r:id="rId1"/></sheets>'
      '</workbook>';

  /// Sešit musí na styly **odkazovat**. Bez téhle vazby soubor
  /// `styles.xml` v archivu leží nevyužitý, Excel ho vůbec nenačte
  /// a všechny odkazy na styl v buňkách spadnou na výchozí formát –
  /// datum se pak ukáže jako pořadové číslo dne.
  static const _vztahySesitu =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/'
      'officeDocument/2006/relationships/worksheet" '
      'Target="worksheets/sheet1.xml"/>'
      '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/'
      'officeDocument/2006/relationships/styles" Target="styles.xml"/>'
      '</Relationships>';

  /// Vlastní formáty začínají od 164, nižší čísla má Excel obsazená.
  static const _styly =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<styleSheet xmlns="$_jmennyProstor">'
      '<numFmts count="2">'
      '<numFmt numFmtId="164" formatCode="#,##0.00"/>'
      '<numFmt numFmtId="165" formatCode="d\\.m\\.yyyy"/>'
      '</numFmts>'
      '<fonts count="2">'
      '<font><sz val="11"/><name val="Calibri"/></font>'
      '<font><b/><sz val="11"/><name val="Calibri"/></font>'
      '</fonts>'
      '<fills count="2"><fill><patternFill patternType="none"/></fill>'
      '<fill><patternFill patternType="gray125"/></fill></fills>'
      '<borders count="1"><border/></borders>'
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0"/></cellStyleXfs>'
      '<cellXfs count="5">'
      '<xf numFmtId="0" fontId="0" xfId="0"/>'
      '<xf numFmtId="0" fontId="1" xfId="0" applyFont="1"/>'
      '<xf numFmtId="164" fontId="0" xfId="0" applyNumberFormat="1"/>'
      '<xf numFmtId="164" fontId="1" xfId="0" '
      'applyNumberFormat="1" applyFont="1"/>'
      '<xf numFmtId="165" fontId="0" xfId="0" applyNumberFormat="1"/>'
      '</cellXfs>'
      '</styleSheet>';
}
