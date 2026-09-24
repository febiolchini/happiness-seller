"""Costruisce in Blender gli edifici dell'aeroporto di CIVIC CENTER.

L'aeroporto prende il posto di quattro isolati in basso a sinistra (vedi
`CityMap.AIRPORT`). Qui ci sono solo le strutture alte, quelle che si vedono
di sbieco come il resto della citta': piste, raccordi e piazzale sono
pavimento e li disegna il gioco (`airport.gd`), come le strade.

Tre unita', tre PNG, allineate lungo il bordo nord dell'aeroporto con la
facciata verso le piste:

  * `hangar_grande` — il capannone a botte di lamiera ondulata, col portone
    scorrevole mezzo aperto e l'interno buio. E' quello davanti a cui si
    ferma l'aereo di linea;
  * `hangar_piccolo` — tetto a capanna, portoni chiusi, una fila di finestre;
  * `torre` — la torre di controllo con la cabina a vetri, sopra alla
    palazzina degli uffici.

Presi dalla foto di un aeroporto regionale, senza verde e senza mezzi: gli
aerei e i furgoni li mette il gioco, e si muovono.

Uso:
  blender --background --factory-startup --python scripts_tools/blender_aeroporto.py
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
import blender_isolato_cinese as ic  # noqa: E402
import blender_grattacieli as gr  # noqa: E402
from blender_cinema_videogiochi import M, PEZZI, bx, finestra, piatto, testo  # noqa: E402

OUT = cv.OUT

# Larghezze in metri: sono i PNG a 22,3 px/m (424, 290, 736 e 169 px).
# Il terminal e la torre sono due unita': la torre e' un fondale a se'.
UNITA = {
    "hangar_grande": 19.0,
    "hangar_piccolo": 13.0,
    "terminal": 33.0,
    "torre": 7.6,
}


def palette():
    cv.palette()
    M["lamiera"] = cv.righe("AE_Lamiera", "#BCC4C8", "#9DA6AB", 0.32, asse="X", frazione=0.28)
    M["lamiera_tetto"] = cv.righe("AE_Lamiera_Tetto", "#A9B1B5", "#8D969B", 0.5, asse="X", frazione=0.3)
    M["lamiera_verde"] = cv.righe("AE_Lamiera_Verde", "#8C9C88", "#76866F", 0.32, asse="X", frazione=0.28)
    M["tetto_verde"] = cv.righe("AE_Tetto_Verde", "#6E7D6A", "#5C6A58", 0.45, asse="Y", frazione=0.25)
    M["portone"] = cv.righe("AE_Portone", "#7C878D", "#66727A", 0.9, asse="X", frazione=0.08)
    M["portone_verde"] = cv.righe("AE_Portone_Verde", "#667562", "#56644F", 0.8, asse="X", frazione=0.08)
    M["buio"] = piatto("AE_Buio", "#1B1F22", 0.95)
    M["pavimento_hangar"] = piatto("AE_Pavimento", "#55595A", 0.9, emissivo="#6A6456", forza=0.15)
    M["arancio"] = piatto("AE_Arancio", "#D66A1E", 0.6)
    M["bianco"] = piatto("AE_Bianco", "#E6E6E0", 0.7)
    M["cemento"] = piatto("AE_Cemento", "#B5AFA3", 0.9)
    M["cemento_scuro"] = piatto("AE_Cemento_Scuro", "#8F897E", 0.9)
    M["vetro_torre"] = piatto("AE_Vetro_Torre", "#3E5A66", 0.15, 0.3, emissivo="#9CC8D8", forza=0.55)
    M["scritta_nera"] = piatto("AE_Scritta_Nera", "#22262A", 0.6)
    M["rosso_luce"] = piatto("AE_Rosso_Luce", "#C8281E", 0.4, emissivo="#FF3A2A", forza=2.5)
    M["antenna"] = piatto("AE_Antenna", "#3A3E42", 0.5, 0.6)
    M["radar"] = piatto("AE_Radar", "#E4E6E2", 0.5, 0.2)
    M["vetro_dt"] = vetro_downtown("AE_Vetro_Terminal", 1.0, 12.0)
    M["vetro_dietro"] = vetro_downtown("AE_Vetro_Uffici", 6.0, 16.0)
    M["cemento_dt"] = cv.righe("AE_Cemento_DT", "#C8C5BD", "#AAA79F", 3.4, asse="Z", frazione=0.08)
    M["montante"] = piatto("AE_Montante", "#D9DEDC", 0.5, 0.3)
    M["pensilina"] = piatto("AE_Pensilina", "#EEEEEA", 0.6)
    M["solare"] = piatto("AE_Solare", "#26323E", 0.25, 0.4)
    M["radar_scuro"] = piatto("AE_Radar_Scuro", "#5A6168", 0.5, 0.4)


def poligono(nome, punti, facce, mat):
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
    PEZZI.append(ob)
    return ob


def botte(nome, x0, x1, y0, y1, z0, alzata, mat, seg=14, chiusa=True):
    """Un tetto a botte: mezza ellisse in sezione (X,Z), estrusa lungo Y. Con
    `chiusa` ha anche le due testate piene."""
    cx, r = (x0 + x1) / 2, (x1 - x0) / 2
    arco = [(cx - r * math.cos(math.pi * i / seg), z0 + alzata * math.sin(math.pi * i / seg))
            for i in range(seg + 1)]
    punti = [(x, y0, z) for x, z in arco] + [(x, y1, z) for x, z in arco]
    n = len(arco)
    facce = [(i, i + 1, n + i + 1, n + i) for i in range(n - 1)]
    if chiusa:
        facce.append(tuple(range(n)))
        facce.append(tuple(range(2 * n - 1, n - 1, -1)))
    return poligono(nome, punti, facce, mat)


def capanna(nome, x0, x1, y0, y1, z0, colmo, mat, sporto=0.3):
    """Tetto a due falde col colmo lungo Y (il timpano guarda la camera)."""
    cx = (x0 + x1) / 2
    a, b = x0 - sporto, x1 + sporto
    punti = [(a, y0 - sporto, z0), (cx, y0 - sporto, colmo), (b, y0 - sporto, z0),
             (a, y1 + sporto, z0), (cx, y1 + sporto, colmo), (b, y1 + sporto, z0)]
    facce = [(0, 1, 4, 3), (1, 2, 5, 4)]
    ob = poligono(nome, punti, facce, mat)
    ob.modifiers.new("spessore", "SOLIDIFY").thickness = 0.12
    return ob


# ----------------------------------------------------------------------
#  le tre unita'
# ----------------------------------------------------------------------

def hangar_grande(w):
    D, H, ALZ = 13.0, 5.5, 3.6
    x0, x1 = 0.0, w
    porta = (2.2, w - 2.2, 5.2)
    PEZZI.append(ic.muro_forato("facciata", x0, x1, 0.0, H, 0.0, 0.3, M["lamiera"],
                                [(porta[0], porta[1], 0.0, porta[2])]))
    bx("lato_sx", x0, x0 + 0.3, 0.3, D, 0.0, H, "lamiera")
    bx("lato_dx", x1 - 0.3, x1, 0.3, D, 0.0, H, "lamiera")
    bx("fondo", x0, x1, D - 0.3, D, 0.0, H, "lamiera")
    botte("tetto", x0 - 0.15, x1 + 0.15, -0.25, D + 0.1, H, ALZ, "lamiera_tetto")
    # La testata a botte sopra al portone: una fascia di lamiera e una
    # finestratura a nastro, come i capannoni della foto.
    bx("architrave", x0, x1, -0.05, 0.3, porta[2], H, "arancio")
    bx("nastro_v", 4.0, w - 4.0, -0.3, -0.26, H + 0.5, H + 1.5, "vetro")
    for i in range(1, 8):
        x = 4.0 + (w - 8.0) * i / 8
        bx("nastro_m%d" % i, x - 0.05, x + 0.05, -0.33, -0.28, H + 0.5, H + 1.5, "infisso")
    testo("scritta", "HANGAR 1", w / 2, -0.34, H + 2.25, 0.62, "scritta_nera")
    # Dentro: buio, col pavimento appena illuminato.
    # Alto quanto il muro e non fino alla botte: ai lati la botte scende, e un
    # volume piu' alto la bucava.
    bx("dentro", x0 + 0.3, x1 - 0.3, 0.3, D - 0.3, 0.02, H - 0.05, "buio")
    bx("pavimento", x0 + 0.3, x1 - 0.3, 0.3, D - 0.3, 0.0, 0.03, "pavimento_hangar")
    # Il portone: pannelli impacchettati ai due lati, il vano aperto in mezzo.
    for s, (a, b) in enumerate(((porta[0], porta[0] + 4.2), (porta[1] - 4.2, porta[1]))):
        for k in range(3):
            pa = a + (b - a) * k / 3
            pb = a + (b - a) * (k + 1) / 3
            y = -0.08 - 0.12 * (k if s == 0 else 2 - k)
            bx("pannello%d_%d" % (s, k), pa, pb, y - 0.1, y, 0.0, porta[2] - 0.05, "portone")
    # Le strisce di pericolo sul bordo del vano.
    for k, x in enumerate((porta[0] + 4.3, porta[1] - 4.5)):
        bx("pericolo%d" % k, x, x + 0.2, -0.12, 0.0, 0.0, porta[2], "arancio")


def hangar_piccolo(w):
    D, H, COLMO = 10.0, 4.6, 6.8
    x0, x1 = 0.0, w
    bx("corpo", x0, x1, 0.0, D, 0.0, H, "lamiera_verde")
    poligono("timpano", [(x0, 0.0, H), (x1, 0.0, H), (w / 2, 0.0, COLMO),
                         (x0, 0.3, H), (x1, 0.3, H), (w / 2, 0.3, COLMO)],
             [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)], "lamiera_verde")
    capanna("tetto", x0, x1, 0.0, D, H - 0.05, COLMO, "tetto_verde")
    # Due portoni chiusi, a doghe orizzontali, e fra i due una porticina.
    for k, (a, b) in enumerate(((0.8, 5.8), (w - 5.8, w - 0.8))):
        bx("portone%d" % k, a, b, -0.12, 0.0, 0.0, 3.9, "portone_verde")
        bx("portone%d_bordo" % k, a - 0.12, b + 0.12, -0.16, -0.1, 3.9, 4.05, "bianco")
        for z in (1.0, 2.0, 3.0):
            bx("portone%d_doga%d" % (k, int(z)), a, b, -0.16, -0.12, z - 0.03, z + 0.03, "infisso")
    bx("porticina", w / 2 - 0.5, w / 2 + 0.5, -0.1, 0.0, 0.0, 2.1, "arancio")
    for k in range(3):
        x = 1.6 + k * 1.5
        # Accese: di notte l'hangar ha la luce di lavoro dentro, e si vede da qui.
        finestra("fin_sx%d" % k, x, x + 1.0, 4.1, 4.45, -0.01, "vetro_acceso")
        finestra("fin_dx%d" % k, w - x - 1.0, w - x, 4.1, 4.45, -0.01, "vetro_acceso")
    testo("scritta", "HANGAR 2", w / 2, -0.04, 5.3, 0.5, "scritta_nera")


def torre(w, animati):
    """La torre di controllo, da sola: fusto alto, cabina a vetri larga, e in
    cima il radar che gira.

    Il radar e' l'unica cosa animata: l'antenna (la barra col suo riflettore)
    sta appesa a un perno sul palo, e l'animazione la fa girare su se' stessa.
    Il palo resta nel disegno; l'antenna va in `animati`."""
    tx0, tx1 = w / 2 - 1.9, w / 2 + 1.9
    ty0, ty1 = 1.0, 4.8
    Z_CAB = 14.0
    bx("fusto", tx0, tx1, ty0, ty1, 0.0, Z_CAB, "cemento")
    bx("zoccolo", tx0 - 0.1, tx1 + 0.1, ty0 - 0.1, ty1, 0.0, 0.6, "cemento_scuro")
    bx("porta", w / 2 - 0.55, w / 2 + 0.55, ty0 - 0.05, ty0, 0.0, 2.3, "vetro")
    for z in (3.4, 6.8, 10.2):
        bx("fusto_fascia%d" % int(z), tx0 - 0.04, tx1 + 0.04, ty0 - 0.04, ty1, z, z + 0.18, "cemento_scuro")
    for z in (4.6, 8.0, 11.4):
        finestra("fusto_fin%d" % int(z), tx0 + 1.3, tx1 - 1.3, z, z + 1.0, ty0 - 0.01, "vetro_acceso")
    bx("cab_base", tx0 - 0.7, tx1 + 0.7, ty0 - 0.7, ty1 + 0.7, Z_CAB, Z_CAB + 0.45, "cemento_scuro")
    # La cabina a vetri: a questa scala si legge la fascia di vetro, coi
    # montanti ogni metro.
    bx("cabina", tx0 - 0.6, tx1 + 0.6, ty0 - 0.6, ty1 + 0.6, Z_CAB + 0.45, Z_CAB + 2.7, "vetro_torre")
    for k in range(6):
        x = tx0 - 0.6 + (tx1 - tx0 + 1.2) * k / 5
        bx("cab_m%d" % k, x - 0.05, x + 0.05, ty0 - 0.66, ty0 - 0.58, Z_CAB + 0.45, Z_CAB + 2.7, "infisso")
    bx("cab_tetto", tx0 - 0.85, tx1 + 0.85, ty0 - 0.85, ty1 + 0.85, Z_CAB + 2.7, Z_CAB + 3.05, "bianco")
    cx, cy = (tx0 + tx1) / 2, (ty0 + ty1) / 2
    z_top = Z_CAB + 3.05
    # Il palo del radar e, accanto, l'antennina con la luce rossa.
    bx("radar_palo", cx - 0.18, cx + 0.18, cy - 0.18, cy + 0.18, z_top, z_top + 1.9, "antenna")
    bx("antenna", tx1 + 0.35, tx1 + 0.45, ty0 - 0.3, ty0 - 0.2, z_top, z_top + 1.6, "antenna")
    bx("luce_rossa", tx1 + 0.28, tx1 + 0.52, ty0 - 0.37, ty0 - 0.13, z_top + 1.6, z_top + 1.84, "rosso_luce")
    # Il radar: la barra lunga dell'antenna e il riflettore curvo davanti,
    # tutto appeso al perno in cima al palo.
    perno = bpy.data.objects.new("radar_perno", None)
    bpy.context.scene.collection.objects.link(perno)
    perno.location = (cx, cy, z_top + 1.9)
    pezzi = []
    # Grande apposta: da quaggiu' e' la cosa che dice "torre di controllo"
    # anche a chi non legge la scritta, e deve vedersi girare.
    bx("radar_mozzo", -0.3, 0.3, -0.3, 0.3, 0.0, 0.4, "antenna", raccolta=pezzi)
    bx("radar_barra", -2.3, 2.3, -0.16, 0.16, 0.4, 1.35, "radar", raccolta=pezzi)
    bx("radar_griglia", -2.2, 2.2, -0.26, -0.16, 0.48, 1.27, "radar_scuro", raccolta=pezzi)
    for k in range(1, 8):
        x = -2.2 + 4.4 * k / 8
        bx("radar_costola%d" % k, x - 0.04, x + 0.04, -0.3, -0.26, 0.48, 1.27, "radar", raccolta=pezzi)
    bx("radar_braccio", -0.07, 0.07, -1.1, -0.26, 0.8, 0.94, "antenna", raccolta=pezzi)
    bx("radar_punta", -0.16, 0.16, -1.3, -1.1, 0.72, 1.02, "rosso_luce", raccolta=pezzi)
    for ob in pezzi:
        ob.parent = perno
    animati.extend(pezzi)
    return perno


