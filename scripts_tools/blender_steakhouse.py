"""Costruisce in Blender la steak house del COMMERCIAL DISTRICT: COPPER STEER.

Sta sopra al parcheggio del grossista dei semi, con la facciata rivolta verso il
parcheggio: in ordine dall'alto ristorante, parcheggio, grossista. Occupa tutto
quello che resta dell'isolato: larga dal marciapiede di HILL DRIVE a quello di
PORT STREET (656 px, 29,4 m a 22,3 px/m) e alta fin quasi a quello di HILLTOP
ROAD.

Presa da una foto di una steak house americana di catena, senza copiarne il
nome: un piano solo lungo, intonaco rosso a riquadri con le fughe chiare,
pilastri e zoccolo di mattoni, e in mezzo la torre dell'ingresso — mattoni,
cornicione nero a dentelli, lo scudo rosso a triangolo, la finestra ad arco
nella cornice crema e sotto la pensilina nera sopra alle porte a vetri. A
sinistra la scritta, il murale e la porta di servizio con la sua tendina; a
destra le vetrate sotto le tende nere, col locale acceso dietro.

Niente palme, panchine, aiuole ne' marciapiede: quello che sta a terra e' citta'
(vedi la nota in cima a `render_buildings.py`).

**Tende e pensilina sono alte apposta**, per la stessa ragione del portico del
negozio di bici: con la camera a 27 gradi il raggio che parte dalla cima di una
vetrina sale di mezzo metro per ogni metro che fa verso la camera, e deve passare
sotto al bordo della tenda. Per questo le tende partono settanta centimetri
sopra alle vetrate e sporgono solo sessanta.

**Il camino della griglia sta davanti, non dietro.** Il fumo si fotografa con la
stessa inquadratura dell'edificio e in `import_flats_art.py` passa dallo stesso
ritaglio: un camino sul fondo del tetto fa uscire il fumo subito sopra al bordo
dello sprite, e il ritaglio se lo mangia. Sulla fascia davanti del tetto il
fumo ha quasi due metri per salire prima di arrivare alla cima del disegno.

## Le animazioni

Tutte sporadiche, come quelle del negozio di bici:

  * `porta` — le due ante a vetri dell'ingresso: ogni tanto qualcuno entra, le
    ante si aprono verso il parcheggio e si richiudono piano, col chiudiporta;
  * `fumo` — tre sbuffi dal camino della griglia che salgono, si allargano e
    si disperdono col vento. Il primo fotogramma, quello di riposo, ha solo un
    filo di fumo: vuoto del tutto, il ritaglio della striscia non saprebbe dove
    tagliare;
  * `neon` — la scritta OPEN in vetrina, che ogni tanto sfarfalla. E' luce, e
    in gioco resta accesa di notte.

Si fotografano come quelle del negozio di bici: tolte dal disegno, rifotografate
da sole col resto in holdout.

Uso (un pezzo per processo: vedi `renderizza()`; il numero dopo il nome e' il
fotogramma da cui ripartire):
  blender --background --factory-startup --python scripts_tools/blender_steakhouse.py -- base
  blender --background --factory-startup --python scripts_tools/blender_steakhouse.py -- porta
  blender --background --factory-startup --python scripts_tools/blender_steakhouse.py -- fumo
  blender --background --factory-startup --python scripts_tools/blender_steakhouse.py -- neon 4
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
# Scena, camera, luci, inquadratura e scritte sono quelle del cinema; mattone,
# vetri trasparenti e muro forato quelli dell'isolato cinese; i tubi quelli del
# negozio di bici.
import blender_bici as bi  # noqa: E402
import blender_cinema_videogiochi as cv  # noqa: E402
import blender_isolato_cinese as ic  # noqa: E402
from blender_cinema_videogiochi import M, PEZZI, bx, piatto, testo  # noqa: E402

OUT = cv.OUT
# Tutto l'isolato, dal marciapiede di HILL DRIVE a quello di PORT STREET: 656
# px, 29,4 m.
W = 656.0 / cv.PX_PER_METRO
# L'altezza la decide lo spazio che c'e' fra il parcheggio e il marciapiede di
# HILLTOP ROAD, 244 px, e la occupano insieme la gronda e la profondita': da 27
# gradi un metro d'altezza vale 20 px di sprite e uno di profondita' 10. Tutta
# in profondita' sarebbe stata un tetto grigio grande quanto la facciata.
PROF = 10.0                     # profondita' del locale
TORRE_FONDO = 2.0               # dove finisce la torre, dietro
SP = 0.3                        # spessore del muro di facciata
H = 6.2                         # gronda delle due ali
H_TORRE = 9.2                   # gronda della torre
ZOC = 0.75                      # lo zoccolo di mattoni sotto all'intonaco
PIL = 0.75                      # larghezza dei pilastri d'angolo

# La torre dell'ingresso in mezzo, e quanto sporge dal filo delle ali.
XC = W / 2
TX0, TX1 = XC - 2.2, XC + 2.2
TY = -0.7

# L'ingresso: vano, sopraluce e le due ante (quelle che si aprono).
VANO = (XC - 1.25, XC + 1.25)
VANO_Z = 2.75
ANTE = ((XC - 0.9, XC), (XC, XC + 0.9))
ANTE_Z = 2.45
# La finestra ad arco sopra alla pensilina.
ARCO = (XC - 0.8, XC + 0.8)
ARCO_Z = 3.7
ARCO_C = 5.6                    # centro dell'arco
ARCO_R = (ARCO[1] - ARCO[0]) / 2
# La pensilina: alta e poco profonda, se no copre le ante (vedi sopra).
PENS_Z = 3.0
PENS_S = 1.0
# Scritte e lampioncini sulle ali.
Z_SCRITTE = 4.9
Z_LAMPIONCINI = H - 0.45

# Ala sinistra: murale, una vetrata e la porta di servizio. Ala destra: tre
# vetrate.
PORTA_SX = (TX0 - 1.45, TX0 - 0.55)
MURALE = (1.4, 6.4, 1.05, 3.05)
VETRATE_SX = ((7.3, 10.2),)
VETRATE = tuple((TX1 + 0.8 + 3.4 * i, TX1 + 3.7 + 3.4 * i) for i in range(3))
VETRATE_Z = (ZOC, 2.7)
Y_VETRO = 0.12

# Il camino della griglia (vedi sopra perche' davanti).
CAMINO = (TX1 + 9.4, 2.2)
CAMINO_Z = H + 1.3


def palette():
    cv.palette()
    M["mattone"] = ic.mattone("ST_Mattone", "#B8624E", "#9A4F3F", "#D8CEC2", "#76584C",
                              seme=3.0, macchie=0.26)
    M["mattone_lato"] = ic.mattone("ST_Mattone_Lato", "#9C5242", "#834335", "#BDB2A6", "#634638",
                                   seme=4.0, macchie=0.32)
    M["intonaco"] = griglia("ST_Intonaco", "#B23B2D", "#D2B1A2", 2.5, 1.8)
    M["intonaco_lato"] = griglia("ST_Intonaco_Lato", "#93301F", "#B0907F", 2.5, 1.8)
    M["nero"] = piatto("ST_Nero", "#1E1C1B", 0.7)
    M["tenda"] = piatto("ST_Tenda", "#19191B", 0.85)
    M["crema"] = piatto("ST_Crema", "#E6DBC8", 0.8)
    M["scudo"] = piatto("ST_Scudo", "#C23328", 0.5)
    M["scudo_bordo"] = piatto("ST_Scudo_Bordo", "#EDE6D8", 0.6)
    M["catrame"] = piatto("ST_Catrame", "#4A453F", 0.97)
    M["metallo"] = piatto("ST_Metallo", "#A8ADB0", 0.35, 0.85)
    M["lettere"] = piatto("ST_Lettere", "#F4F1EA", 0.5, emissivo="#FFF4DC", forza=0.5)
    M["lampadina"] = piatto("ST_Lampadina", "#F4E2B0", 0.3, emissivo="#FFE6A0", forza=2.0)
    M["vetrina"] = ic.trasparente(piatto("ST_Vetrina", "#3A4442", 0.10, 0.2,
                                         emissivo="#C9A86A", forza=0.22), 0.28)
    M["vetro_porta"] = ic.trasparente(piatto("ST_Vetro_Porta", "#5A6A66", 0.10, 0.2), 0.35)
    M["vetro_arco"] = piatto("ST_Vetro_Arco", "#2E3B40", 0.2, emissivo="#E8C890", forza=0.15)
    M["vetro_servizio"] = piatto("ST_Vetro_Servizio", "#28302F", 0.25)
    M["interno"] = piatto("ST_Interno", "#8A6A4A", 0.92, emissivo="#F0C888", forza=1.5)
    M["interno_scuro"] = piatto("ST_Interno_Scuro", "#3A2E26", 0.95)
    M["pavimento"] = cv.righe("ST_Pavimento", "#6E4A30", "#5C3D27", 0.35, asse="X", frazione=0.08)
    M["tavolo"] = piatto("ST_Tavolo", "#4A2E1E", 0.6)
    M["neon"] = piatto("ST_Neon", "#E8321E", 0.3, emissivo="#FF3A22", forza=1.4)
    # Il murale: una fattoria alla maniera dei cartelloni, a macchie piatte.
    for nome, col in (("cielo", "#86AFCB"), ("campo", "#D1A34A"), ("prato", "#6F8C3C"),
                      ("fienile", "#9E2F27"), ("sole", "#F2D06A"), ("colline", "#8C9A55")):
        M["mur_" + nome] = piatto("ST_Murale_" + nome, col, 0.9)
    for k in range(3):
        m = ic.trasparente(piatto("ST_Fumo%d" % k, "#D9D5CF", 1.0), 0.0)
        M["fumo%d" % k] = m
    M["fumo_filo"] = ic.trasparente(piatto("ST_Fumo_Filo", "#D9D5CF", 1.0), 0.22)


def griglia(name, colore, fuga, passo_x, passo_z, frazione=0.022):
    """Intonaco a riquadri: le fughe chiare del rivestimento, verticali ogni
    `passo_x` e orizzontali ogni `passo_z`. Come `cv.righe()` le prende dalla
    posizione nel mondo, cosi' dopo l'unione corrono dritte da un pezzo
    all'altro — ma su due assi invece che su uno."""
    mat = cv._fresh(name)
    N, L = mat.node_tree.nodes, mat.node_tree.links
    b = cv._bsdf(mat)
    geo = N.new("ShaderNodeNewGeometry")
    sep = N.new("ShaderNodeSeparateXYZ")
    L.new(geo.outputs["Position"], sep.inputs[0])
    soglie = []
    for asse, passo in (("X", passo_x), ("Z", passo_z)):
        div = N.new("ShaderNodeMath")
        div.operation = "DIVIDE"
        div.inputs[1].default_value = passo
        L.new(sep.outputs[asse], div.inputs[0])
        fr = N.new("ShaderNodeMath")
        fr.operation = "FRACT"
        L.new(div.outputs[0], fr.inputs[0])
        s = N.new("ShaderNodeMath")
        s.operation = "LESS_THAN"
        s.inputs[1].default_value = frazione
        L.new(fr.outputs[0], s.inputs[0])
        soglie.append(s)
    o = N.new("ShaderNodeMath")
    o.operation = "MAXIMUM"
    L.new(soglie[0].outputs[0], o.inputs[0])
    L.new(soglie[1].outputs[0], o.inputs[1])
    mix = N.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    colori = [s for s in mix.inputs if s.type == "RGBA"]
    colori[0].default_value = cv.srgb(colore)
    colori[1].default_value = cv.srgb(fuga)
    L.new(o.outputs[0], mix.inputs[0])
    L.new([s for s in mix.outputs if s.type == "RGBA"][0], b.inputs["Base Color"])
    cv._set(b, "Roughness", 0.9)
    return mat


