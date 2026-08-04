"""Z dodané ikony (zaoblený čtverec s průhlednými rohy) vyrobí tři zdroje,
které flutter_launcher_icons potřebuje:

  ikona.png          plný čtverec bez průhlednosti  (iOS + starší Android)
  ikona_pozadi.png   jen gradient přes celé plátno   (adaptivní pozadí)
  ikona_popredi.png  jen blesk na průhledném plátně  (adaptivní popředí)

Rohy se nedají prostě zaplnit bílou – iOS si tvar zaobluje sám a předloha
je zaoblená víc (23,6 % proti ~22,4 %), takže by u rohů vykoukly světlé
cípy. Gradient je lineární ve směru úhlopříčky, proto se dá proložit
a dopočítat i pro rohy, kde v předloze nic není.
"""

import sys

import numpy as np
from PIL import Image

sys.stdout.reconfigure(encoding="utf-8")

ZDROJ = "assets/ikona/app-icon-1024.png"
im = Image.open(ZDROJ).convert("RGBA")
w, h = im.size
data = np.asarray(im).astype(np.float64)
rgb, alfa = data[..., :3], data[..., 3]

yy, xx = np.mgrid[0:h, 0:w]
uhlopricka = (xx + yy).astype(np.float64)

# Vzorky pro proložení: jen neprůhledné pixely pozadí. Prahem na jasu se
# blesk odfiltruje jen zhruba – jeho vyhlazený okraj přechází do modré přes
# desítky odstínů a proložení by roztáhl. Proto se po prvním proložení
# zahodí, co se od něj liší o víc než 3/255, a proloží se znovu.
vzorky = (alfa > 250) & (rgb.sum(axis=2) > 200)

gradient = np.zeros((h, w, 3))
for k in range(3):
    beru = vzorky.copy()
    for _ in range(3):
        t = uhlopricka[beru]
        A = np.stack([t, np.ones_like(t)], axis=1)
        koef = np.linalg.lstsq(A, rgb[..., k][beru], rcond=None)[0]
        zbytek = np.abs(A @ koef - rgb[..., k][beru])
        if zbytek.max() <= 3:
            break
        beru[beru] = zbytek <= 3
    print(
        f"  kanal {k}: max odchylka {zbytek.max():.1f}/255 "
        f"na {beru.sum() / vzorky.sum():.0%} vzorku"
    )
    gradient[..., k] = koef[0] * uhlopricka + koef[1]
gradient = gradient.clip(0, 255)

# Předlohu položíme na dopočítaný gradient – uvnitř tvaru se nic nezmění,
# rohy se doplní barvou, která tam podle gradientu patří.
a = (alfa / 255.0)[..., None]
plny = (rgb * a + gradient * (1 - a)).round().astype(np.uint8)
Image.fromarray(plny, "RGB").save("assets/ikona/ikona.png")
Image.fromarray(gradient.round().astype(np.uint8), "RGB").save(
    "assets/ikona/ikona_pozadi.png"
)

# Popředí: blesk vyříznutý podle alfy tmavých pixelů, zvětšený a vystředěný.
# Adaptivní ikona zaručeně ukáže jen prostřední kruh o průměru 66/108 plátna,
# takže se blesk musí vejít do ~61 % – cílíme na 55 % s rezervou.
tma = ((alfa > 200) & (rgb.sum(axis=2) < 200)).astype(np.uint8) * 255
maska = Image.fromarray(tma, "L")
x0, y0, x1, y1 = maska.getbbox()
blesk = Image.new("RGBA", (x1 - x0, y1 - y0), (0, 0, 0, 0))
blesk.putalpha(maska.crop((x0, y0, x1, y1)))

meritko = (h * 0.55) / (y1 - y0)
nova = (round((x1 - x0) * meritko), round((y1 - y0) * meritko))
blesk = blesk.resize(nova, Image.LANCZOS)

popredi = Image.new("RGBA", (w, h), (0, 0, 0, 0))
popredi.paste(blesk, ((w - nova[0]) // 2, (h - nova[1]) // 2), blesk)
popredi.save("assets/ikona/ikona_popredi.png")

print(f"  blesk {x1 - x0}x{y1 - y0} -> {nova[0]}x{nova[1]}, tj. 55 % vysky")
print("  hotovo: ikona.png, ikona_pozadi.png, ikona_popredi.png")

# Kontroly: uvnitř tvaru se nesmělo nic změnit a na hranici, kde předloha
# končila, nesmí být skok – jinak by byl doplněný roh vidět jako šev.
k = np.asarray(Image.open("assets/ikona/ikona.png")).astype(np.int16)
uvnitr = alfa > 250
print(f"  zmena uvnitr tvaru: max {np.abs(k - rgb)[uvnitr].max():.0f}/255")

sev = 0.0
for y in range(h):
    for x in range(1, w):
        if alfa[y, x - 1] < 5 <= alfa[y, x]:  # prvni pixel predlohy v radku
            sev = max(sev, np.abs(k[y, x] - k[y, x - 1]).max())
            break
print(f"  skok na hranici doplnene casti: max {sev:.0f}/255")
print(f"  rohy: {tuple(k[0, 0])} .. {tuple(k[h - 1, w - 1])}")
