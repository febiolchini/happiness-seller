"""Costruisce in Blender gli edifici dell'aeroporto di CIVIC CENTER.

L'aeroporto prende il posto di quattro isolati in basso a sinistra (vedi
`CityMap.AIRPORT`). Qui ci sono solo le strutture alte, quelle che si vedono
di sbieco come il resto della citta': piste, raccordi e piazzale sono
pavimento e li disegna il gioco (`airport.gd`), come le strade.

Tre unita', tre PNG, allineate lungo il bordo nord dell'aeroporto con la
facciata verso le piste:

  * `hangar_grande` — il capannone a botte di lamiera ondulata, col portone
    scorrevole mezzo aperto e l'interno buio. E' quello davanti a cui si
    ferma l'aereo di linea;
  * `hangar_piccolo` — tetto a capanna, portoni chiusi, una fila di finestre;
  * `torre` — la torre di controllo con la cabina a vetri, sopra alla
    palazzina degli uffici.

Presi dalla foto di un aeroporto regionale, senza verde e senza mezzi: gli
aerei e i furgoni li mette il gioco, e si muovono.

Uso:
  blender --background --factory-startup --python scripts_tools/blender_aeroporto.py
  python scripts_tools/import_flats_art.py
"""

import math
import os
import sys

import bmesh
import bpy

try:
    HERE = os.path.dirname(os.path.abspath(__file__))
except NameError:
    HERE = os.path.join(os.getcwd(), "scripts_tools")
sys.path.insert(0, HERE)
import blender_cinema_videogiochi as cv  # noqa: E402
import blender_isolato_cinese as ic  # noqa: E402
from blender_cinema_videogiochi import M, PEZZI, bx, finestra, piatto, testo  # noqa: E402

OUT = cv.OUT

# Larghezze in metri: sono i PNG a 22,3 px/m (424, 290 e 178 px).
UNITA = {
    "hangar_grande": 19.0,
    "hangar_piccolo": 13.0,
    "torre": 8.0,
}


def palette():
    cv.palette()
    M["lamiera"] = cv.righe("AE_Lamiera", "#BCC4C8", "#9DA6AB", 0.32, asse="X", frazione=0.28)
    M["lamiera_tetto"] = cv.righe("AE_Lamiera_Tetto", "#A9B1B5", "#8D969B", 0.5, asse="X", frazione=0.3)
    M["lamiera_verde"] = cv.righe("AE_Lamiera_Verde", "#8C9C88", "#76866F", 0.32, asse="X", frazione=0.28)
    M["tetto_verde"] = cv.righe("AE_Tetto_Verde", "#6E7D6A", "#5C6A58", 0.45, asse="Y", frazione=0.25)
    M["portone"] = cv.righe("AE_Portone", "#7C878D", "#66727A", 0.9, asse="X", frazione=0.08)
    M["portone_verde"] = cv.righe("AE_Portone_Verde", "#667562", "#56644F", 0.8, asse="X", frazione=0.08)
    M["buio"] = piatto("AE_Buio", "#1B1F22", 0.95)
    M["pavimento_hangar"] = piatto("AE_Pavimento", "#55595A", 0.9, emissivo="#6A6456", forza=0.15)
    M["arancio"] = piatto("AE_Arancio", "#D66A1E", 0.6)
    M["bianco"] = piatto("AE_Bianco", "#E6E6E0", 0.7)
    M["cemento"] = piatto("AE_Cemento", "#B5AFA3", 0.9)
    M["cemento_scuro"] = piatto("AE_Cemento_Scuro", "#8F897E", 0.9)
    M["vetro_torre"] = piatto("AE_Vetro_Torre", "#3E5A66", 0.15, 0.3, emissivo="#9CC8D8", forza=0.55)
    M["scritta_nera"] = piatto("AE_Scritta_Nera", "#22262A", 0.6)
    M["rosso_luce"] = piatto("AE_Rosso_Luce", "#C8281E", 0.4, emissivo="#FF3A2A", forza=2.5)
    M["antenna"] = piatto("AE_Antenna", "#3A3E42", 0.5, 0.6)


def poligono(nome, punti, facce, mat):
    me = bpy.data.meshes.new(nome)
    me.from_pydata(punti, [], facce)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(M[mat])
    ob = bpy.data.objects.new(nome, me)
    bpy.context.scene.collection.objects.link(ob)
    PEZZI.append(ob)
    return ob


def botte(nome, x0, x1, y0, y1, z0, alzata, mat, seg=14, chiusa=True):
    """Un tetto a botte: mezza ellisse in sezione (X,Z), estrusa lungo Y. Con
    `chiusa` ha anche le due testate piene."""
    cx, r = (x0 + x1) / 2, (x1 - x0) / 2
    arco = [(cx - r * math.cos(math.pi * i / seg), z0 + alzata * math.sin(math.pi * i / seg))
            for i in range(seg + 1)]
    punti = [(x, y0, z) for x, z in arco] + [(x, y1, z) for x, z in arco]
    n = len(arco)
    facce = [(i, i + 1, n + i + 1, n + i) for i in range(n - 1)]
    if chiusa:
        facce.append(tuple(range(n)))
        facce.append(tuple(range(2 * n - 1, n - 1, -1)))
    return poligono(nome, punti, facce, mat)


