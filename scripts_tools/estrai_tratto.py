"""Stacca un disegno a tratto dal suo foglio, tenendo il bianco DI DENTRO.

Un disegno a penna arriva come un rettangolo bianco con sopra delle righe nere.
Messo in citta' cosi' com'e' e' una cartolina appoggiata sulla strada: quello
che serve e' la sagoma del soggetto, con dentro il suo bianco — la casa e'
bianca, non trasparente — e fuori il niente.

**Non si puo' fare a soglia.** "Tutto il bianco diventa trasparente" cancella
anche il bianco tra le assi e dentro alle finestre, e resta un intrico di righe
nere attraverso cui si vede la strada. La differenza tra il bianco di dentro e
quello di fuori non e' il colore: e' che quello di fuori tocca il bordo del
foglio. Quindi si allaga il foglio partendo dai bordi e ci si ferma sulle
righe: quello che l'acqua raggiunge e' sfondo, tutto il resto e' disegno.

**Il contorno di uno schizzo non e' chiuso.** Le assi di una parete che va in
fuga si fermano dove finisce il foglio, il terreno sotto al portico e' quattro
righe sparse: da li' l'acqua entra e si mangia meta' casa. Per questo si
possono passare delle DIGHE — segmenti che fanno da barriera all'allagamento e
basta, senza comparire nel disegno. Sono l'unica cosa che va decisa a mano, ed
e' giusto cosi': dove finisce il soggetto e dove finisce il foglio lo sa solo
chi guarda il disegno.

**Le righe vanno ingrossate prima di allagare.** Un tratto a penna ha dei
buchi — dove la mano ha alzato la punta, dove il JPEG ha schiarito un pixel —
e l'allagamento ci passa attraverso e si mangia l'interno. Si ingrossano di
qualche pixel per turare i buchi, si allaga, e poi si restituisce alla sagoma
quello che l'ingrossamento le aveva tolto: l'alone si toglie riportando lo
sfondo indietro dello stesso numero di passi, senza mai intaccare le righe
vere.

Uso:
  python scripts_tools/estrai_tratto.py <sorgente> <destinazione> [soglia] [turaggio]
"""

import os
import sys
from collections import deque

import numpy as np
from PIL import Image

# Sotto questo grigio un pixel e' tratto. Alto di proposito: un tratto a matita
# scansionato arriva grigio, e con una soglia stretta resta pieno di buchi.
SOGLIA = 190
# Di quanti pixel si ingrossano le righe per turare i buchi del tratto.
TURAGGIO = 3


def _dilata(mask, passi):
    """Ingrossa una maschera booleana di `passi` pixel, in croce."""
    out = mask.copy()
    for _ in range(passi):
        d = out.copy()
        d[1:, :] |= out[:-1, :]
        d[:-1, :] |= out[1:, :]
        d[:, 1:] |= out[:, :-1]
        d[:, :-1] |= out[:, 1:]
        out = d
    return out


def _allaga(passabile):
    """Segna tutto quello che si raggiunge dai bordi camminando sui passabili.

    A scanline e non un pixel per volta: su un foglio da un milione e mezzo di
    pixel una coda di pixel singoli ci mette dei minuti, per riga intera meno
    di un secondo.
    """
    h, w = passabile.shape
    visto = np.zeros((h, w), dtype=bool)
    coda = deque()
    for x in range(w):
        for y in (0, h - 1):
            if passabile[y, x] and not visto[y, x]:
                visto[y, x] = True
                coda.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if passabile[y, x] and not visto[y, x]:
                visto[y, x] = True
                coda.append((y, x))
    while coda:
        y, x = coda.popleft()
        # si allarga la riga a destra e a sinistra fin dove si passa
        sx = x
        while sx > 0 and passabile[y, sx - 1] and not visto[y, sx - 1]:
            sx -= 1
            visto[y, sx] = True
        dx = x
        while dx < w - 1 and passabile[y, dx + 1] and not visto[y, dx + 1]:
            dx += 1
            visto[y, dx] = True
        for ny in (y - 1, y + 1):
            if 0 <= ny < h:
                riga_p = passabile[ny, sx:dx + 1]
                riga_v = visto[ny, sx:dx + 1]
                nuovi = np.flatnonzero(riga_p & ~riga_v)
                for i in nuovi:
                    visto[ny, sx + i] = True
                    coda.append((ny, sx + i))
    return visto


def _dighe(forma, segmenti, spessore=5):
    """Le barriere disegnate a mano, come maschera booleana.

    Non finiscono nel PNG: servono solo a fermare l'acqua. Dove passa una diga
    il disegno si chiude con un bordo netto, che e' quello che si vuole sul
    lato in cui il foglio taglia il soggetto.
    """
    from PIL import ImageDraw
    tela = Image.new("L", (forma[1], forma[0]), 0)
    dis = ImageDraw.Draw(tela)
    for (x0, y0, x1, y1) in segmenti:
        dis.line([(x0, y0), (x1, y1)], fill=255, width=spessore)
    return np.asarray(tela) > 0


