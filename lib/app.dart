import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'common/motiv/barvy.dart';
import 'common/motiv/motiv.dart';
import 'common/motiv/rezim_motivu.dart';
import 'common/motiv/rozmery.dart';
import 'common/widgety/prvky.dart';
import 'features/auth/application/auth_providery.dart';
import 'features/auth/presentation/onboarding_obrazovka.dart';
import 'features/auth/presentation/prihlaseni_obrazovka.dart';
import 'navigace/hlavni_shell.dart';

class NabijeciDenikApp extends ConsumerWidget {
  const NabijeciDenikApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'RenoCharge',
      debugShowCheckedModeBanner: false,
      theme: Motiv.svetly(),
      darkTheme: Motiv.tmavy(),
      themeMode: ref.watch(rezimMotivuProvider),
      // Přepnutí režimu má být okamžité, bez prolínání.
      themeAnimationDuration: Duration.zero,
      locale: const Locale('cs'),
      supportedLocales: const [Locale('cs')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _Brana(),
    );
  }
}

/// Nepřihlášený uživatel se dostane jen na přihlašovací obrazovku.
class _Brana extends ConsumerWidget {
  const _Brana();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stav = ref.watch(stavPrihlaseniProvider);
    return switch (stav) {
      AsyncData(:final value) when value == null => const PrihlaseniObrazovka(),
      AsyncData() => const _PoPrihlaseni(),
      AsyncError() => const _ChybaSpojeni(),
      _ => const _Nacitani(),
    };
  }
}

/// Přihlášeného uživatele pustíme do aplikace teprve po vyplnění
/// úvodního nastavení – bez jména, osobního čísla a vozidla by neměl
/// čím ani za koho nabíjení evidovat.
class _PoPrihlaseni extends ConsumerWidget {
  const _PoPrihlaseni();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profil = ref.watch(profilProvider);
    return switch (profil) {
      AsyncData(:final value) when value?.maHotovyOnboarding ?? false =>
        const HlavniShell(),
      AsyncData(:final value) => OnboardingObrazovka(profil: value),
      AsyncError() => const _ChybaProfilu(),
      _ => const _Nacitani(),
    };
  }
}

class _Nacitani extends StatelessWidget {
  const _Nacitani();

  @override
  Widget build(BuildContext context) {
    final b = context.barvy;
    return Scaffold(
      backgroundColor: b.bg,
      body: Center(child: Icon(Icons.bolt, size: 44, color: b.accent)),
    );
  }
}

class _ChybaSpojeni extends ConsumerWidget {
  const _ChybaSpojeni();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.barvy.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Rozmery.okrajStranky),
          child: ChybovyBlok(
            zprava:
                'Nepodařilo se ověřit přihlášení. Zkontrolujte prosím '
                'připojení k internetu.',
            onZkusitZnovu: () => ref.invalidate(stavPrihlaseniProvider),
          ),
        ),
      ),
    );
  }
}

class _ChybaProfilu extends ConsumerWidget {
  const _ChybaProfilu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.barvy.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Rozmery.okrajStranky),
          child: ChybovyBlok(
            zprava:
                'Váš profil se nepodařilo načíst. Zkontrolujte prosím '
                'připojení k internetu.',
            onZkusitZnovu: () => ref.invalidate(profilProvider),
          ),
        ),
      ),
    );
  }
}

/// Obrazovka pro případ, že se nepovede nastartovat Firebase – bez něj
/// aplikace nemá kam zapisovat.
class ChybaStartuApp extends StatelessWidget {
  const ChybaStartuApp({super.key, required this.podrobnosti});

  final String podrobnosti;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: Motiv.tmavy(),
      home: Builder(
        builder: (context) => Scaffold(
          backgroundColor: context.barvy.bg,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Rozmery.okrajStranky),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Aplikaci se nepodařilo spustit',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Chybí nebo je neplatné nastavení Firebase. '
                    'Obraťte se prosím na správce aplikace.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    podrobnosti,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
