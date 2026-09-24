"""Costruisce in Blender HOLLY LOFTS, il condominio d'angolo di DOWNTOWN.

Preso da una foto di un complesso nuovo all'angolo di due strade (S. Holly
St.): tre pezzi che si leggono come tre edifici diversi pur essendo uno solo.

  * **l'ala scura**, lungo la strada: rivestimento a doghe orizzontali grigio
    antracite, finestre verticali con qualche riquadro chiaro e un pannello di
    legno sotto, il piano terra arretrato e chiaro dietro a una cancellata nera
    col cancellino d'ingresso;
  * **la torretta d'angolo**, piu' alta di un piano: pannelli grigio chiaro,
    grandi bovindi vetrati coi frangisole a lamelle sopra, i balconi con la
    ringhiera nera dove si attacca all'ala scura, e in cima un piano rivestito di
    legno sotto a un tetto a falda unica che sbalza, con le travi a vista;
  * **l'ala bianca**, lungo l'altra strada, con le fasce di legno verticali.

## L'angolo, visto da sud

Il gioco guarda gli edifici di fronte e dall'alto, senza imbardata: di un
edificio si vede la facciata che guarda a sud e il tetto, mai i fianchi. Quindi
di un edificio d'angolo si vede la facciata sulla strada orizzontale (ala scura
e torretta, cioe' la parte della foto che la caratterizza) e l'ala che corre
lungo la strada verticale si legge dal TETTO, che sale dietro alla torretta.
Non e' un limite da aggirare con una camera ruotata: e' la regola che tiene
allineati tutti gli edifici della citta' (vedi `render_buildings.py`).

## Solo l'edificio

Niente semafori, lampioni, alberi, aiuole, cassette dei contatori e marciapiede:
li mette la citta' (vedi la memoria del progetto su cosa va negli sprite). Resta
la cancellata col cancellino, che sta sul lotto dell'edificio ed e' attaccata
alla facciata.

## Le regole del quartiere

  * camera ortografica inclinata 27 gradi sul solo asse X;
  * 22,3 px per metro, render a 4x e riduzione in `import_flats_art.py`;
  * Freestyle 3,2 e 1,5, e i pezzi UNITI in una mesh sola per gruppo, se no
    ogni scatola si porta dietro il suo contorno nero;
  * palette vicina a quella `DT_` del grossista (vetro, guaina, acciaio), cosi'
    DOWNTOWN resta un quartiere solo.

Origine: l'angolo sud-est dell'edificio, cioe' l'angolo di strada. X verso est,
Y verso nord, facciata sulla strada in y = 0.

Uso:
  blender --background --factory-startup --python scripts_tools/blender_holly_lofts.py
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

# --- misure (metri) ---------------------------------------------------------
PT = 4.2            # piano terra
PIANO = 3.1         # piani sopra
TORRE_X0 = -8.6     # la torretta va da qui all'angolo (x = 0)
TORRE_Y1 = 11.0     # quanto e' profonda
SCURA_X0 = -26.0    # l'ala scura comincia qui
SCURA_Y1 = 10.0
BIANCA_Y1 = 23.0    # l'ala bianca corre verso nord fino a qui
ARRETRO = 1.6       # di quanto il piano terra dell'ala scura sta indietro
PARAPETTO = 0.55

H_SCURA = PT + 2 * PIANO            # tre livelli
H_TORRE = PT + 3 * PIANO            # quattro: l'ultimo e' quello di legno


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


def righe(name, chiaro, scuro, passo, asse="Z", rough=0.7, frazione=0.16):
    """Doghe o pannelli: righe scure a passo fisso lungo un asse, prese dalla
    POSIZIONE NEL MONDO e non dall'oggetto, cosi' dopo l'unione delle mesh le
    doghe dei pezzi accostati restano allineate."""
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
    M["doghe"] = righe("HL_Doghe", "#373E44", "#23282D", 0.22)
    M["pannello"] = righe("HL_Pannello", "#BDBEB7", "#A2A39C", 1.55, asse="Z", frazione=0.02)
    M["bianco"] = righe("HL_Bianco", "#E6E4DE", "#CFCDC6", 1.55, asse="Z", frazione=0.02)
    M["pt"] = righe("HL_Piano_Terra", "#CBCAC2", "#B3B2AA", 1.2, asse="X", frazione=0.03)
    M["legno"] = righe("HL_Legno", "#A56B3A", "#8A552C", 0.16, asse="X", frazione=0.12)
    M["legno_v"] = righe("HL_Legno_V", "#A56B3A", "#8A552C", 0.14, asse="Z", frazione=0.12)
    M["infisso"] = piatto("HL_Infisso", "#1E2225", 0.45, 0.5)
    M["cornice"] = piatto("HL_Cornice", "#D8D6CF", 0.7)
    # Poco metallico: col metallico dei grattacieli il vetro sotto allo sbalzo
    # rifletteva tutto il cielo e usciva bianco.
    M["vetro"] = piatto("HL_Vetro", "#2C4048", 0.3, 0.0)
    # Stessa ricetta di `QB_Vetro_Acceso`/`DT_Vetro`: di giorno appena piu'
    # chiaro, e `modo_luci()` lo riconosce dall'emissione e lo accende di notte.
    M["vetro_acceso"] = piatto("HL_Vetro_Acceso", "#3A4A48", 0.10,
                               emissivo="#E2D3AE", forza=1.05)
    M["atrio"] = piatto("HL_Vetro_Atrio", "#33484E", 0.08, 0.20,
                        emissivo="#D8C9A2", forza=0.9)
    M["ferro"] = piatto("HL_Ferro", "#1A1C1E", 0.5, 0.6)
    M["guaina"] = piatto("HL_Guaina", "#6E6A61", 0.93)
    M["copertina"] = piatto("HL_Copertina", "#8E9498", 0.38, 0.78)
    M["intradosso"] = piatto("HL_Intradosso", "#D9D4CB", 0.8)
    # Il tetto si vede dall'alto per intero, grande quanto la torretta: nero
    # come nella foto (dove lo si guarda da sotto) era una lastra scura che si
    # mangiava l'edificio. Lamiera grigia aggraffata, e il nero resta alla gronda.
    M["tetto"] = righe("HL_Tetto", "#6A7176", "#545A5F", 0.5, asse="X", frazione=0.1)
    M["gronda"] = piatto("HL_Gronda", "#24282C", 0.6, 0.3)
    M["macchina"] = piatto("HL_Macchina", "#9EA3A5", 0.5, 0.5)
    M["applique"] = piatto("HL_Applique", "#E8DCBE", 0.3, emissivo="#F0D8A0", forza=1.6)
    M["insegna"] = piatto("HL_Insegna", "#E4E0D6", 0.5)


# ----------------------------------------------------------------------
#  geometria
# ----------------------------------------------------------------------

PEZZI = []
# Le cose sottili — sbarre della cancellata, ringhiere — stanno in una mesh a
# parte, senza contorno: sono gia' nere, e col contorno Freestyle intorno a ogni
# sbarra da tre centimetri la cancellata diventava una lastra nera piena.
SOTTILI = []


def bx(nome, x0, x1, y0, y1, z0, z1, mat, sottile=False):
    """Scatola dai suoi estremi: in un edificio si ragiona per fili e quote."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x = x0 if v.co.x < 0 else x1
        v.co.y = y0 if v.co.y < 0 else y1
        v.co.z = z0 if v.co.z < 0 else z1
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(M[mat] if isinstance(mat, str) else mat)
    ob = bpy.data.objects.new(nome, me)
    bpy.context.scene.collection.objects.link(ob)
    (SOTTILI if sottile else PEZZI).append(ob)
    return ob


