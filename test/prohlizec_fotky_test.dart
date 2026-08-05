import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renocharge/features/nabijeni/application/nabijeni_providery.dart';
import 'package:renocharge/features/nabijeni/presentation/prohlizec_fotky.dart';

const _cesta = 'nabijeni/u1/r1/start.jpg';

Widget _prohlizec() => ProviderScope(
  overrides: [
    // Skutečné stažení ze Storage v testu neproběhne; stačí, že provider
    // vrátí odkaz a rozvržení se má podle čeho poskládat.
    odkazNaFotkuProvider(
      _cesta,
    ).overrideWith((ref) => 'https://priklad.invalid/fotka.jpg'),
  ],
  child: const MaterialApp(
    home: ProhlizecFotky(cesta: _cesta, popisek: 'Před nabíjením'),
  ),
);

void main() {
  // Regrese: Stack se ve výchozím nastavení roztáhne jen podle
  // nepozicovaných dětí. Když byla nepozicovaná jen horní lišta, dostala
  // fotka jejích šedesát bodů a zobrazila se jako proužek nahoře.
  testWidgets('fotka dostane celou plochu obrazovky', (tester) async {
    await tester.pumpWidget(_prohlizec());
    await tester.pump();

    final plocha = tester.getSize(find.byType(InteractiveViewer));
    final obrazovka = tester.getSize(find.byType(Scaffold));

    expect(plocha.height, obrazovka.height);
    expect(plocha.width, obrazovka.width);
  });

  testWidgets('zavírací tlačítko zůstává nahoře', (tester) async {
    await tester.pumpWidget(_prohlizec());
    await tester.pump();

    final tlacitko = tester.getRect(find.byIcon(Icons.close));
    final obrazovka = tester.getSize(find.byType(Scaffold));

    expect(
      tlacitko.center.dy,
      lessThan(obrazovka.height / 4),
      reason: 's roztaženým Stackem hrozí vycentrování doprostřed',
    );
  });

  testWidgets('popisek fotky je vidět', (tester) async {
    await tester.pumpWidget(_prohlizec());
    await tester.pump();

    expect(find.text('Před nabíjením'), findsOneWidget);
  });
}
