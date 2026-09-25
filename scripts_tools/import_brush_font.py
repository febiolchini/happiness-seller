"""Ricava il font a pennello del gioco da una foto di un alfabeto scritto a mano.

La sorgente e' `assets/sprites/ui/_source/alfabeto_pennello.jpeg`: le ventisei
maiuscole scritte a pennello nero su carta bianca, in quattro righe
(ABCDEF / GHIJKLM / NOPQRST / UVWXYZ). Da li' esce un font bitmap BMFont che
Godot importa come qualunque altro `.fnt`:

  assets/sprites/ui/brush.png   l'atlante dei glifi
  assets/sprites/ui/brush.fnt   le coordinate, in formato BMFont testo

## Come si separano le lettere

Si cerca lo scuro (sotto `SOGLIA`) a meta' risoluzione e se ne prendono i pezzi
connessi. I pezzi grossi sono le lettere: devono essere esattamente ventisei, e
lo script si ferma se non lo sono — vuol dire che due lettere di righe vicine
si toccano, o che una si e' spezzata in due. **Niente dilatazione**: allargando
lo scuro per ricucire le setole del pennello, la gamba della F finiva attaccata
alla M sotto, la G alla N e cosi' via. Le setole staccate (i pezzi piccoli) si
riattaccano dopo, ciascuna alla lettera piu' vicina.

Le lettere si ordinano per riga (le righe sono i gruppi di centri distanti
meno di `SALTO_RIGA` in verticale) e dentro alla riga da sinistra a destra.

## Come si tiene la scrittura a mano, restando leggibile

Nella foto la seconda e la terza riga sono scritte un po' piu' piccole e piu'
in basso della prima. Prese cosi' com'erano, in una parola le loro lettere
sembravano minuscole in mezzo a maiuscole ("cONtINua"). Quindi due correzioni,
tutte e due **a meta'**, per non far sembrare il font stampato:

- l'altezza: ogni lettera si avvicina all'altezza tipica di `NORMALIZZA` (0 =
  com'e' scritta, 1 = tutte uguali); una F scritta alta resta un po' piu' alta;
- la riga: ogni lettera poggia sulla base, e del suo su e giu' rispetto alla
  riga in cui e' scritta ne tiene al massimo `ONDEGGIA` pixel.

## Come si legge sopra alla citta'

Il pennello e' nero su bianco, e i menu stanno sopra alla citta' di notte. Il
glifo esce **bianco** — cosi' il colore lo decide il gioco con `font_color`, il
giallo dell'hover compreso — con un'**ombra scura cotta dentro** sotto e a
destra, come quella di `alphabet.fnt`. Moltiplicata per il colore del testo
l'ombra resta scura, quindi l'hover colora la lettera e non l'ombra.

## Minuscole e il resto

L'alfabeto ha solo maiuscole. Le minuscole puntano agli stessi glifi: le voci
dei menu sono scritte in minuscolo in `strings.gd` ("nuova partita") e a
pennello escono maiuscole. Cifre e punteggiatura non ci sono, come in
`alphabet.fnt`: e' la regola PIXEL di `strings.gd`, che un controllo verifica.

Uso:
  python scripts_tools/import_brush_font.py
"""

import os
from collections import deque

import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
UI = os.path.join(HERE, os.pardir, "assets", "sprites", "ui")
SOURCE = os.path.join(UI, "_source", "alfabeto_pennello.jpeg")

LETTERE = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
# Quello che e' piu' scuro di cosi' e' inchiostro.
SOGLIA = 150
# In cima alla foto c'e' una sbavatura grigia che non e' una lettera.
MARGINE_ALTO = 70
# Un pezzo con meno pixel di cosi' (a meta' risoluzione) e' una setola staccata,
# non una lettera.
MIN_LETTERA = 300
# Anche questo a meta' risoluzione: le righe distano un centinaio di pixel.
SALTO_RIGA = 60

# Le misure del font, in pixel dell'atlante. `ALTEZZA` e' l'altezza tipica di
# una lettera; la riga e la base lasciano spazio a quello che scende sotto (la
# Y) e sale sopra, e all'ombra.
ALTEZZA = 40
RIGA = 56
BASE = 46
NORMALIZZA = 0.75
ONDEGGIA = 2
# L'ombra: quanto e' spostata e quanto e' scura.
OMBRA = (2, 3)
OMBRA_ALPHA = 0.85
# Spazio fra una lettera e l'altra, e la larghezza dello spazio.
INTERLETTERA = 1
SPAZIO = 16


