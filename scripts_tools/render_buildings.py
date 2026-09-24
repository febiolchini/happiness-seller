"""Costruisce gli edifici del quartiere povero in Blender e li renderizza.

Il gioco disegna gli edifici visti di fronte e dall'alto: la facciata e' dritta
e si affaccia su una strada orizzontale, il tetto si vede in scorcio. In Blender
e' una camera ortografica ruotata solo sull'asse X, senza imbardata — se si
ruota anche di yaw la facciata va in prospettiva e le case smettono di allinearsi
tra loro lungo la strada.

L'inclinazione e' 27 gradi sull'orizzonte. E' il punto di equilibrio: sotto i 20
il tetto sparisce e l'edificio sembra un fondale piatto, sopra i 35 il tetto si
mangia un quarto dello sprite e i piani si schiacciano.

**Niente verde nei modelli.** Cespugli, rovi ed erbacce li piazza il gioco, non
il modello: qui davanti a casa e in fondo al cortile del condominio c'erano
quarantotto scatole di `QP_Erbaccia`, messe a caso da un `random` e ruotate a
caso, e alla scala dello sprite non si leggevano come rovi — si leggevano per
quello che erano, dei cubi grigioverdi sparsi davanti agli edifici. Un
cespuglio fatto di scatole e' un segnaposto, e un segnaposto dentro a un
disegno finito e' la cosa che si nota per prima. Lo stesso vale per alberi,
siepi e arredo urbano: vedi la nota in `clinica_base()`.

**E niente marciapiede** (2026-09-21). Ogni edificio di schiera si portava
dentro allo sprite una lastra di marciapiede profonda 2,70 m, e il magazzino
una di 1,70: servivano ad appoggiare l'edificio e a dare a tutti lo stesso
bordo inferiore. Sono uscite tutte, ed e' la stessa regola del verde applicata
al suolo — **quello che sta a terra e' citta', non edificio.**

Tre cose che non tornavano:

1. **Erano un secondo marciapiede.** Quello vero lo disegna `city_ground.gd`
   lungo ogni strada, col suo grigio; la lastra ne aveva uno suo, appoggiato
   sopra. Il bordo fra i due si vedeva, ed essendo dentro a un PNG non c'era
   modo di farli combaciare una volta per tutte.
2. **Falsavano la riga di terra.** Il bordo inferiore dello sprite era la
   lastra e non il muro, cioe' un metro e mezzo piu' AVANTI. Siccome `offset`
   si calcola sul PNG, l'edificio finiva disegnato qualche pixel sotto alla
   sua quota, e il `click` in `city_map.gd` andava accorciato a mano per non
   far risultare l'edificio appoggiato sul marciapiede su cui si cammina
   (c'e' ancora la nota, sul magazzino).
3. **Il gioco ci deve camminare sopra.** Il marciapiede e' terreno a costo 1,0
   nella griglia di `city_navigation.gd`: e' un dato, non un disegno.

Cosa NON e' marciapiede e resta dov'e': il cortile recintato del condominio e
della casa (`lotto()`, `casa_lotto()`) e il piazzale della clinica
(`clinica_base()`). Quelli sono il LOTTO dell'edificio, stanno dentro alla sua
recinzione o ai suoi pilastri, e non hanno niente a che fare con la strada.

**Perche' generare invece di modellare.** Il quartiere deve avere edifici diversi
ma riconoscibilmente dello stesso posto. Modellandoli a mano la coerenza e' una
questione di disciplina e si perde al terzo edificio; generandoli dalla stessa
palette e dalle stesse regole la coerenza e' una proprieta' del codice. Un
edificio nuovo e' una voce in `EDIFICI`, non un file .blend nuovo.

**Dove finisce il render.** Non direttamente in `assets/sprites/buildings/`, ma
in `_source/` alla risoluzione piena, come i disegni. Il ridimensionamento alla
taglia di gioco lo fa `import_flats_art.py`, che sa gia' premoltiplicare l'alpha
e ritagliare il margine: una sola implementazione della riduzione, non due che
divergono.

**Due scatti per edificio.** `render_<nome>.png` e' l'edificio, `luci_<nome>.png`
e' quello che di notte resta acceso: stessa camera, stessa inquadratura, fondo
nero e dentro solo le finestre illuminate. Serve perche' uno sprite di notte si
spegne insieme a tutta la tela, e le finestre accese no — vedi `modo_luci()` qui
sotto e `building_lights.gd` dal lato del gioco.

Uso:
  blender --background --python scripts_tools/render_buildings.py
  python scripts_tools/import_flats_art.py
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(bpy.data.filepath or sys.argv[0]))
if not os.path.basename(HERE) == "scripts_tools":
    HERE = os.path.join(os.getcwd(), "scripts_tools")
OUT = os.path.abspath(os.path.join(
    HERE, os.pardir, "assets", "sprites", "buildings", "_source"))

# Moltiplicatore di risoluzione del render rispetto allo sprite finale. A 1x le
# ringhiere dei balconi, che a schermo sono alte tre pixel, escono a scalini;
# renderizzare a 4x e ridurre dopo le fa arrivare come una sfumatura continua.
SUPERSAMPLING = 4


# ----------------------------------------------------------------------
#  colore
# ----------------------------------------------------------------------

def srgb(hexstr, alpha=1.0):
    """Da esadecimale a lineare: i socket colore di Blender vogliono lineare.

    Scriverci dentro il valore sRGB fa uscire tutto slavato di uno stop buono.
    """
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


def _fresh(name):
    old = bpy.data.materials.get(name)
    if old:
        bpy.data.materials.remove(old)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    return mat


def piatto(name, hexcol, rough=0.90, metal=0.0, emissivo=None, forza=0.0):
    mat = _fresh(name)
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    _set(bsdf, "Base Color", srgb(hexcol))
    _set(bsdf, "Roughness", rough)
    _set(bsdf, "Metallic", metal)
    if emissivo:
        _set(bsdf, "Emission Color", srgb(emissivo))
        _set(bsdf, "Emission Strength", forza)
    return mat


# ----------------------------------------------------------------------
#  intonaco scrostato (shader procedurale)
# ----------------------------------------------------------------------

def intonaco(name, muro, sotto, sporco, seme=0.0,
             chiazze=2.4, chiazza_da=0.535, chiazza_a=0.572,
             zone=0.19, zona_da=0.45, zona_a=0.68,
             colature=0.66, base_h=3.6, base_max=0.34):
    """Intonaco marrone con scrostature, colature e sporco alla base.

    Due accortezze, senza le quali viene finto in modo poco ovvio:

    - **Le scrostature vanno raggruppate.** Una sola maschera di rumore le
      sparpaglia uniformemente e il muro sembra mimetico. Serve una seconda
      maschera a grana grossa che dica *dove* l'intonaco cade, moltiplicata per
      la prima che dice *che forma* ha: l'intonaco si stacca a zone, dove piove
      e dove il muro e' gia' andato.

    - **Il cemento sotto dev'essere vicino di tono al muro.** Se e' molto piu'
      chiaro le chiazze diventano nuvole bianche che si leggono prima del resto.

    Lo sporco alla base usa la Z in **coordinate oggetto**: l'origine dell'oggetto
    deve stare a (0,0,0), altrimenti il gradiente parte da meta' edificio e
    annerisce la parte bassa tutta insieme.
    """
    mat = _fresh(name)
    tree = mat.node_tree
    N, L = tree.nodes, tree.links
    N.clear()

    out = N.new("ShaderNodeOutputMaterial")
    out.location = (1700, 0)
    bsdf = N.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (1420, 0)
    L.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    coord = N.new("ShaderNodeTexCoord")
    coord.location = (-1700, 0)

    def mescola(x, y, modo="MIX"):
        n = N.new("ShaderNodeMix")
        n.location = (x, y)
        n.data_type = "RGBA"
        n.blend_type = modo
        n.clamp_factor = True
        colori = [s for s in n.inputs if s.type == "RGBA"]
        return n, n.inputs[0], colori[0], colori[1], \
            [s for s in n.outputs if s.type == "RGBA"][0]

    def maschera(x, y, scala_map, scala, dettaglio, distorsione,
                 da, a, offset=(0, 0, 0), interp="LINEAR"):
        mapping = N.new("ShaderNodeMapping")
        mapping.location = (x, y)
        _set(mapping, "Scale", scala_map)
        _set(mapping, "Location", offset)
        L.new(coord.outputs["Object"], mapping.inputs["Vector"])
        noise = N.new("ShaderNodeTexNoise")
        noise.location = (x + 200, y)
        _set(noise, "Scale", scala)
        _set(noise, "Detail", dettaglio)
        _set(noise, "Roughness", 0.52)
        _set(noise, "Distortion", distorsione)
        L.new(mapping.outputs["Vector"], noise.inputs["Vector"])
        ramp = N.new("ShaderNodeValToRGB")
        ramp.location = (x + 390, y)
        ramp.color_ramp.interpolation = interp
        ramp.color_ramp.elements[0].position = da
        ramp.color_ramp.elements[1].position = a
        L.new(noise.outputs["Fac"], ramp.inputs["Fac"])
        return ramp

    forma = maschera(-1550, 460, (1, 1, 1), chiazze, 15.0, 0.6,
                     chiazza_da, chiazza_a,
                     (seme * 7.3, seme * 3.1, seme * 5.7))
    dove = maschera(-1550, 180, (1, 1, 0.5), zone, 3.0, 0.25,
                    zona_da, zona_a, (seme * 1.7, seme * 2.9, 0), "EASE")
    scrostato = N.new("ShaderNodeMath")
    scrostato.location = (-1050, 320)
    scrostato.operation = "MULTIPLY"
    L.new(forma.outputs["Color"], scrostato.inputs[0])
    L.new(dove.outputs["Color"], scrostato.inputs[1])

    # Z schiacciata nel mapping: il rumore si stira in verticale e diventa colatura
    strisce = maschera(-1550, -100, (2.2, 2.2, 0.16), 2.0, 9.0, 0.35, 0.44, 0.82,
                       (seme * 2.2, seme * 4.4, 0), "EASE")
    quanto = N.new("ShaderNodeMath")
    quanto.location = (-1050, -100)
    quanto.operation = "MULTIPLY"
    quanto.inputs[1].default_value = colature
    L.new(strisce.outputs["Color"], quanto.inputs[0])

    sep = N.new("ShaderNodeSeparateXYZ")
    sep.location = (-1550, -400)
    L.new(coord.outputs["Object"], sep.inputs["Vector"])
    zoccolo = N.new("ShaderNodeMapRange")
    zoccolo.location = (-1330, -400)
    zoccolo.clamp = True
    _set(zoccolo, "From Min", 0.0)
    _set(zoccolo, "From Max", base_h)
    _set(zoccolo, "To Min", base_max)
    _set(zoccolo, "To Max", 0.0)
    L.new(sep.outputs["Z"], zoccolo.inputs["Value"])

    tutto_sporco = N.new("ShaderNodeMath")
    tutto_sporco.location = (-800, -260)
    tutto_sporco.operation = "MAXIMUM"
    L.new(quanto.outputs["Value"], tutto_sporco.inputs[0])
    L.new(zoccolo.outputs["Result"], tutto_sporco.inputs[1])

    tono = maschera(-1550, 760, (0.26, 0.26, 0.15), 1.0, 5.0, 0.3,
                    0.30, 0.72, (0, 0, 0), "EASE")
    tono.color_ramp.elements[0].color = (0.74, 0.74, 0.77, 1.0)
    tono.color_ramp.elements[1].color = (1.20, 1.18, 1.12, 1.0)

    c_muro = N.new("ShaderNodeRGB")
    c_muro.location = (-800, 660)
    c_muro.outputs[0].default_value = srgb(muro)
    c_sotto = N.new("ShaderNodeRGB")
    c_sotto.location = (-800, 520)
    c_sotto.outputs[0].default_value = srgb(sotto)
    c_sporco = N.new("ShaderNodeRGB")
    c_sporco.location = (-800, -520)
    c_sporco.outputs[0].default_value = srgb(sporco)

    _, f0, a0, b0, variato = mescola(-560, 720, "MULTIPLY")
    f0.default_value = 1.0
    L.new(c_muro.outputs[0], a0)
    L.new(tono.outputs["Color"], b0)

    _, f1, a1, b1, con_chiazze = mescola(-300, 520)
    L.new(scrostato.outputs["Value"], f1)
    L.new(variato, a1)
    L.new(c_sotto.outputs[0], b1)

    _, f2, a2, b2, con_sporco = mescola(0, 280)
    L.new(tutto_sporco.outputs["Value"], f2)
    L.new(con_chiazze, a2)
    L.new(c_sporco.outputs[0], b2)

    # L'occlusione ambientale fa il lavoro che a mano sarebbe una texture per
    # edificio: annerisce da sola sotto i davanzali, dentro le nicchie delle
    # finestre e sotto le solette dei balconi, cioe' dove lo sporco si deposita.
    finale = con_sporco
    ao = N.new("ShaderNodeAmbientOcclusion")
    ao.location = (0, -40)
    ao.samples = 8
    ao.only_local = True
    _set(ao, "Distance", 1.3)
    scala_ao = N.new("ShaderNodeMapRange")
    scala_ao.location = (260, -40)
    scala_ao.clamp = True
    _set(scala_ao, "From Min", 0.0)
    _set(scala_ao, "From Max", 1.0)
    _set(scala_ao, "To Min", 0.46)
    _set(scala_ao, "To Max", 1.0)
    L.new(ao.outputs["AO"], scala_ao.inputs["Value"])
    _, f3, a3, b3, con_ao = mescola(560, 200, "MULTIPLY")
    f3.default_value = 1.0
    L.new(con_sporco, a3)
    L.new(scala_ao.outputs["Result"], b3)
    finale = con_ao
    L.new(finale, bsdf.inputs["Base Color"])

    grana = N.new("ShaderNodeTexNoise")
    grana.location = (560, -620)
    _set(grana, "Scale", 55.0)
    _set(grana, "Detail", 5.0)
    L.new(coord.outputs["Object"], grana.inputs["Vector"])
    rilievo = N.new("ShaderNodeBump")
    rilievo.location = (800, -460)
    _set(rilievo, "Strength", 0.34)
    _set(rilievo, "Distance", 0.05)
    L.new(scrostato.outputs["Value"], rilievo.inputs["Height"])
    rugosita = N.new("ShaderNodeBump")
    rugosita.location = (1020, -620)
    _set(rugosita, "Strength", 0.20)
    _set(rugosita, "Distance", 0.04)
    L.new(grana.outputs["Fac"], rugosita.inputs["Height"])
    L.new(rilievo.outputs["Normal"], rugosita.inputs["Normal"])
    L.new(rugosita.outputs["Normal"], bsdf.inputs["Normal"])

    _, f4, a4, b4, ruvido = mescola(1020, -200)
    a4.default_value = (0.84, 0.84, 0.84, 1.0)
    b4.default_value = (0.97, 0.97, 0.97, 1.0)
    L.new(scrostato.outputs["Value"], f4)
    L.new(ruvido, bsdf.inputs["Roughness"])
    _set(bsdf, "Metallic", 0.0)
    return mat


def tapparella(name, chiaro, scuro, passo=0.075):
    """Tapparella a doghe: rettangoli di colore piatto si leggono come cartone.

    Le doghe vengono dalla Z in coordinate oggetto passata per FRACT, non da una
    texture: cosi' restano alte uguali su tutte le finestre dell'edificio anche
    dopo aver unito le mesh in un oggetto solo.
    """
    mat = _fresh(name)
    tree = mat.node_tree
    N, L = tree.nodes, tree.links
    N.clear()
    out = N.new("ShaderNodeOutputMaterial")
    out.location = (700, 0)
    bsdf = N.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (450, 0)
    L.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    coord = N.new("ShaderNodeTexCoord")
    coord.location = (-700, 0)
    sep = N.new("ShaderNodeSeparateXYZ")
    sep.location = (-500, 0)
    L.new(coord.outputs["Object"], sep.inputs["Vector"])
    per = N.new("ShaderNodeMath")
    per.location = (-320, 0)
    per.operation = "MULTIPLY"
    per.inputs[1].default_value = 1.0 / passo
    L.new(sep.outputs["Z"], per.inputs[0])
    frac = N.new("ShaderNodeMath")
    frac.location = (-150, 0)
    frac.operation = "FRACT"
    L.new(per.outputs["Value"], frac.inputs[0])
    ramp = N.new("ShaderNodeValToRGB")
    ramp.location = (20, 0)
    ramp.color_ramp.interpolation = "B_SPLINE"
    ramp.color_ramp.elements[0].position = 0.10
    ramp.color_ramp.elements[1].position = 0.35
    L.new(frac.outputs["Value"], ramp.inputs["Fac"])
    mix = N.new("ShaderNodeMix")
    mix.location = (250, 120)
    mix.data_type = "RGBA"
    mix.blend_type = "MIX"
    colori = [s for s in mix.inputs if s.type == "RGBA"]
    colori[0].default_value = srgb(chiaro)
    colori[1].default_value = srgb(scuro)
    L.new(ramp.outputs["Color"], mix.inputs[0])
    L.new([s for s in mix.outputs if s.type == "RGBA"][0], bsdf.inputs["Base Color"])
    bump = N.new("ShaderNodeBump")
    bump.location = (250, -250)
    _set(bump, "Strength", 0.55)
    _set(bump, "Distance", 0.02)
    L.new(ramp.outputs["Color"], bump.inputs["Height"])
    L.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    _set(bsdf, "Roughness", 0.78)
    return mat


def righe(name, chiaro, scuro, passo, sporco=None, macchie=0.45,
          rilievo=0.55, rough=0.86, grana=0.0):
    """Materiale a righe orizzontali ricavate dalla Z in coordinate oggetto.

    Serve per tutto quello che nel quartiere e' fatto di corsi sovrapposti:
    l'assito di legno delle case, i corsi di tegole, i mattoni del camino. Le
    righe vengono da FRACT sulla Z e non da una texture, cosi' restano allineate
    e alte uguali anche dopo aver unito le mesh in un oggetto solo — e su una
    falda inclinata diventano da sole i corsi di tegole, che seguono la pendenza.

    `sporco` aggiunge una seconda passata di macchie: senza, il legno verniciato
    e' un grigio uniforme che a 150 px si legge come plastica.
    """
    mat = _fresh(name)
    tree = mat.node_tree
    N, L = tree.nodes, tree.links
    N.clear()
    out = N.new("ShaderNodeOutputMaterial")
    out.location = (900, 0)
    bsdf = N.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (640, 0)
    L.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    coord = N.new("ShaderNodeTexCoord")
    coord.location = (-900, 0)

    sep = N.new("ShaderNodeSeparateXYZ")
    sep.location = (-700, 0)
    L.new(coord.outputs["Object"], sep.inputs["Vector"])
    per = N.new("ShaderNodeMath")
    per.location = (-520, 0)
    per.operation = "MULTIPLY"
    per.inputs[1].default_value = 1.0 / passo
    L.new(sep.outputs["Z"], per.inputs[0])
    frac = N.new("ShaderNodeMath")
    frac.location = (-350, 0)
    frac.operation = "FRACT"
    L.new(per.outputs["Value"], frac.inputs[0])
    ramp = N.new("ShaderNodeValToRGB")
    ramp.location = (-180, 0)
    ramp.color_ramp.interpolation = "B_SPLINE"
    ramp.color_ramp.elements[0].position = 0.08
    ramp.color_ramp.elements[1].position = 0.30
    L.new(frac.outputs["Value"], ramp.inputs["Fac"])

    def mescola(x, y, modo="MIX"):
        n = N.new("ShaderNodeMix")
        n.location = (x, y)
        n.data_type = "RGBA"
        n.blend_type = modo
        n.clamp_factor = True
        col = [s for s in n.inputs if s.type == "RGBA"]
        return n, n.inputs[0], col[0], col[1], \
            [s for s in n.outputs if s.type == "RGBA"][0]

    _, f0, a0, b0, corsi = mescola(60, 140)
    a0.default_value = srgb(chiaro)
    b0.default_value = srgb(scuro)
    L.new(ramp.outputs["Color"], f0)

    colore = corsi
    if sporco:
        chiazze = N.new("ShaderNodeTexNoise")
        chiazze.location = (60, -140)
        _set(chiazze, "Scale", 1.8)
        _set(chiazze, "Detail", 8.0)
        _set(chiazze, "Roughness", 0.6)
        _set(chiazze, "Distortion", 0.4)
        L.new(coord.outputs["Object"], chiazze.inputs["Vector"])
        taglia = N.new("ShaderNodeValToRGB")
        taglia.location = (250, -140)
        taglia.color_ramp.elements[0].position = 0.46
        taglia.color_ramp.elements[1].position = 0.46 + macchie
        L.new(chiazze.outputs["Fac"], taglia.inputs["Fac"])
        _, f1, a1, b1, sporcato = mescola(430, 0)
        L.new(taglia.outputs["Color"], f1)
        L.new(corsi, a1)
        b1.default_value = srgb(sporco)
        colore = sporcato
    L.new(colore, bsdf.inputs["Base Color"])

    bump = N.new("ShaderNodeBump")
    bump.location = (430, -360)
    _set(bump, "Strength", rilievo)
    _set(bump, "Distance", 0.03)
    L.new(ramp.outputs["Color"], bump.inputs["Height"])
    if grana > 0.0:
        fine = N.new("ShaderNodeTexNoise")
        fine.location = (250, -520)
        _set(fine, "Scale", 60.0)
        _set(fine, "Detail", 4.0)
        L.new(coord.outputs["Object"], fine.inputs["Vector"])
        bump2 = N.new("ShaderNodeBump")
        bump2.location = (640, -420)
        _set(bump2, "Strength", grana)
        _set(bump2, "Distance", 0.02)
        L.new(fine.outputs["Fac"], bump2.inputs["Height"])
        L.new(bump.outputs["Normal"], bump2.inputs["Normal"])
        L.new(bump2.outputs["Normal"], bsdf.inputs["Normal"])
    else:
        L.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    _set(bsdf, "Roughness", rough)
    return mat


def palette():
    """La tavolozza del quartiere povero. Tutti i materiali hanno prefisso QP_.

    E' il pezzo che tiene insieme il quartiere: gli edifici cambiano forma e
    dimensioni, ma pescano gli stessi materiali. Un quartiere nuovo e' una
    palette nuova, non uno stile nuovo per ogni edificio.
    """
    intonaco("QP_Intonaco_Marrone_A", "#8E6C48", "#867B6D", "#4A392B", seme=0.0)
    intonaco("QP_Intonaco_Marrone_B", "#7E6242", "#7C7264", "#413124",
             seme=3.0, chiazze=2.9)
    intonaco("QP_Intonaco_Laterale", "#886849", "#827768", "#453629",
             seme=7.0, zona_da=0.44, zona_a=0.68, colature=0.78, base_h=4.2)

    tapparella("QP_Tapparella", "#9A6B49", "#7E563A")
    tapparella("QP_Tapparella_B", "#8A7259", "#6E5A45")
    tapparella("QP_Tapparella_C", "#7E6552", "#645040")

    piatto("QP_Cemento", "#8E877C", 0.92)
    piatto("QP_Cemento_Scuro", "#6E6960", 0.94)
    piatto("QP_Guaina", "#5C564C", 0.95)
    piatto("QP_Vetro_Scuro", "#101316", 0.12, 0.25)
    piatto("QP_Vetro_Rotto", "#07090A", 0.55)
    piatto("QP_Vetro_Acceso", "#4A3C2A", 0.25, emissivo="#D8A868", forza=1.25)
    piatto("QP_Infisso", "#A09686", 0.76)
    piatto("QP_Metallo_Ruggine", "#6B5040", 0.80, 0.35)
    piatto("QP_Serranda", "#5A5C58", 0.70, 0.30)
    piatto("QP_Murato", "#78695A", 0.95)
    piatto("QP_Legno_Vecchio", "#6A5843", 0.92)
    piatto("QP_Panni_Stesi", "#B8B0A0", 0.94)
    piatto("QP_Pannello_Rosso", "#8E4A3A", 0.86)
    piatto("QP_Pannello_Blu", "#45677D", 0.86)
    piatto("QP_Pannello_Ocra", "#A0834F", 0.86)
    piatto("QP_Pannello_Verde", "#566B4F", 0.86)
    piatto("QP_Suolo_Lotto", "#6E6555", 0.96)
    piatto("QP_Cassonetto", "#47624B", 0.72)
    piatto("QP_Bidone", "#4A4236", 0.78)
    piatto("QP_Sacco", "#2E2B28", 0.85)
    piatto("QP_Barile", "#7A3A2C", 0.74, 0.30)
    piatto("QP_Lamiera", "#75766F", 0.66, 0.40)

    # --- roba da casa di legno ---------------------------------------------
    # L'assito e' il carattere della casa americana povera: tavole orizzontali
    # verniciate una volta sola, tanti anni fa. Il passo e' 18 cm, che a 8 px/m
    # fa una riga ogni px e mezzo: si legge come tessitura, non come righe.
    righe("QP_Assito", "#CBC6B8", "#A49E8E", 0.18, sporco="#9A9080",
          macchie=0.38, rilievo=0.60, rough=0.88, grana=0.22)
    righe("QP_Assito_Portico", "#A79F8E", "#7F7867", 0.18, sporco="#7E7260",
          macchie=0.45, rilievo=0.60, rough=0.90, grana=0.20)
    # Il verde dei bordi del tetto e del frontone: nella casa di riferimento e'
    # l'unico colore forte su tutta la facciata bianca, ed e' quello che la fa
    # riconoscere da lontano piu' della sagoma.
    piatto("QP_Verde_Trim", "#3C5C42", 0.82)
    piatto("QP_Verde_Trim_Scuro", "#2E4733", 0.84)
    # I pilastri del portico sono di mattoni a vista, non di legno dipinto:
    # e' il dettaglio che distingue questa casa da una baracca.
    righe("QP_Mattone_Portico", "#9A5B42", "#78412F", 0.10, sporco="#8A7A66",
          macchie=0.30, rilievo=0.80, rough=0.92)
    # La fascia decorata sotto il piano del portico: mattonelle a rombi gialle.
    righe("QP_Decoro", "#C6A24E", "#8E6B33", 0.12, sporco="#A8853F",
          macchie=0.50, rilievo=0.70, rough=0.88)

    # --- roba da bottega ---------------------------------------------------
    # Il vetro di una vetrina non e' quello di una finestra di casa: dietro c'e'
    # una luce accesa anche di giorno, e a 22 px/m e' quel chiarore a dire che
    # il posto e' aperto.
    piatto("QP_Vetrina", "#33393B", 0.10, 0.20, emissivo="#9FB0A8", forza=0.55)
    # Le insegne sono gli unici colori accesi del quartiere, ed e' voluto:
    # servono a distinguere un'attivita' dall'altra a colpo d'occhio, in una
    # strada dove tutto il resto e' marrone.
    piatto("QP_Insegna_Rossa", "#8E3A30", 0.72)
    piatto("QP_Insegna_Blu", "#2E5068", 0.72)
    piatto("QP_Insegna_Verde", "#3A5B40", 0.72)
    piatto("QP_Insegna_Gialla", "#A8853A", 0.72)
    piatto("QP_Insegna_Bianca", "#A7A294", 0.74)
    # Tende parasole a righe, come le fanno.
    righe("QP_Tenda_Rossa", "#9A4438", "#C8BBA6", 0.26, rilievo=0.40, rough=0.85)
    righe("QP_Tenda_Verde", "#3F6147", "#C8BBA6", 0.26, rilievo=0.40, rough=0.85)
    righe("QP_Tenda_Blu", "#3A5A72", "#C8BBA6", 0.26, rilievo=0.40, rough=0.85)
    righe("QP_Mattone_Facciata", "#8A5340", "#6C3E2E", 0.11, sporco="#7E6E5C",
          macchie=0.34, rilievo=0.78, rough=0.93)
    righe("QP_Tegole", "#5A6154", "#41473D", 0.16, sporco="#6B6353",
          macchie=0.55, rilievo=0.75, rough=0.93, grana=0.30)
    righe("QP_Mattoni", "#8A5744", "#6E4436", 0.11, sporco="#7A6A5A",
          macchie=0.35, rilievo=0.80, rough=0.94)
    piatto("QP_Compensato", "#8A7659", 0.93)
    piatto("QP_Legno_Dipinto", "#A9A292", 0.84)
    piatto("QP_Porta_Casa", "#5E6B5C", 0.80)
    piatto("QP_Zanzariera", "#3A3B38", 0.88)
    piatto("QP_Lavatrice", "#B6B4AC", 0.62)
    piatto("QP_Rete", "#7E8078", 0.70, 0.35)

    # --- roba da campo sportivo --------------------------------------------
    # Il giallo dei camminamenti della gradinata. Nella foto di riferimento e'
    # l'unica cosa colorata di tutto lo stadio, ed e' quello che fa leggere il
    # cemento come gradinata invece che come un muro a scaloni.
    piatto("QP_Vernice_Gialla", "#B8933A", 0.80)
    # Zincato: pali della torre faro e telai delle porte. Piu' chiaro e meno
    # caldo del metallo arrugginito, cosi' la torre stacca sul cielo.
    piatto("QP_Zincato", "#8C9096", 0.42, 0.65)
    piatto("QP_Faro_Lampada", "#C8C6BA", 0.30, 0.20)

    # --- roba della casa gialla ----------------------------------------------
    # Giallo stinto e non limone: la casa della foto e' ridipinta da anni, e
    # un giallo pieno in mezzo ai marroni del quartiere si leggerebbe come
    # un segnaposto. Lo sporco e' lo stesso dell'assito della casa bianca.
    righe("QP_Assito_Giallo", "#D9C27A", "#B49E5E", 0.18, sporco="#A69260",
          macchie=0.34, rilievo=0.60, rough=0.88, grana=0.20)
    piatto("QP_Bianco_Trim", "#E4DFD0", 0.80)
    righe("QP_Tegole_Grigie", "#6E7171", "#555858", 0.16, sporco="#6A665C",
          macchie=0.45, rilievo=0.70, rough=0.93, grana=0.25)
    piatto("QP_Infisso_Scuro", "#2A2B2A", 0.70)
    piatto("QP_Porta_Gialla", "#CFC6B0", 0.75)
    # Le tende tirate della finestrona: chiare di giorno, accese la sera.
    piatto("QP_Tende_Accese", "#BDB39C", 0.90, emissivo="#E6C890", forza=0.55)
    piatto("QP_Bandiera", "#5E2226", 0.90)
    piatto("QP_Girandola_Rossa", "#C0392B", 0.60)
    piatto("QP_Girandola_Gialla", "#E6B82E", 0.60)
    piatto("QP_Girandola_Blu", "#2E6DB4", 0.60)
    piatto("QP_Girandola_Verde", "#3E9A4A", 0.60)


def palette_qb():
    """La tavolozza del quartiere benestante. Prefisso QB_.

    Il salto di quartiere non e' un altro stile di disegno — inclinazione,
    contorni Freestyle e px/m restano quelli. E' un'altra tavolozza, e le
    differenze sono tre, tutte leggibili a duecento pixel:

    - **niente degrado.** Nel QP l'intonaco e' scrostato e il metallo
      arrugginito; qui i muri sono lavati e i materiali interi. Le stesse
      funzioni con `macchie` basso, non materiali di un'altra famiglia.
    - **chiaro e freddo invece che marrone e caldo.** Mattone giallino e
      prefabbricato bianco al posto dell'intonaco marrone.
    - **vetro pulito.** Nel QP i vetri sono neri e opachi perche' dietro non
      c'e' luce; qui sono azzurri e lisci, e l'atrio e' illuminato di giorno.
    """
    # Mattone chiaro a corsi: e' il colore dominante del corpo alto.
    righe("QB_Mattone", "#C9A377", "#A67F55", 0.085, sporco="#BB9268",
          macchie=0.16, rilievo=0.72, rough=0.86, grana=0.14)
    righe("QB_Mattone_Scuro", "#A9724F", "#8A5941", 0.085, sporco="#98684A",
          macchie=0.20, rilievo=0.72, rough=0.88, grana=0.14)
    # Il prefabbricato del corpo basso: pannelli grandi, quindi passo largo.
    # Con lo stesso passo del mattone diventerebbe un muro di mattoni bianchi.
    righe("QB_Precast", "#D2CCBE", "#BDB7A9", 0.95, sporco="#C4BEB0",
          macchie=0.12, rilievo=0.35, rough=0.80, grana=0.10)
    piatto("QB_Precast_Liscio", "#D6D0C2", 0.78)
    piatto("QB_Precast_Scuro", "#A9A396", 0.82)
    piatto("QB_Cemento", "#B4AEA2", 0.88)
    piatto("QB_Cemento_Scuro", "#8C8679", 0.90)
    piatto("QB_Guaina", "#8E8B82", 0.92)
    piatto("QB_Vetro", "#27404E", 0.08, 0.30)
    piatto("QB_Vetro_Atrio", "#33505C", 0.07, 0.20, emissivo="#CFE0DC",
           forza=0.85)
    piatto("QB_Vetro_Acceso", "#3A4A48", 0.10, emissivo="#E2D3AE", forza=1.05)
    piatto("QB_Infisso", "#3A3E40", 0.55, 0.45)
    piatto("QB_Alluminio", "#B9BCBA", 0.40, 0.70)
    piatto("QB_Metallo_Bianco", "#CFCEC6", 0.48, 0.25)
    piatto("QB_Acciaio", "#9AA0A2", 0.35, 0.80)
    # Le insegne fanno tutto il lavoro di dire cos'e' l'edificio: a questa
    # scala il testo non si legge, il colore si'.
    piatto("QB_Insegna_Bordeaux", "#8E3352", 0.62)
    piatto("QB_Insegna_Verde", "#2F6B58", 0.62)
    piatto("QB_Insegna_Bianca", "#D8D4CA", 0.68)
    piatto("QB_Insegna_Rossa", "#9E3A32", 0.64)
    # Il piazzale: asfalto pulito e cordoli interi, non terra battuta.
    piatto("QB_Asfalto", "#4E4E4C", 0.94)
    piatto("QB_Cordolo", "#BDB7AA", 0.88)
    piatto("QB_Marciapiede", "#ADA79B", 0.90)


def palette_dt():
    """La tavolozza di DOWNTOWN, la zona commerciale. Prefisso DT_.

    Terzo quartiere, terza tavolozza: inclinazione, contorni e px/m restano
    quelli di tutti gli altri edifici, cambia solo di che cosa e' fatta la
    citta' li' dentro. Le differenze rispetto al QP e al QB, tutte leggibili
    a duecento pixel:

    - **mattone rosso scuro sotto, intonaco beige sopra.** E' la divisione in
      due fasce dei capannoni commerciali americani, e da sola dice "zona
      commerciale" prima di qualunque dettaglio.
    - **niente degrado ma nemmeno pulizia da ospedale.** `macchie` a meta'
      strada fra il QP scrostato e il QB lavato: un capannone di dieci anni.
    - **vetro grande e chiaro.** Le vetrine sono portoni a pannelli alti tre
      metri, e dietro c'e' la luce del magazzino accesa anche di giorno.
    """
    # Il mattone del basamento: rosso scuro, corsi da 8,5 cm come nel QB, che
    # e' la misura vera di un mattone messo in opera.
    righe("DT_Mattone", "#8A4636", "#6B3428", 0.085, sporco="#7A4030",
          macchie=0.26, rilievo=0.76, rough=0.88, grana=0.16)
    # Il mattone chiaro delle lesene: stessa pezzatura, tono sabbia. Sono le
    # lesene a dare il ritmo alla facciata, e si vedono solo se staccano dal
    # fondo.
    righe("DT_Mattone_Chiaro", "#B08A5E", "#906E48", 0.085, sporco="#A17E54",
          macchie=0.22, rilievo=0.74, rough=0.88, grana=0.14)
    # L'intonaco sintetico della fascia alta: pannelli grandi, quindi passo
    # largo. Col passo del mattone diventerebbe un muro di mattoni beige.
    righe("DT_Intonaco", "#C6B189", "#B8A37B", 1.05, sporco="#BCA87F",
          macchie=0.15, rilievo=0.30, rough=0.84, grana=0.10)
    piatto("DT_Intonaco_Liscio", "#CAB68F", 0.82)
    # Le cornici e i capitelli: pietra ricostruita, il tono piu' chiaro della
    # facciata. E' la riga orizzontale che tiene insieme tutto il fronte.
    piatto("DT_Cornice", "#D9CDB0", 0.80)
    piatto("DT_Cornice_Scura", "#AFA488", 0.84)
    piatto("DT_Cemento", "#A8A296", 0.90)
    piatto("DT_Guaina", "#6E6A61", 0.93)
    # Il vetro dei portoni: dietro c'e' il magazzino con i neon accesi, e a
    # 22 px/m e' quel chiarore a dire che il posto e' aperto.
    piatto("DT_Vetro", "#2C4048", 0.09, 0.28, emissivo="#AFC0C4", forza=0.45)
    piatto("DT_Vetro_Ingresso", "#33484E", 0.08, 0.20, emissivo="#C2D2CE",
           forza=0.55)
    piatto("DT_Infisso", "#9AA0A2", 0.40, 0.70)
    piatto("DT_Metallo_Scuro", "#34383C", 0.52, 0.55)
    piatto("DT_Acciaio", "#8E9498", 0.38, 0.78)
    # L'insegna: campo panna e fascia blu. Il testo non e' dipinto qui sopra —
    # e' un PNG a parte (`make_signs.py`), perche' questo modello si
    # rifotografa e una scritta dipinta sparirebbe al primo re-import.
    piatto("DT_Insegna_Campo", "#E4DCC6", 0.70)
    piatto("DT_Insegna_Fascia", "#2B4C86", 0.66)
    piatto("DT_Insegna_Rossa", "#9E312C", 0.66)
    piatto("DT_Lampada", "#E8DCBE", 0.30, emissivo="#F0D8A0", forza=1.60)
    # Il piazzale. L'asfalto rosso davanti all'ingresso non e' un vezzo: e' il
    # passaggio pedonale dei magazzini all'ingrosso, ed e' l'unica macchia di
    # colore che separa l'edificio dal grigio del parcheggio.
    piatto("DT_Asfalto", "#4B4B49", 0.95)
    piatto("DT_Asfalto_Rosso", "#8E4A3C", 0.92)
    piatto("DT_Vernice", "#C6BFAB", 0.86)


# ----------------------------------------------------------------------
#  geometria
# ----------------------------------------------------------------------

M = bpy.data.materials


def box(nome, centro, misure, materiale=None, rot=None, raccolta=None):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=centro)
    obj = bpy.context.active_object
    obj.name = nome
    obj.scale = misure
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if rot:
        obj.rotation_euler = rot
    if materiale:
        obj.data.materials.append(M[materiale])
    if raccolta is not None:
        raccolta.append(obj)
    return obj


def cilindro(nome, centro, raggio, altezza, materiale=None, lati=12,
             rot=None, raccolta=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=lati, radius=raggio,
                                        depth=altezza, location=centro)
    obj = bpy.context.active_object
    obj.name = nome
    if rot:
        obj.rotation_euler = rot
    if materiale:
        obj.data.materials.append(M[materiale])
    if raccolta is not None:
        raccolta.append(obj)
    return obj


def unisci(pezzi, nome):
    """Unisce e riporta l'origine a (0,0,0).

    L'origine conta: `join` porta le mesh nello spazio dell'oggetto attivo, e
    l'intonaco legge la Z in coordinate oggetto per lo sporco alla base. Senza
    questo passaggio il gradiente parte dall'origine dell'oggetto attivo, che e'
    a meta' edificio, e annerisce tutta la parte bassa in blocco.
    """
    bpy.ops.object.select_all(action="DESELECT")
    for p in pezzi:
        p.select_set(True)
    bpy.context.view_layer.objects.active = pezzi[0]
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = nome
    bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    return obj


def pulisci():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for blocco in (bpy.data.meshes, bpy.data.materials, bpy.data.cameras,
                   bpy.data.lights):
        for item in list(blocco):
            if item.users == 0:
                blocco.remove(item)


# ----------------------------------------------------------------------
#  l'edificio
# ----------------------------------------------------------------------

# profondita' delle nicchie: le finestre non sono decal sul muro, sono buchi
# scavati col boolean. E' quello che gli da' l'ombra propria, e a 248 px l'ombra
# sotto l'architrave e' meta' di quel che fa leggere la finestra come finestra.
NICCHIA = 0.24
NICCHIA_TERRA = 0.18
SPORGENZA = 0.40


def corpo(S):
    W, D, H = S["larghezza"], S["profondita"], S["altezza"]
    yf, yb = -D / 2.0, D / 2.0
    muro = box("COND_Corpo", (0, 0, H / 2.0), (W, D, H), S["intonaco"])

    tagli = []

    def taglia(nome, cx, cz, w, h, fronte=True, prof=NICCHIA):
        cy = (yf - SPORGENZA / 2.0 + prof / 2.0) if fronte \
            else (yb + SPORGENZA / 2.0 - prof / 2.0)
        box(nome, (cx, cy, cz), (w, SPORGENZA + prof, h), raccolta=tagli)

    for piano in range(S["piani"]):
        z0 = S["h_terra"] + piano * S["h_piano"]
        for k, (_, cx, w, h, davanzale) in enumerate(S["aperture_fronte"]):
            taglia("t_f%d_%d" % (piano, k), cx, z0 + davanzale + h / 2.0, w, h, True)
        for k, (_, cx, w, h, davanzale) in enumerate(S["aperture_retro"]):
            taglia("t_b%d_%d" % (piano, k), cx, z0 + davanzale + h / 2.0, w, h, False)
    for k, (_, cx, w, h, davanzale) in enumerate(S["aperture_terra"]):
        taglia("t_g%d" % k, cx, davanzale + h / 2.0, w, h, True, NICCHIA_TERRA)
    taglia("t_gb", 0.0, 1.15, 1.10, 2.30, False, NICCHIA_TERRA)

    # Un boolean solo con tutti i cutter uniti, non uno per apertura: con
    # cinquanta modificatori in fila il solver esatto ci mette minuti e a volte
    # lascia facce degeneri agli incroci.
    cutter = unisci(tagli, "COND_Cutter")
    bpy.context.view_layer.objects.active = muro
    mod = muro.modifiers.new("Aperture", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.solver = "EXACT"
    mod.object = cutter
    bpy.ops.object.modifier_apply(modifier="Aperture")
    bpy.data.objects.remove(cutter, do_unlink=True)

    bpy.ops.object.select_all(action="DESELECT")
    muro.select_set(True)
    bpy.context.view_layer.objects.active = muro
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")

    box("COND_Cornicione", (0, 0, H - 0.275), (W + 0.62, D + 0.62, 0.45), "QP_Cemento")
    box("COND_Sottogronda", (0, 0, H - 0.53), (W + 0.30, D + 0.30, 0.12), "QP_Cemento_Scuro")
    box("COND_Zoccolo", (0, 0, 0.20), (W + 0.16, D + 0.16, 0.40), "QP_Cemento_Scuro")
    return muro


def tetto(S):
    """Il tetto non e' un dettaglio: con la camera a 27 gradi occupa un quinto
    dello sprite, e se e' vuoto l'edificio sembra un modello di prova."""
    rnd = random.Random(S["seme"] + 3)
    W, D, H = S["larghezza"], S["profondita"], S["altezza"]
    yf, yb = -D / 2.0, D / 2.0
    pezzi = []

    box("t_manto", (0, 0, H + 0.03), (W - 0.06, D - 0.06, 0.06), "QP_Guaina",
        raccolta=pezzi)
    sp = 0.22
    box("t_par_f", (0, yf + sp / 2, H + 0.24), (W, sp, 0.42), "QP_Cemento", raccolta=pezzi)
    box("t_par_b", (0, yb - sp / 2, H + 0.24), (W, sp, 0.42), "QP_Cemento", raccolta=pezzi)
    box("t_par_l", (-W / 2 + sp / 2, 0, H + 0.24), (sp, D, 0.42), "QP_Cemento", raccolta=pezzi)
    box("t_par_r", (W / 2 - sp / 2, 0, H + 0.24), (sp, D, 0.42), "QP_Cemento", raccolta=pezzi)

    vx, vy = -2.6, 1.9
    box("t_vano", (vx, vy, H + 1.30), (3.40, 2.80, 2.50), "QP_Intonaco_Marrone_B",
        raccolta=pezzi)
    box("t_vano_cap", (vx, vy, H + 2.62), (3.62, 3.02, 0.16), "QP_Cemento", raccolta=pezzi)
    box("t_vano_porta", (vx, vy - 1.42, H + 1.10), (0.95, 0.10, 2.05),
        "QP_Legno_Vecchio", raccolta=pezzi)

    for i, (cx, cy, h) in enumerate([(4.2, -2.6, 1.30), (5.0, 1.2, 1.05), (1.4, 3.2, 1.45)]):
        box("t_com%d" % i, (cx, cy, H + 0.06 + h / 2), (0.50, 0.50, h), "QP_Murato",
            raccolta=pezzi)
        box("t_comcap%d" % i, (cx, cy, H + 0.06 + h + 0.05), (0.68, 0.68, 0.10),
            "QP_Cemento", raccolta=pezzi)
    for i, (cx, cy) in enumerate([(3.9, 3.4), (-5.0, -1.4)]):
        cilindro("t_serb%d" % i, (cx, cy, H + 0.61), 0.62, 1.10, "QP_Serranda",
                 lati=14, raccolta=pezzi)
        box("t_base%d" % i, (cx, cy, H + 0.12), (1.50, 1.50, 0.12), "QP_Cemento_Scuro",
            raccolta=pezzi)
    for i, (cx, cy, h) in enumerate([(-5.2, 2.6, 2.60), (0.6, -3.4, 2.10)]):
        zb = H + 0.06
        box("t_ant%d" % i, (cx, cy, zb + h / 2), (0.07, 0.07, h), "QP_Metallo_Ruggine",
            raccolta=pezzi)
        for k in range(4):
            box("t_antb%d_%d" % (i, k), (cx, cy, zb + h - 0.25 - k * 0.30),
                (0.05, 0.75 + k * 0.18, 0.05), "QP_Metallo_Ruggine", raccolta=pezzi)
    for i, cx in enumerate([-1.2, 3.1]):
        cilindro("t_par%d" % i, (cx, yf + 0.35, H + 0.72), 0.42, 0.10, "QP_Infisso",
                 lati=16, rot=(math.radians(58), 0, 0), raccolta=pezzi)

    obj = unisci(pezzi, "COND_Tetto")
    # La guaina va assegnata dopo l'unione, cercando la faccia piana in alto:
    # e' l'unica grande faccia orizzontale a quella quota.
    guaina = [i for i, m in enumerate(obj.data.materials)
              if m and m.name == "QP_Guaina"]
    if guaina:
        for poly in obj.data.polygons:
            if H + 0.02 < poly.center.z < H + 0.09 and poly.normal.z > 0.9 \
                    and poly.area > 3.0:
                poly.material_index = guaina[0]
    _ = rnd
    return obj


def infissi(S):
    """Finestre, tapparelle, serrande. Lo stato lo decide l'occupazione del piano.

    Randomizzare finestra per finestra da' un rumore uniforme che non racconta
    niente. Decidere *per piano* se l'appartamento e' abitato produce la fascia
    di piani vivi e la fascia di piani murati, che e' come si legge davvero un
    palazzo mezzo occupato.
    """
    rnd = random.Random(S["seme"] + 1)
    D = S["profondita"]
    yf, yb = -D / 2.0, D / 2.0
    pezzi = []
    tende = ["QP_Tapparella", "QP_Tapparella_B", "QP_Tapparella_C"]

    def finestra(tag, cx, zbase, w, h, fronte, occupato, porta=False):
        verso = -1.0 if fronte else 1.0
        faccia = yf if fronte else yb
        fondo = faccia - verso * NICCHIA
        zc = zbase + h / 2.0

        def y(dal_fondo):
            return fondo + verso * dal_fondo

        r = rnd.random()
        if occupato:
            stato = "accesa" if r < 0.22 else ("rotta" if r < 0.30 else "normale")
        else:
            stato = "murata" if r < 0.38 else ("rotta" if r < 0.80 else "normale")

        if stato == "murata":
            box("mur_" + tag, (cx, y(0.09), zc), (w, 0.18, h), "QP_Murato", raccolta=pezzi)
            return

        box("tel_" + tag, (cx, y(0.035), zc), (w, 0.07, h), "QP_Infisso", raccolta=pezzi)
        vetro = {"accesa": "QP_Vetro_Acceso", "rotta": "QP_Vetro_Rotto"}.get(
            stato, "QP_Vetro_Scuro")
        box("vet_" + tag, (cx, y(0.085), zc), (w - 0.16, 0.03, h - 0.16), vetro,
            raccolta=pezzi)
        box("mon_" + tag, (cx, y(0.105), zc), (0.06, 0.04, h - 0.16), "QP_Infisso",
            raccolta=pezzi)
        if not porta:
            box("tra_" + tag, (cx, y(0.105), zc), (w - 0.16, 0.04, 0.05), "QP_Infisso",
                raccolta=pezzi)
        box("cas_" + tag, (cx, y(NICCHIA * 0.45), zbase + h - 0.11),
            (w, NICCHIA * 0.75, 0.22), "QP_Infisso", raccolta=pezzi)

        quota = rnd.choice([0.0, 0.0, 0.12, 0.25, 0.45, 0.85]) if occupato \
            else rnd.choice([0.0, 0.95, 1.0, 1.0, 0.7])
        if quota > 0.02:
            ht = (h - 0.24) * quota
            box("tap_" + tag, (cx, y(NICCHIA * 0.45), zbase + h - 0.24 - ht / 2.0),
                (w - 0.05, 0.05, ht), rnd.choice(tende), raccolta=pezzi)
        if not porta:
            box("dav_" + tag, (cx, faccia + verso * 0.05, zbase - 0.045),
                (w + 0.26, NICCHIA + 0.20, 0.09), "QP_Cemento", raccolta=pezzi)

    for piano in range(S["piani"]):
        z0 = S["h_terra"] + piano * S["h_piano"]
        occupato = bool(S["occupazione"][piano])
        for k, (tipo, cx, w, h, dav) in enumerate(S["aperture_fronte"]):
            finestra("f%d_%d" % (piano, k), cx, z0 + dav, w, h, True, occupato,
                     tipo == "porta")
        for k, (_, cx, w, h, dav) in enumerate(S["aperture_retro"]):
            finestra("b%d_%d" % (piano, k), cx, z0 + dav, w, h, False, occupato)

    yg = yf + NICCHIA_TERRA
    for i, (tipo, cx, w, h, dav) in enumerate(S["aperture_terra"]):
        if tipo == "garage":
            box("ser%d" % i, (cx, yg - 0.06, h / 2.0), (w, 0.10, h), "QP_Serranda",
                raccolta=pezzi)
            for s in range(7):
                box("serd%d_%d" % (i, s), (cx, yg - 0.12, 0.18 + s * 0.32),
                    (w - 0.06, 0.05, 0.07), "QP_Cemento_Scuro", raccolta=pezzi)
        elif tipo == "portone":
            box("por%d" % i, (cx, yg - 0.06, h / 2.0), (w, 0.10, h), "QP_Legno_Vecchio",
                raccolta=pezzi)
            box("porv%d" % i, (cx, yg - 0.13, h * 0.75), (w - 0.35, 0.04, 0.80),
                "QP_Vetro_Scuro", raccolta=pezzi)
            box("port%d" % i, (cx, yg - 0.13, h * 0.49), (0.10, 0.05, 1.10),
                "QP_Metallo_Ruggine", raccolta=pezzi)
        else:
            box("gra%d" % i, (cx, yg - 0.05, dav + h / 2.0), (w, 0.06, h),
                "QP_Vetro_Rotto", raccolta=pezzi)
            for s in range(5):
                box("grab%d_%d" % (i, s), (cx - w / 2 + 0.09 + s * (w - 0.18) / 4.0,
                                           yg - 0.11, dav + h / 2.0),
                    (0.05, 0.05, h - 0.02), "QP_Metallo_Ruggine", raccolta=pezzi)
    box("porta_retro", (0.0, yb - NICCHIA_TERRA + 0.06, 1.15), (1.10, 0.10, 2.30),
        "QP_Metallo_Ruggine", raccolta=pezzi)

    return unisci(pezzi, "COND_Infissi")


def balconi(S):
    """Solette, parapetti rattoppati e panni stesi.

    I panni vanno appesi **sul lato esterno** del parapetto, non dentro il
    balcone: visti di fronte, un panno steso dietro un pannello opaco alto un
    metro non si vede, e il balcone resta un ripiano vuoto.
    """
    rnd = random.Random(S["seme"] + 2)
    yf = -S["profondita"] / 2.0
    x0, x1 = S["balcone_x"]
    cx0 = (x0 + x1) / 2.0
    bw = x1 - x0
    prof = 1.22
    by = yf - prof / 2.0 + 0.04
    bfr = yf - prof + 0.04
    rh = 1.02
    pezzi = []

    rattoppi = ["QP_Pannello_Rosso", "QP_Pannello_Blu", "QP_Pannello_Ocra",
                "QP_Pannello_Verde", "QP_Serranda", "QP_Legno_Vecchio",
                "QP_Tapparella_B"]
    panni = ["QP_Panni_Stesi", "QP_Pannello_Blu", "QP_Pannello_Rosso",
             "QP_Pannello_Ocra", "QP_Infisso", "QP_Pannello_Verde"]

    for piano in range(S["piani"]):
        z0 = S["h_terra"] + piano * S["h_piano"]
        occupato = bool(S["occupazione"][piano])
        t = "b%d" % piano

        box("sol_" + t, (cx0, by, z0 - 0.09), (bw, prof, 0.18), "QP_Cemento",
            raccolta=pezzi)
        box("fas_" + t, (cx0, bfr + 0.03, z0 - 0.10), (bw + 0.04, 0.09, 0.22),
            "QP_Cemento_Scuro", raccolta=pezzi)

        seg = bw / 3.0
        for s in range(3):
            box("pan_%s_%d" % (t, s), (x0 + seg * (s + 0.5), bfr + 0.05, z0 + rh / 2 - 0.02),
                (seg - 0.03, 0.06, rh - 0.14), rnd.choice(rattoppi), raccolta=pezzi)
        for s, cx in enumerate([x0 + 0.04, x1 - 0.04]):
            box("lat_%s_%d" % (t, s), (cx, by + 0.02, z0 + rh / 2 - 0.02),
                (0.06, prof - 0.08, rh - 0.14), rnd.choice(rattoppi), raccolta=pezzi)

        box("cor_" + t, (cx0, bfr + 0.05, z0 + rh), (bw + 0.06, 0.12, 0.07),
            "QP_Metallo_Ruggine", raccolta=pezzi)
        for s, cx in enumerate([x0 + 0.04, x1 - 0.04]):
            box("corl_%s_%d" % (t, s), (cx, by + 0.02, z0 + rh), (0.10, prof - 0.06, 0.07),
                "QP_Metallo_Ruggine", raccolta=pezzi)
            box("mon_%s_%d" % (t, s), (cx, bfr + 0.05, z0 + rh / 2), (0.09, 0.09, rh),
                "QP_Metallo_Ruggine", raccolta=pezzi)
        box("bas_" + t, (cx0, bfr + 0.05, z0 + 0.10), (bw + 0.04, 0.10, 0.06),
            "QP_Metallo_Ruggine", raccolta=pezzi)

        if occupato:
            yp = bfr - 0.05
            box("filo_" + t, (cx0, yp, z0 + rh + 0.13), (bw - 0.20, 0.025, 0.025),
                "QP_Metallo_Ruggine", raccolta=pezzi)
            n = rnd.randint(3, 5)
            for k in range(n):
                cw = rnd.uniform(0.30, 0.50)
                ch = rnd.uniform(0.55, 1.05)
                cx = x0 + 0.32 + (bw - 0.72) * (k + 0.5) / n + rnd.uniform(-0.06, 0.06)
                box("pnn_%s_%d" % (t, k), (cx, yp, z0 + rh + 0.10 - ch / 2.0),
                    (cw, 0.03, ch), rnd.choice(panni), raccolta=pezzi)
            for k in range(rnd.randint(1, 3)):
                h = rnd.uniform(0.35, 1.25)
                box("obj_%s_%d" % (t, k),
                    (rnd.uniform(x0 + 0.45, x1 - 0.45), by + rnd.uniform(-0.15, 0.25), h / 2),
                    (rnd.uniform(0.3, 0.55), rnd.uniform(0.3, 0.45), h),
                    rnd.choice(rattoppi), raccolta=pezzi)
        else:
            box("rot_" + t, (x0 + 0.9, bfr + 0.05, z0 + 0.55), (0.7, 0.07, 0.45),
                "QP_Metallo_Ruggine", rot=(0, math.radians(14), 0), raccolta=pezzi)
            for k in range(2):
                box("cal_%s_%d" % (t, k),
                    (rnd.uniform(x0 + 0.4, x1 - 0.4), by + rnd.uniform(-0.2, 0.2), 0.09),
                    (rnd.uniform(0.25, 0.5), rnd.uniform(0.2, 0.4), 0.16),
                    "QP_Cemento_Scuro", raccolta=pezzi)

    z0 = S["h_terra"] + 4 * S["h_piano"]
    box("tappeto", (cx0 + 0.6, bfr - 0.06, z0 + 0.42), (0.95, 0.04, 1.50),
        "QP_Pannello_Rosso", raccolta=pezzi)
    for cx, piano in S["condizionatori"]:
        z0 = S["h_terra"] + piano * S["h_piano"]
        box("cnd_%d_%d" % (int(cx * 10), piano), (cx + 0.85, yf - 0.22, z0 + 1.15),
            (0.80, 0.34, 0.55), "QP_Infisso", raccolta=pezzi)
        box("cndb_%d_%d" % (int(cx * 10), piano), (cx + 0.85, yf - 0.10, z0 + 0.85),
            (0.70, 0.08, 0.06), "QP_Metallo_Ruggine", raccolta=pezzi)

    return unisci(pezzi, "COND_Balconi")


def lotto(S):
    """Il recinto, l'annesso basso e l'immondizia.

    Senza il lotto l'edificio e' un volume che galleggia. Gli sprite del gioco
    sono *lotti* affacciati sulla strada: quanto occupano di fronte strada e' la
    misura che va guardata accanto ai vicini, ed e' il recinto a definirla.
    """
    rnd = random.Random(S["seme"] + 4)
    x0, x1 = S["lotto_x"]
    y0, y1 = S["lotto_y"]
    varco0, varco1 = S["varco"]
    pezzi = []

    box("lot_suolo", ((x0 + x1) / 2, (y0 + y1) / 2, -0.07), (x1 - x0, y1 - y0, 0.18),
        "QP_Suolo_Lotto", raccolta=pezzi)

    mw, mh, rh = 0.26, 0.55, 1.15

    def recinto(xa, ya, xb, yb, tag):
        dx, dy = xb - xa, yb - ya
        lung = math.hypot(dx, dy)
        cx, cy = (xa + xb) / 2.0, (ya + yb) / 2.0
        oriz = abs(dx) > abs(dy)
        box("lot_mur_" + tag, (cx, cy, mh / 2), (lung, mw, mh) if oriz else (mw, lung, mh),
            "QP_Cemento_Scuro", raccolta=pezzi)
        for k, z in enumerate([mh + rh - 0.06, mh + rh * 0.45]):
            box("lot_cor_%s_%d" % (tag, k), (cx, cy, z),
                (lung, 0.06, 0.07) if oriz else (0.06, lung, 0.07),
                "QP_Metallo_Ruggine", raccolta=pezzi)
        n = max(2, int(lung / 1.35))
        for i in range(n + 1):
            t = i / float(n)
            box("lot_pal_%s_%d" % (tag, i), (xa + dx * t, ya + dy * t, mh + rh / 2),
                (0.09, 0.09, rh), "QP_Metallo_Ruggine", raccolta=pezzi)

    recinto(x0, y0, varco0, y0, "f1")
    recinto(varco1, y0, x1, y0, "f2")
    recinto(x0, y0, x0, y1, "sx")
    recinto(x1, y0, x1, y1, "dx")
    for cx in (varco0, varco1):
        box("lot_pil_%d" % int(cx * 10), (cx, y0, 1.05), (0.40, 0.40, 2.10),
            "QP_Cemento_Scuro", raccolta=pezzi)
        box("lot_pilc_%d" % int(cx * 10), (cx, y0, 2.16), (0.52, 0.52, 0.12),
            "QP_Cemento", raccolta=pezzi)

    ax, ay = S["annesso"]
    box("lot_ann", (ax, ay, 1.55), (4.6, 4.4, 3.10), "QP_Intonaco_Marrone_B",
        raccolta=pezzi)
    box("lot_ann_tetto", (ax, ay, 3.22), (4.9, 4.7, 0.22), "QP_Cemento", raccolta=pezzi)
    box("lot_ann_porta", (ax - 0.6, ay - 2.24, 1.10), (1.60, 0.10, 2.20),
        "QP_Serranda", raccolta=pezzi)
    for s in range(5):
        box("lot_ann_dog%d" % s, (ax - 0.6, ay - 2.30, 0.25 + s * 0.42),
            (1.50, 0.05, 0.07), "QP_Cemento_Scuro", raccolta=pezzi)
    box("lot_ann_fin", (ax + 1.4, ay - 2.24, 2.00), (0.80, 0.09, 0.80),
        "QP_Vetro_Rotto", raccolta=pezzi)
    box("lot_ann_com", (ax + 1.7, ay + 1.2, 3.70), (0.42, 0.42, 0.90), "QP_Murato",
        raccolta=pezzi)

    for i in range(4):
        box("lot_lam%d" % i, (7.6 + i * 0.9, -4.3 + rnd.uniform(-0.2, 0.2), 1.05),
            (0.85, 0.06, 2.10), "QP_Lamiera",
            rot=(math.radians(rnd.uniform(-7, -3)), 0, 0), raccolta=pezzi)
    for i in range(5):
        box("lot_asse%d" % i, (5.6 + i * 0.16, -6.1, 0.85), (0.22, 0.05, 1.70),
            "QP_Legno_Vecchio",
            rot=(math.radians(-13), 0, math.radians(rnd.uniform(-4, 4))), raccolta=pezzi)

    box("lot_cassonetto", (2.9, -7.6, 0.60), (1.85, 1.05, 1.20), "QP_Cassonetto",
        raccolta=pezzi)
    box("lot_casso_cop", (2.9, -7.6, 1.24), (1.92, 1.12, 0.10), "QP_Cemento_Scuro",
        raccolta=pezzi)
    for i, (cx, cy) in enumerate([(4.9, -7.4), (5.8, -7.9)]):
        cilindro("lot_bidone%d" % i, (cx, cy, 0.48), 0.36, 0.96, "QP_Bidone",
                 raccolta=pezzi)
        cilindro("lot_bidcop%d" % i, (cx, cy, 0.99), 0.38, 0.08, "QP_Cemento_Scuro",
                 raccolta=pezzi)
    cilindro("lot_barile", (9.2, -5.4, 0.45), 0.34, 0.90, "QP_Barile", raccolta=pezzi)
    for i in range(7):
        r = rnd.uniform(0.22, 0.38)
        cilindro("lot_sacco%d" % i, (rnd.uniform(1.2, 6.6), rnd.uniform(-8.5, -6.6),
                                     r * 0.75), r, r * 1.5, "QP_Sacco", lati=8,
                 raccolta=pezzi)
    for i in range(3):
        cilindro("lot_gomma%d" % i, (rnd.uniform(6.8, 9.6), rnd.uniform(-7.8, -6.4), 0.11),
                 0.42, 0.22, "QP_Sacco", lati=14, raccolta=pezzi)

    return unisci(pezzi, "COND_Lotto")


# ----------------------------------------------------------------------
#  la casa: villetta americana di legno, un piano e sottotetto
# ----------------------------------------------------------------------

def poligoni(nome, punti, facce, materiale=None, raccolta=None):
    """Mesh da vertici e facce, con le normali rimesse a posto.

    Serve per il timpano del tetto, che e' un prisma triangolare: con i soli
    cubi si farebbe solo con dei boolean, e per sei facce non vale la pena.
    Le normali si ricalcolano con bmesh e non con l'operatore di menu, che
    vorrebbe l'oggetto attivo e la modalita' giusta.
    """
    mesh = bpy.data.meshes.new(nome)
    mesh.from_pydata(punti, [], facce)
    mesh.update()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(nome, mesh)
    bpy.context.scene.collection.objects.link(obj)
    if materiale:
        obj.data.materials.append(M[materiale])
    if raccolta is not None:
        raccolta.append(obj)
    return obj


def casa_corpo(S):
    """Muri, timpano e falde.

    Il colmo corre **perpendicolare** alla strada, non parallelo: e' quello che
    mette il timpano triangolare di fronte a chi guarda, ed e' la sagoma della
    casa di riferimento. Con il colmo parallelo si vedrebbe una falda intera e
    la casa diventerebbe un capannone basso.

    I bordi obliqui del timpano sono verniciati di verde. Su una facciata bianca
    sono l'unico colore forte, e a 8 px/m si riconoscono prima della sagoma.
    """
    W, D = S["larghezza"], S["profondita"]
    h = S["h_terra"] + S["h_primo"]
    p = math.radians(S["pendenza"])
    salita = (W / 2.0) * math.tan(p)
    sporto = S["sporto"]
    yf = -D / 2.0
    pezzi = []

    box("CASA_Muri", (0, 0, h / 2.0), (W, D, h), "QP_Assito", raccolta=pezzi)
    box("CASA_Fondazione", (0, 0, 0.24), (W + 0.20, D + 0.20, 0.48),
        "QP_Cemento_Scuro", raccolta=pezzi)
    # Marcapiano fra terra e primo: nella casa vera e' la fascia dove l'assito
    # cambia corso, e serve a non far leggere i due piani come un muro solo.
    box("CASA_Marcapiano", (0, 0, S["h_terra"]), (W + 0.10, D + 0.10, 0.14),
        "QP_Legno_Dipinto", raccolta=pezzi)

    # sottotetto: prisma triangolare col colmo lungo Y
    punti = [
        (-W / 2, yf, h), (-W / 2, -yf, h), (W / 2, -yf, h), (W / 2, yf, h),
        (0.0, yf, h + salita), (0.0, -yf, h + salita),
    ]
    facce = [(0, 1, 5, 4), (2, 5, 4, 3), (0, 4, 3), (1, 5, 2), (0, 3, 2, 1)]
    poligoni("CASA_Timpano", punti, facce, "QP_Assito", raccolta=pezzi)

    # Le due falde. Il colmo e' lungo Y, quindi le falde scendono verso +/-X e
    # la rotazione e' intorno a Y: `s` e' il lato, e posizione, normale e
    # rotazione devono uscire tutte da lui.
    lung = (W / 2.0) / math.cos(p) + sporto
    t = 0.16
    for s in (-1.0, 1.0):
        n = (s * math.sin(p), 0.0, math.cos(p))        # normale, verso fuori
        giu = (-math.cos(p), 0.0, s * math.sin(p))     # lungo la falda, alla gronda
        centro = (s * W / 4.0 + n[0] * t / 2.0 + giu[0] * sporto / 2.0,
                  0.0,
                  h + salita / 2.0 + n[2] * t / 2.0 + giu[2] * sporto / 2.0)
        box("CASA_Falda_%d" % int(s), centro, (lung, D + 2 * sporto, t),
            "QP_Tegole", rot=(0, s * p, 0), raccolta=pezzi)

        # Bordo obliquo verde sul timpano davanti. Va messo sul **bordo dello
        # sporto** e non sul filo del muro: la falda sporge di 40 cm oltre la
        # facciata, e un bordo alla quota del muro finisce sotto la gronda, dove
        # dall'alto non lo vede nessuno. Sta anche un dito sopra il piano della
        # falda, o si legge come una riga d'ombra invece che come un profilo.
        alza = t / 2.0 + 0.10
        cb = (s * W / 4.0 + n[0] * alza + giu[0] * sporto / 2.0,
              yf - sporto + 0.16,
              h + salita / 2.0 + n[2] * alza + giu[2] * sporto / 2.0)
        box("CASA_Bordo_%d" % int(s), cb, (lung, 0.32, 0.34), "QP_Verde_Trim",
            rot=(0, s * p, 0), raccolta=pezzi)
        # e la gronda verde sul fianco
        cg = (s * (W / 2.0 + sporto * 0.72), 0.0, h - 0.04)
        box("CASA_Gronda_%d" % int(s), cg, (0.20, D + 2 * sporto, 0.20),
            "QP_Verde_Trim_Scuro", raccolta=pezzi)

    box("CASA_Colmo", (0, 0, h + salita + 0.08), (0.30, D + 2 * sporto, 0.14),
        "QP_Verde_Trim_Scuro", raccolta=pezzi)

    cx, cy = S["camino"]
    box("CASA_Camino", (cx, cy, (h + salita + 0.85) / 2.0),
        (0.72, 0.62, h + salita + 0.85), "QP_Mattoni", raccolta=pezzi)
    box("CASA_Camino_Cap", (cx, cy, h + salita + 0.89), (0.86, 0.76, 0.14),
        "QP_Cemento", raccolta=pezzi)

    return unisci(pezzi, "CASA_Corpo")


def casa_portico(S):
    """Portico su tutto il fronte: pilastri di mattoni, fascia decorata, gradini.

    La profondita' e' 1,6 m e non due e mezzo, e non e' una scelta di gusto. Con
    la camera a 27 gradi un tetto di portico a 2,95 m nasconde tutto quello che
    sta sotto sopra i 2,13 m: a 1,6 m di sporgenza la porta ci sta per un pelo,
    a 2,5 m sparirebbe. La casa e' di due piani proprio per questo — sopra al
    portico restano un piano intero e il timpano, e il portico puo' permettersi
    di mangiarsi il piano terra.
    """
    rnd = random.Random(S["seme"] + 5)
    W, D = S["larghezza"], S["profondita"]
    yf = -D / 2.0
    pd = S["portico_p"]
    quota, hp = 0.55, S["h_terra"]
    y_est = yf - pd
    pezzi = []

    box("por_piano", (0, yf - pd / 2.0, quota - 0.09), (W, pd, 0.18),
        "QP_Assito_Portico", raccolta=pezzi)
    # La fascia a mattonelle gialle sotto il piano: nella casa di riferimento e'
    # la cosa piu' caratteristica del fronte, e sta tutta in mezzo metro.
    box("por_decoro", (0, y_est + 0.06, quota - 0.30), (W, 0.14, 0.44),
        "QP_Decoro", raccolta=pezzi)
    box("por_zocc", (0, y_est + 0.14, quota - 0.50), (W, 0.22, 0.20),
        "QP_Cemento_Scuro", raccolta=pezzi)

    # pilastri di mattoni fino al tetto del portico
    pilastri = [-W / 2 + 0.42, 0.0, W / 2 - 0.42]
    for i, cx in enumerate(pilastri):
        box("por_pil%d" % i, (cx, y_est + 0.30, quota + (hp - quota) / 2.0),
            (0.44, 0.44, hp - quota), "QP_Mattone_Portico", raccolta=pezzi)
        box("por_pilcap%d" % i, (cx, y_est + 0.30, hp - 0.04), (0.56, 0.56, 0.14),
            "QP_Cemento", raccolta=pezzi)

    box("por_tetto", (0, yf - pd / 2.0 + 0.04, hp + 0.10),
        (W + 0.24, pd + 0.26, 0.20), "QP_Tegole", raccolta=pezzi)
    box("por_gronda", (0, y_est - 0.11, hp + 0.06), (W + 0.24, 0.16, 0.22),
        "QP_Verde_Trim", raccolta=pezzi)

    # frontoncino verde al centro del tetto del portico
    ang = math.atan2(0.62, 1.25)
    for lato in (-1, 1):
        box("por_front%d" % lato, (lato * 0.625, y_est - 0.08, hp + 0.52),
            (1.42, 0.20, 0.20), "QP_Verde_Trim",
            rot=(0, lato * ang, 0), raccolta=pezzi)

    # gradini a sinistra, come nella casa vera, con la ringhiera di ferro
    gx = -W / 2 + 0.95
    for k in range(4):
        box("por_grad%d" % k, (gx, y_est - 0.20 - k * 0.32, quota - 0.10 - k * 0.15),
            (1.35, 0.36, 0.16), "QP_Cemento", raccolta=pezzi)
    for lato in (-1, 1):
        box("por_ring%d" % lato, (gx + lato * 0.62, y_est - 0.72, quota + 0.42),
            (0.06, 1.55, 0.06), "QP_Metallo_Ruggine",
            rot=(math.radians(-19), 0, 0), raccolta=pezzi)
        for k in range(3):
            box("por_ringm%d_%d" % (lato, k),
                (gx + lato * 0.62, y_est - 0.28 - k * 0.42,
                 quota + 0.10 - k * 0.11),
                (0.05, 0.05, 0.75), "QP_Metallo_Ruggine", raccolta=pezzi)

    # roba sotto al portico
    for k in range(2):
        box("por_cassa%d" % k, (W / 2 - 1.5 + k * 0.12, yf - 0.55 + k * 0.10,
                                quota + 0.17 + k * 0.32),
            (0.54, 0.40, 0.32), "QP_Compensato",
            rot=(0, 0, math.radians(rnd.uniform(-9, 9))), raccolta=pezzi)
    box("por_lampada", (-2.05, yf - 0.06, quota + 1.72), (0.15, 0.13, 0.20),
        "QP_Vetro_Acceso", raccolta=pezzi)

    return unisci(pezzi, "CASA_Portico")


def casa_infissi(S):
    """Porta, finestre dei due piani e la coppia nel timpano.

    Le finestre hanno la cornice **sporgente** e non sono un buco nel muro: su
    una parete di assito il serramento e' un telaio inchiodato sopra le tavole,
    e senza quel rilievo sembrano ritagliate con le forbici.

    Al piano terra una delle due aperture e' chiusa col compensato, come nella
    casa vera: e' il dettaglio che dice "qui non ci sta piu' nessuno" senza
    bisogno di rovinare tutto il resto.
    """
    rnd = random.Random(S["seme"] + 6)
    W, D = S["larghezza"], S["profondita"]
    h_t = S["h_terra"]
    yf = -D / 2.0
    inc = 0.10
    pezzi = []

    def cornice(tag, cx, zc, w, h, colore="QP_Legno_Dipinto"):
        for dx, dz, sx, sz in ((0, h / 2 + 0.08, w + 0.32, 0.16),
                               (0, -h / 2 - 0.08, w + 0.32, 0.16),
                               (-w / 2 - 0.08, 0, 0.16, h + 0.32),
                               (w / 2 + 0.08, 0, 0.16, h + 0.32)):
            box("cor_%s_%d_%d" % (tag, int(dx * 100), int(dz * 100)),
                (cx + dx, yf - 0.05, zc + dz), (sx, 0.12, sz), colore,
                raccolta=pezzi)

    def finestra(tag, cx, zbase, w, h, stato="normale"):
        zc = zbase + h / 2.0
        box("fin_tel_" + tag, (cx, yf + inc - 0.03, zc), (w, 0.08, h),
            "QP_Infisso", raccolta=pezzi)
        vetro = {"rotta": "QP_Vetro_Rotto", "accesa": "QP_Vetro_Acceso",
                 "chiusa": "QP_Compensato"}.get(stato, "QP_Vetro_Scuro")
        box("fin_vet_" + tag, (cx, yf + inc - 0.09, zc),
            (w - 0.14, 0.04, h - 0.14), vetro, raccolta=pezzi)
        if stato != "chiusa":
            box("fin_mon_" + tag, (cx, yf + inc - 0.12, zc),
                (0.06, 0.04, h - 0.14), "QP_Infisso", raccolta=pezzi)
            box("fin_tra_" + tag, (cx, yf + inc - 0.12, zc),
                (w - 0.14, 0.04, 0.06), "QP_Infisso", raccolta=pezzi)
        cornice(tag, cx, zc, w, h)
        box("fin_dav_" + tag, (cx, yf - 0.10, zbase - 0.10),
            (w + 0.42, 0.22, 0.10), "QP_Legno_Dipinto", raccolta=pezzi)

    # --- piano terra, sotto al portico -----------------------------------
    quota = 0.55
    box("porta", (-1.70, yf + inc - 0.02, quota + 1.05), (1.00, 0.10, 2.10),
        "QP_Porta_Casa", raccolta=pezzi)
    box("porta_vetro", (-1.70, yf + inc - 0.08, quota + 1.62), (0.50, 0.04, 0.58),
        "QP_Vetro_Scuro", raccolta=pezzi)
    cornice("porta", -1.70, quota + 1.05, 1.00, 2.10)
    # la grande apertura a destra, tappata col compensato
    finestra("terra_dx", 1.75, quota + 0.62, 1.70, 1.55, "chiusa")

    # --- primo piano: tre finestre in fila --------------------------------
    z1 = h_t + 0.95
    for tag, cx, stato in (("p1_sx", -2.25, "rotta"),
                           ("p1_c", 0.0, "accesa"),
                           ("p1_dx", 2.25, "normale")):
        finestra(tag, cx, z1, 0.98, 1.48, stato)

    # --- coppia di finestre nel timpano -----------------------------------
    p = math.radians(S["pendenza"])
    z_tim = S["h_terra"] + S["h_primo"] + 0.62
    for lato in (-1, 1):
        finestra("tim_%d" % lato, lato * 0.52, z_tim, 0.82, 1.22,
                 rnd.choice(["normale", "rotta"]))
    _ = p

    # La parabola va sul **muro del timpano**, non sulla falda.
    #
    # Su una falda inclinata un disco largo settanta centimetri copre un tratto
    # di tetto che sale di sessanta: per quanto lo si alzi resta mezzo sepolto da
    # una parte, e a 8 px/m si legge come un buco tondo nel tetto. Sul timpano
    # sta appoggiato a una parete verticale, che e' anche dove le montano
    # davvero.
    h_muro = S["h_terra"] + S["h_primo"]
    box("parabola_st", (-1.55, yf - 0.20, h_muro + 1.05), (0.09, 0.30, 0.09),
        "QP_Metallo_Ruggine", raccolta=pezzi)
    cilindro("parabola", (-1.55, yf - 0.36, h_muro + 1.12), 0.36, 0.09,
             "QP_Infisso", lati=16, rot=(math.radians(62), 0, 0), raccolta=pezzi)

    # Lo sfiato invece e' sottile e va bene sulla falda: la quota del tetto a una
    # data x e' h + (W/2 - |x|) * tan(pendenza).
    def su_falda(cx, sopra=0.0):
        return h_muro + (W / 2.0 - abs(cx)) * math.tan(
            math.radians(S["pendenza"])) + sopra

    box("sfiato", (1.90, 1.20, su_falda(1.90, 0.34)), (0.13, 0.13, 0.70),
        "QP_Metallo_Ruggine", raccolta=pezzi)

    return unisci(pezzi, "CASA_Infissi")


def casa_lotto(S):
    """Il cortile: stretto come la casa, e lasciato andare.

    Nella casa di riferimento davanti non c'e' un prato ma un groviglio di rovi
    secchi alto quanto la ringhiera, e il marciapiede comincia subito dopo. Il
    cortile e' corto di proposito: con la camera inclinata la profondita' del
    lotto pesa sull'altezza dello sprite quanto l'edificio.
    """
    rnd = random.Random(S["seme"] + 7)
    x0, x1 = S["lotto_x"]
    y0, y1 = S["lotto_y"]
    pezzi = []

    box("cor_suolo", ((x0 + x1) / 2, (y0 + y1) / 2, -0.07),
        (x1 - x0, y1 - y0, 0.18), "QP_Suolo_Lotto", raccolta=pezzi)
    box("cor_vialetto", (-S["larghezza"] / 2 + 0.95, (y0 - 4.6) / 2.0 - 1.4, 0.03),
        (1.35, abs(y0) - 3.2, 0.10), "QP_Cemento", raccolta=pezzi)

    # staccionata di assi ai lati, niente rete davanti: davanti c'e' il verde
    for lato, cx in ((-1, x0), (1, x1)):
        n = int((y1 - y0) / 0.34)
        for i in range(n):
            box("cor_ass_%d_%d" % (lato, i), (cx, y0 + 0.17 + i * 0.34, 0.60),
                (0.07, 0.30, 1.20 + rnd.uniform(-0.06, 0.06)),
                "QP_Legno_Vecchio", raccolta=pezzi)
        box("cor_asst_%d" % lato, (cx, (y0 + y1) / 2, 1.14), (0.09, y1 - y0, 0.09),
            "QP_Legno_Vecchio", raccolta=pezzi)

    # roba nel cortile
    for i, (cx, cy) in enumerate([(2.9, -6.6), (3.7, -6.1)]):
        cilindro("cor_bid%d" % i, (cx, cy, 0.44), 0.33, 0.88, "QP_Bidone",
                 raccolta=pezzi)
        cilindro("cor_bidc%d" % i, (cx, cy, 0.91), 0.35, 0.08, "QP_Cemento_Scuro",
                 raccolta=pezzi)
    for i in range(3):
        cilindro("cor_gom%d" % i, (rnd.uniform(-5.4, -4.2), rnd.uniform(-7.4, -6.2),
                                   0.11), 0.40, 0.22, "QP_Sacco", lati=14,
                 raccolta=pezzi)
    for i in range(3):
        box("cor_asse%d" % i, (x1 - 1.1 + i * 0.14, -4.2, 0.78), (0.22, 0.05, 1.55),
            "QP_Legno_Vecchio",
            rot=(math.radians(-15), 0, math.radians(rnd.uniform(-5, 5))),
            raccolta=pezzi)
    box("cor_cassetta_p", (-2.4, y0 + 0.5, 1.02), (0.25, 0.23, 0.21),
        "QP_Metallo_Ruggine", raccolta=pezzi)
    box("cor_palo_cass", (-2.4, y0 + 0.5, 0.46), (0.10, 0.10, 0.92),
        "QP_Legno_Vecchio", raccolta=pezzi)

    return unisci(pezzi, "CASA_Lotto")


# ----------------------------------------------------------------------
#  la casa gialla: vittoriana di legno, col portico e la girandola
# ----------------------------------------------------------------------

def _capanna(tag, cx, y0, W, D, h, pendenza, sporto, muro, falda, pezzi):
    """Timpano e due falde col colmo lungo Y, su un corpo largo W e profondo D
    che comincia in `y0` (il suo fronte). Stessa costruzione di `casa_corpo()`,
    riusabile per l'ala laterale."""
    p = math.radians(pendenza)
    salita = (W / 2.0) * math.tan(p)
    y1 = y0 + D
    punti = [
        (cx - W / 2, y0, h), (cx - W / 2, y1, h), (cx + W / 2, y1, h), (cx + W / 2, y0, h),
        (cx, y0, h + salita), (cx, y1, h + salita),
    ]
    facce = [(0, 1, 5, 4), (2, 5, 4, 3), (0, 4, 3), (1, 5, 2), (0, 3, 2, 1)]
    poligoni(tag + "_Timpano", punti, facce, muro, raccolta=pezzi)
    lung = (W / 2.0) / math.cos(p) + sporto
    t = 0.16
    for s in (-1.0, 1.0):
        n = (s * math.sin(p), 0.0, math.cos(p))
        giu = (-math.cos(p), 0.0, s * math.sin(p))
        centro = (cx + s * W / 4.0 + n[0] * t / 2.0 + giu[0] * sporto / 2.0,
                  (y0 + y1) / 2.0,
                  h + salita / 2.0 + n[2] * t / 2.0 + giu[2] * sporto / 2.0)
        box("%s_Falda_%d" % (tag, int(s)), centro, (lung, D + 2 * sporto, t),
            falda, rot=(0, s * p, 0), raccolta=pezzi)
    return salita


