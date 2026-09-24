"""Costruisce in Blender il negozio di biciclette di THE FLATS: FREEWHEEL.

Sta su CROSS STREET, attaccato a destra del garage, e riempie il lotto fino al
marciapiede di MILL ROAD: 322 px di fronte, cioe' 14,44 m a 22,3 px/m.

Preso da una foto di un negozio di bici di provincia, senza copiarne il nome:
un piano solo di mattoni rossi, il portico coi pilastri bianchi e la ringhiera
a sinistra, l'insegna ovale color crema appesa alla trave, le vetrine grandi
coi telai neri e dentro il negozio acceso con le bici in fila, la porta a vetri
aperta. Sopra al portico il frontone rialzato col nome, alla maniera dei
negozi delle cittadine americane.

**Il portico e' alto apposta.** Con la camera a 27 gradi un tetto basso davanti
alle vetrine le copre per meta': il raggio che parte dalla cima di una vetrina
sale di mezzo metro per ogni metro che fa verso la camera, e deve passare sotto
alla gronda del portico. Per questo i pilastri sono alti 4,1 m e le vetrine si
fermano a 2,8.

Le bici sono modellate e non disegnate: telaio a diamante coi suoi sette tubi,
forcella, ruote con copertone, cerchio e raggi, sella di cuoio, manubrio,
corona e pedivelle. A 22 pixel per metro una bici e' lunga quaranta pixel, e
quello che si legge e' la sagoma: due cerchi e un triangolo colorato in mezzo.

Niente marciapiede (e' del gioco): il portico e' il lotto del negozio, come il
cortile della casa.

## Le animazioni

Tutte e tre sporadiche o legate al vento, per far sembrare il posto vivo senza
che niente si muova di continuo:

  * `ruota` — la bici sul cavalletto da officina: ogni tanto qualcuno fa
    girare la ruota dietro per provare il cambio, e la ruota gira e rallenta
    fino a fermarsi (due giri esatti, cosi' l'ultimo fotogramma coincide col
    primo);
  * `insegna` — l'insegna ovale appesa al portico, che dondola col vento;
  * `neon` — la scritta OPEN in vetrina, che ogni tanto sfarfalla. E' luce, e
    in gioco resta accesa di notte.

Si fotografano come quelle del casino': tolte dal disegno, rifotografate da
sole col resto in holdout.

Uso:
  blender --background --factory-startup --python scripts_tools/blender_bici.py
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
# vetrine trasparenti e muro forato quelli dell'isolato cinese, che sta nello
# stesso quartiere.
import blender_cinema_videogiochi as cv  # noqa: E402
import blender_isolato_cinese as ic  # noqa: E402
from blender_cinema_videogiochi import M, PEZZI, bx, piatto, testo  # noqa: E402

OUT = cv.OUT
W = 322.0 / cv.PX_PER_METRO     # 14,44 m: dal muro del garage al marciapiede
PORTICO = 2.4                   # profondita' del portico, fino alle vetrine
SP = 0.3                        # spessore del muro di facciata
FONDO = 8.0                     # il muro di dietro
H = 4.9                         # gronda
H_FRONTE = 5.5                  # il frontone ai lati
H_CENTRO = 6.2                  # e al centro, dove sta il nome
Z_PORTICO = 4.1                 # la trave del portico
Z_PORTICO_MURO = 4.45           # dove il tetto del portico tocca il muro
VETRINA_Z = (0.55, 2.8)
PILASTRI = (0.15, 4.85, 9.6, W - 0.15)
PORTA = (5.05, 6.55)


def palette():
    cv.palette()
    M["mattone"] = ic.mattone("BI_Mattone", "#A4513F", "#8A4234", "#CDBBA4", "#6E5046",
                              seme=6.0, macchie=0.34)
    M["mattone_lato"] = ic.mattone("BI_Mattone_Lato", "#8C4536", "#72382C", "#B7A48E", "#634638",
                                   seme=7.0, macchie=0.40)
    M["bianco"] = piatto("BI_Bianco", "#E3DDCF", 0.75)
    M["bianco_sporco"] = piatto("BI_Bianco_Sporco", "#CFC8B8", 0.8)
    M["cemento"] = piatto("BI_Cemento", "#8E877C", 0.95)
    M["tegole"] = cv.righe("BI_Tegole", "#48524C", "#394039", 0.32, asse="Y", frazione=0.18)
    M["catrame"] = piatto("BI_Catrame", "#4A453F", 0.97)
    M["insegna_verde"] = piatto("BI_Insegna_Verde", "#26402F", 0.6)
    M["scritta_crema"] = piatto("BI_Scritta_Crema", "#F0E2BE", 0.5, emissivo="#F4E6C0", forza=0.9)
    M["legno_pav"] = cv.righe("BI_Parquet", "#8A6440", "#74532F", 0.35, asse="X", frazione=0.08)
    M["vetrina"] = ic.trasparente(piatto("BI_Vetrina", "#3E4640", 0.10, 0.2,
                                         emissivo="#C9A86A", forza=0.22), 0.28)
    M["vetro_porta"] = ic.trasparente(piatto("BI_Vetro_Porta", "#5A6A66", 0.10, 0.2), 0.35)
    M["interno"] = piatto("BI_Interno", "#9A8260", 0.92, emissivo="#E8C890", forza=1.6)
    M["interno_scuro"] = piatto("BI_Interno_Scuro", "#3A302A", 0.95)
    M["ferro"] = piatto("BI_Ferro", "#23211F", 0.6, 0.5)
    M["metallo"] = piatto("BI_Metallo", "#A8ADB0", 0.35, 0.85)
    M["gomma"] = piatto("BI_Gomma", "#1A1A1A", 0.9)
    M["cuoio"] = piatto("BI_Cuoio", "#7A5230", 0.6)
    M["crema_ovale"] = piatto("BI_Ovale", "#EFE3C4", 0.7)
    M["bordo_ovale"] = piatto("BI_Ovale_Bordo", "#7A4A2A", 0.6)
    M["scritta_marrone"] = piatto("BI_Scritta_Marrone", "#6A3A20", 0.6)
    # A 3 il rosso si bruciava in un rosa pallido: il neon vero e' rosso pieno.
    M["neon"] = piatto("BI_Neon", "#E8321E", 0.3, emissivo="#FF3A22", forza=1.4)
    M["macchina"] = piatto("BI_Macchina", "#9EA3A5", 0.5, 0.5)
    for nome, col in (("rossa", "#B8322A"), ("menta", "#7FC8A9"), ("petrolio", "#2E8C92"),
                      ("arancio", "#D9822B"), ("crema", "#E6D9B8"), ("verde", "#5E9A3A"),
                      ("blu", "#2F5E9E")):
        M["telaio_" + nome] = piatto("BI_Telaio_" + nome, col, 0.4, 0.3)


# ----------------------------------------------------------------------
#  primitive che al cinema non servivano
# ----------------------------------------------------------------------

def _mesh(nome, bm, mat, raccolta):
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(M[mat])
    ob = bpy.data.objects.new(nome, me)
    bpy.context.scene.collection.objects.link(ob)
    (raccolta if raccolta is not None else PEZZI).append(ob)
    return ob


def tubo(nome, a, b, r, mat, raccolta=None, lati=8):
    """Un cilindro da `a` a `b`, gia' messo al suo posto nella mesh: l'oggetto
    resta nell'origine, come le scatole di `bx`, e l'unione non sposta niente."""
    a, b = Vector(a), Vector(b)
    asse = b - a
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=lati, radius1=r, radius2=r,
                          depth=asse.length)
    giro = asse.normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=Matrix.Translation((a + b) / 2) @ giro, verts=bm.verts)
    return _mesh(nome, bm, mat, raccolta)


def anello(nome, centro, R, r, mat, raccolta=None, seg=28, lati=6):
    """Un toro nel piano XZ (una ruota vista di fianco), centrato in `centro`."""
    bm = bmesh.new()
    giri = []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        c = Vector((math.cos(a), 0, math.sin(a)))
        giro = []
        for j in range(lati):
            t = 2 * math.pi * j / lati
            p = c * (R + r * math.cos(t)) + Vector((0, r * math.sin(t), 0))
            giro.append(bm.verts.new(Vector(centro) + p))
        giri.append(giro)
    for i in range(seg):
        for j in range(lati):
            a, b = giri[i], giri[(i + 1) % seg]
            bm.faces.new((a[j], a[(j + 1) % lati], b[(j + 1) % lati], b[j]))
    return _mesh(nome, bm, mat, raccolta)


def disco(nome, centro, rx, rz, spessore, mat, raccolta=None, seg=32):
    """Un ovale piatto rivolto verso la camera (asse lungo Y)."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=1.0, radius2=1.0,
                          depth=spessore)
    m = (Matrix.Translation(centro) @ Matrix.Diagonal((rx, 1.0, rz, 1.0))
         @ Matrix.Rotation(math.radians(90), 4, "X"))
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    return _mesh(nome, bm, mat, raccolta)