def poligono(nome, punti, facce, mat):
    me = bpy.data.meshes.new(nome)
    me.from_pydata(punti, [], facce)
    me.materials.append(M[mat])
    ob = bpy.data.objects.new(nome, me)
    bpy.context.scene.collection.objects.link(ob)
    PEZZI.append(ob)
    return ob


def finestra(nome, x0, x1, z0, z1, y, acceso, profondita=0.12, telaio=0.07,
             montanti=1, traversi=0, cornice=None, vetro=None):
    """Una finestra in facciata (che guarda -Y, a quota `y`): vetro arretrato,
    telaio, montanti. `cornice` aggiunge il riquadro chiaro della foto."""
    # I muri sono scatole piene, senza buchi: il vetro e' una lastrina appena
    # DAVANTI alla facciata e il telaio davanti al vetro. Messo dietro al filo
    # del muro, com'era la prima volta, stava dentro allo spessore e si vedeva
    # l'intonaco: tutte le finestre del piano terra uscivano bianche.
    vetro = vetro or ("vetro_acceso" if acceso else "vetro")
    bx(nome + "_vetro", x0, x1, y - 0.035, y - 0.005, z0, z1, vetro)
    t = telaio
    a0, a1 = y - 0.075, y - 0.005
    for k, (a, b) in enumerate(((x0 - t, x0), (x1, x1 + t))):
        bx(f"{nome}_st{k}", a, b, a0, a1, z0 - t, z1 + t, "infisso")
    bx(nome + "_sotto", x0, x1, a0, a1, z0 - t, z0, "infisso")
    bx(nome + "_sopra", x0, x1, a0, a1, z1, z1 + t, "infisso")
    for i in range(1, montanti):
        xm = x0 + (x1 - x0) * i / montanti
        bx(f"{nome}_m{i}", xm - t / 2, xm + t / 2, a0 + 0.01, a1, z0, z1, "infisso")
    for i in range(1, traversi + 1):
        zm = z0 + (z1 - z0) * i / (traversi + 1)
        bx(f"{nome}_t{i}", x0, x1, a0 + 0.01, a1, zm - t / 2, zm + t / 2, "infisso")
    if cornice:
        c = 0.14
        c0, c1 = y - 0.1, y - 0.005
        bx(nome + "_c0", x0 - t - c, x0 - t, c0, c1, z0 - t - c, z1 + t + c, cornice)
        bx(nome + "_c1", x1 + t, x1 + t + c, c0, c1, z0 - t - c, z1 + t + c, cornice)
        bx(nome + "_c2", x0 - t, x1 + t, c0, c1, z1 + t, z1 + t + c, cornice)
        bx(nome + "_c3", x0 - t, x1 + t, c0, c1, z0 - t - c, z0 - t, cornice)


