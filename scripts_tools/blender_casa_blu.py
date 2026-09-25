"""Costruisce in Blender la casetta azzurra di THE FLATS, su WESTGATE AVENUE.

**E' la prima casa girata.** Tutte le altre guardano a sud, verso la camera:
questa ha l'ingresso a OVEST, sulla strada verticale che chiude la citta' da
quel lato, e sta nell'isolato fra MAIN STREET e la casa con la staccionata,
dietro a quest'ultima. La camera pero' guarda sempre a nord, quindi di questa
casa si vede il FIANCO SUD, non la facciata: per questo e' modellata tutta,
su tutti e quattro i lati, e la parte che si vede davvero — il fianco con le
finestre, la porta di servizio, il terrazzino dietro — e' quella curata di piu'.

Presa da una foto di una casetta di provincia americana, senza copiarla:

  * **ovest, sulla strada** — il timpano ripido rivestito di scandole, con la
    finestrella della soffitta; il vestibolo d'ingresso che sporge, col suo
    timpanetto e l'arco bianco; la grande finestra del soggiorno a nord e una
    piccola a sud; davanti la staccionata bianca a tavole piene, col cancelletto
    e la grata a ventaglio;
  * **sud, il lato che si vede** — il fianco lungo a doghe azzurre, quattro
    finestre, la porta di servizio con la tettoia e i gradini, il contatore,
    le grate di aerazione del vespaio, le grondaie coi pluviali;
  * **est, dietro** — il timpano con la persiana d'aerazione e la porta sul
    terrazzino di legno, con la ringhiera e la scaletta;
  * **nord** — l'ala bassa col tetto a padiglione, e le sue finestre.

Il lotto e' chiuso su tutti i lati dalla stessa staccionata a tavole: e' il
lotto della casa, come la rete della casa gialla. Niente verde, cassette
della posta, auto: quello che sta a terra e' citta'.

## Gli assi

Come in tutti gli script: X verso destra (est), Y verso il fondo (nord), la
camera guarda verso +Y. x = 0 e' il confine del lotto sul marciapiede di
WESTGATE AVENUE, y = 0 quello a sud, che nello sprite e' la riga di terra.

Uso:
  blender --background --factory-startup --python scripts_tools/blender_casa_blu.py
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
# Scena, camera, luci e inquadratura del cinema; tubi del negozio di bici;
# prismi e cilindri della steak house; la linea sottile della casa con la
# staccionata.
import blender_bici as bi  # noqa: E402
import blender_casa_staccionata as cs  # noqa: E402
import blender_cinema_videogiochi as cv  # noqa: E402
import blender_steakhouse as st  # noqa: E402
from blender_cinema_videogiochi import M, PEZZI, bx, piatto  # noqa: E402

OUT = cv.OUT
# Il lotto: 357 px da ovest a est (16 m), 15 m da sud a nord.
LOTTO_X = 357.0 / cv.PX_PER_METRO
LOTTO_Y = 15.0

# Il corpo principale, col colmo da ovest a est e il timpano sulla strada.
CX = (3.0, 13.0)
CY = (2.0, 9.5)
GRONDA = 3.1
COLMO = 7.0
FONDAZIONE = 0.4
SPORTO = 0.35
# L'ala bassa a nord.
AX = (4.0, 12.0)
AY = (CY[1], 13.8)
A_GRONDA = 2.8
A_COLMO = 4.4
# Il vestibolo d'ingresso che sporge sulla facciata ovest.
VX = (1.9, CX[0])
VY = (4.25, 5.95)
V_GRONDA = 2.9
V_COLMO = 3.75
# Il cancelletto nella staccionata sulla strada, in asse col vestibolo.
CANCELLO = (4.6, 5.6)
STACCIONATA_H = 1.5
STRADA_H = 1.6


def palette():
    cv.palette()
    M["doghe"] = cv.righe("CB_Doghe", "#7F8D9D", "#6A7788", 0.2, frazione=0.14)
    M["scandole"] = cv.righe("CB_Scandole", "#76849A", "#5E6B7D", 0.17, frazione=0.3)
    M["tegole"] = cv.righe("CB_Tegole", "#4A4F55", "#3B3F44", 0.28, frazione=0.16)
    M["tavole_x"] = cv.righe("CB_Tavole_X", "#EDEDE9", "#CFCFCA", 0.15, asse="X", frazione=0.1)
    M["tavole_y"] = cv.righe("CB_Tavole_Y", "#EDEDE9", "#CFCFCA", 0.15, asse="Y", frazione=0.1)
    M["bianco"] = piatto("CB_Bianco", "#EFEEE9", 0.7)
    M["fondazione"] = piatto("CB_Fondazione", "#9C9992", 0.95)
    M["cemento"] = piatto("CB_Cemento", "#A8A59E", 0.95)
    M["porta"] = piatto("CB_Porta", "#3B4755", 0.5)
    M["scuro"] = piatto("CB_Scuro", "#2A2E33", 0.8)
    M["ferro"] = piatto("CB_Ferro", "#6A3A26", 0.5, 0.4)
    M["metallo"] = piatto("CB_Metallo", "#9FA4A8", 0.4, 0.7)
    M["grondaia"] = piatto("CB_Grondaia", "#E4E3DE", 0.5)
    M["legno_ponte"] = cv.righe("CB_Legno", "#8E7862", "#766250", 0.14, asse="X", frazione=0.1)
    M["mattone"] = cv.righe("CB_Mattone", "#8C4A3C", "#6E392E", 0.09, frazione=0.2)
    M["nero"] = piatto("CB_Nero", "#1E1C1B", 0.6)
    M["lampadina"] = piatto("CB_Lampadina", "#F4E2B0", 0.3, emissivo="#FFE6A0", forza=2.0)


# ----------------------------------------------------------------------
#  primitive: scatole appoggiate a un muro, da qualunque lato guardi
# ----------------------------------------------------------------------

def su_muro(nome, lato, piano, a0, a1, d0, d1, z0, z1, mat, raccolta=None):
    """Una scatola appoggiata a un muro. `lato` e' dove guarda il muro (S, N, O,
    E), `piano` la sua coordinata (y per S e N, x per O ed E), `a0..a1` la
    posizione lungo il muro e `d0..d1` quanto sporge verso fuori. Serve a
    scrivere finestre e porte una volta sola per tutti e quattro i lati."""
    if lato == "S":
        return bx(nome, a0, a1, piano - d1, piano - d0, z0, z1, mat, raccolta=raccolta)
    if lato == "N":
        return bx(nome, a0, a1, piano + d0, piano + d1, z0, z1, mat, raccolta=raccolta)
    if lato == "O":
        return bx(nome, piano - d1, piano - d0, a0, a1, z0, z1, mat, raccolta=raccolta)
    return bx(nome, piano + d0, piano + d1, a0, a1, z0, z1, mat, raccolta=raccolta)


def finestra(nome, lato, piano, a0, a1, z0, z1, vetro, riquadri=1, traversi=1):
    """Il vetro, la cornice bianca larga tutto intorno col davanzale, e i
    montanti bianchi: come nella foto, dove le finestre sono incorniciate da
    tavole bianche piu' larghe del telaio."""
    c = 0.11
    su_muro(nome + "_v", lato, piano, a0, a1, 0.0, 0.03, z0, z1, vetro)
    su_muro(nome + "_cs", lato, piano, a0 - c, a0, 0.0, 0.06, z0 - c, z1 + c, "bianco")
    su_muro(nome + "_cd", lato, piano, a1, a1 + c, 0.0, 0.06, z0 - c, z1 + c, "bianco")
    su_muro(nome + "_ca", lato, piano, a0 - c - 0.03, a1 + c + 0.03, 0.0, 0.08, z1, z1 + c + 0.03, "bianco")
    su_muro(nome + "_cg", lato, piano, a0 - c - 0.05, a1 + c + 0.05, 0.0, 0.1, z0 - c, z0, "bianco")
    t = 0.03
    for i in range(1, riquadri):
        a = a0 + (a1 - a0) * i / riquadri
        su_muro("%s_m%d" % (nome, i), lato, piano, a - t, a + t, 0.03, 0.05, z0, z1, "bianco")
    for i in range(1, traversi + 1):
        z = z0 + (z1 - z0) * i / (traversi + 1)
        su_muro("%s_t%d" % (nome, i), lato, piano, a0, a1, 0.03, 0.05, z - t, z + t, "bianco")


