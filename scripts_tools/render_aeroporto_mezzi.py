"""Renderizza dall'alto gli aerei e i mezzi di pista dell'aeroporto.

Come le auto (`render_cars.py`): il gioco disegna i veicoli visti dritti
dall'alto e li gira in Godot, quindi basta un render per modello, col muso
verso destra (+X). Un aereo che vira o un furgone che curva e' lo stesso sprite
ruotato: nessun fotogramma per direzione.

La scala e' quella delle auto, circa 10 px per metro (un'auto di 4,3 m e' 44
px): un aereo di linea di 34 m viene 340 px, il trattorino 30. Cosi' in pista i
mezzi stanno bene accanto al traffico della citta'.

Gli aerei vengono dagli FBX del pacchetto (`_airport_source/aerei`), coi loro
materiali a texture. I mezzi dal `.blend` dei veicoli di pista, che ha i
materiali giusti (l'FBX della scala li ha persi). La scala mobile ha la parte
alta separata, che sale a scatti come nello script Unity del pacchetto
(`cartandstairs.cs`): se ne fanno `SCALA_FOTOGRAMMI` scatti, dalla scala chiusa
a quella tutta alzata, che in gioco scorrono quando arriva all'aereo.

Uso:
  blender --background --factory-startup --python scripts_tools/render_aeroporto_mezzi.py
"""

import math
import os

import bpy
from mathutils import Matrix, Vector

try:
    HERE = os.path.dirname(os.path.abspath(__file__))
except NameError:
    HERE = os.path.join(os.getcwd(), "scripts_tools")
ROOT = os.path.abspath(os.path.join(HERE, os.pardir))
SRC = os.path.join(ROOT, "assets", "sprites", "_airport_source")
OUT = os.path.join(ROOT, "assets", "sprites", "props", "airport")

PX_PER_METRO = 10.0
PAD = 2

# nome dello sprite -> (file FBX, di quanti gradi girarlo perche' il muso
# guardi +X). Gli aerei del pacchetto hanno tutti il muso verso -X.
AEREI = {
    "jet": ("planehuge.fbx", 180.0),
    "bimotore": ("planeazer.fbx", 180.0),
    "elica_viola": ("planesty.fbx", 180.0),
    "elica_gialla": ("planeazer_002.fbx", 180.0),
    "cartoon_giallo": ("plancestylized_001.fbx", 180.0),
    "elicottero": ("planehelice.fbx", 180.0),
}
# nome dello sprite -> (oggetto nel .blend, giro). I mezzi del .blend sono
# lunghi lungo Y col muso verso +Y. La scala ha `None`: il giro si calcola in
# modo che la piattaforma (la cima) finisca verso +X, cioe' davanti — e' il
# lato che si accosta al portellone.
MEZZI = {
    "trattorino": ("BaggageTug", -90.0),
    "scala": ("Stairs", None),
}
SCALA_FOTOGRAMMI = 6


