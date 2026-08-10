import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/firebase/firebase_providery.dart';
import '../../auth/application/auth_providery.dart';
import '../data/exporty_repository.dart';
import '../domain/zaznam_exportu.dart';

final exportyRepositoryProvider = Provider<ExportyRepository>((ref) {
  return ExportyRepository(db: ref.watch(firestoreProvider));
});

/// Vytvořené reporty přihlášeného uživatele, od nejnovějšího.
final historieExportuProvider = StreamProvider<List<ZaznamExportu>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(const <ZaznamExportu>[]);
  return ref.watch(exportyRepositoryProvider).sleduj(uid);
});

/// Report, jehož období sahá **nejdál**, nebo `null`. Podle něj se nabízí
/// období toho příštího – navazuje se dnem po jeho konci.
///
/// Schválně ne ten naposledy vytvořený: kdo si po reportu za červenec
/// dodatečně vyjede ještě červen, nesmí tím posunout hranici zpátky
/// a dostat červenec podruhé.
///
/// Chyba se tu polyká: kdyby se seznam nepodařilo načíst, nabídka
/// „navázat" prostě nebude, ale export sám musí jít udělat dál.
final posledniExportProvider = Provider<ZaznamExportu?>((ref) {
  final exporty = ref.watch(historieExportuProvider).value ?? const [];
  ZaznamExportu? nejdal;
  for (final e in exporty) {
    if (nejdal == null || e.obdobi.doVcetne.isAfter(nejdal.obdobi.doVcetne)) {
      nejdal = e;
    }
  }
  return nejdal;
});
