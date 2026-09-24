"""Costruisce in Blender le quattro stanze di casa e le renderizza con le loro
animazioni: ingresso, cucina, cantina e garage.

Prende il posto dei quattro fondali disegnati (`ingressoback.png`,
`kitchenBack.png`, `basementBack.png`, `garageBack.png`), da cui riprende la
disposizione: stesso arredo, stessa luce calda, stesse inquadrature — di fronte
per ingresso e cucina, dall'alto in isometria per la cantina, dall'alto e di tre
quarti per il garage.

## Perche' generare invece di disegnare

La stessa ragione degli edifici (`render_buildings.py`): una stanza nuova e'
una funzione in `STANZE`, non un file da ridisegnare, e la luce, la palette e il
contorno nero li decide il codice una volta sola. In piu' una stanza costruita
sa DOVE stanno le sue cose: la finestra, il piano del tavolo su cui vanno i
vasi, il PC, il punto del pavimento su cui sta il protagonista. Quelle misure
sul disegno andavano prese a mano con una griglia sovrapposta; qui si
proiettano dalla camera e finiscono nel manifesto (`punti` in `<stanza>.json`).

## Come si muove un fondale

Il fondale resta un PNG fermo. Quello che si muove — il lampadario che dondola,
la fiamma della caldaia, la goccia del rubinetto — e' un oggetto a se' (o un
perno con dei figli) che una funzione mette in posa. Per ogni animazione si
renderizza TUTTA la stanza, una volta per posa, con le altre animazioni ferme
a riposo; `import_room_art.py` confronta ogni fotogramma col fondale fermo e
tiene solo i pixel che cambiano. Cosi' nel fotogramma c'e' anche quello che il
movimento si porta dietro: la pozza di luce del lampadario che scivola sul
pavimento, il riflesso della fiamma sul muro.

Tre tipi, e il tipo decide cosa sono i fotogrammi:

  * `dondolo` — i fotogrammi sono POSE, da tutto a sinistra (-1) a tutto a
    destra (+1), con quella centrale a riposo. Il gioco non li scorre in fila:
    calcola l'angolo con un'oscillazione smorzata e prende la posa piu' vicina.
    Undici pose bastano per un dondolio di qualunque ampiezza e durata, ed e'
    il motivo per cui ogni volta che il lampadario parte il dondolio e' diverso;
  * `ciclo` — fotogrammi in fila, sempre, senza pausa (la fiamma, il vapore);
  * `evento` — fotogrammi in fila, una volta, poi una pausa a caso (la goccia,
    il ragno). Il primo fotogramma e' la posa di riposo.

Uso:
  blender --background --factory-startup --python scripts_tools/blender_stanze.py -- ingresso
  blender ... -- tutte
  blender ... -- cucina --solo-fondale        (senza animazioni, per provare)
  python scripts_tools/import_room_art.py
"""

import json
import math
import os
import random
import sys

import bmesh
import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Euler, Vector

try:
    HERE = os.path.dirname(os.path.abspath(__file__))
except NameError:
    HERE = os.path.join(os.getcwd(), "scripts_tools")
if os.path.basename(HERE) != "scripts_tools":
    HERE = os.path.join(os.getcwd(), "scripts_tools")
OUT = os.path.abspath(os.path.join(
    HERE, os.pardir, "assets", "sprites", "rooms", "_source"))

# La stanza si vede a 640x360, uno a uno: il `Backdrop` e' in "keep aspect
# covered" e con un PNG gia' in 16:9 non ritaglia niente, quindi un pixel del
# render ridotto e' un pixel di schermo e le coordinate del manifesto valgono
# direttamente per i nodi della scena.
LARGH, ALT = 640, 360
# Si renderizza al doppio e si riduce dopo: le linee del contorno a 1x escono a
# scalini, a 2x ridotte arrivano come un pixel pulito.
SUPERSAMPLING = 2

# Il protagonista delle stanze: `placeholdercharater.png` e' 39 px di figura per
# 1,75 m. Serve a ricavare la scala del `Character` dalla camera.
FIGURA_PX = 39.0
ALTEZZA_UOMO = 1.75

# ----------------------------------------------------------------------
#  colore e materiali
# ----------------------------------------------------------------------


def srgb(hexstr, alpha=1.0):
    """Da esadecimale a lineare: i socket colore di Blender vogliono lineare."""
    h = hexstr.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    out.append(alpha)
    return tuple(out)


def _set(node, name, value):
    if name in node.inputs:
        try:
            node.inputs[name].default_value = value
        except (TypeError, ValueError):
            pass


def _nuovo(name):
    old = bpy.data.materials.get(name)
    if old:
        bpy.data.materials.remove(old)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    return mat


def _bsdf(mat):
    return next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")


def _mix_rgb(N, fac_out, a, b, L):
    """Mix di colori, per socket e non per nome: il nodo Mix ha tre tipi di
    ingresso con lo stesso nome e cercarli per nome prende quello sbagliato."""
    n = N.new("ShaderNodeMix")
    n.data_type = "RGBA"
    n.clamp_factor = True
    colori = [s for s in n.inputs if s.type == "RGBA"]
    if isinstance(fac_out, float):
        n.inputs[0].default_value = fac_out
    else:
        L.new(fac_out, n.inputs[0])
    for sock, val in ((colori[0], a), (colori[1], b)):
        if isinstance(val, tuple):
            sock.default_value = val
        else:
            L.new(val, sock)
    return [s for s in n.outputs if s.type == "RGBA"][0]


def piatto(name, col, rough=0.8, metal=0.0, luce=None, forza=0.0, alpha=1.0):
    mat = _nuovo(name)
    b = _bsdf(mat)
    _set(b, "Base Color", srgb(col))
    _set(b, "Roughness", rough)
    _set(b, "Metallic", metal)
    if luce:
        _set(b, "Emission Color", srgb(luce))
        _set(b, "Emission Strength", forza)
    if alpha < 1.0:
        _set(b, "Alpha", alpha)
        # Dithered: con i campioni del TAA si media in una trasparenza
        # morbida, e non chiede di ordinare gli oggetti come il "blended".
        if hasattr(mat, "surface_render_method"):
            mat.surface_render_method = "DITHERED"
    return mat


def _rumore(N, L, coord, scala, dettaglio=5.0, stira=(1, 1, 1), seme=0.0):
    m = N.new("ShaderNodeMapping")
    _set(m, "Scale", stira)
    _set(m, "Location", (seme * 13.1, seme * 7.7, seme * 3.3))
    L.new(coord, m.inputs["Vector"])
    n = N.new("ShaderNodeTexNoise")
    _set(n, "Scale", scala)
    _set(n, "Detail", dettaglio)
    _set(n, "Roughness", 0.55)
    L.new(m.outputs["Vector"], n.inputs["Vector"])
    return n.outputs["Fac"]


def _soglia(N, L, val, da, a):
    r = N.new("ShaderNodeMapRange")
    r.clamp = True
    _set(r, "From Min", da)
    _set(r, "From Max", a)
    L.new(val, r.inputs["Value"])
    return r.outputs["Result"]


def macchiato(name, a, b, scala=3.0, da=0.35, a_=0.65, rough=0.85,
              macchie=None, stira=(1, 1, 1), metal=0.0, seme=0.0, luce=None,
              forza=0.0):
    """Due toni mescolati da un rumore, piu' eventuali macchie.

    `macchie` = (colore, scala, soglia, quanto): chiazze a bordo netto sopra al
    colore di base — l'umido sui muri, la ruggine, l'olio sul cemento. Il bordo
    netto (soglia stretta) e' quello che le fa leggere come macchie: sfumate
    diventano un muro sporco in modo uniforme.
    """
    mat = _nuovo(name)
    N, L = mat.node_tree.nodes, mat.node_tree.links
    b_ = _bsdf(mat)
    coord = N.new("ShaderNodeTexCoord").outputs["Object"]
    f = _soglia(N, L, _rumore(N, L, coord, scala, stira=stira, seme=seme), da, a_)
    col = _mix_rgb(N, f, srgb(a), srgb(b), L)
    if macchie:
        mcol, mscala, msoglia, quanto = macchie
        mf = _soglia(N, L, _rumore(N, L, coord, mscala, 6.0, seme=seme + 3.0),
                     msoglia, msoglia + 0.035)
        mul = N.new("ShaderNodeMath")
        mul.operation = "MULTIPLY"
        mul.inputs[1].default_value = quanto
        L.new(mf, mul.inputs[0])
        col = _mix_rgb(N, mul.outputs[0], col, srgb(mcol), L)
    L.new(col, b_.inputs["Base Color"])
    _set(b_, "Roughness", rough)
    _set(b_, "Metallic", metal)
    if luce:
        _set(b_, "Emission Color", srgb(luce))
        _set(b_, "Emission Strength", forza)
    return mat


def mattonelle(name, a, b, fuga, lato=0.4, largh=None, fuga_px=0.012,
               sfalsa=0.0, piano="xy", sporco=None, rough=0.7):
    """Mattonelle, mattoni o assi: e' sempre la stessa texture a mattoni.

    `piano` dice su quali due assi dell'oggetto si stende: "xy" per i
    pavimenti, "xz" per un muro che guarda la camera, "yz" per i muri di lato.
    `sporco` = (colore, scala, quanto) aggiunge sopra il rumore che rompe la
    ripetizione: senza, un pavimento di mattonelle identiche sembra carta da
    parati.
    """
    mat = _nuovo(name)
    N, L = mat.node_tree.nodes, mat.node_tree.links
    b_ = _bsdf(mat)
    coord = N.new("ShaderNodeTexCoord").outputs["Object"]
    sep = N.new("ShaderNodeSeparateXYZ")
    L.new(coord, sep.inputs[0])
    comb = N.new("ShaderNodeCombineXYZ")
    u, v = {"xy": ("X", "Y"), "xz": ("X", "Z"), "yz": ("Y", "Z")}[piano]
    L.new(sep.outputs[u], comb.inputs["X"])
    L.new(sep.outputs[v], comb.inputs["Y"])
    t = N.new("ShaderNodeTexBrick")
    t.offset = sfalsa
    t.offset_frequency = 2
    _set(t, "Color1", srgb(a))
    _set(t, "Color2", srgb(b))
    _set(t, "Mortar", srgb(fuga))
    _set(t, "Scale", 1.0)
    _set(t, "Mortar Size", fuga_px)
    _set(t, "Mortar Smooth", 0.1)
    _set(t, "Bias", 0.0)
    _set(t, "Brick Width", largh or lato)
    _set(t, "Row Height", lato)
    L.new(comb.outputs[0], t.inputs["Vector"])
    col = t.outputs["Color"]
    if sporco:
        scol, sscala, quanto = sporco
        f = _soglia(N, L, _rumore(N, L, coord, sscala, 6.0), 0.4, 0.75)
        mul = N.new("ShaderNodeMath")
        mul.operation = "MULTIPLY"
        mul.inputs[1].default_value = quanto
        L.new(f, mul.inputs[0])
        col = _mix_rgb(N, mul.outputs[0], col, srgb(scol), L)
    L.new(col, b_.inputs["Base Color"])
    _set(b_, "Roughness", rough)
    return mat


# ----------------------------------------------------------------------
#  geometria
# ----------------------------------------------------------------------

# Oggetti che non devono avere il contorno nero: vapore, gocce, luce finta.
SENZA_LINEE = "senza_linee"


def _collezione(nome):
    c = bpy.data.collections.get(nome)
    if c is None:
        c = bpy.data.collections.new(nome)
        bpy.context.scene.collection.children.link(c)
    return c


def _oggetto(name, bm, mat, loc, rot, parent, linee):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    if mat:
        me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    if linee:
        bpy.context.scene.collection.objects.link(ob)
    else:
        _collezione(SENZA_LINEE).objects.link(ob)
        # Gli effetti (vapore, gocce, la falena) non fanno ombra: una falena
        # a un palmo dalla lampadina proietterebbe una macchia grande come
        # un tavolo, e muovendosi sporcherebbe mezza stanza di fotogrammi.
        if hasattr(ob, "visible_shadow"):
            ob.visible_shadow = False
    ob.location = loc
    ob.rotation_euler = Euler(tuple(math.radians(r) for r in rot))
    if parent:
        ob.parent = parent
    return ob


def box(name, dim, loc, mat, rot=(0, 0, 0), parent=None, linee=True):
    """Parallelepipedo con l'origine al centro della faccia di SOTTO: i mobili
    si appoggiano al pavimento dando la quota zero, non meta' altezza."""
    sx, sy, sz = dim
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= sx
        v.co.y *= sy
        v.co.z = (v.co.z + 0.5) * sz
    return _oggetto(name, bm, mat, loc, rot, parent, linee)


