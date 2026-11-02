import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renocharge/features/auth/application/auth_providery.dart';
import 'package:renocharge/features/auth/domain/uzivatel.dart';
import 'package:renocharge/features/nabijeni/application/nabijeni_providery.dart';
import 'package:renocharge/features/nabijeni/data/nabijeni_repository.dart';
import 'package:renocharge/features/nabijeni/domain/relace.dart';
import 'package:renocharge/features/reporty/application/exporty_providery.dart';
import 'package:renocharge/features/reporty/application/report_controller.dart';
import 'package:renocharge/features/reporty/data/exporty_repository.dart';
import 'package:renocharge/features/reporty/domain/report.dart';
import 'package:renocharge/features/reporty/domain/zaznam_exportu.dart';
import 'package:renocharge/features/vozidla/application/vozidla_providery.dart';

class _Nabijeni implements NabijeniRepository {
  @override
  Future<List<Relace>> nactiZaObdobi({
    required String uid,
    required DateTime od,
    required DateTime doKonce,
  }) async => [
    Relace(
      id: 'r1',
      uid: uid,
      spz: 'EL238FV',
      vozidloId: 'v1',
      zahajeno: DateTime(2026, 11, 2, 10),
      ukonceno: DateTime(2026, 11, 2, 15),
      kwhNabito: 38.74,
      stav: StavRelace.dokonceno,
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Exporty implements ExportyRepository {
  final zapsane = <Set<FormatExportu>>[];

  @override
  Future<void> zapis({
    required String uid,
    required Obdobi obdobi,
    required int pocetZaznamu,
    required bool sFotkami,
    required Set<FormatExportu> formaty,
  }) async => zapsane.add(formaty);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory slozka;
  late _Exporty exporty;
  late ProviderContainer kontejner;
  late List<Map<Object?, Object?>> sdileni;

  final obdobi = Obdobi(
    od: DateTime(2026, 10, 29),
    doVcetne: DateTime(2026, 11, 2),
  );

  setUp(() async {
    await initializeDateFormatting('cs_CZ');
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
        profilProvider.overrideWith(
          (ref) => Stream.value(
            const Uzivatel(uid: 'u1', jmeno: 'Jan Švihálek', email: 'j@p.cz'),
          ),
        ),
        vozidlaProvider.overrideWith((ref) => Stream.value(const [])),
        nabijeniRepositoryProvider.overrideWithValue(_Nabijeni()),
        exportyRepositoryProvider.overrideWithValue(exporty),
      ],
    );
    addTearDown(kontejner.dispose);
    // Provider, který nikdo nesleduje, Riverpod pozastaví. V aplikaci profil
    // sleduje domovská obrazovka.
    kontejner.listen(profilProvider, (_, _) {});
    await kontejner.read(profilProvider.future);
  });

  tearDown(() => slozka.delete(recursive: true));

  ReportController rizeni() =>
      kontejner.read(reportControllerProvider.notifier);

  List<String> cesty() => [
    for (final c in sdileni.single['paths'] as List<Object?>) c as String,
  ];

  /// Soubory se poznají podle začátku, přípona by nic nedokázala.
  String podpis(String cesta) =>
      String.fromCharCodes(File(cesta).readAsBytesSync().take(2));

  test('oba formáty se nasdílí jedním sdílením', () async {
    final pocet = await rizeni().vytvorNabijeni(
      obdobi: obdobi,
      formaty: {FormatExportu.pdf, FormatExportu.xlsx},
      sFotkami: false,
    );

    expect(pocet, 1);
    expect(sdileni, hasLength(1), reason: 'do jednoho mailu');
    final soubory = cesty();
    expect(soubory, hasLength(2));
    expect(soubory.first, endsWith('.pdf'));
    expect(podpis(soubory.first), '%P');
    expect(soubory.last, endsWith('.xlsx'));
    expect(podpis(soubory.last), 'PK', reason: 'xlsx je ZIP');
    expect(exporty.zapsane.single, {FormatExportu.pdf, FormatExportu.xlsx});
  });

  test('jen PDF vytvoří jen PDF', () async {
    await rizeni().vytvorNabijeni(
      obdobi: obdobi,
      formaty: {FormatExportu.pdf},
      sFotkami: false,
    );

    expect(cesty().single, endsWith('.pdf'));
    expect(exporty.zapsane.single, {FormatExportu.pdf});
  });

  test('jen Excel vytvoří jen Excel', () async {
    await rizeni().vytvorNabijeni(
      obdobi: obdobi,
      formaty: {FormatExportu.xlsx},
      sFotkami: false,
    );

    expect(cesty().single, endsWith('.xlsx'));
    expect(exporty.zapsane.single, {FormatExportu.xlsx});
  });

  ZaznamExportu report(Set<FormatExportu> formaty) => ZaznamExportu(
    id: 'x',
    uid: 'u1',
    obdobi: obdobi,
    pocetZaznamu: 1,
    sFotkami: false,
    vytvorenoAt: DateTime(2026, 11, 2, 16),
    formaty: formaty,
  );

  // Tentýž report nesmí být v historii dvakrát.
  test('opakované sdílení nezakládá nový report', () async {
    await rizeni().sdilejZnovu(report({FormatExportu.xlsx}));

    expect(cesty().single, endsWith('.xlsx'));
    expect(exporty.zapsane, isEmpty);
  });

  test(
    'starý report bez uloženého formátu se znovu vytvoří jako PDF',
    () async {
      await rizeni().sdilejZnovu(report(const {}));

      expect(cesty().single, endsWith('.pdf'));
    },
  );
}