def ruota(tag, centro, R, raccolta):
    """Copertone, cerchio, mozzo e raggi. I raggi sono sottili apposta: a
    questa scala servono a far sembrare la ruota una ruota e non un disco, e
    dodici bastano."""
    pezzi = [anello(tag + "_gomma", centro, R - 0.03, 0.032, "gomma", raccolta),
             anello(tag + "_cerchio", centro, R - 0.07, 0.013, "metallo", raccolta)]
    c = Vector(centro)
    pezzi.append(tubo(tag + "_mozzo", c + Vector((0, -0.06, 0)), c + Vector((0, 0.06, 0)),
                      0.03, "metallo", raccolta))
    for k in range(12):
        a = 2 * math.pi * k / 12
        pezzi.append(tubo("%s_raggio%d" % (tag, k), c,
                          c + Vector((math.cos(a), 0, math.sin(a))) * (R - 0.07),
                          0.007, "metallo", raccolta, lati=4))
    # Il catarifrangente sui raggi: e' quello che fa vedere che la ruota gira.
    pezzi.append(tubo(tag + "_catarifr", c + Vector((0.12, -0.02, 0.10)),
                      c + Vector((0.19, -0.02, 0.16)), 0.02, "telaio_arancio", raccolta, lati=4))
    return pezzi


