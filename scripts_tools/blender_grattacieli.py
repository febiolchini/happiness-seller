"""Costruisce in Blender i due grattacieli di DOWNTOWN.

**MERIDIAN TOWER** — il prisma sfaccettato: base quadrata che salendo si torce
in un quadrato ruotato di 45 gradi, otto triangoli di vetro lunghi quanto tutta
la torre, parapetto e antenna. E' la forma del One World Trade Center, ed e'
quella giusta per questo gioco: le facce guardano in direzioni diverse, quindi
prendono il sole in momenti diversi della giornata.

**HARBOR HEIGHTS** — la torre residenziale sottile: solette dei balconi a vista
una per piano, corpo stretto e alto, coronamento inclinato e un basamento
commerciale piu' largo. Le righe orizzontali sono geometria vera, non una
texture: a 22,3 px/m un piano e' alto settanta pixel, e quelle righe sono la
cosa che si legge da lontano.

## Il vetro che riflette il sole che si muove

Un grattacielo di vetro non e' un muro: cambia colore nell'arco della giornata,
perche' a riflettere non e' il cemento ma il cielo e il sole che ci scorre
davanti. Se resta uguale dall'alba al tramonto si legge come un pannello
dipinto.

Quel riflesso **non e' cotto dentro allo sprite**: sarebbe una striscia di
dodici fotogrammi alta duemila pixel, decine di megabyte di texture per due
edifici. Esce invece dal materiale, in gioco, con uno shader
(`shaders/glass_sheen.gdshader`) pilotato dall'ora — e quello che gli serve e'
una MASCHERA: un terzo scatto, oltre al disegno e alle luci, in cui ogni faccia
di vetro e' tinta secondo dove guarda:

    rosso  = guarda a est (destra)     il sole ce l'ha addosso la mattina
    verde  = guarda la strada (sud)    a mezzogiorno
    blu    = guarda a ovest (sinistra) la sera

Le facce oblique portano il colore mescolato, perche' prendono luce in due
momenti. In gioco lo shader pesa i tre canali con la posizione del sole — la
STESSA `cos((ora - alba) / (tramonto - alba) * PI)` con cui `Daylight.shadow()`
gira le ombre della citta' — e il riflesso e le ombre raccontano la stessa ora.

## Le regole del quartiere, uguali per tutti

  * camera ortografica inclinata 27 gradi sul solo asse X;
  * 22,3 px per metro: qui un piano intero e' alto settanta pixel, quindi il
    dettaglio si vede tutto e non c'e' niente sotto la soglia dei sei pixel;
  * Freestyle sottile (3,2 e 1,5) e mesh UNITA: cento scatole sciolte sono
    cento contorni neri;
  * le righe dei piani vengono dalla POSIZIONE NEL MONDO e non dalle
    coordinate oggetto, cosi' restano allineate dopo l'unione delle mesh.

Uso da MCP: `costruisci("meridian")` lascia la scena pronta, `renderizza()`
sputa i tre scatti di ognuna in `assets/sprites/buildings/_source/`.
"""

import math
import os

import bpy
from mathutils import Vector

# ----------------------------------------------------------------------
#  misure
# ----------------------------------------------------------------------

INCLINAZIONE = 27.0
PX_PER_METRO = 22.3
SUPERSAMPLING = 4

FONT = "C:/Windows/Fonts/arialbd.ttf"
COLL_TESTI = "SenzaContorno"

# Le facce di vetro dichiarano dove guardano, e il colore con cui escono nella
# maschera. Non e' una decorazione: e' l'unico dato che lo shader legge.
EST = (1.0, 0.0, 0.0)
SUD = (0.0, 1.0, 0.0)
OVEST = (0.0, 0.0, 1.0)
SUD_EST = (0.55, 0.45, 0.0)
SUD_OVEST = (0.0, 0.45, 0.55)

# nome materiale -> colore nella maschera
MASCHERA = {}


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


def piatto(name, hexcol, rough=0.90, metal=0.0, emissivo=None, forza=0.0):
    mat = _fresh(name)
    b = _bsdf(mat)
    _set(b, "Base Color", srgb(hexcol))
    _set(b, "Roughness", rough)
    _set(b, "Metallic", metal)
    if emissivo:
        _set(b, "Emission Color", srgb(emissivo))
        _set(b, "Emission Strength", forza)
    return mat


def _posizione(N, L):
    """Posizione in coordinate MONDO, separata nei tre assi.

    Mondo e non oggetto: le righe dei piani devono restare alla stessa quota
    dopo che le mesh sono state unite e l'origine spostata, e le due torri
    devono avere i piani allineati fra loro.
    """
    geo = N.new("ShaderNodeNewGeometry")
    geo.location = (-1600, 0)
    sep = N.new("ShaderNodeSeparateXYZ")
    sep.location = (-1420, 0)
    L.new(geo.outputs["Position"], sep.inputs["Vector"])
    return sep


