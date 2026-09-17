"""Disegna le insegne degli edifici, una per PNG.

## Perche' non sono dipinte sul disegno dell'edificio

I PNG degli edifici escono da Blender e li riscrive `import_flats_art.py`: una
scritta dipinta sopra sparirebbe al primo re-import, e nessuno se ne
accorgerebbe finche' non si guarda quella facciata. Un'insegna e' invece testo —
cambia perche' cambia il gioco, non perche' cambia il modello 3D — e sta in un
file suo, appeso all'edificio da `CityMap` (campo `"sign"`).

## Perche' un alfabeto scritto qui e non il font del gioco

`alphabet.fnt` e' alto 53 px e antialiasato: rimpicciolito agli undici pixel di
una fascia d'insegna diventa una macchia grigia. Le lettere qui sotto sono
disegnate alla misura in cui si vedono, un pixel e' un pixel, e sono solo quelle
che servono davvero.

Uso:
    python scripts_tools/make_signs.py
"""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites" / "buildings" / "signs"

# Alfabeto 7x9. Solo le lettere che compaiono nelle insegne: aggiungerne una
# vuol dire disegnarla qui, e un carattere mancante fa alzare un errore invece
# di lasciare un buco nella parola.
GLYPHS = {
    "A": [
        "..###..",
        ".#...#.",
        "#.....#",
        "#.....#",
        "#.....#",
        "#######",
        "#.....#",
        "#.....#",
        "#.....#",
    ],
    "E": [
        "#######",
        "#......",
        "#......",
        "#......",
        "######.",
        "#......",
        "#......",
        "#......",
        "#######",
    ],
    "H": [
        "#.....#",
        "#.....#",
        "#.....#",
        "#.....#",
        "#######",
        "#.....#",
        "#.....#",
        "#.....#",
        "#.....#",
    ],
    "L": [
        "#......",
        "#......",
        "#......",
        "#......",
        "#......",
        "#......",
        "#......",
        "#......",
        "#######",
    ],
    "O": [
        ".#####.",
        "#.....#",
        "#.....#",
        "#.....#",
        "#.....#",
        "#.....#",
        "#.....#",
        "#.....#",
        ".#####.",
    ],
    "R": [
        "######.",
        "#.....#",
        "#.....#",
        "#.....#",
        "######.",
        "#...#..",
        "#....#.",
        "#.....#",
        "#.....#",
    ],
    "S": [
        ".######",
        "#......",
        "#......",
        "#......",
        ".#####.",
        "......#",
        "......#",
        "......#",
        "######.",
    ],
    "T": [
        "#######",
        "...#...",
        "...#...",
        "...#...",
        "...#...",
        "...#...",
        "...#...",
        "...#...",
        "...#...",
    ],
    "W": [
        "#.....#",
        "#.....#",
        "#.....#",
        "#.....#",
        "#..#..#",
        "#..#..#",
        "#.#.#.#",
        "##...##",
        "#.....#",
    ],
}

GLYPH_W = 7
GLYPH_H = 9
## Spazio fra due lettere della stessa parola, e fra due parole.
LETTER_GAP = 2
WORD_GAP = 7

## Le insegne da disegnare: nome del file -> testo, colore della lettera,
## colore dell'ombra.
##
## L'ombra e' un pixel in basso a destra e non un contorno pieno: sulla fascia
## di un negozio le lettere sono rilevate, e un contorno tutto intorno le
## farebbe leggere come adesivi.
SIGNS = {
    "realEstate": {
        "text": "REAL ESTATE",
        "ink": (233, 225, 206, 255),
        "shadow": (26, 42, 55, 255),
    },
    # Il grossista di DOWNTOWN. Sulla facciata c'e' solo il pannello: la fascia
    # blu e' modellata in Blender, la parola sta qui.
    "wholesale": {
        "text": "WHOLESALE",
        "ink": (236, 233, 224, 255),
        "shadow": (18, 30, 58, 255),
    },
}


def measure(text: str) -> int:
    width = 0
    for i, letter in enumerate(text):
        if i > 0:
            width += WORD_GAP if (letter == " " or text[i - 1] == " ") else LETTER_GAP
        if letter != " ":
            width += GLYPH_W
    return width


def draw(text: str, ink, shadow) -> Image.Image:
    # Un pixel in piu' per lato: l'ombra sborda di uno in basso e a destra.
    image = Image.new("RGBA", (measure(text) + 1, GLYPH_H + 1), (0, 0, 0, 0))
    pixels = image.load()
    x = 0
    for i, letter in enumerate(text):
        if i > 0:
            x += WORD_GAP if (letter == " " or text[i - 1] == " ") else LETTER_GAP
        if letter == " ":
            continue
        if letter not in GLYPHS:
            raise SystemExit("la lettera %r non e' disegnata in GLYPHS" % letter)
        rows = GLYPHS[letter]
        # Prima tutta l'ombra, poi tutta la lettera: al contrario l'ombra di una
        # lettera cancellerebbe il bordo di quella prima.
        for y, row in enumerate(rows):
            for dx, cell in enumerate(row):
                if cell == "#":
                    pixels[x + dx + 1, y + 1] = shadow
        for y, row in enumerate(rows):
            for dx, cell in enumerate(row):
                if cell == "#":
                    pixels[x + dx, y] = ink
        x += GLYPH_W
    return image


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, spec in SIGNS.items():
        image = draw(spec["text"], spec["ink"], spec["shadow"])
        path = OUT / ("%sSign.png" % name)
        image.save(path)
        print("%s  %dx%d  %r" % (path.name, image.width, image.height, spec["text"]))


if __name__ == "__main__":
    main()
