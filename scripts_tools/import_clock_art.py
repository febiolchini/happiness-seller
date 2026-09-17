"""Porta la sveglia digitale alla scala del gioco, e misura il vetro storto.

Stessa storia del telefono (`import_phone_art.py`): arriva un disegno da 1254
px e a schermo deve stare in un angolo di una finestra 640x360. La riduzione e'
quella degli edifici, importata da `import_flats_art.py` — premoltiplicazione e
ritaglio compresi.

**Qui in piu' c'e' che il display non e' dritto.** La sveglia e' disegnata di
tre quarti, quindi il vetro non e' un rettangolo ma un parallelogramma che
scende verso destra: una riga di cifre messa orizzontale dentro a quel buco si
vede subito che non ci appartiene. Lo script misura la pendenza e la stampa
insieme al rettangolo, e `digital_clock.gd` disegna le cifre dentro a una
trasformazione inclinata di quel tanto. E' il pezzo che fa sembrare le cifre
accese DENTRO alla sveglia invece che appiccicate sopra.

Il vetro si trova a tentoni e non a mano: e' la macchia scura piu' grande del
disegno, e si prende col riempimento (`_blob()`). Cercarla a soglia e basta non
funzionerebbe — il contorno nero della scocca e' scuro quanto il vetro e gira
intorno a tutto il disegno, quindi una soglia sola li prende insieme.

Uso:
  python scripts_tools/import_clock_art.py
"""

import os
from collections import deque

import numpy as np
from PIL import Image

from import_flats_art import scale, trim

HERE = os.path.dirname(os.path.abspath(__file__))
UI = os.path.join(HERE, os.pardir, "assets", "sprites", "ui")
SOURCE = os.path.join(UI, "_source")

# Larghezza a schermo.
#
# La misura la detta quello che ci va DENTRO, non la sveglia: il display deve
# tenere l'orario a cifre da sette segmenti alte sedici pixel col tratto da due
# e, di fianco, il blocco del giorno anche a tre cifre. A settantotto il vetro
# viene largo cinquantasei e i conti tornano con due pixel di avanzo; sotto,
# la prima cosa che cede e' il distacco fra l'orario e il giorno.
#
# Era centootto, ed era troppo: in un angolo dello schermo la sveglia diventava
# l'oggetto piu' grande dell'interfaccia, e questo e' un gioco in cui si guarda
# la strada. Rimpicciolirla di un terzo pero' non ha fatto perdere due pixel di
# cifra su quindici: quasi tutto quello che si e' tolto era il vetro sprecato
# intorno (vedi `INSET`).
WIDTH = 78

# Sotto questa luminosita' il pixel e' vetro o contorno: sopra e' la scocca,
# che e' verde oliva chiaro. Le due zone non si sovrappongono, quindi una soglia
# sola basta a separarle — a distinguere il vetro dal contorno ci pensa il
# riempimento, non la soglia.
GLASS_LUMA = 95

# Quanto si tiene il vetro lontano dal bordo del buco, in frazione dell'altezza.
# Il buco non e' un parallelogramma perfetto (e' un disegno in prospettiva, e a
# destra e' un po' piu' alto), quindi le cifre stanno dentro a un rettangolo un
# filo piu' stretto invece che sul filo del bordo.
#
# Poco, e conta: il rettangolo qui sopra e' gia' l'intersezione di tutte le
# colonne, cioe' la parte di buco che c'e' **dappertutto**, quindi il margine
# vero c'e' gia'. Questo e' solo l'ultimo filo di sicurezza, e a metterlo
# generoso (era 0.10) si buttano via due pixel di altezza su quindici — che su
# una cifra alta tredici sono la differenza fra leggerla e indovinarla.
INSET = 0.05


def _blob(mask):
    """La macchia accesa piu' grande, come elenco di (y, x).

    Riempimento a quattro vicini, partito da una griglia di semi ogni quattro
    pixel: il vetro e' grande duecentomila pixel, quindi qualche seme ci cade
    per forza, e cercarne uno per pixel costerebbe venti volte tanto senza
    trovare niente di diverso.
    """
    height, width = mask.shape
    seen = np.zeros_like(mask)
    best = []
    for seed_y in range(0, height, 4):
        for seed_x in range(0, width, 4):
            if not mask[seed_y, seed_x] or seen[seed_y, seed_x]:
                continue
            queue = deque([(seed_y, seed_x)])
            seen[seed_y, seed_x] = True
            found = []
            while queue:
                y, x = queue.popleft()
                found.append((y, x))
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ny, nx = y + dy, x + dx
                    if (0 <= ny < height and 0 <= nx < width
                            and mask[ny, nx] and not seen[ny, nx]):
                        seen[ny, nx] = True
                        queue.append((ny, nx))
            if len(found) > len(best):
                best = found
    return np.array(best)


def _display(im):
    """Il vetro: rettangolo gia' inclinato piu' la pendenza.

    Il rettangolo e' espresso **nel sistema inclinato**, cioe' dopo la
    trasformazione: cosi' `digital_clock.gd` inclina e disegna, senza rifare
    nessun conto. La pendenza e' la media fra quella del bordo di sopra e quella
    di sotto, che in un disegno in prospettiva non sono identiche.
    """
    pixels = np.asarray(im, dtype=np.float64)
    dark = (pixels[:, :, 3] > 128) & (pixels[:, :, :3].mean(axis=2) < GLASS_LUMA)
    blob = _blob(dark)
    ys, xs = blob[:, 0], blob[:, 1]

    columns = np.unique(xs)
    tops = np.array([ys[xs == c].min() for c in columns])
    bottoms = np.array([ys[xs == c].max() for c in columns])
    # Le colonne di bordo, dove la macchia e' solo lo spigolo del buco, vanno
    # buttate: falserebbero la pendenza.
    heights = bottoms - tops
    solid = heights > heights.max() * 0.75
    columns, tops, bottoms = columns[solid], tops[solid], bottoms[solid]

    slope = 0.5 * (np.polyfit(columns, tops, 1)[0] + np.polyfit(columns, bottoms, 1)[0])
    # Raddrizzando il buco con quella pendenza, quanto resta alto e dove sta.
    flat_tops = tops - slope * columns
    flat_bottoms = bottoms - slope * columns
    top = float(flat_tops.max())
    bottom = float(flat_bottoms.min())
    inset = (bottom - top) * INSET
    return {
        "left": float(columns[0]),
        "right": float(columns[-1]),
        "top": top + inset,
        "bottom": bottom - inset,
        "slope": float(slope),
    }


def main():
    art = trim(Image.open(os.path.join(SOURCE, "clock.png")).convert("RGBA"))
    small = scale(art, WIDTH, None)
    small.save(os.path.join(UI, "clock.png"))

    glass = _display(small)
    print("const SIZE  := Vector2(%d.0, %d.0)" % (small.width, small.height))
    print("const GLASS := Rect2(%.1f, %.1f, %.1f, %.1f)" % (
        glass["left"], glass["top"],
        glass["right"] - glass["left"], glass["bottom"] - glass["top"]))
    print("const SHEAR := %.3f" % glass["slope"])


if __name__ == "__main__":
    main()
