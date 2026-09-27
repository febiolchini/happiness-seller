"""Porta la lavagna dell'HUD alla scala del gioco, e misura dove si scrive.

Il disegno (`assets/sprites/ui/_source/board.png`) arriva **senza
trasparenza**: la scacchiera grigia e bianca che di solito vuol dire "qui non
c'e' niente" e' dipinta dentro ai pixel. Si toglie col riempimento partito dai
bordi dell'immagine: passa sui pixel chiari e grigi della scacchiera e si ferma
sul contorno nero della cornice, che gira tutto intorno senza buchi. Una soglia
sola non basterebbe — dentro alla cornice non c'e' niente di chiaro, ma il
riempimento e' l'unico modo di essere sicuri di non bucare il legno.

La riduzione e' quella degli edifici (`import_flats_art.py`), premoltiplicazione
e ritaglio compresi. Poi si misura la **lavagna verde** dentro alla cornice e
la si stampa nella forma della costante di `chalkboard.gd`: e' il rettangolo in
cui vanno le scritte, e deciderlo a occhio vorrebbe dire rifarlo a ogni
ritocco della misura.

Uso:
  python scripts_tools/import_board_art.py
"""

import os
from collections import deque

import numpy as np
from PIL import Image

from import_flats_art import riquadro, scale

HERE = os.path.dirname(os.path.abspath(__file__))
UI = os.path.join(HERE, os.pardir, "assets", "sprites", "ui")
SOURCE = os.path.join(UI, "_source")

# Larghezza a schermo. La detta quello che ci va dentro: cinque voci, ognuna
# su due righe — il nome piccolo sopra, il numero sotto — perche' la lavagna e'
# alta e stretta, e "SPACCIATORE 3" su una riga sola non ci starebbe se non
# rimpicciolendo tutto. A ottantaquattro la lavagna verde e' larga una
# settantina di pixel, quanto basta alla parola piu' lunga delle tre lingue a
# corpo otto, e l'insieme resta sotto alla sveglia senza mangiarsi la strada.
WIDTH = 84

# La scacchiera: chiara e senza colore. Sopra a questa luminosita' e sotto a
# questa saturazione un pixel e' sfondo, se il riempimento ci arriva dal bordo.
BACK_LUMA = 150
BACK_CHROMA = 24


def _clear_background(im):
    pixels = np.asarray(im.convert("RGB"), dtype=np.int16)
    luma = pixels.mean(axis=2)
    chroma = pixels.max(axis=2) - pixels.min(axis=2)
    back = (luma > BACK_LUMA) & (chroma < BACK_CHROMA)
    height, width = back.shape
    seen = np.zeros_like(back)
    queue = deque()
    for x in range(width):
        for y in (0, height - 1):
            if back[y, x] and not seen[y, x]:
                seen[y, x] = True
                queue.append((y, x))
    for y in range(height):
        for x in (0, width - 1):
            if back[y, x] and not seen[y, x]:
                seen[y, x] = True
                queue.append((y, x))
    while queue:
        y, x = queue.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < height and 0 <= nx < width and back[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                queue.append((ny, nx))
    rgba = np.dstack([pixels.astype(np.uint8), np.where(seen, 0, 255).astype(np.uint8)])
    return Image.fromarray(rgba, "RGBA")


def _slate(im):
    """Il rettangolo della lavagna verde: le righe e le colonne in cui il verde
    scuro occupa quasi tutta la larghezza (o l'altezza) del disegno."""
    pixels = np.asarray(im, dtype=np.float64)
    r, g, b, a = pixels[..., 0], pixels[..., 1], pixels[..., 2], pixels[..., 3]
    green = (a > 128) & (g > r + 8) & (g < 120)
    rows = np.where(green.mean(axis=1) > 0.5)[0]
    cols = np.where(green.mean(axis=0) > 0.5)[0]
    return int(cols[0]), int(rows[0]), int(cols[-1] + 1), int(rows[-1] + 1)


def main():
    art = _clear_background(Image.open(os.path.join(SOURCE, "board.png")))
    art = art.crop(riquadro(art))
    small = scale(art, WIDTH, None)
    small.save(os.path.join(UI, "board.png"))
    left, top, right, bottom = _slate(small)
    print("const SIZE  := Vector2(%d.0, %d.0)" % (small.width, small.height))
    print("const SLATE := Rect2(%d, %d, %d, %d)" % (left, top, right - left, bottom - top))


if __name__ == "__main__":
    main()