def capanna(nome, x0, x1, y0, y1, z0, colmo, mat, sporto=0.3):
    """Tetto a due falde col colmo lungo Y (il timpano guarda la camera)."""
    cx = (x0 + x1) / 2
    a, b = x0 - sporto, x1 + sporto
    punti = [(a, y0 - sporto, z0), (cx, y0 - sporto, colmo), (b, y0 - sporto, z0),
             (a, y1 + sporto, z0), (cx, y1 + sporto, colmo), (b, y1 + sporto, z0)]
    facce = [(0, 1, 4, 3), (1, 2, 5, 4)]
    ob = poligono(nome, punti, facce, mat)
    ob.modifiers.new("spessore", "SOLIDIFY").thickness = 0.12
    return ob


# ----------------------------------------------------------------------
#  le tre unita'
# ----------------------------------------------------------------------

def hangar_grande(w):
    D, H, ALZ = 13.0, 5.5, 3.6
    x0, x1 = 0.0, w
    porta = (2.2, w - 2.2, 5.2)
    PEZZI.append(ic.muro_forato("facciata", x0, x1, 0.0, H, 0.0, 0.3, M["lamiera"],
                                [(porta[0], porta[1], 0.0, porta[2])]))
    bx("lato_sx", x0, x0 + 0.3, 0.3, D, 0.0, H, "lamiera")
    bx("lato_dx", x1 - 0.3, x1, 0.3, D, 0.0, H, "lamiera")
    bx("fondo", x0, x1, D - 0.3, D, 0.0, H, "lamiera")
    botte("tetto", x0 - 0.15, x1 + 0.15, -0.25, D + 0.1, H, ALZ, "lamiera_tetto")
    # La testata a botte sopra al portone: una fascia di lamiera e una
    # finestratura a nastro, come i capannoni della foto.
    bx("architrave", x0, x1, -0.05, 0.3, porta[2], H, "arancio")
    bx("nastro_v", 4.0, w - 4.0, -0.3, -0.26, H + 0.5, H + 1.5, "vetro")
    for i in range(1, 8):
        x = 4.0 + (w - 8.0) * i / 8
        bx("nastro_m%d" % i, x - 0.05, x + 0.05, -0.33, -0.28, H + 0.5, H + 1.5, "infisso")
    testo("scritta", "HANGAR 1", w / 2, -0.34, H + 2.25, 0.62, "scritta_nera")
    # Dentro: buio, col pavimento appena illuminato.
    # Alto quanto il muro e non fino alla botte: ai lati la botte scende, e un
    # volume piu' alto la bucava.
    bx("dentro", x0 + 0.3, x1 - 0.3, 0.3, D - 0.3, 0.02, H - 0.05, "buio")
    bx("pavimento", x0 + 0.3, x1 - 0.3, 0.3, D - 0.3, 0.0, 0.03, "pavimento_hangar")
    # Il portone: pannelli impacchettati ai due lati, il vano aperto in mezzo.
    for s, (a, b) in enumerate(((porta[0], porta[0] + 4.2), (porta[1] - 4.2, porta[1]))):
        for k in range(3):
            pa = a + (b - a) * k / 3
            pb = a + (b - a) * (k + 1) / 3
            y = -0.08 - 0.12 * (k if s == 0 else 2 - k)
            bx("pannello%d_%d" % (s, k), pa, pb, y - 0.1, y, 0.0, porta[2] - 0.05, "portone")
    # Le strisce di pericolo sul bordo del vano.
    for k, x in enumerate((porta[0] + 4.3, porta[1] - 4.5)):
        bx("pericolo%d" % k, x, x + 0.2, -0.12, 0.0, 0.0, porta[2], "arancio")


def hangar_piccolo(w):
    D, H, COLMO = 10.0, 4.6, 6.8
    x0, x1 = 0.0, w
    bx("corpo", x0, x1, 0.0, D, 0.0, H, "lamiera_verde")
    poligono("timpano", [(x0, 0.0, H), (x1, 0.0, H), (w / 2, 0.0, COLMO),
                         (x0, 0.3, H), (x1, 0.3, H), (w / 2, 0.3, COLMO)],
             [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)], "lamiera_verde")
    capanna("tetto", x0, x1, 0.0, D, H - 0.05, COLMO, "tetto_verde")
    # Due portoni chiusi, a doghe orizzontali, e fra i due una porticina.
    for k, (a, b) in enumerate(((0.8, 5.8), (w - 5.8, w - 0.8))):
        bx("portone%d" % k, a, b, -0.12, 0.0, 0.0, 3.9, "portone_verde")
        bx("portone%d_bordo" % k, a - 0.12, b + 0.12, -0.16, -0.1, 3.9, 4.05, "bianco")
        for z in (1.0, 2.0, 3.0):
            bx("portone%d_doga%d" % (k, int(z)), a, b, -0.16, -0.12, z - 0.03, z + 0.03, "infisso")
    bx("porticina", w / 2 - 0.5, w / 2 + 0.5, -0.1, 0.0, 0.0, 2.1, "arancio")
    for k in range(3):
        x = 1.6 + k * 1.5
        # Accese: di notte l'hangar ha la luce di lavoro dentro, e si vede da qui.
        finestra("fin_sx%d" % k, x, x + 1.0, 4.1, 4.45, -0.01, "vetro_acceso")
        finestra("fin_dx%d" % k, w - x - 1.0, w - x, 4.1, 4.45, -0.01, "vetro_acceso")
    testo("scritta", "HANGAR 2", w / 2, -0.04, 5.3, 0.5, "scritta_nera")