def porta(nome, lato, piano, a0, a1, z0, z1, finestrella=True):
    su_muro(nome + "_telaio", lato, piano, a0 - 0.09, a1 + 0.09, 0.0, 0.05, z0, z1 + 0.09, "bianco")
    su_muro(nome, lato, piano, a0, a1, 0.05, 0.08, z0, z1, "porta")
    if finestrella:
        m = (a1 - a0) * 0.22
        su_muro(nome + "_vetro", lato, piano, a0 + m, a1 - m, 0.08, 0.09, z1 - 0.75, z1 - 0.2, "vetro")
    am = a1 - 0.12 if lato in ("S", "E") else a0 + 0.12
    su_muro(nome + "_maniglia", lato, piano, am - 0.03, am + 0.03, 0.08, 0.13, z0 + 0.95, z0 + 1.05, "metallo")


def lampioncino(nome, lato, piano, a, z):
    su_muro(nome, lato, piano, a - 0.08, a + 0.08, 0.0, 0.16, z, z + 0.3, "nero")
    su_muro(nome + "_luce", lato, piano, a - 0.05, a + 0.05, 0.16, 0.17, z + 0.05, z + 0.24, "lampadina")


def prisma_x(nome, punti, x0, x1, mat, raccolta=None):
    """Come `st.prisma`, ma il poligono sta nel piano YZ ed e' estruso lungo X:
    i timpani e i tetti col colmo da ovest a est."""
    bm = bmesh.new()
    a = [bm.verts.new((x0, y, z)) for y, z in punti]
    b = [bm.verts.new((x1, y, z)) for y, z in punti]
    bm.faces.new(a)
    bm.faces.new(list(reversed(b)))
    n = len(punti)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[i], b[i], b[j], a[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return st._oggetto(nome, bm, mat, raccolta if raccolta is not None else PEZZI)


def tetto_x(nome, x0, x1, y0, y1, z_gronda, z_colmo, mat, spessore=0.15):
    """Il tetto a due falde col colmo lungo X: la V rovesciata di
    `cs.tetto_a_capanna`, girata di novanta gradi."""
    yc = (y0 + y1) / 2
    t = spessore
    profilo = [(y0, z_gronda), (yc, z_colmo), (y1, z_gronda),
               (y1, z_gronda - t), (yc, z_colmo - t * 1.4), (y0, z_gronda - t)]
    return prisma_x(nome, profilo, x0, x1, mat)


def padiglione(nome, x0, x1, y0, y1, z_gronda, z_colmo, mat):
    """Tetto a padiglione: quattro falde, colmo lungo X."""
    yc = (y0 + y1) / 2
    d = (y1 - y0) / 2
    v = [(x0, y0, z_gronda), (x1, y0, z_gronda), (x1, y1, z_gronda), (x0, y1, z_gronda),
         (x0 + d, yc, z_colmo), (x1 - d, yc, z_colmo)]
    bm = bmesh.new()
    vv = [bm.verts.new(p) for p in v]
    for f in ((0, 1, 5, 4), (3, 2, 5, 4), (0, 4, 3), (1, 2, 5), (0, 3, 2, 1)):
        bm.faces.new([vv[i] for i in f])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return st._oggetto(nome, bm, mat, PEZZI)


def sagoma_arco(y0, y1, z0, z_imposta, passi=12):
    """Il profilo di un arco a tutto sesto nel piano YZ: rettangolo fino
    all'imposta, mezzo cerchio sopra."""
    yc, r = (y0 + y1) / 2, (y1 - y0) / 2
    punti = [(y0, z0), (y1, z0)]
    punti += [(yc + r * math.cos(math.pi * i / passi), z_imposta + r * math.sin(math.pi * i / passi))
              for i in range(passi + 1)]
    return punti


# ----------------------------------------------------------------------
#  la casa
# ----------------------------------------------------------------------

def corpo():
    x0, x1 = CX
    y0, y1 = CY
    bx("corpo", x0, x1, y0, y1, FONDAZIONE, GRONDA, "doghe")
    bx("fondazione", x0 - 0.04, x1 + 0.04, y0 - 0.04, y1 + 0.04, 0.0, FONDAZIONE, "fondazione")
    # I timpani, a scandole, e la fascia bianca che li separa dalle doghe.
    yc = (y0 + y1) / 2
    triangolo = [(y0, GRONDA), (y1, GRONDA), (yc, COLMO - 0.2)]
    prisma_x("timpano_o", triangolo, x0 - 0.03, x0, "scandole")
    prisma_x("timpano_e", triangolo, x1, x1 + 0.03, "scandole")
    for nome, a, b in (("fascia_o", x0 - 0.1, x0), ("fascia_e", x1, x1 + 0.1)):
        bx(nome, a, b, y0, y1, GRONDA - 0.08, GRONDA + 0.1, "bianco")
    # Il tetto, le cornici bianche sui timpani, i frontalini e le grondaie.
    tetto_x("tetto", x0 - SPORTO, x1 + SPORTO, y0 - SPORTO, y1 + SPORTO, GRONDA - 0.1, COLMO, "tegole")
    for nome, a in (("cornice_o", x0 - SPORTO - 0.04), ("cornice_e", x1 + SPORTO)):
        tetto_x(nome, a, a + 0.04, y0 - SPORTO - 0.02, y1 + SPORTO + 0.02, GRONDA - 0.1, COLMO + 0.03,
                "bianco", spessore=0.2)
    for nome, y in (("frontalino_s", y0 - SPORTO), ("frontalino_n", y1 + SPORTO - 0.06)):
        bx(nome, x0 - SPORTO, x1 + SPORTO, y, y + 0.06, GRONDA - 0.3, GRONDA - 0.1, "bianco")
    bx("grondaia_s", x0 - SPORTO, x1 + SPORTO, y0 - SPORTO - 0.12, y0 - SPORTO, GRONDA - 0.32,
       GRONDA - 0.16, "grondaia")
    bx("grondaia_n", x0 - SPORTO, x1 + SPORTO, y1 + SPORTO, y1 + SPORTO + 0.12, GRONDA - 0.32,
       GRONDA - 0.16, "grondaia")
    # I pluviali agli angoli del fianco sud.
    for k, x in enumerate((x0 + 0.15, x1 - 0.15)):
        bx("pluviale_s%d" % k, x - 0.05, x + 0.05, y0 - 0.12, y0 - 0.02, 0.0, GRONDA - 0.2, "grondaia")
        bx("pluviale_n%d" % k, x - 0.05, x + 0.05, y1 + 0.02, y1 + 0.12, 0.0, GRONDA - 0.2, "grondaia")
    # Le cantonali bianche, su tutti e quattro gli angoli e tutte e due le facce.
    for x, y in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):
        sx = -1 if x == x0 else 1
        sy = -1 if y == y0 else 1
        bx("cant_%d_%d_a" % (x, y), min(x, x - sx * 0.14), max(x, x - sx * 0.14),
           min(y, y + sy * 0.04), max(y, y + sy * 0.04), FONDAZIONE, GRONDA, "bianco")
        bx("cant_%d_%d_b" % (x, y), min(x, x + sx * 0.04), max(x, x + sx * 0.04),
           min(y, y - sy * 0.14), max(y, y - sy * 0.14), FONDAZIONE, GRONDA, "bianco")
    # Il comignolo di mattoni sulla falda nord, verso il fondo.
    bx("comignolo", 10.3, 10.9, 7.2, 7.9, 4.6, 7.6, "mattone")
    bx("comignolo_cap", 10.22, 10.98, 7.12, 7.98, 7.6, 7.7, "cemento")
    # Due sfiati sulla falda sud.
    for x in (6.0, 9.2):
        bi.tubo("sfiato%d" % int(x * 10), (x, 3.9, 4.8), (x, 3.9, 5.2), 0.06, "nero")


