"""Scontorna la foglia disegnata da Federico e ne fa la decorazione della UI.

Nella foto la foglia sta su un quadratino crema dentro a un foglio bianco: si
tiene quello che e' verde (saturo) o scuro, cioe' foglia e contorno, e poi solo
il pezzo piu' grande.

    python scripts_tools/import_foglia.py
"""
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

from import_flats_art import scale

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/sprites/ui/_source/foglia.jpeg"
OUT = ROOT / "assets/sprites/ui/foglia.png"
ALTEZZA = 96


def largest_component(mask):
    h, w = mask.shape
    seen = np.zeros_like(mask)
    best = []
    for y0, x0 in zip(*np.nonzero(mask)):
        if seen[y0, x0]:
            continue
        comp = []
        q = deque([(y0, x0)])
        seen[y0, x0] = True
        while q:
            y, x = q.popleft()
            comp.append((y, x))
            for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    q.append((ny, nx))
        if len(comp) > len(best):
            best = comp
    out = np.zeros_like(mask)
    ys, xs = zip(*best)
    out[list(ys), list(xs)] = True
    return out


def main():
    s = np.asarray(Image.open(SRC).convert("RGB")).astype(int)
    sat = s.max(2) - s.min(2)
    leaf = largest_component((sat > 40) | (s.max(2) < 110))
    # Gli spazi chiusi dentro la foglia (le venature chiare) restano foglia.
    outside = ~leaf
    border = np.zeros_like(leaf)
    border[0, :] = border[-1, :] = border[:, 0] = border[:, -1] = True
    reach = np.zeros_like(leaf)
    q = deque(zip(*np.nonzero(border & outside)))
    for y, x in q:
        reach[y, x] = True
    h, w = leaf.shape
    while q:
        y, x = q.popleft()
        for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= ny < h and 0 <= nx < w and outside[ny, nx] and not reach[ny, nx]:
                reach[ny, nx] = True
                q.append((ny, nx))
    leaf = ~reach

    ys, xs = np.nonzero(leaf)
    rgba = np.dstack([s, leaf * 255]).astype(np.uint8)
    im = Image.fromarray(rgba).crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    scale(im, None, ALTEZZA).save(OUT)
    print(OUT.name, im.size, "->", Image.open(OUT).size)


if __name__ == "__main__":
    main()
