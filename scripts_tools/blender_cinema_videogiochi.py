"""Costruisce in Blender il cinema e il negozio di videogiochi del COMMERCIAL
DISTRICT: due unita' attaccate, renderizzate separate.

Presi da una foto di due edifici affiancati su una via del centro:

  * **il negozio di videogiochi**, a sinistra: moderno, rivestito di pannelli
    grigi, con la vetrina al piano terra, l'ingresso arretrato a doppia porta
    di vetro, e sopra una grande vetrata a griglia accanto a un cartellone. La
    fascia in cima con la striscia al neon verde;
  * **il cinema**, a destra: una sala d'epoca, lesene di pietra ai lati,
    cornicione con le mensole, la finestra in mezzo, e soprattutto la pensilina
    che sporge sul marciapiede, bordata di lampadine, sopra alle porte di legno
    e alle bacheche delle locandine.

**Poche scritte, grandi**: quelle che servono a capire cosa sono ("GAME
ZONE" e "VIDEO GAMES" sul negozio, "CINEMA" sulla pensilina e "PALACE" nella
cornice dorata). All'inizio non ce n'erano; senza, da lontano erano due
facciate qualunque. I cartelloni restano grafica. Niente arredo stradale,
niente marciapiede.

## Due unita', una struttura

Come l'isolato cinese (`blender_isolato_cinese.py`): in gioco sono due edifici
che si cliccano separatamente, quindi due PNG — ognuno largo esattamente il suo
lotto (`inquadra()`), cosi' rimessi uno accanto all'altro i muri si toccano. Si
leggono come una struttura sola perche' hanno la stessa zoccolatura di pietra
scura, lo stesso muro divisorio e la stessa linea di gronda a 10,2 m, sopra
alla quale sale solo il coronamento del cinema.

## Le animazioni

  * `lampadine` — le lampadine della pensilina: ogni tanto fanno la "corsa"
    (tre fasi che si rincorrono), poi un lampo di tutte insieme, e si fermano
    accese;
  * `schermi` — la parete di televisori dietro alla vetrata del negozio, che
    cambia immagine di continuo.

Si fotografano come quelle della casa gialla (`render_buildings.py`): gli
oggetti che si muovono spariscono dal disegno e dallo scatto delle luci, e si
rifotografano da soli, fotogramma per fotogramma, col resto in "holdout". Sono
luci, quindi in gioco restano accese anche di notte (`emissive` nella voce).

Uso:
  blender --background --factory-startup --python scripts_tools/blender_cinema_videogiochi.py
  python scripts_tools/import_flats_art.py
"""

import math
import os
import random

import bmesh
import bpy
from mathutils import Vector

INCLINAZIONE = 27.0
PX_PER_METRO = 22.3
SUPERSAMPLING = 4
COLL_TESTI = "SenzaContorno"

try:
    HERE = os.path.dirname(os.path.abspath(__file__))
except NameError:
    HERE = os.path.join(os.getcwd(), "scripts_tools")
OUT = os.path.abspath(os.path.join(HERE, os.pardir, "assets", "sprites",
                                   "buildings", "_source"))

# Le unita' da sinistra, e la larghezza del lotto in metri. 8,6 e 11,4 fanno
# 192 e 254 px: venti metri di fronte, 446 px, e restano 200 px d'isolato per il
# parcheggio accanto.
UNITA = [("videogiochi", 8.6), ("cinema", 11.4)]
# Nove metri e non quattordici: da 27 gradi ogni metro di profondita' e'
# mezzo metro di tetto nello sprite, e a quattordici il tetto grigio si
# prendeva meta' disegno.
PROF = 9.0              # profondita' di tutte e due
H_GRONDA = 10.2         # la linea comune
H_CINEMA = 12.4         # il coronamento del cinema sale sopra
ZOCCOLO = 0.55


# ----------------------------------------------------------------------
#  materiali
# ----------------------------------------------------------------------

def srgb(hexstr, alpha=1.0):
    h = hexstr.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    out.append(alpha)
    return tuple(out)


def _bsdf(mat):
    return next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")


def _set(node, name, value):
    if name in node.inputs:
        try:
            node.inputs[name].default_value = value
        except (TypeError, ValueError):
            pass


def _fresh(name):
    old = bpy.data.materials.get(name)
    if old:
        bpy.data.materials.remove(old)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    return mat


def piatto(name, hexcol, rough=0.85, metal=0.0, emissivo=None, forza=0.0):
    mat = _fresh(name)
    b = _bsdf(mat)
    _set(b, "Base Color", srgb(hexcol))
    _set(b, "Roughness", rough)
    _set(b, "Metallic", metal)
    if emissivo:
        _set(b, "Emission Color", srgb(emissivo))
        _set(b, "Emission Strength", forza)
    return mat