# ----------------------------------------------------------------------
#  primitive
# ----------------------------------------------------------------------

def _oggetto(nome, bm, mat, raccolta):
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    if mat is not None:
        me.materials.append(M[mat])
    ob = bpy.data.objects.new(nome, me)
    bpy.context.scene.collection.objects.link(ob)
    if raccolta is not None:
        raccolta.append(ob)
    return ob


def cilindro_y(nome, xc, zc, r, y0, y1, mat=None, raccolta=None, lati=40):
    """Un cilindro con l'asse lungo Y: la parte tonda di un arco visto di fronte."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=lati, radius1=r, radius2=r,
                          depth=abs(y1 - y0))
    m = Matrix.Translation((xc, (y0 + y1) / 2, zc)) @ Matrix.Rotation(math.radians(90), 4, "X")
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    return _oggetto(nome, bm, mat, raccolta)


def prisma(nome, punti, y0, y1, mat, raccolta=None):
    """Un poligono nel piano XZ estruso fra y0 e y1: lo scudo della torre."""
    bm = bmesh.new()
    davanti = [bm.verts.new((x, y0, z)) for x, z in punti]
    dietro = [bm.verts.new((x, y1, z)) for x, z in punti]
    bm.faces.new(davanti)
    bm.faces.new(list(reversed(dietro)))
    n = len(punti)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((davanti[i], dietro[i], dietro[j], davanti[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _oggetto(nome, bm, mat, raccolta if raccolta is not None else PEZZI)


def tenda(nome, x0, x1, z_muro, z_bordo, sporgenza, balza=0.22):
    """Una tenda a falda: dal muro scende verso la camera fino al bordo, e li'
    la balza dritta. Un cuneo pieno, per avere un profilo solo."""
    s = -sporgenza
    v = [(x0, 0.0, z_muro), (x1, 0.0, z_muro), (x1, s, z_bordo), (x0, s, z_bordo),
         (x0, s, z_bordo - balza), (x1, s, z_bordo - balza),
         (x1, 0.0, z_bordo - balza), (x0, 0.0, z_bordo - balza)]
    bm = bmesh.new()
    vv = [bm.verts.new(p) for p in v]
    for f in ((0, 1, 2, 3), (3, 2, 5, 4), (4, 5, 6, 7), (7, 6, 1, 0), (0, 3, 4, 7), (1, 6, 5, 2)):
        bm.faces.new([vv[i] for i in f])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _oggetto(nome, bm, "tenda", PEZZI)


def sfera(nome, centro, r, mat, raccolta):
    """Una sfera liscia: gli sbuffi di fumo e le lampade appese."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=14, v_segments=9, radius=1.0)
    for f in bm.faces:
        f.smooth = True
    ob = _oggetto(nome, bm, mat, raccolta)
    ob.location = centro
    ob.scale = (r, r, r)
    return ob


