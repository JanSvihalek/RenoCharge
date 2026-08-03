import 'package:cloud_firestore/cloud_firestore.dart';

/// Konektor stanice. Podle zadání jsou vždy dva: A a B.
class Konektor {
  const Konektor({required this.id, required this.nazev});

  final String id;
  final String nazev;

  factory Konektor.zMapy(Map<String, dynamic> data) => Konektor(
    id: data['id'] as String? ?? '',
    nazev: data['nazev'] as String? ?? '',
  );
}

/// Nabíjecí stanice v areálu – dokument `stanice/{id}`.
/// Pro klienta je kolekce jen ke čtení, spravuje ji správce mimo aplikaci.
class Stanice {
  const Stanice({
    required this.id,
    required this.nazev,
    required this.konektory,
  });

  final String id;
  final String nazev;
  final List<Konektor> konektory;

  factory Stanice.zDokumentu(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final syrove = data['konektory'];
    final konektory = syrove is List
        ? syrove
              .whereType<Map<String, dynamic>>()
              .map(Konektor.zMapy)
              .where((k) => k.id.isNotEmpty)
              .toList()
        : const <Konektor>[];
    return Stanice(
      id: doc.id,
      nazev: data['nazev'] as String? ?? doc.id,
      konektory: konektory.isEmpty ? _vychoziKonektory : konektory,
    );
  }

  /// Když stanice konektory neuvádí, počítáme s dvojicí A/B podle zadání.
  static const List<Konektor> _vychoziKonektory = [
    Konektor(id: 'A', nazev: 'Konektor A'),
    Konektor(id: 'B', nazev: 'Konektor B'),
  ];
}