def componenti(scuro):
    """I pezzi connessi (8-vicini) di una maschera: etichette e per ciascuno
    riquadro e numero di pixel. A mano e non con scipy, che qui non c'e': a
    meta' risoluzione sono pochi secondi."""
    h, w = scuro.shape
    lab = np.zeros((h, w), np.int32)
    pezzi = []
    for y in range(h):
        riga = scuro[y]
        for x in np.flatnonzero(riga):
            if lab[y, x]:
                continue
            n = len(pezzi) + 1
            lab[y, x] = n
            coda = deque([(y, x)])
            y0 = y1 = y
            x0 = x1 = x
            conta = 0
            while coda:
                cy, cx = coda.popleft()
                conta += 1
                y0, y1 = min(y0, cy), max(y1, cy)
                x0, x1 = min(x0, cx), max(x1, cx)
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < h and 0 <= nx < w and scuro[ny, nx] and not lab[ny, nx]:
                            lab[ny, nx] = n
                            coda.append((ny, nx))
            pezzi.append({"id": n, "box": (x0, y0, x1 + 1, y1 + 1), "pixel": conta})
    return lab, pezzi


def centro(box):
    return ((box[0] + box[2]) / 2.0, (box[1] + box[3]) / 2.0)


def separa():
    foto = Image.open(SOURCE).convert("L")
    grigio = np.asarray(foto, dtype=np.float32)
    meta = foto.resize((foto.width // 2, foto.height // 2), Image.BOX)
    scuro = np.asarray(meta) < SOGLIA
    scuro[: MARGINE_ALTO // 2, :] = False
    lab, pezzi = componenti(scuro)

    grossi = [p for p in pezzi if p["pixel"] >= MIN_LETTERA]
    if len(grossi) != len(LETTERE):
        raise SystemExit("trovate %d lettere invece di %d: controlla SOGLIA e MIN_LETTERA"
                         % (len(grossi), len(LETTERE)))
    # Le righe: gruppi di centri vicini in verticale, poi da sinistra a destra.
    grossi.sort(key=lambda p: centro(p["box"])[1])
    righe, corrente = [], [grossi[0]]
    for p in grossi[1:]:
        if centro(p["box"])[1] - centro(corrente[-1]["box"])[1] > SALTO_RIGA:
            righe.append(corrente)
            corrente = []
        corrente.append(p)
    righe.append(corrente)
    ordinati = []
    for r, riga in enumerate(righe):
        for p in sorted(riga, key=lambda p: p["box"][0]):
            p["riga"] = r
            ordinati.append(p)

    # Le setole staccate alla lettera piu' vicina, se ci stanno accanto.
    gruppi = {p["id"]: [p["id"]] for p in ordinati}
    for p in pezzi:
        if p["pixel"] >= MIN_LETTERA:
            continue
        cx, cy = centro(p["box"])
        vicina, meglio = None, 1e9
        for g in ordinati:
            x0, y0, x1, y1 = g["box"]
            dx = max(x0 - cx, 0, cx - x1)
            dy = max(y0 - cy, 0, cy - y1)
            d = (dx * dx + dy * dy) ** 0.5
            if d < meglio:
                vicina, meglio = g, d
        if meglio < 12:
            gruppi[vicina["id"]].append(p["id"])

    # La maschera di ogni lettera a piena risoluzione, allargata di un pixel per
    # tenere le sfumature del bordo delle setole.
    lettere = []
    for p, lettera in zip(ordinati, LETTERE):
        mask_meta = np.isin(lab, gruppi[p["id"]])
        mask = np.asarray(Image.fromarray((mask_meta * 255).astype(np.uint8)).resize(
            (foto.width, foto.height), Image.NEAREST)) > 0
        mask = np.asarray(Image.fromarray((mask * 255).astype(np.uint8)).filter(
            ImageFilter.MaxFilter(5))) > 0
        ys, xs = np.nonzero(mask)
        x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
        inchiostro = np.clip((215.0 - grigio[y0:y1, x0:x1]) / 165.0, 0.0, 1.0)
        inchiostro *= mask[y0:y1, x0:x1]
        lettere.append({"lettera": lettera, "riga": p["riga"], "box": (x0, y0, x1, y1),
                        "alpha": inchiostro})
    return lettere


def riduci(alpha, larghezza, altezza):
    """Rimpicciolisce l'inchiostro. E' un canale solo, quindi non serve la
    premoltiplicazione di `import_flats_art.py`: basta un buon filtro."""
    im = Image.fromarray((alpha * 255).round().astype(np.uint8))
    return np.asarray(im.resize((max(1, larghezza), max(1, altezza)), Image.LANCZOS),
                      dtype=np.float32) / 255.0


def glifo(alpha, con_ombra=True):
    """Bianco con l'ombra scura sotto: RGBA, allargato di quanto sposta l'ombra.
    Senza ombra e' solo la lettera bianca, per la versione delle finestre."""
    h, w = alpha.shape
    ox, oy = OMBRA if con_ombra else (0, 0)
    tela = np.zeros((h + oy, w + ox, 4), np.float32)
    # L'ombra: nera, spostata, un filo sfumata per non sembrare un doppione.
    ombra = np.zeros((h + oy, w + ox), np.float32)
    ombra[oy:, ox:] = alpha
    ombra = np.asarray(Image.fromarray((ombra * 255).astype(np.uint8)).filter(
        ImageFilter.GaussianBlur(0.6)), dtype=np.float32) / 255.0 * OMBRA_ALPHA
    if not con_ombra:
        ombra[:] = 0.0
    # Sopra, la lettera bianca: "over" di bianco su nero.
    lettera = np.zeros((h + oy, w + ox), np.float32)
    lettera[:h, :w] = alpha
    a = lettera + ombra * (1.0 - lettera)
    colore = np.divide(lettera, a, out=np.zeros_like(a), where=a > 0)
    for c in range(3):
        tela[:, :, c] = colore
    tela[:, :, 3] = a
    return Image.fromarray((np.clip(tela, 0, 1) * 255).round().astype(np.uint8), "RGBA")


def main():
    lettere = separa()
    altezze = sorted(l["box"][3] - l["box"][1] for l in lettere)
    tipica = altezze[len(altezze) // 2]
    scala = ALTEZZA / tipica
    # La base di ogni riga, sulla foto: la mediana dei piedi delle sue lettere.
    basi = {}
    for r in sorted({l["riga"] for l in lettere}):
        piedi = sorted(l["box"][3] for l in lettere if l["riga"] == r)
        basi[r] = piedi[len(piedi) // 2]

    ridotte = []
    for l in lettere:
        x0, y0, x1, y1 = l["box"]
        # Il fattore di questa lettera: quello comune, corretto verso l'altezza
        # tipica di `NORMALIZZA`.
        s = scala * (tipica / float(y1 - y0)) ** NORMALIZZA
        w = int(round((x1 - x0) * s))
        h = int(round((y1 - y0) * s))
        # Poggia sulla base, col suo scarto dalla riga limitato a `ONDEGGIA`.
        scarto = int(round((y1 - basi[l["riga"]]) * scala))
        scarto = max(-ONDEGGIA, min(ONDEGGIA, scarto))
        ridotte.append({"lettera": l["lettera"], "alpha": riduci(l["alpha"], w, h),
                        "yoffset": BASE - h + scarto, "larghezza": w})

    # Due font dallo stesso alfabeto: `brush` con l'ombra, per i menu sopra
    # alla citta'; `brush_ink` senza, per le finestre di carta chiara, dove la
    # lettera si scrive scura e un'ombra scura sotto la farebbe sembrare
    # sbavata.
    scrivi("brush", ridotte, True)
    scrivi("brush_ink", ridotte, False)
    print("scala %.3f" % scala)


def scrivi(nome, ridotte, con_ombra):
    glifi = [dict(r, img=glifo(r["alpha"], con_ombra)) for r in ridotte]

    # L'atlante: tutti in fila, con due pixel vuoti fra uno e l'altro perche'
    # il filtro lineare non si porti dietro il bordo del vicino.
    larghezza = sum(g["img"].width + 2 for g in glifi)
    altezza = max(g["img"].height for g in glifi)
    atlante = Image.new("RGBA", (larghezza, altezza), (0, 0, 0, 0))
    x = 0
    righe_fnt = []
    for g in glifi:
        atlante.paste(g["img"], (x, 0))
        for codice in (ord(g["lettera"]), ord(g["lettera"].lower())):
            righe_fnt.append(
                "char id=%d x=%d y=0 width=%d height=%d xoffset=0 yoffset=%d xadvance=%d page=0 chnl=15"
                % (codice, x, g["img"].width, g["img"].height, g["yoffset"],
                   g["larghezza"] + INTERLETTERA))
        x += g["img"].width + 2
    atlante.save(os.path.join(UI, nome + ".png"))

    testa = [
        'info face="%s" size=%d bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=1 aa=1 '
        'padding=0,0,0,0 spacing=1,1' % (nome, RIGA),
        "common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0"
        % (RIGA, BASE, larghezza, altezza),
        'page id=0 file="%s.png"' % nome,
        "chars count=%d" % (len(righe_fnt) + 1),
        "char id=32 x=0 y=0 width=0 height=0 xoffset=0 yoffset=0 xadvance=%d page=0 chnl=15" % SPAZIO,
    ]
    with open(os.path.join(UI, nome + ".fnt"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(testa + righe_fnt) + "\n")
    print("%s: %d lettere, atlante %dx%d" % (nome, len(glifi), larghezza, altezza))


if __name__ == "__main__":
    main()