def casa_gialla_corpo(S):
    """Il corpo principale col timpano ripido sulla strada, e l'ala di lato.

    Le cose che fanno riconoscere la casa della foto, in ordine di quanto si
    vedono da lontano: il giallo dell'assito contro il bianco delle cornici, il
    timpano ripido con la grata di ventilazione in punta, i due risvolti di
    cornicione agli angoli del timpano, e l'ala piu' bassa a destra col suo
    tetto grigio.
    """
    W, D = S["larghezza"], S["profondita"]
    h = S["h_terra"] + S["h_primo"]
    yf = -D / 2.0
    pezzi = []
    box("CG_Muri", (0, 0, h / 2.0), (W, D, h), "QP_Assito_Giallo", raccolta=pezzi)
    box("CG_Fondazione", (0, 0, 0.3), (W + 0.16, D + 0.16, 0.6), "QP_Cemento_Scuro",
        raccolta=pezzi)
    # Cantonali bianchi: le tavole d'angolo che chiudono l'assito.
    for s in (-1, 1):
        box("CG_Cantonale_%d" % s, (s * (W / 2 + 0.02), yf + 0.06, h / 2.0 + 0.3),
            (0.2, 0.2, h - 0.6), "QP_Bianco_Trim", raccolta=pezzi)
    box("CG_Marcapiano", (0, 0, S["h_terra"] + 0.05), (W + 0.12, D + 0.12, 0.16),
        "QP_Bianco_Trim", raccolta=pezzi)
    salita = _capanna("CG", 0.0, yf, W, D, h, S["pendenza"], S["sporto"],
                      "QP_Assito_Giallo", "QP_Tegole_Grigie", pezzi)
    # Le tavole bianche lungo i due spioventi del timpano, sul bordo dello
    # sporto: vedi la nota in `casa_corpo()`.
    p = math.radians(S["pendenza"])
    lung = (W / 2.0) / math.cos(p) + S["sporto"]
    for s in (-1.0, 1.0):
        n = (s * math.sin(p), 0.0, math.cos(p))
        giu = (-math.cos(p), 0.0, s * math.sin(p))
        alza = 0.18
        cb = (s * W / 4.0 + n[0] * alza + giu[0] * S["sporto"] / 2.0,
              yf - S["sporto"] + 0.14,
              h + salita / 2.0 + n[2] * alza + giu[2] * S["sporto"] / 2.0)
        box("CG_Bordo_%d" % int(s), cb, (lung, 0.26, 0.30), "QP_Bianco_Trim",
            rot=(0, s * p, 0), raccolta=pezzi)
        # Il risvolto di cornicione all'angolo del timpano: la mensola bianca
        # che nella foto spunta a tutti e due i lati, sotto alla falda.
        box("CG_Risvolto_%d" % int(s), (s * (W / 2 + 0.05), yf - 0.05, h + 0.05),
            (0.75, 0.55, 0.3), "QP_Bianco_Trim", raccolta=pezzi)
        box("CG_Gronda_%d" % int(s), (s * (W / 2.0 + S["sporto"] * 0.75), 0.0, h - 0.05),
            (0.2, D + 2 * S["sporto"], 0.2), "QP_Bianco_Trim", raccolta=pezzi)
    # La grata di ventilazione in punta al timpano.
    zg = h + salita * 0.66
    box("CG_Grata_Cornice", (0, yf - 0.04, zg), (0.95, 0.1, 0.62), "QP_Bianco_Trim",
        raccolta=pezzi)
    box("CG_Grata_Fondo", (0, yf - 0.08, zg), (0.75, 0.04, 0.44), "QP_Infisso_Scuro",
        raccolta=pezzi)
    for k in range(4):
        box("CG_Grata_Lama%d" % k, (0, yf - 0.1, zg - 0.16 + k * 0.1), (0.75, 0.05, 0.04),
            "QP_Bianco_Trim", raccolta=pezzi)
    # Il camino di mattoni, dietro al colmo, un po' a sinistra.
    cx, cy = S["camino"]
    zc = h + salita + 0.7
    box("CG_Camino", (cx, cy, zc / 2.0), (0.62, 0.62, zc), "QP_Mattoni", raccolta=pezzi)
    box("CG_Camino_Cap", (cx, cy, zc + 0.05), (0.74, 0.74, 0.12), "QP_Cemento", raccolta=pezzi)

    # L'ala di destra: un piano e mezzo, arretrata, col suo tettuccio.
    AW, AD, AH = S["ala_l"], S["ala_p"], S["ala_h"]
    ax = W / 2.0 + AW / 2.0
    ay0 = yf + S["ala_arretro"]
    box("CG_Ala", (ax, ay0 + AD / 2.0, AH / 2.0), (AW, AD, AH), "QP_Assito_Giallo",
        raccolta=pezzi)
    box("CG_Ala_Fondazione", (ax, ay0 + AD / 2.0, 0.3), (AW + 0.12, AD + 0.12, 0.6),
        "QP_Cemento_Scuro", raccolta=pezzi)
    box("CG_Ala_Cantonale", (W / 2.0 + AW - 0.02, ay0 + 0.06, AH / 2.0 + 0.3),
        (0.2, 0.2, AH - 0.6), "QP_Bianco_Trim", raccolta=pezzi)
    _capanna("CG_Ala", ax, ay0, AW, AD, AH, S["ala_pendenza"], 0.3,
             "QP_Assito_Giallo", "QP_Tegole_Grigie", pezzi)
    return unisci(pezzi, "CG_Corpo")


