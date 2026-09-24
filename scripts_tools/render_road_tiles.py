"""Renderizza le piastrelle stradali del kit di Kenney in PNG per il gioco.

Il kit (`assets/sprites/kenney_city-kit-roads`, CC0) e' fatto di modelli 3D, e
il gioco e' 2D: questo file e' il ponte fra i due. Prende gli OBJ, li guarda
**dritti dall'alto** e ne scrive un PNG per ciascuno in
`assets/sprites/roads/`.

Uso:
  python scripts_tools/render_road_tiles.py

## Perche' non Blender

Tutto il resto dell'arte passa da Blender (`render_buildings.py`,
`render_cars.py`), e per gli edifici e' giusto: hanno volume, la camera e' a 27
gradi, le ombre contano. Una piastrella stradale invece e' **piatta** — due
centesimi di unita' di spessore, tutto il disegno sta nella texture — e vista
dall'alto un renderer vero non ha niente da fare che un rasterizzatore di
cinquanta righe non faccia uguale. In cambio questo gira ovunque senza avere
Blender aperto, e il risultato e' identico a ogni esecuzione.

## Perche' dall'alto e non a 27 gradi

Il pavimento della citta' (`city_ground.gd`) e' disegnato in pianta: una strada
orizzontale e una verticale sono larghe 96 px tutte e due. Se le piastrelle
fossero rese a 27 gradi come gli edifici, l'asfalto delle orizzontali si
schiaccerebbe e quello delle verticali no, e le due larghezze non tornerebbero
piu'. Dall'alto invece la stessa piastrella serve per tutti e quattro i versi
girandola di novanta gradi, e le curve si specchiano senza rifare niente.

## La scala, e perche' e' 120 e non 160

La piastrella del kit e' un quadrato di 1 unita': 0,8 di asfalto e 0,1 di
cordolo rialzato per lato. Il gioco ha `CityMap.ROAD_WIDTH` = 96 px di asfalto
e una fascia di marciapiede di 32 px per lato.

Le due proporzioni non coincidono, quindi si sceglie a quale delle due misure
tenere: si tiene **l'asfalto**, perche' e' quello su cui passano le auto ed e'
scritto nei dati (`ROAD_WIDTH`, le corsie del traffico, le quote dei
marciapiedi). Da 0,8 unita' = 96 px viene `PX_PER_UNIT` = 120, e il cordolo del
kit esce 12 px: si appoggia sul bordo interno della fascia da 32, esattamente
dove `city_ground.gd` disegnava la sua riga di cordolo. Il resto del
marciapiede resta il grigio del gioco, e chi ci cammina non se ne accorge.

Tenere invece la piastrella intera sui 160 px avrebbe dato 128 px di asfalto:
una strada piu' larga di quella che il gioco crede di avere.

## La luce

Direzionale da nord-ovest e alta, piu' un ambiente generoso. Serve solo a far
leggere il gradino del cordolo: se fosse tutto piatto il marciapiede e
l'asfalto si distinguerebbero per il solo colore, e a questa scala il cordolo
sparirebbe. Le facce orizzontali prendono tutte la stessa luce, quindi la
piastrella resta uniforme e due piastrelle accostate non fanno cucitura.
"""

import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
KIT = os.path.join(PROJECT, "assets", "sprites", "kenney_city-kit-roads",
                   "Models", "OBJ format")
OUT = os.path.join(PROJECT, "assets", "sprites", "roads")

## Pixel per unita' del modello. Vedi "La scala" qui sopra.
PX_PER_UNIT = 120

## Campioni per lato dentro a ogni pixel. Le piastrelle hanno bordi diagonali
## (le curve) e righe sottili: senza antialiasing si vedono a scaletta anche a
## zoom 1. Quattro bastano, otto non si distinguono.
SUPERSAMPLE = 4

LIGHT = np.array([-0.45, 0.82, -0.35])
LIGHT /= np.linalg.norm(LIGHT)
AMBIENT = 0.72
DIFFUSE = 0.28