def _applica(ob, cutter, operazione):
    """Una booleana applicata subito, e il cutter buttato."""
    bpy.context.view_layer.objects.active = ob
    mod = ob.modifiers.new("B", "BOOLEAN")
    mod.operation, mod.solver, mod.object = operazione, "EXACT", cutter
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cutter, do_unlink=True)


def arco(nome, x0, x1, z0, zc, y0, y1, mat):
    """Un rettangolo con sopra il mezzo cerchio: la sagoma di un arco a tutto
    sesto largo `x1 - x0`, con l'imposta a `zc`."""
    ob = bx(nome, x0, x1, y0, y1, z0, zc, mat, raccolta=[])
    _applica(ob, cilindro_y(nome + "_tondo", (x0 + x1) / 2, zc, (x1 - x0) / 2, y0, y1), "UNION")
    return ob


def fora_arco(ob, x0, x1, z0, zc, y0, y1):
    """Scava in `ob` un vano ad arco, passante fra y0 e y1."""
    _applica(ob, bx(ob.name + "_cut", x0, x1, y0, y1, z0, zc + 0.01, "nero", raccolta=[]), "DIFFERENCE")
    _applica(ob, cilindro_y(ob.name + "_cut_t", (x0 + x1) / 2, zc, (x1 - x0) / 2, y0, y1),
             "DIFFERENCE")


