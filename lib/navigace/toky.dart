import 'package:flutter/material.dart';

import '../features/nabijeni/domain/relace.dart';
import '../features/nabijeni/presentation/detail_relace_obrazovka.dart';
import '../features/nabijeni/presentation/foceni_obrazovka.dart';
import '../features/nabijeni/presentation/rekapitulace_obrazovka.dart';
import '../features/nabijeni/presentation/zahajeni_obrazovka.dart';
import '../features/reporty/presentation/export_obrazovka.dart';

/// Otevírání toků nad hlavním rámcem. Navigace je vnořená hierarchie
/// obrazovek, ne router s vlastní historií – tyhle funkce jsou jediné
/// místo, kde se skládá dohromady.

void otevriZahajeni(BuildContext context) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const ZahajeniObrazovka()));
}

/// Ukončení běžící relace: nejdřív fotka počítadla, pak rekapitulace.
/// Do Firestore se zapisuje až na rekapitulaci tlačítkem „Dokončit“.
Future<void> otevriUkonceni(BuildContext context, Relace relace) =>
    otevriUkonceniPres(Navigator.of(context), relace);

Future<void> otevriUkonceniPres(NavigatorState nav, Relace relace) async {
  final vysledek = await nav.push<VysledekFoceni>(
    MaterialPageRoute(
      builder: (_) => FoceniObrazovka(
        rezim: RezimFoceni.ukonceni,
        kwhStart: relace.kwhStart,
      ),
      fullscreenDialog: true,
    ),
  );
  if (vysledek == null || !nav.mounted) return;

  await nav.push(
    MaterialPageRoute(
      builder: (_) => RekapitulaceObrazovka(
        relace: relace,
        kwhEnd: vysledek.hodnota,
        fotoEnd: vysledek.foto,
      ),
    ),
  );
}

void otevriExport(BuildContext context) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const ExportObrazovka()));
}

void otevriDetail(BuildContext context, String relaceId) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => DetailRelaceObrazovka(relaceId: relaceId),
    ),
  );
}
