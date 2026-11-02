import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renocharge/common/formatovani.dart';
import 'package:renocharge/common/motiv/motiv.dart';
import 'package:renocharge/features/auth/application/auth_providery.dart';
import 'package:renocharge/features/auth/domain/uzivatel.dart';
import 'package:renocharge/features/nabijeni/application/nabijeni_providery.dart';
import 'package:renocharge/features/nabijeni/domain/relace.dart';
import 'package:renocharge/features/nabijeni/presentation/domovska_obrazovka.dart';
import 'package:renocharge/features/reporty/application/exporty_providery.dart';
import 'package:renocharge/features/reporty/domain/report.dart';
import 'package:renocharge/features/reporty/domain/zaznam_exportu.dart';
import 'package:renocharge/features/reporty/presentation/export_nabijeni_panel.dart';
import 'package:renocharge/features/vozidla/application/vozidla_providery.dart';
import 'package:renocharge/features/vozidla/domain/vozidlo.dart';

Relace _relace(
  String id,
  DateTime zahajeno, {
  double kwh = 40,
  DateTime? zapsano,
  StavRelace stav = StavRelace.dokonceno,
}) => Relace(
  id: id,
  uid: 'u1',
  spz: 'EL238FV',
  vozidloId: 'v1',
  zahajeno: zahajeno,
  kwhStart: stav == StavRelace.probiha ? 100 : 0,
  kwhEnd: stav == StavRelace.probiha ? null : kwh,
  aktualizovanoAt: stav == StavRelace.probiha
      ? null
      : zapsano ?? zahajeno.add(const Duration(hours: 5)),
  ukonceno: stav == StavRelace.probiha
      ? null
      : zahajeno.add(const Duration(hours: 5)),
  stav: stav,
);

ZaznamExportu _report(
  DateTime od,
  DateTime doVcetne,
  DateTime vytvoreno, {
  int pocet = 12,
  Set<FormatExportu> formaty = const {},
}) => ZaznamExportu(
  id: 'e${vytvoreno.millisecondsSinceEpoch}',
  uid: 'u1',
  obdobi: Obdobi(od: od, doVcetne: doVcetne),
  pocetZaznamu: pocet,
  sFotkami: false,
  vytvorenoAt: vytvoreno,
  formaty: formaty,
);

Widget _aplikace({
  required List<Relace> historie,
  required List<ZaznamExportu> exporty,
  Widget home = const Scaffold(body: SafeArea(child: DomovskaObrazovka())),
}) => ProviderScope(
  overrides: [
    profilProvider.overrideWith(
      (ref) => Stream.value(
        const Uzivatel(
          uid: 'u1',
          jmeno: 'Jan Švihálek',
          email: 'jan@priklad.cz',
          cenaZaKwh: 6.5,
        ),
      ),
    ),
    vozidlaProvider.overrideWith(
      (ref) => Stream.value(const [
        Vozidlo(id: 'v1', spz: 'EL238FV', znackaModel: 'Tesla Model 3'),
      ]),
    ),
    otevrenaRelaceProvider.overrideWith((ref) => Stream.value(null)),
    historieProvider.overrideWith((ref) => Stream.value(historie)),
    historieExportuProvider.overrideWith((ref) => Stream.value(exporty)),
  ],
  child: MaterialApp(theme: Motiv.tmavy(), home: home),
);

