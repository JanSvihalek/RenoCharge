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

```bash
flutter pub get
flutter run
flutter test
```

## Ikona aplikace

V `assets/ikona/` je předloha `app-icon-1024.png` (modrý zaoblený čtverec
s bleskem) a z ní odvozené tři zdroje, ze kterých se generuje zbytek:

| Soubor | Co na něm je | Pro co |
|---|---|---|
| `ikona.png` | plný čtverec, bez alfa kanálu | iOS, starší Android |
| `ikona_pozadi.png` | jen gradient přes celé plátno | spodní vrstva adaptivní ikony |
| `ikona_popredi.png` | jen blesk na průhledném plátně | vrchní vrstva adaptivní ikony |

Předloha se použít napřímo nedá ze dvou důvodů. Má **zaoblené rohy
a v nich průhlednost**, jenže iOS si tvar zaobluje sám a alfa kanál
v ikoně App Store odmítá – rohy je proto potřeba dopočítat, aby byl
čtverec plný. A **adaptivní ikona Androidu je dvouvrstvá**: systém si
z ní podle výrobce vyřízne kolečko nebo zaoblený čtverec, takže motiv
musí být zvlášť a s rezervou u krajů.

Obojí vyřeší [tools/priprav_ikony.py](tools/priprav_ikony.py) (potřebuje
`pip install Pillow numpy`). Gradient předlohy je lineární ve směru
úhlopříčky, takže se dá proložit a dopočítat i pro rohy, kde v předloze
nic není. Skript si sám ověří, že se uvnitř tvaru nezměnil ani pixel
a že na hranici doplněné části není šev.

```bash
python tools/priprav_ikony.py     # jen když se mění předloha
dart run flutter_launcher_icons
```

Vygenerované soubory **patří do gitu** – build na CI je jen použije,
negeneruje je znovu. Konfigurace je v [pubspec.yaml](pubspec.yaml).

## Struktura

Feature-first, uvnitř každé feature `domain` / `data` / `application` /
`presentation`. Widgety nesahají na Firebase SDK – vždy jdou přes
repository vrstvu vystavenou providerem.

```
lib/
  common/           motiv a tokeny, formátování, chyby, sdílené widgety
  features/
    auth/           přihlášení firemním účtem, profil uživatele
    nabijeni/       relace, focení, OCR, historie
    reporty/        export období do PDF
    vozidla/        vozidla uživatele
  navigace/         hlavní rámec s tab barem, otevírání toků
```

## Datový model

```
uzivatele/{uid}                jmeno, email, osobni_cislo?, vytvoreno_at,
                               onboarding_at?,           ← viz Onboarding
                               aktivni_nabijeni_id?      ← viz Rozhodnutí
uzivatele/{uid}/vozidla/{id}   spz, znacka_model?
nabijeni/{id}                  uid, spz, vozidlo_id,
                               kwh_start, kwh_end?, zahajeno, ukonceno?,
                               foto_start{path,sha256,porizeno_at,zdroj},
                               foto_end?,
                               stav: 'probiha'|'dokonceno',
                               vytvoreno_at, aktualizovano_at
```

Relace je **jeden dokument**. Vzniká při zahájení se stavem `probiha`,
při ukončení se doplní koncové hodnoty a stav se změní na `dokonceno`.
Dva samostatné záznamy nikdy nevznikají.

## Pravidla a jak jsou vynucená

| Pravidlo | Kde |
|---|---|
| Jeden uživatel = nejvýš jedna otevřená relace | transakce + `uzivatele/{uid}.aktivni_nabijeni_id`; UI místo výběru nabídne ukončení té rozdělané |
| Fotka jde nahrát, ale ne přepsat ani smazat | `storage.rules`: `create` jen vlastníkovi, `update` i `delete` zakázané |
| `kwh_end > kwh_start` | pole na obrazovce focení, transakce i `firestore.rules` |
| Po ukončení se záznamem nehne | `firestore.rules`: update jen ze stavu `probiha`, delete zakázaný |