def facciata_ovest():
    """Sulla strada: la finestra del soggiorno a nord, la piccola a sud, la
    finestrella della soffitta nel timpano."""
    x = CX[0]
    finestra("soggiorno", "O", x, 6.5, 8.9, 0.95, 2.45, "vetro_acceso", riquadri=1, traversi=0)
    finestra("studio", "O", x, 2.6, 3.5, 1.15, 2.3, "vetro_acceso")
    finestra("soffitta_o", "O", x - 0.03, 5.35, 6.15, 4.75, 5.85, "vetro")


def vestibolo():
    """Il vestibolo d'ingresso che sporge sulla strada: il gradino, l'arco
    bianco davanti alla porta, il timpanetto, il lampioncino, il numero."""
    x0, x1 = VX
    y0, y1 = VY
    yc = (y0 + y1) / 2
    bx("vestibolo", x0, x1, y0, y1, FONDAZIONE, V_GRONDA, "doghe")
    # Il pianerottolo di cemento e i due gradini verso il cancelletto.
    bx("pianerottolo", x0 - 0.6, x1, y0 - 0.15, y1 + 0.15, 0.0, FONDAZIONE, "cemento")
    bx("gradino1", x0 - 0.9, x0 - 0.6, y0 + 0.1, y1 - 0.1, 0.0, 0.27, "cemento")
    bx("gradino2", x0 - 1.2, x0 - 0.9, y0 + 0.1, y1 - 0.1, 0.0, 0.13, "cemento")
    # I corrimano bianchi ai lati dei gradini.
    for k, y in enumerate((y0 + 0.05, y1 - 0.05)):
        bx("corrimano%d" % k, x0 - 1.2, x0 - 0.1, y - 0.03, y + 0.03, 0.95, 1.0, "bianco")
        for xx in (x0 - 1.15, x0 - 0.15):
            bx("corrimano%d_%d" % (k, int(xx * 10)), xx - 0.03, xx + 0.03, y - 0.03, y + 0.03,
               0.0, 0.97, "bianco")
    # L'arco: la cornice bianca e dentro il vano scuro.
    ay0, ay1 = yc - 0.5, yc + 0.5
    cornice = sagoma_arco(ay0 - 0.14, ay1 + 0.14, FONDAZIONE, 2.2)
    prisma_x("arco_cornice", cornice, x0 - 0.04, x0, "bianco")
    prisma_x("arco_vano", sagoma_arco(ay0, ay1, FONDAZIONE, 2.2), x0 - 0.05, x0 - 0.04, "scuro")
    # Il timpanetto, il suo tetto e la cornice.
    prisma_x("vest_timpano", [(y0, V_GRONDA), (y1, V_GRONDA), (yc, V_COLMO - 0.1)], x0 - 0.03, x0, "scandole")
    bx("vest_fascia", x0 - 0.08, x0, y0, y1, V_GRONDA - 0.08, V_GRONDA + 0.06, "bianco")
    tetto_x("vest_tetto", x0 - 0.2, x1 + 0.4, y0 - 0.2, y1 + 0.2, V_GRONDA - 0.08, V_COLMO + 0.1, "tegole",
            spessore=0.12)
    tetto_x("vest_cornice", x0 - 0.24, x0 - 0.2, y0 - 0.22, y1 + 0.22, V_GRONDA - 0.08, V_COLMO + 0.13,
            "bianco", spessore=0.16)
    lampioncino("vest_lamp", "O", x0, y1 - 0.12, 1.75)
    su_muro("vest_numero", "O", x0, y0 + 0.1, y0 + 0.28, 0.0, 0.03, 1.7, 2.3, "nero")
    # Il fianco sud del vestibolo, quello che si vede: una finestrella stretta.
    finestra("vest_fin", "S", y0, x0 + 0.3, x1 - 0.3, 1.25, 2.25, "vetro_acceso", traversi=0)