def _celle(N, L, sep, passo, colonne, centro):
    """Il numero di riga e di colonna della finestra, come vettore intero.

    La colonna viene dall'ANGOLO intorno all'asse della torre e non da x: su un
    prisma sfaccettato le facce guardano in direzioni diverse, e una coordinata
    presa dal solo x si spalmerebbe su quelle di fianco. L'angolo gira intorno
    alla torre e conta le campate allo stesso passo su tutte le facce.
    """
    dx = N.new("ShaderNodeMath")
    dx.operation = "SUBTRACT"
    dx.location = (-1240, 160)
    dx.inputs[1].default_value = centro[0]
    L.new(sep.outputs["X"], dx.inputs[0])

    dy = N.new("ShaderNodeMath")
    dy.operation = "SUBTRACT"
    dy.location = (-1240, 40)
    dy.inputs[1].default_value = centro[1]
    L.new(sep.outputs["Y"], dy.inputs[0])

    ang = N.new("ShaderNodeMath")
    ang.operation = "ARCTAN2"
    ang.location = (-1060, 100)
    L.new(dy.outputs[0], ang.inputs[0])
    L.new(dx.outputs[0], ang.inputs[1])

    col = N.new("ShaderNodeMath")
    col.operation = "MULTIPLY"
    col.location = (-880, 100)
    col.inputs[1].default_value = colonne / (2.0 * math.pi)
    L.new(ang.outputs[0], col.inputs[0])

    colf = N.new("ShaderNodeMath")
    colf.operation = "FLOOR"
    colf.location = (-700, 100)
    L.new(col.outputs[0], colf.inputs[0])

    riga = N.new("ShaderNodeMath")
    riga.operation = "DIVIDE"
    riga.location = (-880, -60)
    riga.inputs[1].default_value = passo
    L.new(sep.outputs["Z"], riga.inputs[0])

    rigaf = N.new("ShaderNodeMath")
    rigaf.operation = "FLOOR"
    rigaf.location = (-700, -60)
    L.new(riga.outputs[0], rigaf.inputs[0])

    comb = N.new("ShaderNodeCombineXYZ")
    comb.location = (-520, 20)
    L.new(colf.outputs[0], comb.inputs["X"])
    L.new(rigaf.outputs[0], comb.inputs["Y"])
    # La colonna CONTINUA serve ai montanti verticali, che non vogliono il
    # numero della campata ma la posizione dentro a quella campata.
    return comb, col.outputs[0]


