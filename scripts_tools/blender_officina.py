"""Costruisce in Blender l'officina meccanica, con la serranda che si muove.

MILLER'S AUTO REPAIR: capannone a timpano con la serranda avvolgibile in
mezzo, la porta del personale con la pensilina, le finestre a riquadri, il
cartellone sopra il portone e le lampade a collo d'oca. Zoccolo rosso, muro
scrostato, tetto in lamiera ondulata.

## Che cosa lo rende diverso dagli altri edifici del quartiere

Gli altri sono un PNG solo. Questo e' una **striscia di fotogrammi**: la stessa
inquadratura con la serranda a diverse altezze, da tutta su a tutta giu'. In
gioco il fotogramma lo sceglie l'ora — `scripts/components/shop_shutter.gd` —
e l'officina apre la mattina e chiude la sera davanti al giocatore.

E' per questo che la serranda e' un oggetto a se' e non fa parte della mesh
unita: di tutto l'edificio e' l'unica cosa che si muove.

## Le regole del quartiere, che qui valgono uguali

  * camera ortografica inclinata 27 gradi sul solo asse X: la facciata resta
    dritta e si allinea agli altri edifici lungo la strada;
  * 22,3 px per metro — la scala la detta il personaggio, alto 39 px;
  * due linee Freestyle, contorno fuori e spigoli dentro, SOTTILI: 3,2 e 1,5.
    Le linee si tarano sulla densita' di dettaglio del modello, non si copiano
    da un altro edificio (vedi `scena()`);
  * i muri si BUCANO con una booleana, non si assemblano a pezzi, e i pezzi si
    UNISCONO in una mesh sola: ogni oggetto sciolto si porta dietro il suo
    contorno nero, e a ventidue pixel per metro quei contorni si toccano fra
    loro e anneriscono la facciata;
  * niente dettaglio sotto i sei pixel: le scritte piccole, alla riduzione,
    diventano poltiglia. Il cartellone ha due righe grandi e basta.

Uso da MCP: `costruisci()` lascia la scena pronta, `renderizza()` sputa la
striscia dei fotogrammi e lo scatto delle luci in
`assets/sprites/buildings/_source/`.
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

W = 11.0          # larghezza del fronte
# Poco profonda di proposito. Col timpano rivolto alla strada le due falde si
# vedono per tutta la profondita' dell'edificio, e a 27 gradi ogni metro di
# profondita' vale mezzo metro di altezza nello sprite: a otto metri il tetto
# si prendeva meta' del disegno. E' la stessa nota che ha la casa in
# `render_buildings.py`.
D = 6.4           # profondita'
H_MURO = 4.40     # quota di gronda
H_COLMO = 5.88    # quota del colmo
SP = 0.34         # spessore della facciata
ZOCCOLO = 1.05    # altezza della fascia rossa
SPORTO = 0.30     # sporto del tetto

# Il vano della serranda.
SER_X0, SER_X1 = -0.75, 3.05
SER_Z0, SER_Z1 = 0.04, 3.05
# Quanto resta in vista, arrotolato sotto al cassonetto, a serranda tutta su.
SER_ROTOLO = 0.22
# A che profondita' sta il fondo dell'officina: davanti a questo c'e' il vuoto
# che si vede dal portone aperto, dietro c'e' il pieno.
INT_FONDO = 3.10

FONT = "C:/Windows/Fonts/arialbd.ttf"
COLL_TESTI = "SenzaContorno"

# Quanti fotogrammi ha la striscia: 0 = tutta su, ultimo = tutta giu'.
#
# Dodici e non quattro: l'animazione dura tre secondi veri (dodici minuti di
# gioco, vedi `shop_shutter.gd`) e con quattro fotogrammi la serranda scende a
# scatti da mezzo metro. Dodici sono anche solo dodici volte la larghezza di un
# edificio in texture, che non e' niente.
FOTOGRAMMI = 12


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
    """Il Principled si cerca per tipo: su una UI non inglese il nome cambia."""
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


def _posizione_mondo(N, L):
    """Il nodo che da' la posizione in coordinate MONDO.

    Non oggetto: le righe della serranda e le onde della lamiera devono restare
    ferme nello spazio mentre l'oggetto si muove e si schiaccia. La serranda si
    anima scalandola in altezza, e con le coordinate oggetto le sue doghe si
    allungherebbero insieme a lei — una serranda che si apre diventando di
    gomma.
    """
    geo = N.new("ShaderNodeNewGeometry")
    geo.location = (-1200, 0)
    sep = N.new("ShaderNodeSeparateXYZ")
    sep.location = (-1020, 0)
    L.new(geo.outputs["Position"], sep.inputs["Vector"])
    return sep


def righe(name, chiaro, scuro, passo, asse="Z", rough=0.68, metal=0.35,
          sporco=None, macchie=0.0, seme=0.0):
    """Righe parallele ricavate dalla posizione nel mondo.

    Le doghe della serranda, le onde della lamiera, i corsi di una tettoia: a
    questa scala sono tutti la stessa cosa, una riga ogni tot centimetri. Prese
    dalla posizione e non da una texture restano allineate anche dopo aver
    unito le mesh, e soprattutto non si deformano se l'oggetto viene scalato.
    """
    mat = _fresh(name)
    N, L = mat.node_tree.nodes, mat.node_tree.links
    b = _bsdf(mat)
    _set(b, "Roughness", rough)
    _set(b, "Metallic", metal)

    sep = _posizione_mondo(N, L)
    div = N.new("ShaderNodeMath")
    div.operation = "DIVIDE"
    div.location = (-840, 0)
    div.inputs[1].default_value = passo
    L.new(sep.outputs[asse], div.inputs[0])
    fra = N.new("ShaderNodeMath")
    fra.operation = "FRACT"
    fra.location = (-680, 0)
    L.new(div.outputs[0], fra.inputs[0])

    ramp = N.new("ShaderNodeValToRGB")
    ramp.location = (-500, 0)
    # Due scalini: la riga scura sta in fondo al passo, il resto e' chiaro. Non
    # una sfumatura: a un pixel e mezzo di passo una sfumatura e' grigio.
    ramp.color_ramp.interpolation = "CONSTANT"
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = srgb(scuro)
    ramp.color_ramp.elements[1].position = 0.26
    ramp.color_ramp.elements[1].color = srgb(chiaro)
    L.new(fra.outputs[0], ramp.inputs["Fac"])

    uscita = ramp.outputs["Color"]
    if sporco:
        noise = N.new("ShaderNodeTexNoise")
        noise.location = (-500, -320)
        _set(noise, "Scale", 1.6)
        _set(noise, "Detail", 5.0)
        _set(noise, "W", seme)
        coord = N.new("ShaderNodeTexCoord")
        coord.location = (-700, -320)
        L.new(coord.outputs["Object"], noise.inputs["Vector"])
        gramp = N.new("ShaderNodeValToRGB")
        gramp.location = (-320, -320)
        gramp.color_ramp.elements[0].position = 0.45
        gramp.color_ramp.elements[0].color = (0.0, 0.0, 0.0, 1.0)
        gramp.color_ramp.elements[1].position = 0.72
        gramp.color_ramp.elements[1].color = (macchie, macchie, macchie, 1.0)
        L.new(noise.outputs["Fac"], gramp.inputs["Fac"])
        mix = N.new("ShaderNodeMixRGB")
        mix.blend_type = "MIX"
        mix.location = (-140, 0)
        mix.inputs["Color2"].default_value = srgb(sporco)
        L.new(uscita, mix.inputs["Color1"])
        L.new(gramp.outputs["Color"], mix.inputs["Fac"])
        uscita = mix.outputs["Color"]
    L.new(uscita, b.inputs["Base Color"])
    return mat


def scrostato(name, muro, sotto, sporco, seme=0.0, chiazze=2.2, forza=0.55):
    """Muro dipinto e scrostato: sotto alla vernice si vede l'intonaco.

    Due rumori: uno largo per le zone slavate, uno stretto per le scrostature
    vere. Senza, il muro bianco di un capannone e' un rettangolo bianco, e a
    questa scala si legge come un buco nello sprite.
    """
    mat = _fresh(name)
    N, L = mat.node_tree.nodes, mat.node_tree.links
    b = _bsdf(mat)
    _set(b, "Roughness", 0.92)

    coord = N.new("ShaderNodeTexCoord")
    coord.location = (-1100, 0)

    grande = N.new("ShaderNodeTexNoise")
    grande.location = (-900, 200)
    _set(grande, "Scale", 0.9)
    _set(grande, "Detail", 6.0)
    _set(grande, "W", seme)
    L.new(coord.outputs["Object"], grande.inputs["Vector"])

    stretto = N.new("ShaderNodeTexNoise")
    stretto.location = (-900, -200)
    _set(stretto, "Scale", chiazze)
    _set(stretto, "Detail", 8.0)
    _set(stretto, "Roughness", 0.75)
    _set(stretto, "W", seme + 3.0)
    L.new(coord.outputs["Object"], stretto.inputs["Vector"])

    r1 = N.new("ShaderNodeValToRGB")
    r1.location = (-700, 200)
    r1.color_ramp.elements[0].position = 0.42
    r1.color_ramp.elements[1].position = 0.60
    L.new(grande.outputs["Fac"], r1.inputs["Fac"])

    r2 = N.new("ShaderNodeValToRGB")
    r2.location = (-700, -200)
    r2.color_ramp.interpolation = "CONSTANT"
    r2.color_ramp.elements[0].position = 0.0
    r2.color_ramp.elements[0].color = (0.0, 0.0, 0.0, 1.0)
    r2.color_ramp.elements[1].position = 0.58
    r2.color_ramp.elements[1].color = (1.0, 1.0, 1.0, 1.0)
    L.new(stretto.outputs["Fac"], r2.inputs["Fac"])

    m1 = N.new("ShaderNodeMixRGB")
    m1.location = (-480, 0)
    m1.inputs["Color1"].default_value = srgb(muro)
    m1.inputs["Color2"].default_value = srgb(sporco)
    L.new(r1.outputs["Color"], m1.inputs["Fac"])

    m2 = N.new("ShaderNodeMixRGB")
    m2.location = (-280, 0)
    m2.inputs["Color2"].default_value = srgb(sotto)
    m2.inputs["Fac"].default_value = forza
    L.new(m1.outputs["Color"], m2.inputs["Color1"])
    L.new(r2.outputs["Color"], m2.inputs["Fac"])
    L.new(m2.outputs["Color"], b.inputs["Base Color"])
    return mat


P = {}


def palette():
    P.clear()
    P["muro"] = scrostato("OF_Muro", "#E6E0D0", "#C2B79F", "#D2CAB4", seme=1.0)
    P["muro_lato"] = scrostato("OF_Muro_Lato", "#D8D1BF", "#B6AB93", "#C0B79F",
                               seme=4.0, forza=0.62)
    P["zoccolo"] = scrostato("OF_Zoccolo", "#B23A2C", "#8E3427", "#9A4133",
                             seme=7.0, chiazze=3.0, forza=0.5)
    P["rosso"] = piatto("OF_Rosso", "#B8382A", rough=0.72)
    P["rosso_scuro"] = piatto("OF_Rosso_Scuro", "#8C2B20", rough=0.75)
    P["lamiera"] = righe("OF_Lamiera", "#A7ADAF", "#7E8689", 0.26, asse="X",
                         rough=0.55, metal=0.55, sporco="#8A5A3C", macchie=0.55,
                         seme=2.0)
    P["serranda"] = righe("OF_Serranda", "#B9BEC0", "#8D9497", 0.155, asse="Z",
                          rough=0.48, metal=0.6, sporco="#8A6142", macchie=0.42,
                          seme=5.0)
    P["ferro"] = piatto("OF_Ferro", "#2E2A27", rough=0.55, metal=0.6)
    P["ferro_chiaro"] = piatto("OF_Ferro_Chiaro", "#8A8F90", rough=0.45,
                               metal=0.7)
    P["zinco"] = piatto("OF_Zinco", "#9DA3A5", rough=0.5, metal=0.65)
    P["blu"] = piatto("OF_Blu", "#3E5C7E", rough=0.7)
    P["blu_scuro"] = piatto("OF_Blu_Scuro", "#22364B", rough=0.7)
    P["insegna"] = piatto("OF_Insegna", "#E7E0CE", rough=0.6)
    # Il pannello del cartellone e' acceso FIOCO: di notte ce l'ha addosso la
    # sua lampada a collo d'oca, e senza questo restava acceso solo il nome in
    # rosso — mezza insegna che galleggia nel buio.
    P["insegna_luce"] = piatto("OF_Insegna_Luce", "#E7E0CE", rough=0.6,
                               emissivo="#E8DFC4", forza=0.30)
    P["testo_rosso"] = piatto("OF_Testo_Rosso", "#C0392B", rough=0.45,
                              emissivo="#C0392B", forza=0.9)
    P["testo_blu"] = piatto("OF_Testo_Blu", "#26384F", rough=0.45,
                            emissivo="#3B5474", forza=0.45)
    P["testo_bianco"] = piatto("OF_Testo_Bianco", "#F2ECDC", rough=0.45,
                               emissivo="#F2ECDC", forza=0.9)
    P["vetro"] = piatto("OF_Vetro", "#4C5A5E", rough=0.12, metal=0.3)
    P["vetro_acceso"] = piatto("OF_Vetro_Acceso", "#C9A765", rough=0.14,
                               emissivo="#E8C179", forza=1.15)
    P["neon"] = piatto("OF_Neon", "#E8453A", rough=0.3, emissivo="#FF5A44",
                       forza=2.4)
    P["neon_blu"] = piatto("OF_Neon_Blu", "#3E7BD6", rough=0.3,
                           emissivo="#4E8BF0", forza=2.0)
    P["lampada"] = piatto("OF_Lampada", "#FFE3A8", rough=0.25,
                          emissivo="#FFD98A", forza=3.4)
    P["cemento"] = piatto("OF_Cemento", "#9B958A", rough=0.95)
    P["asfalto"] = piatto("OF_Asfalto", "#6E6963", rough=0.97)
    P["interno"] = piatto("OF_Interno", "#4A443C", rough=0.95)
    P["interno_luce"] = piatto("OF_Interno_Luce", "#8C7E62", rough=0.9,
                               emissivo="#C9A86A", forza=0.55)
    P["gomma"] = piatto("OF_Gomma", "#26241F", rough=0.95)
    return P


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
    """Scatola dagli estremi: una facciata si legge per estremi, non per centro."""
    return box(nome, ((x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0),
               (abs(x1 - x0), abs(y1 - y0), abs(z1 - z0)), materiale)


def cilindro(nome, centro, raggio, altezza, materiale=None, lati=14, rot=None):
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
    """Mesh da vertici e facce: serve per il timpano, che e' un triangolo."""
    me = bpy.data.meshes.new(nome)
    me.from_pydata([Vector(p) for p in punti], [], facce)
    me.update()
    ob = bpy.data.objects.new(nome, me)
    bpy.context.scene.collection.objects.link(ob)
    if materiale:
        ob.data.materials.append(materiale)
    return ob