def righe(name, chiaro, scuro, passo, asse="Z", rough=0.7, frazione=0.1):
    """Righe dalla posizione nel mondo: bugnato della pietra, giunti dei
    pannelli. Nel mondo e non nell'oggetto, cosi' dopo l'unione restano
    allineate da un pezzo all'altro."""
    mat = _fresh(name)
    N, L = mat.node_tree.nodes, mat.node_tree.links
    b = _bsdf(mat)
    geo = N.new("ShaderNodeNewGeometry")
    sep = N.new("ShaderNodeSeparateXYZ")
    L.new(geo.outputs["Position"], sep.inputs[0])
    div = N.new("ShaderNodeMath")
    div.operation = "DIVIDE"
    div.inputs[1].default_value = passo
    L.new(sep.outputs[asse], div.inputs[0])
    fr = N.new("ShaderNodeMath")
    fr.operation = "FRACT"
    L.new(div.outputs[0], fr.inputs[0])
    soglia = N.new("ShaderNodeMath")
    soglia.operation = "LESS_THAN"
    soglia.inputs[1].default_value = frazione
    L.new(fr.outputs[0], soglia.inputs[0])
    mix = N.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    colori = [s for s in mix.inputs if s.type == "RGBA"]
    colori[0].default_value = srgb(chiaro)
    colori[1].default_value = srgb(scuro)
    L.new(soglia.outputs[0], mix.inputs[0])
    L.new([s for s in mix.outputs if s.type == "RGBA"][0], b.inputs["Base Color"])
    _set(b, "Roughness", rough)
    return mat


M = {}


def palette():
    M.clear()
    # --- in comune ---
    M["zoccolo"] = piatto("CV_Zoccolo", "#3E3B38", 0.8)
    M["guaina"] = piatto("CV_Guaina", "#6E6A61", 0.93)
    M["copertina"] = piatto("CV_Copertina", "#8E9498", 0.4, 0.7)
    M["macchina"] = piatto("CV_Macchina", "#9EA3A5", 0.5, 0.5)
    M["infisso"] = piatto("CV_Infisso", "#1E2225", 0.45, 0.5)
    M["vetro"] = piatto("CV_Vetro", "#2C4048", 0.3)
    M["vetro_acceso"] = piatto("CV_Vetro_Acceso", "#3A4A48", 0.1, emissivo="#E2D3AE", forza=1.05)
    M["vetrina"] = piatto("CV_Vetrina", "#33393B", 0.1, 0.2, emissivo="#AFC0C4", forza=0.6)
    # --- videogiochi ---
    M["pannello"] = righe("CV_Pannello", "#8E9297", "#72767B", 1.6, frazione=0.03)
    M["pannello_chiaro"] = righe("CV_Pannello_Chiaro", "#C9CCCF", "#AEB1B5", 1.6, frazione=0.03)
    M["bianco"] = piatto("CV_Bianco", "#E3E4E2", 0.6)
    M["fascia_scura"] = piatto("CV_Fascia_Scura", "#26282B", 0.5, 0.3)
    M["neon_verde"] = piatto("CV_Neon_Verde", "#3FCB52", 0.4, emissivo="#58F06C", forza=2.2)
    M["scritta_bianca"] = piatto("CV_Scritta_Bianca", "#F2F2EE", 0.5, emissivo="#F2F2EE", forza=0.4)
    M["scritta_oro"] = piatto("CV_Scritta_Oro", "#E8C45A", 0.35, 0.6, emissivo="#F0D070", forza=0.8)
    M["rosso"] = piatto("CV_Rosso", "#C0302A", 0.5)
    M["cartellone_a"] = piatto("CV_Cartellone_A", "#E8A13A", 0.7)
    M["cartellone_b"] = piatto("CV_Cartellone_B", "#EEE7D6", 0.7)
    M["cartellone_c"] = piatto("CV_Cartellone_C", "#F2C84A", 0.7)
    M["interno"] = piatto("CV_Interno", "#1B2226", 0.8)
    # --- cinema ---
    M["pietra"] = righe("CV_Pietra", "#CBBE9F", "#A89B7E", 0.42, frazione=0.07)
    M["facciata"] = righe("CV_Facciata", "#5A524A", "#4A433C", 0.42, frazione=0.05)
    M["cornice"] = piatto("CV_Cornice", "#B7A988", 0.8)
    M["pensilina"] = piatto("CV_Pensilina", "#29372F", 0.55, 0.4)
    M["oro"] = piatto("CV_Oro", "#B08A3E", 0.35, 0.8)
    M["bordeaux"] = piatto("CV_Bordeaux", "#5E1F25", 0.7)
    M["legno"] = righe("CV_Legno", "#6A3C22", "#55301A", 0.18, asse="X", frazione=0.1)
    M["locandina_a"] = piatto("CV_Locandina_A", "#6E2A26", 0.7, emissivo="#9A5A3A", forza=0.35)
    M["locandina_b"] = piatto("CV_Locandina_B", "#27425A", 0.7, emissivo="#5A7A9A", forza=0.35)
    M["cartello_oro"] = piatto("CV_Cartello_Oro", "#C9A548", 0.5, 0.4)
    # --- animati ---
    for k in range(3):
        M["lampadina%d" % k] = piatto("CV_Lampadina%d" % k, "#F4E2B0", 0.3,
                                      emissivo="#FFE6A0", forza=3.0)
    for k in range(6):
        M["schermo%d" % k] = piatto("CV_Schermo%d" % k, "#20303A", 0.3,
                                    emissivo="#40A0E0", forza=1.5)


