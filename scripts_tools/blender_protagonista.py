"""Anima il disegno del protagonista in Blender: un cut-out, non un modello 3D.

Il disegno scontornato (`scontorna_protagonista.py`) viene diviso in cinque
pezzi — busto con la testa, le due braccia, le due gambe — e ogni pezzo e' una
griglia piatta con sopra la sua parte del disegno, deformata da uno scheletro.
Le gambe hanno coscia e stinco, cosi' il ginocchio si piega invece di spezzarsi.

Il disegno e' gia' a meta' passo (gamba vicina avanti, lontana dietro): quella
e' la posa del frame 0, e il ciclo ruota anche e spalle intorno a lei.

    blender --background --factory-startup --python scripts_tools/blender_protagonista.py

Esce in `assets/sprites/characters/_source/camminata/`: `passo_0..7.png` e
`fermo.png`. Poi `python scripts_tools/import_protagonista.py`.
"""
import math
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/sprites/characters/_source/protagonista_scontornato.png"
OUT = ROOT / "assets/sprites/characters/_source/camminata"

U = 0.01  # metri di Blender per pixel del disegno
CELL = 2  # lato della griglia, in pixel del disegno
FRAMES = 8
# Il riquadro renderizzato, in pixel del disegno: piu' largo della figura
# perche' braccia e gambe escono quando oscillano.
CANVAS = (-30, -10, 210, 330)  # x0, y0, larghezza, altezza
RENDER_SCALE = 2

# Le ossa, in pixel del disegno (x a destra, y in giu').
BONES = {
    "root": ((78, 182), (78, 160), None),
    "torso": ((78, 175), (78, 100), "root"),
    "head": ((80, 100), (80, 40), "torso"),
    "arm_b": ((40, 92), (18, 170), "torso"),
    "arm_f": ((102, 88), (136, 160), "torso"),
    "thigh_b": ((70, 182), (52, 218), "root"),
    "shin_b": ((52, 218), (40, 242), "thigh_b"),
    "thigh_f": ((88, 182), (88, 228), "root"),
    "shin_f": ((88, 228), (102, 276), "thigh_f"),
}

ARM_B = [(0, 78), (47, 78), (40, 100), (34, 120), (32, 140), (31, 165), (33, 200), (0, 200)]
ARM_F = [(100, 84), (160, 84), (160, 200), (128, 200), (113, 160), (108, 140), (104, 115), (100, 100)]

# Dietro -> davanti. La y di Blender e' la profondita' (la camera guarda +Y).
LAYERS = ["arm_b", "leg_b", "leg_f", "torso", "arm_f"]

# Ampiezze del ciclo, in gradi (positivo = in avanti).
LEG_SWING = 35.0
KNEE_BEND = 32.0
ARM_SWING = 20.0
BOB = 3.0  # pixel del disegno


def world(p):
    return Vector((p[0] * U, 0.0, -p[1] * U))


def in_polygon(xs, ys, poly):
    inside = np.zeros(xs.shape, dtype=bool)
    n = len(poly)
    for i in range(n):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % n]
        cond = (y1 > ys) != (y2 > ys)
        with np.errstate(divide="ignore", invalid="ignore"):
            xint = x1 + (ys - y1) * (x2 - x1) / (y2 - y1)
        inside ^= cond & (xs < xint)
    return inside


def split_x(y):
    """Dove si separano le gambe: sotto il cavallo c'e' un vuoto, sopra no."""
    return np.full_like(y, 71.0)


def masks(h, w):
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64) + 0.5
    arm_b = in_polygon(xs, ys, ARM_B)
    arm_f = in_polygon(xs, ys, ARM_F)
    body = ~arm_b & ~arm_f
    legs = body & (ys >= 165)
    crotch = ys < 218
    return {
        "arm_b": arm_b,
        "arm_f": arm_f,
        "torso": body & (ys < 178),
        # Sopra il cavallo le due gambe si prendono entrambe la fascia di
        # mezzo: quando si aprono non resta un buco fra loro.
        "leg_b": legs & np.where(crotch, xs < 84, xs < split_x(ys)),
        "leg_f": legs & np.where(crotch, xs > 62, xs >= split_x(ys)),
    }


