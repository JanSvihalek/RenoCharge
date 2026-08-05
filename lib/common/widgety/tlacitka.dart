import 'package:flutter/material.dart';

import '../motiv/barvy.dart';
import '../motiv/rozmery.dart';

/// Tlačítko se stiskovou odezvou podle návrhu: mírné zmenšení a snížení
/// průhlednosti. Žádné hover stavy – jde o dotykové rozhraní.
class _Stisk extends StatefulWidget {
  const _Stisk({required this.child, required this.onTap, this.aktivni = true});

  final Widget child;
  final VoidCallback? onTap;
  final bool aktivni;

  @override
  State<_Stisk> createState() => _StiskState();
}

class _StiskState extends State<_Stisk> {
  bool _drzi = false;

  void _nastav(bool hodnota) {
    if (!widget.aktivni) return;
    if (_drzi != hodnota) setState(() => _drzi = hodnota);
  }

  @override
  Widget build(BuildContext context) {
    final stisknuto = _drzi && widget.aktivni;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _nastav(true),
      onTapUp: (_) => _nastav(false),
      onTapCancel: () => _nastav(false),
      onTap: widget.aktivni ? widget.onTap : null,
      child: AnimatedScale(
        scale: stisknuto ? 0.97 : 1,
        duration: const Duration(milliseconds: 90),
        child: AnimatedOpacity(
          opacity: stisknuto ? 0.9 : 1,
          duration: const Duration(milliseconds: 90),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Primární akce – plná šířka, výrazné pozadí, vždy s textovým popiskem.
class PrimarniTlacitko extends StatelessWidget {
  const PrimarniTlacitko({
    super.key,
    required this.popisek,
    required this.onTap,
    this.ikona,
    this.vyska = Rozmery.tlacitkoPrimarni,
    this.barvaPozadi,
    this.barvaTextu,
    this.nacita = false,
  });

  final String popisek;
  final VoidCallback? onTap;
  final IconData? ikona;
  final double vyska;
  final Color? barvaPozadi;
  final Color? barvaTextu;
  final bool nacita;

  @override
  Widget build(BuildContext context) {
    final b = context.barvy;
    final zakazano = onTap == null || nacita;
    final pozadi = zakazano ? b.border : (barvaPozadi ?? b.accent);
    final popredi = zakazano ? b.textFaint : (barvaTextu ?? b.accentText);

    return _Stisk(
      aktivni: !zakazano,
      onTap: onTap,
      child: Container(
        height: vyska,
        width: double.infinity,
        decoration: BoxDecoration(
          color: pozadi,
          borderRadius: BorderRadius.circular(Rozmery.radiusTlacitka),
        ),
        alignment: Alignment.center,
        child: nacita
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: popredi,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (ikona != null) ...[
                    Icon(ikona, size: 22, color: popredi),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(
                      popisek,
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(color: popredi),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Sekundární akce v podobě odkazu (např. „Vyfotit znovu“). I tak má
/// dotykovou plochu 48 px – žádné drobné prvky.
class OdkazoveTlacitko extends StatelessWidget {
  const OdkazoveTlacitko({
    super.key,
    required this.popisek,
    required this.onTap,
  });

  final String popisek;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final barvaTextu = context.barvy.textDim;
    return _Stisk(
      aktivni: onTap != null,
      onTap: onTap,
      child: Container(
        height: 48,
        width: double.infinity,
        alignment: Alignment.center,
        child: Text(
          popisek,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: barvaTextu,
            decoration: TextDecoration.underline,
            decorationColor: barvaTextu,
          ),
        ),
      ),
    );
  }
}

/// Čtvercové tlačítko s ikonou (přepínač motivu, zpět, odebrat).
class IkonoveTlacitko extends StatelessWidget {
  const IkonoveTlacitko({
    super.key,
    required this.ikona,
    required this.onTap,
    required this.popisPristupnosti,
    this.barvaIkony,
    this.sOramovanim = true,
    this.pozadi,
  });

  final IconData ikona;
  final VoidCallback? onTap;
  final String popisPristupnosti;
  final Color? barvaIkony;
  final bool sOramovanim;
  final Color? pozadi;

  @override
  Widget build(BuildContext context) {
    final b = context.barvy;
    return Semantics(
      button: true,
      label: popisPristupnosti,
      child: _Stisk(
        aktivni: onTap != null,
        onTap: onTap,
        child: Container(
          width: Rozmery.tlacitkoIkona,
          height: Rozmery.tlacitkoIkona,
          decoration: BoxDecoration(
            color: pozadi ?? (sOramovanim ? b.surface : Colors.transparent),
            borderRadius: BorderRadius.circular(Rozmery.radiusMale),
            border: sOramovanim ? Border.all(color: b.border) : null,
          ),
          child: Icon(ikona, size: 20, color: barvaIkony ?? b.text),
        ),
      ),
    );
  }
}

/// Volba ze seznamu (například vozidlo). Vybraná položka má
/// zvýrazněný okraj v akcentní barvě.
class VolbaKarta extends StatelessWidget {
  const VolbaKarta({
    super.key,
    required this.vybrano,
    required this.onTap,
    required this.child,
    this.vyska = Rozmery.vyskaRadku,
    this.vycentrovat = false,
  });

  final bool vybrano;
  final VoidCallback onTap;
  final Widget child;
  final double vyska;
  final bool vycentrovat;

  @override
  Widget build(BuildContext context) {
    final b = context.barvy;
    final pozadi = vybrano ? b.accentDim : b.surface;
    return _Stisk(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: vyska),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: pozadi,
          borderRadius: BorderRadius.circular(Rozmery.radiusPolozky),
          border: Border.all(color: vybrano ? b.accent : b.border, width: 2),
        ),
        alignment: vycentrovat ? Alignment.center : Alignment.centerLeft,
        child: child,
      ),
    );
  }
}