# ----------------------------------------------------------------------
#  geometria
# ----------------------------------------------------------------------

PEZZI = []
SOTTILI = []
FONT = "C:/Windows/Fonts/arialbd.ttf"


def testo(nome, stringa, x, y, z, altezza, mat):
    """Una scritta sulla facciata. Sta in una collezione senza contorno: con la
    linea Freestyle intorno a ogni lettera, a nove pixel d'altezza, le lettere
    si impastano."""
    cu = bpy.data.curves.new(nome, "FONT")
    cu.body = stringa
    cu.size = altezza
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    cu.extrude = 0.02
    if os.path.isfile(FONT):
        cu.font = bpy.data.fonts.load(FONT, check_existing=True)
    ob = bpy.data.objects.new(nome, cu)
    coll = bpy.data.collections.get(COLL_TESTI) or bpy.data.collections.new(COLL_TESTI)
    if coll.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(coll)
    coll.objects.link(ob)
    ob.data.materials.append(M[mat])
    ob.location = (x, y, z)
    ob.rotation_euler = (math.radians(90), 0, 0)
    return ob


def bx(nome, x0, x1, y0, y1, z0, z1, mat, sottile=False, raccolta=None):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x = x0 if v.co.x < 0 else x1
        v.co.y = y0 if v.co.y < 0 else y1
        v.co.z = z0 if v.co.z < 0 else z1
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(M[mat])
    ob = bpy.data.objects.new(nome, me)
    bpy.context.scene.collection.objects.link(ob)
    if raccolta is not None:
        raccolta.append(ob)
    else:
        (SOTTILI if sottile else PEZZI).append(ob)
    return ob