def weights(piece, x, y):
    if piece == "arm_b":
        return {"arm_b": 1.0}
    if piece == "arm_f":
        return {"arm_f": 1.0}
    if piece == "torso":
        t = min(max((y - 92.0) / 12.0, 0.0), 1.0)
        return {"head": 1.0 - t, "torso": t}
    side = piece[-1]
    (hx, hy), (kx, ky), _ = BONES["thigh_" + side]
    d = Vector((kx - hx, ky - hy))
    s = Vector((x - kx, y - ky)).dot(d.normalized())
    t = min(max((s + 6.0) / 12.0, 0.0), 1.0)
    return {"thigh_" + side: 1.0 - t, "shin_" + side: t}


def clear_scene():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)


def piece_image(name, rgba_bottom_up, mask_top_down):
    h, w, _ = rgba_bottom_up.shape
    data = rgba_bottom_up.copy()
    data[:, :, 3] *= mask_top_down[::-1]
    img = bpy.data.images.new(name, w, h, alpha=True)
    img.pixels.foreach_set(data.ravel())
    img.pack()
    return img


def material(name, img):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    tex.extension = "CLIP"
    emit = nt.nodes.new("ShaderNodeEmission")
    clear = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(tex.outputs["Color"], emit.inputs["Color"])
    nt.links.new(tex.outputs["Alpha"], mix.inputs["Fac"])
    nt.links.new(clear.outputs[0], mix.inputs[1])
    nt.links.new(emit.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    return mat


def grid_mesh(name, piece, mask, w, h, depth):
    ys, xs = np.nonzero(mask)
    x0 = max(int(xs.min()) // CELL * CELL - CELL, 0)
    y0 = max(int(ys.min()) // CELL * CELL - CELL, 0)
    x1 = min(int(xs.max()) + 2 * CELL, w)
    y1 = min(int(ys.max()) + 2 * CELL, h)
    gx = list(range(x0, x1 + 1, CELL))
    gy = list(range(y0, y1 + 1, CELL))
    verts, uvs, faces = [], [], []
    for y in gy:
        for x in gx:
            verts.append((x * U, depth, -y * U))
    nx = len(gx)
    for j in range(len(gy) - 1):
        for i in range(nx - 1):
            a = j * nx + i
            faces.append((a, a + nx, a + nx + 1, a + 1))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    uv = mesh.uv_layers.new()
    for poly in mesh.polygons:
        for li in poly.loop_indices:
            v = mesh.loops[li].vertex_index
            x, y = gx[v % nx], gy[v // nx]
            uv.data[li].uv = (x / w, 1.0 - y / h)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    groups = {}
    for vi, (x, _, z) in enumerate(verts):
        for bone, wgt in weights(piece, x / U, -z / U).items():
            if wgt <= 0.0:
                continue
            if bone not in groups:
                groups[bone] = obj.vertex_groups.new(name=bone)
            groups[bone].add([vi], wgt, "REPLACE")
    return obj


def build_armature():
    arm_data = bpy.data.armatures.new("rig")
    rig = bpy.data.objects.new("rig", arm_data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for name, (head, tail, parent) in BONES.items():
        eb = arm_data.edit_bones.new(name)
        eb.head = world(head)
        eb.tail = world(tail)
        eb.roll = 0.0
        if parent:
            eb.parent = arm_data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def rotate(rig, bone, degrees):
    """Ruota l'osso nel piano del disegno; positivo = antiorario a schermo."""
    pb = rig.pose.bones[bone]
    rest = pb.bone.matrix_local.to_3x3()
    turn = Matrix.Rotation(math.radians(-degrees), 3, "Y")
    pb.rotation_mode = "QUATERNION"
    pb.rotation_quaternion = (rest.inverted() @ turn @ rest).to_quaternion()


def lift(rig, dz):
    pb = rig.pose.bones["root"]
    pb.location = pb.bone.matrix_local.to_3x3().inverted() @ Vector((0.0, 0.0, dz))


def ankle_z(rig, side):
    return (rig.matrix_world @ rig.pose.bones["shin_" + side].tail).z


def pose(rig, legs, knees, arms, stance_f):
    """Mette la posa e abbassa le anche finche' il piede d'appoggio tocca terra.

    Ruotando le gambe intorno alle anche i piedi salgono: nella camminata vera
    sono le anche a scendere. `stance_f` e' quanto pesa la gamba vicina.
    """
    rotate(rig, "thigh_f", legs[0])
    rotate(rig, "thigh_b", legs[1])
    rotate(rig, "shin_f", knees[0])
    rotate(rig, "shin_b", knees[1])
    rotate(rig, "arm_f", arms[0])
    rotate(rig, "arm_b", arms[1])
    lift(rig, 0.0)
    bpy.context.view_layer.update()
    rise_f = ankle_z(rig, "f") - REST_ANKLE["f"]
    rise_b = ankle_z(rig, "b") - REST_ANKLE["b"]
    return -(stance_f * rise_f + (1.0 - stance_f) * rise_b)


REST_ANKLE = {}


def setup_render():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.film_transparent = True
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    x0, y0, cw, ch = CANVAS
    scene.render.resolution_x = cw * RENDER_SCALE
    scene.render.resolution_y = ch * RENDER_SCALE
    scene.render.resolution_percentage = 100
    scene.render.filter_size = 0.5
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = max(cw, ch) * U
    cam = bpy.data.objects.new("cam", cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = ((x0 + cw / 2) * U, -5.0, -(y0 + ch / 2) * U)
    cam.rotation_euler = (math.pi / 2, 0.0, 0.0)
    scene.camera = cam


def render(path):
    bpy.context.scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def main():
    clear_scene()
    src = bpy.data.images.load(str(SRC))
    w, h = src.size
    rgba = np.array(src.pixels[:], dtype=np.float32).reshape(h, w, 4)
    piece_masks = masks(h, w)

    rig = build_armature()
    for depth_index, piece in enumerate(LAYERS):
        mask = piece_masks[piece]
        img = piece_image("tex_" + piece, rgba, mask.astype(np.float32))
        obj = grid_mesh(piece, piece, mask, w, h, -depth_index * 0.01)
        obj.data.materials.append(material("mat_" + piece, img))
        mod = obj.modifiers.new("rig", "ARMATURE")
        mod.object = rig
        obj.parent = rig

    setup_render()
    bpy.context.view_layer.update()
    REST_ANKLE["f"] = ankle_z(rig, "f")
    REST_ANKLE["b"] = ankle_z(rig, "b")

    OUT.mkdir(parents=True, exist_ok=True)
    for i in range(FRAMES):
        t = i / FRAMES
        swing = (1.0 - math.cos(2 * math.pi * t)) / 2.0
        # Ogni gamba piega il ginocchio solo mentre e' in aria.
        knee_f = -KNEE_BEND * math.sin(2 * math.pi * (t - 0.5)) if t > 0.5 else 0.0
        knee_b = -KNEE_BEND * math.sin(2 * math.pi * t) if t < 0.5 else 0.0
        stance_f = (1.0 + math.cos(2 * math.pi * (t - 0.25))) / 2.0
        dz = pose(
            rig,
            (-LEG_SWING * swing, LEG_SWING * swing),
            (knee_f, knee_b),
            (-ARM_SWING * swing, ARM_SWING * swing),
            stance_f,
        )
        # Il corpo sale quando le gambe si incrociano, come in ogni passo.
        dz += BOB * U * abs(math.sin(2 * math.pi * t))
        lift(rig, dz)
        render(OUT / f"passo_{i}.png")

    # Da fermo: gambe sotto le anche, braccia lungo i fianchi.
    dz = pose(rig, (-9.0, 27.0), (0.0, 0.0), (-16.0, 10.0), 0.5)
    lift(rig, dz)
    render(OUT / "fermo.png")
    print("PROTAGONISTA OK")


if __name__ == "__main__":
    main()