void _telefon(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('cs_CZ');
  });

  group('je nabíjení v reportu', () {
    final report = _report(
      DateTime(2026, 9, 13),
      DateTime(2026, 10, 28),
      DateTime(2026, 11, 2, 9),
    );

    test('dokončené v období před vytvořením reportu ano', () {
      expect(report.zahrnuje(_relace('a', DateTime(2026, 10, 21))), isTrue);
    });

    test('mimo období ne', () {
      expect(report.zahrnuje(_relace('a', DateTime(2026, 10, 29))), isFalse);
    });

    test('poslední den období je celý uvnitř', () {
      expect(
        report.zahrnuje(_relace('a', DateTime(2026, 10, 28, 23, 30))),
        isTrue,
      );
    });

    // Zahájeno v období, ale ukončené až po reportu: report ho nezahrnul,
    // protože tenkrát ještě běželo. Podle data by se nikdy nevyfakturovalo.
    test('dokončené až po vytvoření reportu ne', () {
      final pozdni = _relace(
        'a',
        DateTime(2026, 10, 28),
        zapsano: DateTime(2026, 11, 3),
      );
      expect(report.zahrnuje(pozdni), isFalse);
    });

    test('běžící ne', () {
      expect(
        report.zahrnuje(
          _relace('a', DateTime(2026, 10, 21), stav: StavRelace.probiha),
        ),
        isFalse,
      );
    });

    test('spotřeba reportu sečte jen jeho nabíjení', () {
      expect(
        report.spotrebaZ([
          _relace('a', DateTime(2026, 10, 21), kwh: 10),
          _relace('b', DateTime(2026, 10, 1), kwh: 5),
          _relace('c', DateTime(2026, 11, 1), kwh: 100),
        ]),
        15,
      );
    });
  });

  group('nová nabíjení k exportu', () {
    final report = _report(
      DateTime(2026, 9, 13),
      DateTime(2026, 10, 28),
      DateTime(2026, 11, 2, 9),
    );

    test('běžící a schválená mezi nová nepatří', () {
      final nove = noveKExportu(
        [
          _relace('nove', DateTime(2026, 11, 2)),
          _relace('hotove', DateTime(2026, 10, 21)),
          _relace('bezi', DateTime(2026, 11, 3), stav: StavRelace.probiha),
          _relace('ok', DateTime(2026, 11, 1), stav: StavRelace.schvaleno),
        ],
        [report],
      );
      expect(nove.map((r) => r.id), ['nove']);
    });

    test('bez nových není co nabízet', () {
      expect(
        NabidkaNovych.z([_relace('a', DateTime(2026, 10, 21))], [report]),
        isNull,
      );
    });

    test('navazuje dnem po konci posledního reportu', () {
      final nabidka = NabidkaNovych.z(
        [_relace('a', DateTime(2026, 11, 2), kwh: 38.74)],
        [report],
        ted: DateTime(2026, 11, 2),
      )!;
      expect(nabidka.obdobi.od, DateTime(2026, 10, 29));
      expect(nabidka.obdobi.doVcetne, DateTime(2026, 11, 2));
      expect(nabidka.pocet, 1);
      expect(nabidka.celkemKwh, closeTo(38.74, 0.001));
    });

    test('novější report posouvá navázání, starší ne', () {
      final nabidka = NabidkaNovych.z(
        [_relace('a', DateTime(2026, 11, 20))],
        [
          _report(
            DateTime(2026, 11),
            DateTime(2026, 11, 10),
            DateTime(2026, 11, 11),
          ),
          report,
        ],
        ted: DateTime(2026, 11, 20),
      )!;
      expect(nabidka.obdobi.od, DateTime(2026, 11, 11));
    });

    // Nabíjení zahájené v poslední den reportu a ukončené po něm. Kdyby
    // se začínalo až dnem po reportu, do žádného by se nedostalo.
    test('starší nové nabíjení období rozšíří', () {
      final nabidka = NabidkaNovych.z(
        [
          _relace(
            'pozdni',
            DateTime(2026, 10, 28, 18),
            zapsano: DateTime(2026, 11, 3),
          ),
        ],
        [report],
        ted: DateTime(2026, 11, 3),
      )!;
      expect(nabidka.obdobi.od, DateTime(2026, 10, 28));
    });

    test('bez reportů začíná nejstarším nabíjením', () {
      final nabidka = NabidkaNovych.z(
        [
          _relace('b', DateTime(2026, 8, 20)),
          _relace('a', DateTime(2026, 8, 4)),
        ],
        const [],
        ted: DateTime(2026, 8, 25),
      )!;
      expect(nabidka.obdobi.od, DateTime(2026, 8, 4));
      expect(nabidka.pocet, 2);
    });
  });

  test('popis výběru formátů nezávisí na pořadí', () {
    expect(
      FormatExportu.popisVyberu({FormatExportu.xlsx, FormatExportu.pdf}),
      'PDF + Excel',
    );
    expect(FormatExportu.popisVyberu({FormatExportu.xlsx}), 'Excel');
  });

  test('rozsah dnů ukáže rok jednou, přes přelom oba', () {
    expect(
      Format.rozsahDnu(DateTime(2026, 9, 13), DateTime(2026, 10, 28)),
      '13. 9. – 28. 10. 2026',
    );
    expect(
      Format.rozsahDnu(DateTime(2025, 12, 13), DateTime(2026, 1, 5)),
      '13. 12. 2025 – 5. 1. 2026',
    );
  });

  group('přehled nabíjení', () {
    final nove = _relace('nove', DateTime(2026, 11, 2), kwh: 38.74);
    final hotove = _relace('hotove', DateTime(2026, 10, 28), kwh: 45.2);
    final report = _report(
      DateTime(2026, 9, 13),
      DateTime(2026, 10, 28),
      DateTime(2026, 11, 2, 9),
    );

    testWidgets('řádky říkají, co je nové a co už v reportu', (tester) async {
      _telefon(tester);
      await tester.pumpWidget(
        _aplikace(historie: [nove, hotove], exporty: [report]),
      );
      await tester.pumpAndSettle();

      expect(find.text('NOVÉ'), findsOneWidget);
      expect(find.text('V reportu'), findsOneWidget);
      expect(find.textContaining('DOKONČENO'), findsNothing);
      expect(find.text('2. 11. · 38,74 kWh'), findsOneWidget);
      // 38,74 kWh × 6,50 Kč: na řádku i v předělu měsíce.
      expect(find.text('251,81 Kč'), findsNWidgets(2));
    });

    testWidgets('karta nabízí export nových', (tester) async {
      _telefon(tester);
      await tester.pumpWidget(
        _aplikace(historie: [nove, hotove], exporty: [report]),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 nové nabíjení k exportu'), findsOneWidget);
      expect(find.text('Poslední report 2. 11. · do 28. 10.'), findsOneWidget);
    });

    testWidgets('bez nových karta zmizí', (tester) async {
      _telefon(tester);
      await tester.pumpWidget(_aplikace(historie: [hotove], exporty: [report]));
      await tester.pumpAndSettle();

      expect(find.textContaining('k exportu'), findsNothing);
      expect(find.text('NOVÉ'), findsNothing);
    });

    testWidgets('bez načtených reportů se nic netváří jako nové', (
      tester,
    ) async {
      _telefon(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profilProvider.overrideWith((ref) => Stream.value(null)),
            vozidlaProvider.overrideWith((ref) => Stream.value(const [])),
            otevrenaRelaceProvider.overrideWith((ref) => Stream.value(null)),
            historieProvider.overrideWith((ref) => Stream.value([nove])),
            historieExportuProvider.overrideWith(
              (ref) => Stream.error(Exception('bez signálu')),
            ),
          ],
          child: MaterialApp(
            theme: Motiv.tmavy(),
            home: const Scaffold(body: DomovskaObrazovka()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('NOVÉ'), findsNothing);
      expect(find.textContaining('k exportu'), findsNothing);
    });
  });

  group('panel exportu', () {
    final nove = _relace('nove', DateTime(2026, 11, 2), kwh: 38.74);
    final report = _report(
      DateTime(2026, 9, 13),
      DateTime(2026, 10, 28),
      DateTime(2026, 11, 2, 9),
      formaty: {FormatExportu.pdf, FormatExportu.xlsx},
    );

    Future<void> otevri(
      WidgetTester tester, {
      List<Relace>? historie,
      List<ZaznamExportu>? exporty,
    }) async {
      _telefon(tester);
      await tester.pumpWidget(
        _aplikace(
          historie: historie ?? [nove],
          exporty: exporty ?? [report],
          home: const Scaffold(body: ExportNabijeniPanel()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('předvybrané jsou jen nové a oba formáty', (tester) async {
      await otevri(tester);

      expect(find.text('Jen nové od 29. 10.'), findsOneWidget);
      expect(find.text('1 nabíjení · 251,81 Kč'), findsOneWidget);
      expect(find.text('Vytvořit PDF + Excel'), findsOneWidget);
    });

    testWidgets('tlačítko říká, co vznikne', (tester) async {
      await otevri(tester);

      await tester.tap(find.text('Excel'));
      await tester.pump();
      expect(find.text('Vytvořit PDF'), findsOneWidget);

      await tester.tap(find.text('PDF'));
      await tester.pump();
      expect(find.text('Vyberte formát'), findsOneWidget);

      await tester.tap(find.text('Excel'));
      await tester.pump();
      expect(find.text('Vytvořit Excel'), findsOneWidget);
    });

    // Popis jedné karty se zalomí a obě se roztáhnou na její výšku. Nadpisy
    // musí zůstat v jedné řadě.
    testWidgets('nadpisy formátů jsou v jedné výšce', (tester) async {
      await otevri(tester);

      expect(
        tester.getTopLeft(find.text('PDF')).dy,
        tester.getTopLeft(find.text('Excel')).dy,
      );
    });

    testWidgets('fotky se nabízejí jen s PDF', (tester) async {
      await otevri(tester);
      expect(find.text('Přiložit do PDF fotky počítadla'), findsOneWidget);

      await tester.tap(find.text('PDF'));
      await tester.pump();
      expect(find.text('Přiložit do PDF fotky počítadla'), findsNothing);
    });

    testWidgets('bez nových se rovnou volí vlastní období', (tester) async {
      await otevri(tester, historie: [_relace('a', DateTime(2026, 10, 21))]);

      expect(find.textContaining('Jen nové'), findsNothing);
      expect(find.text('Tento měsíc'), findsOneWidget);
    });

    testWidgets('vlastní období nabídne zkratky', (tester) async {
      await otevri(tester);
      expect(find.text('Minulý měsíc'), findsNothing);

      await tester.tap(find.text('Vlastní období'));
      await tester.pump();
      expect(find.text('Minulý měsíc'), findsOneWidget);
      expect(find.text('Zvolit od – do'), findsOneWidget);
    });

    testWidgets('historie ukazuje období, počet a formáty', (tester) async {
      await otevri(
        tester,
        exporty: [
          report,
          _report(
            DateTime(2026, 8),
            DateTime(2026, 9, 12),
            DateTime(2026, 9, 13),
            pocet: 9,
          ),
        ],
      );

      expect(find.text('13. 9. – 28. 10. 2026'), findsOneWidget);
      expect(find.text('2. 11. · 12 nabíjení · PDF + Excel'), findsOneWidget);
      // Starší report formát uložený nemá, tak se o něm nic netvrdí.
      expect(find.text('13. 9. · 9 nabíjení'), findsOneWidget);
    });

    // Report starší, než kolik se načítá historie: částku neznáme.
    testWidgets('neznámou částku reportu netvrdí jako nulu', (tester) async {
      await otevri(tester);

      expect(find.textContaining('0,00 Kč'), findsNothing);
    });
  });
}
