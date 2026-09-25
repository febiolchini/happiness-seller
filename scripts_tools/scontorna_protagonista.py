"""Scontorna il disegno del protagonista: fondo bianco -> trasparente.

Il bianco da togliere e' solo quello collegato al bordo del foglio: la
maglietta e' bianca anche lei, ma e' chiusa dentro la giacca e resta.

    python scripts_tools/scontorna_protagonista.py
"""
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/sprites/characters/_source/protagonista.jpeg"
OUT = ROOT / "assets/sprites/characters/_source/protagonista_scontornato.png"


def flood(mask: np.ndarray, seeds) -> np.ndarray:
    h, w = mask.shape
    seen = np.zeros_like(mask)
    q = deque()
    for y, x in seeds:
        if mask[y, x] and not seen[y, x]:
            seen[y, x] = True
            q.append((y, x))
    while q:
        y, x = q.popleft()
        for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                q.append((ny, nx))
    return seen


def main() -> None:
    s = np.array(Image.open(SRC).convert("RGB")).astype(int)
    h, w, _ = s.shape
    white = (s.min(2) > 215) & ((s.max(2) - s.min(2)) < 25)
    border = [(0, x) for x in range(w)] + [(h - 1, x) for x in range(w)]
    border += [(y, 0) for y in range(h)] + [(y, w - 1) for y in range(h)]
    fg = ~flood(white, border)

    # Tiene solo la figura: le macchioline sul foglio restano fuori.
    ys, xs = np.nonzero(fg)
    cy, cx = int(np.median(ys)), int(np.median(xs))
    if not fg[cy, cx]:
        d = (ys - cy) ** 2 + (xs - cx) ** 2
        cy, cx = ys[d.argmin()], xs[d.argmin()]
    fg = flood(fg, [(cy, cx)])

    ys, xs = np.nonzero(fg)
    rgba = np.dstack([s, fg * 255]).astype(np.uint8)
    box = (xs.min() - 2, ys.min() - 2, xs.max() + 3, ys.max() + 3)
    Image.fromarray(rgba).crop(box).save(OUT)
    print("scontornato", OUT.name, "box", box)


if __name__ == "__main__":
    main()
