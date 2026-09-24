"""Costruisce in Blender l'isolato commerciale di DOWNTOWN: un fabbricato
basso con quattro botteghe, renderizzate separate.

Da sinistra:

  * **PRIME REALTY**, l'agenzia immobiliare di DOWNTOWN, presa da una foto di
    un'agenzia americana: intonaco color sabbia, lesene bianche, cornicione
    bianco coi dentelli, la scritta blu grande sulla fascia, le vetrine piene
    di annunci appesi in fila e l'ingresso sotto al portichetto con la colonna;
  * **una lavanderia a gettoni**, con la fila di lavatrici dietro alla vetrina;
  * **un negozio di vestiti**, con i manichini in vetrina e la tenda a righe;
  * **un diner**, con la fascia rossa, le finestre col bancone e l'insegna
    OPEN al neon.

## Un fabbricato, quattro edifici

Come l'isolato cinese e il cinema: in gioco ogni bottega si clicca per conto
suo — l'agenzia apre l'elenco delle case di DOWNTOWN, le altre sono fondale —
quindi quattro PNG, ognuno largo ESATTAMENTE il suo lotto, che rimessi in fila
fanno l'isolato intero (656 px, da LOCK STREET a SEVENTH STREET). Si leggono
come un edificio solo perche' hanno lo stesso zoccolo, la stessa gronda, lo
stesso cornicione bianco a dentelli che corre su tutta la fila e le lesene
bianche sui muri in comune: meta' lesena per parte, e le due meta' si
rincontrano in gioco.

## Le animazioni

  * `lavatrici` — i cestelli che girano dietro agli oblo' (in ciclo);
  * `open` — l'insegna OPEN del diner, che ogni tanto sfarfalla.

Luce tutte e due (`emissive` nella voce): di notte restano accese.

Uso:
  blender --background --factory-startup --python scripts_tools/blender_isolato_downtown.py
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
import blender_cinema_videogiochi as cv  # noqa: E402
from blender_cinema_videogiochi import M, PEZZI, bx, finestra, piatto, righe, testo  # noqa: E402

OUT = cv.OUT
# Larghezze dei lotti in metri: 192 + 152 + 170 + 142 = 656 px, l'isolato.
UNITA = [("agenzia", 8.61), ("lavanderia", 6.82), ("vestiti", 7.62), ("diner", 6.37)]
PROF = 12.0
H = 5.6                 # gronda comune
H_PAR = 7.0             # sopra alla fascia dell'insegna
ZOCC = 0.45


def palette():
    cv.palette()
    M["sabbia"] = righe("DTB_Sabbia", "#B8A07A", "#A58D68", 1.4, frazione=0.02)
    M["bianco"] = piatto("DTB_Bianco", "#ECE8DE", 0.6)
    M["dentelli"] = righe("DTB_Dentelli", "#ECE8DE", "#B8B2A4", 0.3, asse="X", frazione=0.35)
    M["bianco_ombra"] = piatto("DTB_Bianco_Ombra", "#C8C2B4", 0.7)
    M["blu_scritta"] = piatto("DTB_Blu", "#1D3FB8", 0.4, emissivo="#2E58E8", forza=0.5)
    M["annunci"] = righe("DTB_Annunci", "#DCE6F2", "#2E5AA8", 0.36, asse="Z", frazione=0.35)
    M["mattoni"] = righe("DTB_Mattoni", "#8C4A38", "#6E3829", 0.12, frazione=0.18)
    M["verde_acqua"] = piatto("DTB_Verde_Acqua", "#4E9C9A", 0.6)
    M["lavatrice"] = piatto("DTB_Lavatrice", "#E4E6E8", 0.4)
    M["oblo"] = piatto("DTB_Oblo", "#7A9CB0", 0.1, emissivo="#9CC4DC", forza=0.5)
    M["cestello"] = piatto("DTB_Cestello", "#2E3A44", 0.3, 0.6, emissivo="#5E7A8C", forza=0.4)
    M["panni"] = piatto("DTB_Panni", "#E86A5A", 0.8, emissivo="#E86A5A", forza=0.3)
    M["nero_opaco"] = piatto("DTB_Nero", "#26262A", 0.7)
    M["tenda_a"] = righe("DTB_Tenda", "#E6DED0", "#2E4A6E", 0.5, asse="X", frazione=0.5)
    M["manichino"] = piatto("DTB_Manichino", "#E8E0D2", 0.5)
    M["abito_a"] = piatto("DTB_Abito_A", "#B8403A", 0.7)
    M["abito_b"] = piatto("DTB_Abito_B", "#3E6AA8", 0.7)
    M["abito_c"] = piatto("DTB_Abito_C", "#E0B840", 0.7)
    M["rosso_diner"] = piatto("DTB_Rosso", "#B8302C", 0.5)
    M["cromo"] = piatto("DTB_Cromo", "#C8CCD0", 0.2, 0.9)
    M["bancone"] = piatto("DTB_Bancone", "#D8C8A0", 0.5, emissivo="#E8D8B0", forza=0.3)
    M["neon_rosso"] = piatto("DTB_Neon_Rosso", "#FF4A3A", 0.3, emissivo="#FF5A40", forza=3.0)
    M["scritta_bianca"] = piatto("DTB_Scritta_Bianca", "#F4F2EC", 0.5, emissivo="#F4F2EC", forza=0.5)
    M["scritta_scura"] = piatto("DTB_Scritta_Scura", "#2A2A30", 0.5)


def quote():
    fette, x = {}, 0.0
    for chiave, w in UNITA:
        fette[chiave] = (x, x + w)
        x += w
    return fette


def cilindro_y(nome, x, y, z, r, prof, mat, raccolta=None):
    """Un disco che guarda la strada (asse lungo -Y): oblo', cestelli."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=r, radius2=r, depth=prof)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0),
                     matrix=__import__("mathutils").Matrix.Rotation(math.radians(90), 3, "X"))
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(M[mat])
    ob = bpy.data.objects.new(nome, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = (x, y, z)
    (raccolta if raccolta is not None else PEZZI).append(ob)
    return ob


def guscio(x0, x1, muro, testa_sx=False, testa_dx=False):
    """Quello che hanno tutte e quattro uguale, ed e' quello che le fa un
    edificio solo: corpo, zoccolo, fascia dell'insegna, cornicione a dentelli,
    parapetto, e mezza lesena bianca per parte.

    **Niente sporge in avanti a terra.** Il bordo basso di ogni PNG e' la riga
    di terra, e i quattro si allineano su quella: una colonna mezzo metro
    davanti alla facciata abbassava il suo sprite di dieci pixel, e in fila
    l'agenzia sarebbe finita piu' in basso delle vicine. Lesene e basi sporgono
    tutte uguali, di poco.

    Il parapetto e' un anello e non un blocco: pieno si prendeva tutto il
    tetto, che dall'alto sembrava un muro. Le testate di lato ci sono solo alle
    due estremita' dell'isolato (`testa_sx`, `testa_dx`): in mezzo il tetto
    corre di seguito da una bottega all'altra, come in un edificio solo."""
    bx("corpo", x0, x1, 0.0, PROF, 0.0, H, muro)
    bx("zoccolo", x0, x1, -0.06, 0.2, 0.0, ZOCC, "sabbia")
    bx("fascia", x0, x1, -0.12, 0.3, H - 0.1, H_PAR - 0.45, muro)
    bx("cornicione", x0, x1, -0.3, 0.3, H_PAR - 0.45, H_PAR - 0.2, "bianco")
    bx("dentelli", x0, x1, -0.24, -0.1, H_PAR - 0.6, H_PAR - 0.45, "dentelli")
    bx("cimasa", x0, x1, -0.34, 0.35, H_PAR - 0.2, H_PAR, "bianco")
    bx("parapetto_retro", x0, x1, PROF - 0.3, PROF, H, H_PAR - 0.2, muro)
    if testa_sx:
        bx("parapetto_sx", x0, x0 + 0.3, 0.0, PROF, H, H_PAR - 0.2, muro)
    if testa_dx:
        bx("parapetto_dx", x1 - 0.3, x1, 0.0, PROF, H, H_PAR - 0.2, muro)
    bx("tetto", x0, x1, 0.3, PROF - 0.3, H + 0.2, H + 0.3, "guaina")
    bx("marcapiano", x0, x1, -0.16, 0.2, H - 0.3, H - 0.1, "bianco")
    for k, (a, b) in enumerate(((x0, x0 + 0.28), (x1 - 0.28, x1))):
        bx("lesena%d" % k, a, b, -0.14, 0.0, 0.0, H - 0.3, "bianco")
        bx("lesena_base%d" % k, a, b, -0.16, 0.0, 0.0, 0.5, "bianco")


Y_SCRITTA = (H + H_PAR - 0.45) / 2 - 0.1


def agenzia(x0, x1, animati):
    guscio(x0, x1, "sabbia", testa_sx=True)
    xm = (x0 + x1) / 2
    testo("scritta_agenzia", "PRIME REALTY", xm, -0.14, Y_SCRITTA, 0.62, "blu_scritta")
    # Il portichetto d'ingresso a sinistra, come nella foto: la colonna bianca
    # sta sul filo delle lesene (vedi `guscio()`), la porta arretrata dietro.
    bx("colonna", x0 + 1.55, x0 + 1.85, -0.14, 0.0, 0.0, H - 0.3, "bianco")
    bx("colonna_base", x0 + 1.5, x0 + 1.9, -0.16, 0.0, 0.0, 0.5, "bianco")
    bx("portico_fondo", x0 + 0.28, x0 + 1.5, -0.02, 0.0, 0.0, H - 0.3, "bianco_ombra")
    finestra("porta", x0 + 0.55, x0 + 1.35, 0.1, 2.6, 0.0, "vetro_acceso")
    # Le vetrine con gli annunci: tre per gruppo, divise da una lesena.
    for g, (a, b) in enumerate(((x0 + 2.2, x0 + 5.1), (x0 + 5.5, x1 - 0.5))):
        w = (b - a) / 3
        for i in range(3):
            fa, fb = a + i * w + 0.08, a + (i + 1) * w - 0.08
            bx("vetr_cornice%d_%d" % (g, i), fa - 0.08, fb + 0.08, -0.08, 0.0, 1.3, 4.5, "bianco")
            finestra("vetr%d_%d" % (g, i), fa, fb, 1.4, 4.4, -0.08, "vetrina")
            # Gli annunci appesi: una colonna di fogli a righe, due per vetrina.
            for j, cx in enumerate((fa + (fb - fa) * 0.3, fa + (fb - fa) * 0.7)):
                bx("annuncio%d_%d_%d" % (g, i, j), cx - 0.16, cx + 0.16, -0.14, -0.12, 1.9, 4.0, "annunci")
        bx("pannelli%d" % g, a, b, -0.06, 0.0, ZOCC, 1.25, "sabbia")
    bx("lesena_mezzo", x0 + 5.15, x0 + 5.45, -0.3, 0.0, 0.0, H - 0.35, "bianco")


def lavanderia(x0, x1, animati):
    guscio(x0, x1, "sabbia")
    xm = (x0 + x1) / 2
    bx("fascia_colore", x0 + 0.3, x1 - 0.3, -0.16, -0.12, H + 0.05, H_PAR - 0.5, "verde_acqua")
    testo("scritta_lavanderia", "LAUNDROMAT", xm, -0.17, Y_SCRITTA, 0.52, "scritta_bianca")
    finestra("porta", x0 + 0.5, x0 + 1.4, 0.1, 2.6, 0.0, "vetrina")
    a, b = x0 + 1.8, x1 - 0.45
    finestra("vetrina", a, b, 0.6, 4.5, 0.0, "vetrina", montanti=2)
    # Le lavatrici dietro alla vetrina: in fila, due piani. Il cestello con
    # dentro i panni colorati e' l'animazione: gira.
    n = 4
    for riga, z in enumerate((1.3, 2.75)):
        for i in range(n):
            cx = a + 0.55 + i * (b - a - 1.1) / (n - 1)
            bx("lavatrice%d_%d" % (riga, i), cx - 0.5, cx + 0.5, -0.02, 0.0, z - 0.6, z + 0.6, "lavatrice")
            cilindro_y("oblo%d_%d" % (riga, i), cx, -0.04, z, 0.34, 0.03, "oblo")
            perno = bpy.data.objects.new("cestello%d_%d" % (riga, i), None)
            bpy.context.scene.collection.objects.link(perno)
            perno.location = (cx, -0.08, z)
            for k in range(3):
                pale = bx("pala%d_%d_%d" % (riga, i, k), -0.26, 0.26, -0.02, 0.0, -0.035, 0.035,
                          "cestello", raccolta=animati)
                pale.parent = perno
                pale.rotation_euler = (0, math.radians(60 * k), 0)
            panno = bx("panno%d_%d" % (riga, i), 0.06, 0.24, -0.03, -0.01, -0.2, -0.05,
                       "panni", raccolta=animati)
            panno.parent = perno
            animati.append(("perno", perno))


def vestiti(x0, x1, animati):
    guscio(x0, x1, "mattoni")
    xm = (x0 + x1) / 2
    bx("fascia_scura", x0 + 0.3, x1 - 0.3, -0.16, -0.12, H + 0.05, H_PAR - 0.5, "nero_opaco")
    testo("scritta_vestiti", "CLOTHING", xm, -0.17, Y_SCRITTA, 0.58, "scritta_bianca")
    # La tenda a righe sopra alla vetrina.
    a, b = x0 + 0.5, x1 - 0.5
    import mathutils
    me = bpy.data.meshes.new("tenda")
    y0, y1, z0, z1 = 0.0, -1.3, H - 0.4, H - 1.3
    me.from_pydata([(a, y0, z0), (b, y0, z0), (b, y1, z1), (a, y1, z1),
                    (a, y1, z1 - 0.35), (b, y1, z1 - 0.35)], [],
                   [(0, 1, 2, 3), (3, 2, 5, 4)])
    me.materials.append(M["tenda_a"])
    ob = bpy.data.objects.new("tenda", me)
    bpy.context.scene.collection.objects.link(ob)
    PEZZI.append(ob)
    _ = mathutils
    finestra("porta", xm - 0.5, xm + 0.5, 0.1, 2.7, 0.0, "vetro_acceso")
    for k, (fa, fb) in enumerate(((a + 0.1, xm - 0.8), (xm + 0.8, b - 0.1))):
        finestra("vetrina%d" % k, fa, fb, ZOCC + 0.1, 3.7, 0.0, "vetrina")
        # Due manichini per vetrina, vestiti di colori diversi.
        for j, cx in enumerate((fa + (fb - fa) * 0.3, fa + (fb - fa) * 0.72)):
            abito = ("abito_a", "abito_b", "abito_c")[(k * 2 + j) % 3]
            bx("man_testa%d%d" % (k, j), cx - 0.1, cx + 0.1, -0.1, -0.06, 2.75, 3.0, "manichino")
            bx("man_abito%d%d" % (k, j), cx - 0.25, cx + 0.25, -0.1, -0.06, 1.5, 2.75, abito)
            bx("man_gambe%d%d" % (k, j), cx - 0.12, cx + 0.12, -0.1, -0.06, 0.8, 1.5, "nero_opaco")


def diner(x0, x1, animati):
    guscio(x0, x1, "sabbia", testa_dx=True)
    xm = (x0 + x1) / 2
    bx("fascia_rossa", x0 + 0.3, x1 - 0.3, -0.16, -0.12, H + 0.05, H_PAR - 0.5, "rosso_diner")
    testo("scritta_diner", "DINER", xm, -0.17, Y_SCRITTA, 0.7, "scritta_bianca")
    bx("fascia_cromo", x0 + 0.3, x1 - 0.3, -0.16, -0.1, 3.8, 4.0, "cromo")
    finestra("porta", x1 - 1.5, x1 - 0.6, 0.1, 2.7, 0.0, "vetro_acceso")
    # Le finestre col bancone: dentro si vedono il bancone chiaro e gli sgabelli.
    a, b = x0 + 0.5, x1 - 1.8
    bx("bancone", a, b, -0.03, -0.01, ZOCC, 1.3, "bancone")
    finestra("vetrata", a, b, 1.4, 3.6, 0.0, "vetro_acceso", montanti=3)
    for i in range(4):
        cx = a + 0.4 + i * (b - a - 0.8) / 3
        bx("sgabello%d" % i, cx - 0.14, cx + 0.14, -0.08, -0.03, 0.5, 0.95, "rosso_diner")
    # L'insegna OPEN al neon, appesa dentro alla vetrata: l'animazione.
    bx("open_fondo", a + 0.25, a + 1.75, -0.08, -0.06, 2.75, 3.45, "nero_opaco")
    testo("open", "OPEN", a + 1.0, -0.1, 3.1, 0.5, "neon_rosso")
    animati.append(("open", bpy.context.scene.objects["open"]))


FUNZIONI = {"agenzia": agenzia, "lavanderia": lavanderia, "vestiti": vestiti, "diner": diner}
ANIM = {"lavanderia": ("lavatrici", 6), "diner": ("open", 12)}
# Lo sfarfallio del neon: acceso quasi sempre, qualche buco in mezzo. Il primo
# fotogramma e' la posa di riposo (acceso).
SFARFALLIO = [1, 0, 1, 0, 0, 1, 1, 0, 1, 1, 1, 1]


def costruisci(chiave):
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
    x0, x1 = quote()[chiave]
    grezzi = []
    FUNZIONI[chiave](x0, x1, grezzi)
    # Le animazioni possono consegnare oggetti o coppie (tipo, oggetto): i
    # perni dei cestelli e la scritta OPEN servono a posarle, non a
    # nasconderle.
    animati = [o for o in grezzi if not isinstance(o, tuple)]
    extra = [o for o in grezzi if isinstance(o, tuple)]
    for _, ob in extra:
        if ob.type == "FONT":
            animati.append(ob)
    cv.unisci(list(PEZZI), "DTB_" + chiave)
    cam = cv.scena()
    for ob in animati:
        ob.hide_render = True
    cv.inquadra(cam, x0, x1)
    return animati, extra


def renderizza():
    os.makedirs(OUT, exist_ok=True)
    sc = bpy.context.scene
    for chiave, _ in UNITA:
        costruisci(chiave)
        sc.render.filepath = os.path.join(OUT, "render_dt_%s.png" % chiave)
        bpy.ops.render.render(write_still=True)
        cv.modo_luci()
        sc.render.filepath = os.path.join(OUT, "luci_dt_%s.png" % chiave)
        bpy.ops.render.render(write_still=True)
        if chiave not in ANIM:
            print("DTB", chiave, sc.render.resolution_x, sc.render.resolution_y)
            continue
        animati, extra = costruisci(chiave)
        for ob in bpy.data.objects:
            if ob.type in ("MESH", "FONT"):
                ob.is_holdout = ob not in animati
        for ob in animati:
            ob.hide_render = False
        sc.render.use_freestyle = False
        cosa, n = ANIM[chiave]
        for i in range(n):
            if chiave == "lavanderia":
                # Tre pale: dopo 120 gradi il cestello si ripete.
                for tipo, perno in extra:
                    if tipo == "perno":
                        perno.rotation_euler = (0, math.radians(120.0 * i / n), 0)
            else:
                cv._set(cv._bsdf(M["neon_rosso"]), "Emission Strength", 3.0 if SFARFALLIO[i] else 0.1)
            sc.render.filepath = os.path.join(OUT, "anim_dt_%s_%s_%02d.png" % (chiave, cosa, i))
            bpy.ops.render.render(write_still=True)
        print("DTB", chiave, sc.render.resolution_x, sc.render.resolution_y)


if __name__ == "__main__":
    renderizza()
