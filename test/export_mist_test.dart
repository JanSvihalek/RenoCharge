import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renocharge/common/motiv/motiv.dart';
import 'package:renocharge/features/auth/application/auth_providery.dart';
import 'package:renocharge/features/elektromery/application/odecty_controller.dart';
import 'package:renocharge/features/elektromery/data/odecty_repository.dart';
import 'package:renocharge/features/elektromery/domain/druh_mista.dart';
import 'package:renocharge/features/elektromery/domain/elektromer.dart';
import 'package:renocharge/features/elektromery/domain/odecet.dart';
import 'package:renocharge/features/elektromery/domain/pobocka.dart';
import 'package:renocharge/features/reporty/application/exporty_providery.dart';
import 'package:renocharge/features/reporty/application/report_controller.dart';
import 'package:renocharge/features/reporty/application/report_pdf.dart';
import 'package:renocharge/features/reporty/application/report_xlsx.dart';
import 'package:renocharge/features/reporty/data/exporty_repository.dart';
import 'package:renocharge/features/reporty/domain/report.dart';
import 'package:renocharge/features/reporty/domain/zaznam_exportu.dart';
import 'package:renocharge/features/reporty/presentation/export_mist_panel.dart';

Odecet _odecet(String mistoId, DateTime kdy, double hodnota) => Odecet(
  id: '$mistoId-${kdy.millisecondsSinceEpoch}',
  elektromerId: mistoId,
  pobockaKod: 'BSL',
  uid: 'u1',
  hodnota: hodnota,
  odectenoAt: kdy,
);

Elektromer _misto(
  String id, {
  DateTime? posledni,
  bool aktivni = true,
  DruhMista druh = DruhMista.plyn,
}) => Elektromer(
  id: id,
  pobockaKod: 'BSL',
  cislo: '',
  nazev: 'Místo $id',
  druh: druh,
  aktivni: aktivni,
  posledniOdecet: posledni == null
      ? null
      : PosledniOdecet(hodnota: 100, odectenoAt: posledni, odecetId: 'o'),
);

ZaznamExportu _report(
  DateTime od,
  DateTime doVcetne,
  DateTime vytvoreno, {
  DruhMista? druh,
  String? elektromerId,
  int pocet = 3,
}) => ZaznamExportu(
  id: 'e${vytvoreno.millisecondsSinceEpoch}',
  uid: 'u1',
  obdobi: Obdobi(od: od, doVcetne: doVcetne),
  pocetZaznamu: pocet,
  sFotkami: false,
  vytvorenoAt: vytvoreno,
  formaty: const {FormatExportu.pdf, FormatExportu.xlsx},
  pobockaKod: 'BSL',
  druh: druh,
  elektromerId: elektromerId,
);

class _Odecty implements OdectyRepository {
  @override
  Future<List<Odecet>> nactiPobockuZaObdobi({
    required String pobockaKod,
    required DateTime od,
    required DateTime doKonce,
  }) async => [_odecet('p', DateTime(2026, 10, 4), 112.5)];

  @override
  Future<List<Odecet>> nactiPred({
    required String elektromerId,
    required DateTime pred,
    int pocet = 2,
  }) async => [_odecet(elektromerId, DateTime(2026, 9, 2), 100)];

  @override
  Future<List<Odecet>> nactiZaObdobi({
    required String elektromerId,
    required DateTime od,
    required DateTime doKonce,
  }) async => [
    _odecet(elektromerId, DateTime(2026, 9, 2), 100),
    _odecet(elektromerId, DateTime(2026, 10, 4), 112.5),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Stopa {
  const _Stopa(this.formaty, this.pobockaKod, this.druh, this.elektromerId);

  final Set<FormatExportu> formaty;
  final String? pobockaKod;
  final DruhMista? druh;
  final String? elektromerId;
}

class _Exporty implements ExportyRepository {
  final zapsane = <_Stopa>[];

  @override
  Future<void> zapis({
    required String uid,
    required Obdobi obdobi,
    required int pocetZaznamu,
    required bool sFotkami,
    required Set<FormatExportu> formaty,
    String? pobockaKod,
    DruhMista? druh,
    String? elektromerId,
  }) async => zapsane.add(_Stopa(formaty, pobockaKod, druh, elektromerId));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('cs_CZ');
  });

