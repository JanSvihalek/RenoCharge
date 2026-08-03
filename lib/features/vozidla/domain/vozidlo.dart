import 'package:cloud_firestore/cloud_firestore.dart';

/// Vozidlo uživatele – dokument `uzivatele/{uid}/vozidla/{id}`.
class Vozidlo {
  const Vozidlo({required this.id, required this.spz, this.znackaModel});

  final String id;
  final String spz;

  /// Nepovinný název, např. „Škoda Octavia“.
  final String? znackaModel;

  /// Text, kterým se vozidlo označuje v relaci a v historii.
  String get popis => (znackaModel == null || znackaModel!.isEmpty)
      ? spz
      : '$znackaModel · $spz';

  factory Vozidlo.zDokumentu(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final znacka = (data['znacka_model'] as String?)?.trim();
    return Vozidlo(
      id: doc.id,
      spz: data['spz'] as String? ?? '',
      znackaModel: (znacka == null || znacka.isEmpty) ? null : znacka,
    );
  }

  Map<String, dynamic> naMapu() => {'spz': spz, 'znacka_model': znackaModel};
}
