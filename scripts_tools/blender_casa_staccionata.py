"""Costruisce in Blender la casa con la staccionata di THE FLATS.

Sta su CROSS STREET a sinistra della casa gialla, e riempie il lotto dal
marciapiede di WESTGATE AVENUE al muro della casa gialla: 276 px, 12,4 m a
22,3 px/m. Nell'angolo destro del lotto c'e' il giardinetto recintato dalla
staccionata.

Presa da una foto di una casa di provincia americana, senza copiarla:

  * a sinistra l'ala a due piani col timpano sulla strada — rivestimento a
    doghe color sabbia, il timpano a squame con l'oblo' di ventilazione, la
    finestra del primo piano con le persiane verdi e la lunetta sopra, e sotto
    la porta basculante bianca del garage coi due lampioncini;
  * in mezzo il corpo basso, col timpanetto sulla finestra e la porta verde;
  * a destra il portico, arretrato sotto al tetto, coi pilastrini e la
    ringhiera bianchi e le tre finestre a quadretti;
  * il tetto di scandole di cedro, le cornici verdi, e davanti la staccionata
    bianca a punta che gira intorno al giardinetto.

Niente cespugli, prato, vialetto ne' auto: quello che sta a terra e' citta'. La
staccionata si': come la rete della casa gialla, e' il lotto della casa.

**Il portico e' poco profondo apposta** (1,3 m), per la stessa ragione di quello
del negozio di bici: con la camera a 27 gradi la gronda copre la cima delle
finestre che ha dietro di mezzo metro per ogni metro di portico.

Uso:
  blender --background --factory-startup --python scripts_tools/blender_casa_staccionata.py
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
# Scena, camera, luci e inquadratura del cinema; tubi del negozio di bici;
# prismi e cilindri della steak house.
import blender_bici as bi  # noqa: E402
import blender_cinema_videogiochi as cv  # noqa: E402
import blender_steakhouse as st  # noqa: E402
from blender_cinema_videogiochi import M, PEZZI, bx, piatto  # noqa: E402

OUT = cv.OUT
W = 276.0 / cv.PX_PER_METRO     # il lotto intero
# Sei metri e mezzo e non otto: il tetto dell'ala col colmo verso il fondo, da
# 27 gradi, a otto metri saliva nello sprite come una torre di scandole.
PROF = 6.5                      # profondita' della casa

# L'ala del garage, a due piani col timpano sulla strada.
GX = (0.0, 3.9)
G_GRONDA = 5.3
G_COLMO = 7.0
# Il corpo basso: la parte con la porta, e il portico.
CX = (GX[1], 6.9)
PX = (CX[1], 10.2)
GRONDA = 3.3
COLMO = 5.2
PORTICO = 1.3                   # di quanto il muro del portico e' arretrato
# La staccionata: davanti al portico e al giardinetto, e sul lato destro.
STAC_Y = -1.5
STAC_X0 = PX[0] + 0.05

COLL_STACCIONATA = "Staccionata"


def palette():
    cv.palette()
    M["doghe"] = cv.righe("CS_Doghe", "#DDD0C0", "#C3B4A3", 0.2, frazione=0.14)
    M["squame"] = cv.righe("CS_Squame", "#D7C7B4", "#B9A690", 0.13, frazione=0.32)
    M["tegole"] = cv.righe("CS_Tegole", "#B2713F", "#915A33", 0.24, frazione=0.18)
    M["garage"] = cv.righe("CS_Garage", "#EFECE5", "#CFCAC0", 0.52, frazione=0.06)
    M["verde"] = piatto("CS_Verde", "#2D5645", 0.6)
    M["porta"] = piatto("CS_Porta", "#23443A", 0.5)
    M["bianco"] = piatto("CS_Bianco", "#F0ECE4", 0.7)
    M["crema"] = piatto("CS_Crema", "#EAE0CC", 0.8)
    M["portico"] = cv.righe("CS_Portico", "#978C7E", "#7E7468", 0.14, asse="X", frazione=0.1)
    M["nero"] = piatto("CS_Nero", "#1E1C1B", 0.6)
    M["lampadina"] = piatto("CS_Lampadina", "#F4E2B0", 0.3, emissivo="#FFE6A0", forza=2.0)
    M["catrame"] = piatto("CS_Catrame", "#6A5A4C", 0.95)


# ----------------------------------------------------------------------
#  primitive
# ----------------------------------------------------------------------

def tetto_a_capanna(nome, x0, x1, z_gronda, z_colmo, y0, y1, mat, spessore=0.15):
    """Il tetto a due falde col colmo lungo Y: una V rovesciata estrusa, e non
    un prisma pieno, se no la sua faccia davanti coprirebbe il timpano."""
    xc = (x0 + x1) / 2
    t = spessore
    profilo = [(x0, z_gronda), (xc, z_colmo), (x1, z_gronda),
               (x1, z_gronda - t), (xc, z_colmo - t * 1.4), (x0, z_gronda - t)]
    return st.prisma(nome, profilo, y0, y1, mat)


def tetto_a_padiglione(nome, x0, x1, y0, y1, z_gronda, z_colmo, mat):
    """Il tetto del corpo basso: falda davanti, falda dietro e la testata a
    destra inclinata. A sinistra si appoggia all'ala del garage, e li' la
    testata e' dritta: tanto la copre il muro dell'ala."""
    yc = (y0 + y1) / 2
    fine = x1 - (y1 - y0) / 2
    v = [(x0, y0, z_gronda), (x1, y0, z_gronda), (x1, y1, z_gronda), (x0, y1, z_gronda),
         (x0, yc, z_colmo), (fine, yc, z_colmo)]
    bm = bmesh.new()
    vv = [bm.verts.new(p) for p in v]
    for f in ((0, 1, 5, 4), (3, 4, 5, 2), (1, 2, 5), (0, 4, 3), (0, 3, 2, 1)):
        bm.faces.new([vv[i] for i in f])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return st._oggetto(nome, bm, mat, PEZZI)


def lunetta(nome, xc, z, r, y, mat):
    """Il mezzo ventaglio sopra alle finestre."""
    punti = [(xc + r * math.cos(math.pi * i / 12), z + r * math.sin(math.pi * i / 12))
             for i in range(13)]
    st.prisma(nome, punti, y - 0.06, y, mat)


def finestra_con_persiane(nome, x0, x1, z0, z1, y, vetro, traversi=1, persiane=True):
    cv.finestra(nome, x0, x1, z0, z1, y, vetro, montanti=2, traversi=traversi)
    if persiane:
        w = (x1 - x0) * 0.32
        for lato, a, b in (("s", x0 - 0.12 - w, x0 - 0.12), ("d", x1 + 0.12, x1 + 0.12 + w)):
            bx("%s_pers_%s" % (nome, lato), a, b, y - 0.07, y, z0 - 0.02, z1 + 0.02, "verde")
            # Le lamelle: due righe scure, quanto basta a dire "persiana".
            for k in range(1, 4):
                zz = z0 + (z1 - z0) * k / 4
                bx("%s_pers_%s%d" % (nome, lato, k), a + 0.03, b - 0.03, y - 0.08, y - 0.07,
                   zz - 0.015, zz + 0.015, "porta")


# ----------------------------------------------------------------------
#  la casa
# ----------------------------------------------------------------------

def ala_garage():
    x0, x1 = GX
    xc = (x0 + x1) / 2
    bx("ala", x0, x1, 0.0, PROF, 0.0, G_GRONDA, "doghe")
    # Il timpano a squame, e sopra il tetto con la cornice verde davanti.
    st.prisma("ala_timpano", [(x0, G_GRONDA), (x1, G_GRONDA), (xc, G_COLMO - 0.2)],
              -0.03, 0.0, "squame")
    tetto_a_capanna("ala_tetto", x0 - 0.3, x1 + 0.3, G_GRONDA - 0.12, G_COLMO, -0.33, PROF + 0.3,
                    "tegole")
    tetto_a_capanna("ala_cornice", x0 - 0.32, x1 + 0.32, G_GRONDA - 0.12, G_COLMO + 0.02,
                    -0.4, -0.33, "verde", spessore=0.2)
    bx("ala_fascia", x0, x1, -0.06, 0.0, G_GRONDA - 0.14, G_GRONDA, "verde")
    # L'oblo' di ventilazione nel timpano.
    st.cilindro_y("oblo", xc, G_GRONDA + 1.05, 0.3, -0.08, -0.03, "bianco", PEZZI, lati=24)
    st.cilindro_y("oblo_dentro", xc, G_GRONDA + 1.05, 0.2, -0.1, -0.08, "squame", PEZZI, lati=24)
    # Le cantonali bianche.
    for nome, a, b in (("cant_s", x0, x0 + 0.14), ("cant_d", x1 - 0.14, x1)):
        bx(nome, a, b, -0.05, 0.0, 0.0, G_GRONDA, "bianco")
    # Primo piano: la finestra con le persiane e la lunetta.
    finestra_con_persiane("fin_ala", xc - 0.6, xc + 0.6, 3.45, 4.6, 0.0, "vetro_acceso")
    lunetta("lunetta_ala", xc, 4.72, 0.42, -0.02, "crema")
    # La porta del garage, col telaio bianco, e i due lampioncini.
    bx("garage_telaio", 0.42, 3.48, -0.05, 0.0, 0.0, 2.45, "bianco")
    bx("garage", 0.55, 3.35, -0.08, -0.05, 0.0, 2.35, "garage")
    for x in (0.25, 3.65):
        bx("lamp%d" % int(x * 10), x - 0.08, x + 0.08, -0.16, 0.0, 1.95, 2.25, "nero")
        bx("lamp%d_luce" % int(x * 10), x - 0.05, x + 0.05, -0.17, -0.16, 2.0, 2.18, "lampadina")


def corpo():
    """Il corpo basso: la parte con la porta e il timpanetto, e dietro al
    portico il muro arretrato con le tre finestre."""
    bx("corpo", CX[0], CX[1], 0.0, PROF, 0.0, GRONDA, "doghe")
    bx("corpo_portico", PX[0], PX[1], PORTICO, PROF, 0.0, GRONDA, "doghe")
    tetto_a_padiglione("tetto", CX[0], PX[1] + 0.4, -0.4, PROF + 0.3, GRONDA, COLMO, "tegole")
    bx("gronda", CX[0], PX[1] + 0.4, -0.47, -0.4, GRONDA - 0.2, GRONDA, "verde")
    # Il timpanetto sopra alla finestra, con la sua cornice verde.
    a, b = CX[0] + 0.05, CX[0] + 2.25
    xc = (a + b) / 2
    st.prisma("timpanetto", [(a, GRONDA), (b, GRONDA), (xc, 4.45)], -0.03, 0.0, "squame")
    tetto_a_capanna("timpanetto_tetto", a - 0.15, b + 0.15, GRONDA - 0.1, 4.62, -0.45, 3.0, "tegole",
                    spessore=0.12)
    tetto_a_capanna("timpanetto_cornice", a - 0.17, b + 0.17, GRONDA - 0.1, 4.64, -0.5, -0.45,
                    "verde", spessore=0.16)
    finestra_con_persiane("fin_corpo", xc - 0.62, xc + 0.62, 0.9, 2.3, 0.0, "vetro")
    lunetta("lunetta_corpo", xc, 2.42, 0.4, -0.02, "crema")
    # La porta verde, con la maniglia e la lampada accanto.
    d0, d1 = CX[1] - 0.8, CX[1] - 0.1
    bx("porta_telaio", d0 - 0.08, d1 + 0.08, -0.05, 0.0, 0.0, 2.28, "bianco")
    bx("porta", d0, d1, -0.08, -0.05, 0.0, 2.2, "porta")
    bx("porta_maniglia", d0 + 0.08, d0 + 0.14, -0.12, -0.08, 1.0, 1.08, "crema")
    bx("porta_lamp", d1 + 0.18, d1 + 0.32, -0.16, 0.0, 1.75, 2.05, "nero")
    bx("porta_lamp_luce", d1 + 0.21, d1 + 0.29, -0.17, -0.16, 1.8, 1.98, "lampadina")
    # Le tre finestre a quadretti in fondo al portico.
    for k in range(3):
        x0 = PX[0] + 0.3 + k * 1.05
        cv.finestra("fin_portico%d" % k, x0, x0 + 0.85, 0.8, 2.3, PORTICO, "vetro_acceso",
                    montanti=3, traversi=3)
    bx("pers_portico", PX[1] - 0.2, PX[1] - 0.02, PORTICO - 0.07, PORTICO, 0.8, 2.3, "verde")
    # Due sfiati sul tetto.
    for x in (6.2, 8.4):
        bi.tubo("sfiato%d" % int(x * 10), (x, 4.4, 4.0), (x, 4.4, 4.45), 0.06, "nero")


def portico(sottili):
    """Il pavimento, i pilastrini, la trave e la ringhiera bianca."""
    bx("portico_pav", PX[0], PX[1], 0.0, PORTICO + 0.02, 0.0, 0.3, "portico")
    bx("portico_bordo", PX[0], PX[1], -0.03, 0.02, 0.0, 0.3, "bianco")
    bx("portico_trave", PX[0], PX[1] + 0.05, -0.02, 0.22, GRONDA - 0.25, GRONDA, "bianco")
    pilastri = (PX[0] + 0.1, (PX[0] + PX[1]) / 2, PX[1] - 0.05)
    for k, x in enumerate(pilastri):
        bx("pilastro%d" % k, x - 0.1, x + 0.1, 0.03, 0.23, 0.3, GRONDA - 0.25, "bianco")
    y0, y1 = 0.1, 0.16
    for k in range(len(pilastri) - 1):
        a, b = pilastri[k] + 0.1, pilastri[k + 1] - 0.1
        bx("corrimano%d" % k, a, b, y0 - 0.02, y1 + 0.02, 1.02, 1.1, "bianco", raccolta=sottili)
        bx("traversa%d" % k, a, b, y0, y1, 0.42, 0.47, "bianco", raccolta=sottili)
        n = int((b - a) / 0.2)
        for i in range(1, n):
            x = a + (b - a) * i / n
            bx("colonnina%d_%d" % (k, i), x - 0.025, x + 0.025, y0, y1, 0.47, 1.02, "bianco",
               raccolta=sottili)


def staccionata(sottili):
    """La staccionata bianca a punta: davanti dal portico al bordo del lotto,
    e poi lungo il lato destro, a chiudere il giardinetto dell'albero."""
    y = STAC_Y
    x0, x1 = STAC_X0, W - 0.06
    for nome, z0, z1 in (("rail_basso", 0.22, 0.29), ("rail_alto", 0.66, 0.73)):
        bx("st_" + nome, x0, x1, y + 0.03, y + 0.07, z0, z1, "bianco", raccolta=sottili)
        bx("st_lato_" + nome, x1 - 0.04, x1, y, 2.2, z0, z1, "bianco", raccolta=sottili)
    passo = 0.17
    n = int((x1 - x0) / passo)
    for i in range(n + 1):
        x = x0 + (x1 - x0) * i / n
        st.prisma("picchetto%d" % i,
                  [(x - 0.045, 0.0), (x + 0.045, 0.0), (x + 0.045, 0.86), (x, 0.95), (x - 0.045, 0.86)],
                  y - 0.02, y + 0.02, "bianco", raccolta=sottili)
    m = int((2.2 - y) / passo)
    for i in range(1, m + 1):
        yy = y + (2.2 - y) * i / m
        bx("picchetto_lato%d" % i, x1 - 0.03, x1 + 0.01, yy - 0.045, yy + 0.045, 0.0, 0.9, "bianco",
           raccolta=sottili)
    # I pali, un po' piu' alti e col cappello.
    for k, x in enumerate((x0, (x0 + x1) / 2, x1 - 0.04)):
        bx("palo%d" % k, x - 0.07, x + 0.07, y - 0.05, y + 0.09, 0.0, 1.05, "bianco", raccolta=sottili)
        bx("palo%d_cap" % k, x - 0.09, x + 0.09, y - 0.07, y + 0.11, 1.05, 1.1, "bianco",
           raccolta=sottili)