def torre(w):
    """La palazzina degli uffici (bassa, larga quanto il lotto) e la torre che
    ne esce a destra, con la cabina a vetri e la luce rossa in cima."""
    D = 6.0
    bx("uffici", 0.0, w, 0.0, D, 0.0, 3.4, "cemento")
    bx("uffici_cornice", -0.05, w + 0.05, -0.1, D, 3.2, 3.5, "cemento_scuro")
    for k in range(3):
        x = 0.6 + k * 1.6
        finestra("uff_fin%d" % k, x, x + 1.1, 1.2, 2.5, -0.01, "vetro_acceso")
    bx("uff_porta", 5.3, 6.4, -0.05, 0.0, 0.0, 2.3, "vetro")
    # La torre: un fusto quadrato, la cabina che sporge, il tetto piatto.
    # Un metro dal bordo: la cabina sporge di 0,65 per lato, e l'inquadratura
    # e' esattamente il lotto.
    tx0, tx1 = w - 4.0, w - 1.0
    ty0, ty1 = 1.5, 4.5
    Z_CAB = 9.4
    bx("fusto", tx0, tx1, ty0, ty1, 3.4, Z_CAB, "cemento")
    for z in (5.4, 7.4):
        bx("fusto_fascia%d" % int(z), tx0 - 0.03, tx1 + 0.03, ty0 - 0.03, ty1, z, z + 0.15, "cemento_scuro")
    bx("cab_base", tx0 - 0.55, tx1 + 0.55, ty0 - 0.55, ty1 + 0.55, Z_CAB, Z_CAB + 0.35, "cemento_scuro")
    # La cabina a vetri: pannelli inclinati sarebbero belli, ma a questa scala
    # si legge solo la fascia di vetro. Montanti ogni metro.
    bx("cabina", tx0 - 0.45, tx1 + 0.45, ty0 - 0.45, ty1 + 0.45, Z_CAB + 0.35, Z_CAB + 2.0, "vetro_torre")
    for k in range(5):
        x = tx0 - 0.45 + (tx1 - tx0 + 0.9) * k / 4
        bx("cab_m%d" % k, x - 0.05, x + 0.05, ty0 - 0.5, ty0 - 0.44, Z_CAB + 0.35, Z_CAB + 2.0, "infisso")
    bx("cab_tetto", tx0 - 0.65, tx1 + 0.65, ty0 - 0.65, ty1 + 0.65, Z_CAB + 2.0, Z_CAB + 2.3, "bianco")
    bx("antenna", (tx0 + tx1) / 2 - 0.05, (tx0 + tx1) / 2 + 0.05, 3.0, 3.1, Z_CAB + 2.3, Z_CAB + 3.6, "antenna")
    bx("luce_rossa", (tx0 + tx1) / 2 - 0.12, (tx0 + tx1) / 2 + 0.12, 2.93, 3.17, Z_CAB + 3.6, Z_CAB + 3.84,
       "rosso_luce")


COSTRUTTORI = {"hangar_grande": hangar_grande, "hangar_piccolo": hangar_piccolo, "torre": torre}


def costruisci(chiave):
    fs = bpy.context.view_layer.freestyle_settings
    for ls in list(fs.linesets):
        fs.linesets.remove(ls)
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for c in list(bpy.data.collections):
        bpy.data.collections.remove(c)
    PEZZI.clear()
    cv.SOTTILI.clear()
    palette()
    w = UNITA[chiave]
    COSTRUTTORI[chiave](w)
    for ob in PEZZI:
        for mod in list(ob.modifiers):
            bpy.context.view_layer.objects.active = ob
            bpy.ops.object.modifier_apply(modifier=mod.name)
    cv.unisci(list(PEZZI), "AE_" + chiave)
    cam = cv.scena()
    cv.inquadra(cam, 0.0, w)


def renderizza():
    os.makedirs(OUT, exist_ok=True)
    sc = bpy.context.scene
    for chiave in UNITA:
        costruisci(chiave)
        sc.render.filepath = os.path.join(OUT, "render_aero_%s.png" % chiave)
        bpy.ops.render.render(write_still=True)
        cv.modo_luci()
        sc.render.filepath = os.path.join(OUT, "luci_aero_%s.png" % chiave)
        bpy.ops.render.render(write_still=True)
        print("AERO", chiave, sc.render.resolution_x, sc.render.resolution_y)


if __name__ == "__main__":
    renderizza()
