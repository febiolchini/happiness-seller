"""Porta i render delle stanze (`blender_stanze.py`) alla taglia del gioco.

Per ogni stanza in `assets/sprites/rooms/_source/<stanza>/`:

  * `fondale.png` (1280x720) diventa `assets/sprites/rooms/<stanza>.png`
    (640x360, uno a uno con lo schermo);
  * ogni animazione diventa UNA striscia `<stanza>_<animazione>.png` con i
    suoi fotogrammi uno accanto all'altro, ritagliati al rettangolo in cui
    qualcosa cambia davvero;
  * tutte le stanze insieme finiscono in `scripts/data/room_art.gd`, la
    tabella che `room.gd` legge per montare le animazioni sopra al fondale.

## Solo i pixel che cambiano

Ogni fotogramma e' la stanza intera. Tenerla intera vorrebbe dire undici
schermate per un lampadario che dondola; qui si confronta ogni fotogramma col
fondale fermo e si tiene solo quello che si muove. La maschera e' UNA per tutta
l'animazione — l'unione di dove cambia qualcosa in almeno un fotogramma, piu' un
pixel di margine — e fuori dalla maschera il fotogramma e' trasparente: si vede
il fondale sotto, che li' e' identico.

La maschera per pixel e non solo il rettangolo serve quando due animazioni si
toccano: con due rettangoli opachi, quello disegnato dopo coprirebbe l'altro
col fondale fermo, e il lampadario smetterebbe di muovere l'ombra sulla tenda
ogni volta che la tenda sta ferma.

`SOGLIA` e' la differenza sotto la quale un pixel conta come fermo. Il render e'
deterministico (due render della stessa posa differiscono al massimo di 1), ma
la luce del lampadario che si sposta cambia di un livello o due anche il muro
in fondo, e quei cambiamenti non si vedono e allargherebbero la maschera a
tutto lo schermo.

Uso:
  python scripts_tools/import_room_art.py
"""

import json
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, os.pardir))
SRC = os.path.join(ROOT, "assets", "sprites", "rooms", "_source")
DST = os.path.join(ROOT, "assets", "sprites", "rooms")
TABELLA = os.path.join(ROOT, "scripts", "data", "room_art.gd")
RES = "res://assets/sprites/rooms/"

SOGLIA = 4
# Il lato massimo di una texture che conviene dare a Godot: oltre, la striscia
# va a capo su piu' righe.
LATO_MAX = 8192

# Dal nome del tipo in Blender a quello del gioco.
TIPI = {"dondolo": "swing", "ciclo": "loop", "evento": "event"}


def carica(percorso):
    im = Image.open(percorso).convert("RGB")
    # Il render e' al doppio: `reduce` fa la media dei 2x2, cioe' esattamente
    # il supersampling. Un ricampionamento con filtro ammorbidirebbe i contorni.
    return np.asarray(im.reduce(2)).astype(np.int16)


def dilata(maschera):
    # Con un bordo di un pixel e non con `np.roll`: roll riavvolge, e una
    # lanterna sul bordo sinistro si ritrovava un pixel di maschera sul bordo
    # destro, che allargava la striscia a tutto lo schermo.
    h, w = maschera.shape
    pad = np.pad(maschera, 1)
    out = np.zeros_like(maschera)
    for dy in (0, 1, 2):
        for dx in (0, 1, 2):
            out |= pad[dy:dy + h, dx:dx + w]
    return out


