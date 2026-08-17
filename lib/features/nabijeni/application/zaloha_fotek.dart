import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';

import '../domain/porizena_fotografie.dart';

/// Album v galerii telefonu. Vlastní schválně – po roce obchůzek by
/// dvanáct set snímků počítadel ve fotkách z dovolené nikdo nechtěl.
const String albumZaloh = 'RenoCharge';

/// Kopie vyfocených počítadel do galerie telefonu.
///
/// Je to **záloha pro uživatele, ne pro aplikaci**. Ta si fotky drží ve
/// Storage a z galerie je nikdy nečte, takže když se uložení nepovede,
/// na záznamu se nic nemění.
class ZalohaFotek {
  const ZalohaFotek();

  /// Má aplikace právo do galerie zapisovat? Ptá se i o něj, pokud ho
  /// ještě nemá – proto se to volá při zapnutí volby v nastavení, kde
  /// se odmítnutí dá vysvětlit, a ne u nabíječky.
  Future<bool> zajistiPravo() async {
    try {
      if (await Gal.hasAccess(toAlbum: true)) return true;
      return Gal.requestAccess(toAlbum: true);
    } catch (_) {
      return false;
    }
  }

  /// Uloží snímek do galerie. Snímky vybrané z galerie přeskakuje –
  /// ukládat kopii vedle originálu nemá smysl.
  ///
  /// Vyhodí [GalException], když právo chybí nebo zápis selže. Volající
  /// to musí ošetřit tak, aby to nezablokovalo založení záznamu.
  Future<void> uloz(PorizenaFotografie foto) async {
    if (foto.zdroj == ZdrojFoto.galerie) return;
    await Gal.putImage(foto.cestaVSouborovemSystemu, album: albumZaloh);
  }
}

final zalohaFotekProvider = Provider<ZalohaFotek>((ref) => const ZalohaFotek());