def vetro(name, basso, alto, riga_scura, passo, colonne, centro, maschera,
          accese=0.34, seme=0.0, rough=0.10, metal=0.55):
    """La facciata di vetro: sfumatura, righe dei piani e finestre accese.

    Tre cose in un materiale solo:

      * una SFUMATURA verticale, scura in basso e chiara in alto. Un vetro
        riflette il cielo, e il cielo in basso e' coperto dagli edifici di
        fronte: senza la sfumatura una torre alta cento metri e' un rettangolo
        di un colore solo, che e' esattamente il "sembra cemento" da evitare;
      * le RIGHE DEI PIANI, una ogni `passo` metri, prese dalla posizione nel
        mondo;
      * le FINESTRE ACCESE, sorteggiate per cella (riga, colonna) con un
        rumore bianco. Stanno nell'emissione a forza quasi zero, quindi di
        giorno non si vedono: e' `modo_luci()` che le tira su per il secondo
        scatto. Cosi' le finestre accese di notte sono esattamente le stesse
        celle in ogni scatto, senza una seconda lista da tenere allineata.
    """
    mat = _fresh(name)
    N, L = mat.node_tree.nodes, mat.node_tree.links
    b = _bsdf(mat)
    _set(b, "Roughness", rough)
    _set(b, "Metallic", metal)
    sep = _posizione(N, L)

    # --- sfumatura verticale
    quota = N.new("ShaderNodeMapRange")
    quota.location = (-880, 320)
    quota.inputs["From Min"].default_value = 0.0
    quota.inputs["From Max"].default_value = 100.0
    L.new(sep.outputs["Z"], quota.inputs["Value"])

    sfuma = N.new("ShaderNodeValToRGB")
    sfuma.location = (-700, 320)
    sfuma.color_ramp.elements[0].position = 0.02
    sfuma.color_ramp.elements[0].color = srgb(basso)
    sfuma.color_ramp.elements[1].position = 0.85
    sfuma.color_ramp.elements[1].color = srgb(alto)
    L.new(quota.outputs["Result"], sfuma.inputs["Fac"])

    # --- righe dei piani
    div = N.new("ShaderNodeMath")
    div.operation = "DIVIDE"
    div.location = (-880, 480)
    div.inputs[1].default_value = passo
    L.new(sep.outputs["Z"], div.inputs[0])
    fra = N.new("ShaderNodeMath")
    fra.operation = "FRACT"
    fra.location = (-700, 480)
    L.new(div.outputs[0], fra.inputs[0])
    rr = N.new("ShaderNodeValToRGB")
    rr.location = (-520, 480)
    rr.color_ramp.interpolation = "CONSTANT"
    rr.color_ramp.elements[0].position = 0.0
    rr.color_ramp.elements[0].color = (1.0, 1.0, 1.0, 1.0)
    # 0,13 e non 0,20: la fascia della soletta e' alta mezzo metro su tre e
    # otto, undici pixel su settanta. A un quinto del piano la torre si legge
    # come una pila di scatole invece che come una facciata di vetro.
    rr.color_ramp.elements[1].position = 0.13
    rr.color_ramp.elements[1].color = (0.0, 0.0, 0.0, 1.0)
    L.new(fra.outputs[0], rr.inputs["Fac"])

    mix = N.new("ShaderNodeMixRGB")
    mix.location = (-300, 380)
    mix.inputs["Color2"].default_value = srgb(riga_scura)
    L.new(sfuma.outputs["Color"], mix.inputs["Color1"])
    L.new(rr.outputs["Color"], mix.inputs["Fac"])

    # --- finestre accese, per cella
    celle, colonna = _celle(N, L, sep, passo, colonne, centro)

    # --- montanti verticali, dalla stessa colonna delle finestre
    #
    # Senza, una facciata di vetro e' una pila di fasce orizzontali e basta, e
    # da lontano si legge come una scala. I montanti li da' la coordinata
    # ANGOLARE, la stessa che conta le campate: cosi' hanno lo stesso passo su
    # tutte le facce, anche su quelle oblique dove una coordinata presa da x si
    # spalmerebbe.
    mont_f = N.new("ShaderNodeMath")
    mont_f.operation = "FRACT"
    mont_f.location = (-340, 240)
    L.new(colonna, mont_f.inputs[0])
    mont_r = N.new("ShaderNodeValToRGB")
    mont_r.location = (-160, 240)
    mont_r.color_ramp.interpolation = "CONSTANT"
    mont_r.color_ramp.elements[0].position = 0.0
    mont_r.color_ramp.elements[0].color = (1.0, 1.0, 1.0, 1.0)
    mont_r.color_ramp.elements[1].position = 0.12
    mont_r.color_ramp.elements[1].color = (0.0, 0.0, 0.0, 1.0)
    L.new(mont_f.outputs[0], mont_r.inputs["Fac"])
    mont_mix = N.new("ShaderNodeMixRGB")
    mont_mix.location = (20, 380)
    mont_mix.inputs["Fac"].default_value = 0.55
    mont_mix.inputs["Color2"].default_value = srgb(riga_scura)
    L.new(mix.outputs["Color"], mont_mix.inputs["Color1"])
    L.new(mont_r.outputs["Color"], mont_mix.inputs["Fac"])
    L.new(mont_mix.outputs["Color"], b.inputs["Base Color"])
    off = N.new("ShaderNodeVectorMath")
    off.operation = "ADD"
    off.location = (-340, 20)
    off.inputs[1].default_value = (seme, seme * 2.0, 0.0)
    L.new(celle.outputs["Vector"], off.inputs[0])

    rumore = N.new("ShaderNodeTexWhiteNoise")
    rumore.noise_dimensions = "3D"
    rumore.location = (-160, 20)
    L.new(off.outputs["Vector"], rumore.inputs["Vector"])

    soglia = N.new("ShaderNodeValToRGB")
    soglia.location = (20, 20)
    soglia.color_ramp.interpolation = "CONSTANT"
    soglia.color_ramp.elements[0].position = 0.0
    soglia.color_ramp.elements[0].color = (0.0, 0.0, 0.0, 1.0)
    soglia.color_ramp.elements[1].position = 1.0 - accese
    soglia.color_ramp.elements[1].color = (1.0, 1.0, 1.0, 1.0)
    L.new(rumore.outputs["Value"], soglia.inputs["Fac"])

    # Le finestre accese non toccano la riga della soletta: una soletta accesa
    # e' una riga gialla continua, e la torre di notte diventa una scala.
    solo = N.new("ShaderNodeMixRGB")
    solo.blend_type = "MULTIPLY"
    solo.location = (200, 20)
    solo.inputs["Fac"].default_value = 1.0
    L.new(soglia.outputs["Color"], solo.inputs["Color1"])
    L.new(rr.outputs["Color"], solo.inputs["Color2"])

    caldo = N.new("ShaderNodeMixRGB")
    caldo.blend_type = "MULTIPLY"
    caldo.location = (380, 20)
    caldo.inputs["Fac"].default_value = 1.0
    caldo.inputs["Color2"].default_value = srgb("#F0C878")
    L.new(solo.outputs["Color"], caldo.inputs["Color1"])
    L.new(caldo.outputs["Color"], b.inputs["Emission Color"])
    # Quasi zero: di giorno non si deve vedere niente. E' `modo_luci()` che la
    # porta a uno per lo scatto della notte.
    _set(b, "Emission Strength", 0.02)

    MASCHERA[name] = maschera
    return mat


# ----------------------------------------------------------------------
#  primitive
# ----------------------------------------------------------------------

def pulisci():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for blocco in (bpy.data.meshes, bpy.data.curves, bpy.data.materials,
                   bpy.data.lights, bpy.data.cameras, bpy.data.collections):
        for dato in list(blocco):
            if dato.users == 0:
                blocco.remove(dato)
    MASCHERA.clear()


def collezione(nome):
    c = bpy.data.collections.get(nome)
    if c is None:
        c = bpy.data.collections.new(nome)
        bpy.context.scene.collection.children.link(c)
    return c


def box(nome, centro, misure, materiale=None, rot=None):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=centro)
    ob = bpy.context.active_object
    ob.name = nome
    ob.scale = misure
    if rot:
        ob.rotation_euler = rot
    bpy.ops.object.transform_apply(location=False, rotation=bool(rot),
                                   scale=True)
    if materiale:
        ob.data.materials.append(materiale)
    return ob