def fianco_sud():
    """Il lato che si vede: quattro finestre, la porta di servizio con la
    tettoia, i gradini e il lampioncino, il contatore, le grate del vespaio."""
    y = CY[0]
    finestra("s_camera", "S", y, 4.2, 5.2, 0.95, 2.4, "vetro_acceso")
    finestra("s_camera2", "S", y, 6.5, 7.5, 0.95, 2.4, "vetro")
    finestra("s_bagno", "S", y, 9.3, 10.0, 1.55, 2.3, "vetro", traversi=0)
    finestra("s_cucina", "S", y, 10.7, 11.7, 1.3, 2.3, "vetro_acceso", riquadri=2, traversi=0)
    porta("s_porta", "S", y, 12.05, 12.85, FONDAZIONE + 0.05, 2.45)
    lampioncino("s_lamp", "S", y, 11.9, 1.95)
    # I gradini della porta di servizio.
    bx("s_gradino_alto", 11.85, 13.05, y - 0.8, y, 0.0, FONDAZIONE + 0.05, "cemento")
    bx("s_gradino_basso", 11.95, 12.95, y - 1.1, y - 0.8, 0.0, 0.22, "cemento")
    # La tettoia sopra la porta: una falda sola, appoggiata al muro su due
    # mensole bianche.
    prisma_x("s_tettoia", [(y, 3.0), (y, 2.88), (y - 0.9, 2.62), (y - 0.9, 2.72)], 11.8, 13.1, "tegole")
    for k, x in enumerate((11.85, 13.05)):
        prisma_x("s_mensola%d" % k, [(y, 2.85), (y, 2.45), (y - 0.08, 2.45), (y - 0.7, 2.74)],
                 x - 0.03, x + 0.03, "bianco")
    # Il contatore e il suo tubo, e il rubinetto del giardino.
    su_muro("contatore", "S", y, 8.2, 8.55, 0.0, 0.14, 1.3, 1.8, "metallo")
    su_muro("contatore_vetro", "S", y, 8.3, 8.45, 0.14, 0.15, 1.5, 1.65, "scuro")
    su_muro("contatore_tubo", "S", y, 8.35, 8.4, 0.0, 0.05, FONDAZIONE, 1.3, "metallo")
    su_muro("rubinetto", "S", y, 5.8, 5.9, 0.0, 0.1, 0.55, 0.62, "metallo")
    # Le grate di aerazione del vespaio, nella fondazione.
    for k, x in enumerate((4.6, 7.0, 9.6)):
        su_muro("grata%d" % k, "S", CY[0] - 0.04, x, x + 0.4, 0.0, 0.02, 0.12, 0.3, "scuro")