def _sigillo(tratto, lati):
    """Chiude la sagoma sui lati indicati seguendo il tratto piu' esterno.

    Meglio che dare le coordinate a mano: la diga non e' un segmento dritto ma
    una spezzata che sta ADDOSSO al disegno — riga per riga passa per il pixel
    di inchiostro piu' a destra, colonna per colonna per quello piu' in basso.
    Con un segmento dritto, fra la parete che va in fuga e la diga resterebbe
    un cuneo chiuso, e un cuneo chiuso l'acqua non lo raggiunge: verrebbe
    fuori bianco pieno attaccato alla casa.

    I punti vanno COLLEGATI. Il pixel piu' esterno di una riga e' inchiostro
    per definizione, quindi una diga fatta di punti isolati non aggiunge
    niente: quello che tura i vuoti e' il tratto di spezzata fra il punto di
    una riga e quello della riga dopo, cioe' esattamente il pezzo di contorno
    che il disegno non ha.
    """
    from PIL import ImageDraw
    h, w = tratto.shape
    tela = Image.new("L", (w, h), 0)
    dis = ImageDraw.Draw(tela)

    def spezzata(punti):
        if len(punti) > 1:
            dis.line(punti, fill=255, width=2)

    if "destra" in lati or "sinistra" in lati:
        a, b = [], []
        for y in range(h):
            xs = np.flatnonzero(tratto[y])
            if xs.size:
                a.append((int(xs[-1]), y))
                b.append((int(xs[0]), y))
        if "destra" in lati:
            spezzata(a)
        if "sinistra" in lati:
            spezzata(b)
    if "sotto" in lati or "sopra" in lati:
        a, b = [], []
        for x in range(w):
            ys = np.flatnonzero(tratto[:, x])
            if ys.size:
                a.append((x, int(ys[-1])))
                b.append((x, int(ys[0])))
        if "sotto" in lati:
            spezzata(a)
        if "sopra" in lati:
            spezzata(b)
    return np.asarray(tela) > 0


def _luci(dimensioni, finestre, destinazione):
    """Lo scatto delle finestre accese, per un disegno che non ne ha uno.

    Gli edifici costruiti in Blender il secondo PNG ce l'hanno gratis — stessa
    camera, solo le cose emissive accese (`modo_luci()` in
    `render_buildings.py`). Un disegno no: il foglio e' bianco e basta, e senza
    questo file di notte la casa e' una sagoma spenta in mezzo a una fila di
    case abitate. Qui le finestre si dichiarano a mano, in coordinate del PNG
    ritagliato, e ne esce l'equivalente: fondo nero e sopra i rettangoli caldi.
    Il resto — trasparenza, alone, riduzione — lo fa `import_flats_art.py`,
    che questo file lo tratta come quello di un edificio qualunque.
    """
    from PIL import ImageDraw
    tela = Image.new("RGB", dimensioni, (0, 0, 0))
    dis = ImageDraw.Draw(tela)
    for (x0, y0, x1, y1) in finestre:
        dis.rectangle([x0, y0, x1, y1], fill=(232, 192, 122))
    tela.save(destinazione)
    return tela


def estrai(sorgente, destinazione, soglia=SOGLIA, turaggio=TURAGGIO,
           segmenti=(), sigilla=(), finestre=()):
    im = Image.open(sorgente).convert("RGB")
    grigio = np.asarray(im.convert("L"))
    tratto = grigio < soglia
    barriera = tratto | _dighe(tratto.shape, segmenti) | _sigillo(tratto, sigilla)

    sfondo = _allaga(~_dilata(barriera, turaggio))
    # L'ingrossamento ha spinto il confine dentro al disegno di `turaggio`
    # pixel: si ridanno indietro allo sfondo, ma non alle righe.
    sfondo = _dilata(sfondo, turaggio) & ~barriera

    alfa = np.where(sfondo, 0, 255).astype(np.uint8)
    rgba = np.dstack([np.asarray(im), alfa])
    out = Image.fromarray(rgba, "RGBA")
    # Ritaglio sul disegno: il foglio intorno non serve a nessuno, e lasciarlo
    # vorrebbe dire che la taglia richiesta in `import_flats_art.py` comprende
    # dei margini vuoti diversi da un disegno all'altro.
    box = out.getbbox()
    out = out.crop(box)
    out.save(destinazione)
    if finestre:
        nome = os.path.basename(destinazione)
        acceso = os.path.join(os.path.dirname(destinazione),
                              nome.replace("render_", "luci_", 1)
                              if nome.startswith("render_") else "luci_" + nome)
        _luci(out.size, finestre, acceso)
        print("  finestre accese ->", os.path.basename(acceso))
    dentro = int((alfa > 0).sum())
    print("%s  %dx%d  disegno %d%% del foglio  ritaglio %s"
          % (os.path.basename(destinazione), out.width, out.height,
             round(100.0 * dentro / alfa.size), box))
    return out


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return
    soglia = int(sys.argv[3]) if len(sys.argv) > 3 else SOGLIA
    turaggio = int(sys.argv[4]) if len(sys.argv) > 4 else TURAGGIO
    estrai(sys.argv[1], sys.argv[2], soglia, turaggio)


if __name__ == "__main__":
    main()
