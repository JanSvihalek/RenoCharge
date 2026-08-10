import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../common/chyby.dart';
import '../../../common/firebase/firebase_providery.dart';
import '../domain/report.dart';
import '../domain/zaznam_exportu.dart';

/// Zápis a čtení stop po vytvořených reportech.
class ExportyRepository {
  ExportyRepository({required FirebaseFirestore db}) : _db = db;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _exporty =>
      _db.collection(Kolekce.exporty);

  /// Poslední exporty uživatele, od nejnovějšího.
  Stream<List<ZaznamExportu>> sleduj(String uid, {int limit = 50}) => _exporty
      .where('uid', isEqualTo: uid)
      .orderBy('vytvoreno_at', descending: true)
      .limit(limit)
      .snapshots()
      .map((snimek) => snimek.docs.map(ZaznamExportu.zDokumentu).toList())
      .handleError((Object chyba) => throw AppChyba.zFirebase(chyba));

  Future<void> zapis({
    required String uid,
    required Obdobi obdobi,
    required int pocetZaznamu,
    required bool sFotkami,
  }) async {
    try {
      await _exporty.add(
        ZaznamExportu.mapaProZalozeni(
          uid: uid,
          obdobi: obdobi,
          pocetZaznamu: pocetZaznamu,
          sFotkami: sFotkami,
          vytvorenoAt: DateTime.now(),
        ),
      );
    } catch (chyba) {
      throw AppChyba.zFirebase(chyba);
    }
  }
}