def unisci(pezzi, nome):
    """Unisce e riporta l'origine a (0,0,0).

    Il Freestyle disegna la silhouette di ogni OGGETTO: cento scatole sciolte
    sono cento contorni neri, e a ventidue pixel per metro si toccano fra loro.
    Unite, il contorno gira solo intorno all'edificio.
    """
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


def muro_forato(nome, x0, x1, z0, z1, y0, y1, materiale, fori):
    """Un muro solo, bucato con una booleana. NON una fila di scatole."""
    muro = bx(nome, x0, x1, y0, y1, z0, z1, materiale)
    tagli = []
    for i, (fa, fb, za, zb) in enumerate(fori):
        # Il cutter sfonda oltre lo spessore: con le facce complanari la
        # booleana lascia una pellicola di muro dentro al foro.
        tagli.append(bx("%s_cut%d" % (nome, i), fa, fb, y0 - 0.06, y1 + 0.06,
                        za, zb))
    if not tagli:
        return muro
    cutter = unisci(tagli, "%s_cutter" % nome)
    bpy.context.view_layer.objects.active = muro
    mod = muro.modifiers.new("Aperture", "BOOLEAN")
    mod.operation, mod.solver, mod.object = "DIFFERENCE", "EXACT", cutter
    bpy.ops.object.modifier_apply(modifier="Aperture")
    bpy.data.objects.remove(cutter, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    muro.select_set(True)
    bpy.context.view_layer.objects.active = muro
    bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    return muro


def scritta(nome, testo, x, y, z, altezza, materiale, estrusione=0.04,
            allinea="CENTER"):
    """Testo vero estruso, fuori dal Freestyle.

    Una lettera alta nove pixel con intorno un contorno nero da due non e' piu'
    una lettera: le scritte stanno in una collezione che le due linee saltano.
    """
    curva = bpy.data.curves.new(nome, type="FONT")
    curva.body = testo
    curva.align_x = allinea
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
    # La misura si prende sulla copia VALUTATA: `dimensions` di un testo appena
    # creato e' ancora il riquadro vuoto, e scalando su quello le insegne
    # escono cinque volte troppo grandi.
    dg = bpy.context.evaluated_depsgraph_get()
    dg.update()
    alta = max(ob.evaluated_get(dg).dimensions.y, 1e-4)
    curva.size = altezza / alta
    ob.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    ob.location = (x, y, z)
    return ob


# ----------------------------------------------------------------------
#  i pezzi dell'officina
# ----------------------------------------------------------------------

def finestra(nome, x0, x1, z0, z1, colonne, righe_n, pezzi, acceso=True):
    """Finestra industriale a riquadri: vetro, telaio e croce di montanti."""
    pezzi.append(bx(nome + "_Vetro", x0, x1, SP - 0.07, SP - 0.03, z0, z1,
                    P["vetro_acceso"] if acceso else P["vetro"]))
    t = 0.075
    for a, b in ((x0, x0 + t), (x1 - t, x1)):
        pezzi.append(bx(nome + "_TelV%.2f" % a, a, b, 0.0, SP, z0, z1,
                        P["ferro_chiaro"]))
    for a, b in ((z0, z0 + t), (z1 - t, z1)):
        pezzi.append(bx(nome + "_TelO%.2f" % a, x0, x1, 0.0, SP, a, b,
                        P["ferro_chiaro"]))
    for i in range(1, colonne):
        x = x0 + (x1 - x0) * i / colonne
        pezzi.append(bx(nome + "_MontV%d" % i, x - 0.028, x + 0.028, 0.02,
                        SP - 0.02, z0, z1, P["ferro_chiaro"]))
    for i in range(1, righe_n):
        z = z0 + (z1 - z0) * i / righe_n
        pezzi.append(bx(nome + "_MontO%d" % i, x0, x1, 0.02, SP - 0.02,
                        z - 0.028, z + 0.028, P["ferro_chiaro"]))
    # Davanzale e architrave in cemento: sono il contrasto chiaro che a questa
    # scala fa leggere la finestra come finestra e non come macchia scura.
    pezzi.append(bx(nome + "_Davanzale", x0 - 0.10, x1 + 0.10, -0.10, SP,
                    z0 - 0.10, z0, P["cemento"]))
    pezzi.append(bx(nome + "_Arch", x0 - 0.10, x1 + 0.10, -0.07, SP, z1,
                    z1 + 0.12, P["cemento"]))


def lampada(nome, x, z, pezzi, braccio=0.62):
    """Lampada a collo d'oca: braccio, curva e piatto. Il bulbo e' emissivo."""
    pezzi.append(bx(nome + "_Attacco", x - 0.06, x + 0.06, -0.10, 0.02,
                    z - 0.06, z + 0.06, P["ferro"]))
    pezzi.append(cilindro(nome + "_Braccio", (x, -braccio * 0.5, z + 0.16),
                          0.032, braccio, P["ferro"], lati=8,
                          rot=(math.radians(74), 0, 0)))
    bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=0.26, radius2=0.07,
                                    depth=0.20,
                                    location=(x, -braccio + 0.06, z + 0.22))
    piatto_ob = bpy.context.active_object
    piatto_ob.name = nome + "_Piatto"
    piatto_ob.rotation_euler = (math.radians(180), 0, 0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    piatto_ob.data.materials.append(P["ferro"])
    pezzi.append(piatto_ob)
    bulbo = cilindro(nome + "_Bulbo", (x, -braccio + 0.06, z + 0.11), 0.16,
                     0.05, P["lampada"], lati=16)
    # Il bulbo sta fuori dal contorno: un cerchio di sette pixel con intorno
    # una riga nera diventa un punto scuro invece che una lampada accesa.
    for c in list(bulbo.users_collection):
        c.objects.unlink(bulbo)
    collezione(COLL_TESTI).objects.link(bulbo)


def facciata(pezzi):
    """Il fronte: muro, zoccolo, timpano, vano della serranda, aperture."""
    x0, x1 = -W / 2.0, W / 2.0
    porta = (-3.55, -2.45, 0.0, 2.25)
    fin_sx = (-5.15, -3.95, 1.35, 3.05)
    fin_dx = (3.55, 5.05, 1.35, 3.05)
    fori = [(SER_X0, SER_X1, SER_Z0, SER_Z1), porta, fin_sx, fin_dx]
    pezzi.append(muro_forato("OF_Muro_Fronte", x0, x1, ZOCCOLO, H_MURO,
                             0.0, SP, P["muro"], fori))
    pezzi.append(muro_forato("OF_Zoccolo_Fronte", x0, x1, 0.0, ZOCCOLO,
                             -0.02, SP, P["zoccolo"],
                             [(SER_X0, SER_X1, SER_Z0, SER_Z1), porta]))

    # Timpano: il triangolo sopra la gronda, muro e zoccolo non c'entrano.
    punti = [(x0, 0.0, H_MURO), (x1, 0.0, H_MURO), (0.0, 0.0, H_COLMO),
             (x0, SP, H_MURO), (x1, SP, H_MURO), (0.0, SP, H_COLMO)]
    facce = [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]
    pezzi.append(poligono("OF_Timpano", punti, facce, P["muro"]))

    # Cornice rossa intorno al portone: e' il segno che tiene insieme la
    # facciata, e nel riferimento e' la prima cosa che si vede.
    bordo = 0.24
    pezzi.append(bx("OF_Cornice_Sx", SER_X0 - bordo, SER_X0, -0.06, 0.02,
                    0.0, SER_Z1 + bordo, P["rosso"]))
    pezzi.append(bx("OF_Cornice_Dx", SER_X1, SER_X1 + bordo, -0.06, 0.02,
                    0.0, SER_Z1 + bordo, P["rosso"]))
    pezzi.append(bx("OF_Cornice_Su", SER_X0 - bordo, SER_X1 + bordo, -0.06,
                    0.02, SER_Z1, SER_Z1 + bordo, P["rosso"]))
    # Fascia rossa di gronda, da una parte all'altra.
    pezzi.append(bx("OF_Fascia_Gronda", x0 - SPORTO, x1 + SPORTO, -0.12, 0.02,
                    H_MURO - 0.16, H_MURO + 0.02, P["rosso"]))

    # Soglia e battuta del portone.
    pezzi.append(bx("OF_Soglia", SER_X0 - bordo, SER_X1 + bordo, -0.55, SP,
                    -0.02, SER_Z0 + 0.02, P["cemento"]))

    # Porta del personale.
    pezzi.append(bx("OF_Porta", porta[0] + 0.05, porta[1] - 0.05, SP - 0.09,
                    SP - 0.03, porta[2], porta[3] - 0.04, P["blu"]))
    pezzi.append(bx("OF_Porta_Vetro", porta[0] + 0.32, porta[1] - 0.32,
                    SP - 0.11, SP - 0.09, 1.50, 1.92, P["vetro_acceso"]))
    pezzi.append(bx("OF_Porta_Maniglia", porta[1] - 0.26, porta[1] - 0.18,
                    SP - 0.16, SP - 0.09, 1.02, 1.14, P["ferro_chiaro"]))
    for a, b in ((porta[0] - 0.09, porta[0]), (porta[1], porta[1] + 0.09)):
        pezzi.append(bx("OF_Stipite%.2f" % a, a, b, -0.04, SP, 0.0,
                        porta[3] + 0.09, P["cemento"]))
    pezzi.append(bx("OF_Architrave_Porta", porta[0] - 0.09, porta[1] + 0.09,
                    -0.04, SP, porta[3], porta[3] + 0.09, P["cemento"]))
    # Pensilina sopra la porta, in lamiera come il tetto.
    px = (porta[0] + porta[1]) / 2.0
    pezzi.append(box("OF_Pensilina", (px, -0.36, porta[3] + 0.42),
                     (1.62, 0.80, 0.05), P["lamiera"],
                     rot=(math.radians(-18), 0, 0)))
    for s in (-0.74, 0.74):
        pezzi.append(box("OF_Mensola%.2f" % s, (px + s, -0.22, porta[3] + 0.24),
                         (0.05, 0.62, 0.05), P["ferro"],
                         rot=(math.radians(38), 0, 0)))
    # Quadro elettrico accanto alla porta.
    pezzi.append(bx("OF_Quadro", porta[0] - 0.62, porta[0] - 0.22, -0.13, 0.0,
                    1.45, 2.05, P["ferro_chiaro"]))

    finestra("OF_Fin_Sx", fin_sx[0], fin_sx[1], fin_sx[2], fin_sx[3], 2, 3,
             pezzi)
    finestra("OF_Fin_Dx", fin_dx[0], fin_dx[1], fin_dx[2], fin_dx[3], 3, 3,
             pezzi)
    # Neon dentro alla finestra di destra: e' quello che di notte dice che
    # l'officina c'e'. Grande abbastanza da leggersi: 0,8 x 0,42 m = 18 x 9 px.
    # Il neon sta DAVANTI al vetro, non dietro: il vetro e' un pannello opaco
    # (a questa scala un vetro trasparente non porta nessuna informazione in
    # piu'), e messo dietro il neon spariva — di notte restava una finestra
    # gialla come le altre.
    pezzi.append(bx("OF_Neon", 3.95, 4.75, SP - 0.12, SP - 0.09, 1.95, 2.37,
                    P["neon"]))
    pezzi.append(bx("OF_Neon_Bordo", 3.88, 4.82, SP - 0.09, SP - 0.06, 1.88,
                    2.44, P["neon_blu"]))

    # Targa "gomme" sotto la finestra di destra: un disco e due barre, non una
    # scritta. A venti pixel di larghezza una scritta e' poltiglia.
    pezzi.append(bx("OF_Targa", 4.05, 4.95, -0.08, 0.0, 0.25, 1.12,
                    P["blu_scuro"]))
    pezzi.append(cilindro("OF_Targa_Gomma", (4.50, -0.10, 0.52), 0.21, 0.04,
                          P["ferro"], lati=16, rot=(math.radians(90), 0, 0)))
    for z in (0.82, 0.96):
        pezzi.append(bx("OF_Targa_Barra%.2f" % z, 4.16, 4.84, -0.10, -0.08,
                        z, z + 0.07, P["insegna"]))


def cartellone(pezzi):
    """Il cartellone sopra il portone: due righe grandi e basta.

    Nel riferimento sotto al nome c'e' la riga dei servizi — TIRES, BRAKES,
    TUNE UPS — alta dieci centimetri. A 22,3 px per metro sono DUE pixel: non
    e' una scritta piccola, e' una riga grigia. Qui non c'e'.
    """
    # Sotto la linea di gronda, non sul timpano. Lo sporto del tetto, a 27
    # gradi, si proietta in basso di mezzo metro: un cartellone appeso al
    # timpano se lo trovava addosso di traverso, e da lontano sembrava una
    # trave che attraversa l'insegna.
    x0, x1 = -1.35, 3.65
    z0, z1 = SER_Z1 + 0.16, H_MURO - 0.22
    pezzi.append(bx("OF_Cart_Cassa", x0, x1, -0.16, 0.02, z0, z1,
                    P["insegna_luce"]))
    pezzi.append(bx("OF_Cart_Bordo_Su", x0 - 0.06, x1 + 0.06, -0.20, 0.02,
                    z1 - 0.10, z1 + 0.06, P["blu_scuro"]))
    pezzi.append(bx("OF_Cart_Bordo_Giu", x0 - 0.06, x1 + 0.06, -0.20, 0.02,
                    z0 - 0.06, z0 + 0.10, P["blu_scuro"]))
    for x in (x0 - 0.06, x1):
        pezzi.append(bx("OF_Cart_Lato%.2f" % x, x, x + 0.06, -0.20, 0.02,
                        z0 - 0.06, z1 + 0.06, P["blu_scuro"]))
    cx = (x0 + x1) / 2.0
    # Le due righe stanno alte 0,46 e 0,34 m, cioe' dieci e otto pixel nello
    # sprite. Sotto i sei pixel una scritta non e' piccola, e' poltiglia: e' il
    # limite sotto cui, in questo quartiere, le scritte non si renderizzano.
    scritta("OF_Txt_Nome", "MILLER'S", cx, -0.22,
            z0 + (z1 - z0) * 0.68, 0.46, P["testo_rosso"])
    scritta("OF_Txt_Sotto", "AUTO REPAIR", cx, -0.22,
            z0 + (z1 - z0) * 0.27, 0.34, P["testo_blu"])


def serranda():
    """La serranda: cassonetto fisso, telo mobile, barra di fondo.

    Torna il telo e la barra, che sono i due pezzi che si muovono. Il telo NON
    entra nella mesh unita dell'edificio: e' l'unica cosa animata, e deve
    restare un oggetto suo.
    """
    hood = bx("OF_Serranda_Cassonetto", SER_X0 - 0.06, SER_X1 + 0.06,
              -0.12, SP, SER_Z1 - 0.10, SER_Z1 + 0.20, P["ferro_chiaro"])
    telo = bx("OF_Serranda", SER_X0, SER_X1, SP - 0.14, SP - 0.06,
              SER_Z0, SER_Z1, P["serranda"])
    barra = bx("OF_Serranda_Barra", SER_X0, SER_X1, SP - 0.16, SP - 0.04,
               SER_Z0, SER_Z0 + 0.14, P["ferro"])
    # Le tre finestrelle della serranda, come nel riferimento: sono alla quota
    # della barra piu' due terzi, e si muovono col telo.
    oblo = []
    for i, fx in enumerate((0.22, 0.50, 0.78)):
        x = SER_X0 + (SER_X1 - SER_X0) * fx
        oblo.append(bx("OF_Serranda_Oblo%d" % i, x - 0.30, x + 0.30,
                       SP - 0.16, SP - 0.13, 2.28, 2.50, P["ferro"]))
    telo = unisci([telo] + oblo, "OF_Serranda")
    return hood, telo, barra


def interno(pezzi):
    """Quello che si vede dentro quando la serranda e' su.

    Non e' arredamento: e' il fondo scuro che fa leggere il portone come un
    buco e non come un pannello grigio. Quattro cose — parete, banco, pila di
    gomme, plafoniera — perche' a questa scala il resto sarebbe rumore.

    Tutto sta DAVANTI a `INT_FONDO`, cioe' nel vuoto lasciato apposta dal
    volume: un banco modellato dentro al pieno non lo vede nessuno.
    """
    x0, x1 = -W / 2.0 + 0.34, W / 2.0 - 0.34
    pezzi.append(bx("OF_Int_Fondo", x0, x1, INT_FONDO - 0.12, INT_FONDO,
                    0.0, H_MURO, P["interno"]))
    pezzi.append(bx("OF_Int_Pavimento", x0, x1, SP, INT_FONDO, -0.02, 0.04,
                    P["asfalto"]))
    # Banco da lavoro e pannello degli attrezzi, sulla sinistra del vano.
    pezzi.append(bx("OF_Int_Banco", SER_X0 + 0.15, SER_X0 + 1.75,
                    INT_FONDO - 0.65, INT_FONDO - 0.12, 0.0, 0.95,
                    P["interno_luce"]))
    pezzi.append(bx("OF_Int_Pannello", SER_X0 + 0.15, SER_X0 + 1.75,
                    INT_FONDO - 0.16, INT_FONDO - 0.12, 1.10, 2.20,
                    P["interno_luce"]))
    # Pila di gomme sulla destra.
    for i in range(3):
        pezzi.append(cilindro("OF_Int_Gomma%d" % i,
                              (SER_X1 - 0.70, INT_FONDO - 0.45,
                               0.19 + i * 0.30), 0.34, 0.28, P["gomma"],
                              lati=14, rot=(math.radians(90), 0, 0)))
    # Plafoniera del capannone: la riga di luce che si vede dalla strada, ed e'
    # anche quello che di giorno dice che dentro c'e' qualcuno che lavora.
    pezzi.append(bx("OF_Int_Plafoniera", SER_X0 + 0.4, SER_X1 - 0.4,
                    INT_FONDO - 1.30, INT_FONDO - 0.95, SER_Z1 - 0.42,
                    SER_Z1 - 0.30, P["interno_luce"]))


def tetto(pezzi):
    """Le due falde come UNA mesh, piu' colmo, gronda, pluviali e torrino.

    Non due scatole ruotate: due parallelepipedi inclinati non si chiudono al
    colmo — i loro spigoli si incrociano e restano fuori, e nello sprite si
    vede una fessura di cielo in mezzo al tetto. Qui il profilo (gronda, colmo,
    gronda) viene estruso in profondita' una volta sola, e il colmo e' un
    vertice condiviso.
    """
    xe = W / 2.0 + SPORTO
    zg = H_MURO - 0.06          # quota della gronda, appena sotto il muro
    sp = 0.14                   # spessore della falda
    y0, y1 = -SPORTO, D + SPORTO
    profilo = [(-xe, zg), (0.0, H_COLMO), (xe, zg)]
    punti = []
    for (x, z) in profilo:                 # 0,1,2 sopra davanti
        punti.append((x, y0, z))
    for (x, z) in profilo:                 # 3,4,5 sopra dietro
        punti.append((x, y1, z))
    for (x, z) in profilo:                 # 6,7,8 sotto davanti
        punti.append((x, y0, z - sp))
    for (x, z) in profilo:                 # 9,10,11 sotto dietro
        punti.append((x, y1, z - sp))
    facce = [
        (0, 1, 4, 3), (1, 2, 5, 4),        # le due falde
        (6, 9, 10, 7), (7, 10, 11, 8),     # il sottotetto
        (0, 3, 9, 6), (2, 8, 11, 5),       # i due bordi di gronda
        (0, 6, 7, 1), (1, 7, 8, 2),        # il bordo davanti (timpano)
        (3, 4, 10, 9), (4, 5, 11, 10),     # il bordo dietro
    ]
    pezzi.append(poligono("OF_Tetto", punti, facce, P["lamiera"]))
    # Colmo: un coppo di zinco a cavallo della linea di cresta.
    pezzi.append(bx("OF_Colmo", -0.22, 0.22, y0, y1, H_COLMO - 0.02,
                    H_COLMO + 0.12, P["zinco"]))
    # Gronda e pluviali: due righe verticali ai lati, e dicono "capannone"
    # quanto la lamiera.
    pezzi.append(bx("OF_Gronda", -xe, xe, y0 - 0.10, y0 + 0.04,
                    zg - 0.16, zg - 0.02, P["zinco"]))
    for x in (-xe + 0.14, xe - 0.14):
        pezzi.append(cilindro("OF_Pluviale%.2f" % x,
                              (x, y0 - 0.03, (H_MURO - 0.2) / 2.0),
                              0.055, H_MURO - 0.2, P["zinco"], lati=8))
    # Torrino di sfiato sul colmo, con le feritoie. Sta avanti sul colmo: piu'
    # indietro, a 27 gradi, finirebbe sopra la sagoma del tetto e si leggerebbe
    # come una scatola che vola.
    ty = 1.15
    pezzi.append(bx("OF_Torrino", -3.30, -2.30, ty, ty + 0.85,
                    H_COLMO - 0.75, H_COLMO + 0.58, P["zinco"]))
    pezzi.append(bx("OF_Torrino_Tetto", -3.44, -2.16, ty - 0.10, ty + 0.95,
                    H_COLMO + 0.58, H_COLMO + 0.70, P["lamiera"]))
    for i in range(3):
        z = H_COLMO + 0.06 + i * 0.15
        pezzi.append(bx("OF_Torrino_Fer%d" % i, -3.20, -2.40, ty - 0.03, ty,
                        z, z + 0.07, P["ferro"]))


def corpo(pezzi):
    """Il volume dietro alla facciata e il piazzale davanti."""
    x0, x1 = -W / 2.0, W / 2.0
    # Il pieno comincia DIETRO al fondo dell'officina, non subito dietro alla
    # facciata: con la serranda su si deve vedere dentro, e un blocco pieno
    # dietro al portone si legge come un pannello grigio invece che come un
    # capannone. Davanti al fondo resta il vuoto, che e' l'officina.
    pezzi.append(bx("OF_Corpo", x0, x1, INT_FONDO, D, 0.0, H_MURO,
                    P["muro_lato"]))
    for xa, xb in ((x0, x0 + 0.34), (x1 - 0.34, x1)):
        pezzi.append(bx("OF_Fianco%.2f" % xa, xa, xb, SP, INT_FONDO, 0.0,
                        H_MURO, P["muro_lato"]))
    punti = [(x0, D, H_MURO), (x1, D, H_MURO), (0.0, D, H_COLMO)]
    pezzi.append(poligono("OF_Timpano_Retro", punti, [(0, 1, 2)],
                          P["muro_lato"]))
    # Il piazzale: una lastra sottile davanti, larga quanto l'edificio. Niente
    # pompe, cassonetti, auto: quelli li piazza il gioco.
    pezzi.append(bx("OF_Piazzale", x0, x1, -2.70, 0.0, -0.14, -0.02,
                    P["cemento"]))
    # Paletti rossi davanti al portone: sono di questo edificio, non arredo
    # urbano — stanno a proteggere gli stipiti del portone.
    for x in (SER_X0 - 0.42, SER_X1 + 0.42):
        pezzi.append(cilindro("OF_Paletto%.2f" % x, (x, -0.38, 0.45), 0.115,
                              0.90, P["rosso"], lati=12))
        pezzi.append(cilindro("OF_Paletto_Fascia%.2f" % x, (x, -0.38, 0.72),
                              0.12, 0.10, P["insegna"], lati=12))


# ----------------------------------------------------------------------
#  scena, luci, camera
# ----------------------------------------------------------------------

def scena():
    sc = bpy.context.scene
    sc.unit_settings.system = "METRIC"

    dati = bpy.data.cameras.new("CAM_Front")
    dati.type = "ORTHO"
    dati.clip_start, dati.clip_end = 0.1, 500.0
    cam = bpy.data.objects.new("CAM_Front", dati)
    sc.collection.objects.link(cam)
    # Solo rotazione X: nessuna imbardata, la facciata resta dritta.
    cam.rotation_euler = (math.radians(90.0 - INCLINAZIONE), 0.0, 0.0)
    sc.camera = cam

    sole = bpy.data.lights.new("SUN", type="SUN")
    sole.energy = 3.4
    sole.color = (1.0, 0.95, 0.88)
    sole.angle = math.radians(1.0)
    ob = bpy.data.objects.new("SUN", sole)
    sc.collection.objects.link(ob)
    ob.rotation_euler = (math.radians(58), 0.0, math.radians(-46))

    riemp = bpy.data.lights.new("FILL", type="SUN")
    riemp.energy = 0.95
    riemp.color = (0.70, 0.78, 0.94)
    riemp.angle = math.radians(30)
    ob = bpy.data.objects.new("FILL", riemp)
    sc.collection.objects.link(ob)
    ob.rotation_euler = (math.radians(108), 0.0, math.radians(30))

    mondo = bpy.data.worlds.new("World")
    sc.world = mondo
    mondo.use_nodes = True
    N, L = mondo.node_tree.nodes, mondo.node_tree.links
    N.clear()
    uscita = N.new("ShaderNodeOutputWorld")
    sfondo = N.new("ShaderNodeBackground")
    sfondo.inputs["Color"].default_value = srgb("#8FA3B6")
    _set(sfondo, "Strength", 0.95)
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
    # Standard e non AgX: AgX sbiadisce i colori piatti, e a questa scala il
    # rosso dello zoccolo diventerebbe rosa.
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
    # 3,2 e non 6,5: lo spessore si tara sulla densita' di dettaglio del
    # modello. Con una finestra alta trentacinque pixel e i suoi montanti, una
    # linea da 6,5 si mangia la finestra.
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
    """Stringe l'inquadratura sull'ingombro vero, in spazio camera.

    Sui VERTICI e non sul bound box: il riquadro di un oggetto e' allineato
    agli assi, e con la camera inclinata i suoi spigoli finti — "il piazzale
    davanti all'altezza del colmo" — stanno piu' in alto di qualunque pezzo
    vero, e l'edificio si porterebbe dietro un metro di cielo vuoto.
    """
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
        ((minx + maxx) / 2.0, (miny + maxy) / 2.0, 120.0))
    cam.data.ortho_scale = max(larg, alt)
    sc = bpy.context.scene
    sc.render.resolution_x = int(round(larg * PX_PER_METRO))
    sc.render.resolution_y = int(round(alt * PX_PER_METRO))
    return larg, alt