def sfera(nome, centro, r, mat, raccolta):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=5, radius=r)
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(M[mat])
    ob = bpy.data.objects.new(nome, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = centro
    raccolta.append(ob)
    return ob


def finestra(nome, x0, x1, z0, z1, y, vetro, montanti=1, traversi=0, t=0.07):
    """Vetro appena davanti al filo del muro e telaio davanti al vetro: i muri
    sono scatole piene (vedi la nota in `blender_holly_lofts.py`)."""
    bx(nome + "_v", x0, x1, y - 0.035, y - 0.005, z0, z1, vetro)
    a0, a1 = y - 0.075, y - 0.005
    bx(nome + "_s0", x0 - t, x0, a0, a1, z0 - t, z1 + t, "infisso")
    bx(nome + "_s1", x1, x1 + t, a0, a1, z0 - t, z1 + t, "infisso")
    bx(nome + "_sg", x0, x1, a0, a1, z0 - t, z0, "infisso")
    bx(nome + "_ss", x0, x1, a0, a1, z1, z1 + t, "infisso")
    for i in range(1, montanti):
        xm = x0 + (x1 - x0) * i / montanti
        bx(f"{nome}_m{i}", xm - t / 2, xm + t / 2, a0 + 0.01, a1, z0, z1, "infisso")
    for i in range(1, traversi + 1):
        zm = z0 + (z1 - z0) * i / (traversi + 1)
        bx(f"{nome}_t{i}", x0, x1, a0 + 0.01, a1, zm - t / 2, zm + t / 2, "infisso")


def unisci(pezzi, nome):
    if not pezzi:
        return None
    base = pezzi[0]
    with bpy.context.temp_override(active_object=base, selected_editable_objects=list(pezzi),
                                   selected_objects=list(pezzi)):
        bpy.ops.object.join()
    base.name = nome
    return base


# ----------------------------------------------------------------------
#  le due unita'
# ----------------------------------------------------------------------

def guscio(x0, x1, h, mat_muro):
    """Scatola, zoccolo, tetto piano e parapetto: la parte uguale per tutte e
    due, ed e' quella che le fa sembrare lo stesso fabbricato."""
    bx("corpo", x0, x1, 0.0, PROF, 0.0, h, mat_muro)
    bx("zoccolo", x0, x1, -0.02, 0.2, 0.0, ZOCCOLO, "zoccolo")
    bx("tetto", x0 + 0.3, x1 - 0.3, 0.3, PROF - 0.3, h, h + 0.1, "guaina")
    for nome, a, b, c, d in (("par_f", x0, x1, 0.0, 0.3), ("par_r", x0, x1, PROF - 0.3, PROF),
                             ("par_s", x0, x0 + 0.3, 0.0, PROF), ("par_d", x1 - 0.3, x1, 0.0, PROF)):
        bx(nome, a, b, c, d, h, h + 0.6, mat_muro)
        bx(nome + "_cop", a, b, c - (0.05 if nome == "par_f" else 0), d, h + 0.6, h + 0.68, "copertina")


def videogiochi(x0, x1, rnd, animati):
    h = H_GRONDA
    guscio(x0, x1, h, "pannello")
    W = x1 - x0
    # Lesena bianca a destra, dall'alto in basso, come nella foto.
    bx("lesena", x1 - 0.55, x1, -0.12, 0.0, 0.0, h + 0.6, "bianco")
    bx("lesena_sx", x0, x0 + 0.3, -0.08, 0.0, 0.0, h + 0.6, "pannello_chiaro")
    # --- piano terra: vetrina a sinistra, ingresso arretrato a destra ---
    pt = 4.5
    bx("fascia_pt", x0 + 0.3, x1 - 0.55, -0.2, 0.0, pt - 1.0, pt, "pannello_chiaro")
    bx("fascia_pt_riga", x0 + 0.6, x0 + 5.0, -0.23, -0.2, pt - 0.95, pt - 0.87, "rosso")
    testo("scritta_pt", "VIDEO GAMES", x0 + 2.8, -0.24, pt - 0.47, 0.5, "rosso")
    finestra("vetrina", x0 + 0.45, x0 + 4.9, ZOCCOLO, pt - 1.1, 0.0, "vetrina", montanti=3)
    # L'ingresso, sul filo della facciata: i muri sono scatole piene, e una
    # nicchia scavata "dietro" al muro finiva dentro allo spessore e non si
    # vedeva. La cornice sporgente gli da' comunque l'aria di un vano.
    ix0, ix1 = x0 + 5.3, x1 - 0.75
    bx("ingresso_cornice", ix0, ix1, -0.25, 0.0, pt - 1.1, pt - 1.0, "pannello_chiaro")
    finestra("porte", ix0 + 0.2, ix1 - 0.2, 0.05, 2.7, 0.0, "vetrina", montanti=2)
    bx("maniglie", (ix0 + ix1) / 2 - 0.2, (ix0 + ix1) / 2 + 0.2, -0.14, -0.1, 1.1, 1.3, "copertina")
    # Sopra la porta, un sopraluce.
    finestra("sopraluce", ix0 + 0.2, ix1 - 0.2, 2.85, pt - 1.2, 0.0, "vetro", montanti=2)
    # --- primo livello: vetrata a griglia a sinistra, cartellone a destra ---
    z0, z1 = pt + 0.4, h - 1.4
    bx("vetrata_fondo", x0 + 0.5, x0 + 4.6, -0.02, 0.0, z0, z1, "interno")
    # La parete di schermi DIETRO alla vetrata: e' l'animazione.
    for i in range(3):
        for j in range(2):
            k = j * 3 + i
            sx0 = x0 + 0.8 + i * 1.25
            sz0 = z0 + 0.5 + j * 1.35
            bx("schermo_cornice%d" % k, sx0 - 0.06, sx0 + 1.06, -0.05, -0.02, sz0 - 0.06, sz0 + 0.86,
               "fascia_scura")
            bx("schermo%d" % k, sx0, sx0 + 1.0, -0.07, -0.05, sz0, sz0 + 0.8, "schermo%d" % k,
               raccolta=animati)
    finestra("vetrata", x0 + 0.5, x0 + 4.6, z0, z1, -0.12, "vetro", montanti=3, traversi=1)
    # Il vetro della vetrata e' mezzo trasparente: si vedono gli schermi dietro.
    # (Si ottiene non mettendo la lastra: il telaio basta a dire "vetrata".)
    for ob in list(PEZZI):
        if ob.name.startswith("vetrata_v"):
            PEZZI.remove(ob)
            bpy.data.objects.remove(ob, do_unlink=True)
    # Il cartellone: grafica e niente parole. Un triangolo arancio su fondo chiaro
    # e un cerchio giallo, cioe' la composizione della foto senza la scritta.
    cx0, cx1 = x0 + 4.95, x1 - 0.7
    bx("cart_fondo", cx0, cx1, -0.1, 0.0, z0, z1 + 0.2, "cartellone_b")
    me = bpy.data.meshes.new("cart_tri")
    me.from_pydata([(cx0, -0.11, z0), (cx1, -0.11, z0), (cx0, -0.11, z1 - 0.4)], [], [(0, 1, 2)])
    me.materials.append(M["cartellone_a"])
    ob = bpy.data.objects.new("cart_tri", me)
    bpy.context.scene.collection.objects.link(ob)
    PEZZI.append(ob)
    bx("cart_tondo", cx0 + 0.5, cx0 + 1.2, -0.12, -0.11, z0 + 0.6, z0 + 1.3, "cartellone_c")
    # --- in cima: la fascia scura dell'insegna, con la riga al neon ---
    bx("insegna", x0 + 1.2, x0 + 6.0, -0.35, 0.0, h - 1.2, h + 0.3, "fascia_scura")
    bx("insegna_neon", x0 + 1.3, x0 + 5.9, -0.4, -0.35, h - 1.2, h - 1.08, "neon_verde")
    testo("scritta_insegna", "GAME ZONE", x0 + 3.6, -0.4, h - 0.45, 0.62, "neon_verde")
    # Tetto.
    bx("macchina", x0 + 2.0, x0 + 4.0, 4.0, 6.0, h + 0.1, h + 1.0, "macchina")


def cinema(x0, x1, rnd, animati):
    h = H_GRONDA
    W = x1 - x0
    guscio(x0, x1, h, "facciata")
    # Le lesene di pietra ai lati, a tutta altezza, e il coronamento sopra.
    for k, (a, b) in enumerate(((x0, x0 + 1.5), (x1 - 1.5, x1))):
        bx("lesena%d" % k, a, b, -0.3, 0.0, 0.0, H_CINEMA, "pietra")
        bx("capitello%d" % k, a - 0.05, b + 0.05, -0.45, 0.0, H_CINEMA - 0.9, H_CINEMA - 0.6, "cornice")
    # Il coronamento: il muro sale fino a H_CINEMA, col cornicione a mensole.
    bx("coronamento", x0 + 1.5, x1 - 1.5, 0.0, 1.0, h, H_CINEMA, "facciata")
    bx("cornicione", x0 - 0.1, x1 + 0.1, -0.6, 0.4, H_CINEMA, H_CINEMA + 0.35, "cornice")
    for i in range(12):
        x = x0 + 0.3 + (W - 0.6) * i / 11
        bx("mensola%d" % i, x - 0.12, x + 0.12, -0.5, -0.3, H_CINEMA - 0.35, H_CINEMA, "cornice")
    bx("corona_tetto", x0, x1, 0.4, 1.2, H_CINEMA, H_CINEMA + 0.25, "guaina")
    # La finestra in mezzo, di legno, e il cartello dorato sopra (vuoto: e' la
    # cornice di una locandina, la locandina non c'e').
    xm = (x0 + x1) / 2
    bx("cartello", xm - 2.2, xm + 2.2, -0.2, 0.0, 8.55, 9.95, "cartello_oro")
    bx("cartello_dentro", xm - 1.95, xm + 1.95, -0.22, -0.2, 8.7, 9.8, "bordeaux")
    testo("scritta_palace", "PALACE", xm, -0.24, 9.25, 0.75, "scritta_oro")
    for s in (-1, 1):
        bx("cartello_asta%d" % s, xm + s * 2.35 - 0.06, xm + s * 2.35 + 0.06, -0.25, -0.1, 8.3, 10.1, "oro")
    bx("fin_legno", xm - 1.1, xm + 1.1, -0.12, 0.0, 6.8, 8.35, "legno")
    finestra("fin", xm - 0.9, xm + 0.9, 6.95, 8.2, -0.12, "vetro_acceso", montanti=2, traversi=1)
    # --- la pensilina ---
    px0, px1 = x0 + 0.9, x1 - 0.9
    # Alta e poco profonda: da 27 gradi una pensilina di due metri e mezzo a
    # quattro metri si mangiava porte e bacheche.
    pz0, pz1 = 5.0, 6.0
    py = -1.6
    bx("pens_tetto", px0, px1, py, 0.0, pz1 - 0.15, pz1, "pensilina")
    bx("pens_fronte", px0, px1, py - 0.1, py, pz0, pz1, "pensilina")
    bx("pens_fascia", px0 + 0.4, px1 - 0.4, py - 0.14, py - 0.1, pz0 + 0.22, pz1 - 0.22, "bordeaux")
    testo("scritta_cinema", "CINEMA", (px0 + px1) / 2, py - 0.16, (pz0 + pz1) / 2, 0.5, "scritta_oro")
    bx("pens_oro_su", px0, px1, py - 0.16, py - 0.1, pz1 - 0.12, pz1 - 0.04, "oro")
    bx("pens_oro_giu", px0, px1, py - 0.16, py - 0.1, pz0 + 0.04, pz0 + 0.12, "oro")
    for s, x in ((-1, px0), (1, px1)):
        bx("pens_fianco%d" % s, x - 0.05, x + 0.05, py - 0.1, 0.0, pz0, pz1, "pensilina")
    bx("pens_cielo", px0, px1, py, 0.0, pz0, pz0 + 0.12, "oro")
    # Le crestine sopra alla pensilina, come nella foto.
    n = 16
    for i in range(n):
        x = px0 + 0.2 + (px1 - px0 - 0.4) * i / (n - 1)
        bx("cresta%d" % i, x - 0.07, x + 0.07, py + 0.1, py + 0.3, pz1, pz1 + 0.28, "oro")
    # Le lampadine: una fila sotto, sul bordo della pensilina, e una sopra.
    # Tre materiali, uno per fase della corsa.
    for fila, z in enumerate((pz0 - 0.08, pz1 + 0.06)):
        m = 20
        for i in range(m):
            x = px0 + 0.25 + (px1 - px0 - 0.5) * i / (m - 1)
            sfera("lamp_%d_%d" % (fila, i), (x, py - 0.2, z), 0.075, "lampadina%d" % (i % 3),
                  animati)
    # --- piano terra: porte di legno e bacheche ---
    pt = 5.0
    bx("pt_fondo", px0, px1, -0.06, 0.0, 0.0, pt, "legno")
    nporte = 4
    larg = (px1 - px0 - 3.2) / nporte
    for i in range(nporte):
        a = px0 + 1.6 + i * larg
        finestra("porta%d" % i, a + 0.1, a + larg - 0.1, 0.1, 2.8, -0.06, "vetro_acceso", montanti=2)
        bx("porta_sopra%d" % i, a + 0.1, a + larg - 0.1, -0.12, -0.06, 2.95, pt - 0.3, "legno")
        bx("porta_legno%d" % i, a + 0.1, a + larg - 0.1, -0.16, -0.12, 0.1, 1.2, "legno")
    for k, a in enumerate((px0 + 0.2, px1 - 1.3)):
        bx("bacheca%d" % k, a, a + 1.1, -0.2, -0.06, 0.6, 3.2, "oro")
        bx("locandina%d" % k, a + 0.1, a + 1.0, -0.22, -0.2, 0.75, 3.05,
           "locandina_a" if k == 0 else "locandina_b")
    # Tetto.
    bx("macchina", x0 + 3.5, x0 + 6.0, 6.0, 8.0, h + 0.1, h + 1.1, "macchina")


# ----------------------------------------------------------------------
#  costruzione, scena, scatti
# ----------------------------------------------------------------------

def quote():
    """Le fette delle unita' da sinistra: x0 e x1 di ognuna, in metri."""
    fette, x = {}, 0.0
    for chiave, w in UNITA:
        fette[chiave] = (x, x + w)
        x += w
    return fette


def costruisci(chiave):
    # Prima le linee di Freestyle: tengono un riferimento alla collezione delle
    # scritte, e toglierla sotto di loro fa protestare Blender.
    fs = bpy.context.view_layer.freestyle_settings
    for ls in list(fs.linesets):
        fs.linesets.remove(ls)
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for c in list(bpy.data.collections):
        bpy.data.collections.remove(c)
    PEZZI.clear()
    SOTTILI.clear()
    palette()
    rnd = random.Random(31)
    x0, x1 = quote()[chiave]
    animati = []
    (videogiochi if chiave == "videogiochi" else cinema)(x0, x1, rnd, animati)
    unisci(PEZZI, "CV_" + chiave)
    if SOTTILI:
        unisci(SOTTILI, "CV_%s_ferri" % chiave)
    cam = scena()
    for ob in animati:
        ob.hide_render = True
    inquadra(cam, x0, x1)
    return animati


def scena():
    sc = bpy.context.scene
    dati = bpy.data.cameras.new("CAM_Front")
    dati.type = "ORTHO"
    dati.clip_start, dati.clip_end = 0.1, 800.0
    cam = bpy.data.objects.new("CAM_Front", dati)
    sc.collection.objects.link(cam)
    cam.rotation_euler = (math.radians(90.0 - INCLINAZIONE), 0.0, 0.0)
    sc.camera = cam
    for nome, en, col, rot, ang in (("SUN", 3.2, (1.0, 0.96, 0.9), (52, 0, -18), 1.0),
                                    ("FILL", 1.15, (0.72, 0.8, 0.95), (104, 0, 26), 35.0)):
        l = bpy.data.lights.new(nome, type="SUN")
        l.energy = en
        l.color = col
        l.angle = math.radians(ang)
        ob = bpy.data.objects.new(nome, l)
        sc.collection.objects.link(ob)
        ob.rotation_euler = tuple(math.radians(r) for r in rot)
    mondo = bpy.data.worlds.get("World") or bpy.data.worlds.new("World")
    sc.world = mondo
    mondo.use_nodes = True
    N, L = mondo.node_tree.nodes, mondo.node_tree.links
    N.clear()
    uscita = N.new("ShaderNodeOutputWorld")
    sfondo = N.new("ShaderNodeBackground")
    sfondo.inputs["Color"].default_value = srgb("#93A9BE")
    _set(sfondo, "Strength", 1.05)
    L.new(sfondo.outputs["Background"], uscita.inputs["Surface"])
    try:
        sc.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        sc.render.engine = "BLENDER_EEVEE"
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    for attr, val in [("taa_render_samples", 96), ("use_raytracing", True),
                      ("use_shadows", True)]:
        if hasattr(sc.eevee, attr):
            setattr(sc.eevee, attr, val)
    sc.view_settings.view_transform = "Standard"
    sc.render.use_freestyle = True
    sc.render.line_thickness_mode = "ABSOLUTE"
    fs = bpy.context.view_layer.freestyle_settings
    fs.mode = "EDITOR"
    for ls in list(fs.linesets):
        fs.linesets.remove(ls)
    fs.crease_angle = math.radians(85.0)
    fuori = fs.linesets.new("Contorno")
    for a in ("select_crease", "select_ridge_valley", "select_suggestive_contour",
              "select_material_boundary", "select_edge_mark"):
        setattr(fuori, a, False)
    fuori.select_silhouette = True
    fuori.select_border = True
    fuori.linestyle.color = (0.030, 0.023, 0.019)
    fuori.linestyle.thickness = 2.4
    dentro = fs.linesets.new("Spigoli")
    for a in ("select_silhouette", "select_border", "select_ridge_valley",
              "select_suggestive_contour", "select_material_boundary", "select_edge_mark"):
        setattr(dentro, a, False)
    dentro.select_crease = True
    dentro.linestyle.color = (0.075, 0.058, 0.046)
    dentro.linestyle.alpha = 0.45
    dentro.linestyle.thickness = 1.2
    coll = bpy.data.collections.get(COLL_TESTI)
    if coll:
        for ls in (fuori, dentro):
            ls.select_by_collection = True
            ls.collection = coll
            ls.collection_negation = "EXCLUSIVE"
    return cam


def inquadra(cam, x0, x1, margine=0.30):
    """In orizzontale ESATTAMENTE il lotto (vedi `blender_isolato_cinese.py`):
    rimessi in fila in gioco, i due sprite si toccano dove si toccano i muri.
    Quello che sporge oltre il lotto — il cornicione del cinema — resta tagliato
    a filo, ed e' giusto: sporge sopra al vicino, che e' lo stesso fabbricato."""
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    punti = []
    for obj in bpy.data.objects:
        if obj.type != "MESH" or obj.hide_render:
            continue
        val = obj.evaluated_get(dg)
        for v in val.data.vertices:
            punti.append(obj.matrix_world @ v.co)
    inv = cam.matrix_world.inverted()
    vista = [inv @ p for p in punti]
    miny, maxy = min(p.y for p in vista), max(p.y for p in vista)
    larg = x1 - x0
    alt = (maxy - miny) + 2 * margine
    cam.location = cam.matrix_world @ Vector(((x0 + x1) / 2.0, (miny + maxy) / 2.0, 300.0))
    # Ortografica: la scala vale sul lato lungo. Il riquadro e' piu' alto che
    # largo, quindi vale l'altezza, e la larghezza in pixel viene da se'.
    cam.data.ortho_scale = max(larg, alt)
    cam.data.sensor_fit = "AUTO"
    sc = bpy.context.scene
    sc.render.resolution_x = int(round(larg * PX_PER_METRO))
    sc.render.resolution_y = int(round(alt * PX_PER_METRO))
    sc.render.resolution_percentage = SUPERSAMPLING * 100


def modo_luci():
    sc = bpy.context.scene
    sc.render.use_freestyle = False
    for luce in bpy.data.lights:
        luce.energy = 0.0
    for nodo in sc.world.node_tree.nodes:
        if nodo.type == "BACKGROUND":
            _set(nodo, "Strength", 0.0)
    for mat in bpy.data.materials:
        if not mat.use_nodes or mat.node_tree is None:
            continue
        bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        acceso = None
        if bsdf is not None and float(bsdf.inputs["Emission Strength"].default_value) > 0.001:
            acceso = tuple(bsdf.inputs["Emission Color"].default_value)
        N, L = mat.node_tree.nodes, mat.node_tree.links
        N.clear()
        uscita = N.new("ShaderNodeOutputMaterial")
        if acceso is None:
            nero = N.new("ShaderNodeBsdfDiffuse")
            nero.inputs["Color"].default_value = (0.0, 0.0, 0.0, 1.0)
            L.new(nero.outputs[0], uscita.inputs["Surface"])
        else:
            em = N.new("ShaderNodeEmission")
            em.inputs["Color"].default_value = acceso
            L.new(em.outputs[0], uscita.inputs["Surface"])


# --- le pose delle animazioni ---------------------------------------------

# La corsa delle lampadine, fotogramma per fotogramma: quali delle tre fasi
# sono accese. Il primo e' la posa di riposo (tutte accese), poi tre giri di
# corsa, un buio, un lampo, e di nuovo tutte accese.
CORSA = ([(1, 1, 1)] + [(1, 0, 0), (0, 1, 0), (0, 0, 1)] * 3
         + [(0, 0, 0), (1, 1, 1), (0, 0, 0), (1, 1, 1)])

# La parete di schermi: ogni fotogramma una combinazione di colori, come una
# vetrina di televisori che mostrano giochi diversi.
COLORI_SCHERMI = ["#40A0E0", "#E0503C", "#50D060", "#F0C040", "#A060E0", "#40E0D0",
                  "#F07AB0", "#E0E0E0"]


def posa(chiave, i):
    if chiave == "cinema":
        fase = CORSA[i]
        for k in range(3):
            _set(_bsdf(M["lampadina%d" % k]), "Emission Strength", 4.0 if fase[k] else 0.15)
        return
    rnd = random.Random(100 + i)
    for k in range(6):
        col = srgb(rnd.choice(COLORI_SCHERMI))
        _set(_bsdf(M["schermo%d" % k]), "Emission Color", col)
        _set(_bsdf(M["schermo%d" % k]), "Emission Strength", 1.2 + rnd.random() * 0.8)


ANIM = {"cinema": ("lampadine", len(CORSA)), "videogiochi": ("schermi", 8)}


def renderizza():
    os.makedirs(OUT, exist_ok=True)
    sc = bpy.context.scene
    for chiave, _ in UNITA:
        costruisci(chiave)
        sc.render.filepath = os.path.join(OUT, "render_%s.png" % chiave)
        bpy.ops.render.render(write_still=True)
        modo_luci()
        sc.render.filepath = os.path.join(OUT, "luci_%s.png" % chiave)
        bpy.ops.render.render(write_still=True)
        # Le animazioni: si ricostruisce (le luci hanno riscritto i materiali),
        # si nasconde tutto in holdout e si fotografano da sole.
        animati = costruisci(chiave)
        for ob in bpy.data.objects:
            # Anche le scritte: se no finirebbero dentro ai fotogrammi, sopra
            # al disegno, e di notte resterebbero accese due volte.
            if ob.type in ("MESH", "FONT"):
                ob.is_holdout = ob not in animati
        for ob in animati:
            ob.hide_render = False
        # Niente contorni sugli animati: sono lampadine e schermi, luce e basta.
        sc.render.use_freestyle = False
        cosa, n = ANIM[chiave]
        for i in range(n):
            posa(chiave, i)
            sc.render.filepath = os.path.join(OUT, "anim_%s_%s_%02d.png" % (chiave, cosa, i))
            bpy.ops.render.render(write_still=True)
        print("CV", chiave, sc.render.resolution_x, sc.render.resolution_y)


if __name__ == "__main__":
    renderizza()