# ----------------------------------------------------------------------
#  il ristorante
# ----------------------------------------------------------------------

def ali():
    """Le due ali basse di intonaco rosso, coi pilastri di mattoni agli angoli,
    lo zoccolo, il cornicione nero e il tetto piano."""
    PEZZI.append(ic.muro_forato("fac_sx", 0.0, TX0, 0.0, H, 0.0, SP, M["intonaco"],
                                [(PORTA_SX[0], PORTA_SX[1], -0.1, 2.5)]
                                + [(a, b, VETRATE_Z[0], VETRATE_Z[1]) for a, b in VETRATE_SX]))
    PEZZI.append(ic.muro_forato("fac_dx", TX1, W, 0.0, H, 0.0, SP, M["intonaco"],
                                [(a, b, VETRATE_Z[0], VETRATE_Z[1]) for a, b in VETRATE]))
    bx("lato_sx", 0.0, 0.3, SP, PROF, 0.0, H, "intonaco_lato")
    bx("lato_dx", W - 0.3, W, SP, PROF, 0.0, H, "intonaco_lato")
    bx("fondo", 0.0, W, PROF - 0.3, PROF, 0.0, H, "intonaco_lato")
    bx("tetto", 0.3, W - 0.3, SP, PROF - 0.3, H - 0.15, H - 0.05, "catrame")
    # Il cornicione nero, col fregio sottile sotto, e i parapetti.
    for nome, a, b in (("sx", 0.0, TX0), ("dx", TX1, W)):
        bx("fregio_" + nome, a, b, -0.1, 0.0, H - 0.3, H - 0.18, "nero")
        bx("cornice_" + nome, a, b, -0.22, SP + 0.05, H, H + 0.32, "nero")
    for nome, a, b, c, d in (("par_s", 0.0, 0.3, SP, PROF), ("par_d", W - 0.3, W, SP, PROF),
                             ("par_f", 0.0, W, PROF - 0.3, PROF)):
        bx(nome, a, b, c, d, H, H + 0.3, "intonaco_lato")
    # I pilastri di mattoni agli angoli, un po' piu' alti del cornicione.
    for nome, a, b in (("pil_sx", 0.0, PIL), ("pil_dx", W - PIL, W)):
        bx(nome, a, b, -0.16, 1.0, 0.0, H + 0.5, "mattone")
        bx(nome + "_cap", a, b, -0.26, 1.1, H + 0.5, H + 0.7, "nero")
    # Lo zoccolo di mattoni: sotto le vetrate a destra, e a sinistra
    # interrotto dalla porta di servizio.
    for nome, a, b in (("zoc_sx", PIL, PORTA_SX[0]), ("zoc_sx2", PORTA_SX[1], TX0),
                       ("zoc_dx", TX1, W - PIL)):
        bx(nome, a, b, -0.07, 0.0, 0.0, ZOC, "mattone")