def ringhiera(nome, x0, x1, y, z0, h=1.05, passo=0.24):
    """Passo 24 cm e non i 12 veri: a 22 px/m le sbarre vere cadrebbero a meno
    di tre pixel l'una dall'altra, e ridotte diventerebbero una lastra grigia.
    Una ogni cinque pixel si legge ancora come ringhiera."""
    bx(nome + "_corrimano", x0, x1, y - 0.03, y + 0.03, z0 + h - 0.06, z0 + h, "ferro", True)
    bx(nome + "_basso", x0, x1, y - 0.02, y + 0.02, z0 + 0.1, z0 + 0.15, "ferro", True)
    n = max(2, int((x1 - x0) / passo))
    for i in range(n + 1):
        x = x0 + (x1 - x0) * i / n
        bx(f"{nome}_b{i}", x - 0.018, x + 0.018, y - 0.018, y + 0.018, z0, z0 + h, "ferro", True)


def ringhiera_y(nome, x, y0, y1, z0, h=1.05, passo=0.24):
    bx(nome + "_corrimano", x - 0.03, x + 0.03, y0, y1, z0 + h - 0.06, z0 + h, "ferro", True)
    n = max(2, int((y1 - y0) / passo))
    for i in range(n + 1):
        y = y0 + (y1 - y0) * i / n
        bx(f"{nome}_b{i}", x - 0.018, x + 0.018, y - 0.018, y + 0.018, z0, z0 + h, "ferro", True)


def testo(nome, stringa, x, y, z, altezza, mat):
    cu = bpy.data.curves.new(nome, "FONT")
    cu.body = stringa
    cu.size = altezza
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    cu.extrude = 0.02
    ob = bpy.data.objects.new(nome, cu)
    coll = bpy.data.collections.get(COLL_TESTI) or bpy.data.collections.new(COLL_TESTI)
    if coll.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(coll)
    coll.objects.link(ob)
    ob.data.materials.append(M[mat])
    ob.location = (x, y, z)
    ob.rotation_euler = (math.radians(90), 0, 0)
    return ob


def unisci(nome):
    """Una mesh sola per tutto l'edificio: niente contorni neri fra una scatola
    e quella accanto, restano solo gli spigoli veri (vedi il docstring)."""
    if not PEZZI:
        return None
    base = PEZZI[0]
    with bpy.context.temp_override(active_object=base, selected_editable_objects=PEZZI,
                                   selected_objects=PEZZI):
        bpy.ops.object.join()
    base.name = nome
    PEZZI.clear()
    return base


