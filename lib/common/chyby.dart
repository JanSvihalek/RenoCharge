import 'package:firebase_auth/firebase_auth.dart';

/// Chyba, kterou umíme uživateli srozumitelně vysvětlit česky.
///
/// Repozitáře nikdy nepropouštějí do UI syrové výjimky z Firebase SDK –
/// převádějí je přes [AppChyba.zFirebase].
sealed class AppChyba implements Exception {
  const AppChyba(this.zprava);

  /// Text určený přímo k zobrazení uživateli.
  final String zprava;

  @override
  String toString() => '$runtimeType: $zprava';

  /// Převod výjimky z Firebase SDK na hlášku v češtině.
  static AppChyba zFirebase(Object chyba) {
    if (chyba is AppChyba) return chyba;
    if (chyba is FirebaseAuthException) {
      return switch (chyba.code) {
        'web-context-canceled' ||
        'canceled' ||
        'user-canceled' => const PrihlaseniZruseno(),
        'network-request-failed' => const BezPripojeni(),
        'account-exists-with-different-credential' => const PrihlaseniSelhalo(
          'Tento e-mail už je v aplikaci vedený s jiným způsobem přihlášení.',
        ),
        'user-disabled' => const PrihlaseniSelhalo(
          'Účet je zablokovaný. Obraťte se na správce.',
        ),
        // Firebase se zapnutou ochranou proti zjišťování účtů schválně
        // nerozlišuje neexistující účet od špatného hesla – ani my to
        // uživateli neprozradíme.
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' => const NespravnePrihlasovaciUdaje(),
        'invalid-email' => const NeplatnyEmail(),
        'too-many-requests' => const PrilisMnohoPokusu(),
        'operation-not-allowed' => const PrihlaseniSelhalo(
          'Tento způsob přihlášení není povolený. Obraťte se na správce.',
        ),
        _ => PrihlaseniSelhalo(
          'Přihlášení se nezdařilo. Zkuste to prosím znovu. (${chyba.code})',
        ),
      };
    }
    if (chyba is FirebaseException) {
      return switch (chyba.code) {
        'permission-denied' || 'unauthorized' => const NedostatecnaOpravneni(),
        'unavailable' || 'network-request-failed' => const BezPripojeni(),
        'deadline-exceeded' => const BezPripojeni(),
        'not-found' || 'object-not-found' => const ZaznamNenalezen(),
        _ => NeznamaChyba('Operace se nezdařila. (${chyba.code})'),
      };
    }
    return const NeznamaChyba();
  }
}

// ── Přihlášení ───────────────────────────────────────────────────────────────

class PrihlaseniZruseno extends AppChyba {
  const PrihlaseniZruseno() : super('Přihlášení bylo zrušeno.');
}

class PrihlaseniSelhalo extends AppChyba {
  const PrihlaseniSelhalo([
    super.zprava = 'Přihlášení se nezdařilo. Zkuste to prosím znovu.',
  ]);
}

class NespravnePrihlasovaciUdaje extends AppChyba {
  const NespravnePrihlasovaciUdaje()
    : super(
        'Nesprávný e-mail nebo heslo. Zkontrolujte prosím údaje '
        'a zkuste to znovu.',
      );
}

class NeplatnyEmail extends AppChyba {
  const NeplatnyEmail() : super('Zadejte prosím e-mail ve správném tvaru.');
}

class PrilisMnohoPokusu extends AppChyba {
  const PrilisMnohoPokusu()
    : super(
        'Příliš mnoho pokusů o přihlášení. Počkejte prosím chvíli '
        'a zkuste to znovu.',
      );
}

class NeniPrihlasen extends AppChyba {
  const NeniPrihlasen() : super('Nejste přihlášeni.');
}

// ── Průběh nabíjení ──────────────────────────────────────────────────────────

/// Uživatel už má jednu otevřenou relaci – nejdřív musí ukončit ji.
class JizMateOtevrenouRelaci extends AppChyba {
  const JizMateOtevrenouRelaci(this.relaceId)
    : super(
        'Máte rozdělané nabíjení. Nejdřív ho prosím ukončete, '
        'teprve pak můžete zahájit další.',
      );

  final String relaceId;
}

/// Na daném konektoru už běží relace jiného uživatele.
class KonektorObsazen extends AppChyba {
  const KonektorObsazen()
    : super(
        'Na tomto konektoru už nabíjení probíhá. '
        'Vyberte prosím jiný konektor nebo stanici.',
      );
}

class NeplatnyKoncovyStav extends AppChyba {
  const NeplatnyKoncovyStav(this.kwhStart)
    : super(
        'Koncový stav počítadla musí být vyšší než počáteční. '
        'Zkontrolujte prosím přečtenou hodnotu.',
      );

  final double kwhStart;
}

class RelaceJizUkoncena extends AppChyba {
  const RelaceJizUkoncena()
    : super('Tato relace už je ukončená a nelze ji měnit.');
}

class ZaznamNenalezen extends AppChyba {
  const ZaznamNenalezen() : super('Záznam se nepodařilo najít.');
}

// ── Fotografie ───────────────────────────────────────────────────────────────

class FoceniZruseno extends AppChyba {
  const FoceniZruseno() : super('Focení bylo zrušeno.');
}

class KameraNedostupna extends AppChyba {
  const KameraNedostupna()
    : super(
        'K fotoaparátu se nepodařilo přistoupit. '
        'Zkontrolujte prosím oprávnění aplikace v nastavení telefonu.',
      );
}

class NahraniFotoSelhalo extends AppChyba {
  const NahraniFotoSelhalo()
    : super(
        'Fotografii se nepodařilo nahrát. Zkontrolujte připojení '
        'a zkuste to prosím znovu.',
      );
}

// ── Obecné ───────────────────────────────────────────────────────────────────

class BezPripojeni extends AppChyba {
  const BezPripojeni()
    : super('Nemáte připojení k internetu. Zkuste to prosím znovu.');
}

class NedostatecnaOpravneni extends AppChyba {
  const NedostatecnaOpravneni() : super('K této operaci nemáte oprávnění.');
}

class NeznamaChyba extends AppChyba {
  const NeznamaChyba([
    super.zprava = 'Něco se pokazilo. Zkuste to prosím znovu.',
  ]);
}