def torre():
    """La torre dell'ingresso: mattoni, cornicione a dentelli, lo scudo, la
    finestra ad arco nella cornice crema e la pensilina sopra al vano."""
    fronte = bx("torre_fronte", TX0, TX1, TY, TY + 0.35, 0.0, H_TORRE, "mattone", raccolta=[])
    _applica(fronte, bx("torre_vano", VANO[0], VANO[1], TY - 0.1, TY + 0.45, -0.1, VANO_Z, "nero",
                        raccolta=[]), "DIFFERENCE")
    fora_arco(fronte, ARCO[0], ARCO[1], ARCO_Z, ARCO_C, TY - 0.1, TY + 0.45)
    PEZZI.append(fronte)
    tf = TORRE_FONDO
    bx("torre_lato_sx", TX0, TX0 + 0.3, TY + 0.35, tf, 0.0, H_TORRE, "mattone_lato")
    bx("torre_lato_dx", TX1 - 0.3, TX1, TY + 0.35, tf, 0.0, H_TORRE, "mattone_lato")
    bx("torre_fondo", TX0, TX1, tf - 0.3, tf, 0.0, H_TORRE, "mattone_lato")
    # Il cornicione: fregio, dentelli e cappello nero che sporge.
    bx("torre_fregio", TX0, TX1, TY - 0.1, tf + 0.05, H_TORRE - 0.4, H_TORRE - 0.25, "nero")
    n = 14
    for i in range(n):
        x = TX0 + 0.2 + (TX1 - TX0 - 0.4) * i / (n - 1)
        bx("dentello%d" % i, x - 0.07, x + 0.07, TY - 0.2, TY, H_TORRE - 0.25, H_TORRE - 0.1, "nero")
    # Il cappello e' un bordo e non una lastra: dall'alto una lastra nera piena
    # si leggeva come una scatola appoggiata sopra alla torre. Dentro al bordo
    # c'e' il tetto di catrame, come sulle ali.
    z0, z1, b = H_TORRE - 0.1, H_TORRE + 0.28, 0.42
    a0, a1, c0, c1 = TX0 - 0.2, TX1 + 0.2, TY - 0.32, tf + 0.25
    for nome, x0, x1, y0, y1 in (("cap_f", a0, a1, c0, c0 + b), ("cap_r", a0, a1, c1 - b, c1),
                                 ("cap_s", a0, a0 + b, c0, c1), ("cap_d", a1 - b, a1, c0, c1)):
        bx(nome, x0, x1, y0, y1, z0, z1, "nero")
    bx("torre_tetto", a0 + b, a1 - b, c0 + b, c1 - b, z0, z1 - 0.2, "catrame")
    # La cornice crema intorno all'arco: un arco pieno piu' largo, scavato
    # della sagoma della finestra.
    cornice = arco("arco_cornice", ARCO[0] - 0.42, ARCO[1] + 0.42, PENS_Z + 0.25, ARCO_C,
                   TY - 0.1, TY, "crema")
    fora_arco(cornice, ARCO[0], ARCO[1], ARCO_Z, ARCO_C, TY - 0.2, TY + 0.1)
    PEZZI.append(cornice)
    # Il vetro dell'arco, coi montanti.
    y = TY + 0.2
    bx("arco_vetro", ARCO[0], ARCO[1], y - 0.01, y + 0.01, ARCO_Z, ARCO_C, "vetro_arco")
    cilindro_y("arco_vetro_t", XC, ARCO_C, ARCO_R, y - 0.01, y + 0.01, "vetro_arco", PEZZI)
    t = 0.025
    for k, x in enumerate((ARCO[0] + ARCO_R * 0.66, XC, ARCO[1] - ARCO_R * 0.66)):
        cima = ARCO_C + math.sqrt(max(ARCO_R ** 2 - (x - XC) ** 2, 0.0))
        bx("arco_mont%d" % k, x - t, x + t, y - 0.06, y - 0.01, ARCO_Z, cima, "infisso")
    for k, z in enumerate((ARCO_Z + (ARCO_C - ARCO_Z) / 2, ARCO_C)):
        bx("arco_trav%d" % k, ARCO[0], ARCO[1], y - 0.06, y - 0.01, z - t, z + t, "infisso")
    # Lo scudo: un triangolo rovesciato rosso bordato di crema, con le iniziali.
    zc = 7.95
    prisma("scudo_bordo", [(XC - 0.95, zc + 0.72), (XC + 0.95, zc + 0.72), (XC, zc - 0.82)],
           TY - 0.1, TY, "scudo_bordo")
    prisma("scudo", [(XC - 0.8, zc + 0.62), (XC + 0.8, zc + 0.62), (XC, zc - 0.64)],
           TY - 0.14, TY - 0.1, "scudo")
    testo("scudo_scritta", "CS", XC, TY - 0.16, zc + 0.18, 0.5, "lettere")
    # La pensilina nera sopra all'ingresso, coi due tiranti al muro.
    bx("pens", VANO[0] - 0.25, VANO[1] + 0.25, TY - PENS_S, TY, PENS_Z, PENS_Z + 0.2, "nero")
    bx("pens_fascia", VANO[0] - 0.25, VANO[1] + 0.25, TY - PENS_S - 0.05, TY - PENS_S + 0.05,
       PENS_Z - 0.08, PENS_Z + 0.24, "nero")
    for x in (VANO[0] - 0.05, VANO[1] + 0.05):
        bi.tubo("tirante%d" % int(x * 10), (x, TY - PENS_S + 0.1, PENS_Z + 0.2),
                (x, TY, PENS_Z + 1.1), 0.02, "nero")


def ingresso():
    """Il vano d'ingresso con le vetrate fisse ai lati e il sopraluce, e
    dentro l'atrio acceso. Le ante stanno in `ante()`: sono l'animazione."""
    y = TY + 0.18
    for nome, a, b in (("lucesx", VANO[0], ANTE[0][0]), ("lucedx", ANTE[1][1], VANO[1])):
        bx(nome, a, b, y - 0.01, y + 0.01, 0.0, VANO_Z, "vetro_porta")
    bx("sopraluce", ANTE[0][0], ANTE[1][1], y - 0.01, y + 0.01, ANTE_Z, VANO_Z, "vetro_porta")
    t = 0.05
    for k, x in enumerate((VANO[0] + t, ANTE[0][0], ANTE[1][1], VANO[1] - t)):
        bx("vano_mont%d" % k, x - t, x + t, y - 0.07, y - 0.01, 0.0, VANO_Z, "infisso")
    bx("vano_trav", VANO[0], VANO[1], y - 0.07, y - 0.01, ANTE_Z - t, ANTE_Z + t, "infisso")
    bx("vano_archit", VANO[0], VANO[1], y - 0.07, y - 0.01, VANO_Z - 2 * t, VANO_Z, "infisso")
    # L'atrio: pavimento, soffitto e la parete di fondo accesa.
    fondo = TORRE_FONDO - 0.3
    bx("atrio_pav", TX0 + 0.3, TX1 - 0.3, TY + 0.35, fondo, 0.0, 0.05, "pavimento")
    bx("atrio_fondo", TX0 + 0.3, TX1 - 0.3, fondo - 0.15, fondo, 0.0, 3.3, "interno")
    bx("atrio_soff", TX0 + 0.3, TX1 - 0.3, TY + 0.35, fondo, 3.2, 3.3, "interno_scuro")