# ----------------------------------------------------------------------
#  l'edificio
# ----------------------------------------------------------------------

def ala_scura(rnd):
    x0, x1 = SCURA_X0, TORRE_X0
    # Piano terra arretrato, chiaro, con le porte delle unita' e le vetrate.
    bx("scura_pt", x0, x1, ARRETRO, SCURA_Y1, 0.0, PT, "pt")
    # Solaio del primo piano che sbalza sopra al piano terra: e' l'ombra lunga
    # che fa leggere l'arretramento.
    bx("scura_solaio", x0, x1, 0.0, ARRETRO, PT - 0.35, PT, "doghe")
    bx("scura_corpo", x0, x1, 0.0, SCURA_Y1, PT, H_SCURA, "doghe")
    bx("scura_parapetto", x0, x1, 0.0, SCURA_Y1, H_SCURA, H_SCURA + PARAPETTO, "doghe")
    bx("scura_copertina", x0 - 0.05, x1, -0.05, SCURA_Y1 + 0.05, H_SCURA + PARAPETTO,
       H_SCURA + PARAPETTO + 0.08, "copertina")
    bx("scura_tetto", x0 + 0.25, x1, 0.25, SCURA_Y1 - 0.25, H_SCURA, H_SCURA + 0.12, "guaina")
    # Le unita' del piano terra: porta-finestra e finestra, dietro alla cancellata.
    campate = 5
    passo = (x1 - x0) / campate
    for i in range(campate):
        cx = x0 + passo * (i + 0.5)
        finestra(f"pt_porta{i}", cx - 1.35, cx - 0.35, 0.05, 2.4, ARRETRO,
                 rnd.random() < 0.2, montanti=1)
        finestra(f"pt_fin{i}", cx + 0.25, cx + 1.45, 0.9, 2.4, ARRETRO,
                 rnd.random() < 0.2, montanti=2)
    # I due piani di sopra: per campata una finestra alta e una col riquadro
    # chiaro e il pannello di legno sotto (le prese d'aria della foto).
    for piano in range(2):
        z = PT + piano * PIANO
        for i in range(campate):
            if i == campate - 1:
                continue    # l'ultima campata ha i balconi, vedi `torretta()`
            cx = x0 + passo * (i + 0.5)
            finestra(f"p{piano}_alta{i}", cx - 1.2, cx - 0.55, z + 0.35, z + 2.55, 0.0,
                     rnd.random() < 0.22)
            finestra(f"p{piano}_quad{i}", cx + 0.2, cx + 1.25, z + 1.2, z + 2.45, 0.0,
                     rnd.random() < 0.22, montanti=1, cornice="cornice")
            bx(f"p{piano}_legno{i}", cx + 0.2, cx + 1.25, -0.08, 0.0, z + 0.3, z + 0.98,
               "legno")
            if rnd.random() < 0.5:
                # Il condizionatore a finestra: una scatoletta, come nella foto.
                bx(f"p{piano}_clima{i}", cx + 0.45, cx + 1.0, -0.35, 0.0, z + 1.2,
                   z + 1.55, "macchina")
    # Pluviale all'estremita' ovest.
    bx("scura_pluviale", x0 + 0.1, x0 + 0.22, -0.14, -0.02, 0.0, H_SCURA + PARAPETTO, "infisso")
    # Le macchine sul tetto.
    for k, (a, b) in enumerate(((-23.5, -21.8), (-17.0, -15.6))):
        bx(f"tetto_macchina{k}", a, b, 3.0, 4.6, H_SCURA + 0.12, H_SCURA + 1.0, "macchina")
        bx(f"tetto_griglia{k}", a + 0.2, b - 0.2, 3.2, 4.4, H_SCURA + 1.0, H_SCURA + 1.06, "infisso")