  final report = _report(
    DateTime(2026, 9),
    DateTime(2026, 9, 30),
    DateTime(2026, 10, 1, 9),
  );

  group('co je nové u odběrných míst', () {
    test('report zahrnuje jen to, co vzniklo před ním', () {
      expect(report.zahrnujeCas(DateTime(2026, 9, 15)), isTrue);
      expect(report.zahrnujeCas(DateTime(2026, 10, 1, 8)), isFalse);
    });

    // Odpoledne po reportu v týž den: datum v období, ale v reportu není.
    test('odečet v poslední den období po vytvoření reportu je nový', () {
      final dnesni = _report(
        DateTime(2026, 9),
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 1, 9),
      );
      expect(dnesni.zahrnujeCas(DateTime(2026, 10, 1, 14)), isFalse);
      expect(dnesni.zahrnujeCas(DateTime(2026, 10, 1, 8)), isTrue);
    });

    test('report odběrných míst neoznačí nabíjení', () {
      expect(report.jeNabijeni, isFalse);
    });

    test('nabídka míst počítá místa s odečtem v období', () {
      final nabidka = NabidkaOdectu.zMist(
        [
          _misto('a', posledni: DateTime(2026, 10, 4)),
          _misto('b', posledni: DateTime(2026, 10, 5)),
          _misto('c', posledni: DateTime(2026, 9, 2)),
          _misto('d'),
        ],
        [report],
        ted: DateTime(2026, 10, 6),
      )!;
      expect(nabidka.obdobi.od, DateTime(2026, 10));
      expect(nabidka.obdobi.doVcetne, DateTime(2026, 10, 6));
      expect(nabidka.pocet, 2);
      expect(nabidka.spotreba, isNull, reason: 'kWh a m³ se nesčítají');
    });

    test('vyřazené místo novinku nedělá', () {
      expect(
        NabidkaOdectu.zMist(
          [_misto('a', posledni: DateTime(2026, 10, 4), aktivni: false)],
          [report],
        ),
        isNull,
      );
    });

    test('když je všechno v reportu, není co nabízet', () {
      expect(
        NabidkaOdectu.zMist(
          [_misto('a', posledni: DateTime(2026, 9, 4))],
          [report],
        ),
        isNull,
      );
    });

    test('nabídka jednoho místa sečte spotřebu', () {
      final nabidka = NabidkaOdectu.zOdectu(
        [
          OdecetSeSpotrebou(
            odecet: _odecet('a', DateTime(2026, 10, 4), 112.5),
            spotreba: 12.5,
          ),
          OdecetSeSpotrebou(odecet: _odecet('a', DateTime(2026, 9, 2), 100)),
        ],
        [report],
        ted: DateTime(2026, 10, 6),
      )!;
      expect(nabidka.pocet, 1);
      expect(nabidka.spotreba, 12.5);
    });
  });

  group('soubory', () {
    final podkladStavu = PodkladStavu(
      pobocka: Pobocka.bsl,
      druh: null,
      obdobi: Obdobi(od: DateTime(2026, 10), doVcetne: DateTime(2026, 10, 31)),
      radky: slozPrehledStavu(
        mista: [
          _misto('p'),
          _misto('e', druh: DruhMista.elektrina),
          _misto('b', druh: DruhMista.voda),
        ],
        predObdobim: {
          'p': [_odecet('p', DateTime(2026, 9, 2), 100)],
        },
        vObdobi: {
          'p': [_odecet('p', DateTime(2026, 10, 4), 112.5)],
        },
      ),
      vytvorenoAt: DateTime(2026, 11, 1),
    );

    test('PDF stavů je platný dokument na šířku', () async {
      final bajty = await (await ReportPdf.nacti()).sestavStavy(podkladStavu);
      expect(String.fromCharCodes(bajty.sublist(0, 5)), '%PDF-');
      expect(bajty.length, greaterThan(1000));
    });

    test('PDF stavů bez řádků nespadne', () async {
      final bajty = await (await ReportPdf.nacti()).sestavStavy(
        PodkladStavu(
          pobocka: Pobocka.bsl,
          druh: DruhMista.plyn,
          obdobi: podkladStavu.obdobi,
          radky: const [],
          vytvorenoAt: DateTime(2026, 11, 1),
        ),
      );
      expect(String.fromCharCodes(bajty.sublist(0, 5)), '%PDF-');
    });

    PodkladElektromeru odecty(List<PolozkaOdectu> polozky) =>
        PodkladElektromeru(
          elektromer: _misto('p'),
          obdobi: Obdobi(
            od: DateTime(2026, 9),
            doVcetne: DateTime(2026, 10, 31),
          ),
          polozky: polozky,
          vytvorenoAt: DateTime(2026, 11, 1),
        );

    String listOdectu(PodkladElektromeru podklad) => utf8.decode(
      ZipDecoder()
          .decodeBytes(ReportXlsx.sestavOdecty(podklad))
          .files
          .firstWhere((f) => f.name == 'xl/worksheets/sheet1.xml')
          .readBytes()!,
    );

    test('Excel odečtů nese jednotku a součet', () {
      final list = listOdectu(
        odecty(
          slozPolozkyOdectu([
            _odecet('p', DateTime(2026, 9, 2), 100),
            _odecet('p', DateTime(2026, 10, 4), 112.5),
          ]),
        ),
      );

      expect(list, contains('Stav (m³)'));
      expect(list, contains('Spotřeba (m³)'));
      expect(list, contains('<v>112.5</v>'));
      expect(list, contains('<f>SUM(C2:C3)</f>'));
      expect(list, contains('<v>12.5</v>'));
    });

    test('Excel odečtů bez řádků nespadne', () {
      expect(listOdectu(odecty(const [])), contains('Celkem'));
    });
  });

  group('vytvoření a sdílení', () {
    late Directory slozka;
    late _Exporty exporty;
    late ProviderContainer kontejner;
    late List<Map<Object?, Object?>> sdileni;

    final obdobi = Obdobi(
      od: DateTime(2026, 10),
      doVcetne: DateTime(2026, 10, 31),
    );

    setUp(() async {
      slozka = await Directory.systemTemp.createTemp('renocharge_test');
      sdileni = [];
      exporty = _Exporty();
      final kanaly =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      kanaly.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => slozka.path,
      );
      kanaly.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/share'),
        (volani) async {
          sdileni.add(volani.arguments as Map<Object?, Object?>);
          return 'dev.fluttercommunity.plus/share/success';
        },
      );
      kontejner = ProviderContainer(
        overrides: [
          uidProvider.overrideWithValue('u1'),
          odectyRepositoryProvider.overrideWithValue(_Odecty()),
          exportyRepositoryProvider.overrideWithValue(exporty),
        ],
      );
      addTearDown(kontejner.dispose);
    });

    tearDown(() => slozka.delete(recursive: true));

    ReportController rizeni() =>
        kontejner.read(reportControllerProvider.notifier);

    List<String> pripony() => [
      for (final c in sdileni.single['paths'] as List<Object?>)
        (c as String).split('.').last,
    ];

    test('stavy: oba formáty jedním sdílením a stopa s výřezem', () async {
      final pocet = await rizeni().vytvorStavy(
        pobocka: Pobocka.bsl,
        druh: DruhMista.plyn,
        mista: [_misto('p')],
        obdobi: obdobi,
        formaty: {FormatExportu.pdf, FormatExportu.xlsx},
      );

      expect(pocet, 1);
      expect(pripony(), ['pdf', 'xlsx']);
      final stopa = exporty.zapsane.single;
      expect(stopa.pobockaKod, 'BSL');
      expect(stopa.druh, DruhMista.plyn);
      expect(stopa.elektromerId, isNull);
    });

    test('jedno místo: Excel bez PDF a stopa s místem', () async {
      final pocet = await rizeni().vytvorProElektromer(
        elektromer: _misto('p'),
        obdobi: obdobi,
        formaty: {FormatExportu.xlsx},
      );

      expect(pocet, 2);
      expect(pripony(), ['xlsx']);
      final stopa = exporty.zapsane.single;
      expect(stopa.elektromerId, 'p');
      expect(stopa.pobockaKod, 'BSL');
    });

    test('opakované sdílení stopu nezakládá', () async {
      await rizeni().vytvorStavy(
        pobocka: Pobocka.bsl,
        druh: null,
        mista: [_misto('p')],
        obdobi: obdobi,
        formaty: {FormatExportu.pdf},
        zapsatStopu: false,
      );
      await kontejner
          .read(reportControllerProvider.notifier)
          .vytvorProElektromer(
            elektromer: _misto('p'),
            obdobi: obdobi,
            formaty: {FormatExportu.xlsx},
            zapsatStopu: false,
          );

      expect(sdileni, hasLength(2));
      expect(exporty.zapsane, isEmpty);
    });
  });

  group('panely', () {
    Widget aplikace(Widget panel, List<ZaznamExportu> exporty) => ProviderScope(
      overrides: [
        exportyMistProvider.overrideWith((ref) => Stream.value(exporty)),
        historieOdectuProvider('p').overrideWith(
          (ref) => Stream.value([
            OdecetSeSpotrebou(
              odecet: _odecet('p', DateTime(2026, 10, 4), 112.5),
              spotreba: 12.5,
            ),
          ]),
        ),
      ],
      child: MaterialApp(
        theme: Motiv.tmavy(),
        home: Scaffold(body: panel),
      ),
    );

    void telefon(WidgetTester tester) {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    testWidgets('stavy nabídnou nové a nenabízí fotky', (tester) async {
      telefon(tester);
      await tester.pumpWidget(
        aplikace(
          ExportStavuPanel(
            pobocka: Pobocka.bsl,
            druh: null,
            mista: [
              _misto('a', posledni: DateTime(2026, 10, 4)),
              _misto('b', posledni: DateTime(2026, 10, 5)),
            ],
          ),
          [report],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Export stavů'), findsOneWidget);
      expect(find.text('BSL – Brno-Slatina · 2 místa'), findsOneWidget);
      expect(find.text('Jen nové od 1. 10.'), findsOneWidget);
      expect(find.text('2 místa s odečtem'), findsOneWidget);
      expect(find.text('Vytvořit PDF + Excel'), findsOneWidget);
      expect(find.textContaining('fotky'), findsNothing);
      expect(
        find.text('1. 10. · 3 místa s odečtem · PDF + Excel'),
        findsOneWidget,
      );
    });

    // Report za elektřinu neříká nic o plynu. Kdyby se počítal, plyn by se
    // tvářil jako hotový, a nikdo by ho nevyexportoval.
    testWidgets('report jiného druhu novinku neschová', (tester) async {
      telefon(tester);
      await tester.pumpWidget(
        aplikace(
          ExportStavuPanel(
            pobocka: Pobocka.bsl,
            druh: DruhMista.plyn,
            mista: [_misto('a', posledni: DateTime(2026, 10, 4))],
          ),
          [
            _report(
              DateTime(2026, 10),
              DateTime(2026, 10, 31),
              DateTime(2026, 11, 1),
              druh: DruhMista.elektrina,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Jen nové'), findsOneWidget);
      expect(find.byIcon(Icons.ios_share), findsNothing, reason: 'cizí report');
    });

    testWidgets('jedno místo ukáže odečty a spotřebu', (tester) async {
      telefon(tester);
      await tester.pumpWidget(
        aplikace(ExportOdectuPanel(elektromer: _misto('p')), [
          _report(
            DateTime(2026, 9),
            DateTime(2026, 9, 30),
            DateTime(2026, 10, 1, 9),
            elektromerId: 'p',
            pocet: 2,
          ),
          // Report jiného místa se tu nesmí ukázat.
          _report(
            DateTime(2026, 10),
            DateTime(2026, 10, 31),
            DateTime(2026, 11, 1),
            elektromerId: 'jine',
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Export odečtů'), findsOneWidget);
      expect(find.text('Plyn · Místo p'), findsOneWidget);
      expect(find.text('1 odečet · +12,50 m³'), findsOneWidget);
      expect(find.text('1. 10. · 2 odečty · PDF + Excel'), findsOneWidget);
      expect(find.textContaining('1. 11. ·'), findsNothing);
    });
  });
}
