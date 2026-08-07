import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../common/chyby.dart';
import '../../../common/firebase/firebase_providery.dart';
import '../../../common/konfigurace.dart';
import '../../nabijeni/domain/foto_metadata.dart';
import '../domain/elektromer.dart';
import '../domain/odecet.dart';

/// Zápis a čtení odečtů elektroměrů.
///
/// Odečet je nezměnitelný: jednou zapsaný se needituje ani nemaže,
/// oprava se dělá novým odečtem. Vynucují to `firestore.rules`.
class OdectyRepository {
  OdectyRepository({required FirebaseFirestore db}) : _db = db;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _odecty =>
      _db.collection(Kolekce.odecty);

  DocumentReference<Map<String, dynamic>> _elektromer(String id) =>
      _db.collection(Kolekce.elektromery).doc(id);

  /// ID se generuje dopředu – cesta k fotce se z něj odvozuje ještě
  /// předtím, než dokument vznikne.
  String noveId() => _odecty.doc().id;

  /// Historie odečtů elektroměru, od nejnovějšího.
  Stream<List<Odecet>> sledujProElektromer(
    String elektromerId, {
    int limit = Konfigurace.limitHistorie,
  }) => _odecty
      .where('elektromer_id', isEqualTo: elektromerId)
      .orderBy('odecteno_at', descending: true)
      .limit(limit)
      .snapshots()
      .map((snimek) => snimek.docs.map(Odecet.zDokumentu).toList())
      .handleError((Object chyba) => throw AppChyba.zFirebase(chyba));

  /// Zapíše odečet a zároveň ho promítne do elektroměru.
  ///
  /// Transakcí, ne dávkou: dva údržbáři u jednoho elektroměru současně
  /// by si jinak přepsali `posledni_odecet` a seznam by pak ukazoval
  /// starší hodnotu než historie.
  ///
  /// Hodnota musí být vyšší než poslední odečet. Výjimkou je přiznaná
  /// výměna měřidla, kdy počítadlo legitimně začíná od nuly.
  Future<void> zapis({
    required String odecetId,
    required Elektromer elektromer,
    required String uid,
    required double hodnota,
    required DateTime odectenoAt,
    required FotoMetadata foto,
    bool vymenaMeridla = false,
    String? poznamka,
  }) async {
    final odecetRef = _odecty.doc(odecetId);
    final elektromerRef = _elektromer(elektromer.id);

    try {
      await _db.runTransaction((tx) async {
        final snimek = await tx.get(elektromerRef);
        if (!snimek.exists) throw const ZaznamNenalezen();
        final aktualni = Elektromer.zDokumentu(snimek);

        final predchozi = aktualni.posledniOdecet;
        if (!vymenaMeridla &&
            predchozi != null &&
            hodnota <= predchozi.hodnota) {
          throw NizsiNezMinulyOdecet(predchozi.hodnota);
        }

        tx.set(
          odecetRef,
          Odecet.mapaProZalozeni(
            elektromerId: aktualni.id,
            pobockaKod: aktualni.pobockaKod,
            uid: uid,
            hodnota: hodnota,
            odectenoAt: odectenoAt,
            foto: foto,
            predchoziHodnota: predchozi?.hodnota,
            vymenaMeridla: vymenaMeridla,
            poznamka: poznamka,
          ),
        );

        // Novější odečet nesmí přepsat starším – při doplňování
        // zpětného odečtu by se jinak seznam rozešel se skutečností.
        if (predchozi == null || !odectenoAt.isBefore(predchozi.odectenoAt)) {
          tx.update(
            elektromerRef,
            Elektromer.mapaProPosledniOdecet(
              PosledniOdecet(
                hodnota: hodnota,
                odectenoAt: odectenoAt,
                odecetId: odecetId,
              ),
            ),
          );
        }
      });
    } catch (chyba) {
      throw AppChyba.zFirebase(chyba);
    }
  }
}