def bici(tag, cx, y, z0, colore, raccolta, ruota_dietro=None, verso=1):
    """Una bici di fianco, parallela alla facciata. `verso` -1 la gira col
    manubrio a sinistra. Con `ruota_dietro` la ruota posteriore finisce in
    quella lista invece che nella bici: e' quella che gira."""
    R = 0.34

    def p(x, z):
        return Vector((cx + x * verso, y, z0 + z))

    A, F = p(-0.52, R), p(0.52, R)          # mozzi dietro e davanti
    B = p(-0.06, R - 0.06)                  # movimento centrale
    S = p(-0.22, R + 0.52)                  # cima del piantone
    Hs, Hg = p(0.36, R + 0.50), p(0.41, R + 0.33)   # sterzo, sopra e sotto
    t = "telaio_" + colore
    tubo(tag + "_piantone", B, S, 0.028, t, raccolta)
    tubo(tag + "_orizz", S + Vector((0, 0, -0.04)), Hs, 0.028, t, raccolta)
    tubo(tag + "_obliquo", B, Hg, 0.032, t, raccolta)
    tubo(tag + "_foderi", B, A, 0.02, t, raccolta)
    tubo(tag + "_pendenti", S + Vector((0, 0, -0.05)), A, 0.018, t, raccolta)
    tubo(tag + "_sterzo", Hg, Hs, 0.034, t, raccolta)
    tubo(tag + "_forcella", Hg, F, 0.022, t, raccolta)
    # Reggisella e sella di cuoio.
    cima = S + Vector((-0.04 * verso, 0, 0.13))
    tubo(tag + "_reggisella", S, cima, 0.016, "metallo", raccolta)
    bx(tag + "_sella", cima.x - 0.14, cima.x + 0.12, y - 0.07, y + 0.07,
       cima.z, cima.z + 0.06, "cuoio", raccolta=raccolta)
    # Attacco, manubrio (di traverso, verso la camera) e manopole.
    att = Hs + Vector((0.03 * verso, 0, 0.09))
    tubo(tag + "_attacco", Hs, att, 0.018, "metallo", raccolta)
    tubo(tag + "_manubrio", att + Vector((0, -0.28, 0)), att + Vector((0, 0.28, 0)),
         0.016, "ferro", raccolta)
    for s in (-1, 1):
        tubo("%s_manopola%d" % (tag, s), att + Vector((0, 0.22 * s, 0)),
             att + Vector((0, 0.30 * s, 0)), 0.022, "cuoio", raccolta)
    # Corona, pedivelle e pedali.
    anello(tag + "_corona", B + Vector((0, -0.05, 0)), 0.095, 0.012, "metallo", raccolta, seg=16, lati=4)
    ped = B + Vector((0.11 * verso, -0.07, -0.11))
    tubo(tag + "_pedivella", B + Vector((0, -0.07, 0)), ped, 0.015, "ferro", raccolta)
    bx(tag + "_pedale", ped.x - 0.05, ped.x + 0.05, ped.y - 0.07, ped.y, ped.z - 0.015, ped.z + 0.015,
       "ferro", raccolta=raccolta)
    # La catena: due tratti fra corona e pignone.
    for dz in (0.08, -0.08):
        tubo("%s_catena%d" % (tag, dz > 0), B + Vector((0, -0.05, dz)), A + Vector((0, -0.05, dz * 0.5)),
             0.008, "ferro", raccolta, lati=4)
    ruota(tag + "_ant", F, R, raccolta)
    ruota(tag + "_post", A, R, ruota_dietro if ruota_dietro is not None else raccolta)
    return A


