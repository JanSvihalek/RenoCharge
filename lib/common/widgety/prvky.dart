import 'package:flutter/material.dart';

import '../motiv/barvy.dart';
import '../motiv/rozmery.dart';
import 'tlacitka.dart';

/// Barevný odznak stavu (PROBÍHÁ / DOKONČENO / SCHVÁLENO).
class StavovyOdznak extends StatelessWidget {
  const StavovyOdznak({
    super.key,
    required this.popisek,
    required this.pozadi,
    required this.barvaTextu,
  });

  final String popisek;
  final Color pozadi;
  final Color barvaTextu;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: pozadi,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        popisek,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: barvaTextu),
      ),
    );
  }
}

/// Nadpis sekce verzálkami („VOZIDLO“, „STANICE“).
class NadpisSekce extends StatelessWidget {
  const NadpisSekce(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

/// Velký nadpis obrazovky se záložkami („Historie“, „Moje vozidla“).
class VelkyNadpis extends StatelessWidget {
  const VelkyNadpis(this.text, {super.key, this.akce});

  final String text;
  final Widget? akce;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 18),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.headlineSmall),
          ),
          ?akce,
        ],
      ),
    );
  }
}

/// Hlavička toku: tlačítko zpět, titulek na střed, vyvážení vpravo.
class HlavickaToku extends StatelessWidget implements PreferredSizeWidget {
  const HlavickaToku({super.key, required this.titulek, this.onZpet});

  final String titulek;
  final VoidCallback? onZpet;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            SizedBox(
              width: Rozmery.tlacitkoIkona,
              child: onZpet == null
                  ? null
                  : IkonoveTlacitko(
                      ikona: Icons.arrow_back_ios_new,
                      onTap: onZpet,
                      popisPristupnosti: 'Zpět',
                      sOramovanim: false,
                    ),
            ),
            Expanded(
              child: Text(
                titulek,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(width: Rozmery.tlacitkoIkona),
          ],
        ),
      ),
    );
  }
}

/// Karta na podkladu `surface` s okrajem.
class Karta extends StatelessWidget {
  const Karta({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = Rozmery.radiusKarty,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final b = context.barvy;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: b.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: b.border),
      ),
      clipBehavior: Clip.antiAlias,
      padding: padding,
      child: child,
    );
  }
}

/// Řádek `popisek – hodnota` v rekapitulaci a detailu relace.
class RadekDat extends StatelessWidget {
  const RadekDat({
    super.key,
    required this.popisek,
    required this.hodnota,
    this.posledni = false,
  });

  final String popisek;
  final String hodnota;
  final bool posledni;

  @override
  Widget build(BuildContext context) {
    final b = context.barvy;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: posledni ? null : Border(bottom: BorderSide(color: b.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(popisek, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hodnota,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

/// Zvýrazněný blok se spotřebou na patě karty.
class BlokSpotreby extends StatelessWidget {
  const BlokSpotreby({super.key, required this.kwh, this.castka});

  final String kwh;

  /// Orientační částka podle sazby z nastavení. `null`, když sazba
  /// zadaná není – pak se o penězích nemluví vůbec.
  final String? castka;

  @override
  Widget build(BuildContext context) {
    final b = context.barvy;
    return Container(
      width: double.infinity,
      color: b.accentDim,
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Text('Spotřeba', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            '$kwh kWh',
            style: Theme.of(
              context,
            ).textTheme.displaySmall?.copyWith(color: b.accent),
          ),
          // Slovo „orientačně" tu není omylem: fakturuje se mimo aplikaci
          // a sazba se může lišit.
          if (castka != null) ...[
            const SizedBox(height: 2),
            Text(
              'orientačně $castka',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// Sdělení, že v seznamu zatím nic není.
class PrazdnyStav extends StatelessWidget {
  const PrazdnyStav({super.key, required this.text, this.ikona});

  final String text;
  final IconData? ikona;

  @override
  Widget build(BuildContext context) {
    final b = context.barvy;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 8),
      child: Column(
        children: [
          if (ikona != null) ...[
            Icon(ikona, size: 32, color: b.textFaint),
            const SizedBox(height: 12),
          ],
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: b.textDim),
          ),
        ],
      ),
    );
  }
}

/// Sjednocené zobrazení chyby uvnitř obsahu obrazovky.
class ChybovyBlok extends StatelessWidget {
  const ChybovyBlok({super.key, required this.zprava, this.onZkusitZnovu});

  final String zprava;
  final VoidCallback? onZkusitZnovu;

  @override
  Widget build(BuildContext context) {
    final b = context.barvy;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: b.surface,
        borderRadius: BorderRadius.circular(Rozmery.radiusPolozky),
        border: Border.all(color: b.danger, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: b.danger, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  zprava,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          if (onZkusitZnovu != null) ...[
            const SizedBox(height: 12),
            PrimarniTlacitko(
              popisek: 'Zkusit znovu',
              onTap: onZkusitZnovu,
              vyska: Rozmery.dotykMin,
            ),
          ],
        ],
      ),
    );
  }
}
