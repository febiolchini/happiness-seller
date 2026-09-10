"""Renderizza i veicoli low-poly a sprite 2D visti dall'alto.

Il gioco disegna le auto dall'alto (un rettangolo 44x20 in car.gd), quindi
serve una camera ortografica che guarda dritto in giù. Un solo render per
veicolo basta per tutte e quattro le direzioni: dall'alto, girare lo sprite
di 90 gradi è esatto.

Uso:
  blender --background --python render_cars.py -- <cartella_pack> <cartella_out>
"""

import math
import os
import sys

import bpy

PACK, OUT = sys.argv[sys.argv.index("--") + 1:][:2]
# Assoluti: `bpy.data.images.load()` risolve i path relativi rispetto al .blend,
# che in background non esiste, e non trova niente. L'importer OBJ invece usa il
# path così com'è, ed è il motivo per cui i modelli si caricavano e le texture no.
PACK = os.path.abspath(PACK)
OUT = os.path.abspath(OUT)

# Lunghezza a schermo di un'auto normale, in pixel: la stessa `BODY_LENGTH`
# che car.gd disegnava a mano. Tutti gli altri veicoli sono scalati con lo
# stesso fattore, così il bus resta più lungo di una berlina.
CAR_PIXELS = 44.0
REFERENCE = "car01"
# Margine intorno allo sprite: senza, le ruote esterne finiscono tagliate a
# filo del bordo e in movimento si vede lo scalino.
PAD = 2

# nome del modello -> nome della texture (il pacchetto non ha .mtl)
MODELS = {
    "bus": "bus01",
    "car01": "car01",
    "car02": "car02",
    "car03": "car03",
    "carPolice": "carPolice",
    "pickupTruck01": "pickupTruck01",
    "pickupTruck02": "pickupTruck02",
}


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for item in list(block):
            block.remove(item)


def load(model):
    path = os.path.join(PACK, "OBJ", "Low_Poly_Vehicles_%s.obj" % model)
    # L'OBJ viene da un export FBX: Y in alto, avanti -Z.
    bpy.ops.wm.obj_import(filepath=path, forward_axis="NEGATIVE_Z", up_axis="Y")
    meshes = [o for o in bpy.context.selected_objects if o.type == "MESH"]
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


def shade(obj, texture):
    mat = bpy.data.materials.new("veicolo")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(
        os.path.join(PACK, "Texture", "%s.png" % texture))
    # Nearest: la texture è piatta a campiture, e interpolare inventa sfumature
    # sui bordi fra una campitura e l'altra.
    tex.interpolation = "Closest"
    mat.node_tree.links.new(bsdf.inputs["Base Color"], tex.outputs["Color"])
    bsdf.inputs["Roughness"].default_value = 0.85
    bsdf.inputs["Metallic"].default_value = 0.0
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def bounds(obj):
    corners = [obj.matrix_world @ v.co for v in obj.data.vertices]
    xs = [c.x for c in corners]
    ys = [c.y for c in corners]
    zs = [c.z for c in corners]
    return (min(xs), max(xs)), (min(ys), max(ys)), (min(zs), max(zs))


def lay_along_x(obj):
    """Mette il lato lungo del veicolo sull'asse X (che a schermo è la destra)."""
    (x0, x1), (y0, y1), _ = bounds(obj)
    if (y1 - y0) > (x1 - x0):
        obj.rotation_euler[2] = math.radians(90)
        bpy.ops.object.transform_apply(rotation=True)


def setup_world():
    world = bpy.data.worlds.new("mondo")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (1, 1, 1, 1)
    # Poca luce ambiente e un sole quasi a picco. Con l'ambiente alto il rosso
    # dell'auto veniva rosa slavato: quello che serve e' che il tetto esca del
    # colore che ha nella texture, e che i fianchi scendano appena piu' scuri
    # per dare la forma. Sole a pi greco: e' l'energia per cui una superficie
    # rivolta in su rende esattamente il proprio colore.
    # Ambiente generoso: il cassone di un pickup e il vano di una cabina non
    # vedono il sole, e con poca luce diffusa escono neri — mezzo veicolo
    # diventa un buco invece di un pianale.
    bg.inputs["Strength"].default_value = 0.55
    light = bpy.data.lights.new("sole", type="SUN")
    light.energy = 2.6
    rig = bpy.data.objects.new("sole", light)
    bpy.context.collection.objects.link(rig)
    rig.rotation_euler = (math.radians(16), 0, math.radians(35))


def render(obj, name):
    (x0, x1), (y0, y1), (_, z1) = bounds(obj)
    span_x, span_y = x1 - x0, y1 - y0
    ppu = CAR_PIXELS / REFERENCE_LENGTH

    res_x = max(1, int(round(span_x * ppu)) + PAD * 2)
    res_y = max(1, int(round(span_y * ppu)) + PAD * 2)

    scene = bpy.context.scene
    scene.render.resolution_x = res_x
    scene.render.resolution_y = res_y
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"

    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    # La camera sta mille unita' sopra al veicolo, e il clipping di default si
    # ferma a cento: senza allargarlo il fotogramma esce vuoto.
    cam_data.clip_start = 1.0
    cam_data.clip_end = 4000.0
    # `ortho_scale` copre sempre il lato più lungo del fotogramma: legandolo
    # alla risoluzione, un'unità di modello vale esattamente `ppu` pixel su
    # entrambi gli assi, e i veicoli restano in scala fra loro.
    cam_data.ortho_scale = max(res_x, res_y) / ppu
    cam = bpy.data.objects.new("cam", cam_data)
    bpy.context.collection.objects.link(cam)
    # Dritto dall'alto, "su" del fotogramma verso +Y.
    cam.location = ((x0 + x1) / 2, (y0 + y1) / 2, z1 + 1000)
    cam.rotation_euler = (0, 0, 0)
    scene.camera = cam

    scene.render.filepath = os.path.join(OUT, "%s.png" % name)
    bpy.ops.render.render(write_still=True)
    print("RESO %s  %dx%d px" % (name, res_x, res_y))


scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
# "Standard" e non AgX: la trasformazione di default e' fatta per le foto e
# smorza i colori saturi: il rosso dell'auto usciva rosa. Qui serve che il
# colore a schermo sia quello della texture, non una sua interpretazione.
scene.view_settings.view_transform = "Standard"

# Prima passata: quanto è lungo il veicolo di riferimento, in unità di modello.
clear()
ref = load(REFERENCE)
lay_along_x(ref)
(rx0, rx1), _, _ = bounds(ref)
REFERENCE_LENGTH = rx1 - rx0
print("riferimento %s: %.1f unita'" % (REFERENCE, REFERENCE_LENGTH))

os.makedirs(OUT, exist_ok=True)
for model, texture in MODELS.items():
    clear()
    setup_world()
    obj = load(model)
    lay_along_x(obj)
    shade(obj, texture)
    render(obj, texture)