def retro(sottili):
    """Dietro, a est: la persiana d'aerazione nel timpano, la porta sul
    terrazzino di legno con la ringhiera e la scaletta verso sud, una finestra."""
    x = CX[1]
    su_muro("persiana_e", "E", x + 0.03, 5.4, 6.1, 0.0, 0.05, 4.8, 5.7, "scuro")
    su_muro("persiana_e_c", "E", x + 0.03, 5.3, 6.2, 0.0, 0.03, 4.7, 5.8, "bianco")
    for k in range(1, 5):
        z = 4.8 + 0.9 * k / 5
        su_muro("persiana_e_l%d" % k, "E", x + 0.03, 5.4, 6.1, 0.05, 0.07, z - 0.02, z + 0.02, "bianco")
    porta("e_porta", "E", x, 5.0, 5.85, 0.55, 2.6)
    finestra("e_fin", "E", x, 7.6, 8.6, 1.1, 2.3, "vetro_acceso")
    # Il terrazzino: impalcato, pali, ringhiera e scaletta.
    d0, d1 = x, x + 1.8
    t0, t1 = 3.8, 7.2
    zp = 0.55
    bx("terrazzo", d0, d1, t0, t1, zp - 0.1, zp, "legno_ponte")
    bx("terrazzo_bordo", d0, d1, t0 - 0.04, t0, zp - 0.3, zp, "legno_ponte")
    for k, (px, py) in enumerate(((d1 - 0.06, t0 + 0.06), (d1 - 0.06, t1 - 0.06), (d0 + 0.2, t0 + 0.06))):
        bx("terrazzo_palo%d" % k, px - 0.06, px + 0.06, py - 0.06, py + 0.06, 0.0, zp + 0.95, "bianco")
    # La ringhiera: a sud (verso la camera, lasciando il passaggio della
    # scaletta) e a est.
    for nome, a0, a1, b0, b1, lungo_x in (("r_sud", d0 + 0.2, d1 - 0.9, t0 + 0.03, t0 + 0.09, True),
                                           ("r_est", d1 - 0.09, d1 - 0.03, t0 + 0.06, t1 - 0.06, False)):
        bx(nome + "_cm", a0, a1, b0 - 0.01, b1 + 0.01, zp + 0.88, zp + 0.95, "bianco", raccolta=sottili)
        bx(nome + "_tr", a0, a1, b0, b1, zp + 0.08, zp + 0.13, "bianco", raccolta=sottili)
        lung = (a1 - a0) if lungo_x else (b1 - b0)
        n = max(2, int(lung / 0.14))
        for i in range(1, n):
            if lungo_x:
                xx = a0 + (a1 - a0) * i / n
                bx("%s_c%d" % (nome, i), xx - 0.02, xx + 0.02, b0, b1, zp + 0.13, zp + 0.88, "bianco",
                   raccolta=sottili)
            else:
                yy = b0 + (b1 - b0) * i / n
                bx("%s_c%d" % (nome, i), a0, a1, yy - 0.02, yy + 0.02, zp + 0.13, zp + 0.88, "bianco",
                   raccolta=sottili)
    # La scaletta, dal bordo sud verso il giardino.
    for k in range(3):
        bx("scaletta%d" % k, d1 - 0.85, d1 - 0.1, t0 - 0.28 * (k + 1), t0 - 0.28 * k,
           0.0, zp - 0.18 * (k + 1) + 0.02, "legno_ponte")


