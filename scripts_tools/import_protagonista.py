"""Dai render di `blender_protagonista.py` allo spritesheet del protagonista.

Tutti i frame hanno lo stesso riquadro e la stessa scala: la figura da ferma e'
alta `ALTEZZA` px, la stessa del segnaposto (1,75 m a 22,3 px/m). I frame
vanno in fila: `passo_0..7` e per ultimo `fermo`.

    python scripts_tools/import_protagonista.py

Stampa l'`offset` da mettere nello Sprite2D di `Player.tscn`: l'origine del
nodo e' ai piedi.
"""
from pathlib import Path

import numpy as np
from PIL import Image

from import_flats_art import scale

ROOT = Path(__file__).resolve().parent.parent
FRAMES = ROOT / "assets/sprites/characters/_source/camminata"
OUT = ROOT / "assets/sprites/characters/protagonista.png"

ALTEZZA = 39
NOMI = [f"passo_{i}" for i in range(8)] + ["fermo"]

# Il punto a terra del personaggio in pixel del disegno, e come il render li
# mappa (vedi CANVAS e RENDER_SCALE in blender_protagonista.py).
PIEDI = (78.0, 292.0)
CANVAS_ORIGINE = (-30.0, -10.0)
RENDER_SCALE = 2


def bbox(im):
    a = np.asarray(im)[:, :, 3]
    rows = np.where(a.max(axis=1) > 8)[0]
    cols = np.where(a.max(axis=0) > 8)[0]
    return cols[0], rows[0], cols[-1] + 1, rows[-1] + 1


def main():
    frames = [Image.open(FRAMES / f"{n}.png").convert("RGBA") for n in NOMI]
    boxes = [bbox(f) for f in frames]
    _, top, _, bottom = boxes[-1]
    fattore = ALTEZZA / (bottom - top)

    piedi = (
        (PIEDI[0] - CANVAS_ORIGINE[0]) * RENDER_SCALE,
        (PIEDI[1] - CANVAS_ORIGINE[1]) * RENDER_SCALE,
    )
    x0 = min(b[0] for b in boxes)
    y0 = min(b[1] for b in boxes)
    x1 = max(b[2] for b in boxes)
    y1 = max(max(b[3] for b in boxes), piedi[1])
    # Il riquadro si allarga a multipli interi del passo di riduzione, cosi'
    # ogni frame esce della stessa misura e l'origine cade su un pixel.
    passo = 1.0 / fattore
    w = int(np.ceil((x1 - x0) / passo))
    h = int(np.ceil((y1 - y0) / passo))
    x0 = int(round(x0))
    y0 = int(round(y0))
    box = (x0, y0, x0 + int(round(w * passo)), y0 + int(round(h * passo)))

    sheet = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.alpha_composite(scale(f.crop(box), w, h), (i * w, 0))
    sheet.save(OUT)

    ox = -round((piedi[0] - x0) * fattore)
    oy = -round((piedi[1] - y0) * fattore)
    print(f"{OUT.name}: {len(frames)} frame da {w}x{h}, offset Vector2({ox}, {oy})")


if __name__ == "__main__":
    main()
