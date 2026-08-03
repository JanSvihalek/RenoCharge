// Naplní kolekci `stanice` podle tools/stanice.json.
//
// Kolekce je pro mobilní aplikaci jen ke čtení (viz firestore.rules),
// takže se plní admin SDK, ne z telefonu. Skript je idempotentní –
// dokumenty mají pevná ID, takže opakované spuštění stanice přepíše,
// nezaloží duplicity.
//
// Použití:
//   cd tools && npm install
//   set GOOGLE_APPLICATION_CREDENTIALS=C:\cesta\ke\klici.json
//   node seed_stanice.mjs --project renocharge
//
// Klíč servisního účtu: Firebase konzole → Nastavení projektu →
// Servisní účty → Vygenerovat nový soukromý klíč. Klíč nepatří do gitu.

import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

import { cert, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const KONEKTORY = [
  { id: 'A', nazev: 'Konektor A' },
  { id: 'B', nazev: 'Konektor B' },
];

function argument(nazev) {
  const i = process.argv.indexOf(`--${nazev}`);
  return i === -1 ? undefined : process.argv[i + 1];
}

async function main() {
  const projectId =
    argument('project') ??
    process.env.GOOGLE_CLOUD_PROJECT ??
    process.env.FIREBASE_PROJECT;
  if (!projectId) {
    throw new Error(
      'Chybí ID projektu. Spusťte skript s --project <id-projektu>.',
    );
  }

  const klic = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!klic) {
    throw new Error(
      'Chybí GOOGLE_APPLICATION_CREDENTIALS s cestou ke klíči servisního účtu.',
    );
  }

  // Klíč načítáme sami, ať umíme říct srozumitelně, co je špatně.
  let poverovaciUdaje;
  try {
    poverovaciUdaje = cert(JSON.parse(await readFile(klic, 'utf8')));
  } catch (chyba) {
    throw new Error(
      `Klíč servisního účtu se nepodařilo načíst z "${klic}": ${chyba.message}`,
    );
  }

  initializeApp({ credential: poverovaciUdaje, projectId });
  const db = getFirestore();

  const cesta = join(dirname(fileURLToPath(import.meta.url)), 'stanice.json');
  const stanice = JSON.parse(await readFile(cesta, 'utf8'));
  if (!Array.isArray(stanice) || stanice.length === 0) {
    throw new Error('stanice.json musí obsahovat neprázdné pole stanic.');
  }

  const zapis = db.batch();
  for (const s of stanice) {
    if (!s.id || !s.nazev) {
      throw new Error(
        `Každá stanice potřebuje "id" a "nazev". Chybné: ${JSON.stringify(s)}`,
      );
    }
    zapis.set(
      db.collection('stanice').doc(s.id),
      { nazev: s.nazev, konektory: s.konektory ?? KONEKTORY },
      { merge: true },
    );
  }
  await zapis.commit();

  console.log(
    `Hotovo: ${stanice.length} stanic zapsáno do projektu ${projectId}.`,
  );
}

main().catch((chyba) => {
  console.error(`Chyba: ${chyba.message}`);
  process.exitCode = 1;
});
