import 'package:cloud_firestore/cloud_firestore.dart';

import '../../nabijeni/domain/foto_metadata.dart';

/// Poslední odečet, jak si ho u sebe drží elektroměr.
///
/// Denormalizace stejného druhu jako `aktivni_nabijeni_id` na profilu.
/// Bez ní by seznam osmdesáti elektroměrů musel udělat osmdesát dotazů
/// na poslední odečet. Zapisuje se v téže transakci jako odečet.
class PosledniOdecet {
  const PosledniOdecet({
    required this.hodnota,
    required this.odectenoAt,
    required this.odecetId,
  });

  final double hodnota;
  final DateTime odectenoAt;
  final String odecetId;

  /// Je odečet z daného měsíce? Podle toho se v seznamu pozná, co
  /// v obchůzce ještě zbývá.
  bool jeZMesice(DateTime mesic) {
    final kdy = odectenoAt.toLocal();
    return kdy.year == mesic.year && kdy.month == mesic.month;
  }

  Map<String, dynamic> naMapu() => {
    'hodnota': hodnota,
    'odecteno_at': Timestamp.fromDate(odectenoAt),
    'odecet_id': odecetId,
  };

  static PosledniOdecet? zMapy(Object? syrove) {
    if (syrove is! Map) return null;
    final hodnota = (syrove['hodnota'] as num?)?.toDouble();
    final kdy = syrove['odecteno_at'];
    final id = syrove['odecet_id'] as String?;
    if (hodnota == null || kdy is! Timestamp || id == null) return null;
    return PosledniOdecet(
      hodnota: hodnota,
      odectenoAt: kdy.toDate(),
      odecetId: id,
    );
  }
}

/// Jeden odečet elektroměru – dokument `odecty/{id}`.
///
/// Na rozdíl od nabíjecí relace je to **jeden nezměnitelný snímek**
/// zařízení v čase. Spotřeba se počítá až mezi dvěma po sobě jdoucími
/// odečty téhož elektroměru, ne uvnitř jednoho záznamu.
class Odecet {
  const Odecet({
    required this.id,
    required this.elektromerId,
    required this.pobockaKod,
    required this.uid,
    required this.hodnota,
    required this.odectenoAt,
    required this.foto,
    this.predchoziHodnota,
    this.vymenaMeridla = false,
    this.poznamka,
  });

  final String id;
  final String elektromerId;
  final String pobockaKod;

  /// Kdo odečet pořídil.
  final String uid;

  final double hodnota;

  /// Čas z EXIF fotky, ne čas zápisu – je to okamžik, kdy se počítadlo
  /// opravdu odečetlo.
  final DateTime odectenoAt;
  final FotoMetadata foto;

  /// Stav, který elektroměr nesl v době zápisu. Snímek toho, co člověk
  /// v tu chvíli viděl – slouží k auditu, ne k výpočtu spotřeby.
  final double? predchoziHodnota;

  /// Přiznaný restart počítadla. Bez něj aplikace nižší hodnotu než
  /// minulou nepustí.
  final bool vymenaMeridla;

  final String? poznamka;

  /// Spotřeba proti předchozímu odečtu, nebo `null`, když předchozí není
  /// nebo se měřidlo vyměnilo (rozdíl by pak nedával smysl).
  double? get spotrebaOdMinula {
    if (vymenaMeridla || predchoziHodnota == null) return null;
    final rozdil = hodnota - predchoziHodnota!;
    return rozdil < 0 ? null : rozdil;
  }

  factory Odecet.zDokumentu(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final foto = FotoMetadata.zMapy(data['foto']);
    return Odecet(
      id: doc.id,
      elektromerId: data['elektromer_id'] as String? ?? '',
      pobockaKod: data['pobocka_id'] as String? ?? '',
      uid: data['uid'] as String? ?? '',
      hodnota: (data['hodnota'] as num?)?.toDouble() ?? 0,
      odectenoAt:
          (data['odecteno_at'] as Timestamp?)?.toDate() ??
          (data['vytvoreno_at'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      foto:
          foto ??
          FotoMetadata(path: '', sha256: '', porizenoAt: DateTime.now()),
      predchoziHodnota: (data['predchozi_hodnota'] as num?)?.toDouble(),
      vymenaMeridla: data['vymena_meridla'] as bool? ?? false,
      poznamka: data['poznamka'] as String?,
    );
  }

  static Map<String, dynamic> mapaProZalozeni({
    required String elektromerId,
    required String pobockaKod,
    required String uid,
    required double hodnota,
    required DateTime odectenoAt,
    required FotoMetadata foto,
    double? predchoziHodnota,
    bool vymenaMeridla = false,
    String? poznamka,
  }) => {
    'elektromer_id': elektromerId,
    'pobocka_id': pobockaKod,
    'uid': uid,
    'hodnota': hodnota,
    'odecteno_at': Timestamp.fromDate(odectenoAt),
    'foto': foto.naMapu(),
    'predchozi_hodnota': predchoziHodnota,
    'vymena_meridla': vymenaMeridla,
    'poznamka': poznamka,
    'vytvoreno_at': FieldValue.serverTimestamp(),
  };
}

/// Odečet i s dopočítanou spotřebou proti tomu předchozímu.
///
/// Spotřeba se **neukládá** – počítá se až tady z celé řady. Uložená
/// hodnota by zastarala, kdyby se někdy doplnil chybějící starší odečet.
class OdecetSeSpotrebou {
  const OdecetSeSpotrebou({required this.odecet, this.spotreba});

  final Odecet odecet;

  /// `null` u nejstaršího odečtu a po výměně měřidla.
  final double? spotreba;
}

/// Doplní ke každému odečtu spotřebu proti tomu předchozímu.
///
/// Vstup se čeká seřazený **od nejnovějšího** – tak chodí z Firestore
/// i tak se zobrazuje.
List<OdecetSeSpotrebou> dopocitejSpotrebu(List<Odecet> odNejnovejsiho) {
  return [
    for (var i = 0; i < odNejnovejsiho.length; i++)
      OdecetSeSpotrebou(
        odecet: odNejnovejsiho[i],
        spotreba: _spotreba(
          novejsi: odNejnovejsiho[i],
          starsi: i + 1 < odNejnovejsiho.length ? odNejnovejsiho[i + 1] : null,
        ),
      ),
  ];
}

double? _spotreba({required Odecet novejsi, required Odecet? starsi}) {
  if (starsi == null) return null;
  // Po výměně měřidla je rozdíl nesmysl – počítadlo začalo od nuly.
  if (novejsi.vymenaMeridla) return null;
  final rozdil = novejsi.hodnota - starsi.hodnota;
  return rozdil < 0 ? null : rozdil;
}
