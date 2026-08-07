import 'elektromer.dart';

/// Předpona v QR kódu. Bez ní by aplikace reagovala na každý QR, který
/// jí přijde pod ruku – na parkovacím lístku, na obalu, na billboardu.
const String predponaQr = 'renocharge:elektromer:';

/// Jak se elektroměr našel. Ukazuje se uživateli, ať ví, čemu věřit:
/// QR je jednoznačný, číslo z fotky je odhad, který má potvrdit.
enum ZpusobNalezeni { qrKod, cisloZeStitku }

class NalezenyElektromer {
  const NalezenyElektromer({required this.elektromer, required this.zpusob});

  final Elektromer elektromer;
  final ZpusobNalezeni zpusob;
}

/// Co má být v QR štítku daného elektroměru.
String obsahQr(Elektromer elektromer) => '$predponaQr${elektromer.id}';

/// Najde elektroměr podle obsahu QR kódu.
///
/// Přijímá i **holé číslo ze štítku**, kdyby někdo vyrobil jednodušší
/// kódy než ty naše – identifikace je pak stejná jako u OCR.
NalezenyElektromer? najdiPodleQr(String obsah, List<Elektromer> elektromery) {
  final ocisteny = obsah.trim();

  if (ocisteny.startsWith(predponaQr)) {
    final id = ocisteny.substring(predponaQr.length);
    for (final e in elektromery) {
      if (e.id == id) {
        return NalezenyElektromer(elektromer: e, zpusob: ZpusobNalezeni.qrKod);
      }
    }
    // Předpona sedí, ale elektroměr neznáme – nemá smysl padat do OCR,
    // je to náš kód pro něco, co v evidenci není.
    return null;
  }

  return najdiPodleCisla(ocisteny, elektromery);
}

/// Najde elektroměr podle čísla přečteného ze štítku.
///
/// OCR vrací celé řádky včetně typu, výrobce a nesmyslů, proto se
/// z textu vytahují všechny delší číselné shluky a zkouší se každý.
/// Krátká čísla se přeskakují – „2024" na štítku je rok výroby, ne
/// výrobní číslo.
NalezenyElektromer? najdiPodleCisla(String text, List<Elektromer> elektromery) {
  for (final kandidat in cislaZTextu(text)) {
    for (final e in elektromery) {
      if (Elektromer.klicCisla(e.cislo) == kandidat) {
        return NalezenyElektromer(
          elektromer: e,
          zpusob: ZpusobNalezeni.cisloZeStitku,
        );
      }
    }
  }
  return null;
}

/// Číselné shluky z textu, od nejdelšího – delší číslo je s větší
/// pravděpodobností to výrobní.
///
/// Skupiny číslic se skládají dohromady **jen když je dělí mezera**:
/// „18 342 771" na štítku a „18342771" v evidenci je totéž. Přes slova
/// se nespojuje, jinak by z „rok 2024 typ 3f" vzniklo číslo „20243".
///
/// Krátké shluky se zahazují – „2024" je rok výroby, ne výrobní číslo.
List<String> cislaZTextu(String text) {
  const nejkratsi = 5;
  final kandidati = <String>{};

  // Nedělitelné mezery na normální, ať dál stačí hledat souvislé
  // úseky číslic oddělených obyčejnou mezerou nebo tabulátorem.
  final ocisteny = text.replaceAll('\u00A0', ' ');
  final useky = RegExp(r'\d+(?:[ \t]+\d+)*').allMatches(ocisteny);

  for (final usek in useky) {
    final skupiny = RegExp(
      r'\d+',
    ).allMatches(usek.group(0)!).map((m) => m.group(0)!).toList();

    // Všechny souvislé podposloupnosti skupin – číslo může být i jen
    // částí úseku, když za ním následuje třeba rok výroby.
    for (var od = 0; od < skupiny.length; od++) {
      final buffer = StringBuffer();
      for (var doIndexu = od; doIndexu < skupiny.length; doIndexu++) {
        buffer.write(skupiny[doIndexu]);
        final kandidat = buffer.toString();
        if (kandidat.length >= nejkratsi) kandidati.add(kandidat);
      }
    }
  }

  return kandidati.toList()..sort((a, b) => b.length.compareTo(a.length));
}
