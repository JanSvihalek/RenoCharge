# Odečty elektroměrů – zadání

Rozšíření aplikace o evidenci stavů elektroměrů v areálech firmy.
Údržba jednou měsíčně obejde elektroměry, vyfotí displej a zapíše stav.
Čísla slouží ke **kontrole spotřeby**, ne k fakturaci.

Je to **oddělená část aplikace**, ne rozšíření nabíjení. Důvody jsou
v [Proč odděleně](#proč-odděleně).

Rozsah: ~80 elektroměrů, několik poboček, několik údržbářů, odečet
měsíčně. Signál na místech odečtu je podle zadavatele dobrý – elektroměry
nejsou ve sklepích.

## Proč odděleně

**Jiný tvar záznamu.** Nabíjení je dvojice odečtů kolem události: má
životní cyklus (`probiha` → `dokonceno`), spotřeba je rozdíl uvnitř
jednoho dokumentu a účtuje se člověku. Odečet elektroměru je jeden
nezměnitelný snímek zařízení v čase; spotřeba je rozdíl mezi dvěma **po
sobě jdoucími** odečty téhož elektroměru. Ve společné kolekci by vzniklo
pole `typ` a polovina polí prázdná na každé straně.

**Jiná viditelnost.** Nabíjení je osobní údaj zaměstnance, dnes čitelný
jen jím (`uid == ja()`). Odečty jsou firemní fakt – kdo jde na obchůzku
příští měsíc, musí vidět minulý odečet, jinak nepozná, jestli je hotová,
ani neověří, že nová hodnota není nižší. To se v jedné kolekci s jedněmi
pravidly udělat nedá.

## Role

Aplikace poprvé dostane pojem role. Nese ji **pole `role` na profilu**,
které si uživatel **nesmí sám změnit** – pravidla vynutí, že při úpravě
profilu zůstává stejné. Nastavuje ho správce v konzoli, stejně jako dnes
zakládá účty. Chybějící `role` znamená běžného zaměstnance.

| Role | Smí |
|---|---|
| *(chybí)* | jen nabíjení jako dosud; záložka Elektroměry se nezobrazí |
| `udrzba` | zakládat a upravovat elektroměry, zapisovat odečty |

Custom claims by byly čistší, ale nastavují se jen přes Admin SDK –
tedy servisní účet a skript, což zadavatel odmítl hned na začátku.

**Čtení** elektroměrů i odečtů je povolené všem přihlášeným. Není to
osobní údaj a jednodušší pravidla znamenají míň míst, kde udělat chybu.

## Datový model

```
uzivatele/{uid}                … stávající pole +
                               role?: 'udrzba'          ← mění jen správce

pobocky/{id}                   nazev, poradi
                               spravuje správce, klient jen čte

elektromery/{id}               pobocka_id, cislo, nazev,
                               aktivni: bool,
                               foto_zarizeni?: {path, sha256, porizeno_at, zdroj},
                               posledni_odecet?: {hodnota, odecteno_at, odecet_id},
                               vytvoreno_at, vytvoril_uid, aktualizovano_at

odecty/{id}                    elektromer_id, pobocka_id, uid,
                               hodnota, odecteno_at,
                               foto: {path, sha256, porizeno_at, zdroj},
                               predchozi_hodnota?,
                               vymena_meridla: bool,
                               poznamka?,
                               vytvoreno_at
```

**`cislo`** je výrobní číslo ze štítku, **`nazev`** je kde elektroměr je
(*„Hala B – rozvaděč R3"*). Podle obojího se v seznamu vyhledává.

**`pobocka_id` je v odečtu zkopírované** schválně. Bez toho by dotaz
„odečty téhle pobočky za srpen" musel nejdřív načíst všechny elektroměry
pobočky a pak se ptát na odečty po dávkách.

**`posledni_odecet` na elektroměru** je denormalizace stejného druhu jako
`aktivni_nabijeni_id` na profilu. Bez ní by obrazovka seznamu musela
udělat osmdesát dotazů na poslední odečet. Zapisuje se **v téže
transakci** jako odečet.

**Spotřeba se neukládá.** Dopočítává se z řady odečtů (za rok je to
~1000 dokumentů, seřadit se to dá v telefonu). Uložená hodnota by
zastarala, kdyby se někdy doplňoval chybějící starší odečet.
`predchozi_hodnota` se ale ukládá – je to snímek toho, co člověk v tu
chvíli viděl, a slouží k auditu, ne k výpočtu.

**Odečty jsou nezměnitelné**, stejně jako nabíjení. Oprava se dělá novým
odečtem, ne přepsáním. Vyřazený elektroměr se označí `aktivni: false`,
nemaže se – historie musí zůstat čitelná.

### Indexy

```
elektromery   pobocka_id ASC,   nazev ASC
odecty        elektromer_id ASC, odecteno_at DESC
odecty        pobocka_id ASC,    odecteno_at DESC
```

## Obrazovky

Nová záložka **Elektroměry**, viditelná jen pro roli `udrzba`. Běžný
zaměstnanec má tab bar jako dnes (Domů, Historie, Nastavení).

### 1. Seznam elektroměrů

Tahle obrazovka **je zároveň obchůzka**. Žádná entita „obchůzka"
nevzniká – hotovost se dopočítá z `posledni_odecet`, takže se nemůže
rozejít se skutečností.

```
┌ Elektroměry ────────────────────────────────┐
│ Pobočka:  [ Brno – Slatina  ▾ ]             │
│ Srpen 2026 — hotovo 23 z 31                 │
│ [ 🔍 hledat podle čísla nebo umístění    ]  │
│                                             │
│ ZBÝVÁ                                       │
│ ┌─────────────────────────────────────────┐ │
│ │ Kotelna – hlavní              ⚠ chybí   │ │
│ │ č. 18 342 802                           │ │
│ │ naposledy 112 003,40 kWh · 2. 7.   [📷] │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ HOTOVO                                      │
│ ┌─────────────────────────────────────────┐ │
│ │ Hala B – rozvaděč R3          ✓ srpen   │ │
│ │ č. 18 342 771                           │ │
│ │ 118 484,81 kWh · 4. 8.  (+2,3 % k VII.) │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│              [ + Přidat elektroměr ]        │
└─────────────────────────────────────────────┘
```

* Výběr pobočky si pamatuje poslední volbu.
* **Vyhledávání je podmínka, ne vylepšení.** Při osmdesáti kusech se bez
  něj seznam používat nedá.
* Tlačítko fotoaparátu na řádku pustí focení **rovnou ze seznamu** a po
  uložení se zůstane v seznamu. Bez toho vychází na jeden elektroměr
  čtyři klepnutí, krát jedenatřicet.
* **Přidání elektroměru patří sem**, ne do nastavení – první měsíc bude
  celý o tom, že se seznam teprve staví.

### 2. Detail elektroměru

Otevře se klepnutím na řádek. Obsahuje:

* identifikační fotku zařízení a jeho umístění (kde ho příště hledat),
  číslo, pobočku,
* historii odečtů od nejnovějšího, s dopočítanou spotřebou mezi nimi
  a změnou proti předchozímu měsíci,
* tlačítko *Přidat odečet*,
* úpravu názvu a čísla, vyřazení elektroměru.

Klepnutím na fotku u odečtu se otevře přes celou obrazovku – stejný
prohlížeč, jaký má nabíjení.

### 3. Přidání odečtu

Použije **beze změny stávající tok focení**: fotoaparát se otevře hned,
OCR předvyplní hodnotu, pole je vždy přepisovatelné, jde vzít fotku
z galerie. Nad polem se ukáže minulý stav, ať má člověk s čím porovnat.

Kontroly před uložením:

* hodnota musí být vyšší než `posledni_odecet.hodnota`, jinak aplikace
  odmítne uložit a nabídne zaškrtnout **výměnu měřidla** – tím se
  přizná, že počítadlo začalo od nuly,
* volitelná poznámka.

Zápis probíhá **transakcí**: přečti elektroměr, ověř hodnotu, zapiš odečet
a aktualizuj `posledni_odecet`. Ne dávkou – dva lidé u jednoho
elektroměru současně by si jinak přepsali poslední odečet.

### 4. Přidání a úprava elektroměru

Pobočka, číslo, název, identifikační fotka. Číslo musí být v rámci
pobočky jedinečné; kontroluje se dotazem před zápisem, ne pravidlem –
pravidla to bez další pomocné evidence neumí a duplicita tu není
bezpečnostní problém, jen nepořádek.

## Pravidla

### Firestore

```
function role() {
  return prihlasen()
    ? get(/databases/$(database)/documents/uzivatele/$(ja())).data.get('role', '')
    : '';
}
function jeUdrzba() { return role() == 'udrzba'; }

match /pobocky/{id} {
  allow read: if prihlasen();
  allow write: if false;                    // správce v konzoli
}

match /elektromery/{id} {
  allow read: if prihlasen();
  allow create, update: if jeUdrzba() && tvarElektromeru();
  allow delete: if false;                   // vyřazení = aktivni: false
}

match /odecty/{id} {
  allow read: if prihlasen();
  allow create: if jeUdrzba() && tvarOdectu()
                && nova().uid == ja()
                && platnaFoto(nova().foto)
                && (nova().vymena_meridla == true
                    || nova().hodnota > predchoziHodnota(nova().elektromer_id));
  allow update, delete: if false;
}
```

U profilu přibude `role` mezi povolená pole a podmínka, že se **při
úpravě nemění** – včetně případu, kdy chybí v obou verzích:

```
function roleNezmenena() {
  return nova().keys().hasAny(['role']) == stara().keys().hasAny(['role'])
    && (!nova().keys().hasAny(['role']) || nova().role == stara().role);
}
```

Při zakládání profilu aplikací nesmí být `role` přítomná vůbec – přidá
ji jen správce v konzoli, kde pravidla neplatí.

`get()` v pravidlech stojí jedno čtení navíc na každý zápis. Při
osmdesáti odečtech měsíčně je to zanedbatelné.

### Storage

**Pozor na past, na kterou už jsme jednou narazili:** Storage pravidla
**nemůžou ověřit roli**, protože by se musela ptát Firestore, a takové
cross-service volání vyžaduje zvláštní IAM oprávnění, které nenasadí
`firebase deploy` a dá se tiše odebrat. Kvůli tomu nešly nahrát fotky
u nabíjení a museli jsme přepsat cesty.

Proto stejný vzorec jako u nabíjení – **vlastník je součástí cesty**:

```
odecty/{uid}/{odecetId}.jpg
elektromery/{uid}/{elektromerId}.jpg

allow read:   if prihlasen();          // odečty vidí celá firma
allow create: if prihlasen() && uid == ja() && platnyObrazek();
allow update: if false;                // jednou nahraná fotka je neměnná
allow delete: if false;
```

Segment `{uid}` znamená „kdo nahrál", ne „čí to je". Zápis tak smí kdokoli
přihlášený; **roli hlídá až Firestore při zakládání odečtu.** Když si
někdo nahraje fotku a záznam k ní nevznikne, zůstane osiřelý soubor za
pár set kB – stejně jako dnes u nabíjení.

## Co se sdílí s nabíjením

Beze změny: celé `common/` (motiv, formátování, chyby, widgety),
`FotoSluzba` (fotoaparát i galerie, SHA-256, EXIF čas, zdroj snímku),
`OcrSluzba`, `ProhlizecFotky` a strojovna PDF.

**Zobecnit je potřeba jedinou věc:** `FotoUloziste` má cestu natvrdo
`nabijeni/{uid}/{relaceId}/{start|end}.jpg` a `TypFoto` zná jen
`start`/`end`. Odečet je jediná fotka a leží jinde. Z prefixu i názvu
souboru se musí stát parametr.

Struktura: `lib/features/elektromery/` vedle `nabijeni/`, uvnitř
`domain` / `data` / `application` / `presentation` jako všude jinde.

## Report

Za pobočku a měsíc: tabulka *elektroměr · minulý stav · nový stav ·
spotřeba · změna proti minulému měsíci v %*, a seznam elektroměrů, které
za období odečet nemají.

Na kontrolu spotřeby je klíčová právě **ta změna v procentech** – skokový
nárůst je ten signál, kvůli kterému se to celé čte.

Vedle PDF **i CSV**. Kdo hlídá spotřebu, bude chtít data do Excelu; je to
pár řádků kódu a posílá se stejnou cestou jako PDF.

## Mimo rozsah

Ceny a fakturace odečtů. Fronta nahrávání pro práci offline – signál je
podle zadavatele dobrý a fronta by rozbila záruku „fotka je ve Storage
dřív než záznam", na které stojí důvěryhodnost dat. Automatické
vyhodnocování odchylek nad rámec zobrazení změny v procentech. Správa
poboček a rolí v aplikaci; obojí dělá správce v konzoli.

## Postup

1. Role na profilu, pravidla a skrytí záložky – nejmenší krok, po kterém
   jde ověřit, že běžný zaměstnanec nic nového nevidí.
2. Pobočky a elektroměry: seznam, přidání, detail. Bez odečtů.
3. Odečty: focení, zápis transakcí, historie v detailu.
4. Report a CSV.

**Pilot na jedné pobočce.** První měsíc je stejně o stavbě seznamu –
vyladit to tam, kam se dá dojít pro zpětnou vazbu, a teprve pak pustit
dál.

## Otevřené

* **Název aplikace.** RenoCharge s bleskem v ikoně přestane sedět, až
  v ní budou i elektroměry. Není to blokující, ale je lepší to rozhodnout
  dřív, než aplikaci dostane víc lidí.
* **Kdo zakládá pobočky** – zatím se počítá se správcem v konzoli.
  Pokud jich má přibývat, patří to do aplikace pod roli.