## Quali piastrelle servono al gioco, e come si chiama il PNG che ne esce.
##
## Tre, e il kit ne ha novantacinque: cartelli, semafori, ponti, rampe, curve,
## rotatorie. Ci sono solo quelle che `city_ground.gd` mette davvero per terra,
## perche' il reticolo della citta' e' fatto di tre cose — dritti, quadrivi e
## attraversamenti — e un PNG che non disegna nessuno e' peso morto che la
## prossima sessione deve capire da capo.
TILES = {
    # Il rettilineo, con cordolo sui due lati. E' il pezzo che fa i chilometri.
    "road-straight": "straight",
    # L'incrocio a quattro: niente cordoli, solo i quattro angoli smussati.
    "road-crossroad": "crossroad",
    # Le strisce pedonali, che il gioco disegnava a mano.
    "road-crossing": "crossing",
    # L'incrocio a T e la curva: servono ai bordi della citta', dove le strade
    # non attraversano piu' tutta la mappa ma si fermano contro quelle di
    # cornice (vedi `CityMap.junction_sides()`).
    "road-intersection": "tjunction",
    "road-bend": "bend",
}


def load_obj(path):
    """Vertici, coordinate texture e triangoli di un OBJ.

    Le facce del kit sono quadrilateri: si spezzano a ventaglio, che per un
    quadrilatero convesso e' esatto.
    """
    positions = []
    uvs = []
    tris = []
    for line in open(path, encoding="utf-8"):
        parts = line.split()
        if not parts:
            continue
        if parts[0] == "v":
            positions.append([float(v) for v in parts[1:4]])
        elif parts[0] == "vt":
            uvs.append([float(v) for v in parts[1:3]])
        elif parts[0] == "f":
            corners = []
            for token in parts[1:]:
                bits = token.split("/")
                vi = int(bits[0]) - 1
                ti = int(bits[1]) - 1 if len(bits) > 1 and bits[1] else 0
                corners.append((vi, ti))
            for i in range(1, len(corners) - 1):
                tris.append((corners[0], corners[i], corners[i + 1]))
    return np.array(positions, dtype=np.float64), np.array(uvs, dtype=np.float64), tris


def render(obj_path, texture, px_per_unit=PX_PER_UNIT):
    """La piastrella vista dritta dall'alto, in RGBA premoltiplicato da nessuno.

    Proiezione ortografica banale: la x del modello e' la x dello schermo, la z
    e' la y (verso sud), e la y — l'altezza — fa da profondita'. Niente
    prospettiva, quindi due piastrelle accostate combaciano al pixel.
    """
    positions, uvs, tris = load_obj(obj_path)
    lo = positions.min(axis=0)
    hi = positions.max(axis=0)
    # L'inquadratura e' l'ingombro in pianta arrotondato all'unita': una
    # piastrella da 1x1 deve uscire 120x120 tonde anche se il modello e' largo
    # 0,999, o accostandole si aprirebbe una fessura.
    units_x = max(1, int(round(hi[0] - lo[0])))
    units_z = max(1, int(round(hi[2] - lo[2])))
    width = units_x * px_per_unit
    height = units_z * px_per_unit
    ss = SUPERSAMPLE
    w, h = width * ss, height * ss

    color = np.zeros((h, w, 3), dtype=np.float64)
    alpha = np.zeros((h, w), dtype=np.float64)
    depth = np.full((h, w), -1e9, dtype=np.float64)

    tex = np.asarray(texture, dtype=np.float64) / 255.0
    tex_h, tex_w = tex.shape[0], tex.shape[1]

    origin = np.array([lo[0], lo[2]])
    scale = px_per_unit * ss

    for tri in tris:
        idx = [c[0] for c in tri]
        tid = [c[1] for c in tri]
        p = positions[idx]
        # Normale in spazio modello: serve solo per la luce.
        normal = np.cross(p[1] - p[0], p[2] - p[0])
        length = np.linalg.norm(normal)
        if length < 1e-12:
            continue
        normal /= length
        # Le facce rivolte in giu' non si vedono dall'alto e coprirebbero
        # quelle buone se finissero nello z-buffer per un pelo.
        if normal[1] <= 0.0:
            continue
        shade = AMBIENT + DIFFUSE * max(0.0, float(np.dot(normal, LIGHT)))

        screen = (p[:, [0, 2]] - origin) * scale
        _raster(screen, p[:, 1], uvs[tid], tex, tex_w, tex_h,
                shade, color, alpha, depth)

    out = np.zeros((h, w, 4), dtype=np.uint8)
    out[..., :3] = np.clip(color * 255.0, 0, 255).astype(np.uint8)
    out[..., 3] = np.clip(alpha * 255.0, 0, 255).astype(np.uint8)
    image = Image.fromarray(out, "RGBA")
    if ss > 1:
        image = image.resize((width, height), Image.LANCZOS)
    return image


