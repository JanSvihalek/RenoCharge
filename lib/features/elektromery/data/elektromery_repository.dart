import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../common/chyby.dart';
import '../../../common/firebase/firebase_providery.dart';
import '../domain/druh_mista.dart';
import '../domain/elektromer.dart';
import '../domain/vychozi_mista.dart';

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

  /// Založí odběrné místo a vrátí jeho ID.
  ///
  /// Jedinečnost čísla v rámci pobočky se hlídá dotazem, ne pravidlem –
  /// pravidla by na to potřebovala další pomocnou evidenci a duplicita
  /// není bezpečnostní problém, jen nepořádek v seznamu. Místo bez čísla
  /// se nekontroluje, prázdných může být kolik chce.
  Future<String> pridej({
    required String pobockaKod,
    required DruhMista druh,
    required String cislo,
    required String nazev,
    required String uid,
  }) async {
    final ocistene = Elektromer.normalizujCislo(cislo);
    try {
      if (ocistene.isNotEmpty &&
          await cisloObsazeno(pobockaKod: pobockaKod, cislo: ocistene)) {
        throw CisloElektromeruObsazene(ocistene);
      }
      final doc = await _elektromery.add(
        Elektromer.mapaProZalozeni(
          pobockaKod: pobockaKod,
          druh: druh,
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
      if (ocistene.isNotEmpty &&
          Elektromer.klicCisla(ocistene) !=
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

  /// Založí místa z výchozího seznamu pod jejich pevnými ID a vrátí,
  /// kolik jich vzniklo.
  ///
  /// Volající předává jen ta, která v evidenci chybí. Kdyby některé
  /// mezitím založil někdo jiný, zápis na existující dokument je pro
  /// pravidla úprava se změněným `vytvoreno_at` a odmítnou ho – přepsat
  /// cizí odečty se tím nedá.
  ///
  /// Zápisy jdou souběžně a dokončí se všechny, i když některý selže.
  /// Pak se vyhodí první chyba; co prošlo, zůstane a druhý pokus doplní
  /// jen zbytek.
  Future<int> zalozVychozi({
    required List<VychoziMisto> mista,
    required String uid,
  }) async {
    Object? prvniChyba;
    var zalozeno = 0;
    await Future.wait([
      for (final m in mista)
        _elektromery
            .doc(m.id)
            .set(
              Elektromer.mapaProZalozeni(
                pobockaKod: m.pobocka.kod,
                druh: m.druh,
                cislo: '',
                nazev: m.nazev,
                uid: uid,
              ),
            )
            .then((_) => zalozeno++)
            .catchError((Object chyba) {
              prvniChyba ??= chyba;
              return 0;
            }),
    ]);
    if (prvniChyba case final chyba?) throw AppChyba.zFirebase(chyba);
    return zalozeno;
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
