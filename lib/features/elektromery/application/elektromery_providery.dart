import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/chyby.dart';
import '../../../common/firebase/firebase_providery.dart';
import '../../auth/application/auth_providery.dart';
import '../data/elektromery_repository.dart';
import '../domain/druh_mista.dart';
import '../domain/elektromer.dart';
import '../domain/pobocka.dart';
import '../domain/vychozi_mista.dart';

final elektromeryRepositoryProvider = Provider<ElektromeryRepository>((ref) {
  return ElektromeryRepository(db: ref.watch(firestoreProvider));
});

/// Zvolená pobočka. Údržbář obchází pořád ten samý areál, takže volba
/// vydrží po celou dobu běhu aplikace.
class VybranaPobocka extends Notifier<Pobocka> {
  @override
  Pobocka build() => Pobocka.values.first;

  void vyber(Pobocka pobocka) => state = pobocka;
}

final vybranaPobockaProvider = NotifierProvider<VybranaPobocka, Pobocka>(
  VybranaPobocka.new,
);

/// Hledaný text v seznamu elektroměrů.
class Hledani extends Notifier<String> {
  @override
  String build() => '';

  void nastav(String dotaz) => state = dotaz;
}

final hledaniProvider = NotifierProvider<Hledani, String>(Hledani.new);

/// Zobrazený druh odběrných míst, `null` znamená všechny. Údržbář
/// obvykle obchází jeden druh naráz – plynoměry jsou jinde než
/// elektroměry – takže volba vydrží po celou dobu běhu aplikace.
class VybranyDruh extends Notifier<DruhMista?> {
  @override
  DruhMista? build() => null;

  void vyber(DruhMista? druh) => state = druh;
}

final vybranyDruhProvider = NotifierProvider<VybranyDruh, DruhMista?>(
  VybranyDruh.new,
);

/// Ukázat jen místa, která v poslední obchůzce ještě nemají odečet.
/// Výchozí je celý seznam – zúžení je pomůcka pro toho, kdo zrovna
/// obchází, ne výchozí pohled.
class JenNeodectene extends Notifier<bool> {
  @override
  bool build() => false;

  void prepni() => state = !state;
}

final jenNeodecteneProvider = NotifierProvider<JenNeodectene, bool>(
  JenNeodectene.new,
);

/// Místa z výchozího seznamu, která na zvolené pobočce ještě nejsou.
/// Dokud nějaké chybí, nabízí seznam jejich založení.
///
/// Porovnává se podle pevného ID, ne podle názvu – přejmenované místo
/// tak nechybí a nezaloží se znovu.
final chybejiciVychoziProvider = Provider<List<VychoziMisto>>((ref) {
  final pobocka = ref.watch(vybranaPobockaProvider);
  final evidovana = ref.watch(elektromeryProvider).value;
  // Dokud seznam nedorazil, nedá se říct, co chybí.
  if (evidovana == null) return const [];
  final idcka = {for (final e in evidovana) e.id};
  return [
    for (final m in vychoziMista)
      if (m.pobocka == pobocka && !idcka.contains(m.id)) m,
  ];
});

/// Elektroměry zvolené pobočky, seřazené podle umístění.
final elektromeryProvider = StreamProvider<List<Elektromer>>((ref) {
  if (ref.watch(uidProvider) == null) {
    return Stream.value(const <Elektromer>[]);
  }
  final pobocka = ref.watch(vybranaPobockaProvider);
  return ref.watch(elektromeryRepositoryProvider).sleduj(pobocka.kod);
});

/// Jeden elektroměr pro detail. Sleduje se, aby se detail sám srovnal
/// po úpravě.
final elektromerProvider = StreamProvider.autoDispose
    .family<Elektromer?, String>((ref, id) {
      return ref.watch(elektromeryRepositoryProvider).sledujJeden(id);
    });

/// Zakládání a úprava elektroměrů.
class ElektromeryController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String?> pridej({
    required Pobocka pobocka,
    required DruhMista druh,
    required String cislo,
    required String nazev,
  }) async {
    final uid = ref.read(uidProvider);
    if (uid == null) {
      state = AsyncValue.error(const NeniPrihlasen(), StackTrace.current);
      return null;
    }
    state = const AsyncValue.loading();
    final vysledek = await AsyncValue.guard(
      () => ref
          .read(elektromeryRepositoryProvider)
          .pridej(
            pobockaKod: pobocka.kod,
            druh: druh,
            cislo: cislo,
            nazev: nazev,
            uid: uid,
          ),
    );
    state = vysledek.hasError
        ? AsyncValue.error(vysledek.error!, vysledek.stackTrace!)
        : const AsyncValue.data(null);
    return vysledek.value;
  }

  Future<bool> uprav({
    required Elektromer elektromer,
    required String cislo,
    required String nazev,
    required bool aktivni,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref
          .read(elektromeryRepositoryProvider)
          .uprav(
            elektromer: elektromer,
            cislo: cislo,
            nazev: nazev,
            aktivni: aktivni,
          ),
    );
    return !state.hasError;
  }

  /// Založí chybějící místa z výchozího seznamu. Vrací počet založených,
  /// při chybě `null` – co se stihlo založit, zůstane.
  Future<int?> zalozVychozi(List<VychoziMisto> mista) async {
    final uid = ref.read(uidProvider);
    if (uid == null) {
      state = AsyncValue.error(const NeniPrihlasen(), StackTrace.current);
      return null;
    }
    state = const AsyncValue.loading();
    final vysledek = await AsyncValue.guard(
      () => ref
          .read(elektromeryRepositoryProvider)
          .zalozVychozi(mista: mista, uid: uid),
    );
    state = vysledek.hasError
        ? AsyncValue.error(vysledek.error!, vysledek.stackTrace!)
        : const AsyncValue.data(null);
    return vysledek.value;
  }

  void vymazChybu() => state = const AsyncValue.data(null);
}

final elektromeryControllerProvider =
    AsyncNotifierProvider<ElektromeryController, void>(
      ElektromeryController.new,
    );