def ante(animati):
    """Le due ante a vetri, ciascuna appesa al suo cardine esterno: girando il
    perno si aprono verso il parcheggio."""
    y = TY + 0.12
    perni = []
    tutte = []
    for lato, (a, b) in zip(("sx", "dx"), ANTE):
        cardine = Vector((a if lato == "sx" else b, y, 0.0))
        pezzi = []
        t = 0.06
        bx("anta_%s_v" % lato, a + t, b - t, y - 0.01, y + 0.01, t, ANTE_Z - t, "vetro_porta",
           raccolta=pezzi)
        for nome, x0, x1, z0, z1 in (("s", a, a + t, 0.0, ANTE_Z), ("d", b - t, b, 0.0, ANTE_Z),
                                     ("g", a, b, 0.0, 0.22), ("a", a, b, ANTE_Z - t, ANTE_Z)):
            bx("anta_%s_%s" % (lato, nome), x0, x1, y - 0.03, y + 0.03, z0, z1, "infisso",
               raccolta=pezzi)
        # Il maniglione verticale, dalla parte che non ha il cardine.
        xm = b - 0.16 if lato == "sx" else a + 0.16
        bx("anta_%s_man" % lato, xm - 0.025, xm + 0.025, y - 0.1, y - 0.06, 0.8, 1.6, "metallo",
           raccolta=pezzi)
        perno = bpy.data.objects.new("anta_%s_perno" % lato, None)
        bpy.context.scene.collection.objects.link(perno)
        perno.location = cardine
        for ob in pezzi:
            ob.data.transform(Matrix.Translation(-cardine))
            ob.parent = perno
        perni.append(perno)
        tutte.extend(pezzi)
    animati["porta"] = (tutte, perni)


def ala_sinistra():
    """La scritta, i lampioncini a collo di cigno, il murale, una vetrata sul
    locale e la porta di servizio con la sua tendina."""
    testo("scritta_sx", "STEAKHOUSE", (PIL + TX0) / 2, -0.05, Z_SCRITTE, 0.72, "lettere")
    lampioncini(PIL, TX0)
    vetrate("sx", VETRATE_SX)
    sala("sx", VETRATE_SX[0][0] - 0.4, VETRATE_SX[-1][1] + 0.4)
    # Il murale, nella sua cornice nera.
    x0, x1, z0, z1 = MURALE
    bx("murale_cornice", x0 - 0.08, x1 + 0.08, -0.07, 0.0, z0 - 0.08, z1 + 0.08, "nero")
    y = -0.08
    bx("mur_cielo", x0, x1, y - 0.01, y, z0 + 0.95, z1, "mur_cielo")
    bx("mur_colline", x0, x1, y - 0.02, y - 0.01, z0 + 0.95, z0 + 1.25, "mur_colline")
    bx("mur_campo", x0, x1, y - 0.01, y, z0 + 0.45, z0 + 0.95, "mur_campo")
    bx("mur_prato", x0, x1, y - 0.01, y, z0, z0 + 0.45, "mur_prato")
    bx("mur_fienile", x0 + 0.6, x0 + 1.5, y - 0.03, y - 0.02, z0 + 0.7, z0 + 1.45, "mur_fienile")
    prisma("mur_tetto", [(x0 + 0.5, z0 + 1.45), (x0 + 1.6, z0 + 1.45), (x0 + 1.05, z0 + 1.8)],
           y - 0.03, y - 0.02, "mur_fienile")
    cilindro_y("mur_sole", x1 - 0.8, z1 - 0.5, 0.28, y - 0.03, y - 0.02, "mur_sole", PEZZI, lati=20)
    # La porta di servizio: vetro scuro nel suo telaio, e la tendina sopra.
    a, b = PORTA_SX
    yv = Y_VETRO
    bx("servizio_v", a, b, yv - 0.01, yv + 0.01, 0.0, 2.5, "vetro_servizio")
    t = 0.05
    for nome, x0_, x1_, za, zb in (("s", a, a + t, 0.0, 2.5), ("d", b - t, b, 0.0, 2.5),
                                   ("a", a, b, 2.5 - t, 2.5), ("m", a, b, 1.0, 1.0 + t)):
        bx("servizio_" + nome, x0_, x1_, yv - 0.07, yv - 0.01, za, zb, "infisso")
    tenda("tenda_servizio", a - 0.2, b + 0.2, 3.15, 2.95, 0.5)


def ala_destra():
    """Le tre vetrate sotto le tende nere, col locale acceso dietro, la
    scritta e i lampioncini."""
    testo("scritta_dx", "GRILL AND BAR", (TX1 + W - PIL) / 2, -0.05, Z_SCRITTE, 0.66, "lettere")
    lampioncini(TX1, W - PIL)
    vetrate("dx", VETRATE)
    sala("dx", TX1 + 0.3, W - 0.3)


