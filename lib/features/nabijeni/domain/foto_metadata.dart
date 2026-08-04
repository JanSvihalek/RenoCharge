import 'package:cloud_firestore/cloud_firestore.dart';

import 'porizena_fotografie.dart';

/// Údaje o fotografii počítadla uložené v dokumentu relace.
///
/// [sha256] slouží jako otisk souboru – díky němu jde později (např. při
/// fakturaci) ověřit, že se nahraná fotka nezměnila. [porizenoAt] je čas
/// pořízení z EXIF, ne čas nahrání na server. [zdroj] říká, jestli snímek
/// vznikl v aplikaci, nebo byl vybraný z galerie.
class FotoMetadata {
  const FotoMetadata({
    required this.path,
    required this.sha256,
    required this.porizenoAt,
    this.zdroj = ZdrojFoto.fotoaparat,
  });

  /// Cesta ve Firebase Storage, např. `nabijeni/{id}/start.jpg`.
  final String path;
  final String sha256;
  final DateTime porizenoAt;
  final ZdrojFoto zdroj;

  Map<String, dynamic> naMapu() => {
    'path': path,
    'sha256': sha256,
    'porizeno_at': Timestamp.fromDate(porizenoAt),
    'zdroj': zdroj.klic,
  };

  static FotoMetadata? zMapy(Object? syrove) {
    if (syrove is! Map) return null;
    final path = syrove['path'] as String?;
    final sha = syrove['sha256'] as String?;
    final cas = syrove['porizeno_at'];
    if (path == null || sha == null) return null;
    return FotoMetadata(
      path: path,
      sha256: sha,
      porizenoAt: cas is Timestamp ? cas.toDate() : DateTime.now(),
      zdroj: ZdrojFoto.zKlice(syrove['zdroj'] as String?),
    );
  }
}
