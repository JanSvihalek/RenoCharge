import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Jediné místo, kde se saháme na Firebase SDK instance. Repozitáře je
/// dostávají přes tyto providery, takže je lze v testech přepsat.
final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final storageProvider = Provider<FirebaseStorage>(
  (ref) => FirebaseStorage.instance,
);

/// Názvy kolekcí na jednom místě, ať se nepřepisují po řetězcích.
abstract final class Kolekce {
  static const uzivatele = 'uzivatele';
  static const vozidla = 'vozidla';
  static const nabijeni = 'nabijeni';
  static const elektromery = 'elektromery';
  static const odecty = 'odecty';
}