def vetrate(tag, finestre):
    """Vetrate coi telai neri, ciascuna sotto la sua tenda."""
    y = Y_VETRO
    for k, (a, b) in enumerate(finestre):
        nome = "vetrata_%s%d" % (tag, k)
        bx(nome, a, b, y - 0.01, y + 0.01, VETRATE_Z[0], VETRATE_Z[1], "vetrina")
        n = 3
        for i in range(n + 1):
            x = a + (b - a) * i / n
            bx("%s_m%d" % (nome, i), x - 0.05, x + 0.05, y - 0.07, y + 0.01,
               VETRATE_Z[0], VETRATE_Z[1], "infisso")
        for z in VETRATE_Z:
            bx("%s_t%d" % (nome, int(z * 10)), a, b, y - 0.07, y + 0.01, z - 0.05, z + 0.05,
               "infisso")
        tenda("tenda_%s%d" % (tag, k), a - 0.12, b + 0.12, 3.65, 3.35, 0.6)


def sala(tag, x0, x1):
    """Il locale dietro alle vetrate: pavimento, parete di fondo accesa, e una
    fila di tavoli con le lampade appese."""
    bx("sala_pav_" + tag, x0, x1, SP, 4.5, 0.0, 0.05, "pavimento")
    bx("sala_fondo_" + tag, x0, x1, 4.35, 4.5, 0.0, H - 0.15, "interno")
    bx("sala_soff_" + tag, x0, x1, SP, 4.5, 3.3, 3.4, "interno_scuro")
    n = max(1, int((x1 - x0) / 1.6))
    for k in range(n):
        x = x0 + (x1 - x0) * (k + 0.5) / n
        t = "%s%d" % (tag, k)
        bx("tavolo" + t, x - 0.45, x + 0.45, 1.5, 2.3, 0.72, 0.78, "tavolo")
        bx("tavolo%s_g" % t, x - 0.05, x + 0.05, 1.85, 1.95, 0.0, 0.72, "tavolo")
        for s in (-1, 1):
            bx("sedia%s_%d" % (t, s), x + s * 0.55 - 0.18, x + s * 0.55 + 0.18, 1.7, 2.1, 0.0, 0.95,
               "interno_scuro")
        bi.tubo("lampada%s_filo" % t, (x, 1.9, 3.3), (x, 1.9, 2.55), 0.01, "infisso")
        sfera("lampada" + t, (x, 1.9, 2.5), 0.12, "lampadina", PEZZI)


def lampioncini(x0, x1, n=4):
    """I lampioncini a collo di cigno sopra alle scritte, `n` in fila fra x0 e
    x1: il braccio nero e il piatto con la lampadina sotto, che di notte resta
    accesa."""
    z = Z_LAMPIONCINI
    for i in range(n):
        x = x0 + (x1 - x0) * (i + 0.5) / n
        t = "%d" % int(x * 10)
        bi.tubo("collo" + t, (x, 0.0, z), (x, -0.45, z + 0.15), 0.03, "nero")
        bx("piatto" + t, x - 0.13, x + 0.13, -0.6, -0.38, z + 0.02, z + 0.16, "nero")
        bx("luce" + t, x - 0.08, x + 0.08, -0.56, -0.42, z, z + 0.02, "lampadina")


def tetto():
    """Le macchine sul tetto e il camino della griglia, sulla fascia davanti."""
    bx("clima1", 2.4, 4.0, 5.2, 6.6, H - 0.05, H + 0.8, "macchina")
    bx("clima2", 8.6, 9.8, 6.4, 7.6, H - 0.05, H + 0.65, "macchina")
    bx("clima3", TX1 + 3.0, TX1 + 4.2, 5.6, 6.8, H - 0.05, H + 0.65, "macchina")
    cx, cy = CAMINO
    bx("cappa", cx - 0.5, cx + 0.5, cy - 0.5, cy + 0.5, H - 0.05, H + 0.45, "metallo")
    bi.tubo("camino", (cx, cy, H + 0.45), (cx, cy, CAMINO_Z), 0.16, "metallo")
    bx("camino_cappello", cx - 0.28, cx + 0.28, cy - 0.28, cy + 0.28, CAMINO_Z, CAMINO_Z + 0.08,
       "metallo")


def neon(animati):
    """OPEN in rosso, appeso dietro alla prima vetrata, davanti al vetro."""
    pezzi = []
    x0, z0, z1 = VETRATE[0][0] + 0.3, 1.95, 2.42
    x1 = x0 + 1.2
    y = Y_VETRO - 0.03
    for nome, a, b, za, zb in (("neon_g", x0, x1, z0, z0 + 0.04), ("neon_a", x0, x1, z1 - 0.04, z1),
                               ("neon_s", x0, x0 + 0.04, z0, z1), ("neon_d", x1 - 0.04, x1, z0, z1)):
        bx(nome, a, b, y - 0.03, y, za, zb, "neon", raccolta=pezzi)
    pezzi.append(testo("neon_scritta", "OPEN", (x0 + x1) / 2, y - 0.04, (z0 + z1) / 2, 0.3, "neon"))
    animati["neon"] = (pezzi, None)


def fumo(animati):
    """Gli sbuffi della griglia: tre sfere trasparenti, una per sbuffo, piu' il
    filo di fumo fermo che esce sempre dal camino."""
    cx, cy = CAMINO
    pezzi = [sfera("fumo%d" % k, (cx, cy, CAMINO_Z + 0.2), 0.2, "fumo%d" % k, None)
             for k in range(3)]
    pezzi.append(sfera("fumo_filo", (cx + 0.05, cy, CAMINO_Z + 0.25), 0.13, "fumo_filo", None))
    animati["fumo"] = (pezzi, None)