def bx(nome, x0, x1, y0, y1, z0, z1, materiale=None):
    return box(nome, ((x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0),
               (abs(x1 - x0), abs(y1 - y0), abs(z1 - z0)), materiale)


def cilindro(nome, centro, raggio, altezza, materiale=None, lati=16, rot=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=lati, radius=raggio,
                                        depth=altezza, location=centro)
    ob = bpy.context.active_object
    ob.name = nome
    if rot:
        ob.rotation_euler = rot
        bpy.ops.object.transform_apply(location=False, rotation=True,
                                       scale=False)
    if materiale:
        ob.data.materials.append(materiale)
    return ob


def poligono(nome, punti, facce, materiale=None):
    me = bpy.data.meshes.new(nome)
    me.from_pydata([Vector(p) for p in punti], [], facce)
    me.update()
    ob = bpy.data.objects.new(nome, me)
    bpy.context.scene.collection.objects.link(ob)
    if materiale:
        ob.data.materials.append(materiale)
    return ob


def unisci(pezzi, nome):
    """Unisce e riporta l'origine a (0,0,0). Vedi la nota nel docstring."""
    pezzi = [p for p in pezzi if p and p.name in bpy.data.objects]
    if not pezzi:
        return None
    bpy.ops.object.select_all(action="DESELECT")
    for p in pezzi:
        p.select_set(True)
    bpy.context.view_layer.objects.active = pezzi[0]
    if len(pezzi) > 1:
        bpy.ops.object.join()
    ob = bpy.context.active_object
    ob.name = nome
    bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    bpy.ops.object.select_all(action="DESELECT")
    return ob


def scritta(nome, testo, x, y, z, altezza, materiale, estrusione=0.03):
    curva = bpy.data.curves.new(nome, type="FONT")
    curva.body = testo
    curva.align_x = "CENTER"
    curva.align_y = "CENTER"
    curva.extrude = estrusione
    try:
        curva.font = bpy.data.fonts.load(FONT, check_existing=True)
    except RuntimeError:
        pass
    ob = bpy.data.objects.new(nome, curva)
    collezione(COLL_TESTI).objects.link(ob)
    if materiale:
        ob.data.materials.append(materiale)
    dg = bpy.context.evaluated_depsgraph_get()
    dg.update()
    alta = max(ob.evaluated_get(dg).dimensions.y, 1e-4)
    curva.size = altezza / alta
    ob.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    ob.location = (x, y, z)
    return ob


# ----------------------------------------------------------------------
#  MERIDIAN TOWER
# ----------------------------------------------------------------------

MER = {
    "podio_w": 12.5, "podio_d": 13.0, "podio_h": 11.0,
    "base": 5.75,          # mezza larghezza del fusto in basso
    "cima": 4.40,          # semidiagonale del quadrato ruotato in cima
    "z0": 11.0, "z1": 83.0,
    "corona": 2.6,
    "antenna": 21.4,
    "piano": 3.8,
}


def meridian(pezzi):
    """Il fusto sfaccettato, dal basamento all'antenna.

    La forma: un quadrato in basso e lo stesso quadrato ruotato di 45 gradi in
    cima. Congiungendoli vengono otto triangoli lunghi quanto la torre —
    quattro che poggiano su un lato della base e puntano a un vertice della
    cima, quattro al contrario. Non e' un vezzo: le otto facce guardano in
    quattro direzioni diverse, quindi la torre prende il sole a pezzi e in
    momenti diversi, che e' tutto il punto del riflesso che si muove.
    """
    S = MER
    a, c = S["base"], S["cima"]
    z0, z1 = S["z0"], S["z1"]
    centro = (0.0, S["podio_d"] / 2.0)
    cy = centro[1]

    # --- materiali del vetro, uno per orientamento
    v_sud = vetro("GR_Vetro_Sud", "#4E6274", "#BCD8EA", "#27323E", S["piano"],
                  24, centro, SUD, seme=1.0)
    v_est = vetro("GR_Vetro_Est", "#53687A", "#C4DCEC", "#28333D", S["piano"],
                  24, centro, EST, seme=2.0)
    v_ovest = vetro("GR_Vetro_Ovest", "#475B6E", "#AFCCE2", "#232E39",
                    S["piano"], 24, centro, OVEST, seme=3.0)
    v_se = vetro("GR_Vetro_SudEst", "#506575", "#C0DAEB", "#26313C", S["piano"],
                 24, centro, SUD_EST, seme=4.0)
    v_so = vetro("GR_Vetro_SudOvest", "#4A5E71", "#B4D0E5", "#242F3A",
                 S["piano"], 24, centro, SUD_OVEST, seme=5.0)

    # --- gli otto triangoli
    #  A: quadrato in basso (angoli)     B: quadrato ruotato in cima (vertici)
    A = [(-a, cy - a), (a, cy - a), (a, cy + a), (-a, cy + a)]
    B = [(0.0, cy - c), (c, cy), (0.0, cy + c), (-c, cy)]
    facce = [
        # (i, j, orientamento):  triangolo con base sul lato A[i]-A[i+1]
        # e punta sul vertice B[j], poi quello opposto.
        ((A[0], A[1], B[0]), v_sud),        # lato sud, punta in cima
        ((A[1], B[0], B[1]), v_se),         # spigolo sud-est
        ((A[1], A[2], B[1]), v_est),        # lato est
        ((A[2], B[1], B[2]), v_est),        # spigolo nord-est (si vede poco)
        ((A[2], A[3], B[2]), v_sud),        # lato nord (dietro)
        ((A[3], B[2], B[3]), v_ovest),      # spigolo nord-ovest
        ((A[3], A[0], B[3]), v_ovest),      # lato ovest
        ((A[0], B[3], B[0]), v_so),         # spigolo sud-ovest
    ]
    for i, (tri, mat) in enumerate(facce):
        (p, q, r) = tri
        # I due triangoli di ogni coppia hanno il verso opposto: uno poggia in
        # basso e punta in alto, l'altro il contrario. Si distingue da quale
        # dei tre punti viene dal quadrato di cima.
        if i % 2 == 0:
            punti = [(p[0], p[1], z0), (q[0], q[1], z0), (r[0], r[1], z1)]
        else:
            punti = [(p[0], p[1], z0), (q[0], q[1], z1), (r[0], r[1], z1)]
        pezzi.append(poligono("MER_Faccia%d" % i, punti, [(0, 1, 2)], mat))

    # --- corona di vetro e cappello
    zc = z1 + S["corona"]
    corona = []
    for k in range(4):
        p, q = B[k], B[(k + 1) % 4]
        corona.append(poligono(
            "MER_Corona%d" % k,
            [(p[0], p[1], z1), (q[0], q[1], z1), (q[0], q[1], zc),
             (p[0], p[1], zc)], [(0, 1, 2, 3)], v_sud))
    pezzi.extend(corona)
    pezzi.append(poligono(
        "MER_Cappello",
        [(B[0][0], B[0][1], zc), (B[1][0], B[1][1], zc),
         (B[2][0], B[2][1], zc), (B[3][0], B[3][1], zc)],
        [(0, 1, 2, 3)], P["metallo"]))

    # --- antenna: il pennone e il suo anello di cavi
    za = zc + S["antenna"]
    bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=0.55, radius2=0.08,
                                    depth=S["antenna"],
                                    location=(0.0, cy, zc + S["antenna"] / 2.0))
    ant = bpy.context.active_object
    ant.name = "MER_Antenna"
    ant.data.materials.append(P["metallo"])
    pezzi.append(ant)
    pezzi.append(cilindro("MER_Anello", (0.0, cy, zc + 2.4), 1.35, 0.5,
                          P["metallo_scuro"], lati=12))
    # Il faro di segnalazione in punta: di notte e' l'unica cosa accesa lassu'.
    faro = cilindro("MER_Faro", (0.0, cy, za + 0.4), 0.42, 0.8, P["faro"],
                    lati=10)
    for col in list(faro.users_collection):
        col.objects.unlink(faro)
    collezione(COLL_TESTI).objects.link(faro)

    # --- basamento in pietra, con le lesene verticali
    pw, pd, ph = S["podio_w"] / 2.0, S["podio_d"], S["podio_h"]
    pezzi.append(bx("MER_Podio", -pw, pw, 0.0, pd, 0.0, ph, P["pietra"]))
    # Cinque lesene e non sette, e sottili: a sette il basamento si leggeva
    # come una gabbia, e un grattacielo non ha le sbarre al piano terra.
    for i in range(5):
        x = -pw + 1.1 + i * (2.0 * pw - 2.2) / 4.0
        pezzi.append(bx("MER_Lesena%d" % i, x - 0.17, x + 0.17, -0.16, 0.0,
                        0.0, ph - 0.55, P["pietra_chiara"]))
    pezzi.append(bx("MER_Cornice", -pw - 0.28, pw + 0.28, -0.34, pd,
                    ph - 0.55, ph + 0.30, P["pietra_chiara"]))
    # Ingresso: vetrata alta due piani e pensilina.
    pezzi.append(bx("MER_Ingresso", -4.2, 4.2, -0.10, 0.06, 0.0, 6.4,
                    P["atrio"]))
    for x in (-4.2, -1.4, 1.4, 4.2):
        pezzi.append(bx("MER_Mont%.1f" % x, x - 0.16, x + 0.16, -0.16, 0.10,
                        0.0, 6.6, P["metallo_scuro"]))
    pezzi.append(bx("MER_Pensilina", -5.0, 5.0, -1.6, 0.0, 6.5, 6.8,
                    P["metallo_scuro"]))
    scritta("MER_Nome", "MERIDIAN", 0.0, -0.22, 8.5, 0.9, P["insegna"])


