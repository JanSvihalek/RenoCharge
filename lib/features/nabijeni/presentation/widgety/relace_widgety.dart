import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/formatovani.dart';
import '../../../../common/motiv/barvy.dart';
import '../../../../common/motiv/rozmery.dart';
import '../../../../common/widgety/prvky.dart';
import '../../../vozidla/application/vozidla_providery.dart';
import '../../application/nabijeni_providery.dart';
import '../../domain/relace.dart';

/// Odznak stavu relace ve třech variantách podle návrhu.
class OdznakStavu extends StatelessWidget {
  const OdznakStavu(this.stav, {super.key});

  final StavRelace stav;

  @override
  Widget build(BuildContext context) {
    final b = context.barvy;
    final (pozadi, popredi) = switch (stav) {
      StavRelace.probiha => (b.odznakProbihaBg, b.odznakProbihaText),
      StavRelace.schvaleno => (b.odznakSchvalenoBg, b.odznakSchvalenoText),
      StavRelace.dokonceno => (b.odznakDokoncenoBg, b.odznakDokoncenoText),
    };
    return StavovyOdznak(
      popisek: stav == StavRelace.probiha ? '● ${stav.popisek}' : stav.popisek,
      pozadi: pozadi,
      barvaTextu: popredi,
    );
  }
}

/// Popisky relace poskládané ze zkopírované SPZ, aktuálního seznamu
/// vozidel a seznamu stanic.
class PopiskyRelace {
  const PopiskyRelace({required this.vozidlo, required this.stanice});

  final String vozidlo;
  final String stanice;
}

/// Popisky se počítají z aktuálních dat; SPZ v relaci je ale kopie textu,
/// takže historie zůstane čitelná i po smazání vozidla z profilu.
///
/// Záměrně funkce, ne `Provider.family`: relace přicházejí ze streamu
/// jako nové instance bez hodnotové rovnosti, takže by rodina donekonečna
/// přibírala další a další záznamy.
PopiskyRelace popiskyRelace(WidgetRef ref, Relace relace) {
  final vozidla = ref.watch(vozidlaProvider).value ?? const [];
  String? znacka;
  for (final v in vozidla) {
    if (v.id == relace.vozidloId) {
      znacka = v.znackaModel;
      break;
    }
  }
  final stanice = ref.watch(mapaStanicProvider)[relace.staniceId];
  return PopiskyRelace(
    vozidlo: znacka == null ? relace.spz : '$znacka · ${relace.spz}',
    stanice: '${stanice?.nazev ?? 'Stanice'} · Konektor ${relace.konektor}',
  );
}

/// Řádek v seznamu relací (domovská obrazovka i historie).
class RadekRelace extends ConsumerWidget {
  const RadekRelace({super.key, required this.relace, required this.onTap});

  final Relace relace;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = context.barvy;
    final popisky = popiskyRelace(ref, relace);
    final podtitulek = relace.probiha
        ? '${popisky.stanice} · probíhá'
        : '${popisky.stanice} · ${Format.datum(relace.zahajeno)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: Rozmery.vyskaRadku),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: b.surface,
            borderRadius: BorderRadius.circular(Rozmery.radiusPolozky),
            border: Border.all(color: b.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      popisky.vozidlo,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      podtitulek,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OdznakStavu(relace.stav),
            ],
          ),
        ),
      ),
    );
  }
}