def ala_nord():
    """L'ala bassa a nord col tetto a padiglione: finestre a ovest, a nord e a
    est, cantonali e fondazione come il corpo."""
    x0, x1 = AX
    y0, y1 = AY
    bx("ala", x0, x1, y0, y1, FONDAZIONE, A_GRONDA, "doghe")
    bx("ala_fond", x0 - 0.04, x1 + 0.04, y0, y1 + 0.04, 0.0, FONDAZIONE, "fondazione")
    padiglione("ala_tetto", x0 - SPORTO, x1 + SPORTO, y0 - 0.2, y1 + SPORTO, A_GRONDA - 0.08, A_COLMO, "tegole")
    bx("ala_frontalino", x0 - SPORTO, x1 + SPORTO, y1 + SPORTO - 0.06, y1 + SPORTO, A_GRONDA - 0.28,
       A_GRONDA - 0.08, "bianco")
    finestra("ala_o1", "O", x0, 10.3, 11.3, 1.0, 2.2, "vetro_acceso")
    finestra("ala_o2", "O", x0, 12.3, 13.2, 1.0, 2.2, "vetro")
    for k, (a, b) in enumerate(((5.0, 6.0), (7.5, 8.5), (10.0, 11.0))):
        finestra("ala_n%d" % k, "N", y1, a, b, 1.0, 2.2, "vetro_acceso" if k == 1 else "vetro")
    finestra("ala_e", "E", x1, 11.0, 12.0, 1.0, 2.2, "vetro")
    for x, y in ((x0, y1), (x1, y1)):
        bx("ala_cant_%d" % x, x - 0.07, x + 0.07, y - 0.07, y + 0.07, FONDAZIONE, A_GRONDA, "bianco")


