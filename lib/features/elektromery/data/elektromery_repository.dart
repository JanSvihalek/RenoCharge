import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../common/chyby.dart';
import '../../../common/firebase/firebase_providery.dart';
import '../domain/elektromer.dart';

/// Čtení a správa elektroměrů. Zápis smí jen údržba – vynucují to
/// `firestore.rules`, tady se na roli nespoléhá.
class ElektromeryRepository {
  ElektromeryRepository({required FirebaseFirestore db}) : _db = db;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _elektromery =>
      _db.collection(Kolekce.elektromery);

  /// Elektroměry pobočky, seřazené podle umístění.
  ///
  /// Vyřazené se nefiltrují dotazem, ale až v aplikaci – filtr na
  /// `aktivni` by si vyžádal další složený index a na pobočce jde
  /// o jednotky až desítky dokumentů.
  Stream<List<Elektromer>> sleduj(String pobockaKod) => _elektromery
      .where('pobocka_id', isEqualTo: pobockaKod)
      .orderBy('nazev')
      .snapshots()
      .map((snimek) => snimek.docs.map(Elektromer.zDokumentu).toList())
      .handleError((Object chyba) => throw AppChyba.zFirebase(chyba));

  Stream<Elektromer?> sledujJeden(String id) => _elektromery
      .doc(id)
      .snapshots()
      .map((doc) => doc.exists ? Elektromer.zDokumentu(doc) : null)
      .handleError((Object chyba) => throw AppChyba.zFirebase(chyba));

  /// Založí elektroměr a vrátí jeho ID.
  ///
  /// Jedinečnost čísla v rámci pobočky se hlídá dotazem, ne pravidlem –
  /// pravidla by na to potřebovala další pomocnou evidenci a duplicita
  /// není bezpečnostní problém, jen nepořádek v seznamu.
  Future<String> pridej({
    required String pobockaKod,
    required String cislo,
    required String nazev,
    required String uid,
  }) async {
    final ocistene = Elektromer.normalizujCislo(cislo);
    try {
      if (await cisloObsazeno(pobockaKod: pobockaKod, cislo: ocistene)) {
        throw CisloElektromeruObsazene(ocistene);
      }
      final doc = await _elektromery.add(
        Elektromer.mapaProZalozeni(
          pobockaKod: pobockaKod,
          cislo: ocistene,
          nazev: nazev.trim(),
          uid: uid,
        ),
      );
      return doc.id;
    } catch (chyba) {
      throw AppChyba.zFirebase(chyba);
    }
  }

  Future<void> uprav({
    required Elektromer elektromer,
    required String cislo,
    required String nazev,
    required bool aktivni,
  }) async {
    final ocistene = Elektromer.normalizujCislo(cislo);
    try {
      if (Elektromer.klicCisla(ocistene) !=
              Elektromer.klicCisla(elektromer.cislo) &&
          await cisloObsazeno(
            pobockaKod: elektromer.pobockaKod,
            cislo: ocistene,
          )) {
        throw CisloElektromeruObsazene(ocistene);
      }
      await _elektromery
          .doc(elektromer.id)
          .update(
            Elektromer.mapaProUpravu(
              cislo: ocistene,
              nazev: nazev.trim(),
              aktivni: aktivni,
            ),
          );
    } catch (chyba) {
      throw AppChyba.zFirebase(chyba);
    }
  }

  /// Porovnává se bez mezer, proto se načtou elektroměry pobočky
  /// a porovná se v aplikaci – Firestore neumí dotaz na normalizovanou
  /// podobu bez toho, aby se ukládala zvlášť.
  Future<bool> cisloObsazeno({
    required String pobockaKod,
    required String cislo,
  }) async {
    final klic = Elektromer.klicCisla(cislo);
    final snimek = await _elektromery
        .where('pobocka_id', isEqualTo: pobockaKod)
        .get();
    return snimek.docs.any(
      (doc) => Elektromer.klicCisla(Elektromer.zDokumentu(doc).cislo) == klic,
    );
  }
}
