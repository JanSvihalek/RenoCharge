import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../common/chyby.dart';
import '../../../common/firebase/firebase_providery.dart';
import '../domain/stanice.dart';

/// Seznam stanic. Kolekce je pro klienta pouze ke čtení.
class StaniceRepository {
  StaniceRepository({required FirebaseFirestore db}) : _db = db;

  final FirebaseFirestore _db;

  Stream<List<Stanice>> sleduj() => _db
      .collection(Kolekce.stanice)
      .snapshots()
      .map(
        (snimek) =>
            snimek.docs.map(Stanice.zDokumentu).toList()..sort(porovnejNazvy),
      )
      .handleError((Object chyba) => throw AppChyba.zFirebase(chyba));

  Future<Stanice?> nacti(String id) async {
    try {
      final doc = await _db.collection(Kolekce.stanice).doc(id).get();
      return doc.exists ? Stanice.zDokumentu(doc) : null;
    } catch (chyba) {
      throw AppChyba.zFirebase(chyba);
    }
  }

  /// Řadí „Stanice 2“ před „Stanice 10“ – prosté abecední řazení by
  /// v gridu udělalo nepřehledný nepořádek.
  static int porovnejNazvy(Stanice a, Stanice b) {
    final cisloA = _cislo(a.nazev);
    final cisloB = _cislo(b.nazev);
    if (cisloA != null && cisloB != null && cisloA != cisloB) {
      return cisloA.compareTo(cisloB);
    }
    return a.nazev.toLowerCase().compareTo(b.nazev.toLowerCase());
  }

  static int? _cislo(String text) {
    final shoda = RegExp(r'\d+').firstMatch(text);
    return shoda == null ? null : int.tryParse(shoda.group(0)!);
  }
}