def staccionata():
    """La staccionata bianca a tavole piene, su tutti e quattro i lati del
    lotto. Sulla strada e' un filo piu' alta e ha il cancelletto, in asse col
    vestibolo, con la grata di ferro a ventaglio in alto."""
    X, Y = LOTTO_X, LOTTO_Y
    s = 0.08
    lati = (
        # nome, x0, x1, y0, y1, altezza, materiale
        ("st_sud", 0.0, X, 0.0, s, STACCIONATA_H, "tavole_x"),
        ("st_nord", 0.0, X, Y - s, Y, STACCIONATA_H, "tavole_x"),
        ("st_est", X - s, X, 0.0, Y, STACCIONATA_H, "tavole_y"),
        ("st_ovest_a", 0.0, s, 0.0, CANCELLO[0], STRADA_H, "tavole_y"),
        ("st_ovest_b", 0.0, s, CANCELLO[1], Y, STRADA_H, "tavole_y"),
    )
    for nome, x0, x1, y0, y1, h, mat in lati:
        bx(nome, x0, x1, y0, y1, 0.0, h, mat)
        bx(nome + "_cap", x0 - 0.02, x1 + 0.02, y0 - 0.02, y1 + 0.02, h, h + 0.05, "bianco")
    # I pali, ogni due metri e mezzo circa, un palmo piu' alti.
    passo = 2.4
    for k in range(int(X / passo) + 1):
        x = min(k * passo, X - 0.1) + 0.05
        for nome, y in (("s", 0.04), ("n", Y - 0.04)):
            bx("palo_%s%d" % (nome, k), x - 0.07, x + 0.07, y - 0.07, y + 0.07, 0.0, STACCIONATA_H + 0.12,
               "bianco")
    for k in range(1, int(Y / passo) + 1):
        y = min(k * passo, Y - 0.1)
        bx("palo_e%d" % k, X - 0.11, X + 0.03, y - 0.07, y + 0.07, 0.0, STACCIONATA_H + 0.12, "bianco")
        if not (CANCELLO[0] - 0.2 < y < CANCELLO[1] + 0.2):
            bx("palo_o%d" % k, -0.03, 0.11, y - 0.07, y + 0.07, 0.0, STRADA_H + 0.12, "bianco")
    # Il cancelletto, i suoi due pilastrini e la grata a ventaglio.
    c0, c1 = CANCELLO
    for k, y in enumerate((c0, c1)):
        bx("cancello_pil%d" % k, -0.04, 0.12, y - 0.08, y + 0.08, 0.0, STRADA_H + 0.25, "bianco")
        bx("cancello_pil%d_cap" % k, -0.06, 0.14, y - 0.1, y + 0.1, STRADA_H + 0.25, STRADA_H + 0.3, "bianco")
    bx("cancello", 0.01, 0.07, c0 + 0.08, c1 - 0.08, 0.05, STRADA_H + 0.08, "tavole_y")
    yc = (c0 + c1) / 2
    r = (c1 - c0) / 2 - 0.2
    zc = STRADA_H - 0.35
    ventaglio = [(yc + r * math.cos(math.pi * i / 10), zc + r * math.sin(math.pi * i / 10)) for i in range(11)]
    prisma_x("grata", ventaglio, -0.01, 0.01, "ferro")
    for k in range(5):
        a = math.pi * (k + 0.5) / 5
        bx("grata_raggio%d" % k, -0.015, 0.0, yc + (r - 0.05) * math.cos(a) - 0.015,
           yc + (r - 0.05) * math.cos(a) + 0.015, zc, zc + (r - 0.05) * math.sin(a), "bianco")
    bx("cancello_maniglia", -0.05, 0.01, c1 - 0.2, c1 - 0.15, 0.85, 1.05, "nero")
    # Il numero civico sulla staccionata, accanto al cancelletto.
    bx("civico", -0.02, 0.0, c1 + 0.25, c1 + 0.6, STRADA_H - 0.35, STRADA_H - 0.15, "nero")


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
    sottili = []
    corpo()
    facciata_ovest()
    vestibolo()
    fianco_sud()
    retro(sottili)
    ala_nord()
    staccionata()
    cv.unisci(list(PEZZI), "CB_Casa")
    fine = cv.unisci(sottili, "CB_Ringhiera")
    # La ringhiera del terrazzino fuori dal contorno spesso, con la linea
    # sottile della casa con la staccionata (vedi `cs.linea_sottile()`).
    testi = bpy.data.collections.new(cv.COLL_TESTI)
    bpy.context.scene.collection.children.link(testi)
    mia = bpy.data.collections.new(cs.COLL_STACCIONATA)
    bpy.context.scene.collection.children.link(mia)
    testi.objects.link(fine)
    mia.objects.link(fine)
    bpy.context.scene.collection.objects.unlink(fine)
    cam = cv.scena()
    cs.linea_sottile()
    cv.inquadra(cam, 0.0, LOTTO_X)


def renderizza():
    os.makedirs(OUT, exist_ok=True)
    sc = bpy.context.scene
    costruisci()
    sc.render.filepath = os.path.join(OUT, "render_casa_blu.png")
    bpy.ops.render.render(write_still=True)
    cv.modo_luci()
    sc.render.filepath = os.path.join(OUT, "luci_casa_blu.png")
    bpy.ops.render.render(write_still=True)
    print("CASA_BLU", sc.render.resolution_x, sc.render.resolution_y)


if __name__ == "__main__":
    renderizza()