def linea_sottile():
    """Una linea sottile e a mezza opacita' solo intorno a staccionata e
    ringhiera, come per le bici: a picchetti di due pixel la linea da due pixel
    del contorno li farebbe diventare una striscia nera."""
    fs = bpy.context.view_layer.freestyle_settings
    ls = fs.linesets.new("Staccionata")
    for a in ("select_crease", "select_border", "select_ridge_valley", "select_suggestive_contour",
              "select_material_boundary", "select_edge_mark"):
        setattr(ls, a, False)
    ls.select_silhouette = True
    ls.select_by_collection = True
    ls.collection = bpy.data.collections[COLL_STACCIONATA]
    ls.collection_negation = "INCLUSIVE"
    ls.linestyle.color = (0.18, 0.17, 0.15)
    ls.linestyle.alpha = 0.45
    ls.linestyle.thickness = 0.8


def costruisci():
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
    sottili = []
    ala_garage()
    corpo()
    portico(sottili)
    staccionata(sottili)
    cv.unisci(list(PEZZI), "CS_Casa")
    fine = cv.unisci(sottili, "CS_Staccionata")
    # Fuori dal contorno spesso (la collezione delle scritte, che il contorno
    # salta) e dentro a una sua, che ha la linea sottile.
    testi = bpy.data.collections.new(cv.COLL_TESTI)
    bpy.context.scene.collection.children.link(testi)
    mia = bpy.data.collections.new(COLL_STACCIONATA)
    bpy.context.scene.collection.children.link(mia)
    testi.objects.link(fine)
    mia.objects.link(fine)
    bpy.context.scene.collection.objects.unlink(fine)
    cam = cv.scena()
    linea_sottile()
    cv.inquadra(cam, 0.0, W)


def renderizza():
    os.makedirs(OUT, exist_ok=True)
    sc = bpy.context.scene
    costruisci()
    sc.render.filepath = os.path.join(OUT, "render_casa_staccionata.png")
    bpy.ops.render.render(write_still=True)
    cv.modo_luci()
    sc.render.filepath = os.path.join(OUT, "luci_casa_staccionata.png")
    bpy.ops.render.render(write_still=True)
    print("CASA", sc.render.resolution_x, sc.render.resolution_y)


if __name__ == "__main__":
    renderizza()
