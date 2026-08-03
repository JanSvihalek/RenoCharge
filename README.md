# Nabíjecí deník

Mobilní aplikace pro zaměstnance autosalonu k evidenci nabíjení soukromých
vozidel na firemní nabíječce. Uživatel před nabíjením a po něm vyfotí stav
počítadla; rozdíl kWh se fakturuje **mimo aplikaci**.

Aplikace o penězích nic neví – nezobrazuje ceny, sazby ani částky.

**Fáze 1: pouze mobilní zápis dat.** Webový portál pro schvalování
a fakturaci vznikne později a není součástí tohoto zadání.

## Stack

| | |
|---|---|
| Klient | Flutter (Android + iOS), stav přes Riverpod |
| Backend | Firebase Auth, Firestore, Storage – region `europe-west3` |
| Přihlášení | Firebase Auth, Microsoft OIDC provider |
| OCR | `google_mlkit_text_recognition`, on-device |

## Než se to poprvé spustí

Repozitář neobsahuje konfiguraci Firebase – tu je potřeba vygenerovat pro
konkrétní projekt.

1. **Firebase projekt.** Firestore i Storage založte v regionu
   `europe-west3`. Region se určuje při vytvoření a později se nedá změnit.

2. **Konfigurace klienta.**
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure --project=<id-projektu> --platforms=android,ios
   ```
   Příkaz přepíše zástupný `lib/firebase_options.dart` a založí
   `android/app/google-services.json` i `ios/Runner/GoogleService-Info.plist`.
   Dokud to neproběhne, aplikace se spustí do obrazovky s vysvětlením, ne
   do pádu.

3. **Přihlašování.** V konzoli Firebase → Authentication → Sign-in method
   zapněte **Email/Password** (bez *Email link*).

   Aplikace nemá registraci – účty zakládá správce v konzoli
   (*Authentication → Users → Add user*: e-mail a počáteční heslo).
   Zbytek si uživatel vyplní sám při prvním přihlášení v úvodním
   nastavení, takže konzole víc než e-mail a heslo řešit nemusí.

4. **Pravidla a indexy.**
   ```bash
   firebase deploy --only firestore:rules,firestore:indexes,storage
   ```

5. **Stanice.** Kolekce `stanice` je pro klienta jen ke čtení, plní se
   admin SDK. Seznam upravte v [tools/stanice.json](tools/stanice.json)
   (výchozí je 15 stanic s konektory A/B) a spusťte:
   ```bash
   cd tools
   npm install
   set GOOGLE_APPLICATION_CREDENTIALS=C:\cesta\ke\klici.json
   node seed_stanice.mjs --project renocharge
   ```
   Klíč servisního účtu se stahuje v konzoli: *Nastavení projektu →
   Servisní účty → Vygenerovat nový soukromý klíč*. Obchází security
   rules, takže **nepatří do gitu** – `.gitignore` na běžné názvy pamatuje.
   Skript je idempotentní, dokumenty mají pevná ID.

```bash
flutter pub get
flutter run
flutter test
```

## Struktura

Feature-first, uvnitř každé feature `domain` / `data` / `application` /
`presentation`. Widgety nesahají na Firebase SDK – vždy jdou přes
repository vrstvu vystavenou providerem.

```
lib/
  common/           motiv a tokeny, formátování, chyby, sdílené widgety
  features/
    auth/           přihlášení firemním účtem, profil uživatele
    nabijeni/       relace, stanice, focení, OCR, historie
    vozidla/        vozidla uživatele
  navigace/         hlavní rámec s tab barem, otevírání toků
```

## Datový model

```
uzivatele/{uid}                jmeno, email, osobni_cislo?, vytvoreno_at,
                               onboarding_at?,           ← viz Onboarding
                               aktivni_nabijeni_id?      ← viz Rozhodnutí
uzivatele/{uid}/vozidla/{id}   spz, znacka_model?
stanice/{id}                   nazev, konektory[{id,nazev}]   (jen ke čtení)
nabijeni/{id}                  uid, spz, vozidlo_id, stanice_id, konektor,
                               kwh_start, kwh_end?, zahajeno, ukonceno?,
                               foto_start{path,sha256,porizeno_at}, foto_end?,
                               stav: 'probiha'|'dokonceno',
                               vytvoreno_at, aktualizovano_at
zamky_konektoru/{stanice}__{A|B}   nabijeni_id, uid, stanice_id, konektor,
                                   zahajeno              ← viz Rozhodnutí