def cancellata():
    """La cancellata nera davanti al piano terra arretrato, col cancellino.

    Sta sul filo della facciata (y ~ 0): e' il limite del lotto, non arredo di
    strada. Il cancellino e' a meta', dove si entra al cortiletto delle unita'.
    """
    x0, x1 = SCURA_X0 + 0.2, TORRE_X0 - 0.2
    g0, g1 = -17.9, -16.6          # il cancellino
    y = 0.12
    h = 1.55
    for tratto, (a, b) in enumerate(((x0, g0 - 0.12), (g1 + 0.12, x1))):
        bx(f"canc_corrimano{tratto}", a, b, y - 0.03, y + 0.03, h - 0.07, h, "ferro", True)
        bx(f"canc_basso{tratto}", a, b, y - 0.03, y + 0.03, 0.08, 0.15, "ferro", True)
        n = int((b - a) / 0.25)
        for i in range(n + 1):
            x = a + (b - a) * i / n
            bx(f"canc_{tratto}_{i}", x - 0.02, x + 0.02, y - 0.02, y + 0.02, 0.0, h, "ferro", True)
        passo_pali = 2.3
        m = max(1, int((b - a) / passo_pali))
        for i in range(m + 1):
            x = a + (b - a) * i / m
            bx(f"canc_palo{tratto}_{i}", x - 0.05, x + 0.05, y - 0.05, y + 0.05, 0.0, h + 0.1, "ferro", True)
    # Il cancellino: telaio, sbarre, i due pilastrini, la maniglia e la
    # lampada sopra al pilastro.
    for k, x in enumerate((g0 - 0.12, g1 + 0.12)):
        bx(f"cancello_pilastro{k}", x - 0.12, x + 0.12, y - 0.12, y + 0.12, 0.0, 1.85, "pannello")
        bx(f"cancello_cappello{k}", x - 0.15, x + 0.15, y - 0.15, y + 0.15, 1.85, 1.92, "copertina")
    bx("cancello_telaio_su", g0, g1, y - 0.03, y + 0.03, 1.6, 1.7, "ferro", True)
    bx("cancello_telaio_giu", g0, g1, y - 0.03, y + 0.03, 0.06, 0.16, "ferro", True)
    bx("cancello_telaio_mezzo", g0, g1, y - 0.03, y + 0.03, 0.85, 0.92, "ferro", True)
    for k, x in enumerate((g0, g1)):
        bx(f"cancello_montante{k}", x - 0.04, x + 0.04, y - 0.03, y + 0.03, 0.06, 1.7, "ferro", True)
    for i in range(5):
        x = g0 + (g1 - g0) * (i + 0.5) / 5
        bx(f"cancello_sbarra{i}", x - 0.02, x + 0.02, y - 0.02, y + 0.02, 0.06, 1.7, "ferro", True)
    bx("cancello_maniglia", g1 - 0.18, g1 - 0.06, y - 0.08, y - 0.03, 0.95, 1.1, "copertina")
    bx("cancello_citofono", g1 + 0.05, g1 + 0.19, y - 0.14, y - 0.12, 1.1, 1.4, "copertina")
    for k, x in enumerate((g0 - 0.12, g1 + 0.12)):
        bx(f"cancello_lampada{k}", x - 0.08, x + 0.08, y - 0.08, y + 0.08, 1.92, 2.1, "applique")