def modo_luci():
    """Riduce la scena a quello che di notte resta acceso.

    Stessa logica di `render_buildings.modo_luci()`: di notte il
    `CanvasModulate` della citta' moltiplica lo sprite per il blu della sera, e
    una finestra dipinta gialla viene fuori marrone. Il secondo scatto e' lo
    stesso edificio, stessa camera e stessa inquadratura, con dentro solo cio'
    che il modello dichiara gia' emissivo, su fondo nero.
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
        bsdf = next((n for n in mat.node_tree.nodes
                     if n.type == "BSDF_PRINCIPLED"), None)
        acceso = None
        if bsdf is not None and "Emission Strength" in bsdf.inputs:
            forza = float(bsdf.inputs["Emission Strength"].default_value)
            if forza > 0.001 and "Emission Color" in bsdf.inputs:
                acceso = tuple(bsdf.inputs["Emission Color"].default_value)
        N, L = mat.node_tree.nodes, mat.node_tree.links
        N.clear()
        uscita = N.new("ShaderNodeOutputMaterial")
        if acceso is None:
            nero = N.new("ShaderNodeBsdfDiffuse")
            nero.inputs["Color"].default_value = (0.0, 0.0, 0.0, 1.0)
            L.new(nero.outputs[0], uscita.inputs["Surface"])
        else:
            luce = N.new("ShaderNodeEmission")
            luce.inputs["Color"].default_value = acceso
            luce.inputs["Strength"].default_value = 1.0
            L.new(luce.outputs[0], uscita.inputs["Surface"])


# ----------------------------------------------------------------------
#  costruzione e render
# ----------------------------------------------------------------------

def apri(telo, barra, quanto):
    """Mette la serranda a `quanto` di apertura: 0 tutta giu', 1 tutta su.

    Il telo si accorcia dall'alto: il bordo di sopra resta appeso al
    cassonetto e quello di sotto sale. Si fa scalando l'oggetto, ed e' il
    motivo per cui le doghe sono prese dalla posizione nel MONDO e non
    dall'oggetto: scalate insieme a lui diventerebbero di gomma.
    """
    piena = SER_Z1 - SER_Z0
    visibile = max(SER_ROTOLO, piena * (1.0 - quanto))
    zb = SER_Z1 - visibile
    telo.scale.z = visibile / piena
    telo.location.z = (SER_Z1 + zb) / 2.0 - (SER_Z1 + SER_Z0) / 2.0
    barra.location.z = zb - SER_Z0 + 0.07
    # La barra sparisce dentro al cassonetto quando e' tutta su.
    barra.hide_render = quanto > 0.97


def costruisci():
    """Costruisce l'officina. Torna (telo, barra) per animare la serranda."""
    pulisci()
    palette()
    collezione(COLL_TESTI)
    pezzi = []
    corpo(pezzi)
    interno(pezzi)
    facciata(pezzi)
    cartellone(pezzi)
    tetto(pezzi)
    lampada("OF_Lampada_Insegna", 1.15, H_MURO + 0.62, pezzi, braccio=0.66)
    lampada("OF_Lampada_Porta", -3.0, 3.05, pezzi)
    lampada("OF_Lampada_Dx", 4.3, 3.35, pezzi)
    hood, telo, barra = serranda()
    pezzi.append(hood)
    unisci(pezzi, "OFFICINA")
    cam = scena()
    apri(telo, barra, 0.0)
    misure = inquadra(cam)
    return telo, barra, misure


