import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:renocharge/common/motiv/motiv.dart';
import 'package:renocharge/features/nabijeni/application/foto_sluzba.dart';
import 'package:renocharge/features/nabijeni/application/ocr_sluzba.dart';
import 'package:renocharge/features/nabijeni/domain/porizena_fotografie.dart';
import 'package:renocharge/features/nabijeni/presentation/foceni_obrazovka.dart';

/// Průhledný PNG 1 × 1 px – obrazovka potřebuje jen platné bajty.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class _Foto implements FotoSluzba {
  @override
  Future<PorizenaFotografie> nactiPocitadlo(ZdrojFoto zdroj) async =>
      PorizenaFotografie(
        cestaVSouborovemSystemu: 'x.jpg',
        bajty: _png,
        sha256: 'x' * 64,
        porizenoAt: DateTime(2026, 11, 2),
        casZExif: true,
        zdroj: zdroj,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Ocr implements OcrSluzba {
  _Ocr(this.hodnota);

  final double? hodnota;

  @override
  Future<double?> najdiHodnotu(String cestaKSouboru) async => hodnota;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Telefon 360 × 780 s klávesnicí vysokou 300 bodů, typický Android.
const _vyskaKlavesnice = 300.0;

Future<void> _otevriSVysledkem(WidgetTester tester, {double? ocr}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  // Telefon bez kamery: obrazovka spadne na systémový fotoaparát, tedy na
  // [_Foto]. Bez odpovědi by plugin čekal na neexistující nativní stranu.
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/camera'),
    (_) async => const <Object?>[],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        fotoSluzbaProvider.overrideWithValue(_Foto()),
        ocrSluzbaProvider.overrideWithValue(_Ocr(ocr)),
      ],
      child: MaterialApp(
        theme: Motiv.tmavy(),
        home: const FoceniObrazovka(rezim: RezimFoceni.ukonceni, kwhStart: 100),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _otevriKlavesnici(WidgetTester tester) async {
  await tester.tap(find.byType(TextField));
  await tester.pump();
  tester.view.viewInsets = const FakeViewPadding(bottom: _vyskaKlavesnice * 3);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // Regrese: obrazovka se o klávesnici zmenšila a panel si ji přidal ještě
  // jednou jako odsazení. Na fotku nezbylo místo a stav se z ní nedal opsat.
  testWidgets('fotka zůstane vidět i s otevřenou klávesnicí', (tester) async {
    await _otevriSVysledkem(tester, ocr: 12345.6);
    await _otevriKlavesnici(tester);

    expect(tester.takeException(), isNull, reason: 'přetečení rozvržení');
    final fotka = tester.getRect(find.byType(InteractiveViewer));
    expect(
      fotka.height,
      greaterThan(200),
      reason: 'z fotky se musí dát číst, ne jen proužek',
    );

    // Pole i potvrzení musí být nad klávesnicí, jinak se nedá dopsat.
    final hranaKlavesnice = 780 - _vyskaKlavesnice;
    expect(
      tester.getRect(find.byType(TextField)).bottom,
      lessThanOrEqualTo(hranaKlavesnice),
    );
    expect(
      tester.getRect(find.text('Potvrdit stav')).bottom,
      lessThanOrEqualTo(hranaKlavesnice),
    );
  });

  testWidgets('přečtená hodnota se při psaní nezahodí', (tester) async {
    await _otevriSVysledkem(tester, ocr: 12345.6);
    await _otevriKlavesnici(tester);

    // Pole se při otevření klávesnice přesune do menšího panelu. Kdyby se
    // přitom vytvořilo znovu, ztratilo by fokus a klávesnice by zase zajela.
    final pole = find.byType(EditableText);
    expect(tester.widget<EditableText>(pole).focusNode.hasFocus, isTrue);

    await tester.enterText(find.byType(TextField), '12999,5');
    await tester.pump();
    expect(find.text('12999,5'), findsOneWidget);
  });

  testWidgets('bez klávesnice je nabídka celá', (tester) async {
    await _otevriSVysledkem(tester, ocr: 12345.6);

    expect(find.text('Vyfotit znovu'), findsOneWidget);
    expect(find.text('Vybrat jinou z galerie'), findsOneWidget);
  });

  testWidgets('s klávesnicí ustoupí vedlejší akce fotce', (tester) async {
    await _otevriSVysledkem(tester, ocr: 12345.6);
    await _otevriKlavesnici(tester);

    expect(find.text('Vyfotit znovu'), findsNothing);
    expect(find.text('Vybrat jinou z galerie'), findsNothing);
  });

  testWidgets('ruční zadání po nepřečteném čísle nechá fotku vidět', (
    tester,
  ) async {
    await _otevriSVysledkem(tester);

    await tester.ensureVisible(find.text('Zadat hodnotu ručně'));
    await tester.tap(find.text('Zadat hodnotu ručně'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(
      bottom: _vyskaKlavesnice * 3,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.byType(InteractiveViewer)).height,
      greaterThan(200),
    );
    expect(find.text('Potvrdit ručně'), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
  });

  // Celý displej, ne oříznutý výřez, a přiblížení prsty: stav se opisuje
  // z malé části snímku.
  testWidgets('fotka se ukazuje celá a jde přiblížit', (tester) async {
    await _otevriSVysledkem(tester, ocr: 12345.6);

    final obrazek = tester.widget<Image>(
      find.descendant(
        of: find.byType(InteractiveViewer),
        matching: find.byType(Image),
      ),
    );
    expect(obrazek.fit, BoxFit.contain);
    expect(
      tester.widget<InteractiveViewer>(find.byType(InteractiveViewer)).maxScale,
      greaterThan(1),
    );
  });

  testWidgets('klepnutí na fotku klávesnici schová', (tester) async {
    await _otevriSVysledkem(tester, ocr: 12345.6);
    await _otevriKlavesnici(tester);

    // Číselná klávesnice na iPhonu nemá tlačítko „hotovo".
    await tester.tap(find.byType(InteractiveViewer));
    await tester.pumpAndSettle();

    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isFalse,
    );
  });
}