def torretta(rnd):
    x0, x1 = TORRE_X0, 0.0
    # Il corpo: piano terra vetrato (l'atrio), due piani di pannelli grigi,
    # l'ultimo piano rivestito di legno.
    bx("torre_pt", x0, x1, 0.25, TORRE_Y1, 0.0, PT, "pannello")
    bx("torre_corpo", x0, x1, 0.0, TORRE_Y1, PT, PT + 2 * PIANO, "pannello")
    bx("torre_legno", x0 + 0.3, x1, 0.3, TORRE_Y1, PT + 2 * PIANO, H_TORRE, "legno")
    # Atrio: la vetrata lunga e la porta, con la fascia dell'insegna sopra.
    # Il vetro dell'atrio e' sempre acceso: e' la luce del portone.
    finestra("atrio", x0 + 0.8, x1 - 0.8, 0.05, PT - 0.8, 0.25, False, montanti=5,
             profondita=0.2, vetro="atrio")
    bx("atrio_porta", x0 + 4.9, x0 + 6.1, 0.1, 0.25, 0.0, 2.5, "infisso")
    bx("atrio_porta_vetro", x0 + 5.0, x0 + 6.0, 0.05, 0.12, 0.1, 2.4, "atrio")
    bx("atrio_fascia", x0 + 0.5, x1 - 0.5, 0.0, 0.25, PT - 0.75, PT - 0.3, "infisso")
    testo("insegna", "HOLLY LOFTS", (x0 + x1) / 2, -0.02, PT - 0.53, 0.34, "insegna")
    bx("atrio_pensilina", x0 + 4.4, x0 + 6.6, -1.1, 0.25, 2.75, 2.88, "infisso")
    # I due bovindi, uno per piano: sporgono, vetrata a griglia, e sopra il
    # frangisole a lamelle.
    for piano in range(2):
        z = PT + piano * PIANO
        bx0, bx1 = x0 + 3.2, x1 - 0.5
        bx(f"bov{piano}_fondo", bx0, bx1, -0.6, 0.0, z + 0.1, z + 0.35, "pannello")
        bx(f"bov{piano}_cielo", bx0, bx1, -0.6, 0.0, z + 2.7, z + PIANO - 0.05, "pannello")
        finestra(f"bov{piano}", bx0 + 0.1, bx1 - 0.1, z + 0.35, z + 2.7, -0.6,
                 rnd.random() < 0.4, montanti=4, traversi=1)
        bx(f"bov{piano}_fianco0", bx0, bx0 + 0.1, -0.6, 0.0, z + 0.1, z + PIANO - 0.05, "infisso")
        bx(f"bov{piano}_fianco1", bx1 - 0.1, bx1, -0.6, 0.0, z + 0.1, z + PIANO - 0.05, "infisso")
        # Il frangisole: telaio che sbalza e lamelle trasversali.
        fz = z + PIANO - 0.08
        bx(f"frang{piano}_0", bx0 - 0.2, bx0 - 0.1, -1.5, 0.0, fz, fz + 0.1, "ferro")
        bx(f"frang{piano}_1", bx1 + 0.1, bx1 + 0.2, -1.5, 0.0, fz, fz + 0.1, "ferro")
        bx(f"frang{piano}_2", bx0 - 0.2, bx1 + 0.2, -1.55, -1.45, fz, fz + 0.1, "ferro")
        for i in range(10):
            yy = -1.45 + 1.45 * i / 10
            bx(f"frang{piano}_l{i}", bx0 - 0.1, bx1 + 0.1, yy, yy + 0.05, fz + 0.02, fz + 0.08, "ferro")
    # I balconi, dove la torretta si attacca all'ala scura: sporgono, hanno la
    # ringhiera nera e una porta-finestra dietro.
    for piano in range(2):
        z = PT + piano * PIANO
        a, b = TORRE_X0 - 3.2, TORRE_X0 + 2.9
        bx(f"balc{piano}_soletta", a, b, -1.45, 0.0, z - 0.05, z + 0.18, "pannello")
        ringhiera(f"balc{piano}_r", a + 0.05, b - 0.05, -1.4, z + 0.18)
        ringhiera_y(f"balc{piano}_rs", a + 0.03, -1.4, 0.0, z + 0.18)
        ringhiera_y(f"balc{piano}_rd", b - 0.03, -1.4, 0.0, z + 0.18)
        finestra(f"balc{piano}_porta", a + 0.4, a + 2.6, z + 0.2, z + 2.55, 0.0,
                 rnd.random() < 0.5, montanti=2)
        finestra(f"balc{piano}_fin", a + 3.6, b - 0.3, z + 0.9, z + 2.55, 0.0,
                 rnd.random() < 0.5, montanti=2)
    # L'ultimo piano, di legno: una fascia di finestre sottili.
    z = PT + 2 * PIANO
    for k, (a, b) in enumerate(((x0 + 1.2, x0 + 2.4), (x0 + 5.2, x0 + 7.4))):
        finestra(f"legno_fin{k}", a, b, z + 0.9, z + 2.4, 0.3, rnd.random() < 0.5, montanti=1)
    # Il tetto a falda unica: sale verso la strada e sbalza di un metro e
    # mezzo davanti e di uno sui fianchi. Le travi sporgono sotto alla gronda.
    zb, zf = H_TORRE + 0.35, H_TORRE + 1.25     # quota dietro e davanti
    ya, yb = TORRE_Y1 + 0.8, -1.6
    xa, xb = x0 - 1.0, x1 + 0.6
    s = 0.28
    punti = [(xa, ya, zb), (xb, ya, zb), (xb, yb, zf), (xa, yb, zf),
             (xa, ya, zb + s), (xb, ya, zb + s), (xb, yb, zf + s), (xa, yb, zf + s)]
    facce = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    poligono("tetto_falda", punti, facce, "tetto")
    # L'intradosso chiaro, appena sotto: si vede solo sul filo di gronda, ed e'
    # la riga chiara che nella foto separa il tetto scuro dal legno.
    punti_i = [(xa + 0.05, ya, zb - 0.06), (xb - 0.05, ya, zb - 0.06),
               (xb - 0.05, yb + 0.05, zf - 0.06), (xa + 0.05, yb + 0.05, zf - 0.06),
               (xa + 0.05, ya, zb), (xb - 0.05, ya, zb), (xb - 0.05, yb + 0.05, zf),
               (xa + 0.05, yb + 0.05, zf)]
    poligono("tetto_intradosso", punti_i, facce, "intradosso")
    # Le travi: da dentro al muro fino alla gronda, sotto all'intradosso.
    for i in range(7):
        x = x0 + 0.5 + (x1 - x0 - 1.0) * i / 6
        for_z = zf - 0.06
        bx(f"trave{i}", x - 0.11, x + 0.11, yb + 0.25, 0.3, for_z - 0.32, for_z, "gronda")
    # La fascia scura sul filo di gronda.
    bx("gronda_fronte", xa, xb, yb - 0.08, yb, zf - 0.05, zf + s + 0.05, "gronda")
    # Pluviale sull'angolo.
    bx("torre_pluviale", x1 - 0.2, x1 - 0.06, -0.14, 0.0, 0.0, H_TORRE, "infisso")


