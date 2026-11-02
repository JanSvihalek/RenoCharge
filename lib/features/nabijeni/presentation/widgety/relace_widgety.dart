import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/formatovani.dart';
import '../../../../common/motiv/barvy.dart';
import '../../../../common/motiv/rozmery.dart';
import '../../../../common/widgety/prvky.dart';
import '../../../auth/application/auth_providery.dart';
import '../../../vozidla/application/vozidla_providery.dart';
import '../../domain/mesicni_skupina.dart';
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

/// Popisek vozidla: značka doplněná z aktuálního profilu, SPZ z relace.
///
/// SPZ je v relaci kopie textu, takže historie zůstane čitelná i po
/// smazání vozidla z profilu – jen bez značky.
///
/// Záměrně funkce, ne `Provider.family`: relace přicházejí ze streamu
/// jako nové instance bez hodnotové rovnosti, takže by rodina donekonečna
/// přibírala další a další záznamy.
String popisekVozidla(WidgetRef ref, Relace relace) {
  final vozidla = ref.watch(vozidlaProvider).value ?? const [];
  String? znacka;
  for (final v in vozidla) {
    if (v.id == relace.vozidloId) {
      znacka = v.znackaModel;
      break;
    }
  }
  return znacka == null ? relace.spz : '$znacka · ${relace.spz}';
}

/// Orientační částka za odběr podle sazby z nastavení, nebo `null`,
/// když si ji uživatel nezadal.
///
/// Počítá se z **aktuálně nastavené** sazby, neukládá se k záznamu.
/// Změna sazby proto přepočítá i historii – u orientačního údaje je to
/// srozumitelnější než mít v seznamu částky podle několika starých sazeb.
/// Fakturuje se stejně mimo aplikaci.
String? orientacniCastka(WidgetRef ref, double? spotreba) {
  final castka = ref.watch(profilProvider).value?.castkaZa(spotreba);
  return castka == null ? null : Format.castka(castka);
}

/// Předěl mezi měsíci v historii se součtem za daný měsíc.
class PredelMesice extends ConsumerWidget {
  const PredelMesice(this.skupina, {super.key});

  final MesicniSkupina skupina;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = context.barvy;
    final castka = orientacniCastka(ref, skupina.celkemKwh);

    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              Format.mesicARok(skupina.mesic).toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Když sazba není zadaná, nese hlavní roli spotřeba – jinak
              // by v předělu zbylo jen drobné šedé číslo.
              if (castka == null)
                Text(
                  '${Format.kwh(skupina.celkemKwh)} kWh',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: b.accent),
                )
              else ...[
                Text(
                  castka,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: b.penize,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${Format.kwh(skupina.celkemKwh)} kWh',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Řádek v seznamu relací: vozidlo, datum a spotřeba, vpravo částka a stav.
///
/// Stav říká, co s nabíjením ještě zbývá udělat: `NOVÉ` čeká na report,
/// `V reportu` je vyřízené. Dřív tu byl u všech stejný odznak „dokončeno"
/// a mezi nabíjeními ležely řádky reportů, ze kterých se to muselo
/// odvozovat.
class RadekRelace extends ConsumerWidget {
  const RadekRelace({
    super.key,
    required this.relace,
    required this.onTap,
    this.vReportu,
  });

  final Relace relace;
  final VoidCallback? onTap;

  /// `null`, dokud se reporty nenačetly – pak se stav neukazuje, jinak by
  /// po chybě načítání bylo všechno „nové".
  final bool? vReportu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = context.barvy;
    final castka = orientacniCastka(ref, relace.spotreba);
    final podtitulek = relace.probiha
        ? 'Probíhá od ${Format.cas(relace.zahajeno)}'
        : '${Format.denAMesic(relace.zahajeno)} · '
              '${Format.kwh(relace.spotreba ?? 0)} kWh';
    final stav = switch ((relace.stav, vReportu)) {
      (StavRelace.dokonceno, true) => const _VReportu(),
      (StavRelace.dokonceno, false) => StavovyOdznak(
        popisek: 'NOVÉ',
        pozadi: b.accentDim,
        barvaTextu: b.accent,
      ),
      (StavRelace.dokonceno, null) => null,
      // Běžící a schválené nabíjení říká víc jeho stav než report.
      _ => OdznakStavu(relace.stav),
    };

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
                      popisekVozidla(ref, relace),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (castka != null)
                    Text(
                      castka,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (castka != null && stav != null) const SizedBox(height: 4),
                  ?stav,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VReportu extends StatelessWidget {
  const _VReportu();

  @override
  Widget build(BuildContext context) {
    final b = context.barvy;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check, size: 14, color: b.textDim),
        const SizedBox(width: 4),
        Text('V reportu', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