# ----------------------------------------------------------------------
#  il negozio
# ----------------------------------------------------------------------

def corpo():
    fori = [(0.6, 4.3, VETRINA_Z[0], VETRINA_Z[1]),
            (PORTA[0], PORTA[1], 0.1, 2.6),
            (7.1, 13.9, VETRINA_Z[0], VETRINA_Z[1])]
    PEZZI.append(ic.muro_forato("facciata", 0.0, W, 0.0, H, PORTICO, PORTICO + SP, M["mattone"], fori))
    bx("lato_sx", 0.0, 0.3, PORTICO + SP, FONDO, 0.0, H, "mattone_lato")
    bx("lato_dx", W - 0.3, W, PORTICO + SP, FONDO, 0.0, H, "mattone_lato")
    bx("fondo", 0.0, W, FONDO - 0.3, FONDO, 0.0, H, "mattone_lato")
    bx("zoccolo", 0.0, W, PORTICO - 0.03, PORTICO + 0.02, 0.0, 0.5, "zoccolo")
    # Il frontone: basso ai lati, piu' alto in mezzo col nome.
    bx("frontone", 0.0, W, PORTICO, PORTICO + SP, H, H_FRONTE, "mattone")
    bx("frontone_c", 3.9, 10.55, PORTICO, PORTICO + SP, H_FRONTE, H_CENTRO, "mattone")
    for nome, a, b, z in (("cop_sx", 0.0, 3.9, H_FRONTE), ("cop_dx", 10.55, W, H_FRONTE),
                          ("cop_c", 3.8, 10.65, H_CENTRO)):
        bx(nome, a, b, PORTICO - 0.08, PORTICO + SP + 0.05, z, z + 0.12, "bianco")
    bx("cornice", 0.0, W, PORTICO - 0.06, PORTICO, H - 0.25, H - 0.1, "bianco")
    bx("tabella", 4.35, 10.1, PORTICO - 0.06, PORTICO, H_FRONTE - 0.35, H_CENTRO - 0.18, "insegna_verde")
    bx("tabella_bordo", 4.25, 10.2, PORTICO - 0.04, PORTICO - 0.01, H_FRONTE - 0.45, H_CENTRO - 0.08,
       "bianco_sporco")
    testo("nome", "FREEWHEEL", (4.35 + 10.1) / 2, PORTICO - 0.08, (H_FRONTE - 0.35 + H_CENTRO - 0.18) / 2,
          0.52, "scritta_crema")
    # Il tetto piano, basso dietro al frontone, con due macchine e uno sfiato.
    bx("tetto", 0.3, W - 0.3, PORTICO + SP, FONDO - 0.3, H - 0.15, H - 0.05, "catrame")
    for nome, a, b in (("par_sx", 0.0, 0.3), ("par_dx", W - 0.3, W)):
        bx(nome, a, b, PORTICO + SP, FONDO, H, H + 0.3, "mattone_lato")
    bx("par_fondo", 0.0, W, FONDO - 0.3, FONDO, H, H + 0.3, "mattone_lato")
    bx("clima", 2.0, 3.3, 5.6, 6.6, H - 0.05, H + 0.6, "macchina")
    bx("clima2", 11.2, 12.0, 6.2, 7.0, H - 0.05, H + 0.45, "macchina")
    tubo("sfiato", (7.5, 6.8, H - 0.05), (7.5, 6.8, H + 0.8), 0.09, "metallo")