def ala_bianca(rnd):
    """Corre verso nord lungo la strada verticale, dietro alla torretta. Da sud
    se ne vede il tetto e il bordo alto; le facciate le ha sui fianchi."""
    x0, x1 = TORRE_X0, 0.0
    y0, y1 = TORRE_Y1, BIANCA_Y1
    bx("bianca_corpo", x0, x1, y0, y1, 0.0, H_SCURA, "bianco")
    bx("bianca_parapetto", x0, x1, y0, y1, H_SCURA, H_SCURA + PARAPETTO, "bianco")
    bx("bianca_copertina", x0 - 0.05, x1 + 0.05, y0, y1 + 0.05, H_SCURA + PARAPETTO,
       H_SCURA + PARAPETTO + 0.08, "copertina")
    bx("bianca_tetto", x0 + 0.25, x1 - 0.25, y0, y1 - 0.25, H_SCURA, H_SCURA + 0.12, "guaina")
    # Le fasce di legno verticali, che spuntano sul parapetto come nella foto.
    for k, y in enumerate((14.0, 18.5)):
        bx(f"bianca_legno{k}", x1 - 0.02, x1 + 0.06, y, y + 1.1, 0.0, H_SCURA + PARAPETTO, "legno_v")
    bx("bianca_macchina", -6.5, -4.8, 17.0, 18.6, H_SCURA + 0.12, H_SCURA + 0.95, "macchina")
    # La facciata nord, l'unica che guarda verso chi guarda da... nessuno: ma
    # chiude la scatola, e un lucernario sul tetto le da' un po' di vita.
    bx("bianca_lucernario", -3.5, -1.5, 20.0, 21.5, H_SCURA + 0.12, H_SCURA + 0.5, "vetro")


def costruisci():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for c in list(bpy.data.collections):
        bpy.data.collections.remove(c)
    PEZZI.clear()
    palette()
    rnd = random.Random(12)
    ala_scura(rnd)
    cancellata()
    torretta(rnd)
    ala_bianca(rnd)
    unisci("HollyLofts")
    if SOTTILI:
        PEZZI.extend(SOTTILI)
        SOTTILI.clear()
        sottili = unisci("HollyLofts_Ferri")
        coll = bpy.data.collections.get(COLL_TESTI) or bpy.data.collections.new(COLL_TESTI)
        if coll.name not in bpy.context.scene.collection.children:
            bpy.context.scene.collection.children.link(coll)
        bpy.context.scene.collection.objects.unlink(sottili)
        coll.objects.link(sottili)
    return scena()


# ----------------------------------------------------------------------
#  scena, inquadratura, scatti
# ----------------------------------------------------------------------

