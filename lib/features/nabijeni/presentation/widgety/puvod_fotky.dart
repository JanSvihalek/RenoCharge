import 'package:flutter/material.dart';

import '../../../../common/formatovani.dart';
import '../../../../common/motiv/barvy.dart';
import '../../domain/porizena_fotografie.dart';

/// Řádek o původu snímku pod náhledem fotky.
///
/// U fotky z galerie je to podstatná informace: čas, který se zapíše
/// k relaci, je čas vzniku snímku z EXIF, ne okamžik výběru. Uživatel
/// tak vidí, že vybral fotku z minulého týdne, ještě než ji potvrdí.
///
/// U snímku pořízeného v aplikaci se nezobrazuje nic – tam se čas výběru
/// a čas pořízení liší nanejvýš o vteřiny.
class PuvodFotky extends StatelessWidget {
  const PuvodFotky(this.foto, {super.key});

  final PorizenaFotografie foto;

  @override
  Widget build(BuildContext context) {
    if (foto.zdroj != ZdrojFoto.galerie) return const SizedBox.shrink();
    final b = context.barvy;

    // Bez EXIF neumíme říct, kdy snímek vznikl – zapíše se čas výběru,
    // což je potřeba přiznat, ne schovat.
    final text = foto.casZExif
        ? 'Z galerie · vyfoceno ${Format.datum(foto.porizenoAt)} '
              'v ${Format.cas(foto.porizenoAt)}'
        : 'Z galerie · snímek neobsahuje čas pořízení, '
              'zapíše se aktuální čas';

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.photo_library_outlined, size: 15, color: b.textFaint),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: b.textFaint),
            ),
          ),
        ],
      ),
    );
  }
}