def pulisci():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def unisci(oggetti):
    oggetti = [o for o in oggetti if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in oggetti:
        o.select_set(True)
    bpy.context.view_layer.objects.active = oggetti[0]
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if len(oggetti) > 1:
        bpy.ops.object.join()
    return bpy.context.view_layer.objects.active


def estremi(oggetti):
    punti = [o.matrix_world @ v.co for o in oggetti for v in o.data.vertices]
    mn = Vector((min(p.x for p in punti), min(p.y for p in punti), min(p.z for p in punti)))
    mx = Vector((max(p.x for p in punti), max(p.y for p in punti), max(p.z for p in punti)))
    return mn, mx


def a_terra(oggetti, giro):
    """Gira attorno a Z di `giro` gradi, poi centra in XY e appoggia a Z=0."""
    for o in oggetti:
        o.matrix_world = Matrix.Rotation(math.radians(giro), 4, "Z") @ o.matrix_world
    mn, mx = estremi(oggetti)
    spost = Vector((-(mn.x + mx.x) / 2, -(mn.y + mx.y) / 2, -mn.z))
    for o in oggetti:
        o.matrix_world = Matrix.Translation(spost) @ o.matrix_world


def mondo():
    sc = bpy.context.scene
    try:
        sc.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        sc.render.engine = "BLENDER_EEVEE"
    sc.view_settings.view_transform = "Standard"
    w = bpy.data.worlds.new("mondo")
    sc.world = w
    w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (1, 1, 1, 1)
    # Gli stessi numeri delle auto: ambiente generoso, sole quasi a picco.
    bg.inputs["Strength"].default_value = 0.55
    luce = bpy.data.lights.new("sole", type="SUN")
    luce.energy = 2.6
    ob = bpy.data.objects.new("sole", luce)
    sc.collection.objects.link(ob)
    ob.rotation_euler = (math.radians(16), 0, math.radians(35))


def scatta(oggetti, nome, riquadro=None):
    """Dall'alto, un'unita' = `PX_PER_METRO` pixel. `riquadro` (mn, mx) fissa
    l'inquadratura: serve ai fotogrammi della scala, che devono avere tutti la
    stessa taglia e lo stesso centro."""
    mn, mx = riquadro if riquadro else estremi(oggetti)
    sc = bpy.context.scene
    rx = int(round((mx.x - mn.x) * PX_PER_METRO)) + PAD * 2
    ry = int(round((mx.y - mn.y) * PX_PER_METRO)) + PAD * 2
    sc.render.resolution_x, sc.render.resolution_y = rx, ry
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    cd = bpy.data.cameras.new("cam")
    cd.type = "ORTHO"
    cd.clip_start, cd.clip_end = 1.0, 4000.0
    cd.ortho_scale = max(rx, ry) / PX_PER_METRO
    cam = bpy.data.objects.new("cam", cd)
    sc.collection.objects.link(cam)
    cam.location = ((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mx.z + 1000)
    sc.camera = cam
    sc.render.filepath = os.path.join(OUT, nome + ".png")
    bpy.ops.render.render(write_still=True)
    print("MEZZO %-16s %4dx%-4d px" % (nome, rx, ry))


def aerei():
    for nome, (file, giro) in AEREI.items():
        pulisci()
        mondo()
        bpy.ops.import_scene.fbx(filepath=os.path.join(SRC, "aerei", file))
        ob = unisci(list(bpy.context.scene.objects))
        a_terra([ob], giro)
        scatta([ob], nome)


def mezzi():
    for nome, (radice, giro) in MEZZI.items():
        pulisci()
        mondo()
        with bpy.data.libraries.load(os.path.join(SRC, "airportgroundvehiclesstarter.blend")) as (src, dst):
            dst.objects = [n for n in src.objects if n.startswith(radice)]
        for o in dst.objects:
            bpy.context.scene.collection.objects.link(o)
        oggetti = [o for o in dst.objects if o.type == "MESH"]
        # La parte alta della scala resta un oggetto a se': e' quella che sale.
        cima = next((o for o in oggetti if o.name == "StairsTop"), None)
        corpo = unisci([o for o in oggetti if o is not cima])
        pezzi = [corpo] + ([cima] if cima else [])
        if cima:
            bpy.ops.object.select_all(action="DESELECT")
            cima.select_set(True)
            bpy.context.view_layer.objects.active = cima
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        if giro is None:
            verso = (cima.matrix_world.translation if cima.data is None else
                     sum((cima.matrix_world @ v.co for v in cima.data.vertices), Vector()) / len(cima.data.vertices))
            centro = sum((corpo.matrix_world @ v.co for v in corpo.data.vertices), Vector()) / len(corpo.data.vertices)
            giro = -math.degrees(math.atan2(verso.y - centro.y, verso.x - centro.x))
        a_terra(pezzi, giro)
        if cima is None:
            scatta(pezzi, nome)
            continue
        # I fotogrammi della scala: la cima sale e avanza a scatti uguali.
        # Il passo e' quello di `cartandstairs.cs` (0,10 in su e 0,207 in
        # avanti per scatto), fino a sette scatti. Dall'alto la salita non si
        # vede: quello che si legge e' la piattaforma che si allunga.
        posa0 = cima.matrix_world.copy()
        # Dopo il giro la piattaforma guarda +X: e' li' che avanza.
        avanti = Vector((1, 0, 0))
        riquadri = []
        for i in range(SCALA_FOTOGRAMMI):
            k = 7.0 * i / (SCALA_FOTOGRAMMI - 1)
            cima.matrix_world = Matrix.Translation(Vector((0, 0, 0.10 * k)) + avanti * 0.207 * k) @ posa0
            bpy.context.view_layer.update()
            riquadri.append(estremi(pezzi))
        mn = Vector((min(r[0].x for r in riquadri), min(r[0].y for r in riquadri), 0))
        mx = Vector((max(r[1].x for r in riquadri), max(r[1].y for r in riquadri),
                     max(r[1].z for r in riquadri)))
        for i in range(SCALA_FOTOGRAMMI):
            k = 7.0 * i / (SCALA_FOTOGRAMMI - 1)
            cima.matrix_world = Matrix.Translation(Vector((0, 0, 0.10 * k)) + avanti * 0.207 * k) @ posa0
            scatta(pezzi, "%s_%02d" % (nome, i), (mn, mx))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    aerei()
    mezzi()