def scena():
    sc = bpy.context.scene
    dati = bpy.data.cameras.new("CAM_Front")
    dati.type = "ORTHO"
    dati.clip_start, dati.clip_end = 0.1, 800.0
    cam = bpy.data.objects.new("CAM_Front", dati)
    sc.collection.objects.link(cam)
    cam.rotation_euler = (math.radians(90.0 - INCLINAZIONE), 0.0, 0.0)
    sc.camera = cam

    sole = bpy.data.lights.new("SUN", type="SUN")
    sole.energy = 3.2
    sole.color = (1.0, 0.96, 0.90)
    sole.angle = math.radians(1.0)
    ob = bpy.data.objects.new("SUN", sole)
    sc.collection.objects.link(ob)
    ob.rotation_euler = (math.radians(52), 0.0, math.radians(-18))
    riemp = bpy.data.lights.new("FILL", type="SUN")
    riemp.energy = 1.15
    riemp.color = (0.72, 0.80, 0.95)
    riemp.angle = math.radians(35)
    ob = bpy.data.objects.new("FILL", riemp)
    sc.collection.objects.link(ob)
    ob.rotation_euler = (math.radians(104), 0.0, math.radians(26))

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
                      ("use_shadows", True), ("shadow_ray_count", 2),
                      ("shadow_step_count", 6)]:
        if hasattr(sc.eevee, attr):
            try:
                setattr(sc.eevee, attr, val)
            except (AttributeError, TypeError):
                pass
    sc.view_settings.view_transform = "Standard"

    sc.render.use_freestyle = True
    sc.render.line_thickness_mode = "ABSOLUTE"
    sc.render.line_thickness = 1.0
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
    # 2,4 e non 3,2 come le torri: qui c'e' molto piu' dettaglio per metro, e
    # con le linee delle torri ogni finestra aveva una cornice nera doppia.
    fuori.linestyle.thickness = 2.4
    dentro = fs.linesets.new("Spigoli")
    for a in ("select_silhouette", "select_border", "select_ridge_valley",
              "select_suggestive_contour", "select_material_boundary",
              "select_edge_mark"):
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
    return inquadra(cam)


def inquadra(cam, margine=0.30):
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    punti = []
    for obj in bpy.data.objects:
        if obj.type not in ("MESH", "FONT"):
            continue
        val = obj.evaluated_get(dg)
        mesh = val.to_mesh()
        for v in mesh.vertices:
            punti.append(obj.matrix_world @ v.co)
        val.to_mesh_clear()
    inv = cam.matrix_world.inverted()
    vista = [inv @ p for p in punti]
    minx, maxx = min(p.x for p in vista), max(p.x for p in vista)
    miny, maxy = min(p.y for p in vista), max(p.y for p in vista)
    larg = (maxx - minx) + 2 * margine
    alt = (maxy - miny) + 2 * margine
    cam.location = cam.matrix_world @ Vector(((minx + maxx) / 2.0, (miny + maxy) / 2.0, 400.0))
    cam.data.ortho_scale = max(larg, alt)
    sc = bpy.context.scene
    sc.render.resolution_x = int(round(larg * PX_PER_METRO))
    sc.render.resolution_y = int(round(alt * PX_PER_METRO))
    # Dove cade l'angolo di strada (x = 0) rispetto al bordo sinistro del
    # disegno, e dove cade il filo ovest dell'ala scura: servono a piazzarlo in
    # citta' senza misurare il PNG.
    return {"min_x": minx, "max_x": maxx, "larghezza_m": maxx - minx,
            "altezza_m": maxy - miny}


def modo_luci():
    """Come `render_buildings.py::modo_luci()`: resta acceso solo quello che il
    modello dichiara emissivo, su fondo nero."""
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
        if bsdf is not None and "Emission Strength" in bsdf.inputs:
            if float(bsdf.inputs["Emission Strength"].default_value) > 0.001:
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
            em.inputs["Strength"].default_value = 1.0
            L.new(em.outputs[0], uscita.inputs["Surface"])


def renderizza():
    os.makedirs(OUT, exist_ok=True)
    misure = costruisci()
    sc = bpy.context.scene
    sc.render.resolution_percentage = SUPERSAMPLING * 100
    sc.render.filepath = os.path.join(OUT, "render_holly.png")
    bpy.ops.render.render(write_still=True)
    modo_luci()
    sc.render.filepath = os.path.join(OUT, "luci_holly.png")
    bpy.ops.render.render(write_still=True)
    print("HOLLY", misure)
    return misure


if __name__ == "__main__":
    renderizza()