def casa_gialla_portico(S):
    """Il portico su tutta la facciata, ala compresa.

    Colonnine bianche con le mensole ad arco, ringhiera bianca a colonnine, i
    gradini a sinistra. La profondita' e' quella della casa del giocatore (vedi
    `casa_portico()`): con la camera a 27 gradi un portico piu' profondo si
    mangerebbe porta e finestre.

    Le colonnine della ringhiera sono una ogni 20 cm e non ogni 10 come in una
    ringhiera vera: a 22 px/m quelle vere cadrebbero a due pixel e ridotte
    diventerebbero una fascia bianca piena.
    """
    W, D = S["larghezza"], S["profondita"]
    yf = -D / 2.0
    pd, quota, hp = S["portico_p"], S["quota"], S["h_terra"]
    x0 = -W / 2.0 - 0.1
    x1 = W / 2.0 + S["ala_l"]
    y_est = yf - pd
    pezzi = []
    box("CGP_Piano", ((x0 + x1) / 2, yf - pd / 2.0 + 0.3, quota - 0.08),
        (x1 - x0, pd + 0.6, 0.16), "QP_Assito_Portico", raccolta=pezzi)
    box("CGP_Zoccolo", ((x0 + x1) / 2, y_est + 0.12, (quota - 0.16) / 2.0),
        (x1 - x0, 0.24, quota - 0.16), "QP_Cemento_Scuro", raccolta=pezzi)
    box("CGP_Fascia", ((x0 + x1) / 2, y_est + 0.02, quota - 0.1),
        (x1 - x0, 0.06, 0.2), "QP_Bianco_Trim", raccolta=pezzi)

    # Il tetto del portico: una falda sola che scende verso la strada. Alto: col
    # bordo davanti sotto ai tre metri si mangiava porta e finestrona, perche'
    # da 27 gradi un tetto profondo un metro e mezzo copre un metro di muro.
    z_die, z_dav = hp + 0.5, hp + 0.08
    sp = 0.3
    ya, yb = yf, y_est - sp
    t = 0.14
    punti = [(x0 - sp, ya, z_die), (x1 + sp, ya, z_die), (x1 + sp, yb, z_dav), (x0 - sp, yb, z_dav),
             (x0 - sp, ya, z_die + t), (x1 + sp, ya, z_die + t), (x1 + sp, yb, z_dav + t),
             (x0 - sp, yb, z_dav + t)]
    facce = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    poligoni("CGP_Tetto", punti, facce, "QP_Tegole_Grigie", raccolta=pezzi)
    box("CGP_Gronda", ((x0 + x1) / 2, yb + 0.06, z_dav - 0.06), (x1 - x0 + 2 * sp, 0.12, 0.22),
        "QP_Bianco_Trim", raccolta=pezzi)
    # La trave sopra alle colonnine.
    z_trave = z_dav - 0.3
    box("CGP_Trave", ((x0 + x1) / 2, y_est + 0.1, z_trave), (x1 - x0, 0.18, 0.26),
        "QP_Bianco_Trim", raccolta=pezzi)

    # Colonnine e mensole ad arco.
    n_col = S["colonnine"]
    xs = [x0 + 0.1 + (x1 - x0 - 0.2) * i / (n_col - 1) for i in range(n_col)]
    for i, cx in enumerate(xs):
        box("CGP_Col%d" % i, (cx, y_est + 0.1, (quota + z_trave) / 2.0),
            (0.18, 0.18, z_trave - quota), "QP_Bianco_Trim", raccolta=pezzi)
        for s in (-1, 1):
            if (i == 0 and s < 0) or (i == n_col - 1 and s > 0):
                continue
            # Due tavolette a quarto di cerchio fanno l'arco: a questa scala
            # un arco vero e un triangolo smussato sono lo stesso pixel.
            for k, (dx, dz, ang) in enumerate(((0.22, -0.12, 35), (0.48, -0.03, 12))):
                box("CGP_Mensola%d_%d_%d" % (i, s, k), (cx + s * dx, y_est + 0.1, z_trave + dz),
                    (0.34, 0.1, 0.07), "QP_Bianco_Trim",
                    rot=(0, math.radians(s * ang), 0), raccolta=pezzi)

    # La ringhiera, interrotta davanti ai gradini.
    gx = S["gradini_x"]
    zr = quota + 0.9
    for i in range(n_col - 1):
        a, b = xs[i] + 0.09, xs[i + 1] - 0.09
        if a < gx < b:
            continue
        box("CGP_Corr%d" % i, ((a + b) / 2, y_est + 0.1, zr), (b - a, 0.1, 0.08),
            "QP_Bianco_Trim", raccolta=pezzi)
        box("CGP_Bass%d" % i, ((a + b) / 2, y_est + 0.1, quota + 0.1), (b - a, 0.08, 0.06),
            "QP_Bianco_Trim", raccolta=pezzi)
        n = int((b - a) / 0.2)
        for k in range(1, n):
            x = a + (b - a) * k / n
            box("CGP_Bal%d_%d" % (i, k), (x, y_est + 0.1, (quota + zr) / 2.0),
                (0.05, 0.05, zr - quota), "QP_Bianco_Trim", raccolta=pezzi)

    # I gradini di cemento.
    for k in range(3):
        box("CGP_Grad%d" % k, (gx, y_est - 0.18 - k * 0.3, quota - 0.1 - k * 0.2 - 0.05),
            (1.4, 0.34, 0.2 + 0.0), "QP_Cemento", raccolta=pezzi)
        box("CGP_GradS%d" % k, (gx, y_est - 0.18 - k * 0.3, (quota - 0.2 - k * 0.2) / 2.0),
            (1.4, 0.34, max(0.05, quota - 0.2 - k * 0.2)), "QP_Cemento_Scuro", raccolta=pezzi)
    return unisci(pezzi, "CG_Portico")