# ----------------------------------------------------------------------
#  HARBOR HEIGHTS
# ----------------------------------------------------------------------

HAR = {
    "podio_w": 11.0, "podio_d": 11.0, "podio_h": 9.0,
    "w": 9.0, "d": 11.5,
    "piani": 22, "piano": 3.1,
    "corona": 5.0,
}


def harbor(pezzi):
    """La torre residenziale: solette a vista, piano su piano.

    Le solette dei balconi sono geometria vera e non righe dipinte. A settanta
    pixel di piano lo sporto di mezzo metro e' una riga di undici pixel con la
    sua ombra sotto, ed e' quella che da' il ritmo alla torre — nella foto di
    riferimento e' l'unica cosa che si vede da lontano.
    """
    S = HAR
    w, d = S["w"] / 2.0, S["d"]
    z0 = S["podio_h"]
    centro = (0.0, S["podio_d"] / 2.0)
    cy = centro[1]
    y0, y1 = cy - d / 2.0, cy + d / 2.0

    v_sud = vetro("GR_Har_Sud", "#56646E", "#BDD4E0", "#2B333A", S["piano"],
                  20, centro, SUD, accese=0.32, seme=7.0, rough=0.16,
                  metal=0.45)
    v_est = vetro("GR_Har_Est", "#5A6872", "#C6DAE4", "#2D353C", S["piano"],
                  20, centro, EST, accese=0.32, seme=8.0, rough=0.16,
                  metal=0.45)
    v_ovest = vetro("GR_Har_Ovest", "#4F5D67", "#B2C8D6", "#282F36",
                    S["piano"], 20, centro, OVEST, accese=0.32, seme=9.0,
                    rough=0.16, metal=0.45)
    # Gli spigoli smussati non sono un vezzo: con la camera dritta sul fronte
    # le facce a est e a ovest di un parallelepipedo si vedono di taglio, cioe'
    # non si vedono. Senza smussi la torre avrebbe una faccia sola, e il
    # riflesso del sole potrebbe solo accendersi e spegnersi a mezzogiorno
    # invece di attraversarla da destra a sinistra nell'arco della giornata.
    v_se = vetro("GR_Har_SudEst", "#54626C", "#BBD2DE", "#2A323A", S["piano"],
                 20, centro, SUD_EST, accese=0.32, seme=10.0, rough=0.16,
                 metal=0.45)
    v_so = vetro("GR_Har_SudOvest", "#4D5B65", "#AFC6D4", "#272F37",
                 S["piano"], 20, centro, SUD_OVEST, accese=0.32, seme=11.0,
                 rough=0.16, metal=0.45)

    zt = z0 + S["piani"] * S["piano"]
    # Il corpo: tre gusci di vetro, uno per orientamento, cosi' la maschera sa
    # dove guarda ogni faccia. Il pieno dentro non si vede mai.
    # Il fronte: pannello centrale dritto e due smussi a 45 gradi sugli
    # spigoli, larghi un metro e mezzo.
    sm = 1.5
    pezzi.append(bx("HAR_Corpo_Sud", -w + sm, w - sm, y0, y0 + 0.30, z0, zt,
                    v_sud))
    pezzi.append(poligono("HAR_Smusso_Est",
                          [(w - sm, y0, z0), (w, y0 + sm, z0),
                           (w, y0 + sm, zt), (w - sm, y0, zt)],
                          [(0, 1, 2, 3)], v_se))
    pezzi.append(poligono("HAR_Smusso_Ovest",
                          [(-w, y0 + sm, z0), (-w + sm, y0, z0),
                           (-w + sm, y0, zt), (-w, y0 + sm, zt)],
                          [(0, 1, 2, 3)], v_so))
    pezzi.append(bx("HAR_Corpo_Est", w - 0.30, w, y0 + sm, y1, z0, zt,
                    v_est))
    pezzi.append(bx("HAR_Corpo_Ovest", -w, -w + 0.30, y0 + sm, y1, z0, zt,
                    v_ovest))
    pezzi.append(bx("HAR_Corpo_Nord", -w, w, y1 - 0.30, y1, z0, zt,
                    P["cemento"]))
    pezzi.append(bx("HAR_Corpo_Pieno", -w + 0.28, w - 0.28, y0 + 0.28,
                    y1 - 0.28, z0, zt, P["cemento"]))

    # --- le solette, una per piano
    for i in range(S["piani"] + 1):
        z = z0 + i * S["piano"]
        pezzi.append(bx("HAR_Soletta%d" % i, -w - 0.55, w + 0.55, y0 - 0.55,
                        y1 + 0.20, z - 0.16, z + 0.16, P["cemento_chiaro"]))
    # Il setto cieco su un fianco: nella foto e' la striscia piena che tiene
    # insieme la pila di solette, ed e' anche quello che le impedisce di
    # leggersi come una scala. Parte dal basamento e muore sotto al
    # coronamento: prima scendeva fino a terra e sembrava un tubo di scarico.
    pezzi.append(bx("HAR_Setto", -w - 0.62, -w + 0.20, y0 - 0.62, y0 + 1.4,
                    z0, zt, P["cemento"]))

    # --- coronamento inclinato
    #
    # **Il taglio scende verso il fondo, non verso la strada.** Con la camera a
    # 27 gradi il tetto di una torre profonda undici metri si vede per cinque
    # metri di schermo: piatto era un lastrone grigio appoggiato in cima, la
    # cosa piu' grande e piu' vuota di tutto il disegno. Inclinandolo
    # all'indietro il fronte resta alto — la sagoma che si vede da lontano — e
    # del tetto si vede quasi niente. E' anche il coronamento scolpito della
    # foto di riferimento.
    zc = zt + S["corona"]
    zr = zt + 1.1
    punti = [(-w, y0, zt), (w, y0, zt), (w, y1, zt), (-w, y1, zt),
             (-w, y0, zc), (w, y0, zc), (w, y1, zr), (-w, y1, zr)]
    facce = [(0, 1, 5, 4), (1, 2, 6, 5), (3, 2, 6, 7), (3, 0, 4, 7)]
    pezzi.append(poligono("HAR_Corona", punti, facce, v_sud))
    # La falda del tetto, scura: e' una copertura, non una facciata.
    pezzi.append(poligono("HAR_Tetto", [(-w, y0, zc), (w, y0, zc),
                                        (w, y1, zr), (-w, y1, zr)],
                          [(0, 1, 2, 3)], P["copertura"]))
    # Parapetto sul fronte alto e cassone dei macchinari sul retro.
    pezzi.append(bx("HAR_Parapetto", -w - 0.34, w + 0.34, y0 - 0.34, y0 + 0.30,
                    zc - 0.10, zc + 0.55, P["cemento_chiaro"]))
    pezzi.append(bx("HAR_Macchinari", -w + 1.2, w - 1.2, y1 - 3.6, y1 - 1.2,
                    zr - 0.2, zr + 1.9, P["cemento"]))

    # --- basamento commerciale, piu' largo
    pw, pd, ph = S["podio_w"] / 2.0, S["podio_d"], S["podio_h"]
    pezzi.append(bx("HAR_Podio", -pw, pw, 0.0, pd, 0.0, ph, P["pietra"]))
    pezzi.append(bx("HAR_Podio_Vetro", -pw + 0.4, pw - 0.4, -0.08, 0.06, 0.6,
                    ph - 1.6, P["atrio"]))
    for i in range(5):
        x = -pw + 0.9 + i * (2.0 * pw - 1.8) / 4.0
        pezzi.append(bx("HAR_Podio_Mont%d" % i, x - 0.14, x + 0.14, -0.14,
                        0.10, 0.0, ph - 1.5, P["metallo_scuro"]))
    pezzi.append(bx("HAR_Podio_Cornice", -pw - 0.3, pw + 0.3, -0.36, pd,
                    ph - 1.5, ph - 1.0, P["pietra_chiara"]))
    pezzi.append(bx("HAR_Pensilina", -pw + 0.2, pw - 0.2, -1.7, 0.0, ph - 2.6,
                    ph - 2.35, P["metallo_scuro"]))
    scritta("HAR_Nome", "HARBOR HEIGHTS", 0.0, -0.40, ph - 0.7, 0.62,
            P["insegna"])


