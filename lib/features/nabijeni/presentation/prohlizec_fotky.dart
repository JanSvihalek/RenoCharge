import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/nabijeni_providery.dart';

/// Fotka počítadla přes celou obrazovku, se zvětšováním prsty.
///
/// Kvůli tomu se fotí – při kontrole odečtu je potřeba si číslo na
/// displeji přiblížit. Náhled v detailu je na to moc malý.
class ProhlizecFotky extends ConsumerWidget {
  const ProhlizecFotky({super.key, required this.cesta, required this.popisek});

  final String cesta;
  final String popisek;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final odkaz = ref.watch(odkazNaFotkuProvider(cesta));

    return Scaffold(
      // Tmavé pozadí bez ohledu na motiv – u fotky se hodí, ať kolem ní
      // nic nesvítí.
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          Positioned.fill(
            child: switch (odkaz) {
              AsyncData(:final value) => InteractiveViewer(
                minScale: 1,
                maxScale: 6,
                child: Center(
                  child: Image.network(
                    value,
                    fit: BoxFit.contain,
                    loadingBuilder: (_, dite, prubeh) => prubeh == null
                        ? dite
                        : const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                    errorBuilder: (_, _, _) =>
                        const _Nedostupna('Fotku se nepodařilo načíst.'),
                  ),
                ),
              ),
              AsyncError() => const _Nedostupna(
                'Fotku se nepodařilo načíst. Zkontrolujte prosím připojení.',
              ),
              _ => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  Semantics(
                    button: true,
                    label: 'Zavřít fotku',
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Color(0x66000000),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      popisek,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        shadows: [Shadow(blurRadius: 6)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Nedostupna extends StatelessWidget {
  const _Nedostupna(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.broken_image_outlined,
            size: 40,
            color: Colors.white54,
          ),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    ),
  );
}