def _raster(screen, heights, tri_uv, tex, tex_w, tex_h, shade, color, alpha, depth):
    """Riempie un triangolo, con z-buffer sull'altezza.

    Baricentriche su un rettangolo di contorno: i triangoli sono pochi e
    piccoli, e una versione furba non farebbe guadagnare niente di misurabile
    su novantacinque piastrelle.
    """
    h, w = alpha.shape
    x0 = max(0, int(np.floor(screen[:, 0].min())))
    x1 = min(w, int(np.ceil(screen[:, 0].max())) + 1)
    y0 = max(0, int(np.floor(screen[:, 1].min())))
    y1 = min(h, int(np.ceil(screen[:, 1].max())) + 1)
    if x0 >= x1 or y0 >= y1:
        return

    ax, ay = screen[0]
    bx, by = screen[1]
    cx, cy = screen[2]
    area = (bx - ax) * (cy - ay) - (cx - ax) * (by - ay)
    if abs(area) < 1e-12:
        return

    ys, xs = np.mgrid[y0:y1, x0:x1]
    px = xs + 0.5
    py = ys + 0.5
    w0 = ((bx - px) * (cy - py) - (cx - px) * (by - py)) / area
    w1 = ((cx - px) * (ay - py) - (ax - px) * (cy - py)) / area
    w2 = 1.0 - w0 - w1
    inside = (w0 >= 0) & (w1 >= 0) & (w2 >= 0)
    if not inside.any():
        return

    z = w0 * heights[0] + w1 * heights[1] + w2 * heights[2]
    window = depth[y0:y1, x0:x1]
    closer = inside & (z > window)
    if not closer.any():
        return

    u = w0 * tri_uv[0, 0] + w1 * tri_uv[1, 0] + w2 * tri_uv[2, 0]
    v = w0 * tri_uv[0, 1] + w1 * tri_uv[1, 1] + w2 * tri_uv[2, 1]
    # Campionamento al pixel piu' vicino: la colormap del kit e' un atlante di
    # tinte piatte, e interpolando si peschera' il colore della tinta accanto.
    tx = np.clip((u * tex_w).astype(np.int32), 0, tex_w - 1)
    ty = np.clip(((1.0 - v) * tex_h).astype(np.int32), 0, tex_h - 1)
    texel = tex[ty, tx, :3]

    window[closer] = z[closer]
    color[y0:y1, x0:x1][closer] = texel[closer] * shade
    alpha[y0:y1, x0:x1][closer] = 1.0


def main():
    if not os.path.isdir(KIT):
        print("Kit non trovato in %s" % KIT)
        return 1
    texture = Image.open(os.path.join(KIT, "Textures", "colormap.png")).convert("RGB")
    os.makedirs(OUT, exist_ok=True)
    for source, name in sorted(TILES.items()):
        path = os.path.join(KIT, source + ".obj")
        if not os.path.isfile(path):
            print("manca %s" % path)
            continue
        image = render(path, texture)
        target = os.path.join(OUT, name + ".png")
        image.save(target)
        print("%-14s -> %s  %dx%d" % (source, os.path.basename(target),
                                      image.width, image.height))
    return 0


if __name__ == "__main__":
    sys.exit(main())