Pravidlo „nejvýš jedna" se dá porušit jen souběhem dvou telefonů, proto
ho hlídá Firestore transakce, ne dotaz před zápisem. Klientské SDK ale
umí v transakci číst pouze konkrétní dokument (ne dotaz) – odtud pomocné
pole `aktivni_nabijeni_id` popsané níže.

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

**Stanice a konektor se nezadávají.** Zadání s nimi počítalo, ale
nabíječky v areálu zatím nejsou nijak označené ani očíslované, takže by
uživatel vybíral z položek, které v reálu nerozezná. Do doby, než
označené budou, se zaznamenává jen vozidlo a stav počítadla.

Nabíjet naráz může víc aut, takže s tím padl i zámek konektoru – jediné
pravidlo o jedinečnosti je „jeden uživatel = jedna otevřená relace".
Až budou nabíječky označené, vrátí se to jako přidání pole do relace
a jednoho kroku ve výběru; podobu z doby, kdy to v projektu bylo, má git
v commitu předcházejícím tuhle změnu.

**Uid je součástí cesty ve Storage** – `nabijeni/{uid}/{relaceId}/start.jpg`.
Původně tam nebylo a `storage.rules` se na vlastníka doptávaly Firestore
přes `firestore.exists()`. Jenže takové cross-service volání Firebase
podmiňuje zvláštním IAM oprávněním pro servisní účet Storage: bez něj
vyhodnocení pravidla **selže a zápis se zamítne**. To oprávnění není
v repozitáři, nenasadí ho `firebase deploy` a dá se tiše odebrat – na
takové věci se nedá stavět. S uid v cestě se vlastnictví ověří přímo
z ní a pravidla se Firestore neptají vůbec.

Cenou je, že se z pravidel nedá poznat, jestli fotka patří k existujícímu
záznamu. Mazání je proto zakázané úplně, i vlastníkovi – jinak by z fotky
jako důkazu bylo jen přání. Po neúspěšném zahájení relace tak ve Storage
zůstane osiřelý snímek; děje se to jen když selže transakce po úspěšném
nahrání a uklidí se to dávkově zvenčí.

**`aktivni_nabijeni_id` na profilu.** Zadaný datový model ho neobsahuje;
bez něj se ale požadavek „kontroluj to transakcí, ne dotazem" splnit
nedá, protože `Transaction.get` přijímá jen `DocumentReference`. Je to
čistě technická evidence, žádná data navíc – vzniká i zaniká ve stejné
transakci jako relace.

**Čas pořízení fotky.** `foto.porizeno_at` se čte z EXIF a slouží zároveň
jako `zahajeno` / `ukonceno` relace – je to okamžik, kdy se počítadlo
opravdu odečetlo. `image_picker` ale snímek při zmenšení na 1600 px
překomprimuje a EXIF na části zařízení zahodí; v takovém případě se
použije čas, kdy fotoaparát snímek vrátil (`PorizenaFotografie.casZExif`
říká, který z obou to byl). Pokud musí být čas pořízení průkazný,
je potřeba fotit vlastním `camera` pluginem a EXIF si zapisovat sám.

**Fotka jde vzít i z galerie.** Focení přímo v aplikaci je hlavní cesta,
ale když se nepovede (rozbitý fotoaparát, snímek pořízený dřív), dá se
vybrat hotová fotka z telefonu. Nese to dva důsledky, které aplikace
přiznává místo aby je schovala:

* U snímku z galerie je EXIF čas jediný údaj o tom, kdy fotka vznikla –
  může to být před týdnem. Obrazovka focení proto u vybrané fotky ukáže
  datum a čas pořízení, ať uživatel potvrzuje to, co se opravdu zapíše.
  Když EXIF chybí, řekne to rovnou.
