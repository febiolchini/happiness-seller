"""Il cerchio d'oro e il triangolo verde disegnati da Federico, scontornati.

Nella foto stanno uno sopra l'altro su un foglio bianco: si tiene quello che e'
colorato (saturo) e lo si divide a meta' altezza.

- `cerchio_oro.png`: il segno di selezione nelle finestre (`UiTheme`).
- `triangolo_verde.png`: il segnalino sopra le proprieta' possedute.

    python scripts_tools/import_segni_ui.py
"""
from pathlib import Path

import numpy as np
from PIL import Image

from import_flats_art import scale

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/sprites/ui/_source/cerchio_triangolo.jpeg"
UI = ROOT / "assets/sprites/ui"

SEGNI = {
    # nome: (righe della foto, altezza finale)
    "cerchio_oro": ((0, 450), 96),
    "triangolo_verde": ((450, None), 36),
}


def main():
    s = np.asarray(Image.open(SRC).convert("RGB")).astype(int)
    sat = s.max(2) - s.min(2)
    # Alpha morbido sul bordo della pennellata: dove il colore sfuma nel bianco
    # la saturazione cala, e la si usa come opacita'.
    alpha = np.clip((sat - 25) / 60.0, 0.0, 1.0)
    for name, ((y0, y1), altezza) in SEGNI.items():
        a = alpha.copy()
        a[:y0] = 0
        if y1 is not None:
            a[y1:] = 0
        ys, xs = np.nonzero(a > 0.05)
        # Il colore pieno della pennellata, non quello schiarito dal bianco del
        # foglio: sul bordo semitrasparente il bianco rifarebbe l'alone.
        pieno = s[a > 0.9].mean(axis=0)
        rgb = np.where(a[:, :, None] > 0.9, s, pieno)
        rgba = np.dstack([rgb, a * 255]).astype(np.uint8)
        im = Image.fromarray(rgba).crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
        out = UI / f"{name}.png"
        scale(im, None, altezza).save(out)
        print(out.name, im.size, "->", Image.open(out).size)


if __name__ == "__main__":
    main()