def casa_gialla_infissi(S):
    """Porte e finestre: tutte con la cornice bianca sporgente.

    Al primo piano la coppia di finestre col pannello a croce in mezzo e la
    cimasa sopra, che e' il pezzo piu' "vittoriano" della facciata. Al piano
    terra la porta a sinistra, la finestrona con le tende e la porta dell'ala.
    """
    W, D = S["larghezza"], S["profondita"]
    yf = -D / 2.0
    quota = S["quota"]
    pezzi = []

    def cornice(tag, cx, zc, w, h, y=yf):
        for dx, dz, sx, sz in ((0, h / 2 + 0.07, w + 0.28, 0.14),
                               (0, -h / 2 - 0.07, w + 0.28, 0.14),
                               (-w / 2 - 0.07, 0, 0.14, h + 0.28),
                               (w / 2 + 0.07, 0, 0.14, h + 0.28)):
            box("cgc_%s_%d_%d" % (tag, int(dx * 100), int(dz * 100)),
                (cx + dx, y - 0.05, zc + dz), (sx, 0.1, sz), "QP_Bianco_Trim",
                raccolta=pezzi)

    def finestra(tag, cx, zbase, w, h, vetro="QP_Vetro_Scuro", y=yf, traverso=True):
        zc = zbase + h / 2.0
        box("cgf_v_" + tag, (cx, y - 0.03, zc), (w, 0.04, h), vetro, raccolta=pezzi)
        if traverso:
            box("cgf_t_" + tag, (cx, y - 0.07, zc + h * 0.08), (w, 0.04, 0.06),
                "QP_Bianco_Trim", raccolta=pezzi)
        cornice(tag, cx, zc, w, h, y)
        box("cgf_d_" + tag, (cx, y - 0.1, zbase - 0.12), (w + 0.36, 0.2, 0.08),
            "QP_Bianco_Trim", raccolta=pezzi)

    # --- piano terra ---------------------------------------------------------
    px = S["porta_x"]
    box("cg_porta", (px, yf - 0.03, quota + 1.08), (0.95, 0.06, 2.16), "QP_Porta_Gialla",
        raccolta=pezzi)
    box("cg_porta_vetro", (px, yf - 0.07, quota + 1.45), (0.55, 0.04, 0.95), "QP_Vetro_Scuro",
        raccolta=pezzi)
    cornice("porta", px, quota + 1.08, 0.95, 2.16)
    box("cg_cassetta", (px + 0.85, yf - 0.08, quota + 1.3), (0.34, 0.12, 0.22), "QP_Infisso_Scuro",
        raccolta=pezzi)
    box("cg_lampada", (px - 0.75, yf - 0.08, quota + 1.9), (0.14, 0.12, 0.2), "QP_Vetro_Acceso",
        raccolta=pezzi)
    # La finestrona con le tende tirate: la luce di casa sta li'.
    finestra("salotto", 1.05, quota + 0.55, 2.3, 1.75, vetro="QP_Tende_Accese", traverso=False)
    for k in range(1, 4):
        box("cg_sal_mont%d" % k, (1.05 - 1.15 + 2.3 * k / 4, yf - 0.07, quota + 0.55 + 0.875),
            (0.06, 0.04, 1.75), "QP_Bianco_Trim", raccolta=pezzi)
    # L'ala: porta con la finestra a lato.
    ay = yf + S["ala_arretro"]
    ax = W / 2.0 + S["ala_l"] / 2.0
    box("cg_ala_porta", (ax - 0.45, ay - 0.03, quota + 1.05), (0.85, 0.06, 2.1),
        "QP_Porta_Gialla", raccolta=pezzi)
    box("cg_ala_porta_v", (ax - 0.45, ay - 0.07, quota + 1.35), (0.55, 0.04, 1.2),
        "QP_Tende_Accese", raccolta=pezzi)
    cornice("ala_porta", ax - 0.45, quota + 1.05, 0.85, 2.1, ay)
    finestra("ala_fin", ax + 0.95, quota + 0.8, 0.7, 1.3, y=ay)

    # --- primo piano: la coppia col pannello a croce -------------------------
    z1 = S["h_terra"] + 0.7
    wf, hf = 0.8, 1.5
    for tag, cx, vetro in (("p1_sx", -1.0, "QP_Vetro_Scuro"), ("p1_dx", 1.0, "QP_Vetro_Acceso")):
        finestra(tag, cx, z1, wf, hf, vetro=vetro)
    # Il pannello fra le due, con la croce di Sant'Andrea.
    zc = z1 + hf / 2.0
    box("cg_pann", (0, yf - 0.03, zc), (0.95, 0.05, hf), "QP_Assito_Giallo", raccolta=pezzi)
    cornice("pann", 0.0, zc, 0.95, hf)
    diag = math.hypot(0.95, hf)
    ang = math.atan2(hf, 0.95)
    for s in (-1, 1):
        box("cg_croce_%d" % s, (0, yf - 0.08, zc), (diag, 0.06, 0.1), "QP_Bianco_Trim",
            rot=(0, s * ang, 0), raccolta=pezzi)
    # La cimasa: una cornice orizzontale su tutte e tre, un frontoncino basso
    # e il pinnacolo in mezzo.
    ztop = z1 + hf + 0.2
    box("cg_cimasa", (0, yf - 0.1, ztop), (3.2, 0.2, 0.16), "QP_Bianco_Trim", raccolta=pezzi)
    for s in (-1, 1):
        box("cg_front_%d" % s, (s * 0.8, yf - 0.1, ztop + 0.22), (1.7, 0.14, 0.12),
            "QP_Bianco_Trim", rot=(0, s * math.radians(15), 0), raccolta=pezzi)
    box("cg_pinnacolo", (0, yf - 0.12, ztop + 0.5), (0.14, 0.12, 0.34), "QP_Bianco_Trim",
        raccolta=pezzi)
    # Il condizionatore sotto alla finestra di destra, come nella foto.
    box("cg_clima", (1.3, yf - 0.2, z1 - 0.05), (0.45, 0.35, 0.3), "QP_Lavatrice",
        raccolta=pezzi)
    # L'ala: finestrella sotto al tetto.
    finestra("ala_su", ax, S["ala_h"] - 0.2, 0.6, 0.75, y=ay)
    return unisci(pezzi, "CG_Infissi")


def casa_gialla_lotto(S):
    """Il giardinetto davanti: terra battuta e la recinzione della foto, pali
    di legno e rete, con il varco davanti ai gradini. Niente verde (la
    vegetazione la mette il gioco): il palo della girandola e la bandiera sul
    portico sono l'unica cosa in piu', e si muovono (`casa_gialla_animati`)."""
    x0, x1 = S["lotto_x"]
    y0 = S["lotto_y0"]
    D = S["profondita"]
    yf = -D / 2.0
    pezzi = []
    box("CGL_Suolo", ((x0 + x1) / 2, (y0 + yf) / 2, -0.05), (x1 - x0, yf - y0 + 0.4, 0.12),
        "QP_Suolo_Lotto", raccolta=pezzi)
    gx = S["gradini_x"]
    box("CGL_Vialetto", (gx, (y0 + yf - S["portico_p"]) / 2 - 0.3, 0.02),
        (1.2, yf - S["portico_p"] - y0 - 0.6, 0.06), "QP_Cemento", raccolta=pezzi)
    # La recinzione: pali ogni due metri e mezzo, traverso in cima, tre fili.
    tratti = ((x0, gx - 0.75), (gx + 0.75, x1))
    for t, (a, b) in enumerate(tratti):
        n = max(1, int(round((b - a) / 2.4)))
        for i in range(n + 1):
            x = a + (b - a) * i / n
            box("CGL_Palo%d_%d" % (t, i), (x, y0, 0.6), (0.14, 0.14, 1.2), "QP_Legno_Vecchio",
                raccolta=pezzi)
        box("CGL_Trav%d" % t, ((a + b) / 2, y0, 1.12), (b - a, 0.07, 0.07), "QP_Rete",
            raccolta=pezzi)
        for k, z in enumerate((0.25, 0.55, 0.85)):
            box("CGL_Filo%d_%d" % (t, k), ((a + b) / 2, y0, z), (b - a, 0.025, 0.025), "QP_Rete",
                raccolta=pezzi)
    # I due fianchi, corti.
    for s, x in ((0, x0), (1, x1)):
        box("CGL_Fianco%d" % s, (x, (y0 + yf) / 2, 1.12), (0.07, yf - y0, 0.07), "QP_Rete",
            raccolta=pezzi)
        box("CGL_PaloF%d" % s, (x, yf - 0.2, 0.6), (0.14, 0.14, 1.2), "QP_Legno_Vecchio",
            raccolta=pezzi)
    # I pali fermi delle due cose che si muovono.
    gx2, gy2 = S["girandola"]
    # Piu' alta della rete (1,2 m): sotto, la recinzione le passa davanti.
    box("CGL_PaloGirandola", (gx2, gy2 + 0.04, 0.78), (0.05, 0.05, 1.56), "QP_Legno_Vecchio",
        raccolta=pezzi)
    bx0, by0, bz0 = S["bandiera"]
    lung = S["asta"]
    d = Vector(S["asta_dir"]).normalized()
    c = Vector((bx0, by0, bz0)) + d * (lung / 2)
    asta = cilindro("CGL_Asta", tuple(c), 0.025, lung, "QP_Metallo_Ruggine", lati=6,
                    raccolta=pezzi)
    asta.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    bpy.context.view_layer.update()
    return unisci(pezzi, "CG_Lotto")


def casa_gialla_animati(S):
    """Le due cose che si muovono col vento, fuori dallo sprite dell'edificio.

    Stanno in oggetti a se' e **non** finiscono nel disegno: `main()` le
    nasconde per lo scatto della casa e delle luci, poi le fotografa da sole,
    fotogramma per fotogramma, con tutto il resto della casa in "holdout" —
    invisibile ma ancora li' a coprirle dove ci passa davanti. Cosi' i
    fotogrammi escono gia' allineati al disegno, e in gioco si appoggiano sopra
    (`scripts/components/wind_prop.gd`).

    Torna una lista di animazioni: nome, oggetti, funzione di posa (0..1, a
    ciclo chiuso) e numero di fotogrammi.
    """
    anims = []

    # --- la girandola: quattro pale colorate che girano intorno al perno ----
    gx, gy = S["girandola"]
    zc = 1.56
    perno_g = bpy.data.objects.new("CGA_Girandola", None)
    bpy.context.scene.collection.objects.link(perno_g)
    perno_g.location = (gx, gy - 0.02, zc)
    r = 0.40
    colori = ["QP_Girandola_Rossa", "QP_Girandola_Gialla", "QP_Girandola_Blu",
              "QP_Girandola_Verde"]
    pale = []
    for i in range(4):
        a = math.radians(90 * i)
        ca, sa = math.cos(a), math.sin(a)

        def ruota(x, z):
            return (x * ca - z * sa, 0.0, x * sa + z * ca)
        # La pala classica: un triangolo che parte dal perno e piega di lato.
        punti = [ruota(0.0, 0.0), ruota(r, 0.02), ruota(r * 0.55, r * 0.72)]
        punti = [(p[0], p[1] - 0.005 * i, p[2]) for p in punti]
        pala = poligoni("CGA_Pala%d" % i, punti + [(p[0], p[1] - 0.02, p[2]) for p in punti],
                        [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)],
                        colori[i])
        pala.parent = perno_g
        pale.append(pala)
    mozzo = cilindro("CGA_Mozzo", (0, -0.04, 0), 0.045, 0.06, "QP_Bianco_Trim", lati=8,
                     rot=(math.radians(90), 0, 0))
    mozzo.parent = perno_g

    def posa_girandola(t):
        # Quattro pale uguali: dopo novanta gradi il disegno si ripete, quindi
        # il ciclo e' un quarto di giro e non un giro intero.
        perno_g.rotation_euler = (0.0, math.radians(90.0 * t), 0.0)
    anims.append(("girandola", pale + [mozzo], posa_girandola, 6))

    # --- la bandiera: il telo appeso all'asta, che sventola ---------------
    bx0, by0, bz0 = S["bandiera"]
    lung = S["asta"]
    d = Vector(S["asta_dir"]).normalized()
    cima = Vector((bx0, by0, bz0)) + d * lung
    lato_asta = d * 0.85                # il telo e' cucito sull'ultimo tratto
    NU, NV = 9, 5
    lung_telo = 1.3
    bm = bmesh.new()
    riposo = []
    for j in range(NV):
        v = j / (NV - 1)
        attacco = cima - lato_asta * v
        for i in range(NU):
            u = i / (NU - 1)
            # Il telo esce di lato dall'asta e cade un po' verso terra.
            p = attacco + Vector((-lung_telo * u, -0.05 * u, -0.25 * u * u))
            riposo.append((p.copy(), u, v))
            bm.verts.new(p)
    bm.verts.ensure_lookup_table()
    for j in range(NV - 1):
        for i in range(NU - 1):
            a = j * NU + i
            bm.faces.new((bm.verts[a], bm.verts[a + 1], bm.verts[a + NU + 1], bm.verts[a + NU]))
    me = bpy.data.meshes.new("CGA_Bandiera")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(M["QP_Bandiera"])
    telo = bpy.data.objects.new("CGA_Bandiera", me)
    bpy.context.scene.collection.objects.link(telo)

    def posa_bandiera(t):
        for vtx, (p, u, v) in zip(telo.data.vertices, riposo):
            onda = math.sin(2 * math.pi * (t - u * 0.9))
            vtx.co = (p.x, p.y + 0.16 * u * onda, p.z + 0.07 * u * math.cos(2 * math.pi * (t - u)))
        telo.data.update()
    anims.append(("bandiera", [telo], posa_bandiera, 8))
    return anims