# ----------------------------------------------------------------------
#  materiali comuni, scena, camera
# ----------------------------------------------------------------------

P = {}


def palette():
    P.clear()
    P["pietra"] = piatto("GR_Pietra", "#7E7A72", rough=0.88)
    P["pietra_chiara"] = piatto("GR_Pietra_Chiara", "#9A958B", rough=0.85)
    P["cemento"] = piatto("GR_Cemento", "#8B8880", rough=0.92)
    P["cemento_chiaro"] = piatto("GR_Cemento_Chiaro", "#A8A49A", rough=0.88)
    P["metallo"] = piatto("GR_Metallo", "#9BA3A8", rough=0.35, metal=0.85)
    P["metallo_scuro"] = piatto("GR_Metallo_Scuro", "#3A3F44", rough=0.45,
                                metal=0.7)
    P["atrio"] = piatto("GR_Atrio", "#5E6154", rough=0.15, metal=0.2,
                        emissivo="#D8BF86", forza=0.40)
    P["insegna"] = piatto("GR_Insegna", "#D8D2C4", rough=0.5,
                          emissivo="#D8D2C4", forza=0.6)
    P["faro"] = piatto("GR_Faro", "#E03A2A", rough=0.4, emissivo="#FF4028",
                       forza=3.0)
    P["copertura"] = piatto("GR_Copertura", "#4B4E52", rough=0.94)
    return P


