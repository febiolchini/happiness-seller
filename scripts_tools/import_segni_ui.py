"""Il cerchio d'oro e il triangolo verde disegnati da Federico, scontornati.

Nella foto stanno uno sopra l'altro su un foglio bianco: si tiene quello che e'
colorato (saturo) e lo si divide a meta' altezza.

- `cerchio_oro.png`: il segno di selezione disegnato, com'era.
- `cerchio_verde.png`: lo stesso ricolorato di verde, ed e' quello che usano le
  finestre (`UiTheme`): Federico ha voluto verdi i dettagli che erano arancio.
- `triangolo_verde.png`: il segnalino sopra le proprieta' possedute.
- `triangolo_arancio.png`: lo stesso in giallo-arancio, sopra agli edifici con
  uno sportello (agenzie, grossista, stazione).

Le copie ricolorate cambiano solo la tinta: saturazione e luminosita' restano
quelle della pennellata, quindi le sfumature del disegno non si perdono.

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
    # Era 36: sopra ai tetti, a zoom normale, si perdeva fra le finestre.
    "triangolo_verde": ((450, None), 72),
}

# Le copie ricolorate: nome -> (da quale segno, tinta in gradi, di quanto
# alzare la luminosita').
TINTE = {
    "triangolo_arancio": ("triangolo_verde", 42.0, 1.7),
    "cerchio_verde": ("cerchio_oro", 140.0, 0.85),
}


def ricolora(im, tinta, luce):
    """Stessa pennellata, un'altra tinta."""
    rgba = np.asarray(im).astype(float) / 255.0
    hsv = np.asarray(im.convert("RGB").convert("HSV")).astype(float)
    hsv[..., 0] = tinta / 360.0 * 255.0
    hsv[..., 2] = np.clip(hsv[..., 2] * luce, 0, 255)
    rgb = np.asarray(Image.fromarray(hsv.astype(np.uint8), "HSV").convert("RGB"))
    return Image.fromarray(np.dstack([rgb, (rgba[..., 3] * 255).astype(np.uint8)]), "RGBA")


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
    for name, (da, tinta, luce) in TINTE.items():
        out = UI / f"{name}.png"
        ricolora(Image.open(UI / f"{da}.png").convert("RGBA"), tinta, luce).save(out)
        print(out.name, "da", da)


if __name__ == "__main__":
    main()