def vetro_downtown(nome, seme, alto_m):
    """Il vetro dei grattacieli di DOWNTOWN (`blender_grattacieli.vetro()`):
    blu-grigio, sfumato dal basso in alto, con le righe dei piani, i montanti
    e le finestre che la notte si accendono a caso. Guarda a sud, e la
    maschera lo dice allo shader del riflesso in gioco.

    La sfumatura dei grattacieli va da 0 a 100 m: su un edificio di dodici
    resterebbe tutta scura, quindi qui la si stringe sulla sua altezza."""
    mat = gr.vetro(nome, "#4E6274", "#BCD8EA", "#27323E", 3.4, 90, (16.5, 4.0), gr.SUD, seme=seme)
    for n in mat.node_tree.nodes:
        if n.type == "MAP_RANGE":
            n.inputs["From Max"].default_value = alto_m
    return mat


def terminal(w):
    """Il terminal: due corpi, come i palazzi di DOWNTOWN.

    DAVANTI, il vetro: la sala partenze bassa e lunga con la grande pensilina
    bianca a sbalzo (pannelli solari sopra, pilastri esili sotto), e a destra
    il cubo piu' alto. Il vetro e' quello dei grattacieli, blu-grigio e
    sfumato, e ha la maschera: in gioco il sole ci scorre sopra con l'ora.

    DIETRO, il cemento: un palazzo di uffici piu' alto, con le lesene e i
    nastri di finestre, che spunta sopra alla sala e le da' il peso di un
    edificio vero invece che di una pensilina.
    """
    xs = 21.0                 # dove finisce la sala e comincia il cubo
    H_SALA, H_CUBO = 8.4, 11.2
    P = 4.6                   # quanto sporge la pensilina
    # --- dietro: il palazzo di cemento
    bx0, bx1, by0, by1, H_DIETRO = 2.5, 25.5, 9.0, 16.5, 14.4
    bx("dietro", bx0, bx1, by0, by1, 0.0, H_DIETRO, "cemento_dt")
    bx("dietro_cornice", bx0 - 0.1, bx1 + 0.1, by0 - 0.25, by1, H_DIETRO - 0.3, H_DIETRO + 0.4, "cemento_scuro")
    for k, z in enumerate((9.2, 12.0)):
        bx("dietro_nastro%d" % k, bx0 + 0.3, bx1 - 0.3, by0 - 0.06, by0, z, z + 1.7, "vetro_dietro")
    n = 12
    for i in range(n + 1):
        x = bx0 + (bx1 - bx0) * i / n
        bx("dietro_lesena%d" % i, x - 0.18, x + 0.18, by0 - 0.3, by0, 8.0, H_DIETRO - 0.3, "cemento_dt")
    for k, (a0, b0, c0, d0, h0) in enumerate(((4.0, 7.5, 11.0, 14.0, 1.2), (9.0, 11.0, 12.0, 15.5, 0.9),
                                              (18.0, 22.5, 10.5, 13.0, 1.3), (14.0, 15.0, 14.5, 15.5, 2.4))):
        bx("dietro_macchina%d" % k, a0, b0, c0, d0, H_DIETRO + 0.4, H_DIETRO + 0.4 + h0, "macchina")
    bx("dietro_antenna", 23.0, 23.15, 15.0, 15.15, H_DIETRO + 0.4, H_DIETRO + 3.0, "antenna")
    bx("dietro_luce", 22.95, 23.2, 14.95, 15.2, H_DIETRO + 3.0, H_DIETRO + 3.25, "rosso_luce")
    # --- davanti: la sala e il cubo, pieni di vetro
    bx("sala", 0.0, xs, 0.0, 11.0, 0.0, H_SALA, "vetro_dt")
    bx("cubo", xs, w, -0.9, 11.0, 0.0, H_CUBO, "vetro_dt")
    bx("cubo_tetto", xs - 0.05, w, -1.0, 11.0, H_CUBO - 0.05, H_CUBO + 0.4, "bianco")
    bx("cubo_zoccolo", xs, w, -0.96, -0.9, 0.0, 0.35, "cemento_scuro")
    bx("sala_zoccolo", 0.0, xs, -0.06, 0.0, 0.0, 0.35, "cemento_scuro")
    bx("sala_tetto", 0.0, xs, 0.0, 11.0, H_SALA - 0.05, H_SALA + 0.25, "cemento_scuro")
    for k, (a0, b0, c0, d0) in enumerate(((xs + 1.5, xs + 4.0, 3.0, 5.0), (xs + 6.5, xs + 9.5, 6.5, 8.5),
                                          (xs + 2.0, xs + 3.2, 8.0, 10.0))):
        bx("cubo_macchina%d" % k, a0, b0, c0, d0, H_CUBO + 0.4, H_CUBO + 1.1, "macchina")
    # Montanti sottili, bianchi sporchi: le righe dei piani ce le ha gia' il
    # materiale, qui si marcano solo le campate grandi.
    for nome, a, b, y, z1, passo in (("sala_g", 0.0, xs, 0.0, H_SALA, 3.0), ("cubo_g", xs, w, -0.9, H_CUBO, 2.4)):
        k = int(round((b - a) / passo))
        for i in range(k + 1):
            x = a + (b - a) * i / k
            bx("%s_m%d" % (nome, i), x - 0.07, x + 0.07, y - 0.1, y, 0.35, z1, "montante")
    for k, x in enumerate((4.5, 10.5, 16.5)):
        bx("porta%d" % k, x - 1.2, x + 1.2, -0.12, -0.02, 0.35, 2.7, "vetro")
        bx("porta%d_cornice" % k, x - 1.3, x + 1.3, -0.14, -0.1, 2.7, 2.9, "montante")
    # --- la pensilina
    z_dietro, z_davanti = H_SALA + 0.9, H_SALA + 1.5
    pts = [(0.0, 6.5, z_dietro), (xs + 1.2, 6.5, z_dietro), (xs + 1.2, -P, z_davanti), (0.0, -P, z_davanti)]
    lastra = [(x, y, z) for x, y, z in pts] + [(x, y, z + 0.35) for x, y, z in pts]
    poligono("pensilina", lastra, [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2),
                                    (2, 6, 7, 3), (3, 7, 4, 0)], "pensilina")
    bx("pensilina_bordo", 0.0, xs + 1.2, -P - 0.15, -P + 0.05, z_davanti - 0.25, z_davanti + 0.45, "bianco")
    for r in range(3):
        y0 = -P + 0.8 + r * 3.1
        for c in range(6):
            x0 = 0.9 + c * 3.4
            t = (y0 + P) / (6.5 + P)
            z = z_davanti + (z_dietro - z_davanti) * t + 0.36
            bx("solare%d_%d" % (r, c), x0, x0 + 2.8, y0, y0 + 2.3, z, z + 0.08, "solare")
    # I pilastri a filo del vetro: cosi' la riga di terra resta la facciata,
    # e la pensilina sporge nel vuoto come nella foto.
    for k, x in enumerate((3.0, 7.5, 12.0, 16.5)):
        bx("pilastro%d" % k, x - 0.15, x + 0.15, -0.5, -0.2, 0.0, z_davanti - 0.3, "bianco")
    testo("scritta", "AIRPORT", xs * 0.5, -P - 0.17, z_davanti + 0.1, 0.5, "scritta_nera")