def tornio(name, profilo, loc, mat, seg=20, chiudi=(True, True),
           rot=(0, 0, 0), parent=None, linee=True, scala=(1, 1, 1)):
    """Solido di rotazione da un profilo [(raggio, quota), ...] dal basso in
    alto: paralumi, vasi, bottiglie, pentole, secchi."""
    bm = bmesh.new()
    anelli = []
    for r, z in profilo:
        anello = []
        for i in range(seg):
            a = 2 * math.pi * i / seg
            anello.append(bm.verts.new((r * math.cos(a) * scala[0],
                                        r * math.sin(a) * scala[1], z * scala[2])))
        anelli.append(anello)
    for k in range(len(anelli) - 1):
        for i in range(seg):
            j = (i + 1) % seg
            bm.faces.new((anelli[k][i], anelli[k][j], anelli[k + 1][j], anelli[k + 1][i]))
    if chiudi[0] and profilo[0][0] > 0:
        bm.faces.new(list(reversed(anelli[0])))
    if chiudi[1] and profilo[-1][0] > 0:
        bm.faces.new(anelli[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _oggetto(name, bm, mat, loc, rot, parent, linee)


def cilindro(name, r, h, loc, mat, seg=16, rot=(0, 0, 0), parent=None, linee=True):
    return tornio(name, [(r, 0), (r, h)], loc, mat, seg, rot=rot, parent=parent, linee=linee)


def sfera(name, r, loc, mat, parent=None, linee=True, scala=(1, 1, 1), seg=12):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=max(6, seg // 2), radius=r)
    for v in bm.verts:
        v.co.x *= scala[0]
        v.co.y *= scala[1]
        v.co.z *= scala[2]
    return _oggetto(name, bm, mat, loc, (0, 0, 0), parent, linee)


def lastra(name, w, h, loc, mat, rot=(90, 0, 0), parent=None, linee=True,
           nx=1, nz=1):
    """Rettangolo sottile, in piedi e rivolto verso -Y (cioe' verso la camera
    delle stanze viste di fronte). `nx`, `nz` lo suddividono, per le tende."""
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=nx, y_segments=nz, size=0.5)
    for v in bm.verts:
        v.co.x *= w
        v.co.y = (v.co.y + 0.5) * h
    return _oggetto(name, bm, mat, loc, rot, parent, linee)


def perno(name, loc, parent=None):
    """Un Empty da far ruotare: tutto quello che gli si appende dondola con lui."""
    ob = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = loc
    if parent:
        ob.parent = parent
    return ob


def luce(name, tipo, loc, energia, colore, raggio=0.1, rot=(0, 0, 0),
         parent=None, dim=None, cono=None, portata=None):
    """`portata` taglia la luce oltre quei metri. Serve alle luci che
    tremolano: senza taglio anche il muro in fondo cambia di un livello a ogni
    fotogramma, e l'animazione si porta dietro tutta la stanza."""
    dati = bpy.data.lights.new(name, type=tipo)
    if portata and hasattr(dati, "use_custom_distance"):
        dati.use_custom_distance = True
        dati.cutoff_distance = portata
    dati.energy = energia
    dati.color = srgb(colore)[:3]
    if tipo in ("POINT", "SPOT"):
        dati.shadow_soft_size = raggio
    if tipo == "AREA" and dim:
        dati.shape = "RECTANGLE"
        dati.size, dati.size_y = dim
    if tipo == "SPOT" and cono:
        dati.spot_size = math.radians(cono)
        dati.spot_blend = 0.6
    if tipo == "SUN":
        dati.angle = math.radians(raggio)
    ob = bpy.data.objects.new(name, dati)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = loc
    ob.rotation_euler = Euler(tuple(math.radians(r) for r in rot))
    if parent:
        ob.parent = parent
    return ob


def testo(name, stringa, loc, mat, dim=0.1, rot=(90, 0, 0), parent=None):
    cu = bpy.data.curves.new(name, "FONT")
    cu.body = stringa
    cu.size = dim
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    cu.extrude = 0.002
    ob = bpy.data.objects.new(name, cu)
    _collezione(SENZA_LINEE).objects.link(ob)
    ob.data.materials.append(mat)
    ob.location = loc
    ob.rotation_euler = Euler(tuple(math.radians(r) for r in rot))
    if parent:
        ob.parent = parent
    return ob


def muro_con_buchi(name, asse, fisso, da, a, altezza, buchi, mat, spessore=0.12,
                   verso=1):
    """Un muro piano con delle aperture rettangolari, fatto a pezzi.

    `asse` = "x" per un muro che corre lungo X (fermo in y = `fisso`), "y" per
    uno lungo Y (fermo in x = `fisso`). `buchi` = [(inizio, fine, da_terra,
    a_terra), ...] lungo l'asse. Niente booleane: i pezzi sono scatole, e
    dentro una stanza vista da vicino lo spessore del muro nelle mazzette si
    vede, quindi i pezzi lo danno gratis.
    """
    pezzi = []
    buchi = sorted(buchi)
    corsa = da
    for i, (b0, b1, z0, z1) in enumerate(buchi):
        if b0 > corsa:
            pezzi.append((corsa, b0, 0.0, altezza))
        if z0 > 0:
            pezzi.append((b0, b1, 0.0, z0))
        if z1 < altezza:
            pezzi.append((b0, b1, z1, altezza))
        corsa = b1
    if corsa < a:
        pezzi.append((corsa, a, 0.0, altezza))
    obs = []
    for k, (p0, p1, z0, z1) in enumerate(pezzi):
        c = (p0 + p1) / 2
        lung = p1 - p0
        if asse == "x":
            ob = box(f"{name}_{k}", (lung, spessore, z1 - z0),
                     (c, fisso + verso * spessore / 2, z0), mat)
        else:
            ob = box(f"{name}_{k}", (spessore, lung, z1 - z0),
                     (fisso + verso * spessore / 2, c, z0), mat)
        obs.append(ob)
    return obs


def prisma(name, profilo, x0, spessore, mat):
    """Un poligono nel piano YZ, estruso lungo X da `x0` per `spessore`: i
    fianchi delle scale, che sono l'unica sagoma non squadrata di una casa."""
    bm = bmesh.new()
    davanti = [bm.verts.new((x0, y, z)) for y, z in profilo]
    dietro = [bm.verts.new((x0 + spessore, y, z)) for y, z in profilo]
    bm.faces.new(davanti)
    bm.faces.new(list(reversed(dietro)))
    n = len(profilo)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((davanti[i], davanti[j], dietro[j], dietro[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _oggetto(name, bm, mat, (0, 0, 0), (0, 0, 0), None, True)


def prisma_xz(name, profilo, y0, spessore, mat):
    """Come `prisma`, ma il poligono sta nel piano XZ ed e' estruso lungo Y."""
    bm = bmesh.new()
    davanti = [bm.verts.new((x, y0, z)) for x, z in profilo]
    dietro = [bm.verts.new((x, y0 + spessore, z)) for x, z in profilo]
    bm.faces.new(davanti)
    bm.faces.new(list(reversed(dietro)))
    n = len(profilo)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((davanti[i], davanti[j], dietro[j], dietro[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _oggetto(name, bm, mat, (0, 0, 0), (0, 0, 0), None, True)


def quadro(name, w, h, loc, cornice, tela_a, tela_b, rot=(90, 0, 0), seme=0.0):
    """Un quadretto: cornice e tela dipinta a macchie. A 640 px un paesaggio
    e' tre macchie di colore, quindi e' esattamente quello che si disegna."""
    p = perno(name, loc)
    p.rotation_euler = Euler(tuple(math.radians(r) for r in rot))
    box(name + "_cornice", (w, h, 0.03), (0, 0, 0), cornice, rot=(0, 0, 0), parent=p)
    tela = macchiato(name + "_tela", tela_a, tela_b, scala=5.0, da=0.3, a_=0.7,
                     seme=seme, stira=(1, 2.5, 1))
    b = box(name + "_tela", (w - 0.05, h - 0.05, 0.01), (0, 0, 0.03), tela, parent=p,
            linee=False)
    return p, b


def lampadario(name, attacco, filo, paralume, colore_luce="#FFC98A",
               energia=90.0, forma="piatto", lume=None):
    """Lampada a sospensione appesa a un perno sul soffitto.

    Il perno e' in `attacco` (sul soffitto) e tutto il resto gli pende sotto,
    luce compresa: facendolo ruotare, la pozza di luce scivola sul pavimento
    insieme al paralume. E' quello che vende il dondolio — il paralume da solo
    si muove di tre pixel, la luce che si sposta si vede da tutta la stanza.
    """
    p = perno(name, attacco)
    ferro = piatto(name + "_filo", "#1B1A1A", 0.6)
    cilindro(name + "_filo", 0.006, filo, (0, 0, -filo), ferro, seg=6, parent=p)
    if forma == "piatto":
        prof = [(0.03, 0.0), (0.05, -0.03), (0.16, -0.12), (0.21, -0.16), (0.215, -0.17)]
    elif forma == "campana":
        prof = [(0.03, 0.0), (0.06, -0.02), (0.11, -0.10), (0.15, -0.20), (0.17, -0.23)]
    else:  # "cono": il paralume da officina, stretto e alto
        prof = [(0.025, 0.0), (0.05, -0.05), (0.13, -0.14), (0.24, -0.20), (0.25, -0.205)]
    prof = [(r, z - filo) for r, z in prof]
    tornio(name + "_paralume", list(reversed(prof)), (0, 0, 0), paralume, seg=24,
           chiudi=(False, False), parent=p)
    fondo = prof[-1][1]
    lampadina = piatto(name + "_lampadina", "#FFF2D8", 0.3, luce="#FFE3B0",
                       forza=lume if lume is not None else 30.0)
    sfera(name + "_lampadina", 0.04, (0, 0, fondo + 0.05), lampadina, parent=p, linee=False)
    luce(name + "_luce", "POINT", (0, 0, fondo - 0.02), energia, colore_luce,
         raggio=0.05, parent=p)
    return p


# ----------------------------------------------------------------------
#  scena, camera e render
# ----------------------------------------------------------------------


def svuota():
    # Prima le linee di Freestyle: tengono un riferimento alla collezione
    # degli effetti, e toglierla sotto di loro fa protestare Blender.
    fs = bpy.context.view_layer.freestyle_settings
    for ls in list(fs.linesets):
        fs.linesets.remove(ls)
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.lights,
                 bpy.data.cameras, bpy.data.curves, bpy.data.images):
        for d in list(coll):
            if d.users == 0:
                coll.remove(d)
    # La collezione degli effetti resta (vuota): toglierla e rifarla a ogni
    # stanza fa sbagliare a Blender il conto degli utenti.


def mondo(colore="#15131A", forza=0.35):
    sc = bpy.context.scene
    w = bpy.data.worlds.get("Stanza") or bpy.data.worlds.new("Stanza")
    sc.world = w
    w.use_nodes = True
    N, L = w.node_tree.nodes, w.node_tree.links
    N.clear()
    out = N.new("ShaderNodeOutputWorld")
    bg = N.new("ShaderNodeBackground")
    bg.inputs["Color"].default_value = srgb(colore)
    _set(bg, "Strength", forza)
    L.new(bg.outputs["Background"], out.inputs["Surface"])


def camera_frontale(pos, fov, orizzonte_y):
    """Camera di una stanza vista di fronte: in bolla, guarda dritta verso +Y.

    In bolla vuol dire verticali dritte, come nei disegni di partenza e come si
    disegna una stanza da punta-e-clic. L'orizzonte non si alza inclinando la
    camera ma decentrando l'obiettivo (`shift_y`): stesso scorcio, verticali
    che restano verticali.
    """
    sc = bpy.context.scene
    dati = bpy.data.cameras.new("CAM")
    dati.sensor_fit = "HORIZONTAL"
    dati.angle = math.radians(fov)
    dati.clip_start, dati.clip_end = 0.05, 100.0
    # Lo shift si misura in frazioni del lato lungo (la larghezza).
    dati.shift_y = -(ALT / 2 - orizzonte_y) / LARGH
    cam = bpy.data.objects.new("CAM", dati)
    sc.collection.objects.link(cam)
    cam.location = pos
    cam.rotation_euler = Euler((math.radians(90), 0, 0))
    sc.camera = cam
    return cam


def camera_libera(pos, rot, fov=None, orto=None, shift=(0.0, 0.0)):
    sc = bpy.context.scene
    dati = bpy.data.cameras.new("CAM")
    dati.sensor_fit = "HORIZONTAL"
    if orto:
        dati.type = "ORTHO"
        dati.ortho_scale = orto
    else:
        dati.angle = math.radians(fov)
    dati.shift_x, dati.shift_y = shift
    dati.clip_start, dati.clip_end = 0.05, 200.0
    cam = bpy.data.objects.new("CAM", dati)
    sc.collection.objects.link(cam)
    cam.location = pos
    cam.rotation_euler = Euler(tuple(math.radians(r) for r in rot))
    sc.camera = cam
    return cam


def impostazioni():
    sc = bpy.context.scene
    try:
        sc.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x = LARGH * SUPERSAMPLING
    sc.render.resolution_y = ALT * SUPERSAMPLING
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = False
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGB"
    for attr, val in [("taa_render_samples", 48), ("use_raytracing", True),
                      ("use_shadows", True), ("shadow_ray_count", 2),
                      ("shadow_step_count", 6), ("use_fast_gi", True)]:
        if hasattr(sc.eevee, attr):
            try:
                setattr(sc.eevee, attr, val)
            except (AttributeError, TypeError):
                pass
    # Standard e non AgX, come per gli edifici: AgX sbiadisce i colori pieni, e
    # un interno di sera vive del contrasto fra la lampadina e gli angoli bui.
    sc.view_settings.view_transform = "Standard"
    try:
        sc.view_settings.look = "Medium High Contrast"
    except TypeError:
        pass

    sc.render.use_freestyle = True
    sc.render.line_thickness_mode = "ABSOLUTE"
    sc.render.line_thickness = 1.0
    fs = bpy.context.view_layer.freestyle_settings
    fs.mode = "EDITOR"
    for ls in list(fs.linesets):
        fs.linesets.remove(ls)
    fs.crease_angle = math.radians(80.0)

    def _escludi(ls):
        if bpy.data.collections.get(SENZA_LINEE):
            ls.select_by_collection = True
            ls.collection = bpy.data.collections[SENZA_LINEE]
            ls.collection_negation = "EXCLUSIVE"

    fuori = fs.linesets.new("Contorno")
    for a in ("select_crease", "select_ridge_valley", "select_suggestive_contour",
              "select_material_boundary", "select_edge_mark", "select_border"):
        setattr(fuori, a, False)
    fuori.select_silhouette = True
    fuori.select_external_contour = True
    # Il colore della linea e' LINEARE: 0,035 sembra nero e invece a schermo
    # e' un grigio 52, che in una stanza buia viene piu' chiaro dei muri e
    # disegna tutto a gesso. Serve un valore vicino a zero davvero.
    fuori.linestyle.color = (0.004, 0.0028, 0.0022)
    # Due pixel del render, cioe' uno a schermo: il contorno scuro dei disegni
    # di partenza, che in una stanza piena di roba tiene separati gli oggetti.
    fuori.linestyle.thickness = 2.0
    _escludi(fuori)

    dentro = fs.linesets.new("Spigoli")
    for a in ("select_silhouette", "select_border", "select_ridge_valley",
              "select_suggestive_contour", "select_material_boundary",
              "select_edge_mark", "select_external_contour"):
        setattr(dentro, a, False)
    dentro.select_crease = True
    dentro.linestyle.color = (0.008, 0.006, 0.005)
    dentro.linestyle.alpha = 0.45
    dentro.linestyle.thickness = 1.2
    _escludi(dentro)


def schermo(p):
    """Da punto del mondo a pixel della stanza (640x360, origine in alto a
    sinistra), cioe' le coordinate dei nodi della scena Godot."""
    sc = bpy.context.scene
    co = world_to_camera_view(sc, sc.camera, Vector(p))
    return (round(co.x * LARGH, 1), round((1.0 - co.y) * ALT, 1))


def rettangolo(punti):
    xy = [schermo(p) for p in punti]
    x0 = min(p[0] for p in xy)
    y0 = min(p[1] for p in xy)
    x1 = max(p[0] for p in xy)
    y1 = max(p[1] for p in xy)
    return [round(x0), round(y0), round(x1 - x0), round(y1 - y0)]


def misure(punti):
    """Traduce i punti 3D della stanza nelle misure che servono alla scena."""
    out = {}
    if punti.get("finestra"):
        # Il rettangolo che la contiene e, per le finestre viste di sbieco, i
        # quattro angoli: in basso a sinistra, in basso a destra, in alto a
        # sinistra, in alto a destra in 3D, riordinati come li vuole il gioco
        # (`room.gd::window_quad`: in senso orario dall'alto a sinistra).
        out["finestra"] = rettangolo(punti["finestra"])
        bs, bd, as_, ad = [schermo(p) for p in punti["finestra"]]
        out["finestra_angoli"] = [list(as_), list(ad), list(bd), list(bs)]
    if punti.get("personaggio"):
        piedi = Vector(punti["personaggio"])
        a = schermo(piedi)
        b = schermo(piedi + Vector((0, 0, ALTEZZA_UOMO)))
        scala = abs(a[1] - b[1]) / FIGURA_PX
        # Il `Character` e' centrato: i piedi cadono a y + 19,5 * scala.
        out["personaggio"] = {"piedi": list(a), "scala": round(scala, 2),
                              "posizione": [round(a[0]), round(a[1] - 19.5 * scala)]}
    if punti.get("vasi"):
        out["vasi"] = [list(schermo(p)) for p in punti["vasi"]]
    if punti.get("pc"):
        out["pc"] = rettangolo(punti["pc"])
    return out


def render(percorso):
    sc = bpy.context.scene
    sc.render.filepath = percorso
    bpy.ops.render.render(write_still=True)


def renderizza(nome, solo_fondale=False, solo=None):
    svuota()
    stanza = STANZE[nome]()
    impostazioni()
    cartella = os.path.join(OUT, nome)
    os.makedirs(cartella, exist_ok=True)
    anims = stanza.get("animazioni", [])
    for a in anims:
        a["posa"](a["riposo"])
    render(os.path.join(cartella, "fondale.png"))

    meta = []
    for a in anims:
        m = {k: v for k, v in a.items() if k not in ("posa", "pose", "riposo")}
        m["fotogrammi"] = len(a["pose"])
        meta.append(m)
        if solo_fondale or (solo and a["nome"] not in solo):
            continue
        for i, x in enumerate(a["pose"]):
            a["posa"](x)
            render(os.path.join(cartella, f"{a['nome']}_{i:02d}.png"))
        a["posa"](a["riposo"])

    with open(os.path.join(cartella, "stanza.json"), "w", encoding="utf-8") as f:
        json.dump({"stanza": nome, "animazioni": meta,
                   "punti": misure(stanza.get("punti", {}))}, f, indent=2)
    print("STANZA", nome, json.dumps(misure(stanza.get("punti", {}))))


# ----------------------------------------------------------------------
#  animazioni
# ----------------------------------------------------------------------


def dondolo(nome, perno_ob, gradi, asse="Y", pose=11, periodo=1.6,
            smorza=2.6, pausa=(9.0, 22.0), spinta=(0.45, 1.0)):
    """Un oggetto appeso che ogni tanto dondola: vedi il commento del modulo.

    `periodo` e `smorza` sono i secondi di un'oscillazione e il tempo in cui
    l'ampiezza cala di e volte; `spinta` e' l'ampiezza con cui riparte, a caso
    fra i due valori (1 = `gradi`). Li legge il gioco, qui servono solo le pose.
    """
    base = perno_ob.rotation_euler.copy()
    idx = "XYZ".index(asse)

    def posa(x):
        r = base.copy()
        r[idx] = base[idx] + math.radians(gradi) * x
        perno_ob.rotation_euler = r

    return {"nome": nome, "tipo": "dondolo", "posa": posa, "riposo": 0.0,
            "pose": [-1.0 + 2.0 * i / (pose - 1) for i in range(pose)],
            "periodo": periodo, "smorza": smorza, "pausa": list(pausa),
            "spinta": list(spinta)}


def ciclo(nome, posa, fotogrammi, fps):
    return {"nome": nome, "tipo": "ciclo", "posa": posa, "riposo": 0.0,
            "pose": [i / fotogrammi for i in range(fotogrammi)], "fps": fps}


def evento(nome, posa, fotogrammi, fps, pausa):
    return {"nome": nome, "tipo": "evento", "posa": posa, "riposo": 0.0,
            "pose": [i / fotogrammi for i in range(fotogrammi)], "fps": fps,
            "pausa": list(pausa)}


# ----------------------------------------------------------------------
#  palette comune
# ----------------------------------------------------------------------

def materiali_casa():
    """I materiali che ingresso e cucina condividono: sono la stessa casa."""
    return {
        "legno_scuro": macchiato("legno_scuro", "#4A2E1E", "#3A2317", scala=6,
                                 stira=(1, 1, 7), rough=0.6),
        "legno": macchiato("legno", "#6B4127", "#56331F", scala=5, stira=(1, 1, 6),
                           rough=0.55),
        "legno_chiaro": macchiato("legno_chiaro", "#8A5A36", "#744A2C", scala=5,
                                  stira=(7, 1, 1), rough=0.55),
        "stipite": piatto("stipite", "#3E2519", 0.6),
        "zoccolo": piatto("zoccolo", "#3A2418", 0.6),
        "ferro": piatto("ferro", "#2A2A2C", 0.45, metal=0.6),
        "ottone": piatto("ottone", "#A7803F", 0.35, metal=0.9),
        "bianco_sporco": macchiato("bianco_sporco", "#CFC7B5", "#B9B09C", scala=4,
                                   macchie=("#8F826C", 5.0, 0.62, 0.8)),
        "radiatore": piatto("radiatore", "#C9C4B6", 0.5, metal=0.2),
        "soffitto": macchiato("soffitto", "#6A5F55", "#5E544B", scala=2.5,
                              macchie=("#2F2824", 3.0, 0.63, 0.7)),
        "presa": piatto("presa", "#D8D0BE", 0.5),
    }


# ----------------------------------------------------------------------
#  INGRESSO
# ----------------------------------------------------------------------

def ingresso():
    """Il corridoio d'ingresso, visto dal fondo verso la porta di casa.

    Dal disegno: la porta al centro in fondo, a sinistra la porta aperta su
    una stanza con la finestra (e' la `window_rect` della scena, la sola
    finestra che l'ingresso ha), il termosifone, i quadretti; a destra la
    scala che sale col corrimano, la credenza con l'appendiabiti sopra.
    Pavimento a mattonelle chiare, passatoia rossa, lampadario a campana.
    """
    mondo("#2A2622", 0.55)
    M = materiali_casa()
    muro = macchiato("muro_ingresso", "#8C8566", "#7D7659", scala=2.2,
                     macchie=("#5E5642", 2.6, 0.64, 0.9), seme=1.0)
    muro_stanza = macchiato("muro_salotto", "#5F6B70", "#56626A", scala=2.0,
                            macchie=("#454F55", 2.5, 0.64, 0.8))
    pav = mattonelle("pav_ingresso", "#B39B80", "#A68E74", "#3C302B", lato=0.42,
                     fuga_px=0.018, sporco=("#6E5A4A", 3.0, 0.55), rough=0.6)
    pav_stanza = mattonelle("pav_salotto", "#6E6A6C", "#625E61", "#2E2B2E",
                            lato=0.35, fuga_px=0.015)
    passatoia = macchiato("passatoia", "#6E2A22", "#5A2019", scala=12,
                          macchie=("#B08A5A", 9.0, 0.66, 0.5))
    bordo_pass = piatto("bordo_passatoia", "#8E6A48", 0.9)
    zerbino = macchiato("zerbino", "#3B2A22", "#2F211B", scala=30)

    X0, X1 = -1.75, 1.75      # muri di lato
    Y0, Y1 = 0.6, 7.4         # dal davanti al muro della porta
    HC = 2.75                 # soffitto

    # Pavimento e soffitto.
    box("pavimento", (X1 - X0, Y1 - Y0 + 0.4, 0.05), (0, (Y0 + Y1) / 2, -0.05), pav)
    # Sopra alla scala il soffitto si apre: la scala sale al piano di sopra,
    # e da sotto si vede il buio del vano.
    SX = 0.72             # bordo interno della scala
    box("soffitto", (SX - X0 + 0.2, Y1 - Y0 + 0.4, 0.08), ((X0 + SX) / 2 - 0.1, (Y0 + Y1) / 2, HC), M["soffitto"])
    box("soffitto_scala", (X1 - SX, Y1 - 5.0, 0.08), ((SX + X1) / 2, (5.0 + Y1) / 2, HC), M["soffitto"])
    box("solaio_bordo", (X1 - SX, 0.3, 0.3), ((SX + X1) / 2, 5.0 - 0.15, HC - 0.22), M["soffitto"])
    box("vano_scala", (X1 - SX + 1, 6.0, 0.1), ((SX + X1) / 2, 3.0, HC + 2.4), piatto("vano", "#0E0C0C", 1.0))
    box("cornicione_sx", (0.06, Y1 - Y0, 0.07), (X0 + 0.03, (Y0 + Y1) / 2, HC - 0.07), M["stipite"])
    box("cornicione_dx", (0.06, Y1 - Y0, 0.07), (X1 - 0.03, (Y0 + Y1) / 2, HC - 0.07), M["stipite"])
    box("cornicione_fondo", (X1 - X0, 0.06, 0.07), (0, Y1 - 0.03, HC - 0.07), M["stipite"])

    # Muro di fondo con la porta di casa.
    PX0, PX1, PH = -0.52, 0.52, 2.12
    muro_con_buchi("muro_fondo", "x", Y1, X0, X1, HC, [(PX0, PX1, 0.0, PH)], muro)
    box("porta", (PX1 - PX0, 0.06, PH), (0, Y1 + 0.05, 0), M["legno_scuro"])
    for i, (w, h, z) in enumerate([(0.74, 0.8, 0.18), (0.74, 0.85, 1.1)]):
        box(f"porta_pannello{i}", (w, 0.02, h), (0, Y1 + 0.01, z), M["legno"])
    box("porta_buca", (0.28, 0.02, 0.05), (0, Y1 - 0.005, 0.95), M["ottone"])
    box("porta_maniglia", (0.14, 0.05, 0.03), (PX1 - 0.18, Y1 - 0.02, 1.02), M["ottone"])
    box("porta_placca", (0.05, 0.02, 0.22), (PX1 - 0.13, Y1 - 0.005, 0.92), M["ottone"])
    cilindro("porta_spioncino", 0.018, 0.02, (0, Y1 - 0.01, 1.58), M["ottone"], rot=(90, 0, 0))
    box("stipite_sx", (0.09, 0.06, PH + 0.08), (PX0 - 0.045, Y1 - 0.03, 0), M["stipite"])
    box("stipite_dx", (0.09, 0.06, PH + 0.08), (PX1 + 0.045, Y1 - 0.03, 0), M["stipite"])
    box("stipite_su", (PX1 - PX0 + 0.18, 0.06, 0.09), (0, Y1 - 0.03, PH), M["stipite"])
    box("zerbino", (0.9, 0.5, 0.015), (0, Y1 - 0.4, 0), zerbino)
    # Citofono e interruttore accanto alla porta.
    box("citofono", (0.12, 0.04, 0.24), (0.85, Y1 - 0.02, 1.32), M["presa"])
    box("citofono_cornetta", (0.05, 0.05, 0.2), (0.85, Y1 - 0.05, 1.34), piatto("citofono_grigio", "#8C877B", 0.5))
    box("interruttore", (0.07, 0.02, 0.1), (0.72, Y1 - 0.01, 1.05), M["presa"])
    box("zoccolo_fondo", (X1 - X0, 0.02, 0.1), (0, Y1 - 0.01, 0), M["zoccolo"])

    # Muro sinistro, con la porta aperta sulla stanza accanto.
    DY0, DY1, DH = 2.3, 3.5, 2.12
    muro_con_buchi("muro_sx", "y", X0, Y0 - 0.2, Y1, HC, [(DY0, DY1, 0.0, DH)], muro, verso=-1)
    box("zoccolo_sx_a", (0.02, DY0 - Y0, 0.1), (X0 + 0.01, (Y0 + DY0) / 2, 0), M["zoccolo"])
    box("zoccolo_sx_b", (0.02, Y1 - DY1, 0.1), (X0 + 0.01, (DY1 + Y1) / 2, 0), M["zoccolo"])
    for k, yy in enumerate((DY0 - 0.045, DY1 + 0.045)):
        box(f"mazzetta{k}", (0.16, 0.09, DH + 0.08), (X0 + 0.02, yy, 0), M["stipite"])
    box("mazzetta_su", (0.16, DY1 - DY0 + 0.18, 0.09), (X0 + 0.02, (DY0 + DY1) / 2, DH), M["stipite"])
    # La porta aperta verso la stanza, contro la mazzetta.
    box("porta_sx", (0.84, 0.05, 2.05), (X0 - 0.42 - 0.06, DY0 + 0.03, 0), M["legno_scuro"], rot=(0, 0, 0))

    # La stanza accanto: si vede solo dalla porta. Sera, luce blu dalla
    # finestra — e' da li' che entra il giorno nell'ingresso.
    SX0 = -5.2
    box("stanza_pav", (SX0 * -1 + X0, 5.0, 0.05), ((SX0 + X0) / 2, 3.6, -0.05), pav_stanza)
    box("stanza_soff", (-SX0 + X0, 5.0, 0.08), ((SX0 + X0) / 2, 3.6, HC), M["soffitto"])
    WY = 5.4
    FX0, FX1, FZ0, FZ1 = -3.55, -2.65, 0.95, 2.25
    muro_con_buchi("stanza_fondo", "x", WY, SX0, X0, HC, [(FX0, FX1, FZ0, FZ1)], muro_stanza)
    muro_con_buchi("stanza_muro", "y", SX0, 1.0, WY, HC, [], muro_stanza, verso=-1)
    box("stanza_davanti", (-SX0 + X0, 0.1, HC), ((SX0 + X0) / 2, 1.1, 0), muro_stanza)
    # La finestra: telaio, persiana a stecche per meta', vetro con il fuori.
    telaio = piatto("telaio_salotto", "#D9D6CC", 0.5)
    box("fin_davanzale", (FX1 - FX0 + 0.16, 0.2, 0.05), ((FX0 + FX1) / 2, WY - 0.05, FZ0 - 0.05), telaio)
    for k, xx in enumerate((FX0 + 0.03, (FX0 + FX1) / 2, FX1 - 0.03)):
        box(f"fin_montante{k}", (0.05, 0.06, FZ1 - FZ0), (xx, WY + 0.04, FZ0), telaio)
    for k, zz in enumerate((FZ0, FZ1 - 0.05, (FZ0 + FZ1) / 2 + 0.1)):
        box(f"fin_traverso{k}", (FX1 - FX0, 0.06, 0.05), ((FX0 + FX1) / 2, WY + 0.04, zz), telaio)
    fuori = piatto("fuori_sera", "#7F9CB8", 1.0, luce="#8FA8C4", forza=0.8)
    lastra("fin_fuori", FX1 - FX0 + 0.4, FZ1 - FZ0 + 0.4, ((FX0 + FX1) / 2, WY + 0.6, FZ0 - 0.2), fuori, linee=False)
    stecca = piatto("stecca", "#3F4A55", 0.7)
    for k in range(9):
        box(f"fin_stecca{k}", (FX1 - FX0 - 0.06, 0.02, 0.035), ((FX0 + FX1) / 2, WY + 0.09, FZ1 - 0.08 - k * 0.06), stecca, rot=(20, 0, 0))
    box("stanza_radiatore", (0.9, 0.08, 0.6), ((FX0 + FX1) / 2, WY - 0.06, 0.15), M["radiatore"])
    for k in range(10):
        box(f"stanza_rad_el{k}", (0.05, 0.1, 0.62), (FX0 + 0.08 + k * 0.083, WY - 0.08, 0.14), M["radiatore"])
    box("stanza_tavolo", (1.0, 0.8, 0.04), (-2.6, 4.3, 0.74), M["legno"])
    for dx in (-0.45, 0.45):
        for dy in (-0.35, 0.35):
            box("stanza_gamba", (0.05, 0.05, 0.74), (-2.6 + dx, 4.3 + dy, 0), M["legno"])
    box("stanza_sedia", (0.42, 0.42, 0.04), (-2.35, 3.6, 0.45), M["legno_scuro"])
    box("stanza_sedia_sch", (0.42, 0.04, 0.5), (-2.35, 3.4, 0.45), M["legno_scuro"])
    for dx in (-0.18, 0.18):
        for dy in (-0.18, 0.18):
            box("stanza_sedia_g", (0.04, 0.04, 0.45), (-2.35 + dx, 3.6 + dy, 0), M["legno_scuro"])
    luce("stanza_giorno", "AREA", ((FX0 + FX1) / 2, WY - 0.3, 1.6), 30.0, "#A9C2E0",
         rot=(90, 0, 0), dim=(0.9, 1.2))
    luce("stanza_riempi", "POINT", (-3.4, 3.0, 2.2), 12.0, "#8FA7C8", raggio=0.8)

    # La tenda della stanza accanto: si gonfia quando entra uno spiffero.
    tenda_mat = piatto("tenda", "#C8BFA8", 0.95)
    tenda_mat.use_backface_culling = False
    TH = FZ1 - FZ0 + 0.25
    tenda = lastra("tenda", 0.42, TH, (FX1 - 0.02, WY - 0.1, FZ0 - 0.05), tenda_mat,
                   nx=6, nz=10)
    tenda_rip = [v.co.copy() for v in tenda.data.vertices]
    box("tenda_bastone", (FX1 - FX0 + 0.5, 0.03, 0.03), ((FX0 + FX1) / 2, WY - 0.1, FZ1 + 0.22), M["ferro"])

    # Muro destro dietro la scala, e la scala.
    muro_con_buchi("muro_dx", "y", X1, Y0 - 0.2, Y1, HC, [], muro)
    GRADINI = 12
    ALZ, PED = 0.2, 0.27
    SY0 = 1.4
    for i in range(GRADINI):
        y = SY0 + i * PED
        box(f"gradino{i}", (X1 - SX, PED + 0.03, 0.035), ((SX + X1) / 2, y + PED / 2, (i + 1) * ALZ - 0.035), M["legno_chiaro"])
        box(f"alzata{i}", (X1 - SX, 0.02, ALZ), ((SX + X1) / 2, y, i * ALZ), piatto("alzata", "#6E6252", 0.8) if i == 0 else bpy.data.materials["alzata"])
    # Il fianco della scala, chiuso: un profilo a dente di sega estruso.
    fianco = macchiato("fianco_scala", "#5A4533", "#4E3B2B", scala=4)
    profilo = [(SY0, 0.0)]
    for i in range(GRADINI):
        profilo += [(SY0 + i * PED, (i + 1) * ALZ), (SY0 + (i + 1) * PED, (i + 1) * ALZ)]
    profilo += [(SY0 + GRADINI * PED, 0.0)]
    prisma("fianco_scala", profilo, SX - 0.04, 0.04, fianco)
    # Corrimano: montanti e barra inclinata.
    for i in range(0, GRADINI, 1):
        y = SY0 + i * PED + PED / 2
        box(f"colonnina{i}", (0.03, 0.03, 0.9), (SX + 0.05, y, (i + 1) * ALZ), M["legno_scuro"])
    box("pilastrino", (0.1, 0.1, 1.15), (SX + 0.05, SY0 + PED / 2, 0.2), M["legno_scuro"])
    lung = math.hypot(GRADINI * PED, GRADINI * ALZ)
    ang = math.degrees(math.atan2(ALZ, PED))
    box("corrimano", (0.07, lung, 0.06),
        (SX + 0.05, SY0 + GRADINI * PED / 2 + PED / 2, 0.85 + ALZ + GRADINI * ALZ / 2), M["legno"], rot=(ang, 0, 0))
    # Il muro davanti sotto il primo gradino, dove la scala finisce nel muro.

    # Termosifone sul muro di sinistra, subito dopo la porta aperta.
    RY = 4.2
    box("termosifone", (0.08, 1.0, 0.62), (X0 + 0.1, RY, 0.14), M["radiatore"])
    for k in range(12):
        box(f"term_el{k}", (0.1, 0.05, 0.64), (X0 + 0.11, RY - 0.46 + k * 0.083, 0.13), M["radiatore"])
    box("term_valvola", (0.05, 0.05, 0.08), (X0 + 0.12, RY + 0.55, 0.12), M["ottone"])

    # Credenza e appendiabiti, sul muro di sinistra verso il fondo. Nel disegno
    # stavano a destra, ma qui la scala e' chiusa di lato e se li mangerebbe.
    CY = 5.95
    CX = X0 + 0.23
    box("credenza", (0.45, 1.1, 0.9), (CX, CY, 0), M["legno_scuro"])
    box("credenza_piano", (0.5, 1.16, 0.04), (CX + 0.02, CY, 0.9), M["legno"])
    box("credenza_anta1", (0.02, 0.5, 0.7), (CX + 0.24, CY - 0.27, 0.1), M["legno"])
    box("credenza_anta2", (0.02, 0.5, 0.7), (CX + 0.24, CY + 0.27, 0.1), M["legno"])
    for k, yy in enumerate((CY - 0.08, CY + 0.08)):
        box(f"credenza_pomo{k}", (0.03, 0.03, 0.03), (CX + 0.26, yy, 0.6), M["ottone"])
    tornio("svuotatasche", [(0.05, 0), (0.09, 0.03), (0.1, 0.04)], (CX + 0.02, CY - 0.3, 0.94),
           piatto("ciotola_blu", "#3C6E8F", 0.4))
    quadro("foto_credenza", 0.14, 0.18, (CX - 0.02, CY + 0.3, 0.94),
           M["legno_scuro"], "#6E7B63", "#B8A27D", rot=(80, 0, 90), seme=3.0)
    box("appendiabiti", (0.04, 0.9, 0.08), (X0 + 0.02, CY - 0.05, 1.72), M["legno"])
    for k in range(4):
        box(f"gancio{k}", (0.1, 0.02, 0.02), (X0 + 0.08, CY - 0.4 + k * 0.23, 1.74), M["ferro"])
    # Il cappotto appeso: dondola quando si apre la porta, cioe' ogni tanto.
    p_cappotto = perno("cappotto", (X0 + 0.14, CY - 0.17, 1.74))
    cappotto_mat = macchiato("cappotto", "#26304F", "#1E2641", scala=8)
    tornio("cappotto_corpo", [(0.13, -0.95), (0.16, -0.7), (0.14, -0.3), (0.09, -0.05), (0.03, 0.0)],
           (0, 0, 0), cappotto_mat, seg=12, scala=(0.55, 1.0, 1.0), parent=p_cappotto)
    tornio("cappotto_manica", [(0.05, -0.8), (0.06, -0.3), (0.04, -0.08)], (0.02, -0.14, 0),
           cappotto_mat, seg=8, parent=p_cappotto)
    p_cappello = perno("berretto", (X0 + 0.12, CY + 0.28, 1.74))
    tornio("berretto_corpo", [(0.08, -0.34), (0.12, -0.2), (0.08, -0.04), (0.02, 0.0)], (0, 0, 0),
           macchiato("berretto", "#3E5040", "#344536", scala=8), seg=12, scala=(0.6, 1, 1),
           parent=p_cappello)

    # Quadri.
    quadro("quadro_sx1", 0.4, 0.5, (X0 + 0.02, 4.2, 1.45), M["stipite"], "#5E7A55", "#A99A6A",
           rot=(90, 0, 90), seme=1.0)
    quadro("quadro_sx2", 0.22, 0.3, (X0 + 0.02, 6.75, 1.45), M["stipite"], "#8C6F52", "#3F5A6B",
           rot=(90, 0, 90), seme=2.0)
    quadro("quadro_dx2", 0.5, 0.65, (X1 - 0.02, 3.0, 2.0), M["stipite"], "#7A6A4F", "#4E6B7C",
           rot=(90, 0, -90), seme=5.0)
    box("interruttore_sx", (0.02, 0.07, 0.1), (X0 + 0.01, 1.9, 1.05), M["presa"])

    # Orologio a pendolo sul muro di fondo, a sinistra della porta: batte
    # sempre, come tutti gli orologi a pendolo di tutti gli ingressi.
    OX = -1.12
    cassa = M["legno_scuro"]
    # La cassa e' aperta davanti, col pendolo dentro e un vetro quasi
    # trasparente: una scatola piena si mangerebbe il pendolo.
    box("orologio_fondo", (0.36, 0.05, 0.9), (OX, Y1 - 0.025, 1.05), cassa)
    for k, dx in enumerate((-0.16, 0.16)):
        box(f"orologio_fianco{k}", (0.04, 0.16, 0.9), (OX + dx, Y1 - 0.08, 1.05), cassa)
    box("orologio_base", (0.36, 0.16, 0.06), (OX, Y1 - 0.08, 1.05), cassa)
    box("orologio_testa", (0.36, 0.16, 0.3), (OX, Y1 - 0.08, 1.65), cassa)
    box("orologio_vetro", (0.28, 0.01, 0.54), (OX, Y1 - 0.155, 1.11),
        piatto("vetro_orologio", "#9AA4A8", 0.05, alpha=0.12), linee=False)
    cilindro("orologio_quadrante", 0.12, 0.02, (OX, Y1 - 0.16, 1.8), M["presa"], seg=24, rot=(90, 0, 0))
    box("orologio_lancetta1", (0.012, 0.01, 0.09), (OX, Y1 - 0.18, 1.8), M["ferro"], rot=(0, 30, 0), linee=False)
    box("orologio_lancetta2", (0.012, 0.01, 0.065), (OX, Y1 - 0.18, 1.8), M["ferro"], rot=(0, 120, 0), linee=False)
    box("orologio_cappello", (0.42, 0.18, 0.06), (OX, Y1 - 0.08, 1.95), cassa)
    p_pendolo = perno("pendolo", (OX, Y1 - 0.1, 1.62))
    cilindro("pendolo_asta", 0.008, 0.36, (0, 0, -0.36), M["ottone"], seg=6, parent=p_pendolo)
    cilindro("pendolo_lente", 0.06, 0.015, (0, 0.01, -0.4), M["ottone"], seg=16, rot=(90, 0, 0),
             parent=p_pendolo)

    # Passatoia e lampadario.
    box("passatoia", (0.95, 2.9, 0.012), (-0.05, 4.0, 0), passatoia)
    box("passatoia_bordo", (1.02, 2.97, 0.008), (-0.05, 4.0, 0), bordo_pass)
    p_lampada = lampadario("lampadario", (-0.1, 4.6, HC), 0.5,
                           piatto("paralume_ingresso", "#3A3A33", 0.5, metal=0.3),
                           forma="campana", energia=260.0)

    # Riempimento caldo da dietro la camera: e' la luce della stanza da cui si
    # guarda, e senza la scala e il muro di destra restano un buco nero.
    luce("riempi", "AREA", (0.2, 0.3, 2.4), 60.0, "#FFD9B0", rot=(70, 0, 0), dim=(2.5, 1.0))
    luce("riempi_scala", "POINT", (0.3, 3.4, 2.2), 25.0, "#FFD7A8", raggio=0.8)

    camera_frontale((0.0, -0.05, 1.72), 76.0, 128)

    def posa_tenda(t):
        # Uno spiffero: la tenda si gonfia verso la stanza e ricade. `t` va
        # da 0 a 1 e a 0 e' ferma. In locale la tenda e' in piedi su Y e la
        # sua Z guarda verso l'interno della stanza.
        forza = math.sin(math.pi * t) ** 1.5
        for v, rip in zip(tenda.data.vertices, tenda_rip):
            giu = 1.0 - rip.y / TH
            onda = math.sin(rip.x * 16.0 + t * 9.0)
            v.co.z = rip.z + forza * giu * (0.2 + 0.05 * onda)
            v.co.x = rip.x - forza * giu * 0.07
        tenda.data.update()

    def posa_pendolo(t):
        p_pendolo.rotation_euler = Euler((0, math.radians(11.0) * math.sin(2 * math.pi * t), 0))

    return {
        "animazioni": [
            dondolo("lampadario", p_lampada, 7.0, asse="Y", periodo=1.5, smorza=3.0,
                    pausa=(10.0, 24.0)),
            dondolo("cappotto", p_cappotto, 5.0, asse="X", pose=7, periodo=1.2, smorza=1.6,
                    pausa=(14.0, 30.0)),
            ciclo("pendolo", posa_pendolo, 16, 8),
            evento("tenda", posa_tenda, 16, 8, (8.0, 20.0)),
        ],
        "punti": {
            "finestra": [(FX0, WY, FZ0), (FX1, WY, FZ0), (FX0, WY, FZ1), (FX1, WY, FZ1)],
            "personaggio": (-0.45, 4.25, 0.0),
        },
    }


# ----------------------------------------------------------------------
#  CUCINA
# ----------------------------------------------------------------------

def sedia(name, loc, rot_z, mat, schienale=True):
    p = perno(name, loc)
    p.rotation_euler = Euler((0, 0, math.radians(rot_z)))
    box(name + "_seduta", (0.42, 0.42, 0.04), (0, 0, 0.45), mat, parent=p)
    for dx in (-0.18, 0.18):
        for dy in (-0.18, 0.18):
            box(name + "_gamba", (0.04, 0.04, 0.45), (dx, dy, 0), mat, parent=p)
    if schienale:
        for dx in (-0.18, 0.18):
            box(name + "_montante", (0.04, 0.04, 0.5), (dx, 0.19, 0.49), mat, parent=p)
        for zz in (0.72, 0.9):
            box(name + "_traversa", (0.4, 0.03, 0.07), (0, 0.19, zz), mat, parent=p)
    return p


def fuori_citta(y, x0, x1, z0=-1.0):
    """Quello che si vede dalla finestra: un palazzo di fronte col tetto
    rosso e il cielo. Emissivo e non illuminato, cosi' nessuna luce del fuori
    entra in cucina: il taglio di sole lo disegna il gioco, all'ora giusta."""
    cielo = piatto("cielo", "#AFC0CB", 1.0, luce="#B7C6D0", forza=1.0)
    lastra("cielo", x1 - x0 + 6, 10, ((x0 + x1) / 2, y + 6, z0), cielo, linee=False)
    facciata = macchiato("facciata_fronte", "#B48A6A", "#A67C5E", scala=3,
                         luce="#B48A6A", forza=0.55)
    tetto = piatto("tetto_fronte", "#8A4A38", 0.9, luce="#8A4A38", forza=0.5)
    buio = piatto("finestra_fronte", "#3B3834", 0.9, luce="#3B3834", forza=0.4)
    box("palazzo_fronte", (x1 - x0 + 3, 1.0, 4.6), ((x0 + x1) / 2 + 0.6, y + 2.5, z0), facciata, linee=False)
    box("tetto_fronte", (x1 - x0 + 3.2, 1.4, 0.35), ((x0 + x1) / 2 + 0.6, y + 2.2, z0 + 4.6), tetto,
        rot=(-12, 0, 0), linee=False)
    for i in range(5):
        for j in range(2):
            box(f"fin_fronte{i}{j}", (0.45, 0.02, 0.7),
                (x0 - 0.8 + i * 1.0, y + 1.99, z0 + 1.6 + j * 1.5), buio, linee=False)
    campanile = macchiato("campanile", "#9C7A62", "#8E6E57", scala=3, luce="#9C7A62", forza=0.5)
    box("campanile", (0.6, 0.6, 7.0), (x0 - 0.9, y + 4.0, z0), campanile, linee=False)


def cucina():
    """La cucina, vista dalla porta verso la finestra.

    Dal disegno: pensili e cucina a gas a sinistra con la cappa e il tubo che
    sale al soffitto, il lavello sotto la finestra con le mattonelle bianche,
    la finestra con la tapparella mezza giu' e il termosifone, il frigorifero
    in fondo a destra, il tavolo al centro col lampadario verde sopra, le
    sedie, lo strofinaccio a quadretti sul forno.
    """
    mondo("#2A2622", 0.5)
    M = materiali_casa()
    muro = macchiato("muro_cucina", "#7F7A5E", "#716C52", scala=2.4,
                     macchie=("#58523E", 2.8, 0.64, 0.9), seme=2.0)
    pav = mattonelle("pav_cucina", "#A89276", "#9C866B", "#4A3C32", lato=0.36,
                     fuga_px=0.012, sporco=("#6A5645", 2.6, 0.6), rough=0.55)
    piastrelle = mattonelle("piastrelle", "#D9D4C8", "#CFC9BC", "#8E877A", lato=0.15,
                            fuga_px=0.01, piano="xz", rough=0.3)
    mobile = macchiato("mobile_cucina", "#5B3522", "#4E2D1C", scala=5, stira=(1, 1, 5), rough=0.6)
    anta = macchiato("anta_cucina", "#6A3F28", "#5E3722", scala=5, stira=(1, 1, 5), rough=0.55)
    piano_lav = piatto("piano_lavoro", "#6B5140", 0.5)
    smalto = piatto("smalto", "#E4DFD2", 0.35)
    inox = piatto("inox", "#9FA3A5", 0.3, metal=0.9)
    nero = piatto("nero", "#1C1B1B", 0.6)
    frigo = macchiato("frigo", "#D9D1BD", "#CBC2AC", scala=3,
                      macchie=("#A99A7E", 4.0, 0.66, 0.6), rough=0.4)
    vetro_verde = piatto("vetro_verde", "#2F5A33", 0.15)
    tessuto = macchiato("quadretti", "#B04A42", "#E3D8C8", scala=40, da=0.48, a_=0.52)

    X0, X1 = -2.4, 2.4
    Y0, Y1 = 0.4, 6.0
    HC = 2.8

    box("pavimento", (X1 - X0, Y1 - Y0 + 0.4, 0.05), (0, (Y0 + Y1) / 2, -0.05), pav)
    box("soffitto", (X1 - X0 + 0.4, Y1 - Y0 + 0.4, 0.08), (0, (Y0 + Y1) / 2, HC), M["soffitto"])
    for nome, dim, loc in (("corn_sx", (0.06, Y1 - Y0, 0.07), (X0 + 0.03, (Y0 + Y1) / 2, HC - 0.07)),
                           ("corn_dx", (0.06, Y1 - Y0, 0.07), (X1 - 0.03, (Y0 + Y1) / 2, HC - 0.07)),
                           ("corn_fondo", (X1 - X0, 0.06, 0.07), (0, Y1 - 0.03, HC - 0.07))):
        box(nome, dim, loc, M["stipite"])

    # Muro di fondo con la finestra.
    FX0, FX1, FZ0, FZ1 = 0.45, 1.45, 1.0, 2.3
    muro_con_buchi("muro_fondo", "x", Y1, X0, X1, HC, [(FX0, FX1, FZ0, FZ1)], muro)
    telaio = M["legno_scuro"]
    box("fin_davanzale", (FX1 - FX0 + 0.2, 0.25, 0.05), ((FX0 + FX1) / 2, Y1 - 0.05, FZ0 - 0.05), M["legno"])
    for k, xx in enumerate((FX0 + 0.04, (FX0 + FX1) / 2, FX1 - 0.04)):
        box(f"fin_montante{k}", (0.07, 0.07, FZ1 - FZ0), (xx, Y1 + 0.05, FZ0), telaio)
    for k, zz in enumerate((FZ0, FZ1 - 0.06)):
        box(f"fin_traverso{k}", (FX1 - FX0, 0.07, 0.06), ((FX0 + FX1) / 2, Y1 + 0.05, zz), telaio)
    box("fin_maniglia", (0.03, 0.04, 0.12), ((FX0 + FX1) / 2 + 0.06, Y1, 1.6), M["ottone"])
    # Tapparella giu' per un terzo, con le stecche, e il cassonetto sopra.
    stecca = piatto("stecca_tapparella", "#3C3833", 0.7)
    for k in range(8):
        box(f"tapparella{k}", (FX1 - FX0 - 0.02, 0.02, 0.05), ((FX0 + FX1) / 2, Y1 + 0.12, FZ1 - 0.06 - k * 0.055),
            stecca)
    box("cassonetto", (FX1 - FX0 + 0.5, 0.2, 0.3), ((FX0 + FX1) / 2, Y1 - 0.1, FZ1 + 0.1), M["legno_scuro"])
    cilindro("cinghia", 0.008, 1.2, (FX1 + 0.18, Y1 - 0.03, 1.2), piatto("cinghia", "#2E2B28", 0.8), seg=6)
    box("cinghia_scatola", (0.1, 0.04, 0.2), (FX1 + 0.18, Y1 - 0.02, 1.0), M["presa"])
    fuori_citta(Y1 + 1.5, FX0 - 1, FX1 + 1)
    # Termosifone sotto la finestra, col panno appeso.
    box("termosifone", (1.0, 0.08, 0.62), ((FX0 + FX1) / 2, Y1 - 0.12, 0.18), M["radiatore"])
    for k in range(12):
        box(f"term_el{k}", (0.05, 0.12, 0.64), (FX0 + 0.04 + k * 0.083, Y1 - 0.13, 0.17), M["radiatore"])
    box("term_panno", (0.16, 0.02, 0.36), ((FX0 + FX1) / 2 + 0.2, Y1 - 0.2, 0.46), tessuto)

    # Blocco cucina sul muro di fondo, da sinistra: fornelli, piano, lavello.
    CD = 0.62                  # profondita' dei mobili
    CY = Y1 - CD / 2
    box("base_cucina", (2.8, CD, 0.86), (X0 + 1.4, CY, 0), mobile)
    box("piano_cucina", (2.84, CD + 0.03, 0.04), (X0 + 1.42, CY - 0.015, 0.86), piano_lav)
    for k in range(4):
        x = (X0 + 0.08) if k == 0 else (-1.02 + (k - 1) * 0.48)
        box(f"anta{k}", (0.44, 0.02, 0.7), (x + 0.24, Y1 - CD - 0.01, 0.1), anta)
        box(f"pomolo{k}", (0.1, 0.02, 0.02), (x + 0.24, Y1 - CD - 0.03, 0.72), M["ottone"])
    box("zoccolo_cucina", (2.8, 0.02, 0.1), (X0 + 1.4, Y1 - CD + 0.05, 0), nero)
    box("alzatina", (2.8, 0.02, 0.6), (X0 + 1.4, Y1 - 0.01, 0.9), piastrelle)
    # Il lavello, col rubinetto.
    LX = -0.4
    box("lavello", (0.62, 0.42, 0.02), (LX, CY, 0.885), inox)
    box("vasca", (0.5, 0.34, 0.16), (LX, CY, 0.73), piatto("vasca", "#6F7375", 0.3, metal=0.8))
    cilindro("rubinetto", 0.018, 0.28, (LX, Y1 - 0.08, 0.9), inox, seg=10)
    box("rubinetto_becco", (0.03, 0.16, 0.03), (LX, Y1 - 0.14, 1.15), inox)
    box("rubinetto_leva", (0.02, 0.1, 0.02), (LX, Y1 - 0.06, 1.2), inox, rot=(20, 0, 0))
    # Cucina a gas bianca con forno, pentola e lo strofinaccio sulla maniglia.
    GX = -1.35
    box("cucina_gas", (0.62, CD, 0.88), (GX, CY - 0.02, 0), smalto)
    box("forno_vetro", (0.46, 0.02, 0.34), (GX, Y1 - CD - 0.03, 0.2), nero)
    box("forno_maniglia", (0.46, 0.03, 0.03), (GX, Y1 - CD - 0.06, 0.6), inox)
    for k in range(4):
        cilindro(f"manopola{k}", 0.022, 0.03, (GX - 0.2 + k * 0.13, Y1 - CD - 0.03, 0.76), nero, seg=10,
                 rot=(90, 0, 0))
    box("piano_fuochi", (0.62, CD, 0.02), (GX, CY - 0.02, 0.88), nero)
    griglia = piatto("griglia", "#2C2B2A", 0.5, metal=0.5)
    for dx, dy in ((-0.15, -0.14), (0.15, -0.14), (-0.15, 0.14), (0.15, 0.14)):
        cilindro("fuoco", 0.07, 0.02, (GX + dx, CY + dy, 0.9), griglia, seg=12)
    pentola = piatto("pentola", "#3C4546", 0.35, metal=0.6)
    PX, PY = GX + 0.15, CY - 0.14
    tornio("pentola", [(0.13, 0), (0.14, 0.02), (0.14, 0.17), (0.145, 0.18)], (PX, PY, 0.92), pentola, seg=20)
    tornio("coperchio", [(0.15, 0), (0.1, 0.03), (0.02, 0.05), (0.0, 0.05)], (PX, PY, 1.1), pentola, seg=20)
    tornio("pentolino", [(0.08, 0), (0.09, 0.1)], (GX - 0.15, CY + 0.14, 0.92), pentola, seg=16)
    p_panno = perno("strofinaccio", (GX + 0.1, Y1 - CD - 0.07, 0.6))
    box("strofinaccio_telo", (0.2, 0.02, 0.36), (0, 0, -0.36), tessuto, parent=p_panno)
    box("strofinaccio_piega", (0.2, 0.03, 0.05), (0, 0.02, -0.02), tessuto, parent=p_panno)
    # Cappa sopra i fornelli e il tubo che sale.
    box("cappa", (0.66, 0.42, 0.14), (GX, Y1 - 0.24, 1.62), inox)
    tornio("cappa_tronco", [(0.32, 0), (0.12, 0.22)], (GX, Y1 - 0.26, 1.76), inox, seg=4,
           scala=(1.0, 0.7, 1.0), rot=(0, 0, 45))
    tubo = piatto("tubo_cappa", "#8A8E90", 0.45, metal=0.8)
    cilindro("tubo_cappa", 0.09, HC - 1.98, (GX, Y1 - 0.26, 1.98), tubo, seg=14)
    for k in range(5):
        cilindro(f"tubo_anello{k}", 0.095, 0.02, (GX, Y1 - 0.26, 2.05 + k * 0.15), tubo, seg=14)
    # Pensili, uno con l'anta aperta.
    for k, x in enumerate((X0 + 0.06, -1.0, -0.52, -0.04)):
        box(f"pensile{k}", (0.48, 0.34, 0.7), (x + 0.24, Y1 - 0.17, 1.55), mobile)
        if k != 3:
            box(f"pensile_anta{k}", (0.44, 0.02, 0.64), (x + 0.24, Y1 - 0.35, 1.58), anta)
    # L'ultimo pensile ha l'anta aperta: dentro, i barattoli.
    box("pensile_vano", (0.44, 0.02, 0.64), (0.2, Y1 - 0.05, 1.58), nero)
    box("pensile_ripiano", (0.44, 0.3, 0.02), (0.2, Y1 - 0.17, 1.9), mobile)
    box("pensile_aperta", (0.02, 0.44, 0.64), (0.45, Y1 - 0.58, 1.58), anta)
    for k in range(3):
        tornio(f"barattolo{k}", [(0.035, 0), (0.035, 0.1)], (0.06 + k * 0.1, Y1 - 0.17, 1.6),
               piatto(f"barattolo{k}", ("#7C6A4A", "#556B4A", "#8F5A3A")[k], 0.4), seg=10)
    tornio("scolapasta", [(0.06, 0), (0.12, 0.08)], (-0.76, Y1 - 0.17, 2.25), inox, seg=14)
    tornio("pentola_su", [(0.1, 0), (0.1, 0.12)], (-0.28, Y1 - 0.17, 2.25), pentola, seg=14)
    # Sul piano: bottiglie, tagliere, barattoli.
    for k, (x, col) in enumerate(((-2.2, "#3B5A2A"), (-2.08, "#5E6A2A"), (-1.96, "#6B4A22"))):
        tornio(f"bottiglia{k}", [(0.035, 0), (0.035, 0.2), (0.012, 0.27), (0.012, 0.32)],
               (x, Y1 - 0.12, 0.9), piatto(f"vetro_b{k}", col, 0.15), seg=10)
    box("tagliere", (0.3, 0.03, 0.4), (-0.85, Y1 - 0.05, 0.9), M["legno_chiaro"], rot=(-8, 0, 0))
    tornio("tazza", [(0.04, 0), (0.045, 0.09)], (0.05, CY - 0.1, 0.9), vetro_verde, seg=12)
    tornio("vasetto", [(0.05, 0), (0.06, 0.1)], (0.2, CY + 0.1, 0.9), vetro_verde, seg=12)
    # Sul muro di sinistra una mensola coi piatti e il mestolo appeso.
    box("mensola", (0.24, 1.0, 0.03), (X0 + 0.12, 4.5, 1.55), M["legno"])
    for k in range(4):
        cilindro(f"piatto{k}", 0.11, 0.015, (X0 + 0.08, 4.15 + k * 0.23, 1.58), smalto, seg=16,
                 rot=(0, 75, 0))
    box("barra_mestoli", (0.02, 0.8, 0.02), (X0 + 0.04, 4.5, 1.3), inox)
    for k in range(3):
        cilindro(f"mestolo{k}", 0.008, 0.3, (X0 + 0.06, 4.25 + k * 0.25, 1.0), inox, seg=6)
        tornio(f"mestolo_testa{k}", [(0.01, 0), (0.04, 0.02), (0.045, 0.04)], (X0 + 0.06, 4.25 + k * 0.25, 0.96),
               inox, seg=10)
    quadro("quadro_cucina", 0.35, 0.45, (X0 + 0.02, 2.9, 1.5), M["stipite"], "#A8804A", "#5E7A55",
           rot=(90, 0, 90), seme=7.0)
    # Tappeto davanti ai fornelli.
    box("tappeto", (0.7, 1.1, 0.012), (X0 + 1.1, 4.6, 0),
        macchiato("tappeto_cucina", "#4A2D26", "#3A221C", scala=14, macchie=("#7A5A3C", 10.0, 0.66, 0.6)),
        rot=(0, 0, 90))

    # Muro sinistro con la porta da cui si guarda.
    DY0, DY1 = 0.2, 1.3
    muro_con_buchi("muro_sx", "y", X0, Y0 - 0.2, Y1, HC, [(DY0, DY1, 0.0, 2.15)], muro, verso=-1)
    box("mazzetta_porta", (0.12, 0.12, 2.3), (X0 + 0.02, DY1 + 0.06, 0), M["stipite"])
    box("porta_aperta", (0.05, 0.9, 2.1), (X0 + 0.1, DY1 - 0.3, 0), M["legno_scuro"], rot=(0, 0, -25))
    box("porta_maniglia", (0.03, 0.14, 0.03), (X0 + 0.24, DY1 - 0.62, 1.02), M["ottone"], rot=(0, 0, -25))

    # Muro destro: frigorifero, mobiletto col microonde, calendario, mobile
    # basso davanti.
    muro_con_buchi("muro_dx", "y", X1, Y0 - 0.2, Y1, HC, [], muro)
    FRX = X1 - 0.36
    box("frigo", (0.68, 0.66, 1.78), (FRX, Y1 - 0.4, 0), frigo)
    box("frigo_fuga", (0.68, 0.02, 0.02), (FRX, Y1 - 0.74, 1.12), nero)
    box("frigo_maniglia1", (0.03, 0.04, 0.3), (FRX - 0.28, Y1 - 0.75, 1.3), inox)
    box("frigo_maniglia2", (0.03, 0.04, 0.3), (FRX - 0.28, Y1 - 0.75, 0.75), inox)
    for k, (dx, dz, col) in enumerate(((-0.15, 1.45, "#C9A25A"), (0.05, 1.5, "#7C8A5A"), (0.12, 1.35, "#A85A4A"),
                                       (-0.05, 1.3, "#E0D7B0"))):
        box(f"calamita{k}", (0.08, 0.01, 0.1), (FRX + dx, Y1 - 0.735, dz), piatto(f"calam{k}", col, 0.6))
    box("frigo_scatola", (0.24, 0.2, 0.2), (FRX - 0.15, Y1 - 0.4, 1.78), piatto("scatola_rossa", "#8A3A2A", 0.7))
    tornio("frigo_bottiglia", [(0.04, 0), (0.04, 0.22), (0.014, 0.3), (0.014, 0.36)], (FRX + 0.05, Y1 - 0.4, 1.78),
           vetro_verde, seg=10)
    box("frigo_barattolo", (0.14, 0.14, 0.16), (FRX + 0.2, Y1 - 0.4, 1.78), piatto("latta", "#B08A3A", 0.5))
    box("mobiletto", (0.5, 0.8, 0.86), (X1 - 0.25, 4.45, 0), mobile)
    box("mobiletto_piano", (0.53, 0.83, 0.04), (X1 - 0.26, 4.45, 0.86), piano_lav)
    box("mobiletto_anta", (0.02, 0.72, 0.7), (X1 - 0.51, 4.45, 0.1), anta)
    box("microonde", (0.36, 0.48, 0.28), (X1 - 0.22, 4.5, 0.9), smalto)
    box("microonde_vetro", (0.02, 0.3, 0.2), (X1 - 0.41, 4.44, 0.94), nero)
    quadro("calendario", 0.3, 0.44, (X1 - 0.02, 4.4, 1.6), piatto("calendario_carta", "#E8E0CC", 0.9),
           "#6E8A5A", "#9DB2C0", rot=(90, 0, -90), seme=6.0)
    box("gancio_dx", (0.08, 0.02, 0.02), (X1 - 0.04, 3.6, 1.5), M["ferro"])
    box("presina", (0.02, 0.18, 0.4), (X1 - 0.03, 3.6, 1.08), tessuto)
    box("base_davanti", (0.6, 1.2, 0.86), (X1 - 0.3, 2.0, 0), mobile)
    box("base_davanti_piano", (0.63, 1.24, 0.04), (X1 - 0.31, 2.0, 0.86), piano_lav)
    for k, yy in enumerate((1.7, 2.3)):
        box(f"base_davanti_anta{k}", (0.02, 0.56, 0.7), (X1 - 0.61, yy, 0.1), anta)
    tornio("ciotola", [(0.06, 0), (0.13, 0.07), (0.14, 0.08)], (X1 - 0.3, 2.2, 0.9),
           piatto("ciotola", "#4E5A66", 0.4), seg=16)

    # Il tavolo, le sedie, il lampadario.
    TX, TY = 0.2, 3.85
    box("tavolo", (1.0, 1.45, 0.05), (TX, TY, 0.74), M["legno"])
    for dx in (-0.44, 0.44):
        for dy in (-0.66, 0.66):
            box("tavolo_gamba", (0.06, 0.06, 0.74), (TX + dx, TY + dy, 0), M["legno_scuro"])
    box("tavolo_fascia", (0.92, 1.37, 0.1), (TX, TY, 0.64), M["legno_scuro"])
    sedia("sedia_fondo", (TX - 0.05, TY + 0.95, 0), 0, M["legno_scuro"])
    sedia("sedia_dx", (TX + 0.72, TY + 0.2, 0), 90, M["legno_scuro"])
    sedia("sedia_sx", (TX - 0.72, TY + 0.35, 0), -90, M["legno_scuro"])
    sedia("sedia_davanti", (TX + 0.1, TY - 0.95, 0), 180, M["legno_scuro"])
    box("sedia_panno", (0.2, 0.05, 0.3), (TX + 0.22, TY - 1.16, 0.66), tessuto)
    tornio("tavolo_bottiglia", [(0.04, 0), (0.04, 0.22), (0.014, 0.3), (0.014, 0.36)], (TX - 0.15, TY + 0.1, 0.79),
           vetro_verde, seg=12)
    tornio("posacenere", [(0.06, 0), (0.07, 0.03)], (TX + 0.15, TY - 0.05, 0.79), piatto("posacenere", "#B8B2A6", 0.3),
           seg=14)
    TL = HC - 0.95
    p_lampada = lampadario("lampadario", (TX, TY, HC), HC - TL,
                           piatto("paralume_cucina", "#34523B", 0.4, metal=0.2),
                           forma="piatto", energia=240.0)
    # Una falena che gira intorno alla lampadina: un pixel e mezzo di cosa, ma
    # e' quella che dice che la luce e' accesa da un pezzo.
    p_falena = perno("falena_perno", (TX, TY, TL - 0.2))
    falena = sfera("falena", 0.016, (0.22, 0, 0), piatto("falena", "#D8CFB8", 0.9, luce="#FFE8C0", forza=0.6),
                   parent=p_falena, linee=False, scala=(1.6, 1.0, 0.6))

    luce("riempi", "AREA", (0.0, 0.3, 2.5), 55.0, "#FFD9B0", rot=(70, 0, 0), dim=(3.0, 1.0))
    luce("finestra_luce", "AREA", ((FX0 + FX1) / 2, Y1 - 0.2, 1.7), 25.0, "#C8D6E4", rot=(90, 0, 0),
         dim=(1.0, 1.3))

    camera_frontale((0.0, -0.1, 1.66), 76.0, 126)

    # Il vapore della pentola: tre sbuffi che salgono, si allargano e spariscono.
    sbuffi = []
    for k in range(3):
        m = piatto(f"vapore{k}", "#E8E4DC", 1.0, luce="#E8E4DC", forza=0.3, alpha=0.3)
        ob = sfera(f"vapore{k}", 0.05, (PX, PY, 1.2), m, linee=False, seg=10)
        sbuffi.append((ob, m))

    def posa_vapore(t):
        for k, (ob, m) in enumerate(sbuffi):
            f = (t + k / 3.0) % 1.0
            ob.location = (PX + 0.04 * math.sin(f * 5 + k), PY, 1.16 + f * 0.45)
            s = 0.6 + f * 1.8
            ob.scale = (s, s, s * 0.8)
            _set(_bsdf(m), "Alpha", 0.32 * math.sin(math.pi * f) ** 1.2)

    # La goccia del rubinetto: si gonfia sul becco, cade, schizza.
    goccia_mat = piatto("goccia", "#B9D2E0", 0.05, luce="#C9DCE8", forza=0.5)
    becco_z, fondo_z = 1.13, 0.75
    goccia = sfera("goccia", 0.012, (LX, Y1 - 0.2, becco_z), goccia_mat, linee=False, seg=8)
    schizzo = sfera("schizzo", 0.02, (LX, Y1 - 0.2, fondo_z), goccia_mat, linee=False, seg=8,
                    scala=(1.8, 1.8, 0.3))

    def posa_goccia(t):
        i = t * 10
        schizzo.hide_render = True
        goccia.hide_render = False
        if i < 4:          # si gonfia sul becco
            s = 0.4 + 0.2 * i
            goccia.scale = (s, s, s * 1.2)
            goccia.location.z = becco_z - 0.004 * i
        elif i < 7:        # cade
            goccia.scale = (1, 1, 1.6)
            goccia.location.z = becco_z - ((i - 3) / 4.0) ** 2 * (becco_z - fondo_z)
        else:              # schizza nel lavello
            goccia.hide_render = True
            schizzo.hide_render = i >= 9
            s = 1.0 + (i - 7) * 0.6
            schizzo.scale = (1.8 * s, 1.8 * s, 0.3 * s)

    def posa_falena(t):
        a = 2 * math.pi * t
        p_falena.rotation_euler = Euler((0, 0, a))
        falena.location = (0.2 + 0.05 * math.sin(3 * a), 0, 0.06 * math.sin(2 * a))

    return {
        "animazioni": [
            dondolo("lampadario", p_lampada, 6.0, asse="Y", periodo=1.9, smorza=3.2,
                    pausa=(12.0, 26.0)),
            dondolo("strofinaccio", p_panno, 18.0, asse="X", pose=7, periodo=1.0, smorza=1.4,
                    pausa=(15.0, 35.0)),
            ciclo("vapore", posa_vapore, 12, 6),
            ciclo("falena", posa_falena, 12, 10),
            evento("goccia", posa_goccia, 10, 10, (2.5, 7.0)),
        ],
        "punti": {
            "finestra": [(FX0, Y1, FZ0), (FX1, Y1, FZ0), (FX0, Y1, FZ1), (FX1, Y1, FZ1)],
            "personaggio": (-1.6, 3.95, 0.0),
        },
    }


# ----------------------------------------------------------------------
#  CANTINA
# ----------------------------------------------------------------------

def camera_iso(centro, scala, pendenza=35.26, imbardata=45.0, shift=(0.0, 0.0)):
    """Camera ortografica in isometria, che guarda l'angolo di fondo della
    stanza (x = 0, y = massimo): i due muri di fondo si aprono a V e i due
    davanti non ci sono, come nei plastici e nel disegno di partenza."""
    p = math.radians(pendenza)
    a = math.radians(imbardata)
    verso = Vector((-math.sin(a) * math.cos(p), math.cos(a) * math.cos(p), -math.sin(p)))
    pos = Vector(centro) - verso * 30.0
    return camera_libera(tuple(pos), (90.0 - pendenza, 0.0, imbardata), orto=scala, shift=shift)


def cassa(name, dim, loc, mat, rot_z=0.0, coperchio=None):
    box(name, dim, loc, mat, rot=(0, 0, rot_z))
    if coperchio:
        box(name + "_coperchio", (dim[0] + 0.03, dim[1] + 0.03, 0.04),
            (loc[0], loc[1], loc[2] + dim[2]), coperchio, rot=(0, 0, rot_z))


def cantina():
    """Il seminterrato: il posto dove si coltiva.

    Dal disegno: muri di mattoni con le travi di legno, pavimento di assi, la
    scaffalatura dei barattoli con la lanterna sopra, il banco di lavoro con gli
    attrezzi appesi, la caldaia con la fiamma nella finestrella e lo scaldabagno,
    i tubi, la scala che sale, le casse. In mezzo il tavolo lungo dei vasi.

    Due cose sono del gioco e non del disegno:

      * **il tavolo e' il posto dei sei vasi.** I vasi e le lampade da
        coltivazione li disegna il gioco (`GrowPlot`, `GrowLamp`), qui c'e'
        solo il piano vuoto; le sei posizioni si calcolano sul piano e finiscono
        in `punti.vasi`, due file da tre, la fila di fondo per prima;
      * **la finestrella e' oscurata.** Il disegno ne aveva una con il cielo
        blu, ma la cantina in gioco non vede l'ora (`daylight = false`): una
        finestra col giorno fuori a mezzanotte si noterebbe subito. Qui e'
        chiusa col cartone, come la chiude chi coltiva di sotto.
    """
    mondo("#1A1820", 0.45)
    mattoni = mattonelle("mattoni", "#4E4852", "#443F49", "#29252D", lato=0.075, largh=0.24,
                         fuga_px=0.012, sfalsa=0.5, piano="xz",
                         sporco=("#342F36", 2.0, 0.7), rough=0.9)
    mattoni_y = mattonelle("mattoni_y", "#4E4852", "#443F49", "#29252D", lato=0.075, largh=0.24,
                           fuga_px=0.012, sfalsa=0.5, piano="yz",
                           sporco=("#342F36", 2.0, 0.7), rough=0.9)
    assi = mattonelle("assi", "#6E4B33", "#62432D", "#2A1D15", lato=0.2, largh=1.3,
                      fuga_px=0.008, sfalsa=0.37, piano="xy",
                      sporco=("#4A3222", 3.0, 0.6), rough=0.7)
    trave = macchiato("trave", "#6A4428", "#5A3920", scala=5, stira=(1, 1, 6))
    legno = macchiato("legno_cantina", "#7A4E2E", "#6A4226", scala=6, stira=(6, 1, 1))
    legno_s = macchiato("legno_scaffale", "#5E3C24", "#52341F", scala=6, stira=(1, 1, 6))
    verde = macchiato("verde_militare", "#4A5A3A", "#415033", scala=5)
    rosso = piatto("rosso_latta", "#8E2E26", 0.5)
    ferro = piatto("ferro_cantina", "#5A5C60", 0.45, metal=0.7)
    tubo = piatto("tubo_cantina", "#8C9094", 0.35, metal=0.8)
    cartone = macchiato("cartone", "#9C7A52", "#8C6C46", scala=6)
    tappeto = macchiato("tappeto_cantina", "#6A2A24", "#5A221D", scala=10,
                        macchie=("#9A7048", 7.0, 0.66, 0.55))
    bianco = piatto("bianco_boiler", "#CFCBC2", 0.35)

    L = 5.6                   # lato della stanza
    HM = 2.5                  # altezza dei muri

    box("pavimento", (L, L, 0.08), (L / 2, L / 2, -0.08), assi)
    box("muro_sx", (0.2, L + 0.2, HM), (-0.1, L / 2 + 0.1, 0), mattoni_y)
    box("muro_dx", (L, 0.2, HM), (L / 2, L + 0.1, 0), mattoni)
    # Le travi in cima ai muri e il pilastro d'angolo, come nel disegno.
    box("trave_sx", (0.22, L + 0.2, 0.2), (0.05, L / 2 + 0.1, HM), trave)
    box("trave_dx", (L + 0.1, 0.22, 0.2), (L / 2, L - 0.05, HM), trave)
    for k, y in enumerate((1.6, 3.4)):
        box(f"trave_sx_montante{k}", (0.14, 0.14, HM), (0.07, y, 0), trave)
    box("trave_dx_montante", (0.14, 0.14, HM), (3.3, L - 0.07, 0), trave)
    box("battiscopa_sx", (0.03, L, 0.08), (0.015, L / 2, 0), trave)
    box("battiscopa_dx", (L, 0.03, 0.08), (L / 2, L - 0.015, 0), trave)

    # --- Muro di sinistra: scaffale dei barattoli, finestrella, banco --------
    SY0 = 0.55
    for k in range(5):
        box(f"scaffale_piano{k}", (0.45, 1.3, 0.03), (0.28, SY0 + 0.65, 0.1 + k * 0.45), legno)
    for dy in (0, 1.26):
        for dx in (0.06, 0.46):
            box("scaffale_montante", (0.04, 0.04, 1.95), (dx, SY0 + 0.02 + dy, 0), legno_s)
    colori = ["#7A5A3A", "#5A6A4A", "#8A6A3A", "#6A4A3A", "#4A5A5A", "#9A7A4A", "#5A4A3A"]
    rnd = random.Random(5)
    for k in range(4):
        z = 0.13 + k * 0.45
        y = SY0 + 0.12
        while y < SY0 + 1.2:
            if rnd.random() < 0.3:
                larg = rnd.uniform(0.22, 0.3)
                box(f"scatola{k}_{y:.2f}", (0.3, larg, rnd.uniform(0.14, 0.22)), (0.26, y + larg / 2, z),
                    cartone if rnd.random() < 0.6 else verde)
                y += larg + 0.03
            else:
                r = rnd.uniform(0.05, 0.07)
                tornio(f"barattolo{k}_{y:.2f}", [(r, 0), (r, rnd.uniform(0.14, 0.24))],
                       (0.26, y + r, z), piatto(f"bar{k}{y:.2f}", rnd.choice(colori), 0.4), seg=10)
                y += 2 * r + 0.03
    # La lanterna in cima allo scaffale: e' lei a tremolare.
    LAN = (0.26, SY0 + 0.3, 1.94)
    ottone = piatto("ottone_cantina", "#8A6A32", 0.4, metal=0.8)
    box("lanterna_base", (0.12, 0.12, 0.03), LAN, ottone)
    lanterna_vetro = piatto("lanterna_vetro", "#FFC070", 0.2, luce="#FFB050", forza=6.0)
    tornio("lanterna_vetro", [(0.045, 0), (0.05, 0.08), (0.04, 0.16)], (LAN[0], LAN[1], LAN[2] + 0.03),
           lanterna_vetro, seg=12, linee=False)
    box("lanterna_tetto", (0.12, 0.12, 0.03), (LAN[0], LAN[1], LAN[2] + 0.19), ottone)
    cilindro("lanterna_manico", 0.008, 0.08, (LAN[0], LAN[1], LAN[2] + 0.22), ottone, seg=6)
    luce_lanterna = luce("lanterna_luce", "POINT", (LAN[0] + 0.15, LAN[1], LAN[2] + 0.1), 14.0,
                         "#FFAA55", raggio=0.05, portata=1.4)
    # Piante finte che pendono dallo scaffale: nel disegno c'era l'edera.
    edera = macchiato("edera", "#3E6A32", "#2E5226", scala=12)
    for k in range(5):
        sfera(f"edera{k}", 0.09, (0.46, SY0 + 0.9 + k * 0.08, 1.9 - k * 0.14), edera,
              scala=(0.6, 1.3, 1.6))
    # Finestrella in alto, chiusa col cartone.
    WY = 2.45
    box("finestrella_telaio", (0.12, 0.9, 0.5), (0.02, WY, 1.8), legno_s)
    box("finestrella_cartone", (0.02, 0.78, 0.4), (0.08, WY, 1.85), cartone)
    box("finestrella_nastro1", (0.01, 0.8, 0.04), (0.095, WY, 2.03), piatto("nastro", "#C8C0A0", 0.6),
        rot=(20, 0, 0))
    box("finestrella_nastro2", (0.01, 0.8, 0.04), (0.095, WY, 2.03), bpy.data.materials["nastro"],
        rot=(-20, 0, 0))
    # Il banco da lavoro col PC: vecchio monitor a tubo, tastiera, sedia.
    BY = 3.95
    box("banco", (0.7, 1.6, 0.05), (0.38, BY, 0.8), legno)
    for dy in (-0.75, 0.75):
        for dx in (0.08, 0.66):
            box("banco_gamba", (0.06, 0.06, 0.8), (dx, BY + dy, 0), legno_s)
    box("cassettiera", (0.55, 0.45, 0.78), (0.32, BY - 0.5, 0), verde)
    for k in range(3):
        box(f"cassetto{k}", (0.02, 0.38, 0.2), (0.6, BY - 0.5, 0.06 + k * 0.25), verde)
        box(f"maniglia_cassetto{k}", (0.03, 0.12, 0.02), (0.615, BY - 0.5, 0.2 + k * 0.25), ottone)
    box("cassettiera_rossa", (0.45, 0.4, 0.6), (0.3, BY + 0.5, 0), rosso)
    monitor = piatto("monitor", "#C9C2B0", 0.5)
    box("monitor", (0.4, 0.42, 0.36), (0.26, BY + 0.05, 0.85), monitor, rot=(0, 0, 0))
    box("monitor_schermo", (0.02, 0.32, 0.26), (0.47, BY + 0.05, 0.9),
        piatto("schermo", "#2A4A3A", 0.2, luce="#4A9A6A", forza=1.2))
    box("monitor_retro", (0.22, 0.3, 0.26), (0.08, BY + 0.05, 0.89), monitor)
    box("tastiera", (0.18, 0.44, 0.03), (0.58, BY + 0.05, 0.85), monitor, rot=(0, 0, 0))
    box("case_pc", (0.45, 0.2, 0.42), (0.3, BY + 0.55, 0.85), monitor)
    luce("schermo_luce", "AREA", (0.6, BY + 0.05, 1.03), 3.0, "#6ACA8A", rot=(0, 90, 0), dim=(0.3, 0.3))
    tornio("tazza_cantina", [(0.04, 0), (0.045, 0.09)], (0.6, BY - 0.45, 0.85), bianco, seg=10)
    # Il pannello forato con gli attrezzi, il bersaglio, i poster.
    box("pannello", (0.02, 1.0, 0.55), (0.01, BY, 1.25), piatto("pannello_forato", "#8A6A4A", 0.8))
    for k in range(6):
        box(f"attrezzo{k}", (0.02, 0.035, 0.25 + (k % 3) * 0.05), (0.03, BY - 0.38 + k * 0.15, 1.38), ferro)
    tornio("bersaglio", [(0.0, 0), (0.2, 0), (0.2, 0.04)], (0.02, BY + 0.9, 1.5),
           macchiato("bersaglio", "#2A2A26", "#B0A080", scala=30, da=0.45, a_=0.55), seg=20, rot=(0, 90, 0))
    for k, (y, col_a, col_b) in enumerate(((1.95, "#C8B89A", "#5A4A3A"), (3.2, "#B89A6A", "#3A4A5A"))):
        quadro(f"poster{k}", 0.4, 0.55, (0.02, y, 1.5), piatto(f"poster_bordo{k}", "#D8CCB0", 0.8),
               col_a, col_b, rot=(90, 0, 90), seme=10.0 + k)

    # --- Muro di destra: scaldabagno, caldaia, tubi, scala -------------------
    tornio("scaldabagno", [(0.0, 0), (0.28, 0.0), (0.3, 0.05), (0.3, 1.45), (0.25, 1.55), (0.0, 1.58)],
           (0.75, L - 0.4, 0), bianco, seg=20)
    for k in range(2):
        cilindro(f"scaldabagno_tubo{k}", 0.03, HM - 1.58, (0.68 + k * 0.14, L - 0.4, 1.58), tubo, seg=8)
    sfera("valvola_rossa", 0.06, (0.82, L - 0.42, 1.75), rosso, scala=(1.3, 1.3, 0.5))
    # La caldaia, con la finestrella della fiamma che guarda la stanza.
    CX = 1.65
    grigio = piatto("caldaia", "#6A6E72", 0.5, metal=0.3)
    box("caldaia", (0.8, 0.7, 1.25), (CX, L - 0.45, 0), grigio)
    box("caldaia_griglia", (0.5, 0.02, 0.18), (CX, L - 0.81, 0.12), piatto("griglia_caldaia", "#2A2C2E", 0.5))
    box("caldaia_sportello", (0.3, 0.02, 0.2), (CX, L - 0.81, 0.62), piatto("sportello", "#3A3C3E", 0.4))
    fuoco_mat = piatto("fiamma", "#FF8A2A", 0.5, luce="#FF7A20", forza=8.0)
    fuoco = box("caldaia_fiamma", (0.2, 0.02, 0.1), (CX, L - 0.825, 0.67), fuoco_mat, linee=False)
    luce_fuoco = luce("fiamma_luce", "SPOT", (CX, L - 0.9, 0.72), 12.0, "#FF8A3A", raggio=0.05,
                      rot=(95, 0, 180), cono=110, portata=1.8)
    cilindro("caldaia_camino", 0.12, HM - 1.25, (CX, L - 0.45, 1.25), tubo, seg=14)
    for k in range(3):
        cilindro(f"camino_anello{k}", 0.13, 0.03, (CX, L - 0.45, 1.5 + k * 0.35), tubo, seg=14)
    # Tubi lungo il muro, con un gomito che gocciola.
    for k, (x, r) in enumerate(((2.35, 0.05), (2.55, 0.035), (2.7, 0.035))):
        cilindro(f"tubo_muro{k}", r, HM, (x, L - 0.12, 0), tubo, seg=10)
    GX, GY = 2.5, L - 0.25            # il gomito che perde
    cilindro("tubo_orizz", 0.04, 2.2, (2.35, L - 0.12, 2.1), tubo, seg=10, rot=(0, 90, 0))
    cilindro("tubo_scende", 0.04, 0.4, (GX, L - 0.12, 1.7), tubo, seg=10)
    cilindro("tubo_gocciola", 0.04, 0.13, (GX, L - 0.12, 1.7), tubo, seg=10, rot=(90, 0, 0))
    sfera("tubo_gomito", 0.055, (GX, GY, 1.7), tubo)
    tornio("secchio", [(0.13, 0), (0.16, 0.26), (0.165, 0.27)], (GX, GY - 0.05, 0), ferro, seg=16)
    box("secchio_acqua", (0.2, 0.2, 0.01), (GX, GY - 0.05, 0.2), piatto("acqua", "#3A4A5A", 0.1), linee=False)
    # Scopa appoggiata, bidone.
    cilindro("scopa_manico", 0.015, 1.4, (3.45, L - 0.12, 0.25), legno_s, seg=6, rot=(8, 0, 0))
    tornio("scopa_testa", [(0.02, 0), (0.1, 0.25), (0.02, 0.3)], (3.45, L - 0.1, 0), cartone, seg=8,
           scala=(1, 0.4, 1))
    tornio("bidone", [(0.2, 0), (0.22, 0.55), (0.23, 0.58)], (3.05, L - 0.35, 0), ferro, seg=16)
    tornio("bidone_coperchio", [(0.24, 0), (0.1, 0.05), (0.03, 0.08)], (3.05, L - 0.35, 0.58), ferro, seg=16)
    cassa("scatoloni1", (0.5, 0.4, 0.35), (3.3, 4.1, 0), cartone)
    cassa("scatoloni2", (0.45, 0.35, 0.3), (3.32, 4.1, 0.35), cartone, rot_z=8)
    # La scala che sale, lungo il muro di destra verso il davanti.
    SX0 = 3.7
    GRAD = 11
    ALZ, PED = 0.22, 0.26
    gradino = macchiato("gradino_cantina", "#8A5E3A", "#7A5232", scala=6, stira=(1, 6, 1))
    for i in range(GRAD):
        x = SX0 + i * PED
        box(f"gradino{i}", (PED + 0.03, 0.95, 0.05), (x + PED / 2, L - 0.5, (i + 1) * ALZ - 0.05), gradino)
        box(f"alzata{i}", (0.02, 0.95, ALZ), (x, L - 0.5, i * ALZ), legno_s)
    profilo = [(SX0, 0.0)]
    for i in range(GRAD):
        profilo += [(SX0 + i * PED, (i + 1) * ALZ), (SX0 + (i + 1) * PED, (i + 1) * ALZ)]
    profilo += [(SX0 + GRAD * PED, 0.0)]
    prisma_xz("fianco_scala", profilo, L - 1.02, 0.04, legno_s)
    for i in range(0, GRAD, 2):
        box(f"ringhiera{i}", (0.04, 0.04, 0.9), (SX0 + i * PED + PED / 2, L - 1.0, (i + 1) * ALZ), legno_s)
    lung = math.hypot(GRAD * PED, GRAD * ALZ)
    # Il corrimano ha l'origine a meta' (sotto al centro): va messo a meta'
    # della rampa, non al primo gradino.
    box("corrimano", (lung, 0.06, 0.06),
        (SX0 + GRAD * PED / 2 + PED / 2, L - 1.0, 0.9 + ALZ + GRAD * ALZ / 2),
        legno, rot=(0, -math.degrees(math.atan2(ALZ, PED)), 0))
    # Applique sul muro della scala.
    box("applique", (0.1, 0.06, 0.16), (SX0 + 0.3, L - 0.05, 1.7), ottone)
    sfera("applique_vetro", 0.06, (SX0 + 0.3, L - 0.13, 1.72),
          piatto("applique_vetro", "#FFD8A0", 0.2, luce="#FFC880", forza=5.0), linee=False)
    luce("applique_luce", "POINT", (SX0 + 0.3, L - 0.3, 1.72), 10.0, "#FFC080", raggio=0.1)
    luce("scala_luce", "POINT", (4.7, L - 0.8, 2.4), 22.0, "#FFC890", raggio=0.3)

    # --- Il pavimento: tavolo dei vasi, tappeti, casse ---------------------
    TX, TY = 2.3, 2.5                 # centro del tavolo
    TL, TW, TH = 2.5, 1.15, 0.8       # lungo (su Y), largo (su X), alto
    box("tappeto", (2.6, 3.4, 0.012), (TX, TY, 0), tappeto)
    box("tavolo_piano", (TW, TL, 0.06), (TX, TY, TH - 0.06), legno)
    box("tavolo_fascia", (TW - 0.1, TL - 0.1, 0.12), (TX, TY, TH - 0.18), legno_s)
    for dx in (-TW / 2 + 0.07, TW / 2 - 0.07):
        for dy in (-TL / 2 + 0.07, TL / 2 - 0.07):
            box("tavolo_gamba", (0.08, 0.08, TH - 0.06), (TX + dx, TY + dy, 0), legno_s)
    sedia("sgabello_tavolo", (TX + TW / 2 + 0.35, TY + 0.4, 0), 90, legno_s, schienale=False)
    box("tappeto2", (1.2, 0.8, 0.012), (2.1, 4.65, 0), tappeto, rot=(0, 0, 10))
    box("tappeto3", (0.9, 1.1, 0.012), (4.9, 3.0, 0), tappeto, rot=(0, 0, -6))
    # Casse, taniche, cassette in basso a sinistra, come nel disegno.
    cassa("cassa_verde1", (0.6, 0.45, 0.4), (0.35, 0.0, 0), verde, coperchio=verde)
    cassa("cassa_legno1", (0.5, 0.45, 0.4), (0.3, 0.4, 0), legno_s)
    cassa("cassa_verde2", (0.5, 0.4, 0.32), (0.32, 0.25, 0.4), verde, coperchio=verde, rot_z=6)
    box("tanica", (0.3, 0.16, 0.42), (1.05, 0.2, 0), rosso)
    box("tanica_manico", (0.12, 0.04, 0.05), (1.05, 0.2, 0.42), rosso)
    for k in range(3):
        tornio(f"barattolo_terra{k}", [(0.07, 0), (0.07, 0.18)], (1.35 + k * 0.17, 0.25, 0),
               piatto(f"bt{k}", ("#8A8A7A", "#5A6A4A", "#6A5A4A")[k], 0.5), seg=10)
    cassa("cassa_fondo", (0.55, 0.5, 0.45), (5.1, 4.2, 0), verde, coperchio=verde)
    cassa("cassa_fondo2", (0.5, 0.5, 0.4), (5.15, 4.2, 0.45), cartone)
    box("tanica2", (0.3, 0.16, 0.42), (4.6, 4.4, 0), rosso, rot=(0, 0, 20))

    # --- Luci -----------------------------------------------------------
    # Il lampadario da officina sopra al banco: e' la luce principale.
    p_lampada = lampadario("lampadario", (1.45, 4.35, 3.0), 0.9,
                           piatto("paralume_cantina", "#2E3A2E", 0.4, metal=0.3),
                           forma="cono", energia=230.0)
    # Riempimento freddo e basso: la cantina e' buia, ma la stanza si deve leggere.
    luce("riempi", "AREA", (4.5, 1.0, 3.2), 60.0, "#B0A8C8", rot=(45, 0, 225), dim=(3.0, 3.0))
    luce("riempi_tavolo", "POINT", (TX, TY, 2.4), 45.0, "#FFD0A0", raggio=0.8)

    camera_iso((2.55, 3.1, 1.3), 7.4)

    # --- Animazioni -------------------------------------------------------
    fuoco_base = fuoco_mat.node_tree.nodes
    bsdf_fuoco = _bsdf(fuoco_mat)
    bsdf_lanterna = _bsdf(lanterna_vetro)

    def tremolio(t, semi):
        return sum(math.sin(2 * math.pi * (t * f) + s) for f, s in semi) / len(semi)

    def posa_caldaia(t):
        v = tremolio(t, [(1, 0.3), (2, 1.7), (3, 4.1)])
        _set(bsdf_fuoco, "Emission Strength", 8.0 + 3.5 * v)
        luce_fuoco.data.energy = 12.0 + 6.0 * v

    def posa_lanterna(t):
        v = tremolio(t, [(1, 2.1), (2, 0.4), (3, 5.0)])
        _set(bsdf_lanterna, "Emission Strength", 6.0 + 2.0 * v)
        luce_lanterna.data.energy = 14.0 + 5.0 * v

    goccia_mat = piatto("goccia_cantina", "#9AB8CA", 0.05, luce="#9AB8CA", forza=0.6)
    goccia = sfera("goccia", 0.018, (GX, GY, 1.66), goccia_mat, linee=False, seg=8)
    anello = tornio("anello", [(0.03, 0), (0.05, 0.002)], (GX, GY - 0.05, 0.21),
                    piatto("anello", "#8AA8BA", 0.1, luce="#8AA8BA", forza=0.4), seg=16, linee=False)

    def posa_goccia(t):
        i = t * 10
        anello.hide_render = True
        goccia.hide_render = False
        if i < 4:
            s = 0.4 + 0.2 * i
            goccia.scale = (s, s, s * 1.2)
            goccia.location.z = 1.66 - 0.005 * i
        elif i < 7:
            goccia.scale = (1, 1, 1.5)
            goccia.location.z = 1.66 - ((i - 3) / 4.0) ** 2 * (1.66 - 0.22)
        else:
            goccia.hide_render = True
            anello.hide_render = False
            s = 1.0 + (i - 7) * 1.2
            anello.scale = (s, s, 1)

    # Il topo: esce da dietro le casse del fondo, corre lungo il muro e si
    # infila dietro la caldaia.
    pelo = piatto("topo", "#4A423C", 0.9)
    p_topo = perno("topo", (5.0, L - 0.15, 0))
    sfera("topo_corpo", 0.05, (0, 0, 0.04), pelo, parent=p_topo, scala=(1.6, 0.9, 0.8))
    sfera("topo_testa", 0.03, (-0.08, 0, 0.05), pelo, parent=p_topo, scala=(1.3, 1, 1))
    cilindro("topo_coda", 0.006, 0.16, (0.07, 0, 0.02), pelo, seg=5, rot=(0, 80, 0), parent=p_topo)
    topo_via = Vector((5.0, L - 0.15, -0.3))

    def posa_topo(t):
        if t == 0.0:
            p_topo.location = topo_via
            return
        # Da x 4.4 (casse) a x 2.1 (caldaia), con una sosta a meta'.
        f = t / (1.0 - 1.0 / 20)
        if f < 0.4:
            x = 4.4 - (f / 0.4) * 1.1
        elif f < 0.6:
            x = 3.3 - (f - 0.4) * 0.3
        else:
            x = 3.24 - ((f - 0.6) / 0.4) * 1.2
        # Gira intorno al bidone invece di passargli attraverso.
        scarto = max(0.0, 1.0 - abs(x - 3.05) / 0.35) * 0.35
        p_topo.location = (x, L - 0.15 - scarto, 0)

    posa_topo(0.0)

    # I sei vasi: due file da tre lungo il tavolo. Fila di fondo = verso il
    # muro di sinistra (x piccola), che in isometria e' la piu' lontana.
    vasi = []
    for fila, dx in ((0, -0.27), (1, 0.27)):
        for col, dy in enumerate((0.8, 0.0, -0.8)):
            vasi.append((TX + dx, TY + dy, TH))

    return {
        "animazioni": [
            dondolo("lampadario", p_lampada, 6.0, asse="X", periodo=2.0, smorza=3.5,
                    pausa=(10.0, 24.0)),
            ciclo("caldaia", posa_caldaia, 12, 10),
            ciclo("lanterna", posa_lanterna, 12, 8),
            evento("goccia", posa_goccia, 10, 10, (3.0, 8.0)),
            evento("topo", posa_topo, 20, 12, (40.0, 90.0)),
        ],
        "punti": {
            "personaggio": (4.1, 4.0, 0.0),
            "vasi": vasi,
            "pc": [(0.1, BY - 0.2, 0.85), (0.5, BY + 0.3, 0.85), (0.1, BY - 0.2, 1.21),
                   (0.5, BY + 0.3, 1.21), (0.5, BY - 0.2, 1.21), (0.1, BY + 0.3, 0.85)],
        },
    }


# ----------------------------------------------------------------------
#  GARAGE
# ----------------------------------------------------------------------

def cartello(name, righe, loc, dim, fondo, inchiostro, rot=(90, 0, 0), corpo=0.1):
    """Un cartello di latta con le scritte. Poche parole e grandi: sotto i sei
    pixel una lettera ridotta diventa poltiglia (vedi `blender_officina.py`)."""
    p = perno(name, loc)
    p.rotation_euler = Euler(tuple(math.radians(r) for r in rot))
    box(name + "_lastra", (dim[0], dim[1], 0.015), (0, 0, 0), fondo, parent=p)
    n = len(righe)
    for i, r in enumerate(righe):
        z = (n - 1) / 2 * corpo * 1.15 - i * corpo * 1.15
        testo(f"{name}_{i}", r, (0, z, 0.02), inchiostro, dim=corpo, rot=(0, 0, 0), parent=p)
    return p


def garage():
    """Il garage della seconda proprieta': il posto dei dodici vasi.

    Dal disegno: pavimento di cemento macchiato d'olio e crepato, i due banconi
    di legno in mezzo, la finestra rotta in alto a sinistra, il pannello degli
    attrezzi e il banco da lavoro, lo scaffale di metallo, l'armadietto, le
    gomme impilate, la serranda a destra coi vetri da cui entra la luce, le
    casse davanti, i cartelli ("STILL RUNS SOMEHOW").

    Come in cantina, i banconi sono vuoti: vasi e lampade li disegna il gioco,
    e le dodici posizioni finiscono in `punti.vasi` — due banconi, due file da
    tre ciascuno, nell'ordine dei nodi `Plot6`..`Plot17`.
    """
    mondo("#2A2A2E", 0.5)
    cemento = macchiato("cemento", "#77736A", "#6B675F", scala=3.0,
                        macchie=("#4A463F", 2.2, 0.63, 0.85), rough=0.8)
    muro = macchiato("muro_garage", "#6E6A62", "#625E57", scala=2.2,
                     macchie=("#4E4A44", 2.8, 0.64, 0.8), seme=4.0)
    legno_b = macchiato("legno_banco", "#8A5A32", "#7A4E2A", scala=5, stira=(6, 1, 1), rough=0.6)
    legno_s = macchiato("legno_banco_scuro", "#5E3C22", "#52341E", scala=5, stira=(1, 1, 6))
    metallo = piatto("scaffale_metallo", "#6A6C70", 0.45, metal=0.6)
    ruggine = macchiato("armadietto", "#6E7468", "#62685C", scala=4,
                        macchie=("#7A5236", 5.0, 0.64, 0.8), metal=0.3, rough=0.6)
    verde = macchiato("verde_cassa", "#4A5A3A", "#415033", scala=5)
    rosso = piatto("rosso_garage", "#9A2E26", 0.45)
    gomma = piatto("gomma", "#1E1E20", 0.8)
    cartone = macchiato("cartone_garage", "#9C7A52", "#8C6C46", scala=6)
    telone = macchiato("telone", "#4E5A42", "#445036", scala=4)
    latta = macchiato("latta_cartello", "#D8CDB2", "#C8BC9E", scala=3, macchie=("#9A7A52", 4, 0.65, 0.7))
    inchiostro = piatto("inchiostro", "#2A2622", 0.8)
    serranda = mattonelle("serranda", "#B8B8B2", "#ACACA6", "#6A6A66", lato=0.6, largh=4.0,
                          fuga_px=0.012, piano="yz", rough=0.5)

    X0, X1 = -3.4, 3.4
    Y1 = 5.8
    HC = 3.1

    box("pavimento", (X1 - X0, Y1 + 1.0, 0.08), (0, Y1 / 2 - 0.5, -0.08), cemento)
    box("tombino", (0.8, 0.3, 0.01), (0.9, 0.9, 0), piatto("tombino", "#2A2A2A", 0.5, metal=0.5))
    for k in range(7):
        box(f"tombino_fessura{k}", (0.03, 0.24, 0.012), (0.6 + k * 0.1, 0.9, 0), piatto("fessura", "#0E0E0E", 1))
    # Le crepe: strisce sottili spezzate, niente texture.
    crepa = piatto("crepa", "#3A3632", 1.0)
    x, y = 0.1, 0.0
    rnd = random.Random(3)
    for k in range(9):
        nx, ny = x + rnd.uniform(-0.25, 0.25), y + rnd.uniform(0.2, 0.35)
        lung = math.hypot(nx - x, ny - y)
        box(f"crepa{k}", (0.02, lung, 0.003), ((x + nx) / 2, (y + ny) / 2, 0), crepa,
            rot=(0, 0, -math.degrees(math.atan2(nx - x, ny - y))), linee=False)
        x, y = nx, ny

    # Muri.
    muro_con_buchi("muro_fondo", "x", Y1, X0, X1, HC, [], muro)
    FY0, FY1, FZ0, FZ1 = 3.3, 4.5, 1.35, 2.25
    muro_con_buchi("muro_sx", "y", X0, -1.0, Y1, HC, [(FY0, FY1, FZ0, FZ1)], muro, verso=-1)
    # La serranda sul muro di destra: tutto il muro e' serranda.
    SY0, SY1, SH = 0.6, 5.2, 2.6
    muro_con_buchi("muro_dx", "y", X1, -1.0, Y1, HC, [(SY0, SY1, 0.0, SH)], muro)
    box("serranda", (0.05, SY1 - SY0, SH), (X1 + 0.03, (SY0 + SY1) / 2, 0), serranda)
    vetro_giorno = piatto("vetro_serranda", "#F2D9A8", 0.4, luce="#FFE2A8", forza=1.1)
    for k in range(4):
        box(f"serranda_vetro{k}", (0.02, 0.8, 0.28), (X1 + 0.0, SY0 + 0.4 + k * 1.12 + 0.3, 1.75), vetro_giorno,
            linee=False)
    for k, yy in enumerate((SY0 - 0.06, SY1 + 0.06)):
        box(f"serranda_guida{k}", (0.1, 0.1, SH), (X1 - 0.05, yy, 0), metallo)
    box("serranda_binario", (0.1, SY1 - SY0, 0.1), (X1 - 0.05, (SY0 + SY1) / 2, SH + 0.02), metallo)
    box("serranda_maniglia", (0.04, 0.2, 0.05), (X1 - 0.01, (SY0 + SY1) / 2, 0.45), metallo)
    # La luce che filtra dai vetri e da sotto la serranda.
    # Le aree emettono lungo la propria -Z: ruotate di +90 su Y guardano -X,
    # cioe' dentro al garage e non contro la serranda.
    luce("serranda_luce", "AREA", (X1 - 0.3, (SY0 + SY1) / 2, 1.8), 45.0, "#FFD9A0",
         rot=(0, 90, 0), dim=(0.4, SY1 - SY0))
    luce("serranda_fessura", "AREA", (X1 - 0.1, (SY0 + SY1) / 2, 0.05), 20.0, "#FFD9A0",
         rot=(0, 90, 0), dim=(0.05, SY1 - SY0))

    # --- Muro di sinistra: finestra rotta, carrello rosso -------------------
    telaio = legno_s
    for k, yy in enumerate((FY0, (FY0 + FY1) / 2, FY1)):
        box(f"fin_montante{k}", (0.1, 0.06, FZ1 - FZ0), (X0 + 0.02, yy, FZ0), telaio)
    for k, zz in enumerate((FZ0, (FZ0 + FZ1) / 2, FZ1 - 0.05)):
        box(f"fin_traverso{k}", (0.1, FY1 - FY0, 0.05), (X0 + 0.02, (FY0 + FY1) / 2, zz), telaio)
    fuori = piatto("fuori_garage", "#D8C8A0", 1.0, luce="#E8D4A8", forza=1.3)
    box("fin_fuori", (0.02, FY1 - FY0 + 2.0, FZ1 - FZ0 + 1.5), (X0 - 0.3, (FY0 + FY1) / 2, FZ0 - 0.75), fuori,
        linee=False)
    # Un vetro rotto: triangoli di vetro rimasti nell'angolo del riquadro.
    rotto = piatto("vetro_rotto", "#9FB0B8", 0.1, alpha=0.5)
    for k, (yy, zz, s) in enumerate(((FY0 + 0.15, FZ1 - 0.15, 0.2), (FY0 + 0.4, FZ0 + 0.12, 0.14))):
        box(f"coccio{k}", (0.01, s, s), (X0 + 0.02, yy, zz - s / 2), rotto, rot=(45, 0, 0), linee=False)
    box("davanzale", (0.2, FY1 - FY0 + 0.2, 0.05), (X0 + 0.1, (FY0 + FY1) / 2, FZ0 - 0.05), telaio)
    # Ragnatele negli angoli alti.
    tela = piatto("ragnatela", "#D8D8D0", 0.9, alpha=0.35)
    for k, (x, y) in enumerate(((X0 + 0.25, Y1 - 0.25), (X1 - 0.25, Y1 - 0.25))):
        box(f"ragnatela{k}", (0.5, 0.01, 0.5), (x, y, HC - 0.5), tela, rot=(0, 0, 45 if k == 0 else -45),
            linee=False)
    # Carrello porta attrezzi rosso e il banco sotto la finestra.
    box("carrello", (0.5, 0.8, 0.9), (X0 + 0.3, 2.3, 0), rosso)
    for k in range(3):
        box(f"carrello_cassetto{k}", (0.02, 0.7, 0.2), (X0 + 0.56, 2.3, 0.35 + k * 0.18), rosso)
        box(f"carrello_maniglia{k}", (0.03, 0.4, 0.02), (X0 + 0.58, 2.3, 0.48 + k * 0.18), metallo)
    box("banco_sx", (0.6, 1.4, 0.05), (X0 + 0.3, 3.9, 0.8), legno_b)
    for dy in (-0.62, 0.62):
        box("banco_sx_gamba", (0.06, 0.06, 0.8), (X0 + 0.5, 3.9 + dy, 0), legno_s)
    box("radio", (0.22, 0.34, 0.2), (X0 + 0.25, 3.6, 0.85), piatto("radio", "#B8AE98", 0.5))
    cilindro("radio_manopola", 0.03, 0.02, (X0 + 0.36, 3.5, 0.95), inchiostro, seg=10, rot=(0, 90, 0))
    box("cassetta_attrezzi", (0.3, 0.45, 0.2), (X0 + 0.28, 4.25, 0.85), rosso)
    box("tanica_garage", (0.16, 0.3, 0.42), (X0 + 0.25, 1.5, 0), rosso)
    telone_ob = box("telone_sx", (0.8, 0.9, 0.6), (X0 + 0.4, 0.6, 0), telone)
    tornio("gomma_sx", [(0.22, 0), (0.3, 0.02), (0.32, 0.1), (0.3, 0.18), (0.22, 0.2)], (X0 + 0.7, 1.35, 0.3),
           gomma, seg=20, rot=(0, 75, 10))

    # --- Muro di fondo: pannello, banco col PC, scaffale, armadietto, gomme --
    BX = -2.35
    box("banco_pc", (1.5, 0.65, 0.05), (BX, Y1 - 0.33, 0.85), legno_b)
    for dx in (-0.68, 0.68):
        box("banco_pc_gamba", (0.06, 0.06, 0.85), (BX + dx, Y1 - 0.6, 0), legno_s)
    box("banco_pc_ripiano", (1.4, 0.55, 0.03), (BX, Y1 - 0.33, 0.2), legno_s)
    cassa("scatola_banco", (0.5, 0.4, 0.35), (BX + 0.3, Y1 - 0.33, 0.23), cartone)
    box("pannello_forato", (1.3, 0.03, 0.7), (BX, Y1 - 0.015, 1.0), piatto("pannello_garage", "#8A5E3E", 0.8))
    for k in range(7):
        box(f"chiave{k}", (0.04, 0.02, 0.22 + (k % 3) * 0.06), (BX - 0.5 + k * 0.16, Y1 - 0.04, 1.3 + (k % 2) * 0.08),
            metallo)
    beige = piatto("pc_beige", "#CFC6B0", 0.5)
    box("monitor_garage", (0.42, 0.4, 0.36), (BX - 0.2, Y1 - 0.33, 0.9), beige)
    box("monitor_garage_schermo", (0.32, 0.02, 0.26), (BX - 0.2, Y1 - 0.54, 0.95),
        piatto("schermo_garage", "#2A4A3A", 0.2, luce="#4A9A6A", forza=1.2))
    box("tastiera_garage", (0.44, 0.16, 0.03), (BX - 0.2, Y1 - 0.62, 0.9), beige)
    box("case_garage", (0.2, 0.42, 0.42), (BX + 0.3, Y1 - 0.33, 0.9), beige)
    luce("schermo_garage_luce", "AREA", (BX - 0.2, Y1 - 0.7, 1.08), 3.0, "#6ACA8A", rot=(90, 0, 0), dim=(0.3, 0.3))
    sedia("sgabello_garage", (BX + 0.1, Y1 - 1.05, 0), 0, metallo, schienale=False)
    cartello("cartello_attrezzi", ["GOOD TOOLS", "LONGER DAYS"], (BX + 0.1, Y1 - 0.01, 1.9), (0.84, 0.36),
             latta, inchiostro, corpo=0.11)
    # Scaffale di metallo coi barattoli e le cassette.
    SX = -0.6
    for k in range(4):
        box(f"scaffale_g{k}", (1.1, 0.45, 0.03), (SX, Y1 - 0.25, 0.1 + k * 0.55), metallo)
    for dx in (-0.53, 0.53):
        for dy in (-0.2, 0.2):
            box("scaffale_g_montante", (0.04, 0.04, 1.85), (SX + dx, Y1 - 0.25 + dy, 0), metallo)
    rnd = random.Random(11)
    for k in range(4):
        x = SX - 0.45
        while x < SX + 0.4:
            if rnd.random() < 0.5:
                w = rnd.uniform(0.25, 0.35)
                box(f"cassetta{k}_{x:.2f}", (w, 0.3, rnd.uniform(0.15, 0.25)), (x + w / 2, Y1 - 0.25, 0.13 + k * 0.55),
                    rnd.choice([verde, cartone, cartone]))
                x += w + 0.04
            else:
                r = rnd.uniform(0.07, 0.1)
                tornio(f"latta{k}_{x:.2f}", [(r, 0), (r, rnd.uniform(0.14, 0.22))], (x + r, Y1 - 0.25, 0.13 + k * 0.55),
                       piatto(f"lattag{k}{x:.2f}", rnd.choice(["#6A6E72", "#5A6A4A", "#8A6A3A", "#4A5A6A"]), 0.4,
                              metal=0.4), seg=12)
                x += 2 * r + 0.04
    # L'armadietto arrugginito.
    AX = 0.65
    box("armadietto", (0.9, 0.5, 1.9), (AX, Y1 - 0.26, 0), ruggine)
    box("armadietto_fuga", (0.01, 0.02, 1.8), (AX, Y1 - 0.52, 0.05), inchiostro)
    for dx in (-0.08, 0.08):
        box("armadietto_maniglia", (0.03, 0.03, 0.12), (AX + dx, Y1 - 0.53, 0.95), metallo)
        for k in range(3):
            box("armadietto_feritoia", (0.25, 0.01, 0.02), (AX + dx * 2.8, Y1 - 0.52, 1.6 + k * 0.06), inchiostro)
    cartello("cartello_auto", ["STILL RUNS", "SOMEHOW"], (1.85, Y1 - 0.01, 1.95), (0.8, 0.62),
             latta, inchiostro, corpo=0.1)
    # Le gomme impilate, la scopa, la cassa verde "GAS OIL LIFE".
    for k in range(4):
        tornio(f"gomma_pila{k}", [(0.2, 0), (0.3, 0.02), (0.32, 0.1), (0.3, 0.18), (0.2, 0.2)],
               (1.75, Y1 - 0.4, k * 0.2), gomma, seg=20)
    cilindro("scopa_g_manico", 0.015, 1.35, (1.35, Y1 - 0.15, 0.2), legno_s, seg=6, rot=(-10, 12, 0))
    tornio("scopa_g_testa", [(0.02, 0), (0.12, 0.26), (0.02, 0.3)], (1.3, Y1 - 0.2, 0), cartone, seg=8,
           scala=(1, 0.4, 1))
    box("cassa_gas", (0.7, 0.6, 0.8), (2.65, Y1 - 0.4, 0), verde)
    cartello("scritta_gas", ["GAS", "OIL", "LIFE"], (2.65, Y1 - 0.71, 0.4), (0.5, 0.55), verde,
             piatto("vernice", "#C8C0A0", 0.8), corpo=0.1)
    tornio("secchio_g", [(0.12, 0), (0.15, 0.28)], (3.05, Y1 - 0.9, 0), metallo, seg=14)
    for k, (x, a) in enumerate(((2.3, 8), (2.4, -5), (3.0, 12))):
        box(f"asse{k}", (0.08, 0.03, 1.4), (x, Y1 - 0.08, 0.0), legno_s, rot=(0, a, 0))

    # --- I due banconi dei vasi -------------------------------------------
    BH = 0.72
    banconi = []
    for nome, cx in (("sx", -1.15), ("dx", 1.15)):
        BW, BD, CY = 1.8, 1.0, 2.6
        box(f"bancone_{nome}", (BW, BD, 0.07), (cx, CY, BH - 0.07), legno_b)
        box(f"bancone_{nome}_fascia", (BW - 0.1, BD - 0.1, 0.12), (cx, CY, BH - 0.19), legno_s)
        for dx in (-BW / 2 + 0.08, BW / 2 - 0.08):
            for dy in (-BD / 2 + 0.08, BD / 2 - 0.08):
                box(f"bancone_{nome}_gamba", (0.09, 0.09, BH - 0.07), (cx + dx, CY + dy, 0), legno_s)
            box(f"bancone_{nome}_traverso", (0.05, BD - 0.2, 0.06), (cx + dx, CY, 0.18), legno_s)
        banconi.append((cx, CY, BW, BD))

    # Foglie secche sparse davanti alla serranda.
    foglia_mats = [piatto(f"foglia{k}", c, 0.9) for k, c in enumerate(("#9A5A22", "#B07A2A", "#7A4A1E"))]
    rnd = random.Random(8)
    for k in range(26):
        x = rnd.uniform(1.8, X1 - 0.1) if k < 18 else rnd.uniform(X0 + 0.3, -1.5)
        y = rnd.uniform(0.2, 5.3)
        box(f"foglia{k}", (0.07, 0.05, 0.004), (x, y, 0), foglia_mats[k % 3], rot=(0, 0, rnd.uniform(0, 180)),
            linee=False)

    # --- Davanti: casse e telone ------------------------------------------
    cassa("cassa_davanti1", (0.7, 0.6, 0.55), (-2.8, -0.2, 0), legno_s)
    cassa("cassa_davanti2", (0.55, 0.45, 0.4), (-2.75, -0.2, 0.55), verde, coperchio=verde)
    box("cassa_davanti3", (0.9, 0.6, 0.55), (-2.0, -0.6, 0), piatto("cassa_grigia", "#4A4E54", 0.6))
    box("telone_dx", (1.0, 0.9, 0.9), (2.8, -0.3, 0), telone)
    cartello("cassa_rossa", ["BETTER", "THINGS", "SOMEDAY"], (2.85, -0.76, 0.35), (0.7, 0.55),
             piatto("cassa_rossa", "#8A3A2E", 0.6), piatto("vernice_scura", "#C89A8A", 0.8), corpo=0.1)
    cassa("scatola_telone", (0.45, 0.35, 0.22), (2.8, -0.3, 0.9), cartone)

    # --- Luci ---------------------------------------------------------------
    p_lampada = lampadario("lampadario", (0.0, 3.4, HC), 0.85,
                           piatto("paralume_garage", "#3A4A3A", 0.4, metal=0.3),
                           forma="cono", energia=280.0)
    luce("riempi", "AREA", (0.0, -0.8, 3.2), 70.0, "#E8E0D0", rot=(40, 0, 0), dim=(5.0, 2.0))
    luce("finestra_garage", "AREA", (X0 + 0.3, (FY0 + FY1) / 2, 1.8), 18.0, "#FFE6B8", rot=(0, 90, 0),
         dim=(FY1 - FY0, FZ1 - FZ0))

    camera_libera((0.0, -1.5, 4.3), (52.0, 0.0, 0.0), fov=71.0)

    # --- Animazioni -------------------------------------------------------
    # Il ragno: scende dall'angolo della finestra appeso al filo, si ferma,
    # risale.
    ragno_mat = piatto("ragno", "#1A1614", 0.7)
    RX, RY, RZ = X0 + 0.35, 4.9, HC - 0.05
    p_ragno = perno("ragno", (RX, RY, RZ))
    corpo_ragno = sfera("ragno_corpo", 0.035, (0, 0, -0.04), ragno_mat, parent=p_ragno, scala=(1, 1, 1.2))
    for k in range(4):
        for s_ in (-1, 1):
            box(f"ragno_zampa{k}{s_}", (0.07, 0.006, 0.006), (s_ * 0.045, 0, -0.03 - k * 0.012), ragno_mat,
                rot=(0, s_ * (30 - k * 20), 0), parent=p_ragno, linee=False)
    filo = cilindro("ragno_filo", 0.002, 1.0, (RX, RY, RZ), piatto("filo", "#C8C8C0", 0.5, luce="#C8C8C0",
                                                                      forza=0.3), seg=4, linee=False)

    def posa_ragno(t):
        # 0 -> fermo in alto (nascosto contro il soffitto); scende fino a 1,1 m,
        # ondeggia, risale.
        if t < 0.4:
            d = (t / 0.4) ** 0.8 * 1.1
        elif t < 0.7:
            d = 1.1 + 0.03 * math.sin((t - 0.4) * 40)
        else:
            d = 1.1 * (1.0 - (t - 0.7) / 0.3)
        p_ragno.location = (RX, RY, RZ - d)
        p_ragno.rotation_euler = Euler((0, 0, math.radians(40 * math.sin(t * 12))))
        filo.scale = (1, 1, max(0.001, d))
        filo.location = (RX, RY, RZ - d)
        p_ragno.hide_render = d < 0.02
        for c in p_ragno.children:
            c.hide_render = d < 0.02
        filo.hide_render = d < 0.02

    # Le foglie: uno spiffero sotto la serranda ne spinge dentro tre, che
    # scivolano sul cemento e si fermano.
    volanti = []
    for k in range(3):
        ob = box(f"foglia_vola{k}", (0.08, 0.055, 0.004), (X1 + 0.3, 2.0 + k * 0.6, 0), foglia_mats[k],
                 linee=False)
        volanti.append(ob)

    def posa_foglie(t):
        for k, ob in enumerate(volanti):
            f = max(0.0, min(1.0, (t - k * 0.08) / 0.7))
            dist = (1.0 - (1.0 - f) ** 2) * (1.6 + 0.5 * k)
            ob.location = (X1 + 0.05 - dist, 1.6 + k * 0.9 + 0.25 * math.sin(f * 4 + k), 0.002 + 0.12 * math.sin(math.pi * f) * (1.0 - f))
            ob.rotation_euler = Euler((0, 0, math.radians(k * 50 + f * 400)))
            ob.hide_render = f <= 0.0

    posa_foglie(0.0)
    posa_ragno(0.0)

    vasi = []
    for cx, cy, bw, bd in banconi:
        for v in (0.30, 0.86):
            for u in (1 / 6, 1 / 2, 5 / 6):
                vasi.append((cx - bw / 2 + u * bw, cy + bd / 2 - v * bd, BH))

    return {
        "animazioni": [
            dondolo("lampadario", p_lampada, 5.0, asse="Y", periodo=2.0, smorza=3.5,
                    pausa=(12.0, 26.0)),
            evento("ragno", posa_ragno, 24, 8, (30.0, 70.0)),
            evento("foglie", posa_foglie, 16, 12, (14.0, 32.0)),
        ],
        "punti": {
            "finestra": [(X0, FY0, FZ0), (X0, FY1, FZ0), (X0, FY0, FZ1), (X0, FY1, FZ1)],
            "personaggio": (2.3, 1.45, 0.0),
            "vasi": vasi,
            "pc": [(BX - 0.42, Y1 - 0.55, 0.9), (BX + 0.42, Y1 - 0.55, 0.9),
                   (BX - 0.42, Y1 - 0.55, 1.26), (BX + 0.42, Y1 - 0.55, 1.32)],
        },
    }


STANZE = {
    "ingresso": ingresso,
    "cucina": cucina,
    "cantina": cantina,
    "garage": garage,
}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    nomi = [a for a in argv if not a.startswith("--")]
    solo_fondale = "--solo-fondale" in argv
    solo = None
    for a in argv:
        if a.startswith("--solo="):
            solo = a.split("=", 1)[1].split(",")
    if not nomi or nomi == ["tutte"]:
        nomi = list(STANZE)
    for n in nomi:
        renderizza(n, solo_fondale, solo)


if __name__ == "__main__":
    main()