def striscia(fotogrammi, maschera, rett):
    x, y, w, h = rett
    n = len(fotogrammi)
    colonne = max(1, min(n, LATO_MAX // w))
    righe = (n + colonne - 1) // colonne
    foglio = np.zeros((righe * h, colonne * w, 4), dtype=np.uint8)
    alfa = (maschera[y:y + h, x:x + w] * 255).astype(np.uint8)
    for i, f in enumerate(fotogrammi):
        r, c = divmod(i, colonne)
        pezzo = foglio[r * h:(r + 1) * h, c * w:(c + 1) * w]
        pezzo[..., :3] = f[y:y + h, x:x + w]
        pezzo[..., 3] = alfa
    return foglio, colonne, righe


def stanza(nome):
    cartella = os.path.join(SRC, nome)
    with open(os.path.join(cartella, "stanza.json"), encoding="utf-8") as fh:
        dati = json.load(fh)
    fondo = carica(os.path.join(cartella, "fondale.png"))
    Image.fromarray(fondo.astype(np.uint8)).save(os.path.join(DST, f"{nome}.png"))

    animazioni = []
    for a in dati["animazioni"]:
        percorsi = [os.path.join(cartella, f"{a['nome']}_{i:02d}.png")
                    for i in range(a["fotogrammi"])]
        if not all(os.path.exists(p) for p in percorsi):
            print(f"  {nome}/{a['nome']}: fotogrammi mancanti, salto")
            continue
        fotogrammi = [carica(p) for p in percorsi]
        diff = np.zeros(fondo.shape[:2], dtype=bool)
        for f in fotogrammi:
            diff |= np.abs(f - fondo).max(axis=2) > SOGLIA
        if not diff.any():
            print(f"  {nome}/{a['nome']}: non si muove niente, salto")
            continue
        maschera = dilata(diff)
        ys, xs = np.nonzero(maschera)
        rett = [int(xs.min()), int(ys.min()),
                int(xs.max() - xs.min() + 1), int(ys.max() - ys.min() + 1)]
        foglio, colonne, righe = striscia(fotogrammi, maschera, rett)
        file = f"{nome}_{a['nome']}.png"
        Image.fromarray(foglio, "RGBA").save(os.path.join(DST, file), optimize=True)
        voce = {
            "name": a["nome"],
            "texture": RES + file,
            "rect": rett,
            "frames": a["fotogrammi"],
            "columns": colonne,
            "rows": righe,
            "kind": TIPI[a["tipo"]],
        }
        for chiave, gioco in (("fps", "fps"), ("pausa", "pause"), ("periodo", "period"),
                              ("smorza", "decay"), ("spinta", "kick")):
            if chiave in a:
                voce[gioco] = a[chiave]
        animazioni.append(voce)
        print(f"  {nome}/{a['nome']}: {rett[2]}x{rett[3]} in {rett[0]},{rett[1]}"
              f" — {a['fotogrammi']} fotogrammi, {int(maschera.sum())} px")

    return {"backdrop": RES + f"{nome}.png", "animations": animazioni,
            "points": dati.get("punti", {})}


def gd(valore, rientro=1):
    """Da Python a letterale GDScript. JSON e' quasi GDScript, ma una tabella
    scritta a righe si legge e si confronta nei diff; un json.dumps su una riga
    no."""
    tab = "\t" * rientro
    if isinstance(valore, dict):
        if not valore:
            return "{}"
        righe = [f'{tab}"{k}": {gd(v, rientro + 1)},' for k, v in valore.items()]
        return "{\n" + "\n".join(righe) + "\n" + "\t" * (rientro - 1) + "}"
    if isinstance(valore, list):
        if all(not isinstance(v, (dict, list)) for v in valore):
            return "[" + ", ".join(gd(v) for v in valore) + "]"
        righe = [f"{tab}{gd(v, rientro + 1)}," for v in valore]
        return "[\n" + "\n".join(righe) + "\n" + "\t" * (rientro - 1) + "]"
    if isinstance(valore, bool):
        return "true" if valore else "false"
    if isinstance(valore, str):
        return json.dumps(valore)
    if isinstance(valore, float):
        return repr(round(valore, 3))
    return str(valore)


def main():
    os.makedirs(DST, exist_ok=True)
    stanze = {}
    for nome in sorted(os.listdir(SRC)):
        if os.path.exists(os.path.join(SRC, nome, "stanza.json")):
            print(nome)
            stanze[nome] = stanza(nome)
    with open(TABELLA, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(
            "class_name RoomArt\n"
            "extends RefCounted\n\n"
            "## I fondali delle stanze e le loro animazioni.\n"
            "##\n"
            "## FILE GENERATO da `scripts_tools/import_room_art.py`: non si tocca a mano,\n"
            "## si rifanno i render (`blender_stanze.py`) e si rilancia l'importatore.\n"
            "##\n"
            "## `rect` e' dove la striscia si appoggia sul fondale, in pixel di schermo;\n"
            "## `points` sono le misure proiettate dalla camera (finestra, protagonista,\n"
            "## vasi, PC) da cui sono presi i numeri delle scene.\n\n"
            f"const ROOMS := {gd(stanze)}\n")
    print("scritto", os.path.relpath(TABELLA, ROOT))


if __name__ == "__main__":
    main()