# ----------------------------------------------------------------------
#  scena e scatti
# ----------------------------------------------------------------------

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
    animati = {}
    ali()
    torre()
    ingresso()
    ala_sinistra()
    ala_destra()
    tetto()
    ante(animati)
    neon(animati)
    fumo(animati)
    cv.unisci(list(PEZZI), "ST_Ristorante")
    cam = cv.scena()
    for pezzi, _ in animati.values():
        for ob in pezzi:
            ob.hide_render = True
    cv.inquadra(cam, 0.0, W)
    return animati


# La porta: si apre in fretta e si richiude piano, col chiudiporta. Gradi
# d'apertura, fotogramma per fotogramma; il primo e l'ultimo sono la posa di
# riposo.
APERTURA = [0, 22, 48, 68, 76, 78, 78, 78, 74, 64, 52, 40, 29, 19, 11, 5, 1, 0]
# Il fumo: il fotogramma in cui parte ogni sbuffo e quanti ne vive.
FOTOGRAMMI_FUMO = 18
PARTENZE = (1, 4, 7)
VITA = 10
SALITA = 1.4
DERIVA = 0.9
# Il neon: acceso, e poi lo sfarfallio. Il primo e' la posa di riposo.
SFARFALLIO = [1, 0, 1, 0, 0, 1, 0, 1, 1, 1]


def posa_fumo(i):
    cx, cy = CAMINO
    for k, parte in enumerate(PARTENZE):
        ob = bpy.data.objects["fumo%d" % k]
        t = (i - parte) / float(VITA)
        if t < 0.0 or t > 1.0:
            alpha = 0.0
            t = 0.0
        else:
            # Entra in fretta e se ne va piano: un fumo che sparisce di colpo
            # si legge come un fotogramma mancante.
            alpha = 0.62 * min(1.0, t * 4.0) * (1.0 - t) ** 1.3
        ob.location = (cx + DERIVA * t * t + 0.05 * k, cy, CAMINO_Z + 0.25 + SALITA * t)
        r = 0.2 + 0.28 * t
        ob.scale = (r * 1.15, r, r)
        cv._set(cv._bsdf(M["fumo%d" % k]), "Alpha", alpha)
        # Spento e non solo trasparente: uno sbuffo fermo sul camino ad alpha
        # zero scrive lo stesso la profondita' (`show_transparent_back` spento
        # vuol dire prepassata), e nasconde il filo di fumo che ha dentro.
        ob.hide_render = alpha <= 0.0


def renderizza(cose=("base", "porta", "fumo", "neon"), da=0):
    """`cose` dice cosa fotografare, `da` da che fotogramma ripartire.

    Servono perche' Blender 5.2 in background si chiude da solo dopo una
    ventina di render nella stessa sessione, senza errore: fatti tutti in fila
    non si arriva in fondo. Uno per processo si', e se uno cade si riparte
    dal fotogramma che manca."""
    os.makedirs(OUT, exist_ok=True)
    sc = bpy.context.scene
    if "base" in cose:
        costruisci()
        sc.render.filepath = os.path.join(OUT, "render_steakhouse.png")
        bpy.ops.render.render(write_still=True)
        cv.modo_luci()
        sc.render.filepath = os.path.join(OUT, "luci_steakhouse.png")
        bpy.ops.render.render(write_still=True)

    for cosa in [c for c in ("porta", "fumo", "neon") if c in cose]:
        animati = costruisci()
        tengo, perni = animati[cosa]
        tutti = [ob for pezzi, _ in animati.values() for ob in pezzi]
        for ob in bpy.data.objects:
            if ob.type in ("MESH", "FONT"):
                ob.is_holdout = ob not in tengo
                ob.hide_render = ob in tutti and ob not in tengo
        for ob in tengo:
            ob.hide_render = False
        sc.render.use_freestyle = False
        if cosa == "porta":
            pose = APERTURA
        elif cosa == "fumo":
            pose = list(range(FOTOGRAMMI_FUMO))
        else:
            pose = SFARFALLIO
        for i, posa in enumerate(pose):
            if i < da:
                continue
            if cosa == "porta":
                # Verso la camera: l'anta di sinistra gira in senso orario vista
                # dall'alto, quella di destra al contrario.
                perni[0].rotation_euler = (0, 0, math.radians(-posa))
                perni[1].rotation_euler = (0, 0, math.radians(posa))
            elif cosa == "fumo":
                posa_fumo(posa)
            else:
                cv._set(cv._bsdf(M["neon"]), "Emission Strength", 1.4 if posa else 0.05)
                cv._set(cv._bsdf(M["neon"]), "Base Color",
                        cv.srgb("#E8321E") if posa else cv.srgb("#5A2622"))
            sc.render.filepath = os.path.join(OUT, "anim_steakhouse_%s_%02d.png" % (cosa, i))
            bpy.ops.render.render(write_still=True)
    print("STEAKHOUSE", sc.render.resolution_x, sc.render.resolution_y)


if __name__ == "__main__":
    argomenti = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if argomenti:
        renderizza((argomenti[0],), int(argomenti[1]) if len(argomenti) > 1 else 0)
    else:
        renderizza()