```

Relace je **jeden dokument**. Vzniká při zahájení se stavem `probiha`,
při ukončení se doplní koncové hodnoty a stav se změní na `dokonceno`.
Dva samostatné záznamy nikdy nevznikají.

## Pravidla a jak jsou vynucená

| Pravidlo | Kde |
|---|---|
| Jeden uživatel = nejvýš jedna otevřená relace | transakce + `uzivatele/{uid}.aktivni_nabijeni_id`; UI místo výběru nabídne ukončení té rozdělané |
| Jeden konektor = nejvýš jedna otevřená relace | transakce + kolekce `zamky_konektoru` |
| `kwh_end > kwh_start` | pole na obrazovce focení, transakce i `firestore.rules` |
| Po ukončení se záznamem nehne | `firestore.rules`: update jen ze stavu `probiha`, delete zakázaný |

Obě „nejvýš jedna" pravidla se dají porušit jen souběhem dvou telefonů,
proto je hlídá Firestore transakce, ne dotaz před zápisem. Klientské SDK
ale umí v transakci číst pouze konkrétní dokument (ne dotaz) – odtud obě
pomocné evidence popsané níže.

## Onboarding

Přihlašovací účet dá aplikaci jen e-mail. Jméno do pozdravu, osobní
firemní číslo pro párování při fakturaci a první vozidlo si proto
uživatel vyplní při prvním přihlášení
([onboarding_obrazovka.dart](lib/features/auth/presentation/onboarding_obrazovka.dart)).

Dokud v profilu chybí `onboarding_at`, pustí ho aplikace jen sem –
záměrně, protože bez vozidla nejde nabíjení ani zahájit. Příznak je
samostatné pole, ne dopočet z vyplněnosti: kdyby se odvozoval od toho,
že uživatel má aspoň jedno vozidlo, spadl by do onboardingu znovu
pokaždé, když si všechna vozidla smaže.

Profil a první vozidlo se zapisují **jednou dávkou**. Kdyby se uložilo
jen vozidlo, uživatel by zůstal v onboardingu a na druhý pokus by si
tutéž SPZ přidal podruhé.

Pole „Jméno a příjmení" se předvyplní odhadem z e-mailu
(`jana.novakova@firma.cz` → `Jana Novakova`) – jen jako návrh, který si
uživatel opraví na tvar s diakritikou.

## Rozhodnutí, která zadání nechalo otevřená

**`aktivni_nabijeni_id` na profilu a kolekce `zamky_konektoru`.**
Zadaný datový model je neobsahuje; bez nich se ale požadavek „kontroluj
to transakcí, ne dotazem" splnit nedá, protože `Transaction.get` přijímá
jen `DocumentReference`. Obojí je čistě technická evidence, žádná data
navíc – zámek vzniká i zaniká ve stejné transakci jako relace.

*Známé omezení:* zámek zakládá klient, takže si teoreticky může zabrat
konektor, na kterém nenabíjí. Pravidla to částečně vyvažují – zámek,
jehož relace neběží, smí přepsat kdokoli, takže blokace není trvalá.
Neprůstřelné řešení je založit zámek z Cloud Functions; ve fázi 1 to
zadání nepředpokládá.

**Čas pořízení fotky.** `foto.porizeno_at` se čte z EXIF a slouží zároveň
jako `zahajeno` / `ukonceno` relace – je to okamžik, kdy se počítadlo
opravdu odečetlo. `image_picker` ale snímek při zmenšení na 1600 px
překomprimuje a EXIF na části zařízení zahodí; v takovém případě se
použije čas, kdy fotoaparát snímek vrátil (`PorizenaFotografie.casZExif`
říká, který z obou to byl). Pokud musí být čas pořízení průkazný,
je potřeba fotit vlastním `camera` pluginem a EXIF si zapisovat sám.

**Rekapitulace se zapisuje až tlačítkem „Dokončit".** Do té doby je
relace pořád otevřená a uživatel se může vrátit. Odpovídá to prototypu.

**Odebrání vozidla se potvrzuje dialogem.** Prototyp maže rovnou, ale
akce se nedá vzít zpět a uživatel ji dělá v rukavicích.

**Motiv se nikam neukládá.** Přepínač na domovské obrazovce platí do
konce běhu aplikace, po restartu se aplikace zase řídí systémem – stejně
jako prototyp. Trvalé uložení by znamenalo přidat `shared_preferences`.

## Focení a OCR

Fotoaparát se otevře hned po vstupu na obrazovku focení – uživatel stojí
u nabíječky a nemá důvod ťukat na další tlačítko. Po vyfocení se snímek
zmenší na 1600 px (kvalita 80), spočítá se SHA-256 přesně těch bajtů,
které jdou do Storage, a on-device OCR se pokusí najít hodnotu.

OCR je **pomůcka, ne autorita**: pole je vždy přepisovatelné a bez
potvrzení tlačítkem se nikam nezapíše. Když se číslo přečíst nepodaří,
ruční zadání je rovnocenná cesta – ne nouzové řešení.

Heuristika výběru čísla ([ocr_sluzba.dart](lib/features/nabijeni/application/ocr_sluzba.dart))
zvýhodňuje čísla na řádku s „kWh", delší čísla a čísla s desetinami.
Je pokrytá testy, takže se dá ladit podle toho, co konkrétní nabíječky
v areálu na displeji ukazují.

## Mimo rozsah

Ceny, sazby, výpočet částek, export ISDOC, schvalování. Stav `schvaleno`
umí aplikace jen zobrazit v odznaku – nastavuje se mimo ni.
#   R e n o C h a r g e  
 