# ----------------------------------------------------------------------
#  edifici di schiera: botteghe, uffici, garage
# ----------------------------------------------------------------------

def commerciale(S):
    """Edificio di schiera: bottega o ufficio al piano terra, alloggi sopra.

    **E' a filo sui fianchi, e non e' un dettaglio: e' il motivo per cui
    esiste.** Casa e condominio hanno il loro lotto con la recinzione e vanno
    bene da soli; un quartiere povero vero pero' e' fatto di muri in comune, e
    per affiancarne dieci lungo una strada servono edifici che finiscano esatti
    dove finisce il muro. Niente sporgenze laterali, niente cortile: il
    cornicione sporge solo davanti, e due sprite messi a distanza pari alla loro
    larghezza si toccano come due case che condividono il muro.

    Il piano terra e' l'unica cosa che cambia davvero fra un'attivita' e
    l'altra (`fronte`): una vetrina, una serranda da garage, un portone da
    officina o una finestra con le sbarre. Sopra sono tutti uguali — finestre in
    fila — perche' sopra le botteghe ci abita gente, e le case si somigliano.

    Le aperture sono **scavate nel muro col boolean**, non appoggiate sopra. La
    facciata e' rivolta verso -Y: tutto quello che si mette a una y maggiore di
    quella del muro finisce dentro al muro e non si vede. E' un errore che non
    da' nessun segnale — niente compenetrazioni visibili, niente avvisi — si
    vede solo guardando il render e trovando una facciata cieca.
    """
    rnd = random.Random(S["seme"])
    W, D = S["larghezza"], S["profondita"]
    h_t, h_p = S["h_terra"], S["h_piano"]
    piani = S["piani"]
    H = h_t + piani * h_p
    yf = -D / 2.0

    REC_V = 0.26                     # profondita' della nicchia del fronte
    REC_F = 0.20                     # profondita' delle nicchie delle finestre
    luce_w = W - 1.30                # larghezza libera del fronte
    luce_h = h_t - 1.10              # altezza libera del fronte
    fw, fh = 1.02, 1.42              # finestre dei piani alti
    nf = S.get("finestre", 3)

    def col_fin(i):
        return -W / 2.0 + W * (i + 0.5) / nf

    # ==================================================================
    #  1. corpo, con le aperture scavate
    # ==================================================================
    muro = box("COM_Corpo", (0, 0, H / 2.0), (W, D, H), S["intonaco"])

    tagli = []
    SP = 0.40                        # quanto il cutter esce dal muro

    def taglia(nome, cx, cz, w, h, rec):
        box(nome, (cx, yf - SP / 2.0 + rec / 2.0, cz), (w, SP + rec, h),
            raccolta=tagli)

    taglia("t_fronte", 0.0, luce_h / 2.0, luce_w, luce_h, REC_V)
    for piano in range(piani):
        z0 = h_t + piano * h_p
        for i in range(nf):
            taglia("t_f%d_%d" % (piano, i), col_fin(i), z0 + 0.82 + fh / 2.0,
                   fw, fh, REC_F)

    cutter = unisci(tagli, "COM_Cutter")
    bpy.context.view_layer.objects.active = muro
    mod = muro.modifiers.new("Aperture", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.solver = "EXACT"
    mod.object = cutter
    bpy.ops.object.modifier_apply(modifier="Aperture")
    bpy.data.objects.remove(cutter, do_unlink=True)
    bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
    bpy.ops.object.select_all(action="DESELECT")
    muro.select_set(True)
    bpy.context.view_layer.objects.active = muro
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")

    # ==================================================================
    #  2. tutto il resto
    # ==================================================================
    pezzi = []
    box("com_zoccolo", (0, yf + 0.06, 0.26), (W, 0.16, 0.52), "QP_Cemento_Scuro",
        raccolta=pezzi)

    # Cornicione: sporge SOLO in avanti. Di lato resta a filo, o due edifici
    # accostati si compenetrerebbero per dieci centimetri per parte e in mezzo
    # comparirebbe una riga scura che non e' un muro in comune, e' un errore.
    box("com_cornicione", (0, yf - 0.16, H - 0.22), (W, 0.62, 0.44),
        "QP_Cemento", raccolta=pezzi)
    box("com_sottogronda", (0, yf - 0.02, H - 0.50), (W, 0.34, 0.12),
        "QP_Cemento_Scuro", raccolta=pezzi)

    # --- tetto piano --------------------------------------------------
    box("com_manto", (0, 0, H + 0.03), (W - 0.04, D - 0.04, 0.06), "QP_Guaina",
        raccolta=pezzi)
    box("com_par_f", (0, yf + 0.11, H + 0.22), (W, 0.22, 0.38), "QP_Cemento",
        raccolta=pezzi)
    box("com_par_b", (0, -yf - 0.11, H + 0.22), (W, 0.22, 0.38), "QP_Cemento",
        raccolta=pezzi)
    for lato in (-1, 1):
        box("com_par_%d" % lato, (lato * (W / 2 - 0.09), 0, H + 0.22),
            (0.18, D, 0.38), "QP_Cemento", raccolta=pezzi)
    # Roba tecnica: un tetto piano vuoto e' un rettangolo grigio che si prende
    # un quarto dello sprite senza dire niente.
    if piani >= 2:
        vx = rnd.uniform(-W / 5, W / 5)
        box("com_vano", (vx, 0.9, H + 0.06 + 0.85), (2.0, 1.7, 1.70),
            S["intonaco"], raccolta=pezzi)
        box("com_vano_cap", (vx, 0.9, H + 0.98), (2.2, 1.9, 0.14),
            "QP_Cemento", raccolta=pezzi)
    for i in range(rnd.randint(2, 4)):
        box("com_sfiato%d" % i, (rnd.uniform(-W / 2 + 0.8, W / 2 - 0.8),
                                 rnd.uniform(-D / 2 + 0.8, 0.4),
                                 H + 0.06 + 0.32),
            (0.30, 0.30, 0.64), "QP_Murato", raccolta=pezzi)
    box("com_clima", (rnd.uniform(-W / 2 + 1.2, W / 2 - 1.2), -1.2, H + 0.38),
        (0.95, 0.75, 0.62), "QP_Serranda", raccolta=pezzi)
    if rnd.random() < 0.7:
        cilindro("com_serb", (rnd.uniform(-W / 2 + 1.0, W / 2 - 1.0), -0.3,
                              H + 0.06 + 0.45), 0.46, 0.88, "QP_Serranda",
                 lati=14, raccolta=pezzi)
    for i in range(rnd.randint(1, 3)):
        cx = rnd.uniform(-W / 2 + 0.6, W / 2 - 0.6)
        box("com_tubo%d" % i, (cx, rnd.uniform(-1.6, 1.6), H + 0.06 + 0.45),
            (0.10, 0.10, 0.90), "QP_Metallo_Ruggine", raccolta=pezzi)

    # --- piano terra: il fronte dell'attivita', dentro alla nicchia -----
    fronte = S["fronte"]
    fondo = yf + REC_V                       # fondo del vano

    def yv(dal_fondo):
        """Dal fondo della nicchia verso la strada."""
        return fondo - dal_fondo

    box("com_arch", (0, yf - 0.06, luce_h + 0.26), (W, 0.34, 0.36),
        "QP_Cemento", raccolta=pezzi)

    if fronte == "vetrina":
        box("com_banc", (0, yv(0.10), 0.32), (luce_w, 0.32, 0.64),
            "QP_Mattone_Portico", raccolta=pezzi)
        vw = luce_w - 1.35
        zc = 0.64 + (luce_h - 0.64) / 2.0
        box("com_telaio", (-0.62, yv(0.05), zc), (vw + 0.14, 0.07, luce_h - 0.62),
            "QP_Infisso", raccolta=pezzi)
        box("com_vetro", (-0.62, yv(0.11), zc), (vw, 0.05, luce_h - 0.74),
            "QP_Vetrina", raccolta=pezzi)
        for k in range(2):
            box("com_mont%d" % k, (-0.62 - vw / 3.0 + k * vw / 1.5, yv(0.16), zc),
                (0.07, 0.05, luce_h - 0.74), "QP_Infisso", raccolta=pezzi)
        px = luce_w / 2.0 - 0.60
        box("com_porta", (px, yv(0.06), luce_h / 2.0), (1.00, 0.09, luce_h),
            "QP_Porta_Casa", raccolta=pezzi)
        box("com_porta_v", (px, yv(0.13), luce_h * 0.66), (0.62, 0.05, luce_h * 0.45),
            "QP_Vetrina", raccolta=pezzi)
    elif fronte in ("serranda", "officina"):
        alt = luce_h if fronte == "officina" else luce_h - 0.22
        # La serranda non prende tutta la campata: a destra resta la porta di
        # servizio, che e' l'unica cosa illuminata di un'officina chiusa. Senza
        # di lei garage e officina erano gli unici due edifici del quartiere
        # completamente spenti di notte — una saracinesca non ha finestre, e
        # nello sprite notturno restavano due sagome nere in mezzo a una fila
        # di case con le luci accese.
        sw = luce_w - 1.35
        sx = -(luce_w - sw) / 2.0
        box("com_serranda", (sx, yv(0.10), alt / 2.0), (sw, 0.12, alt),
            "QP_Serranda", raccolta=pezzi)
        n = max(5, int(alt / 0.32))
        for s in range(n):
            box("com_doga%d" % s, (sx, yv(0.18), 0.14 + s * (alt - 0.22) / n),
                (sw - 0.08, 0.06, 0.07), "QP_Cemento_Scuro", raccolta=pezzi)
        box("com_maniglia", (sx, yv(0.22), 0.55), (0.55, 0.06, 0.10),
            "QP_Metallo_Ruggine", raccolta=pezzi)
        px = luce_w / 2.0 - 0.60
        box("com_porta", (px, yv(0.06), luce_h / 2.0), (1.05, 0.09, luce_h),
            "QP_Metallo_Ruggine", raccolta=pezzi)
        box("com_porta_v", (px, yv(0.13), luce_h * 0.70), (0.62, 0.05, luce_h * 0.34),
            "QP_Vetro_Acceso", raccolta=pezzi)
    elif fronte == "barre":
        box("com_banc", (0, yv(0.10), 0.42), (luce_w, 0.32, 0.84),
            "QP_Mattone_Portico", raccolta=pezzi)
        vw = luce_w - 1.35
        zc = 0.84 + (luce_h - 0.84) / 2.0
        # Vetrina e non vetro spento: un negozio di liquori la sera e' aperto,
        # ed e' l'unica cosa accesa di quell'angolo di strada. Le barre
        # davanti restano, e sono proprio il contrasto che lo fa leggere.
        box("com_vetro", (-0.62, yv(0.09), zc), (vw, 0.05, luce_h - 0.96),
            "QP_Vetrina", raccolta=pezzi)
        for k in range(7):
            box("com_barra%d" % k, (-0.62 - vw / 2.0 + 0.12 + k * (vw - 0.24) / 6.0,
                                    yv(0.16), zc),
                (0.06, 0.06, luce_h - 0.96), "QP_Metallo_Ruggine", raccolta=pezzi)
        px = luce_w / 2.0 - 0.60
        box("com_porta", (px, yv(0.06), luce_h / 2.0), (1.00, 0.09, luce_h),
            "QP_Metallo_Ruggine", raccolta=pezzi)
    else:  # "ufficio"
        box("com_banc", (0, yv(0.10), 0.46), (luce_w, 0.32, 0.92),
            "QP_Cemento_Scuro", raccolta=pezzi)
        vw = luce_w / 2.0 - 0.95
        zc = 0.92 + (luce_h - 0.92) / 2.0
        for lato in (-1, 1):
            cx = lato * (luce_w / 4.0 + 0.28)
            box("com_tel%d" % lato, (cx, yv(0.05), zc), (vw + 0.14, 0.07, luce_h - 0.92),
                "QP_Infisso", raccolta=pezzi)
            box("com_vetro%d" % lato, (cx, yv(0.11), zc), (vw, 0.05, luce_h - 1.04),
                "QP_Vetrina", raccolta=pezzi)
            box("com_mont%d" % lato, (cx, yv(0.16), zc), (0.07, 0.05, luce_h - 1.04),
                "QP_Infisso", raccolta=pezzi)
        box("com_porta", (0, yv(0.06), luce_h / 2.0), (1.10, 0.09, luce_h),
            "QP_Porta_Casa", raccolta=pezzi)
        box("com_porta_v", (0, yv(0.13), luce_h * 0.68), (0.70, 0.05, luce_h * 0.42),
            "QP_Vetrina", raccolta=pezzi)

    # --- insegna sopra al fronte ----------------------------------------
    if S.get("insegna"):
        box("com_insegna_tel", (0, yf - 0.26, luce_h + 0.78), (W - 0.56, 0.14, 0.88),
            "QP_Metallo_Ruggine", raccolta=pezzi)
        box("com_insegna", (0, yf - 0.34, luce_h + 0.78), (W - 0.70, 0.18, 0.72),
            S["insegna"], raccolta=pezzi)
        for lato in (-1, 1):
            box("com_faro%d" % lato, (lato * (W / 2 - 1.5), yf - 0.48,
                                      luce_h + 1.26), (0.22, 0.26, 0.16),
                "QP_Vetro_Acceso", raccolta=pezzi)

    # --- tenda parasole --------------------------------------------------
    if S.get("tenda"):
        box("com_tenda", (0, yf - 0.62, luce_h + 0.14), (W - 0.80, 1.20, 0.14),
            S["tenda"], rot=(math.radians(-13), 0, 0), raccolta=pezzi)
        for lato in (-1, 1):
            box("com_tenda_br%d" % lato, (lato * (W / 2 - 0.9), yf - 0.32,
                                          luce_h - 0.04),
                (0.06, 0.70, 0.06), "QP_Metallo_Ruggine",
                rot=(math.radians(28), 0, 0), raccolta=pezzi)

    # --- piani sopra: finestre dentro alle nicchie ------------------------
    for piano in range(piani):
        z0 = h_t + piano * h_p
        abitato = rnd.random() < 0.65
        fondo_f = yf + REC_F

        def yw(dal_fondo):
            return fondo_f - dal_fondo

        for i in range(nf):
            cx = col_fin(i)
            zb = z0 + 0.82
            zc = zb + fh / 2.0
            box("com_fin_tel_%d_%d" % (piano, i), (cx, yw(0.03), zc),
                (fw, 0.07, fh), "QP_Infisso", raccolta=pezzi)
            stato = rnd.random()
            if abitato and stato < 0.25:
                vetro = "QP_Vetro_Acceso"
            elif stato < 0.42:
                vetro = "QP_Vetro_Rotto"
            else:
                vetro = "QP_Vetro_Scuro"
            box("com_fin_vet_%d_%d" % (piano, i), (cx, yw(0.08), zc),
                (fw - 0.14, 0.04, fh - 0.14), vetro, raccolta=pezzi)
            box("com_fin_mon_%d_%d" % (piano, i), (cx, yw(0.12), zc),
                (0.06, 0.04, fh - 0.14), "QP_Infisso", raccolta=pezzi)
            box("com_fin_cass_%d_%d" % (piano, i), (cx, yw(REC_F * 0.45),
                                                    zb + fh - 0.10),
                (fw, REC_F * 0.7, 0.20), "QP_Infisso", raccolta=pezzi)
            quota = rnd.choice([0.0, 0.0, 0.2, 0.5, 0.9])
            if quota > 0.02:
                ht = (fh - 0.22) * quota
                box("com_fin_tap_%d_%d" % (piano, i),
                    (cx, yw(REC_F * 0.45), zb + fh - 0.22 - ht / 2.0),
                    (fw - 0.06, 0.05, ht), rnd.choice(
                        ["QP_Tapparella", "QP_Tapparella_B", "QP_Tapparella_C"]),
                    raccolta=pezzi)
            # davanzale sporgente, fuori dal muro
            box("com_fin_dav_%d_%d" % (piano, i), (cx, yf - 0.09, zb - 0.07),
                (fw + 0.34, REC_F + 0.22, 0.10), "QP_Cemento", raccolta=pezzi)
            if abitato and rnd.random() < 0.3:
                box("com_clima_%d_%d" % (piano, i), (cx + 0.72, yf - 0.20,
                                                     zc + 0.1),
                    (0.66, 0.34, 0.46), "QP_Infisso", raccolta=pezzi)

    # --- niente marciapiede ------------------------------------------------
    # Qui c'era una lastra di marciapiede larga quanto l'edificio e profonda
    # 2,70 m, dentro allo sprite. E' stata tolta (2026-09-21) e la regola
    # adesso vale per tutti i modelli: **il marciapiede lo disegna il gioco.**
    #
    # Non e' una ripulita di stile, e' che un marciapiede disegnato dentro
    # all'edificio e' un marciapiede in piu' appoggiato sopra a quello vero di
    # `city_ground.gd`, con un grigio suo che non combacia e un bordo che si
    # vede. Ed e' anche terreno su cui il gioco crede che si cammini mentre lo
    # sprite dice un'altra cosa.
    #
    # Resta fuori il cortile recintato del condominio (`lotto()`): quello non
    # e' marciapiede, e' il lotto dell'edificio — sta dentro alla sua
    # recinzione e non c'entra con la strada.
    #
    # Conseguenza da sapere: senza la lastra il bordo inferiore dello sprite e'
    # la riga di terra del muro, e le ombre non hanno piu' niente su cui
    # cadere. E' giusto cosi' — l'ombra a terra la fara' il gioco, che e'
    # l'unico posto in cui puo' girare con il sole.
    #
    # Sono usciti con la lastra anche i sacchi della spazzatura e il bidone,
    # che ci stavano sopra, e non e' un di piu': erano arredo urbano dentro a
    # un edificio, cioe' la cosa che questo progetto non mette nei modelli
    # (vedi la nota in cima al file). E ci sarebbe stato anche un guaio
    # pratico — piazzati fino a un metro DAVANTI alla facciata, restavano il
    # punto piu' basso dello sprite e tiravano giu' il bordo inferiore di
    # sette-otto pixel sotto alla riga di terra del muro. Cioe' esattamente il
    # problema che si toglie via col marciapiede, in piccolo, e per giunta a
    # caso: quanti sacchi ci fossero lo decideva un `random`, quindi l'errore
    # era diverso per ogni edificio.

    return unisci(pezzi, "COM_Dettagli")


# ----------------------------------------------------------------------
#  la clinica (quartiere benestante)
# ----------------------------------------------------------------------

def _scava(muro, tagli):
    """Sottrae i cutter dal muro e riporta l'origine a (0,0,0).

    L'origine va rimessa a zero perche' `QB_Mattone` e `QB_Precast` leggono la
    Z in coordinate oggetto: lasciata a meta' muro, i corsi partirebbero da
    li' e i due corpi avrebbero i mattoni sfalsati fra loro.
    """
    cutter = unisci(tagli, "cutter_tmp")
    bpy.context.view_layer.objects.active = muro
    mod = muro.modifiers.new("Aperture", "BOOLEAN")
    mod.operation, mod.solver, mod.object = "DIFFERENCE", "EXACT", cutter
    bpy.ops.object.modifier_apply(modifier="Aperture")
    bpy.data.objects.remove(cutter, do_unlink=True)
    bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
    bpy.ops.object.select_all(action="DESELECT")
    muro.select_set(True)
    bpy.context.view_layer.objects.active = muro
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")


def _quote(S):
    """Le quote derivate, uguali per tutte e quattro le fasi della clinica."""
    W, D = S["larghezza"], S["profondita"]
    Wa, Da = S["ala_larghezza"], S["ala_profondita"]
    q = dict(
        W=W, D=D, H=S["h_terra"] + S["piani"] * S["h_piano"],
        yf=-D / 2.0,
        Wa=Wa, Da=Da, Ha=S["ala_altezza"],
        # L'ala sta a sinistra, a filo col fianco del corpo alto, e sporge in
        # avanti: il gradino in pianta e' quello che, vista da 27 gradi,
        # distingue due volumi invece di leggersi come un muro unico.
        xa=-W / 2.0 - Wa / 2.0,
    )
    q["yfa"] = q["yf"] - S["ala_sporgenza"]
    q["ya"] = q["yfa"] + Da / 2.0
    q["yp"] = q["yf"] - S["pensilina_sporgenza"]
    q["yb"] = q["yf"] - S["base_sporgenza"]
    return q


def clinica_corpo(S):
    """I due volumi, con le aperture scavate col boolean.

    Come per gli altri edifici la facciata guarda verso -Y e si dettaglia solo
    quella e il tetto: con la camera ruotata solo sull'asse X i fianchi sono
    esattamente di taglio e il retro e' coperto dall'edificio stesso.
    """
    q = _quote(S)
    SP = 0.40

    def taglia(nome, cx, cz, w, h, rec, faccia, lista):
        box(nome, (cx, faccia - SP / 2.0 + rec / 2.0, cz), (w, SP + rec, h),
            raccolta=lista)

    # --- corpo alto in mattone ------------------------------------------
    muro = box("CL_Corpo", (0, 0, q["H"] / 2.0), (q["W"], q["D"], q["H"]),
               "QB_Mattone")
    tagli = []
    taglia("t_atrio", S["x_atrio"], 0.15 + 4.20 / 2.0, S["w_atrio"], 4.20,
           0.45, q["yf"], tagli)
    for piano in range(S["piani"]):
        z0 = S["h_terra"] + piano * S["h_piano"]
        for i, cx in enumerate(S["colonne"]):
            taglia("t_f%d_%d" % (piano, i), cx, z0 + 1.75, 1.35, 1.60, 0.22,
                   q["yf"], tagli)
    _scava(muro, tagli)

    # --- ala bassa in prefabbricato -------------------------------------
    ala = box("CL_Ala", (q["xa"], q["ya"], q["Ha"] / 2.0),
              (q["Wa"], q["Da"], q["Ha"]), "QB_Precast")
    tagli = []
    # Finestra a nastro, non finestre punteggiate: e' la cosa che fa leggere
    # il corpo basso come moderno invece che come un capannone.
    taglia("t_nastro", q["xa"] - 0.55, 2.15, 4.60, 1.55, 0.25, q["yfa"], tagli)
    taglia("t_porta_ala", q["xa"] + 2.55, 1.25, 1.50, 2.50, 0.30, q["yfa"],
           tagli)
    _scava(ala, tagli)
    return q


def clinica_fronte(S):
    """Atrio vetrato, pensilina d'ingresso, marcapiani e insegne."""
    q = _quote(S)
    rnd = random.Random(S["seme"])
    p = []
    W, H, yf = q["W"], q["H"], q["yf"]
    xat, wat = S["x_atrio"], S["w_atrio"]

    # --- atrio vetrato ---------------------------------------------------
    # Il vetro sta in fondo alla nicchia e i montanti gli stanno DAVANTI. Se si
    # invertono, i montanti finiscono dentro al muro: nessun errore, solo una
    # vetrata liscia che non sembra una vetrata.
    yv = yf + 0.42
    box("cl_atrio_vetro", (xat, yv, 2.25), (wat - 0.10, 0.06, 4.20),
        "QB_Vetro_Atrio", raccolta=p)
    montanti = 7
    for i in range(1, montanti):
        box("cl_mont%d" % i, (xat - wat / 2.0 + wat * i / montanti, yv - 0.07,
                              2.25), (0.11, 0.10, 4.20), "QB_Infisso",
            raccolta=p)
    # Il traverso alto sta SOPRA la pensilina di proposito: e' la riga che,
    # nella fascia di vetro che resta visibile, dice che li' c'e' una vetrata
    # e non un buco scuro nel muro.
    box("cl_traverso", (xat, yv - 0.07, 3.78), (wat - 0.10, 0.10, 0.12),
        "QB_Infisso", raccolta=p)
    box("cl_atrio_arch", (xat, yv - 0.07, 4.22), (wat, 0.16, 0.26),
        "QB_Infisso", raccolta=p)
    for s in (-1, 1):
        box("cl_porta%d" % s, (xat + s * 0.62, yv - 0.12, 1.22),
            (1.16, 0.08, 2.44), "QB_Vetro", raccolta=p)
    box("cl_porta_mont", (xat, yv - 0.14, 1.22), (0.12, 0.12, 2.44),
        "QB_Alluminio", raccolta=p)
    box("cl_soglia", (xat, yf - 0.24, 0.07), (wat + 0.30, 0.98, 0.14),
        "QB_Cemento", raccolta=p)

    # --- pensilina -------------------------------------------------------
    # E' l'elemento che dice "clinica" prima di qualsiasi insegna: una lastra
    # piana che esce sul piazzale su pilastrini sottili. Nel quartiere povero
    # non c'e' niente del genere, ed e' li' che si vede il cambio di quartiere.
    yp, zp = q["yp"], S["pensilina_z"]
    wp = wat + 0.30
    ymed = (yf + yp) / 2.0
    prof = yf - yp
    box("cl_pen_lastra", (xat, ymed, zp - 0.17), (wp, prof, 0.34),
        "QB_Precast_Liscio", raccolta=p)
    box("cl_pen_soffitto", (xat, ymed + 0.10, zp - 0.38),
        (wp - 0.55, prof - 0.55, 0.07), "QB_Precast_Scuro", raccolta=p)
    box("cl_pen_fascia_f", (xat, yp + 0.14, zp - 0.31), (wp, 0.28, 0.62),
        "QB_Precast_Liscio", raccolta=p)
    for s in (-1, 1):
        box("cl_pen_fascia%d" % s, (xat + s * (wp / 2.0 - 0.14), ymed,
                                    zp - 0.31), (0.28, prof, 0.62),
            "QB_Precast_Liscio", raccolta=p)
    box("cl_pen_insegna", (xat, yp - 0.03, zp - 0.33), (5.20, 0.10, 0.40),
        "QB_Insegna_Verde", raccolta=p)
    box("cl_pen_insegna_t", (xat, yp - 0.10, zp - 0.33), (4.30, 0.06, 0.15),
        "QB_Insegna_Bianca", raccolta=p)
    for i in range(4):
        cilindro("cl_faretto%d" % i, (xat - 2.7 + i * 1.8, ymed + 0.10,
                                      zp - 0.44), 0.16, 0.06,
                 "QB_Vetro_Acceso", lati=8, raccolta=p)
    for cx in S["pilastri"]:
        box("cl_pil%d" % int(cx * 10), (cx, yp + 0.45, (zp - 0.48) / 2.0),
            (0.30, 0.30, zp - 0.48), "QB_Metallo_Bianco", raccolta=p)
        box("cl_pilb%d" % int(cx * 10), (cx, yp + 0.45, 0.09),
            (0.52, 0.52, 0.18), "QB_Cemento", raccolta=p)

    # --- facciata: zoccolo, marcapiani, finestre -------------------------
    box("cl_zoccolo", (0, yf + 0.07, 0.24), (W, 0.18, 0.48), "QB_Cemento_Scuro",
        raccolta=p)
    for piano in range(S["piani"]):
        z = S["h_terra"] + piano * S["h_piano"]
        box("cl_marcapiano%d" % piano, (0, yf - 0.09, z - 0.16),
            (W, 0.30, 0.32), "QB_Precast_Liscio", raccolta=p)

    for piano in range(S["piani"]):
        zc = S["h_terra"] + piano * S["h_piano"] + 1.75
        for i, cx in enumerate(S["colonne"]):
            acceso = rnd.random() < 0.35
            box("cl_v%d_%d" % (piano, i), (cx, yf + 0.20, zc),
                (1.35, 0.05, 1.60),
                "QB_Vetro_Acceso" if acceso else "QB_Vetro", raccolta=p)
            box("cl_vm%d_%d" % (piano, i), (cx, yf + 0.14, zc),
                (0.08, 0.08, 1.60), "QB_Infisso", raccolta=p)
            box("cl_vt%d_%d" % (piano, i), (cx, yf + 0.14, zc + 0.30),
                (1.35, 0.08, 0.08), "QB_Infisso", raccolta=p)
            box("cl_vd%d_%d" % (piano, i), (cx, yf - 0.07, zc - 0.86),
                (1.55, 0.32, 0.12), "QB_Precast_Liscio", raccolta=p)

    # --- insegna verticale sul mattone -----------------------------------
    # Prende la campata di destra al posto delle finestre, come il pannello
    # della foto: e' l'unico colore acceso di tutto l'edificio.
    bx = S["banner_x"]
    box("cl_banner", (bx, yf - 0.09, 7.40), (3.20, 0.18, 5.20),
        "QB_Insegna_Bordeaux", raccolta=p)
    box("cl_banner_logo", (bx, yf - 0.19, 9.40), (2.40, 0.06, 0.60),
        "QB_Insegna_Bianca", raccolta=p)
    for i in range(3):
        box("cl_banner_riga%d" % i, (bx, yf - 0.19, 8.30 - i * 0.75),
            (2.00 - i * 0.28, 0.05, 0.16), "QB_Insegna_Bianca", raccolta=p)

    # --- fronte dell'ala --------------------------------------------------
    xa, yfa, Ha = q["xa"], q["yfa"], q["Ha"]
    box("cl_ala_nastro_v", (xa - 0.55, yfa + 0.20, 2.15), (4.55, 0.05, 1.52),
        "QB_Vetro", raccolta=p)
    for i in range(1, 4):
        box("cl_ala_mont%d" % i, (xa - 0.55 - 2.30 + i * 1.15, yfa + 0.14,
                                  2.15), (0.09, 0.09, 1.52), "QB_Infisso",
            raccolta=p)
    box("cl_ala_dav", (xa - 0.55, yfa - 0.07, 1.32), (4.85, 0.32, 0.12),
        "QB_Precast_Liscio", raccolta=p)
    box("cl_ala_porta", (xa + 2.55, yfa + 0.22, 1.22), (1.44, 0.06, 2.44),
        "QB_Vetro", raccolta=p)
    box("cl_ala_porta_m", (xa + 2.55, yfa + 0.15, 1.22), (0.10, 0.10, 2.44),
        "QB_Alluminio", raccolta=p)
    # Banda rossa sopra la porta di servizio: e' l'"EMERGENCY" della foto,
    # ridotto a quello che a questa scala si legge davvero.
    box("cl_ala_insegna", (xa + 2.55, yfa - 0.08, 3.15), (2.10, 0.12, 0.44),
        "QB_Insegna_Rossa", raccolta=p)
    box("cl_ala_insegna_t", (xa + 2.55, yfa - 0.15, 3.15), (1.60, 0.05, 0.16),
        "QB_Insegna_Bianca", raccolta=p)
    box("cl_ala_zoccolo", (xa, yfa + 0.07, 0.20), (q["Wa"], 0.18, 0.40),
        "QB_Cemento_Scuro", raccolta=p)
    return unisci(p, "CL_Fronte")


def clinica_tetto(S):
    """Tetti piani: parapetti, impianti e vano scala.

    A 27 gradi il tetto e' un quinto dello sprite. Lasciarlo vuoto vuol dire
    spendere un quinto dell'immagine in un rettangolo grigio.
    """
    q = _quote(S)
    rnd = random.Random(S["seme"] + 7)
    p = []
    W, D, H = q["W"], q["D"], q["H"]

    def parapetto(nome, cx, cy, w, d, z, alt=0.60, sp=0.22):
        box(nome + "_f", (cx, cy - d / 2.0 + sp / 2.0, z + alt / 2.0),
            (w, sp, alt), "QB_Precast_Liscio", raccolta=p)
        box(nome + "_b", (cx, cy + d / 2.0 - sp / 2.0, z + alt / 2.0),
            (w, sp, alt), "QB_Precast_Liscio", raccolta=p)
        for s in (-1, 1):
            box(nome + "_l%d" % s, (cx + s * (w / 2.0 - sp / 2.0), cy,
                                    z + alt / 2.0), (sp, d, alt),
                "QB_Precast_Liscio", raccolta=p)
        # Il coprimuro e' una CORNICE, non una lastra piena. Fatto come un
        # unico box grande quanto la pianta diventa un coperchio: il tetto si
        # chiude sopra e manto, lucernari e base degli impianti spariscono
        # sotto, senza nessun errore e senza compenetrazioni visibili.
        cs = sp + 0.12
        zc = z + alt + 0.04
        box(nome + "_cap_f", (cx, cy - d / 2.0 + sp / 2.0, zc),
            (w + 0.12, cs, 0.09), "QB_Cemento", raccolta=p)
        box(nome + "_cap_b", (cx, cy + d / 2.0 - sp / 2.0, zc),
            (w + 0.12, cs, 0.09), "QB_Cemento", raccolta=p)
        for s in (-1, 1):
            box(nome + "_cap_l%d" % s, (cx + s * (w / 2.0 - sp / 2.0), cy, zc),
                (cs, d + 0.12, 0.09), "QB_Cemento", raccolta=p)

    box("cl_manto", (0, 0, H + 0.04), (W - 0.06, D - 0.06, 0.08), "QB_Guaina",
        raccolta=p)
    parapetto("cl_par", 0, 0, W, D, H + 0.08)

    # Lucernari sulla meta' anteriore. A 27 gradi quella e' la parte di tetto
    # che si vede di piu', e lasciata liscia era un rettangolo grigio grande
    # come un piano dell'edificio.
    y_luc = -D * 0.29
    for i, cx in enumerate((-5.40, -1.80, 1.80, 5.40)):
        box("cl_luc_b%d" % i, (cx, y_luc, H + 0.08 + 0.11), (1.80, 1.35, 0.22),
            "QB_Precast_Liscio", raccolta=p)
        box("cl_luc%d" % i, (cx, y_luc, H + 0.08 + 0.26), (1.55, 1.10, 0.10),
            "QB_Vetro", raccolta=p)

    # vano scala/ascensore
    y_vano = D * 0.13
    box("cl_vano", (3.60, y_vano, H + 0.08 + 1.30), (3.40, 3.10, 2.60),
        "QB_Precast", raccolta=p)
    box("cl_vano_cap", (3.60, y_vano, H + 0.08 + 2.66), (3.60, 3.30, 0.14),
        "QB_Cemento", raccolta=p)
    box("cl_vano_porta", (3.60, y_vano - 1.60, H + 0.08 + 1.05),
        (1.10, 0.10, 2.10), "QB_Alluminio", raccolta=p)

    # gruppi di trattamento aria, dietro a un grigliato: in un quartiere
    # benestante gli impianti si nascondono, ed e' un dettaglio che si legge.
    y_uta = D * 0.16
    for i, cx in enumerate((-5.60, -2.90, -0.20)):
        box("cl_uta%d" % i, (cx, y_uta, H + 0.08 + 0.58), (2.10, 1.60, 1.16),
            "QB_Acciaio", raccolta=p)
        box("cl_uta_cap%d" % i, (cx, y_uta, H + 0.08 + 1.22), (2.20, 1.70, 0.12),
            "QB_Metallo_Bianco", raccolta=p)
    box("cl_grigliato", (-2.90, y_uta - 1.15, H + 0.08 + 0.85), (8.20, 0.10, 1.70),
        "QB_Alluminio", raccolta=p)
    for s in (-1, 1):
        box("cl_grigliato%d" % s, (-2.90 + s * 4.05, y_uta, H + 0.08 + 0.85),
            (0.10, 2.20, 1.70), "QB_Alluminio", raccolta=p)
    for i in range(3):
        cilindro("cl_camino%d" % i, (rnd.uniform(-6.0, 6.0),
                                     rnd.uniform(D * 0.34, D * 0.45),
                                     H + 0.08 + 0.45), 0.22, 0.90,
                 "QB_Acciaio", lati=10, raccolta=p)

    # --- tetto dell'ala ---------------------------------------------------
    xa, ya, Wa, Da, Ha = q["xa"], q["ya"], q["Wa"], q["Da"], q["Ha"]
    box("cl_ala_manto", (xa, ya, Ha + 0.04), (Wa - 0.06, Da - 0.06, 0.08),
        "QB_Guaina", raccolta=p)
    parapetto("cl_ala_par", xa, ya, Wa, Da, Ha + 0.08, alt=0.46, sp=0.20)
    for i, off in enumerate((-1.5, 0.9)):
        box("cl_ala_uta%d" % i, (xa + off, ya + 1.0, Ha + 0.08 + 0.42),
            (1.50, 1.20, 0.84), "QB_Acciaio", raccolta=p)
    return unisci(p, "CL_Tetto")


def clinica_base(S):
    """Il piazzale davanti all'ingresso, e nient'altro.

    Niente verde e niente arredo: alberi, siepi e aiuole arrivano in gioco
    come asset separati, e i lampioni li piazza gia' la citta'
    (`street_lamp.gd`). Metterli dentro allo sprite vorrebbe dire averli
    sempre identici e sempre negli stessi due punti, in ogni copia
    dell'edificio.

    Quello che resta e' il minimo perche' l'edificio non galleggi: la lastra
    su cui poggiano i pilastri della pensilina e un bordo davanti che da' allo
    sprite lo stesso filo inferiore degli altri edifici.
    """
    q = _quote(S)
    p = []
    x0, x1 = S["base_x"]
    y0 = q["yb"]
    y1 = q["D"] / 2.0

    box("cl_piazzale", ((x0 + x1) / 2.0, (y0 + y1) / 2.0, -0.06),
        (x1 - x0, y1 - y0, 0.12), "QB_Asfalto", raccolta=p)
    box("cl_cordolo", ((x0 + x1) / 2.0, y0 + 0.16, 0.05), (x1 - x0, 0.32, 0.22),
        "QB_Cordolo", raccolta=p)
    # Camminamento rialzato lungo la facciata: separa la corsia dell'ingresso
    # dal muro e da' un appoggio ai dissuasori.
    box("cl_camminamento", (0, q["yf"] - 0.85, 0.05), (q["W"], 1.70, 0.22),
        "QB_Marciapiede", raccolta=p)
    box("cl_camminamento_ala", (q["xa"], q["yfa"] - 0.85, 0.05),
        (q["Wa"], 1.70, 0.22), "QB_Marciapiede", raccolta=p)

    for i in range(4):
        cilindro("cl_dissuasore%d" % i, (S["x_atrio"] - 3.0 + i * 2.0,
                                         q["yf"] - 1.45, 0.53),
                 0.11, 0.84, "QB_Acciaio", lati=8, raccolta=p)
    return unisci(p, "CL_Base")


# ----------------------------------------------------------------------
#  il campo da football abbandonato
# ----------------------------------------------------------------------
#
# Qui ci sono solo le STRUTTURE: gradinata, torre faro, porte. L'erba non e'
# un render — la disegna Godot con uno shader (`grass_field.gdshader`), perche'
# e' una superficie piatta grande quanto mezzo isolato e deve muoversi col
# vento. Fotografata da Blender sarebbe un PNG enorme e immobile, e il verde
# cartoonesco che serve qui lo si ottiene meglio con quattro tinte quantizzate
# che con della geometria.
#
# Niente erbacce nemmeno dentro a queste strutture, per la stessa regola degli
# edifici: il degrado lo fanno crepe, macchie, ruggine e calcinacci, e l'erba
# che cresce attorno ci arriva sopra dallo shader.

def gradinata(S):
    """La curva: un banco di gradoni di cemento con il muro di fondo.

    Guarda a SUD, verso il campo: la camera sta a -Y e i gradoni salgono
    allontanandosi, quindi si vedono le pedate una dietro l'altra. Girata al
    contrario si vedrebbe solo il retro del muro, che e' un rettangolo grigio.

    I gradoni sono spezzati in segmenti lungo la larghezza e non tirati da
    parte a parte, perche' e' l'unico modo di farne mancare qualcuno: una
    gradinata intera con una crepa disegnata sopra si legge come una gradinata
    in ordine, una a cui manca un pezzo di terzo gradone si legge come
    abbandonata.
    """
    rnd = random.Random(S["seme"])
    W = S["larghezza"]
    n, alz, ped = S["gradoni"], S["alzata"], S["pedata"]
    p = []

    # parapetto basso sul fronte campo
    y0 = -S["profondita"] / 2.0
    box("gr_parapetto", (0, y0 + 0.13, 0.28), (W, 0.26, 0.56), "QP_Cemento",
        raccolta=p)
    box("gr_parapetto_cap", (0, y0 + 0.13, 0.59), (W + 0.10, 0.34, 0.08),
        "QP_Cemento_Scuro", raccolta=p)

    # I camminamenti: due scalette verticali che tagliano i gradoni. Sono le
    # uniche parti dipinte, ed e' da li' che la gradinata si riconosce.
    vomitori = S["camminamenti"]
    seg = S["segmenti"]
    larg_seg = W / seg

    for k in range(n):
        yk = y0 + 0.26 + k * ped
        zt = 0.56 + (k + 1) * alz
        rotti = [rnd.random() < 0.085 for _ in range(seg)]
        # I segmenti interi vanno fusi in tratte uniche prima di diventare
        # geometria. Emessi uno per uno sarebbero dodici cuciture per fila, e
        # Freestyle disegna una riga su ognuna: la gradinata verrebbe
        # piastrellata a quadretti invece che a gradoni.
        i = 0
        while i < seg:
            if rotti[i]:
                cx = -W / 2.0 + larg_seg * (i + 0.5)
                h = zt - alz * 0.45
                largo = larg_seg - rnd.uniform(0.25, 0.6)
                box("gr_rotto_%d_%d" % (k, i), (cx, yk + ped / 2.0, h / 2.0),
                    (largo, ped, h), "QP_Cemento", raccolta=p)
                i += 1
                continue
            j = i
            while j < seg and not rotti[j]:
                j += 1
            x_da = -W / 2.0 + larg_seg * i
            x_a = -W / 2.0 + larg_seg * j
            largo = x_a - x_da
            cx = (x_da + x_a) / 2.0
            box("gr_%d_%d" % (k, i), (cx, yk + ped / 2.0, zt / 2.0),
                (largo, ped, zt), "QP_Cemento", raccolta=p)
            # naso del gradone, piu' scuro: e' la riga d'ombra che a questa
            # scala fa contare i gradoni
            box("gr_naso_%d_%d" % (k, i), (cx, yk + 0.04, zt - 0.05),
                (largo, 0.10, 0.10), "QP_Cemento_Scuro", raccolta=p)
            i = j
        for vx in vomitori:
            box("gr_giallo_%d_%.0f" % (k, vx * 10), (vx, yk + 0.05, zt - 0.04),
                (S["camminamento_largo"], 0.12, 0.09), "QP_Vernice_Gialla",
                raccolta=p)

    # muro di fondo e sua copertina
    z_alto = 0.56 + n * alz
    yb = y0 + 0.26 + n * ped
    h_muro = z_alto + S["muro_alto"]
    box("gr_muro", (0, yb + 0.30, h_muro / 2.0), (W, 0.60, h_muro),
        "QP_Cemento_Scuro", raccolta=p)
    box("gr_muro_cap", (0, yb + 0.30, h_muro + 0.06), (W + 0.14, 0.74, 0.12),
        "QP_Cemento", raccolta=p)

    # pali della ringhiera in cima, quasi tutti piegati o mancanti
    for i in range(int(W / 1.6)):
        if rnd.random() < 0.3:
            continue
        px = -W / 2.0 + 0.8 + i * 1.6
        inc = math.radians(rnd.uniform(-14, 14))
        cilindro("gr_palo%d" % i, (px, yb + 0.30, h_muro + 0.55), 0.05, 0.90,
                 "QP_Metallo_Ruggine", lati=6, rot=(inc, 0, 0), raccolta=p)

    # calcinacci ai piedi della gradinata
    for i in range(9):
        w = rnd.uniform(0.18, 0.5)
        box("gr_detrito%d" % i, (rnd.uniform(-W / 2 + 0.4, W / 2 - 0.4),
                                 y0 - rnd.uniform(0.1, 0.9), w * 0.22),
            (w, w * 0.7, w * 0.45), "QP_Cemento_Scuro",
            rot=(0, 0, math.radians(rnd.uniform(0, 90))), raccolta=p)
    return unisci(p, "Gradinata")


def torre_faro(S):
    """Il palo della luce: traliccio a quattro montanti e testata di lampade.

    E' l'elemento che dice "stadio" da lontano piu' di qualunque altro, ed e'
    anche l'unica cosa alta del campo: a sedici metri sbuca sopra ai tetti del
    quartiere e si vede da due isolati.

    Il traliccio e' fatto di montanti veri e non di un cono liscio: a questa
    scala i diagonali sono due pixel, ma sono i due pixel che distinguono una
    torre faro da un lampione gigante — e Freestyle ci disegna sopra il
    contorno scuro, quindi si leggono.
    """
    rnd = random.Random(S["seme"])
    H = S["altezza"]
    liv = S["livelli"]
    b_giu, b_su = S["base_larga"] / 2.0, S["cima_larga"] / 2.0
    p = []

    box("tf_plinto", (0, 0, 0.45), (1.70, 1.70, 0.90), "QP_Cemento",
        raccolta=p)
    box("tf_plinto_cap", (0, 0, 0.94), (1.90, 1.90, 0.10), "QP_Cemento_Scuro",
        raccolta=p)

    def mezzo(z):
        """Mezza larghezza del traliccio alla quota z: rastrema salendo."""
        return b_giu + (b_su - b_giu) * (z / H)

    z0 = 0.90
    passo = (H - z0) / liv
    for lato_x in (-1, 1):
        for lato_y in (-1, 1):
            for k in range(liv):
                za, zb = z0 + k * passo, z0 + (k + 1) * passo
                ma, mb = mezzo(za), mezzo(zb)
                # Il montante e' inclinato, quindi non e' un box dritto: lo si
                # mette al centro del tratto e lo si ruota di quanto rientra.
                dx = (mb - ma)
                lung = math.sqrt(passo * passo + dx * dx)
                ang = math.atan2(dx, passo)
                box("tf_mont_%d%d_%d" % (lato_x, lato_y, k),
                    (lato_x * (ma + mb) / 2.0, lato_y * (ma + mb) / 2.0,
                     (za + zb) / 2.0),
                    (0.13, 0.13, lung),
                    "QP_Zincato",
                    rot=(lato_y * -ang, lato_x * ang, 0), raccolta=p)

    # traversi e diagonali sulle due facce che si vedono (fronte e fianchi
    # sono di taglio: basta la faccia verso la camera e quella di dietro)
    for k in range(liv + 1):
        z = z0 + k * passo
        m = mezzo(z)
        for lato_y in (-1, 1):
            box("tf_trav_%d_%d" % (k, lato_y), (0, lato_y * m, z),
                (m * 2.0, 0.09, 0.09), "QP_Zincato", raccolta=p)
        for lato_x in (-1, 1):
            box("tf_travx_%d_%d" % (k, lato_x), (lato_x * m, 0, z),
                (0.09, m * 2.0, 0.09), "QP_Zincato", raccolta=p)
        if k >= liv:
            continue
        zb = z0 + (k + 1) * passo
        mb = mezzo(zb)
        corsa = m + mb
        salita = zb - z
        diag = math.sqrt(salita * salita + corsa * corsa)
        # Il verso si alterna a ogni livello: e' quello che fa lo zig-zag del
        # traliccio invece di una scala di sbarre tutte parallele.
        verso = 1.0 if k % 2 else -1.0
        # Box lungo sull'asse X inclinato nel piano XZ: la rotazione e' attorno
        # a Y, negativa perche' ruotando di +Y la X scende in Z.
        ang = -math.atan2(salita, corsa) * verso
        for lato_y in (-1, 1):
            box("tf_diag_%d_%d" % (k, lato_y),
                ((mb - m) / 2.0, lato_y * corsa / 2.0, (z + zb) / 2.0),
                (diag, 0.07, 0.07), "QP_Zincato", rot=(0, ang, 0), raccolta=p)

    # testata: telaio inclinato verso il campo con la griglia di lampade
    zt = H + 0.30
    incl = math.radians(-24.0)
    tw, th = S["testa_larga"], S["testa_alta"]
    box("tf_telaio", (0, -0.45, zt), (tw, 0.22, th), "QP_Zincato",
        rot=(incl, 0, 0), raccolta=p)
    nx, nz = S["lampade"]
    for ix in range(nx):
        for iz in range(nz):
            lx = -tw / 2.0 + tw * (ix + 0.5) / nx
            lz = -th / 2.0 + th * (iz + 0.5) / nz
            box("tf_lamp_%d_%d" % (ix, iz),
                (lx, -0.45 - 0.14 - lz * math.sin(incl),
                 zt + lz * math.cos(incl)),
                (tw / nx - 0.09, 0.10, th / nz - 0.09), "QP_Faro_Lampada",
                rot=(incl, 0, 0), raccolta=p)
    # scaletta di servizio, un montante con i pioli
    for i in range(int((H - 1.2) / 0.55)):
        z = 1.2 + i * 0.55
        box("tf_piolo%d" % i, (0, mezzo(z) + 0.12, z), (0.44, 0.05, 0.05),
            "QP_Metallo_Ruggine", raccolta=p)
    return unisci(p, "TorreFaro")


def porta_campo(S):
    """Una porta sfondata: telaio storto, niente rete.

    Senza rete di proposito. Una rete e' la prima cosa che sparisce da un campo
    lasciato andare, e modellarla vorrebbe dire o un piano pieno — che si legge
    come un muro — o una griglia di bacchette che a questa scala diventa una
    macchia grigia. Il telaio piegato dice la stessa cosa e si legge.
    """
    rnd = random.Random(S["seme"])
    W, H = S["larghezza"], S["altezza"]
    p = []
    pend = math.radians(S["storto"])

    for lato in (-1, 1):
        # un palo dritto e uno piegato: e' l'asimmetria a dire che e' rotta
        inc = pend if lato > 0 else 0.0
        box("pt_palo%d" % lato, (lato * W / 2.0, 0, H / 2.0),
            (0.13, 0.13, H), "QP_Zincato", rot=(0, inc, 0), raccolta=p)
        box("pt_piede%d" % lato, (lato * W / 2.0, 0, 0.06), (0.34, 0.34, 0.12),
            "QP_Cemento_Scuro", raccolta=p)
    # la traversa segue il palo storto: si abbassa da un lato
    calo = math.sin(pend) * H
    box("pt_traversa", (calo / 2.0, 0, H - 0.06), (W + 0.13, 0.13, 0.13),
        "QP_Zincato", rot=(0, math.atan2(calo * 0.5, W), 0), raccolta=p)
    # moncherini dei tiranti posteriori, piegati
    for lato in (-1, 1):
        box("pt_tirante%d" % lato, (lato * W / 2.0, 0.55, 0.45),
            (0.09, 1.20, 0.09), "QP_Metallo_Ruggine",
            rot=(math.radians(38), 0, 0), raccolta=p)
    for i in range(4):
        w = rnd.uniform(0.12, 0.3)
        box("pt_detrito%d" % i, (rnd.uniform(-W / 2, W / 2),
                                 rnd.uniform(-0.5, 0.8), w * 0.2),
            (w, w * 0.8, w * 0.4), "QP_Cemento_Scuro",
            rot=(0, 0, math.radians(rnd.uniform(0, 90))), raccolta=p)
    return unisci(p, "Porta")


# ----------------------------------------------------------------------
#  il grossista di DOWNTOWN
# ----------------------------------------------------------------------
#
# Il magazzino all'ingrosso da cui Brian prende i semi, e da cui piu' avanti
# li compra anche il protagonista. E' il primo edificio di DOWNTOWN, quindi
# e' anche il posto dove si decide che aspetto ha il quartiere: palette DT_,
# stessa inclinazione e stessi contorni di tutto il resto.
#
# La forma viene dal capannone all'ingrosso americano, e le tre cose che lo
# fanno riconoscere sono sempre le stesse:
#
# - **due fasce.** Basamento in mattone rosso fino a quattro metri, intonaco
#   beige sopra. Non e' decorazione: e' la riga orizzontale che tiene insieme
#   una facciata larga ventidue metri e le impedisce di leggersi come un muro.
# - **le lesene.** Senza, la facciata e' un rettangolo lungo. Con le lesene
#   ogni campata e' una cosa sola col suo portone, e a duecento pixel si
#   contano le campate invece di vedere un muro.
# - **il corpo centrale rialzato.** E' quello che porta l'insegna e che dice
#   dov'e' la porta da lontano. Un capannone tutto della stessa altezza non
#   ha un ingresso, ha un lato.
#
# L'ala bassa a sinistra e' arretrata di un metro: il gradino in pianta, visto
# da 27 gradi, e' quello che fa leggere due volumi invece di una stecca sola.
#
# **Niente proiezione obliqua.** Provata: una matrice di taglio che sposta la x
# di un decimo per ogni metro di profondita', facciata ferma (sta tutta alla
# stessa y, quindi trasla in blocco) e tetto e fianco che scivolano a sinistra.
# Sulla carta e' la cosa giusta — il fianco si vede e l'edificio ha uno
# spessore — e in citta' non funziona: la facciata resta parallela alla strada
# ma tutto il resto no, marciapiede del disegno compreso, che da rettangolo
# diventa un parallelogramma appoggiato di sbieco su un marciapiede dritto.
# L'edificio si legge storto accanto ai vicini, che sono frontali. Qui la
# regola e' una sola e vale per tutti: facciata parallela al marciapiede, e il
# rilievo lo danno l'inclinazione della camera e le ombre, non la pianta.


def _mag_quote(S):
    """Le quote derivate, uguali per tutte e quattro le fasi del magazzino."""
    W, D = S["larghezza"], S["profondita"]
    Wa, Da = S["ala_larghezza"], S["ala_profondita"]
    q = dict(W=W, D=D, H=S["h_muro"], yf=-D / 2.0, Wa=Wa, Da=Da,
             Ha=S["ala_altezza"])
    # L'insieme e' centrato su x=0 perche' l'origine dell'edificio e' il punto
    # a terra al centro della facciata, ed e' da li' che `import_flats_art.py`
    # calcola l'offset dello sprite (meta' larghezza per parte). Il corpo alto
    # sta quindi spostato a destra di mezza ala, non nell'origine.
    q["xc"] = Wa / 2.0
    q["xa"] = q["xc"] - W / 2.0 - Wa / 2.0
    # L'ala e' arretrata: il suo fronte sta PIU' INDIETRO di quello del corpo.
    q["yfa"] = q["yf"] + S["ala_arretramento"]
    q["ya"] = q["yfa"] + Da / 2.0
    return q


def _mag_tagli(S, q, lista):
    """I cutter delle aperture del fronte, ricostruiti a ogni chiamata.

    Servono due volte — una per il muro, una per il basamento in mattone, che
    sono due oggetti distinti — e `_scava` consuma i cutter unendoli. Farne
    una copia con `duplicate` lascerebbe in giro mesh orfane; ricostruirli e'
    sei box.
    """
    SP = 0.60
    yf, xc = q["yf"], q["xc"]

    def taglia(nome, cx, cz, w, h, rec):
        box(nome, (cx, yf - SP / 2.0 + rec / 2.0, cz), (w, SP + rec, h),
            raccolta=lista)

    for i, (dx, w) in enumerate(S["portoni"]):
        taglia("mg_t_portone%d" % i, xc + dx,
               S["portone_sotto"] + S["portone_h"] / 2.0, w, S["portone_h"],
               S["portone_rec"])
    taglia("mg_t_ingresso", xc, S["ingresso_h"] / 2.0, S["ingresso_w"],
           S["ingresso_h"], S["ingresso_rec"])
    return lista


def magazzino_corpo(S):
    """I due volumi, il basamento in mattone e le aperture scavate."""
    q = _mag_quote(S)
    W, D, H, xc, yf = q["W"], q["D"], q["H"], q["xc"], q["yf"]

    # --- corpo alto ------------------------------------------------------
    muro = box("MG_Corpo", (xc, 0, H / 2.0), (W, D, H), "DT_Intonaco")
    _scava(muro, _mag_tagli(S, q, []))

    # Il basamento e' un guscio davanti al muro e non una fascia di materiale
    # diverso sullo stesso box: sporge di dodici centimetri, e a 27 gradi
    # quella sporgenza e' la riga d'ombra che divide le due fasce. Dipinta
    # sarebbe una banda di colore, non un basamento.
    hb = S["h_mattone"]
    zoc = box("MG_Zoccolo", (xc, yf + 0.06, hb / 2.0), (W, 0.24, hb),
              "DT_Mattone")
    _scava(zoc, _mag_tagli(S, q, []))

    # --- ala bassa -------------------------------------------------------
    xa, ya, Wa, Da, Ha = q["xa"], q["ya"], q["Wa"], q["Da"], q["Ha"]
    yfa = q["yfa"]
    ala = box("MG_Ala", (xa, ya, Ha / 2.0), (Wa, Da, Ha), "DT_Intonaco")
    tagli = []
    box("mg_t_porta_ala", (xa + 1.85, yfa + 0.10, 1.15), (1.30, 0.80, 2.30),
        raccolta=tagli)
    box("mg_t_fin_ala", (xa - 1.55, yfa + 0.10, 2.30), (2.80, 0.80, 1.10),
        raccolta=tagli)
    _scava(ala, tagli)
    zoc_a = box("MG_Zoccolo_Ala", (xa, yfa + 0.06, hb / 2.0), (Wa, 0.24, hb),
                "DT_Mattone")
    tagli = []
    box("mg_t2_porta_ala", (xa + 1.85, yfa + 0.10, 1.15), (1.30, 0.80, 2.30),
        raccolta=tagli)
    box("mg_t2_fin_ala", (xa - 1.55, yfa + 0.10, 2.30), (2.80, 0.80, 1.10),
        raccolta=tagli)
    _scava(zoc_a, tagli)
    return q


def magazzino_fronte(S):
    """Lesene, portoni vetrati, ingresso con l'arco e il corpo dell'insegna."""
    q = _mag_quote(S)
    p = []
    W, H, xc, yf = q["W"], q["H"], q["xc"], q["yf"]
    hb = S["h_mattone"]
    sp = S["lesena_sp"]
    yl = yf - sp / 2.0

    # --- lesene ----------------------------------------------------------
    # Mattone chiaro fino sotto la cornice, capitello in pietra sopra: e' il
    # capitello a chiuderle, altrimenti sembrano colonne tagliate.
    for i, dx in enumerate(S["lesene"]):
        x = xc + dx
        box("mg_lesena%d" % i, (x, yl, S["lesena_h"] / 2.0),
            (S["lesena_w"], sp, S["lesena_h"]), "DT_Mattone_Chiaro",
            raccolta=p)
        box("mg_capitello%d" % i, (x, yl - 0.05, S["lesena_h"] + 0.19),
            (S["lesena_w"] + 0.22, sp + 0.10, 0.38), "DT_Cornice", raccolta=p)

    # --- portoni vetrati -------------------------------------------------
    # Il vetro sta in fondo alla nicchia e i montanti gli stanno DAVANTI: al
    # contrario finirebbero dentro al muro e resterebbe una lastra liscia.
    for i, (dx, w) in enumerate(S["portoni"]):
        x = xc + dx
        z0, h = S["portone_sotto"], S["portone_h"]
        yv = yf + S["portone_rec"] - 0.06
        box("mg_vetro%d" % i, (x, yv, z0 + h / 2.0), (w - 0.12, 0.06, h - 0.10),
            "DT_Vetro", raccolta=p)
        # Griglia da portone sezionale: tre file di pannelli, due montanti.
        for k in range(1, 3):
            box("mg_mont%d_%d" % (i, k), (x - w / 2.0 + w * k / 3.0, yv - 0.07,
                                          z0 + h / 2.0), (0.09, 0.10, h - 0.10),
                "DT_Infisso", raccolta=p)
        for k in range(1, 3):
            box("mg_trav%d_%d" % (i, k), (x, yv - 0.07, z0 + h * k / 3.0),
                (w - 0.12, 0.10, 0.09), "DT_Infisso", raccolta=p)
        # Architrave in pietra sopra la campata: e' quello che fa leggere il
        # buco come un'apertura invece che come una macchia scura.
        box("mg_arch%d" % i, (x, yf - 0.10, z0 + h + 0.17),
            (w + 0.42, 0.28, 0.34), "DT_Cornice", raccolta=p)

    # --- marcapiano ------------------------------------------------------
    # La riga di pietra in cima al basamento, da un capo all'altro del fronte.
    # E' l'unica cosa orizzontale che passa DAVANTI alle lesene, e serve
    # esattamente a quello: senza, la facciata e' sei lesene verticali e
    # nient'altro, e l'occhio non ha niente che la tenga insieme.
    box("mg_marcapiano", (xc, yf - 0.10, hb + 0.15), (W + 0.16, 0.38, 0.30),
        "DT_Cornice", raccolta=p)

    # --- ingresso --------------------------------------------------------
    wi, hi, rec = S["ingresso_w"], S["ingresso_h"], S["ingresso_rec"]
    yv = yf + rec - 0.08
    box("mg_ing_vetro", (xc, yv, hi / 2.0), (wi - 0.10, 0.06, hi - 0.08),
        "DT_Vetro_Ingresso", raccolta=p)
    ante = 6
    for k in range(1, ante):
        box("mg_ing_mont%d" % k, (xc - wi / 2.0 + wi * k / ante, yv - 0.07,
                                  hi / 2.0), (0.11, 0.11, hi - 0.08),
            "DT_Infisso", raccolta=p)
    # Il traverso alto divide le ante dal sopraluce: senza, l'ingresso e' una
    # vetrata alta quattro metri e non si capisce dove sia la porta.
    box("mg_ing_trav", (xc, yv - 0.07, 2.30), (wi - 0.10, 0.12, 0.14),
        "DT_Infisso", raccolta=p)
    box("mg_ing_soglia", (xc, yf + rec / 2.0, 0.05), (wi, rec, 0.10),
        "DT_Cemento", raccolta=p)

    # --- l'arco sopra l'ingresso -----------------------------------------
    # Sta davanti al muro e sporge in avanti: e' l'unica curva di tutto
    # l'edificio, ed e' quello che si guarda per primo.
    c = S["arco_corda"] / 2.0
    r = S["arco_freccia"]
    R = (c * c + r * r) / (2.0 * r)
    zc = S["arco_imposta"] + r - R
    tmax = math.asin(min(1.0, c / R))
    n = 16
    ya = yf - S["arco_sporgenza"] / 2.0
    for i in range(n):
        t = -tmax + (i + 0.5) * (2 * tmax / n)
        seg = R * (2 * tmax / n) * 1.06
        box("mg_arco%d" % i, (xc + R * math.sin(t), ya, zc + R * math.cos(t)),
            (seg, S["arco_sporgenza"], 0.26), "DT_Metallo_Scuro",
            rot=(0.0, t, 0.0), raccolta=p)
    for s in (-1, 1):
        box("mg_arco_piede%d" % s, (xc + s * c, ya, S["arco_imposta"] / 2.0),
            (0.30, S["arco_sporgenza"] * 0.55, S["arco_imposta"]),
            "DT_Metallo_Scuro", raccolta=p)

    # --- cornicione e attico ---------------------------------------------
    # Due pezzi e non uno: gola e fascia. Un cornicione fatto con un box solo
    # e' uno spigolo, e a 27 gradi non fa ombra sulla facciata.
    def cornicione(nome, cx, w, z, sporgenza=0.34, alt=0.42):
        box(nome + "_gola", (cx, yf - sporgenza / 2.0, z + alt / 2.0),
            (w, sporgenza, alt), "DT_Cornice", raccolta=p)
        box(nome + "_fascia", (cx, yf - sporgenza * 0.30, z + alt + 0.09),
            (w + 0.14, sporgenza * 0.78, 0.18), "DT_Cornice_Scura", raccolta=p)

    cornicione("mg_corn", xc, W + 0.10, H - 0.60)

    # --- corpo centrale rialzato -----------------------------------------
    wt, ht = S["timpano_w"], S["timpano_h"]
    box("mg_timpano", (xc, yf + 0.55, (H + ht) / 2.0), (wt, 1.10, ht - H),
        "DT_Intonaco_Liscio", raccolta=p)
    # I due gradini laterali: il salto secco da otto a dieci metri e mezzo
    # taglia la facciata in due, il gradino la fa salire.
    for s in (-1, 1):
        box("mg_gradino%d" % s, (xc + s * (wt / 2.0 + S["gradino_w"] / 2.0),
                                 yf + 0.55, (H + S["gradino_h"]) / 2.0),
            (S["gradino_w"], 1.10, S["gradino_h"] - H), "DT_Intonaco_Liscio",
            raccolta=p)
        cornicione("mg_grad_corn%d" % s,
                   xc + s * (wt / 2.0 + S["gradino_w"] / 2.0),
                   S["gradino_w"] + 0.10, S["gradino_h"] - 0.55,
                   sporgenza=0.30, alt=0.36)
    cornicione("mg_tim_corn", xc, wt + 0.10, ht - 0.62)

    # --- l'insegna -------------------------------------------------------
    # Solo il pannello: la scritta e' un PNG appeso in gioco (`make_signs.py`),
    # perche' questo modello si rifotografa e una scritta dipinta qui sopra
    # sparirebbe al primo re-import senza che nessuno se ne accorga.
    # La fascia blu sta nella meta' BASSA del campo e non al centro: sopra
    # deve restare del panna vuoto, che e' quello che fa leggere il pannello
    # come un'insegna e non come una finestra dipinta di blu.
    zi, wi_, hi_ = S["insegna_z"], S["insegna_w"], S["insegna_h"]
    box("mg_insegna_campo", (xc, yf - 0.05, zi), (wi_, 0.10, hi_),
        "DT_Insegna_Campo", raccolta=p)
    z_fascia = zi - hi_ / 2.0 + S["fascia_h"] / 2.0 + 0.30
    box("mg_insegna_fascia", (xc, yf - 0.13, z_fascia),
        (wi_ - 0.80, 0.08, S["fascia_h"]), "DT_Insegna_Fascia", raccolta=p)
    box("mg_insegna_filo", (xc, yf - 0.13, z_fascia + S["fascia_h"] / 2.0 + 0.26),
        (wi_ - 0.80, 0.08, 0.16), "DT_Insegna_Rossa", raccolta=p)

    # --- lampade a muro --------------------------------------------------
    # Una per lesena scelta, sopra il basamento: di notte la luce in citta' la
    # fa `Daylight`, ma lo sprite deve gia' avere i corpi illuminanti dove ha
    # senso che siano.
    for i, dx in enumerate(S["lampade"]):
        x = xc + dx
        box("mg_lamp_b%d" % i, (x, yf - 0.34, hb + 0.62), (0.22, 0.42, 0.24),
            "DT_Metallo_Scuro", raccolta=p)
        box("mg_lamp%d" % i, (x, yf - 0.52, hb + 0.40), (0.46, 0.46, 0.26),
            "DT_Lampada", raccolta=p)

    # --- pensilina dell'ala ----------------------------------------------
    xa, yfa, Ha = q["xa"], q["yfa"], q["Ha"]
    # La pensilina copre la porta e basta. Lunga quanto tutto il fronte
    # faceva da coperchio: passava davanti alla finestra a nastro e l'ala
    # diventava una fascia nera su un muro rosso.
    xp = xa + 1.85
    box("mg_ala_pens", (xp, yfa - 0.62, 3.20), (3.20, 1.24, 0.16),
        "DT_Metallo_Scuro", raccolta=p)
    for s in (-1, 1):
        box("mg_ala_mens%d" % s, (xp + s * 1.35, yfa - 0.30, 2.98),
            (0.10, 0.60, 0.30), "DT_Acciaio", raccolta=p)
    box("mg_ala_vetro", (xa - 1.55, yfa + 0.16, 2.30), (2.70, 0.06, 1.00),
        "DT_Vetro", raccolta=p)
    box("mg_ala_porta", (xa + 1.85, yfa + 0.16, 1.15), (1.20, 0.06, 2.20),
        "DT_Metallo_Scuro", raccolta=p)
    box("mg_ala_marcapiano", (xa, yfa - 0.10, hb + 0.15),
        (q["Wa"] + 0.16, 0.38, 0.30), "DT_Cornice", raccolta=p)
    # La cornice dell'ala corre su un fronte arretrato: `cornicione` la mette
    # sul filo del corpo alto, va riportata indietro col suo muro.
    prima = len(p)
    cornicione("mg_ala_corn", xa, q["Wa"] + 0.10, Ha - 0.55, sporgenza=0.30,
               alt=0.36)
    for obj in p[prima:]:
        obj.location.y += S["ala_arretramento"]
    return unisci(p, "MG_Fronte")


def magazzino_tetto(S):
    """Tetto piano: parapetti, gruppi di condizionamento, estrattori.

    A 27 gradi il tetto di un capannone profondo tredici metri e' un quarto
    dello sprite. Su un magazzino gli impianti stanno in vista — nessuno li
    nasconde dietro a un grigliato come nel quartiere benestante — e sono
    l'unica cosa che ci si puo' mettere.
    """
    q = _mag_quote(S)
    rnd = random.Random(S["seme"] + 11)
    p = []
    W, D, H, xc = q["W"], q["D"], q["H"], q["xc"]

    def parapetto(nome, cx, cy, w, d, z, alt=0.55, sp=0.22):
        box(nome + "_b", (cx, cy + d / 2.0 - sp / 2.0, z + alt / 2.0),
            (w, sp, alt), "DT_Intonaco_Liscio", raccolta=p)
        for s in (-1, 1):
            box(nome + "_l%d" % s, (cx + s * (w / 2.0 - sp / 2.0), cy,
                                    z + alt / 2.0), (sp, d, alt),
                "DT_Intonaco_Liscio", raccolta=p)
        cs = sp + 0.10
        zc = z + alt + 0.04
        box(nome + "_cap_b", (cx, cy + d / 2.0 - sp / 2.0, zc),
            (w + 0.10, cs, 0.09), "DT_Cornice_Scura", raccolta=p)
        for s in (-1, 1):
            box(nome + "_cap_l%d" % s, (cx + s * (w / 2.0 - sp / 2.0), cy, zc),
                (cs, d + 0.10, 0.09), "DT_Cornice_Scura", raccolta=p)

    box("mg_manto", (xc, 0, H + 0.04), (W - 0.06, D - 0.06, 0.08), "DT_Guaina",
        raccolta=p)
    # Il parapetto e' senza lato anteriore: davanti c'e' gia' il cornicione, e
    # sovrapporli lascia una riga chiara sopra la cornice.
    parapetto("mg_par", xc, 0, W, D, H + 0.08)

    for i, dx in enumerate((-8.2, -4.4, -0.6, 3.2, 7.0)):
        y = rnd.uniform(-D * 0.08, D * 0.16)
        box("mg_uta%d" % i, (xc + dx, y, H + 0.08 + 0.52), (2.30, 1.70, 1.04),
            "DT_Acciaio", raccolta=p)
        box("mg_uta_cap%d" % i, (xc + dx, y, H + 0.08 + 1.10),
            (2.42, 1.82, 0.12), "DT_Metallo_Scuro", raccolta=p)
        box("mg_uta_zoc%d" % i, (xc + dx, y, H + 0.08 + 0.10),
            (2.50, 1.90, 0.20), "DT_Guaina", raccolta=p)
    for i in range(4):
        cilindro("mg_estrattore%d" % i,
                 (xc + rnd.uniform(-W * 0.36, W * 0.36),
                  rnd.uniform(D * 0.26, D * 0.40), H + 0.08 + 0.34),
                 0.44, 0.68, "DT_Metallo_Scuro", lati=10, raccolta=p)

    xa, ya, Wa, Da, Ha = q["xa"], q["ya"], q["Wa"], q["Da"], q["Ha"]
    box("mg_ala_manto", (xa, ya, Ha + 0.04), (Wa - 0.06, Da - 0.06, 0.08),
        "DT_Guaina", raccolta=p)
    parapetto("mg_ala_par", xa, ya, Wa, Da, Ha + 0.08, alt=0.44, sp=0.20)
    for i, off in enumerate((-1.6, 1.2)):
        box("mg_ala_uta%d" % i, (xa + off, ya + 0.9, Ha + 0.08 + 0.40),
            (1.50, 1.20, 0.80), "DT_Acciaio", raccolta=p)
    return unisci(p, "MG_Tetto")


# Il magazzino non ha nessun pezzo di terra dentro allo sprite, e per due
# potature successive che hanno lo stesso motivo: **quello che sta a terra e'
# citta', non edificio.**
#
# Prima e' uscito il parcheggio — marciapiede, passaggio pedonale, corsia e
# una fila di posti auto — che adesso e' un lotto "asphalt" in `LOTS` disegnato
# da `city_ground.gd`, coi lampioni sopra che sono nodi veri
# (`street_lamp.gd`) e si accendono la sera da soli. Un lampione disegnato
# nello sprite non puo' accendersi: lo sprite e' una texture, e di notte il
# `CanvasModulate` della citta' la moltiplica per il blu come tutto il resto.
#
# Poi e' uscito anche il marciapiede (2026-09-21, vedi la nota in cima al
# file): davanti al muro restava una striscia di 17 px con un grigio suo,
# appoggiata sopra a quella vera di MAIN STREET, che e' fatta di un altro
# grigio. Si vedeva il bordo.


# ----------------------------------------------------------------------
#  scena e render
# ----------------------------------------------------------------------

INCLINAZIONE = 27.0


def scena():
    sc = bpy.context.scene
    sc.unit_settings.system = "METRIC"

    dati = bpy.data.cameras.new("CAM_Front")
    dati.type = "ORTHO"
    dati.clip_start, dati.clip_end = 0.1, 400.0
    cam = bpy.data.objects.new("CAM_Front", dati)
    sc.collection.objects.link(cam)
    # Solo rotazione X: nessuna imbardata, la facciata resta dritta.
    cam.rotation_euler = (math.radians(90.0 - INCLINAZIONE), 0.0, 0.0)
    sc.camera = cam

    sole = bpy.data.lights.new("SUN", type="SUN")
    sole.energy = 2.7
    sole.color = (1.0, 0.95, 0.88)
    sole.angle = math.radians(1.0)
    obj = bpy.data.objects.new("SUN", sole)
    sc.collection.objects.link(obj)
    obj.rotation_euler = (math.radians(58), 0.0, math.radians(-46))

    # Schiarita fredda dall'alto-dietro: senza, le ombre si chiudono sul nero e
    # a 248 px un'ombra nera e un muro scuro diventano la stessa cosa.
    riemp = bpy.data.lights.new("FILL", type="SUN")
    riemp.energy = 0.75
    riemp.color = (0.70, 0.78, 0.94)
    riemp.angle = math.radians(30)
    obj = bpy.data.objects.new("FILL", riemp)
    sc.collection.objects.link(obj)
    obj.rotation_euler = (math.radians(108), 0.0, math.radians(30))

    mondo = bpy.data.worlds.new("World")
    sc.world = mondo
    mondo.use_nodes = True
    N, L = mondo.node_tree.nodes, mondo.node_tree.links
    N.clear()
    uscita = N.new("ShaderNodeOutputWorld")
    uscita.location = (400, 0)
    sfondo = N.new("ShaderNodeBackground")
    sfondo.location = (180, 0)
    grad = N.new("ShaderNodeTexGradient")
    grad.location = (-300, 0)
    mapping = N.new("ShaderNodeMapping")
    mapping.location = (-480, 0)
    mapping.inputs["Rotation"].default_value = (0, math.radians(-90), 0)
    coord = N.new("ShaderNodeTexCoord")
    coord.location = (-680, 0)
    ramp = N.new("ShaderNodeValToRGB")
    ramp.location = (-90, 0)
    ramp.color_ramp.elements[0].position = 0.40
    ramp.color_ramp.elements[0].color = srgb("#C6C0B2")
    ramp.color_ramp.elements[1].position = 0.62
    ramp.color_ramp.elements[1].color = srgb("#6E8BA8")
    L.new(coord.outputs["Generated"], mapping.inputs["Vector"])
    L.new(mapping.outputs["Vector"], grad.inputs["Vector"])
    L.new(grad.outputs["Fac"], ramp.inputs["Fac"])
    L.new(ramp.outputs["Color"], sfondo.inputs["Color"])
    _set(sfondo, "Strength", 0.95)
    L.new(sfondo.outputs["Background"], uscita.inputs["Surface"])

    sc.render.engine = "BLENDER_EEVEE"
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

    # Standard e non AgX: AgX e' fatto per il fotorealismo e sbiadisce di brutto
    # i colori piatti: a 248 px il marrone diventa grigio.
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.exposure = 0.0

    # Due linee separate. Una sola, spessa, sugli spigoli interni annerisce la
    # facciata; una sola, sottile, sulla silhouette non stacca l'edificio dal
    # fondo. Contorno spesso fuori, spigoli sottili dentro.
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
    fuori.linestyle.alpha = 1.0
    fuori.linestyle.thickness = 6.5

    dentro = fs.linesets.new("Spigoli")
    for a in ("select_silhouette", "select_border", "select_ridge_valley",
              "select_suggestive_contour", "select_material_boundary",
              "select_edge_mark"):
        setattr(dentro, a, False)
    dentro.select_crease = True
    dentro.linestyle.color = (0.075, 0.058, 0.046)
    dentro.linestyle.alpha = 0.55
    dentro.linestyle.thickness = 2.8
    return cam


def modo_luci():
    """Riduce la scena a quello che di notte resta acceso, per il secondo scatto.

    ## Perche' serve un secondo PNG

    Lo sprite di un edificio e' una texture, e di notte il `CanvasModulate`
    della citta' la moltiplica per il blu della sera: una finestra dipinta
    gialla viene fuori marrone, come tutto il resto del muro. Finche' gli
    edifici erano segnaposto disegnati via codice il problema non esisteva —
    `building_placeholder.gd` disegnava le finestre accese con
    `Daylight.emissive()`, che pre-divide il colore per la luce dell'ambiente —
    ma i disegni quella possibilita' non ce l'hanno.

    Il secondo PNG la restituisce: e' lo stesso edificio, stessa camera e
    stessa inquadratura, con dentro solo le cose accese su fondo nero. In gioco
    lo si appoggia sopra allo sprite e lo si moltiplica per la compensazione di
    `emissive()`, e quelle restano accese mentre il muro sotto si spegne.

    ## Che cosa e' acceso

    Non c'e' una lista: e' acceso quello che il modello dichiara gia'
    emissivo — `QP_Vetro_Acceso`, `QP_Vetrina`, `QB_Vetro_Atrio`, `DT_Vetro`,
    le lampade. E' la stessa informazione che di giorno fa un vetro piu'
    chiaro degli altri, quindi le finestre accese di notte sono esattamente
    quelle che di giorno si leggono come accese, e non un secondo elenco da
    tenere allineato a mano.

    Spegne anche sole, cielo e contorni Freestyle: un contorno nero intorno a
    una finestra accesa, moltiplicato per la compensazione, diventa un bordo
    grigio intorno alla luce.
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
        # L'albero si riscrive invece di spegnere gli ingressi uno per uno:
        # intonaci e mattoni hanno il colore COLLEGATO al Base Color, e un
        # valore scritto sopra a un ingresso collegato non lo guarda nessuno.
        N, L = mat.node_tree.nodes, mat.node_tree.links
        N.clear()
        uscita = N.new("ShaderNodeOutputMaterial")
        uscita.location = (300, 0)
        if acceso is None:
            nero = N.new("ShaderNodeBsdfDiffuse")
            nero.inputs["Color"].default_value = (0.0, 0.0, 0.0, 1.0)
            L.new(nero.outputs[0], uscita.inputs["Surface"])
        else:
            luce = N.new("ShaderNodeEmission")
            luce.inputs["Color"].default_value = acceso
            luce.inputs["Strength"].default_value = 1.0
            L.new(luce.outputs[0], uscita.inputs["Surface"])


def inquadra(cam, margine=0.35):
    """Stringe l'inquadratura sull'ingombro reale, in spazio camera.

    Non sul bounding box in coordinate mondo: con la camera inclinata la Y e la
    Z del mondo finiscono mescolate sull'asse verticale dello schermo, e un
    riquadro calcolato in mondo lascia margini diversi sopra e sotto.

    L'aggiornamento del view layer non e' pignoleria: `bound_box` e
    `matrix_world` sono valori in cache che Blender ricalcola quando valuta il
    depsgraph. Con l'interfaccia aperta succede da solo tra un'operazione e
    l'altra; in background no, e si finisce a inquadrare su un bounding box
    vecchio e una camera ancora non ruotata.
    """
    bpy.context.view_layer.update()
    punti = []
    for obj in bpy.data.objects:
        if obj.type != "MESH" or obj.hide_render:
            continue
        for angolo in obj.bound_box:
            punti.append(obj.matrix_world @ Vector(angolo))
    inv = cam.matrix_world.inverted()
    vista = [inv @ p for p in punti]
    minx, maxx = min(p.x for p in vista), max(p.x for p in vista)
    miny, maxy = min(p.y for p in vista), max(p.y for p in vista)
    larg = (maxx - minx) + 2 * margine
    alt = (maxy - miny) + 2 * margine
    # La camera va centrata *e* tirata indietro lungo il proprio asse Z. Che sia
    # ortografica non la esonera dal piano di taglio vicino: lasciata
    # nell'origine si ritrova dentro l'edificio e ne perde la meta' dietro,
    # senza errori, restituendo un palazzo tagliato a filo.
    ARRETRAMENTO = 80.0
    cam.location = cam.matrix_world @ Vector(
        ((minx + maxx) / 2.0, (miny + maxy) / 2.0, ARRETRAMENTO))
    cam.data.ortho_scale = max(larg, alt)

    altezza_sprite = int(round(alt * PX_PER_METRO))
    sc = bpy.context.scene
    sc.render.resolution_y = altezza_sprite * SUPERSAMPLING
    sc.render.resolution_x = int(round(sc.render.resolution_y * larg / alt))
    return larg, alt, altezza_sprite


# ----------------------------------------------------------------------
#  gli edifici del quartiere
# ----------------------------------------------------------------------

# Quanti pixel vale un metro, uguale per tutti gli edifici del quartiere.
#
# **La misura non si sceglie: la detta il personaggio.** La figura dentro
# `placeholdercharater.png` e' alta 39 px e rappresenta una persona di circa
# 1,75 m, quindi il gioco vale 39 / 1,75 = 22,3 px per metro. Tutto il resto
# deve stare in quella scala.
#
# Qui prima c'era 8.0, preso dall'altezza che aveva il disegno del palazzo che
# il render ha sostituito. Era sbagliato di quasi tre volte, e si vedeva: una
# porta alta 2,10 m veniva 17 px contro un personaggio di 39, cioe' la gente
# era alta il doppio delle porte. Un numero ereditato da un disegno non e' una
# scala — e' l'altezza che quel disegno aveva, che e' un'altra cosa.
#
# Conseguenza da tenere presente: in scala vera un palazzo di otto piani e' piu'
# alto dello schermo. Non e' un problema da aggirare rimpicciolendolo, e' come
# stanno le cose — la camera fa zoom da 1x a 8x (`camera_zoom.gd`), e a 1x si
# vedono 720 px di mondo in altezza, abbastanza per guardarlo tutto.
PX_PER_METRO = 22.3

EDIFICI = {
    # Il condominio mezzo occupato: otto livelli, garage al piano terra,
    # balconi su una sola campata centrale come nel palazzo di riferimento.
    "condominio": dict(
        tipo="condominio",
        larghezza=13.0, profondita=11.0,
        h_terra=3.4, h_piano=2.85, piani=7,
        intonaco="QP_Intonaco_Marrone_A",
        # 1 = piano abitato, 0 = abbandonato. La striscia conta piu' della
        # proporzione: due piani vivi di fila si leggono, sparsi no.
        occupazione=[1, 0, 1, 1, 0, 1, 0],
        # (tipo, centro_x, larghezza, altezza, altezza_davanzale_dal_piano)
        aperture_fronte=[
            ("finestra", -5.20, 1.10, 1.50, 0.95),
            ("porta", -2.90, 1.00, 2.25, 0.00),
            ("finestra", -0.70, 1.30, 1.50, 0.95),
            ("finestra", 2.40, 1.10, 1.50, 0.95),
            ("finestra", 4.80, 1.10, 1.50, 0.95),
        ],
        aperture_retro=[
            ("finestra", -4.80, 1.10, 1.40, 1.00),
            ("finestra", -1.60, 1.10, 1.40, 1.00),
            ("finestra", 1.60, 1.10, 1.40, 1.00),
            ("finestra", 4.80, 1.10, 1.40, 1.00),
        ],
        aperture_terra=[
            ("garage", -4.40, 2.70, 2.35, 0.00),
            ("garage", -1.30, 2.70, 2.35, 0.00),
            ("portone", 2.20, 1.30, 2.45, 0.00),
            ("grata", 4.70, 0.90, 0.90, 1.55),
        ],
        balcone_x=(-3.78, 0.28),
        condizionatori=[(2.40, 2), (4.80, 5), (-5.20, 3)],
        # Cortile di venti metri e non ventidue: alla scala del personaggio due
        # metri in meno sono quarantacinque pixel, e servono a far stare il
        # palazzo nel primo isolato di THE FLATS accanto a casa. Il fabbricato
        # resta quello, si stringe solo il terreno intorno — che per un
        # caseggiato di citta' e' anche piu' giusto.
        lotto_x=(-10.0, 10.0), lotto_y=(-9.6, 6.2),
        varco=(-6.1, 0.4), annesso=(-7.6, -3.4),
        seme=4241,
    ),

    # La casa del giocatore: casa di legno americana a due piani col timpano
    # rivolto alla strada e il portico sui pilastri di mattoni.
    #
    # Stretta e alta, non larga e bassa: e' la proporzione della casa di
    # riferimento, ed e' anche quella che serve qui — accanto a un palazzo di
    # otto piani una villetta bassa si legge come un capanno, mentre una casa
    # alta e stretta resta una casa.
    "casa": dict(
        tipo="casa",
        # Poco profonda di proposito. Col timpano davanti le due falde scendono
        # ai lati e si vedono per tutta la profondita' della casa: a otto metri
        # e mezzo si prendevano meta' sprite e la casa sembrava due ali di
        # tetto con una facciata in mezzo.
        larghezza=7.8, profondita=7.2,
        h_terra=2.95, h_primo=2.80,
        # 42 gradi: il timpano deve essere ripido. Sotto i 35 il triangolo si
        # appiattisce e la sagoma torna quella di un capannone.
        pendenza=42.0,
        sporto=0.40,
        portico_p=1.60,
        camino=(2.15, 1.85),
        # Cortile corto di proposito. Con la camera inclinata la profondita' del
        # lotto pesa sull'altezza dello sprite quanto l'edificio: un cortile di
        # quindici metri davanti a una casa fa uno sprite in cui la casa e' un
        # dettaglio in mezzo al prato.
        lotto_x=(-6.2, 6.2), lotto_y=(-7.4, 4.2),
        seme=7717,
    ),

    # La casa gialla di CROSS STREET, a sinistra del garage in vendita: una
    # vittoriana di legno presa da una foto, col timpano ripido sulla strada,
    # il portico a colonnine bianche su tutta la facciata e l'ala bassa a
    # destra. E' la prima casa del quartiere con qualcosa che si muove: la
    # girandola nel giardinetto e la bandiera appesa al portico
    # (`casa_gialla_animati()`).
    "casa_gialla": dict(
        tipo="casa_gialla",
        larghezza=7.2, profondita=8.0,
        h_terra=3.2, h_primo=2.75,
        # 50 gradi, piu' ripido della casa del giocatore: nella foto il timpano
        # e' alto quasi quanto i due piani sotto, ed e' la sagoma che la fa
        # riconoscere.
        pendenza=50.0, sporto=0.35,
        camino=(-1.3, 1.8),
        ala_l=3.4, ala_p=6.0, ala_h=4.3, ala_arretro=0.5, ala_pendenza=34.0,
        portico_p=1.5, quota=0.6, colonnine=5,
        gradini_x=-2.45, porta_x=-2.3,
        # Il giardinetto e' corto: due metri fra i gradini e la rete. Vedi la
        # nota sul cortile della casa del giocatore.
        lotto_x=(-4.3, 7.6), lotto_y0=-7.5,
        girandola=(6.3, -6.75),
        # L'asta parte dalla seconda colonnina, a mezza altezza, e punta fuori
        # verso sinistra passando SOTTO alla gronda del portico.
        bandiera=(-0.975, -5.42, 1.8), asta=1.7, asta_dir=(-0.55, -0.6, 0.58),
        seme=2604,
    ),

    # --- la schiera -------------------------------------------------------
    # Questi non hanno lotto e sono a filo sui fianchi: si affiancano a
    # distanza pari alla loro larghezza e formano una fila continua. Le
    # larghezze sono tutte diverse di proposito — una fila di edifici larghi
    # uguali si legge come una griglia, non come una strada.

    # L'agenzia immobiliare: l'unica con due piani interi di uffici e le
    # vetrine grandi. Deve distinguersi, perche' ci si clicca sopra.
    "agenzia": dict(
        tipo="commerciale",
        larghezza=9.2, profondita=6.6, piani=2,
        h_terra=3.60, h_piano=2.90,
        intonaco="QP_Intonaco_Marrone_B",
        fronte="ufficio", insegna="QP_Insegna_Blu", finestre=3,
        seme=1101,
    ),
    # Il garage in vendita.
    "garage": dict(
        tipo="commerciale",
        larghezza=7.6, profondita=6.2, piani=0,
        h_terra=3.50, h_piano=2.90,
        intonaco="QP_Intonaco_Laterale",
        fronte="serranda", insegna="QP_Insegna_Bianca",
        seme=1102,
    ),
    "bodega": dict(
        tipo="commerciale",
        larghezza=8.4, profondita=6.2, piani=1,
        h_terra=3.50, h_piano=2.90,
        intonaco="QP_Intonaco_Marrone_A",
        fronte="vetrina", insegna="QP_Insegna_Rossa", tenda="QP_Tenda_Rossa",
        finestre=3, seme=1103,
    ),
    "lavanderia": dict(
        tipo="commerciale",
        larghezza=7.2, profondita=5.8, piani=1,
        h_terra=3.45, h_piano=2.85,
        intonaco="QP_Intonaco_Marrone_B",
        fronte="vetrina", insegna="QP_Insegna_Gialla", tenda="QP_Tenda_Blu",
        finestre=2, seme=1104,
    ),
    "liquori": dict(
        tipo="commerciale",
        larghezza=6.4, profondita=5.8, piani=1,
        h_terra=3.40, h_piano=2.85,
        intonaco="QP_Mattone_Facciata",
        fronte="barre", insegna="QP_Insegna_Rossa",
        finestre=2, seme=1105,
    ),
    "officina": dict(
        tipo="commerciale",
        larghezza=10.4, profondita=7.0, piani=0,
        h_terra=4.20, h_piano=2.90,
        intonaco="QP_Intonaco_Laterale",
        fronte="officina", insegna="QP_Insegna_Verde",
        seme=1106,
    ),
    # Caseggiato di sole abitazioni: riempie le file senza aggiungere
    # un'attivita' in piu'. In un quartiere povero la maggior parte degli
    # edifici non e' un negozio.
    "caseggiato": dict(
        tipo="commerciale",
        larghezza=11.5, profondita=7.4, piani=3,
        h_terra=3.30, h_piano=2.85,
        intonaco="QP_Intonaco_Marrone_A",
        fronte="ufficio", insegna=None,
        finestre=4, seme=1107,
    ),
    "pensione": dict(
        tipo="commerciale",
        larghezza=9.0, profondita=6.8, piani=2,
        h_terra=3.45, h_piano=2.80,
        intonaco="QP_Mattone_Facciata",
        fronte="vetrina", insegna="QP_Insegna_Verde",
        finestre=3, seme=1108,
    ),

    # --- quartiere benestante ---------------------------------------------
    # La clinica dove lavora Brian. E' il primo edificio dell'altro quartiere,
    # quindi e' anche il posto dove si decide che aspetto ha: palette QB_,
    # stessa inclinazione e stessi contorni di tutto il resto.
    #
    # E' larga e bassa mentre il condominio e' stretto e alto, e non e' un
    # caso: e' la differenza che si legge da lontano prima di qualsiasi
    # dettaglio. Un edificio pubblico occupa il lotto in orizzontale perche'
    # il terreno ce l'ha; un caseggiato popolare cresce in altezza perche' non
    # ce l'ha.
    "clinica": dict(
        tipo="clinica",
        # Profondita' 9 e non 11: a 27 gradi ogni metro di profondita' e' mezzo
        # metro di tetto in altezza sullo sprite, e il tetto e' la parte che
        # dice meno. Due metri in meno sono quarantacinque pixel di guaina in
        # meno e nessun dettaglio perso.
        larghezza=16.0, profondita=9.0,
        # Piano terra alto 4,60: non e' generosita', e' quello che rende
        # visibile l'atrio. Vista da 27 gradi la pensilina fa da coperchio e
        # nasconde la facciata per tutta la sua sporgenza; l'atrio si vede
        # solo per la fascia che resta SOPRA la lastra e per quella che si
        # intravede SOTTO. Con un piano terra basso non resta ne' l'una ne'
        # l'altra e l'ingresso sparisce.
        h_terra=4.60, h_piano=3.30, piani=2,
        ala_larghezza=7.0, ala_profondita=7.2, ala_altezza=4.60,
        ala_sporgenza=0.70,
        x_atrio=-2.50, w_atrio=8.50,
        colonne=[-6.60, -4.40, -2.20, 0.0, 2.20],
        # Sporgenze e non coordinate: sono misurate dalla facciata, cosi'
        # cambiare la profondita' dell'edificio non stacca la pensilina dal
        # muro o non la lascia a mezz'aria sul piazzale.
        pensilina_sporgenza=3.10, pensilina_z=3.40,
        pilastri=[-6.20, -3.73, -1.27, 1.20],
        banner_x=5.20,
        # Il piazzale arriva appena oltre i pilastri della pensilina: verde e
        # arredo urbano non stanno nello sprite, li mette la citta'.
        base_x=(-15.4, 8.4), base_sporgenza=3.90,
        seme=2201,
    ),

    # --- DOWNTOWN ---------------------------------------------------------
    # Il grossista dei semi: il magazzino all'ingrosso dove Brian va a
    # prendere la merce, e dove piu' avanti ci si va da soli. Primo edificio
    # di DOWNTOWN, quindi e' lui a fissare la palette del quartiere.
    #
    # Ventidue metri di fronte strada contro i sedici della clinica: e' la
    # differenza che si legge da lontano prima di ogni dettaglio. Un
    # magazzino all'ingrosso e' largo perche' dentro ci passano i muletti, e
    # basso perche' non ha piani — un solo volume alto sette metri e mezzo,
    # con sopra il corpo dell'insegna a dire dov'e' la porta.
    "magazzino": dict(
        tipo="magazzino",
        # Profondita' 11,5 e non 20: il magazzino vero e' profondo il
        # quadruplo, ma a 27 gradi ogni metro di profondita' e' mezzo metro di
        # tetto sullo sprite, e il tetto e' la parte che dice meno. Da davanti
        # la differenza fra undici e venti metri non si vede; sullo sprite sono
        # trenta pixel di guaina in piu'.
        larghezza=21.6, profondita=11.5,
        h_muro=7.40,
        # Il basamento arriva sopra gli architravi dei portoni: e' li' che va
        # la riga fra mattone e intonaco, altrimenti taglia le aperture a
        # meta' e la facciata si legge a pezzi.
        # Fra l'architrave dei portoni e la fine del mattone ci devono
        # restare almeno ottanta centimetri. Qui prima c'era 4,05: il
        # basamento finiva subito sopra i portoni e fra le lesene non ne
        # restava visibile un pezzo grande abbastanza da leggersi, quindi
        # la facciata non aveva due fasce — aveva delle lesene marroni su
        # un muro beige.
        h_mattone=4.95,
        lesene=[-10.35, -6.85, -3.35, 3.35, 6.85, 10.35],
        lesena_w=0.95, lesena_sp=0.42, lesena_h=6.30,
        # (scostamento dal centro del corpo, larghezza)
        portoni=[(-8.60, 2.35), (-5.10, 2.35), (5.10, 2.35), (8.60, 2.35)],
        portone_sotto=0.25, portone_h=3.20, portone_rec=0.34,
        ingresso_w=5.60, ingresso_h=3.80, ingresso_rec=0.55,
        # L'arco poggia sulle due lesene centrali: la corda e' la loro
        # distanza, non la larghezza dell'ingresso. Un arco piu' stretto
        # delle lesene resta a mezz'aria in mezzo alla campata.
        arco_corda=6.70, arco_freccia=1.25, arco_imposta=3.95,
        arco_sporgenza=1.30,
        timpano_w=12.40, timpano_h=10.50,
        gradino_w=1.80, gradino_h=9.20,
        insegna_z=8.95, insegna_w=8.60, insegna_h=2.10, fascia_h=0.95,
        lampade=[-10.35, -6.85, -3.35, 3.35, 6.85, 10.35],
        # L'ala e' profonda 7,2 e alta 6,4, e i due numeri stanno
        # insieme: a 27 gradi un corpo basso e profondo e' per meta' tetto.
        # Con 10,4 di profondita' e 5,3 di altezza l'ala era mezza guaina e
        # due condizionatori, e da lontano sembrava un buco nell'edificio.
        ala_larghezza=6.40, ala_profondita=7.20, ala_altezza=6.40,
        ala_arretramento=1.10,
        # Niente misure di terra: il magazzino non porta piu' nessun pezzo di
        # suolo dentro allo sprite. Il parcheggio e' un lotto della citta' e il
        # marciapiede lo disegna `city_ground.gd`. Vedi la nota sopra
        # `magazzino_corpo`.
        seme=5501,
    ),

    # --- il campo da football abbandonato ---------------------------------
    # Non sono edifici, sono le strutture del campo: entrano in citta' come
    # props (al pari dei lampioni), non come punti di riferimento. Stanno qui
    # perche' e' qui che c'e' la camera giusta e la palette del quartiere.
    "gradinata": dict(
        tipo="gradinata",
        # Lunga trenta metri e bassa quattro gradoni. La lunghezza copre da
        # sola tutto il lato nord del campo: due gradinate corte affiancate
        # ripeterebbero lo stesso identico sbriciolamento a pochi metri di
        # distanza, e si vedrebbe. L'altezza invece e' obbligata — fra il
        # marciapiede di MAIN STREET e il campo ci sono centoventi pixel, e una
        # gradinata da otto gradoni ne occupava quasi duecento, finendo
        # disegnata sopra al marciapiede su cui si cammina.
        larghezza=30.0, profondita=3.74,
        gradoni=4, alzata=0.34, pedata=0.72,
        # In quanti pezzi si spezza ogni gradone lungo la larghezza: da questo
        # dipende quanto fine e' lo sbriciolamento. A 4 mancherebbero pezzi da
        # quattro metri, a 32 non si vedrebbe niente.
        segmenti=24,
        camminamenti=[-9.50, 0.0, 9.50], camminamento_largo=1.40,
        muro_alto=0.80,
        seme=3301,
    ),
    "torre_faro": dict(
        tipo="torre_faro",
        altezza=15.6, livelli=8,
        base_larga=1.45, cima_larga=0.72,
        testa_larga=3.10, testa_alta=2.05, lampade=(4, 3),
        seme=3302,
    ),
    "porta_campo": dict(
        tipo="porta",
        larghezza=7.32, altezza=2.44,
        # Gradi di fuori piombo del palo destro. A meno di sei non si vede che
        # e' storta, a piu' di dodici sembra caduta.
        storto=8.5,
        seme=3303,
    ),
}


def costruisci(nome):
    S = dict(EDIFICI[nome])
    pulisci()
    if S.get("tipo") == "clinica":
        # Altra tavolozza, non altro stile: la scena, l'inclinazione e i
        # contorni restano quelli di tutti gli altri edifici.
        palette_qb()
        S["altezza"] = S["h_terra"] + S["piani"] * S["h_piano"]
        clinica_corpo(S)
        clinica_fronte(S)
        clinica_tetto(S)
        clinica_base(S)
        return S
    if S.get("tipo") == "magazzino":
        # Terzo quartiere, terza tavolozza. Vale la stessa regola della
        # clinica: altra palette, non altro stile.
        palette_dt()
        magazzino_corpo(S)
        magazzino_fronte(S)
        magazzino_tetto(S)
        return S
    palette()
    # Le strutture del campo pescano dalla palette del quartiere povero: il
    # campo sta in THE FLATS, ed e' lo stesso cemento dei suoi muri.
    if S.get("tipo") == "gradinata":
        gradinata(S)
        return S
    if S.get("tipo") == "torre_faro":
        torre_faro(S)
        return S
    if S.get("tipo") == "porta":
        porta_campo(S)
        return S
    if S.get("tipo") == "casa_gialla":
        S["altezza"] = S["h_terra"] + S["h_primo"] + \
            (S["larghezza"] / 2.0) * math.tan(math.radians(S["pendenza"]))
        casa_gialla_corpo(S)
        casa_gialla_portico(S)
        casa_gialla_infissi(S)
        casa_gialla_lotto(S)
        S["animati"] = casa_gialla_animati(S)
        return S
    if S.get("tipo") == "casa":
        # Il colmo e' lungo Y, quindi la salita del timpano si misura sulla
        # meta' della LARGHEZZA, non della profondita'.
        S["altezza"] = S["h_terra"] + S["h_primo"] + \
            (S["larghezza"] / 2.0) * math.tan(math.radians(S["pendenza"]))
        casa_corpo(S)
        casa_portico(S)
        casa_infissi(S)
        casa_lotto(S)
    elif S.get("tipo") == "commerciale":
        S["altezza"] = S["h_terra"] + S["piani"] * S["h_piano"]
        commerciale(S)
    else:
        S["altezza"] = S["h_terra"] + S["piani"] * S["h_piano"]
        corpo(S)
        tetto(S)
        infissi(S)
        balconi(S)
        lotto(S)
    return S


def _nascondi_animati(S, nascosti=True):
    for _, oggetti, _, _ in S.get("animati", []):
        for obj in oggetti:
            obj.hide_render = nascosti


def fotografa_animati(nome):
    """I fotogrammi delle cose che si muovono (vedi `casa_gialla_animati()`).

    L'edificio si ricostruisce da zero — `modo_luci()` ha riscritto i
    materiali — e si rinquadra con le parti mobili nascoste, esattamente come
    per il disegno: stessa camera, stesso ritaglio, e i fotogrammi cadono al
    pixel sopra allo sprite. Poi tutto quello che non e' l'animazione diventa
    "holdout": non si vede, ma buca l'immagine dove ci sta davanti.

    Anche le linee Freestyle vanno ristrette alla sola animazione, o si
    disegnerebbero i contorni di tutta la casa invisibile.
    """
    S = costruisci(nome)
    cam = scena()
    _nascondi_animati(S)
    inquadra(cam)
    sc = bpy.context.scene
    fs = bpy.context.view_layer.freestyle_settings
    for tag, oggetti, posa, n in S["animati"]:
        coll = bpy.data.collections.new("ANIM_" + tag)
        sc.collection.children.link(coll)
        for obj in oggetti:
            coll.objects.link(obj)
        for ls in fs.linesets:
            ls.select_by_collection = True
            ls.collection = coll
            ls.collection_negation = "INCLUSIVE"
        for obj in bpy.data.objects:
            if obj.type == "MESH":
                obj.is_holdout = obj not in oggetti
                obj.hide_render = obj not in oggetti and obj.hide_render
        _nascondi_animati(S)
        for obj in oggetti:
            obj.hide_render = False
        for i in range(n):
            posa(i / float(n))
            sc.render.filepath = os.path.join(OUT, "anim_%s_%s_%02d.png" % (nome, tag, i))
            bpy.ops.render.render(write_still=True)
        posa(0.0)
    print("%-12s animazioni: %s" % (nome, ", ".join(
        "%s x%d" % (tag, n) for tag, _, _, n in S["animati"])))


def main():
    if not os.path.isdir(OUT):
        os.makedirs(OUT)
    # Dopo `--` si possono dare i nomi degli edifici da rifare: rifarli tutti
    # vuol dire riscrivere una ventina di PNG per cambiarne uno.
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    nomi = [n for n in argv if n in EDIFICI] or list(EDIFICI)
    for nome in nomi:
        S = costruisci(nome)
        cam = scena()
        # Le parti mobili non stanno nel disegno: hanno i loro fotogrammi.
        _nascondi_animati(S)
        larg, alt, h_sprite = inquadra(cam)
        sc = bpy.context.scene
        sc.render.filepath = os.path.join(OUT, "render_%s.png" % nome)
        bpy.ops.render.render(write_still=True)
        facce = sum(len(o.data.polygons) for o in bpy.data.objects
                    if o.type == "MESH")
        # Secondo scatto, stessa inquadratura: le luci accese. Va dopo il
        # primo e non prima, perche' `modo_luci()` riscrive i materiali e non
        # li rimette a posto — tanto l'edificio dopo si ricostruisce da zero.
        modo_luci()
        sc.render.filepath = os.path.join(OUT, "luci_%s.png" % nome)
        bpy.ops.render.render(write_still=True)
        # L'altezza stampata e' quella da mettere in `ASSETS` dentro
        # `import_flats_art.py`: e' l'ingombro reale per i px/m del quartiere,
        # non un numero scelto a occhio.
        print("%-12s %5.1f x %5.1f m  render %dx%d  %5d facce  ->  ASSETS: "
              "(\"render_%s.png\", \"<nome>\", None, %d)"
              % (nome, larg, alt, sc.render.resolution_x, sc.render.resolution_y,
                 facce, nome, h_sprite))
        if S.get("animati"):
            fotografa_animati(nome)


if __name__ == "__main__":
    main()
