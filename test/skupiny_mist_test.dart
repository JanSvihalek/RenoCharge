import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:renocharge/common/motiv/motiv.dart';
import 'package:renocharge/features/elektromery/application/elektromery_providery.dart';
import 'package:renocharge/features/elektromery/domain/druh_mista.dart';
import 'package:renocharge/features/elektromery/domain/elektromer.dart';
import 'package:renocharge/features/elektromery/domain/odecet.dart';
import 'package:renocharge/features/elektromery/presentation/elektromery_obrazovka.dart';

final _ted = DateTime.now();

Elektromer _misto(
  String nazev,
  DruhMista druh, {
  bool odecteno = false,
  bool aktivni = true,
}) => Elektromer(
  id: '${druh.klic}-$nazev',
  pobockaKod: 'BSL',
  cislo: '',
  nazev: nazev,
  druh: druh,
  aktivni: aktivni,
  posledniOdecet: odecteno
      ? PosledniOdecet(hodnota: 100, odectenoAt: _ted, odecetId: 'o')
      : null,
);

final _mista = [
  _misto('Servis', DruhMista.elektrina, odecteno: true),
  _misto('Myčka', DruhMista.elektrina),
  _misto('Kotelna', DruhMista.plyn, odecteno: true),
  _misto('Stará hala', DruhMista.plyn, odecteno: true),
  _misto('Přípr. Stání 1', DruhMista.lakovna),
  _misto('Stará', DruhMista.voda, aktivni: false),
];

Future<ProviderContainer> _otevri(
  WidgetTester tester, {
  List<Elektromer>? mista,
}) async {
  tester.view.physicalSize = const Size(1200, 3600);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final kontejner = ProviderContainer(
    overrides: [
      elektromeryProvider.overrideWith((ref) => Stream.value(mista ?? _mista)),
      chybejiciVychoziProvider.overrideWithValue(const []),
    ],
  );
  addTearDown(kontejner.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: kontejner,
      child: MaterialApp(
        theme: Motiv.tmavy(),
        home: const Scaffold(body: ElektromeryObrazovka()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return kontejner;
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('cs_CZ');
  });

  testWidgets('ve výchozím stavu jsou vidět jen skupiny s průběhem', (
    tester,
  ) async {
    await _otevri(tester);

    expect(find.text('odečteno 1 z 2'), findsOneWidget, reason: 'elektřina');
    expect(find.text('odečteno 2 z 2'), findsOneWidget, reason: 'plyn');
    expect(find.text('odečteno 0 z 1'), findsOneWidget, reason: 'lakovna');
    expect(find.text('Vyřazené'), findsOneWidget);
    expect(find.text('Servis'), findsNothing);
    expect(find.text('Kotelna'), findsNothing);
  });

  testWidgets('klepnutí skupinu rozbalí a znovu sbalí', (tester) async {
    await _otevri(tester);

    await tester.tap(find.text('Plyn').last);
    await tester.pump();
    expect(find.text('Kotelna'), findsOneWidget);
    expect(find.text('Servis'), findsNothing, reason: 'jiná skupina zůstává');

    await tester.tap(find.text('Plyn').last);
    await tester.pump();
    expect(find.text('Kotelna'), findsNothing);
  });

  testWidgets('prázdný druh skupinu nemá', (tester) async {
    await _otevri(tester);

    // Nabíječky na téhle pobočce nejsou, v seznamu druhů ano.
    expect(find.text('Nabíječky'), findsNothing);
  });

  testWidgets('hledání ukáže výsledek i ve sbalené skupině', (tester) async {
    await _otevri(tester);

    await tester.enterText(find.byType(TextField), 'kotel');
    await tester.pump();

    expect(find.text('Kotelna'), findsOneWidget);
    expect(find.text('Servis'), findsNothing);
    // Skupina bez výsledku se neukazuje.
    expect(find.text('odečteno 1 z 2'), findsNothing);
    expect(
      find.byIcon(Icons.expand_less),
      findsNothing,
      reason: 'nejde sbalit',
    );
  });

  testWidgets('se zvoleným druhem jde rovnou seznam', (tester) async {
    final kontejner = await _otevri(tester);

    kontejner.read(vybranyDruhProvider.notifier).vyber(DruhMista.plyn);
    await tester.pump();

    expect(find.text('Kotelna'), findsOneWidget);
    expect(find.text('Stará hala'), findsOneWidget);
    expect(find.text('odečteno 2 z 2'), findsNothing);
  });

  testWidgets('jen neodečtené schová hotové druhy, sbalení nechá', (
    tester,
  ) async {
    final kontejner = await _otevri(tester);

    kontejner.read(jenNeodecteneProvider.notifier).prepni();
    await tester.pump();

    expect(find.text('odečteno 2 z 2'), findsNothing, reason: 'plyn je hotový');
    // Průběh se pořád počítá za celý druh, ne za to, co je vidět.
    expect(find.text('odečteno 1 z 2'), findsOneWidget);
    expect(find.text('Servis'), findsNothing);

    await tester.tap(find.text('odečteno 1 z 2'));
    await tester.pump();
    expect(find.text('Myčka'), findsOneWidget);
    expect(find.text('Servis'), findsNothing, reason: 'už odečtené');
  });

  testWidgets('rozbalení se drží mimo obrazovku, přežije návrat z detailu', (
    tester,
  ) async {
    final kontejner = await _otevri(tester);

    await tester.tap(find.text('Plyn').last);
    await tester.pump();
    expect(kontejner.read(rozbaleneSkupinyProvider), {DruhMista.plyn.klic});
  });

  testWidgets('bez jediného odečtu ukazuje skupina počet míst', (tester) async {
    await _otevri(
      tester,
      mista: [_misto('A', DruhMista.plyn), _misto('B', DruhMista.plyn)],
    );

    expect(find.text('2 místa'), findsOneWidget);
  });

  testWidgets('vyřazená místa jsou ve vlastní sbalené skupině', (tester) async {
    await _otevri(tester);

    expect(find.text('Stará'), findsNothing);
    await tester.tap(find.text('Vyřazené'));
    await tester.pump();
    expect(find.text('Stará'), findsOneWidget);
  });
}