def vetrine():
    y = PORTICO + 0.12
    for nome, a, b in (("vetr_sx", 0.6, 4.3), ("vetr_dx", 7.1, 13.9)):
        bx(nome + "_v", a, b, y - 0.01, y + 0.01, VETRINA_Z[0], VETRINA_Z[1], "vetrina")
        # Telai neri, come nella foto: pochi montanti, larghi.
        n = 2 if b - a < 5 else 4
        for i in range(n + 1):
            x = a + (b - a) * i / n
            bx("%s_m%d" % (nome, i), x - 0.05, x + 0.05, y - 0.06, y + 0.02,
               VETRINA_Z[0], VETRINA_Z[1], "infisso")
        for z in VETRINA_Z:
            bx("%s_t%d" % (nome, int(z * 10)), a, b, y - 0.06, y + 0.02, z - 0.05, z + 0.05, "infisso")
        bx(nome + "_davanz", a - 0.08, b + 0.08, PORTICO - 0.1, PORTICO + 0.05,
           VETRINA_Z[0] - 0.12, VETRINA_Z[0] - 0.04, "bianco")
    # La porta: il vano e, spalancata verso il portico, l'anta a vetri col
    # telaio bianco, incernierata a destra.
    bx("porta_sopraluce", PORTA[0], PORTA[1], y - 0.01, y + 0.01, 2.62, VETRINA_Z[1], "vetrina")
    bx("porta_archit", PORTA[0], PORTA[1], y - 0.06, y + 0.02, 2.56, 2.64, "infisso")
    anta = []
    x0, y0 = PORTA[0], PORTICO - 0.02
    bx("anta_v", x0 + 0.1, PORTA[1] - 0.1, y0 - 0.02, y0, 0.2, 2.45, "vetro_porta", raccolta=anta)
    for nome, a, b, za, zb in (("anta_s", x0, x0 + 0.1, 0.1, 2.55), ("anta_d", PORTA[1] - 0.1, PORTA[1], 0.1, 2.55),
                               ("anta_g", x0, PORTA[1], 0.1, 0.35), ("anta_a", x0, PORTA[1], 2.45, 2.55)):
        bx(nome, a, b, y0 - 0.05, y0, za, zb, "bianco", raccolta=anta)
    bx("anta_maniglia", x0 + 0.15, x0 + 0.2, y0 - 0.12, y0 - 0.05, 1.0, 1.35, "metallo", raccolta=anta)
    cardine = Vector((PORTA[1], y0, 0))
    giro = Matrix.Translation(cardine) @ Matrix.Rotation(math.radians(72), 4, "Z") @ Matrix.Translation(-cardine)
    for ob in anta:
        ob.data.transform(giro)
    PEZZI.extend(anta)


def interno(bici_dentro):
    """Il negozio acceso dietro alle vetrine: pavimento, parete di fondo, due
    bici esposte e le ruote appese al muro."""
    bx("pavimento", 0.3, W - 0.3, PORTICO + SP, 5.8, 0.0, 0.05, "legno_pav")
    bx("parete_fondo", 0.3, W - 0.3, 5.6, 5.8, 0.0, H - 0.15, "interno")
    bx("bancone", 10.4, 13.2, 4.6, 5.3, 0.0, 1.05, "legno")
    bx("bancone_top", 10.3, 13.3, 4.55, 5.35, 1.05, 1.12, "interno_scuro")
    for k, x in enumerate((1.2, 2.2, 3.2, 8.0, 9.0)):
        anello("ruota_muro%d" % k, (x, 5.55, 2.6), 0.3, 0.03, "gomma")
    bici("dentro1", 2.5, 4.4, 0.05, "verde", bici_dentro)
    bici("dentro2", 8.9, 4.2, 0.05, "rossa", bici_dentro, verso=-1)