def renderizza(cartella=None, fotogrammi=FOTOGRAMMI):
    """La striscia dei fotogrammi piu' lo scatto delle luci.

    Fotogramma 0 = serranda tutta su (officina aperta), ultimo = tutta giu'.
    L'inquadratura si calcola UNA volta, a serranda chiusa: se cambiasse fra un
    fotogramma e l'altro l'edificio ballerebbe mentre la serranda scende.
    """
    if cartella is None:
        cartella = os.path.abspath(os.path.join(
            os.path.dirname(os.path.abspath(__file__)), os.pardir, "assets",
            "sprites", "buildings", "_source"))
    os.makedirs(cartella, exist_ok=True)
    telo, barra, _ = costruisci()
    sc = bpy.context.scene
    sc.render.resolution_percentage = SUPERSAMPLING * 100
    for k in range(fotogrammi):
        quanto = 1.0 - k / float(fotogrammi - 1)
        apri(telo, barra, quanto)
        sc.render.filepath = os.path.join(cartella,
                                          "render_officina_%02d.png" % k)
        bpy.ops.render.render(write_still=True)
    # Le luci: serranda chiusa, perche' di notte l'officina e' chiusa.
    apri(telo, barra, 0.0)
    modo_luci()
    sc.render.filepath = os.path.join(cartella, "luci_officina.png")
    bpy.ops.render.render(write_still=True)
    return fotogrammi, sc.render.resolution_x, sc.render.resolution_y


if __name__ == "__main__":
    print("OFFICINA", costruisci()[2])