# Le torri non hanno marciapiede dentro allo sprite. Ce l'avevano — una lastra
# profonda 2,40 m davanti al basamento — ed e' uscita insieme a quelle di tutti
# gli altri modelli (2026-09-21): **il marciapiede lo disegna il gioco**
# (`city_ground.gd`). Uno cotto dentro allo sprite e' una seconda lastra col
# suo grigio, appoggiata sopra a quella vera, e il bordo fra i due si vede.
#
# Per le torri la lastra faceva anche un danno suo: era il pezzo piu' BASSO
# dello sprite, quindi il bordo inferiore del PNG non era la riga di terra del
# basamento ma un metro piu' avanti. Siccome `offset` in `city_map.gd` si
# calcola sul PNG, le due torri finivano disegnate qualche pixel sotto alla
# loro quota — poco, ma accostate si vedeva che non poggiavano sulla stessa
# riga.


def scena():
    sc = bpy.context.scene
    sc.unit_settings.system = "METRIC"

    dati = bpy.data.cameras.new("CAM_Front")
    dati.type = "ORTHO"
    dati.clip_start, dati.clip_end = 0.1, 800.0
    cam = bpy.data.objects.new("CAM_Front", dati)
    sc.collection.objects.link(cam)
    cam.rotation_euler = (math.radians(90.0 - INCLINAZIONE), 0.0, 0.0)
    sc.camera = cam

    # Il sole di mezzogiorno, in asse: il riflesso del mattino e della sera lo
    # mette lo shader in gioco, e uno scatto gia' sbilanciato a destra o a
    # sinistra si sommerebbe al suo — la torre avrebbe due soli.
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

    mondo = bpy.data.worlds.new("World")
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
        try:
            sc.render.engine = "BLENDER_EEVEE"
        except TypeError:
            pass
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    for attr, val in [("taa_render_samples", 128), ("use_raytracing", True),
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
    fuori.linestyle.thickness = 3.2
    _salta_testi(fuori)
    dentro = fs.linesets.new("Spigoli")
    for a in ("select_silhouette", "select_border", "select_ridge_valley",
              "select_suggestive_contour", "select_material_boundary",
              "select_edge_mark"):
        setattr(dentro, a, False)
    dentro.select_crease = True
    dentro.linestyle.color = (0.075, 0.058, 0.046)
    dentro.linestyle.alpha = 0.45
    dentro.linestyle.thickness = 1.5
    _salta_testi(dentro)
    return cam


def _salta_testi(lineset):
    coll = bpy.data.collections.get(COLL_TESTI)
    if coll is None:
        return
    lineset.select_by_collection = True
    lineset.collection = coll
    lineset.collection_negation = "EXCLUSIVE"


def inquadra(cam, margine=0.30):
    """Inquadratura sull'ingombro vero, sui VERTICI e non sul bound box."""
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    punti = []
    for obj in bpy.data.objects:
        if obj.type not in ("MESH", "FONT") or obj.hide_render:
            continue
        val = obj.evaluated_get(dg)
        mesh = val.to_mesh() if obj.type == "FONT" else val.data
        if mesh is None:
            continue
        for v in mesh.vertices:
            punti.append(obj.matrix_world @ v.co)
        if obj.type == "FONT":
            val.to_mesh_clear()
    inv = cam.matrix_world.inverted()
    vista = [inv @ p for p in punti]
    minx, maxx = min(p.x for p in vista), max(p.x for p in vista)
    miny, maxy = min(p.y for p in vista), max(p.y for p in vista)
    larg = (maxx - minx) + 2 * margine
    alt = (maxy - miny) + 2 * margine
    cam.location = cam.matrix_world @ Vector(
        ((minx + maxx) / 2.0, (miny + maxy) / 2.0, 400.0))
    cam.data.ortho_scale = max(larg, alt)
    sc = bpy.context.scene
    sc.render.resolution_x = int(round(larg * PX_PER_METRO))
    sc.render.resolution_y = int(round(alt * PX_PER_METRO))
    return larg, alt


# ----------------------------------------------------------------------
#  i tre scatti
# ----------------------------------------------------------------------

def _uscita(mat):
    return next((n for n in mat.node_tree.nodes
                 if n.type == "OUTPUT_MATERIAL"), None)


def modo_luci():
    """Solo quello che di notte resta acceso, su fondo nero.

    Diversa dalla versione degli altri edifici in un punto: qui l'emissione di
    una facciata **non e' un colore fisso**, e' una rete di nodi — le finestre
    sorteggiate cella per cella. Quindi l'albero non si puo' buttare e
    riscrivere: si stacca l'uscita e le si mette davanti un nodo Emission
    attaccato alla stessa rete che gia' c'era. Cosi' le finestre accese di
    notte sono esattamente le celle che il materiale aveva gia' scelto.
    """
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
        N, L = mat.node_tree.nodes, mat.node_tree.links
        bsdf = next((n for n in N if n.type == "BSDF_PRINCIPLED"), None)
        uscita = _uscita(mat)
        if uscita is None:
            continue
        sorgente = None
        if bsdf is not None and "Emission Strength" in bsdf.inputs:
            forza = float(bsdf.inputs["Emission Strength"].default_value)
            ingresso = bsdf.inputs.get("Emission Color")
            if forza > 0.001 and ingresso is not None:
                if ingresso.is_linked:
                    sorgente = ingresso.links[0].from_socket
                else:
                    sorgente = tuple(ingresso.default_value)
        em = N.new("ShaderNodeEmission")
        em.location = (uscita.location.x - 200, uscita.location.y - 200)
        if sorgente is None:
            em.inputs["Color"].default_value = (0.0, 0.0, 0.0, 1.0)
        elif isinstance(sorgente, tuple):
            em.inputs["Color"].default_value = sorgente
        else:
            L.new(sorgente, em.inputs["Color"])
        em.inputs["Strength"].default_value = 1.0
        for link in list(uscita.inputs["Surface"].links):
            L.remove(link)
        L.new(em.outputs["Emission"], uscita.inputs["Surface"])


def modo_vetro():
    """La maschera del vetro: ogni faccia tinta di dove guarda.

    Niente luci, niente contorni, niente sfumature: piatto e assoluto, perche'
    questo file non e' un disegno, e' un DATO che lo shader legge canale per
    canale. Tutto quello che non e' vetro esce nero, e nero vuol dire "qui non
    riflette niente".
    """
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
        N, L = mat.node_tree.nodes, mat.node_tree.links
        uscita = _uscita(mat)
        if uscita is None:
            continue
        colore = MASCHERA.get(mat.name, (0.0, 0.0, 0.0))
        em = N.new("ShaderNodeEmission")
        em.location = (uscita.location.x - 200, uscita.location.y + 200)
        em.inputs["Color"].default_value = (colore[0], colore[1], colore[2], 1.0)
        em.inputs["Strength"].default_value = 1.0
        for link in list(uscita.inputs["Surface"].links):
            L.remove(link)
        L.new(em.outputs["Emission"], uscita.inputs["Surface"])


TORRI = {
    "meridian": meridian,
    "harbor": harbor,
}


def costruisci(quale="meridian"):
    pulisci()
    palette()
    collezione(COLL_TESTI)
    pezzi = []
    TORRI[quale](pezzi)
    unisci(pezzi, "TORRE_" + quale.upper())
    cam = scena()
    return inquadra(cam)


def renderizza(cartella=None):
    """Tre scatti per torre: il disegno, le luci della notte, la maschera."""
    if cartella is None:
        cartella = os.path.abspath(os.path.join(
            os.path.dirname(os.path.abspath(__file__)), os.pardir, "assets",
            "sprites", "buildings", "_source"))
    os.makedirs(cartella, exist_ok=True)
    fatti = []
    for nome in TORRI:
        misure = costruisci(nome)
        sc = bpy.context.scene
        sc.render.resolution_percentage = SUPERSAMPLING * 100
        sc.render.filepath = os.path.join(cartella, "render_%s.png" % nome)
        bpy.ops.render.render(write_still=True)
        larghezza, altezza = sc.render.resolution_x, sc.render.resolution_y
        modo_luci()
        sc.render.filepath = os.path.join(cartella, "luci_%s.png" % nome)
        bpy.ops.render.render(write_still=True)
        # La maschera si fa ricostruendo: `modo_luci()` ha gia' riscritto i
        # materiali, e rifarci sopra un secondo passaggio darebbe la maschera
        # delle luci invece che quella del vetro.
        costruisci(nome)
        sc.render.resolution_percentage = SUPERSAMPLING * 100
        modo_vetro()
        sc.render.filepath = os.path.join(cartella, "vetro_%s.png" % nome)
        bpy.ops.render.render(write_still=True)
        fatti.append((nome, larghezza, altezza, misure))
    return fatti


if __name__ == "__main__":
    print("GRATTACIELI", costruisci("meridian"))