def portico():
    """Il pavimento, i pilastri, la trave e il tetto a falda del portico, e la
    ringhiera bianca nella campata di sinistra."""
    bx("pav_portico", 0.0, W, 0.0, PORTICO + 0.05, 0.0, 0.1, "cemento")
    bx("gradino", 0.0, W, 0.0, 0.08, 0.0, 0.1, "bianco_sporco")
    for k, x in enumerate(PILASTRI):
        bx("pilastro%d" % k, x - 0.13, x + 0.13, 0.1, 0.36, 0.1, Z_PORTICO, "bianco")
        bx("capitello%d" % k, x - 0.17, x + 0.17, 0.07, 0.4, Z_PORTICO - 0.14, Z_PORTICO, "bianco")
    bx("trave", 0.0, W, 0.06, 0.4, Z_PORTICO, Z_PORTICO + 0.28, "bianco")
    # La falda: dalla trave al muro, in salita.
    zf, zm = Z_PORTICO + 0.28, Z_PORTICO_MURO
    cv_p = [(0.0, 0.0, zf), (W, 0.0, zf), (W, PORTICO, zm), (0.0, PORTICO, zm),
            (0.0, 0.0, zf + 0.1), (W, 0.0, zf + 0.1), (W, PORTICO, zm + 0.1), (0.0, PORTICO, zm + 0.1)]
    facce = [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
    me = bpy.data.meshes.new("falda")
    me.from_pydata(cv_p, [], facce)
    me.materials.append(M["tegole"])
    ob = bpy.data.objects.new("falda", me)
    bpy.context.scene.collection.objects.link(ob)
    PEZZI.append(ob)
    # La ringhiera: corrimano, traversa bassa e colonnine.
    a, b = PILASTRI[0] + 0.13, PILASTRI[1] - 0.13
    bx("corrimano", a, b, 0.16, 0.3, 0.92, 1.0, "bianco")
    bx("traversa", a, b, 0.18, 0.28, 0.22, 0.28, "bianco")
    # Rade e un filo grosse: fitte, i contorni di due colonnine vicine si
    # toccavano e la ringhiera bianca usciva nera.
    n = int((b - a) / 0.34)
    for i in range(1, n):
        x = a + (b - a) * i / n
        bx("colonnina%d" % i, x - 0.04, x + 0.04, 0.19, 0.27, 0.28, 0.92, "bianco")


def bici_fuori(parcheggio, animati):
    """Le bici sul portico. Due appoggiate alla ringhiera, due alla
    rastrelliera davanti alla vetrina, una sul cavalletto da officina con la
    ruota di dietro che gira (nell'animazione)."""
    bici("ringhiera1", 1.4, 0.75, 0.1, "rossa", parcheggio)
    bici("ringhiera2", 3.4, 1.35, 0.1, "menta", parcheggio, verso=-1)
    # La rastrelliera: archetti neri, uno per bici, dietro alla bici.
    for k, x in enumerate((8.2, 10.2)):
        for s in (-0.35, 0.35):
            tubo("rastr%d_%d" % (k, s > 0), (x + s, 1.25, 0.1), (x + s, 1.25, 0.85), 0.025, "ferro", parcheggio)
        tubo("rastr%d_top" % k, (x - 0.35, 1.25, 0.85), (x + 0.35, 1.25, 0.85), 0.025, "ferro", parcheggio)
    bici("rastr_bici1", 8.2, 1.05, 0.1, "petrolio", parcheggio)
    bici("rastr_bici2", 10.2, 1.05, 0.1, "arancio", parcheggio, verso=-1)
    # Il cavalletto da officina: base a treppiede, colonna, braccio e morsa.
    cx, y, z0 = 12.4, 1.35, 0.42
    base = Vector((cx - 0.05, y + 0.25, 0.1))
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.4
        tubo("cav_piede%d" % k, base, base + Vector((math.cos(a) * 0.4, math.sin(a) * 0.3, 0)),
             0.025, "ferro", parcheggio)
    tubo("cav_colonna", base, base + Vector((0, 0, 1.25)), 0.03, "ferro", parcheggio)
    tubo("cav_braccio", base + Vector((0, 0, 1.25)), (cx - 0.2, y, z0 + 0.8), 0.028, "ferro", parcheggio)
    bx("cav_morsa", cx - 0.28, cx - 0.12, y - 0.06, y + 0.06, z0 + 0.72, z0 + 0.86, "telaio_rossa",
       raccolta=parcheggio)
    ruota_giro = []
    mozzo = bici("cavalletto", cx, y, z0, "crema", parcheggio, ruota_dietro=ruota_giro)
    perno = bpy.data.objects.new("ruota_perno", None)
    bpy.context.scene.collection.objects.link(perno)
    perno.location = mozzo
    for ob in ruota_giro:
        # La mesh e' gia' al suo posto nel mondo: la si riporta attorno al
        # perno e la si appende a lui, cosi' girando il perno gira sul mozzo.
        ob.data.transform(Matrix.Translation(-mozzo))
        ob.parent = perno
    animati["ruota"] = (ruota_giro, perno)


def insegna(animati):
    """L'ovale crema col bordo marrone, appeso alla trave con due catenelle.
    Tutto appeso a un perno sulla trave: e' quello che dondola."""
    x, y = 2.55, 0.18
    z_perno = Z_PORTICO
    pezzi = []
    perno = bpy.data.objects.new("insegna_perno", None)
    bpy.context.scene.collection.objects.link(perno)
    perno.location = (x, y, z_perno)
    zc = z_perno - 0.75
    disco("ovale_bordo", (x, y + 0.02, zc), 0.98, 0.42, 0.05, "bordo_ovale", pezzi)
    disco("ovale", (x, y - 0.01, zc), 0.9, 0.35, 0.05, "crema_ovale", pezzi)
    for s in (-0.55, 0.55):
        tubo("catenella%d" % (s > 0), (x + s, y, z_perno), (x + s * 0.9, y, zc + 0.36), 0.012, "ferro", pezzi)
    scritta = testo("ovale_scritta", "BIKES", x, y - 0.05, zc, 0.36, "scritta_marrone")
    pezzi.append(scritta)
    for ob in pezzi:
        if ob.type == "MESH":
            ob.data.transform(Matrix.Translation(-Vector(perno.location)))
        else:
            ob.location = ob.location - perno.location
        ob.parent = perno
    animati["insegna"] = (pezzi, perno)


def neon(animati):
    """OPEN in rosso, appeso dietro alla vetrina di destra, in alto a
    sinistra: davanti al vetro e non dietro, se no lo scatto dei fotogrammi
    lo trova coperto dal cristallo."""
    pezzi = []
    x0, x1, z0, z1 = 7.35, 8.55, 2.08, 2.55
    y = PORTICO + 0.02
    for nome, a, b, za, zb in (("neon_g", x0, x1, z0, z0 + 0.04), ("neon_a", x0, x1, z1 - 0.04, z1),
                               ("neon_s", x0, x0 + 0.04, z0, z1), ("neon_d", x1 - 0.04, x1, z0, z1)):
        bx(nome, a, b, y - 0.03, y, za, zb, "neon", raccolta=pezzi)
    pezzi.append(testo("neon_scritta", "OPEN", (x0 + x1) / 2, y - 0.04, (z0 + z1) / 2, 0.3, "neon"))
    animati["neon"] = (pezzi, None)


# ----------------------------------------------------------------------
#  scena e scatti
# ----------------------------------------------------------------------

COLL_BICI = "Bici"


def linea_bici():
    """Una linea sottile e a mezza opacita' solo intorno alle bici: quanto
    basta a staccarle dal pavimento del portico senza annerirle."""
    fs = bpy.context.view_layer.freestyle_settings
    ls = fs.linesets.new("Bici")
    for a in ("select_crease", "select_border", "select_ridge_valley", "select_suggestive_contour",
              "select_material_boundary", "select_edge_mark"):
        setattr(ls, a, False)
    ls.select_silhouette = True
    ls.select_by_collection = True
    ls.collection = bpy.data.collections[COLL_BICI]
    ls.collection_negation = "INCLUSIVE"
    ls.linestyle.color = (0.05, 0.04, 0.035)
    ls.linestyle.alpha = 0.55
    ls.linestyle.thickness = 0.9


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
    parcheggio, dentro = [], []
    corpo()
    vetrine()
    interno(dentro)
    portico()
    bici_fuori(parcheggio, animati)
    insegna(animati)
    neon(animati)
    cv.unisci(list(PEZZI), "BI_Negozio")
    # Le bici a parte, e fuori dal contorno spesso: intorno a tubi di un pixel
    # e mezzo la linea da due pixel del Freestyle le faceva diventare macchie
    # nere. Stanno nella collezione delle scritte, che il contorno salta, e in
    # una loro, che ha una linea sottile tutta sua (`linea_bici()`).
    bici_ob = [cv.unisci(parcheggio, "BI_Bici"), cv.unisci(dentro, "BI_Bici_Dentro")]
    testi = bpy.data.collections.get(cv.COLL_TESTI)
    mie = bpy.data.collections.new(COLL_BICI)
    bpy.context.scene.collection.children.link(mie)
    for ob in bici_ob:
        testi.objects.link(ob)
        mie.objects.link(ob)
        bpy.context.scene.collection.objects.unlink(ob)
    cam = cv.scena()
    linea_bici()
    for pezzi, _ in animati.values():
        for ob in pezzi:
            ob.hide_render = True
    cv.inquadra(cam, 0.0, W)
    return animati


# La ruota: due giri esatti che rallentano, cosi' l'ultimo fotogramma torna
# sulla posa di partenza. Il passo scende di un tanto a fotogramma.
FOTOGRAMMI_RUOTA = 24
# L'insegna: un'oscillazione intera, in otto pose.
FOTOGRAMMI_INSEGNA = 8
OSCILLAZIONE = 5.0
# Il neon: acceso, e poi lo sfarfallio. Il primo e' la posa di riposo.
SFARFALLIO = [1, 0, 1, 0, 0, 1, 0, 1, 1, 1]


def angoli_ruota():
    passi = [FOTOGRAMMI_RUOTA - i for i in range(FOTOGRAMMI_RUOTA)]
    scala = 720.0 / sum(passi)
    out, a = [], 0.0
    for p in passi:
        out.append(a)
        a += p * scala
    return out


def renderizza():
    os.makedirs(OUT, exist_ok=True)
    sc = bpy.context.scene
    costruisci()
    sc.render.filepath = os.path.join(OUT, "render_bici.png")
    bpy.ops.render.render(write_still=True)
    cv.modo_luci()
    sc.render.filepath = os.path.join(OUT, "luci_bici.png")
    bpy.ops.render.render(write_still=True)

    for cosa in ("ruota", "insegna", "neon"):
        animati = costruisci()
        tengo, perno = animati[cosa]
        tutti = [ob for pezzi, _ in animati.values() for ob in pezzi]
        for ob in bpy.data.objects:
            if ob.type in ("MESH", "FONT"):
                ob.is_holdout = ob not in tengo
                ob.hide_render = ob in tutti and ob not in tengo
        for ob in tengo:
            ob.hide_render = False
        sc.render.use_freestyle = False
        if cosa == "ruota":
            pose = angoli_ruota()
        elif cosa == "insegna":
            pose = [OSCILLAZIONE * math.sin(2 * math.pi * i / FOTOGRAMMI_INSEGNA)
                    for i in range(FOTOGRAMMI_INSEGNA)]
        else:
            pose = SFARFALLIO
        for i, posa in enumerate(pose):
            if cosa == "ruota":
                # Positivo attorno a +Y e' orario visto dalla camera: il verso
                # di una ruota di dietro quando si pedala in avanti.
                perno.rotation_euler = (0, math.radians(posa), 0)
            elif cosa == "insegna":
                perno.rotation_euler = (0, math.radians(posa), 0)
            else:
                cv._set(cv._bsdf(M["neon"]), "Emission Strength", 1.4 if posa else 0.05)
                cv._set(cv._bsdf(M["neon"]), "Base Color",
                        cv.srgb("#E8321E") if posa else cv.srgb("#5A2622"))
            sc.render.filepath = os.path.join(OUT, "anim_bici_%s_%02d.png" % (cosa, i))
            bpy.ops.render.render(write_still=True)
    print("BICI", sc.render.resolution_x, sc.render.resolution_y)


if __name__ == "__main__":
    renderizza()
