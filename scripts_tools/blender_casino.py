"""Costruisce in Blender il casino' del COMMERCIAL DISTRICT: STAR CASINO.

Preso da una foto di un grande casino' americano: facciata simmetrica di pietra
chiara, due torrette con la lanterna illuminata di blu, le ali con i finestroni
ad arco e le vetrate a griglia gialle di luce, il porticato d'ingresso in mezzo
col tetto a padiglione, la cupola dietro, e davanti a tutto il mappamondo
gigante con l'anello e l'insegna. Le luci blu che salgono dal basso sui
pilastri.

Occupa un isolato intero — quello fra EAST STREET e HILL DRIVE, a sinistra del
grossista — quindi e' largo esattamente l'isolato (27,2 m, 606 px) e profondo
quanto basta a riempirlo. Davanti ha il suo piazzale d'ingresso, lastricato,
con l'aiuola di pietra del mappamondo: e' il LOTTO del casino', come il cortile
della casa, non marciapiede. Niente verde (la foto ne ha molto), niente
bandiere, niente auto: quelle le mette il gioco.

## Le animazioni

  * `mappamondo` — i meridiani del globo che girano piano (in ciclo);
  * `lampadine` — la fila di lampadine sul bordo del porticato, che ogni tanto
    fa la corsa come quella del cinema.

Tutte e due luce: in gioco restano accese di notte (`emissive`). Si fotografano
come quelle del cinema: tolte dal disegno, rifotografate da sole col resto in
holdout.

Uso:
  blender --background --factory-startup --python scripts_tools/blender_casino.py
  python scripts_tools/import_flats_art.py
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

try:
    HERE = os.path.dirname(os.path.abspath(__file__))
except NameError:
    HERE = os.path.join(os.getcwd(), "scripts_tools")
sys.path.insert(0, HERE)
# Gli attrezzi sono quelli del cinema: materiali a righe, scatole, finestre col
# vetro davanti al muro, scritte senza contorno, inquadratura sul lotto.
import blender_cinema_videogiochi as cv  # noqa: E402
from blender_cinema_videogiochi import M, PEZZI, bx, finestra, piatto, righe, testo  # noqa: E402

OUT = cv.OUT
W = 27.2                # l'isolato intero, 606 px
X0, X1 = -W / 2, W / 2
PIAZZALE = 7.5          # il lotto davanti alla facciata
PROF = 40.0             # il corpo del casino'
H = 11.0                # gronda
H_MANSARDA = 13.2
H_TORRE = 16.5


def palette():
    cv.palette()
    M["pietra_c"] = righe("CA_Pietra", "#DCCFB2", "#C4B697", 0.55, frazione=0.05)
    M["pietra_scura"] = piatto("CA_Pietra_Scura", "#9C8E74", 0.85)
    M["ardesia"] = righe("CA_Ardesia", "#3C4450", "#2F3640", 0.45, asse="Z", frazione=0.12)
    M["lastricato"] = righe("CA_Lastricato", "#B9B2A4", "#A39C8E", 1.2, asse="X", frazione=0.04)
    M["cordolo"] = piatto("CA_Cordolo", "#8C867A", 0.9)
    M["oro_vetro"] = piatto("CA_Vetro_Oro", "#9A7A34", 0.2, emissivo="#F2C04A", forza=1.2)
    M["blu_luce"] = piatto("CA_Blu_Luce", "#3A8FD8", 0.3, emissivo="#4FB4FF", forza=2.4)
    M["blu_vetro"] = piatto("CA_Vetro_Blu", "#2E6A9A", 0.2, emissivo="#58B8F0", forza=1.6)
    M["ingresso"] = piatto("CA_Ingresso", "#4A2A28", 0.3, emissivo="#D86848", forza=0.9)
    M["colonna"] = piatto("CA_Colonna", "#C9A56A", 0.5, 0.2)
    M["globo"] = piatto("CA_Globo", "#1E5A9E", 0.25, 0.4, emissivo="#2E78C8", forza=0.9)
    M["globo_linee"] = piatto("CA_Globo_Linee", "#9CC8F0", 0.3, 0.6, emissivo="#9CD2FF", forza=1.6)
    M["anello"] = piatto("CA_Anello", "#D8B45A", 0.3, 0.8, emissivo="#E8C060", forza=0.6)
    M["scritta"] = piatto("CA_Scritta", "#F2D680", 0.3, 0.6, emissivo="#FFE090", forza=1.4)
    M["tetto"] = piatto("CA_Tetto", "#8A857B", 0.93)
    M["insegna"] = piatto("CA_Insegna", "#1E2A44", 0.5, 0.3)
    M["lucernario"] = piatto("CA_Lucernario", "#5E7C90", 0.2, 0.3, emissivo="#7AA8C8", forza=0.25)
    M["stella"] = piatto("CA_Stella", "#FFFFFF", 0.3, emissivo="#FFF6D0", forza=3.0)


def poligono(nome, punti, facce, mat, raccolta=None):
    me = bpy.data.meshes.new(nome)
    me.from_pydata(punti, [], facce)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(M[mat])
    ob = bpy.data.objects.new(nome, me)
    bpy.context.scene.collection.objects.link(ob)
    (raccolta if raccolta is not None else PEZZI).append(ob)
    return ob


def tronco(nome, xa, xb, ya, yb, z0, rientro, z1, mat, punta=False, aperto=False):
    """Un tetto a padiglione (o una mansarda): la base e' il rettangolo, la cima
    lo stesso rettangolo rientrato di `rientro`. Con `punta` si chiude in un
    vertice solo."""
    if punta:
        cx, cy = (xa + xb) / 2, (ya + yb) / 2
        punti = [(xa, ya, z0), (xb, ya, z0), (xb, yb, z0), (xa, yb, z0), (cx, cy, z1)]
        facce = [(0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4), (3, 2, 1, 0)]
    else:
        r = rientro
        punti = [(xa, ya, z0), (xb, ya, z0), (xb, yb, z0), (xa, yb, z0),
                 (xa + r, ya + r, z1), (xb - r, ya + r, z1), (xb - r, yb - r, z1), (xa + r, yb - r, z1)]
        facce = [(0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7), (3, 2, 1, 0)]
        # La mansarda e' aperta in cima: dentro c'e' il tetto piano, e chiusa
        # si prendeva tutto il tetto d'ardesia scura.
        if not aperto:
            facce.append((4, 5, 6, 7))
    return poligono(nome, punti, facce, mat)


def arco(nome, xc, zc, r, y, mat, seg=12, raccolta=None):
    """Mezzo disco verticale (la lunetta di un finestrone ad arco)."""
    punti = [(xc, y, zc)] + [(xc + r * math.cos(math.pi * i / seg), y, zc + r * math.sin(math.pi * i / seg))
                             for i in range(seg + 1)]
    facce = [(0, i + 1, i + 2) for i in range(seg)]
    return poligono(nome, punti, facce, mat, raccolta)


def cilindro(nome, centro, r, h, mat, seg=24, raccolta=None, r2=None):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r,
                          radius2=r if r2 is None else r2, depth=h)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, h / 2))
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(M[mat])
    ob = bpy.data.objects.new(nome, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = centro
    (raccolta if raccolta is not None else PEZZI).append(ob)
    return ob


def cupola(nome, centro, r, mat, raccolta=None):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=12, radius=r)
    via = [v for v in bm.verts if v.co.z < -0.001]
    bmesh.ops.delete(bm, geom=via, context="VERTS")
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(M[mat])
    ob = bpy.data.objects.new(nome, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = centro
    (raccolta if raccolta is not None else PEZZI).append(ob)
    return ob


def toro(nome, R, r, mat, raccolta, seg=40, lati=6):
    """Un anello, nel piano XY e centrato nell'origine dell'oggetto."""
    bm = bmesh.new()
    anelli = []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        c = Vector((math.cos(a), math.sin(a), 0))
        anello = []
        for j in range(lati):
            b = 2 * math.pi * j / lati
            p = c * (R + r * math.cos(b)) + Vector((0, 0, r * math.sin(b)))
            anello.append(bm.verts.new(p))
        anelli.append(anello)
    for i in range(seg):
        for j in range(lati):
            a, b = anelli[i], anelli[(i + 1) % seg]
            bm.faces.new((a[j], a[(j + 1) % lati], b[(j + 1) % lati], b[j]))
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(M[mat])
    ob = bpy.data.objects.new(nome, me)
    bpy.context.scene.collection.objects.link(ob)
    raccolta.append(ob)
    return ob


# ----------------------------------------------------------------------
#  il casino'
# ----------------------------------------------------------------------

def piazzale():
    bx("piazzale", X0, X1, 0.0, PIAZZALE + 0.2, -0.05, 0.02, "lastricato")
    # L'aiuola di pietra del mappamondo: due gradoni tondi.
    cilindro("aiuola1", (0, 2.4, 0), 2.3, 0.35, "pietra_scura")
    cilindro("aiuola2", (0, 2.4, 0.35), 1.6, 0.35, "pietra_c")
    cilindro("piedistallo", (0, 2.4, 0.7), 0.35, 2.6, "colonna", r2=0.18)


def corpo():
    yf = PIAZZALE
    bx("corpo", X0, X1, yf, yf + PROF, 0.0, H, "pietra_c")
    bx("zoccolo", X0, X1, yf - 0.1, yf + 0.2, 0.0, 0.7, "pietra_scura")
    bx("cornicione", X0 - 0.15, X1 + 0.15, yf - 0.35, yf + PROF, H - 0.5, H, "pietra_scura")
    # La mansarda d'ardesia tutto intorno, e il tetto piano dentro.
    tronco("mansarda", X0, X1, yf - 0.2, yf + PROF, H, 2.4, H_MANSARDA, "ardesia", aperto=True)
    # Le luci blu che salgono dal basso lungo la facciata: una fascia sul
    # piede e una sotto al cornicione, come nella foto al tramonto.
    bx("blu_piede", X0 + 0.2, X1 - 0.2, yf - 0.18, yf - 0.12, 0.72, 0.84, "blu_luce")
    # Tetto: il lucernario a botte in mezzo e le macchine.
    zt = H_MANSARDA
    bx("tetto_piano", X0 + 2.3, X1 - 2.3, yf + 2.1, yf + PROF - 2.3, zt - 0.3, zt - 0.2, "tetto")
    for i in range(6):
        y = yf + 18 + i * 3.2
        bx("lucernario%d" % i, -5.0, 5.0, y, y + 2.6, zt - 0.2, zt + 0.4, "lucernario")
        bx("lucernario_c%d" % i, -5.1, 5.1, y + 2.6, y + 2.8, zt - 0.2, zt + 0.5, "copertina")
    for k, (a, b, c, d) in enumerate(((-11, -8, yf + 30, yf + 33), (8, 11, yf + 26, yf + 29),
                                      (-10.5, -8.5, yf + 14, yf + 16))):
        bx("macchina%d" % k, a, b, c, d, zt - 0.2, zt + 0.8, "macchina")


def ali():
    """Le due ali: vetrata a griglia gialla sotto, finestrone ad arco sopra."""
    yf = PIAZZALE
    for s in (-1, 1):
        cx = s * 10.8
        finestra("ala_giu%d" % s, cx - 2.0, cx + 2.0, 1.1, 4.0, yf, "oro_vetro", montanti=4, traversi=1)
        z0, z1, r = 4.9, 7.3, 2.0
        finestra("ala_su%d" % s, cx - r, cx + r, z0, z1, yf, "oro_vetro", montanti=4, traversi=1)
        arco("ala_arco%d" % s, cx, z1, r, yf - 0.035, "oro_vetro")
        # Il telaio della lunetta: raggi e bordo, sottili.
        for i in range(1, 4):
            a = math.pi * i / 4
            bx("raggio%d_%d" % (s, i), cx + math.cos(a) * 1.0 - 0.04, cx + math.cos(a) * 1.0 + 0.04,
               yf - 0.08, yf - 0.03, z1, z1 + math.sin(a) * r, "infisso")
        arco("ala_arco_bordo%d" % s, cx, z1, r + 0.18, yf + 0.0, "pietra_scura")
        bx("ala_chiave%d" % s, cx - 0.25, cx + 0.25, yf - 0.2, yf, z1 + r - 0.05, z1 + r + 0.45, "pietra_scura")
        # I lampioncini blu ai due lati dell'ala.
        for k, dx in enumerate((-2.6, 2.6)):
            bx("ala_blu%d_%d" % (s, k), cx + dx - 0.12, cx + dx + 0.12, yf - 0.2, yf, 0.8, H - 0.6, "blu_luce")


def torri():
    yf = PIAZZALE
    for s in (-1, 1):
        a, b = s * 5.2, s * 8.6
        xa, xb = min(a, b), max(a, b)
        y0 = yf - 0.8
        bx("torre%d" % s, xa, xb, y0, yf + 4.0, 0.0, H_TORRE, "pietra_c")
        bx("torre_zoccolo%d" % s, xa - 0.1, xb + 0.1, y0 - 0.1, yf + 4.0, 0.0, 0.9, "pietra_scura")
        for k, (z0, z1) in enumerate(((1.3, 4.3), (5.3, 8.6), (9.8, 13.2))):
            finestra("torre_fin%d_%d" % (s, k), xa + 0.7, xb - 0.7, z0, z1, y0, "oro_vetro",
                     montanti=2, traversi=2)
        bx("torre_fascia%d" % s, xa - 0.2, xb + 0.2, y0 - 0.25, yf + 4.2, 13.8, 14.3, "pietra_scura")
        # La lanterna in cima, coi vetri blu.
        bx("lanterna%d" % s, xa + 0.25, xb - 0.25, y0 + 0.3, yf + 3.7, H_TORRE, H_TORRE + 1.6, "pietra_c")
        finestra("lanterna_v%d" % s, xa + 0.6, xb - 0.6, H_TORRE + 0.3, H_TORRE + 1.35, y0 + 0.3,
                 "blu_vetro", montanti=3)
        bx("lanterna_gronda%d" % s, xa - 0.3, xb + 0.3, y0 - 0.2, yf + 4.3, H_TORRE + 1.6, H_TORRE + 1.8,
           "pietra_scura")
        tronco("lanterna_tetto%d" % s, xa - 0.3, xb + 0.3, y0 - 0.2, yf + 4.3, H_TORRE + 1.8, 0, H_TORRE + 3.0,
               "ardesia", punta=True)
        # Le luci blu che salgono sugli spigoli della torre.
        for k, x in enumerate((xa - 0.08, xb - 0.08)):
            bx("torre_blu%d_%d" % (s, k), x, x + 0.16, y0 - 0.15, y0, 0.9, 13.8, "blu_luce")


def ingresso(animati):
    """Il porticato: colonne, tetto a padiglione, la fascia con l'insegna, le
    lampadine sul bordo. Dietro, il timpano e la cupola."""
    yf = PIAZZALE
    xa, xb = -4.9, 4.9
    ya = yf - 4.2
    zp = 5.2
    # Il fondo: le porte a vetri rosse di luce.
    finestra("porte", -3.6, 3.6, 0.1, 3.4, yf, "ingresso", montanti=6)
    bx("porte_fascia", -4.2, 4.2, yf - 0.1, yf, 3.4, 4.2, "pietra_scura")
    for k, x in enumerate((-4.4, -1.5, 1.5, 4.4)):
        cilindro("colonna%d" % k, (x, ya + 0.4, 0), 0.32, zp, "colonna", seg=16)
        cilindro("colonna_base%d" % k, (x, ya + 0.4, 0), 0.45, 0.4, "pietra_scura", seg=16)
    bx("portico_trave", xa, xb, ya, yf, zp, zp + 0.9, "pietra_c")
    bx("portico_fascia", xa + 0.3, xb - 0.3, ya - 0.08, ya, zp + 0.1, zp + 0.8, "pietra_scura")
    # L'insegna non sta sul porticato: il mappamondo ci sta davanti e la
    # coprirebbe a meta'. Sta sul timpano, grande, sopra a tutto.
    tronco("portico_tetto", xa - 0.4, xb + 0.4, ya - 0.4, yf + 1.0, zp + 0.9, 0, zp + 3.0, "ardesia",
           punta=True)
    # Le lampadine sul bordo del porticato: l'animazione della corsa.
    for i in range(24):
        x = xa + 0.2 + (xb - xa - 0.4) * i / 23
        s = cv.sfera("lamp%d" % i, (x, ya - 0.12, zp + 0.05), 0.08, "lampadina%d" % (i % 3), animati)
        _ = s
    # Il timpano sopra all'ingresso, sulla facciata, e la cupola dietro.
    poligono("timpano", [(-6.5, yf - 0.1, H - 0.5), (6.5, yf - 0.1, H - 0.5), (0, yf - 0.1, H + 2.6),
                         (-6.5, yf + 3, H - 0.5), (6.5, yf + 3, H - 0.5), (0, yf + 3, H + 2.6)],
             [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)], "pietra_c")
    bx("timpano_cornice", -6.8, 6.8, yf - 0.3, yf + 0.2, H - 0.7, H - 0.4, "pietra_scura")
    bx("insegna_lastra", -4.3, 4.3, yf - 0.14, yf - 0.1, H - 0.3, H + 1.0, "insegna")
    testo("scritta_timpano", "STAR CASINO", 0, yf - 0.16, H + 0.35, 1.05, "scritta")
    yc = yf + 9.0
    cilindro("tamburo", (0, yc, H_MANSARDA - 0.3), 4.2, 2.4, "pietra_c", seg=32)
    bx("tamburo_blu", -3.0, 3.0, yc - 4.25, yc - 4.15, H_MANSARDA + 1.4, H_MANSARDA + 1.55, "blu_luce")
    cilindro("tamburo_cornice", (0, yc, H_MANSARDA + 2.1), 4.45, 0.3, "pietra_scura", seg=32)
    cupola("cupola", (0, yc, H_MANSARDA + 2.4), 4.2, "ardesia")
    cilindro("lanternino", (0, yc, H_MANSARDA + 6.5), 0.45, 0.8, "pietra_c", seg=12)


def mappamondo(animati):
    """Il mappamondo davanti all'ingresso: sfera blu, paralleli e meridiani di
    luce, l'anello d'oro inclinato, la stella e l'insegna. Tutto dentro
    all'animazione — e' luce, e deve restare accesa di notte — ma gira solo il
    perno dei meridiani."""
    c = Vector((0, 2.4, 5.4))
    R = 2.25
    sfera_ob = cv.sfera("globo", tuple(c), R * 0.97, "globo", animati)
    sfera_ob.scale = (1, 1, 1)
    for k, z in enumerate((-0.6, 0.0, 0.6)):
        rr = math.sqrt(1 - z * z) * R
        t = toro("parallelo%d" % k, rr, 0.05, "globo_linee", animati)
        t.location = c + Vector((0, 0, z * R))
    perno = bpy.data.objects.new("globo_perno", None)
    bpy.context.scene.collection.objects.link(perno)
    perno.location = c
    for k in range(6):
        t = toro("meridiano%d" % k, R, 0.05, "globo_linee", animati)
        t.parent = perno
        t.rotation_euler = (math.radians(90), 0, math.radians(30 * k))
    anello = toro("anello", R * 1.45, 0.08, "anello", animati, seg=56)
    anello.location = c
    anello.rotation_euler = (math.radians(72), math.radians(-18), 0)
    testo("scritta_globo", "STAR", c.x, c.y - R - 0.15, c.z + 0.15, 0.9, "scritta")
    ob = bpy.data.objects[-1] if False else bpy.context.scene.objects.get("scritta_globo")
    stella = cv.sfera("stella", (c.x + 0.9, c.y - R - 0.1, c.z + 1.1), 0.16, "stella", animati)
    _ = stella
    return perno, ob


def costruisci():
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
    animati = []
    piazzale()
    corpo()
    ali()
    torri()
    ingresso(animati)
    perno, scritta_globo = mappamondo(animati)
    animati.append(scritta_globo)
    cv.unisci(list(PEZZI), "CA_Casino")
    cam = cv.scena()
    for ob in animati:
        ob.hide_render = True
    # Le scritte fuori dall'animazione (l'insegna del porticato) restano.
    cv.inquadra(cam, X0, X1)
    return animati, perno


# La corsa delle lampadine, come al cinema.
CORSA = cv.CORSA
FOTOGRAMMI_GLOBO = 8


def renderizza():
    os.makedirs(OUT, exist_ok=True)
    sc = bpy.context.scene
    costruisci()
    sc.render.filepath = os.path.join(OUT, "render_casino.png")
    bpy.ops.render.render(write_still=True)
    cv.modo_luci()
    sc.render.filepath = os.path.join(OUT, "luci_casino.png")
    bpy.ops.render.render(write_still=True)

    for cosa in ("mappamondo", "lampadine"):
        animati, perno = costruisci()
        globo = [o for o in animati if not o.name.startswith("lamp")]
        lampadine = [o for o in animati if o.name.startswith("lamp")]
        tengo = globo if cosa == "mappamondo" else lampadine
        for ob in bpy.data.objects:
            if ob.type in ("MESH", "FONT"):
                ob.is_holdout = ob not in tengo
                ob.hide_render = ob in animati and ob not in tengo
        for ob in tengo:
            ob.hide_render = False
        sc.render.use_freestyle = False
        if cosa == "mappamondo":
            for i in range(FOTOGRAMMI_GLOBO):
                # Sei meridiani: dopo trenta gradi il disegno si ripete.
                perno.rotation_euler = (0, 0, math.radians(30.0 * i / FOTOGRAMMI_GLOBO))
                sc.render.filepath = os.path.join(OUT, "anim_casino_mappamondo_%02d.png" % i)
                bpy.ops.render.render(write_still=True)
        else:
            for i, fase in enumerate(CORSA):
                for k in range(3):
                    cv._set(cv._bsdf(M["lampadina%d" % k]), "Emission Strength",
                            4.0 if fase[k] else 0.15)
                sc.render.filepath = os.path.join(OUT, "anim_casino_lampadine_%02d.png" % i)
                bpy.ops.render.render(write_still=True)
    print("CASINO", sc.render.resolution_x, sc.render.resolution_y)


if __name__ == "__main__":
    renderizza()