* Do metadat se ukládá `zdroj` (`fotoaparat` / `galerie`), protože fotka
  z galerie je slabší doklad – mohla vzniknout kdykoli a kdekoli. Pro
  schvalování mimo aplikaci je to podstatný rozdíl.

**Rekapitulace se zapisuje až tlačítkem „Dokončit".** Do té doby je
relace pořád otevřená a uživatel se může vrátit. Odpovídá to prototypu.

**Odebrání vozidla se potvrzuje dialogem.** Prototyp maže rovnou, ale
akce se nedá vzít zpět a uživatel ji dělá v rukavicích.

**Motiv se nikam neukládá.** Přepínač na domovské obrazovce platí do
konce běhu aplikace, po restartu se aplikace zase řídí systémem – stejně
jako prototyp. Trvalé uložení by znamenalo přidat `shared_preferences`.

## Focení a OCR

Fotoaparát se otevře hned po vstupu na obrazovku focení – uživatel stojí
u nabíječky a nemá důvod ťukat na další tlačítko. Když ho zavře, zůstane
na obrazovce s volbou mezi spouští a galerií; ven vede křížek nahoře.
Po vyfocení se snímek zmenší na 1600 px (kvalita 80), spočítá se SHA-256
přesně těch bajtů, které jdou do Storage, a on-device OCR se pokusí najít
hodnotu.

OCR je **pomůcka, ne autorita**: pole je vždy přepisovatelné a bez
potvrzení tlačítkem se nikam nezapíše. Když se číslo přečíst nepodaří,
ruční zadání je rovnocenná cesta – ne nouzové řešení.

Heuristika výběru čísla ([ocr_sluzba.dart](lib/features/nabijeni/application/ocr_sluzba.dart))
zvýhodňuje čísla na řádku s „kWh", delší čísla a čísla s desetinami.
Je pokrytá testy, takže se dá ladit podle toho, co konkrétní nabíječky
v areálu na displeji ukazují.

## Report do PDF

Nad historií je tlačítko exportu: uživatel zvolí období (zkratky *tento
měsíc* / *minulý měsíc*, nebo vlastní rozsah) a aplikace vyrobí PDF,
které rovnou předá systémovému sdílení – odtud se dá poslat mailem.

Rozvržení je tabulka všech nabíjení se součtem, za ní oddíl s fotkami po
dvojicích začátek/konec. Kdo řeší jen čísla, dál nelistuje.

Report je **snímek k okamžiku vytvoření**, proto jednorázový dotaz, ne
stream. Zahrnuje jen dokončené relace a jen vlastní – security rules
cizí data nepustí, takže hromadný přehled za všechny zaměstnance patří
do webového portálu, ne sem.

Tři věci, které nejsou zřejmé:

**Fotky se pro PDF zmenšují** na 1000 px a kvalitu 70
([zmenseni_fotky.dart](lib/features/reporty/application/zmenseni_fotky.dart)).
V původní velikosti by měsíční report vyšel na 5–12 MB a přes leckterý
mailový server by neprošel; takhle vyjde na 2–3 MB a číslo na displeji
zůstane čitelné. Překódování běží přes `compute()` v jiné izolaci, jinak
by na dvaceti snímcích sekalo UI.

**Font se vkládá do dokumentu.** Vestavěná Helvetica z balíčku `pdf`
neumí háčky ani čárky – „Švihálek" by se vysázel jako „Svihlek". Roboto
v [assets/fonty/](assets/fonty/) je součástí Flutter SDK (Apache 2.0)
a funguje i offline, na rozdíl od stahování z Google Fonts za běhu.

**Horní mez období je exkluzivní.** Uživatel zadává „do" včetně toho dne,
dotaz ale potřebuje půlnoc následujícího – jinak by relace zahájená
poslední den v 7:12 z reportu vypadla.

## Mimo rozsah

Ceny, sazby, výpočet částek, export ISDOC, schvalování. Stav `schvaleno`
umí aplikace jen zobrazit v odznaku – nastavuje se mimo ni.
#   R e n o C h a r g e  
 