COSTRUTTORI = {"hangar_grande": hangar_grande, "hangar_piccolo": hangar_piccolo, "terminal": terminal}


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
    w = UNITA[chiave]
    animati = []
    perno = None
    if chiave == "torre":
        perno = torre(w, animati)
    else:
        COSTRUTTORI[chiave](w)
    for ob in PEZZI:
        for mod in list(ob.modifiers):
            bpy.context.view_layer.objects.active = ob
            bpy.ops.object.modifier_apply(modifier=mod.name)
    cv.unisci(list(PEZZI), "AE_" + chiave)
    cam = cv.scena()
    # Prima si inquadra e poi si nasconde il radar: l'inquadratura guarda solo
    # quello che si renderizza, e il radar sta piu' in alto di tutto il resto.
    cv.inquadra(cam, 0.0, w)
    for ob in animati:
        ob.hide_render = True
    return animati, perno


# Il radar: un giro intero in sedici pose. Il disegno non si ripete prima del
# giro (il riflettore sta da una parte sola), quindi servono tutte.
FOTOGRAMMI_RADAR = 16


def renderizza():
    os.makedirs(OUT, exist_ok=True)
    sc = bpy.context.scene
    for chiave in UNITA:
        costruisci(chiave)
        sc.render.filepath = os.path.join(OUT, "render_aero_%s.png" % chiave)
        bpy.ops.render.render(write_still=True)
        # Le luci della notte con la versione dei grattacieli, che sa leggere
        # le finestre sorteggiate dal vetro di downtown (vedi `vetro_downtown`).
        gr.modo_luci() if chiave == "terminal" else cv.modo_luci()
        sc.render.filepath = os.path.join(OUT, "luci_aero_%s.png" % chiave)
        bpy.ops.render.render(write_still=True)
        if chiave == "terminal":
            # La maschera del vetro, come per i grattacieli: dice allo shader
            # in gioco dove batte il sole. Si ricostruisce, perche' le luci
            # hanno gia' riscritto i materiali.
            costruisci(chiave)
            gr.modo_vetro()
            sc.render.filepath = os.path.join(OUT, "vetro_aero_%s.png" % chiave)
            bpy.ops.render.render(write_still=True)
        print("AERO", chiave, sc.render.resolution_x, sc.render.resolution_y)
        if chiave != "torre":
            continue
        # Il radar, da solo, col resto in holdout: come il mappamondo del
        # casino'. Senza contorni, perche' il Freestyle disegnerebbe anche i
        # bordi di quello che e' in holdout.
        animati, perno = costruisci(chiave)
        for ob in bpy.data.objects:
            if ob.type in ("MESH", "FONT"):
                ob.is_holdout = ob not in animati
        for ob in animati:
            ob.hide_render = False
        sc.render.use_freestyle = False
        for i in range(FOTOGRAMMI_RADAR):
            perno.rotation_euler = (0, 0, 2 * math.pi * i / FOTOGRAMMI_RADAR)
            sc.render.filepath = os.path.join(OUT, "anim_aero_torre_radar_%02d.png" % i)
            bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    renderizza()
