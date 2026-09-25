"""Costruisce in Blender la stazione degli autobus del COMMERCIAL DISTRICT.

Occupa tutto l'isolato fra LOCK STREET e SEVENTH STREET, sopra MAIN STREET:
l'edificio in fondo, largo quanto l'isolato come la steak house nel suo (656
px, 29,4 m a 22,3 px/m), con la facciata rivolta verso il piazzale; nel
piazzale le banchine con le loro pensiline, fra cui gli autobus vanno e vengono.

Presa da un'illustrazione di una stazione americana di provincia: un corpo
basso di mattoni lungo tutto il lotto, col tetto piano pieno di macchine, e in
mezzo l'atrio piu' alto con la volta a botte, la vetrata ad arco con
l'orologio e l'insegna blu BUS STATION. Davanti alle due ali corre una
pensilina scura con le luci sotto.

**Due disegni e non uno.** Le pensiline delle banchine stanno in mezzo al
piazzale e gli autobus ci passano davanti e dietro: cotte nello stesso PNG
dell'edificio non si potrebbero Y-sortare. Quindi escono a parte
(`render_pensilina_bus.png`), e in gioco se ne mettono due uguali.

Tutto quello che sta a terra — asfalto, banchine, strisce gialle, aiuole — e'
citta', e lo disegna Godot (vedi la nota in cima a `render_buildings.py`).
Niente vegetazione, panchine ne' lampioni: arredo del lotto, non edificio.

## La pensilina e la sua base

La base in gioco e' il piede dei pali, che stanno a meta' banchina: e' il punto
piu' basso del disegno. Il tetto sale di 3,7 m di sprite (83 px) sopra al piede,
e questa misura decide la pianta del piazzale in `city_map.gd` — un autobus
fermo dietro a una pensilina deve stare piu' in alto di tanto, o il tetto gli
passa davanti.

Uso (un pezzo per processo, come la steak house):
  blender --background --factory-startup --python scripts_tools/blender_stazione_bus.py -- stazione
  blender --background --factory-startup --python scripts_tools/blender_stazione_bus.py -- pensilina
  python scripts_tools/import_flats_art.py

Con `-- blend <percorso>` invece di renderizzare salva la scena della stazione
e della pensilina in un .blend, per guardarla in Blender.
"""

import math
import os
import sys

import bpy
from mathutils import Matrix

try:
    HERE = os.path.dirname(os.path.abspath(__file__))
except NameError:
    HERE = os.path.join(os.getcwd(), "scripts_tools")
sys.path.insert(0, HERE)
# Scena, camera, luci, inquadratura e scritte sono quelle del cinema; il
# mattone e i muri forati quelli dell'isolato cinese; tubi, cilindri e tende
# quelli del negozio di bici e della steak house.
import blender_bici as bi  # noqa: E402
import blender_cinema_videogiochi as cv  # noqa: E402
import blender_isolato_cinese as ic  # noqa: E402
import blender_steakhouse as st  # noqa: E402
from blender_cinema_videogiochi import M, PEZZI, bx, piatto, testo  # noqa: E402

OUT = cv.OUT
# Tutto l'isolato, dal marciapiede di LOCK STREET a quello di SEVENTH STREET.
W = 656.0 / cv.PX_PER_METRO
# Nove metri di profondita': da 27 gradi ogni metro ne fa dieci di sprite, e
# a dieci lo sprite non stava fra il piazzale e HILLTOP ROAD.
PROF = 9.0
SP = 0.35                       # spessore dei muri
H = 5.3                         # gronda delle due ali
ZOC = 0.6                       # zoccolo di pietra
PIL = 0.7                       # pilastri d'angolo

# L'atrio in mezzo: piu' alto, sporge dal filo delle ali, e sopra ha la volta.
XC = W / 2
HX0, HX1 = XC - 3.6, XC + 3.6
HY = -0.8                       # quanto sporge verso il piazzale
H_ATRIO = 6.6                   # l'imposta della volta
R_VOLTA = (HX1 - HX0) / 2
# La volta e' ribassata: mezza ellisse alta 2,2 m e non mezzo cerchio alto
# 3,6. Tonda, col tetto delle ali, lo sprite usciva alto 341 px, e fra il
# piazzale e il marciapiede di HILLTOP ROAD ce ne stanno 244.
RIBASSO = 2.2 / R_VOLTA
# E copre solo la parte davanti dell'atrio: da 27 gradi ogni metro di volta in
# profondita' e' mezzo metro di sprite in piu'. Dietro, tetto piano.
VOLTA_FONDO = 4.2
# La vetrata dell'atrio, le porte in basso e l'insegna sopra alle porte.
VETRATA = (HX0 + 0.6, HX1 - 0.6)
VETRATA_Z = 4.3
PORTE = (XC - 1.5, XC + 1.5)
PORTE_Z = 2.5
INSEGNA_Z = (4.55, 5.45)
OROLOGIO_Z = H_ATRIO + 0.95

# La pensilina lungo le ali: alta, per non coprire le vetrine (vedi la nota
# della steak house sulle tende), e con le luci sotto.
PENS_Z = 3.35
PENS_S = 1.5
# Le vetrine delle due ali, fra il pilastro d'angolo e l'atrio: finestroni
# larghi alternati a porte, come la biglietteria e la sala d'attesa.
FIN_Z = (ZOC + 0.2, 2.75)

# La pensilina delle banchine.
PL = 440.0 / cv.PX_PER_METRO    # lunga 19,7 m: la banchina meno un respiro
PH = 3.2                        # altezza del bordo basso del tetto
PY0, PY1 = -1.7, 1.7            # il tetto, avanti e dietro al piede dei pali
PASSO_PALI = 4.0


def palette():
    cv.palette()
    M["mattone"] = ic.mattone("SB_Mattone", "#A5563F", "#8A4533", "#CFC3B4", "#6B4C40",
                              seme=7.0, macchie=0.24)
    M["mattone_lato"] = ic.mattone("SB_Mattone_Lato", "#8A4534", "#733829", "#B5A898",
                                   "#5A3E33", seme=8.0, macchie=0.3)
    M["pietra"] = piatto("SB_Pietra", "#B9B2A4", 0.85)
    M["catrame"] = piatto("SB_Catrame", "#4B4944", 0.97)
    M["zinco"] = cv.righe("SB_Zinco", "#8C9398", "#737A80", 0.55, asse="Y", rough=0.45,
                          frazione=0.08)
    M["zinco_fondo"] = piatto("SB_Zinco_Fondo", "#5E656A", 0.5, 0.6)
    M["nero"] = piatto("SB_Nero", "#1D1E20", 0.7)
    # Il tetto delle pensiline a lamiera grecata: righe chiare e scure lungo la
    # banchina. Piatto e scuro com'era prima, a quaranta metri quadri, usciva
    # una lastra nera senza niente sopra.
    M["tetto_pens"] = cv.righe("SB_Tetto_Pensilina", "#5B6268", "#474D53", 0.9, asse="X",
                               rough=0.55, frazione=0.18)
    # La fascia sul bordo davanti del tetto: la striscia di luce della
    # pensilina. Le lampade vere stanno sotto al tetto e da 27 gradi il tetto
    # le copre: senza questa, di notte la pensilina era un rettangolo spento.
    M["fascia"] = piatto("SB_Fascia", "#C9CDD0", 0.5, 0.3, emissivo="#FFF0C8", forza=0.35)
    M["palo"] = piatto("SB_Palo", "#33383C", 0.45, 0.7)
    M["blu"] = piatto("SB_Blu", "#1F4E8C", 0.5, emissivo="#2A5FA8", forza=0.35)
    M["lettere"] = piatto("SB_Lettere", "#F4F4EE", 0.5, emissivo="#FFFFFF", forza=0.9)
    M["quadrante"] = piatto("SB_Quadrante", "#F2EEE2", 0.5, emissivo="#FFF4D8", forza=0.6)
    M["lancette"] = piatto("SB_Lancette", "#161616", 0.5)
    M["luce"] = piatto("SB_Luce", "#F4E6C0", 0.3, emissivo="#FFE9B0", forza=2.2)
    M["vetro_arco"] = piatto("SB_Vetro_Arco", "#2C3B42", 0.2, emissivo="#E6CD96", forza=0.28)
    M["vetrina"] = ic.trasparente(piatto("SB_Vetrina", "#35403F", 0.10, 0.2,
                                         emissivo="#D1B27A", forza=0.25), 0.3)
    M["vetro_riparo"] = ic.trasparente(piatto("SB_Vetro_Riparo", "#9FB4BA", 0.08, 0.1), 0.25)
    M["interno"] = piatto("SB_Interno", "#8B7A62", 0.92, emissivo="#F0CF92", forza=1.4)
    M["interno_scuro"] = piatto("SB_Interno_Scuro", "#3A342C", 0.95)
    M["pavimento"] = cv.righe("SB_Pavimento", "#9A9284", "#86806F", 0.6, asse="X", frazione=0.06)
    M["banco"] = piatto("SB_Banco", "#5A4130", 0.6)
    M["tabellone"] = piatto("SB_Tabellone", "#141A20", 0.4, emissivo="#F0B040", forza=0.9)


# ----------------------------------------------------------------------
#  la stazione
# ----------------------------------------------------------------------

def aperture_ala(x0, x1):
    """Le aperture di un'ala: finestroni larghi 2,4 m ogni 3,4, e una porta
    ogni tre. Restituisce (finestre, porte) come coppie di x."""
    finestre, porte = [], []
    n = max(1, int((x1 - x0) / 3.4))
    passo = (x1 - x0) / n
    for i in range(n):
        c = x0 + passo * (i + 0.5)
        if i % 3 == 1:
            porte.append((c - 0.7, c + 0.7))
        else:
            finestre.append((c - 1.2, c + 1.2))
    return finestre, porte


def ali():
    """Le due ali basse di mattoni: zoccolo di pietra, pilastri, cornicione,
    tetto piano col parapetto."""
    for nome, a, b in (("sx", 0.0, HX0), ("dx", HX1, W)):
        finestre, porte = aperture_ala(a + PIL, b - 0.2)
        fori = [(p, q, FIN_Z[0], FIN_Z[1]) for p, q in finestre]
        fori += [(p, q, -0.1, 2.6) for p, q in porte]
        PEZZI.append(ic.muro_forato("fac_" + nome, a, b, 0.0, H, 0.0, SP, M["mattone"], fori))
        vetrine(nome, finestre, porte)
        interno(nome, a + 0.3, b - 0.3)
        # Lo zoccolo di pietra, interrotto dalle porte, e il cornicione.
        tagli = sorted(porte)
        x = a
        for k, (p, q) in enumerate(tagli + [(b, b)]):
            if p > x + 0.05:
                bx("zoc_%s%d" % (nome, k), x, p, -0.06, 0.0, 0.0, ZOC, "pietra")
            x = q
        bx("cornice_" + nome, a, b, -0.2, SP + 0.05, H, H + 0.35, "pietra")
        bx("fascia_" + nome, a, b, -0.08, 0.0, H - 0.55, H - 0.4, "pietra")
        pensilina_ala(nome, a + (PIL if nome == "sx" else 0.15), b - (0.15 if nome == "sx" else PIL))
    bx("lato_sx", 0.0, 0.3, SP, PROF, 0.0, H, "mattone_lato")
    bx("lato_dx", W - 0.3, W, SP, PROF, 0.0, H, "mattone_lato")
    bx("fondo", 0.0, W, PROF - 0.3, PROF, 0.0, H, "mattone_lato")
    bx("tetto", 0.3, W - 0.3, SP, PROF - 0.3, H - 0.15, H - 0.05, "catrame")
    for nome, a, b, c, d in (("par_s", 0.0, 0.3, SP, PROF), ("par_d", W - 0.3, W, SP, PROF),
                             ("par_f", 0.0, W, PROF - 0.3, PROF)):
        bx(nome, a, b, c, d, H, H + 0.35, "pietra")
    for nome, a, b in (("pil_sx", 0.0, PIL), ("pil_dx", W - PIL, W)):
        bx(nome, a, b, -0.15, 0.9, 0.0, H + 0.55, "mattone")
        bx(nome + "_cap", a, b, -0.25, 1.0, H + 0.55, H + 0.72, "pietra")


def vetrine(tag, finestre, porte):
    """Vetri e telai: i finestroni divisi in tre, le porte a vetri in due."""
    y = 0.14
    for k, (a, b) in enumerate(finestre):
        nome = "vetr_%s%d" % (tag, k)
        bx(nome, a, b, y - 0.01, y + 0.01, FIN_Z[0], FIN_Z[1], "vetrina")
        for i in range(4):
            x = a + (b - a) * i / 3
            bx("%s_m%d" % (nome, i), x - 0.05, x + 0.05, y - 0.07, y + 0.01,
               FIN_Z[0], FIN_Z[1], "infisso")
        for z in (FIN_Z[0], FIN_Z[1], FIN_Z[1] - 0.55):
            bx("%s_t%d" % (nome, int(z * 100)), a, b, y - 0.07, y + 0.01, z - 0.05, z + 0.05,
               "infisso")
    for k, (a, b) in enumerate(porte):
        nome = "porta_%s%d" % (tag, k)
        bx(nome, a, b, y - 0.01, y + 0.01, 0.0, 2.6, "vetrina")
        for x in (a + 0.05, (a + b) / 2, b - 0.05):
            bx("%s_m%d" % (nome, int(x * 100)), x - 0.05, x + 0.05, y - 0.07, y + 0.01,
               0.0, 2.6, "infisso")
        bx(nome + "_a", a, b, y - 0.07, y + 0.01, 2.2, 2.3, "infisso")
        bx(nome + "_s", a, b, y - 0.07, y + 0.01, 2.5, 2.6, "infisso")


def interno(tag, x0, x1):
    """La sala dietro alle vetrine: pavimento, soffitto, parete di fondo
    accesa, e qualche banco della biglietteria."""
    bx("int_pav_" + tag, x0, x1, SP, 4.8, 0.0, 0.05, "pavimento")
    bx("int_fondo_" + tag, x0, x1, 4.6, 4.8, 0.0, H - 0.2, "interno")
    bx("int_soff_" + tag, x0, x1, SP, 4.8, 3.0, 3.1, "interno_scuro")
    n = max(1, int((x1 - x0) / 3.0))
    for k in range(n):
        x = x0 + (x1 - x0) * (k + 0.5) / n
        bx("banco_%s%d" % (tag, k), x - 0.8, x + 0.8, 3.4, 4.0, 0.0, 1.05, "banco")


def pensilina_ala(tag, x0, x1):
    """La pensilina scura davanti a un'ala, coi puntoni al muro e la fila di
    luci sotto al bordo."""
    bx("pens_" + tag, x0, x1, -PENS_S, 0.0, PENS_Z, PENS_Z + 0.22, "tetto_pens")
    bx("pens_bordo_" + tag, x0, x1, -PENS_S - 0.05, -PENS_S + 0.05, PENS_Z - 0.12,
       PENS_Z + 0.28, "nero")
    n = max(2, int((x1 - x0) / 3.2))
    for i in range(n + 1):
        x = x0 + 0.2 + (x1 - x0 - 0.4) * i / n
        bi.tubo("puntone_%s%d" % (tag, i), (x, 0.0, PENS_Z + 1.0), (x, -PENS_S + 0.1, PENS_Z + 0.22),
                0.035, "nero")
    for i in range(n):
        x = x0 + (x1 - x0) * (i + 0.5) / n
        bx("luce_%s%d" % (tag, i), x - 0.35, x + 0.35, -PENS_S + 0.25, -PENS_S + 0.55,
           PENS_Z - 0.03, PENS_Z, "luce")


def atrio():
    """L'atrio: la scatola di mattoni che sporge, la vetrata grande, le porte,
    l'insegna blu, la volta di zinco con la lunetta di vetro e l'orologio."""
    fronte = ic.muro_forato("atrio_fronte", HX0, HX1, 0.0, H_ATRIO, HY, HY + SP, M["mattone"],
                            [(VETRATA[0], VETRATA[1], 0.0 - 0.1, VETRATA_Z)])
    PEZZI.append(fronte)
    bx("atrio_lato_sx", HX0, HX0 + 0.3, HY + SP, PROF, 0.0, H_ATRIO, "mattone_lato")
    bx("atrio_lato_dx", HX1 - 0.3, HX1, HY + SP, PROF, 0.0, H_ATRIO, "mattone_lato")
    for nome, a, b in (("sx", HX0 - 0.1, HX0 + 0.55), ("dx", HX1 - 0.55, HX1 + 0.1)):
        bx("atrio_pil_" + nome, a, b, HY - 0.15, HY + SP, 0.0, H_ATRIO + 0.2, "pietra")
    bx("atrio_zoc", VETRATA[0], VETRATA[1], HY - 0.05, HY + SP, 0.0, 0.15, "pietra")
    bx("atrio_cornice", HX0 - 0.15, HX1 + 0.15, HY - 0.2, HY + SP + 0.1, H_ATRIO - 0.1,
       H_ATRIO + 0.15, "pietra")

    # La vetrata: montanti ogni 1,2 m, un traverso sopra alle porte, e le
    # porte a vetri in mezzo.
    y = HY + 0.18
    a, b = VETRATA
    bx("vetrata", a, b, y - 0.01, y + 0.01, 0.0, VETRATA_Z, "vetrina")
    n = int(round((b - a) / 1.2))
    for i in range(n + 1):
        x = a + (b - a) * i / n
        bx("vetrata_m%d" % i, x - 0.05, x + 0.05, y - 0.08, y + 0.01, 0.0, VETRATA_Z, "infisso")
    for z in (PORTE_Z, VETRATA_Z - 0.06):
        bx("vetrata_t%d" % int(z * 100), a, b, y - 0.08, y + 0.01, z - 0.05, z + 0.05, "infisso")
    bx("porte_telaio", PORTE[0], PORTE[1], y - 0.1, y - 0.06, PORTE_Z - 0.12, PORTE_Z, "infisso")
    bx("porte_mezzo", XC - 0.04, XC + 0.04, y - 0.1, y - 0.06, 0.0, PORTE_Z, "infisso")

    # L'insegna blu sopra alla vetrata, larga quanto l'atrio.
    z0, z1 = INSEGNA_Z
    bx("insegna", HX0 + 0.3, HX1 - 0.3, HY - 0.28, HY - 0.08, z0, z1, "blu")
    bx("insegna_bordo", HX0 + 0.25, HX1 - 0.25, HY - 0.25, HY - 0.1, z0 - 0.06, z1 + 0.06, "nero")
    testo("insegna_scritta", "BUS STATION", XC, HY - 0.3, (z0 + z1) / 2, 0.58, "lettere")

    # L'atrio dentro: pavimento, fondo acceso, il tabellone delle partenze.
    fondo = 3.4
    bx("atrio_pav", HX0 + 0.3, HX1 - 0.3, HY + SP, fondo, 0.0, 0.05, "pavimento")
    bx("atrio_fondo", HX0 + 0.3, HX1 - 0.3, fondo - 0.15, fondo, 0.0, H_ATRIO, "interno")
    bx("tabellone", XC - 1.6, XC + 1.6, fondo - 0.25, fondo - 0.15, 2.6, 3.5, "tabellone")

    # La volta a botte ribassata: un cilindro lungo la profondita', schiacciato
    # in altezza, meta' dentro alla scatola. Davanti la lunetta di vetro, e
    # nella lunetta l'orologio. Dietro alla volta, il tetto piano dell'atrio.
    for ob in (st.cilindro_y("volta", XC, H_ATRIO, R_VOLTA, HY + 0.2, VOLTA_FONDO, "zinco", PEZZI,
                             lati=48),
               st.cilindro_y("volta_testa", XC, H_ATRIO, R_VOLTA + 0.12, HY - 0.05, HY + 0.2,
                             "pietra", PEZZI, lati=48),
               st.cilindro_y("lunetta", XC, H_ATRIO + 0.02, R_VOLTA - 0.35, HY - 0.1, HY - 0.05,
                             "vetro_arco", PEZZI, lati=48)):
        schiaccia(ob, H_ATRIO)
    bx("atrio_tetto", HX0, HX1, VOLTA_FONDO - 0.2, PROF, H_ATRIO - 0.1, H_ATRIO + 0.05, "catrame")
    bx("atrio_parapetto", HX0, HX1, PROF - 0.3, PROF, H_ATRIO, H_ATRIO + 0.35, "pietra")
    r = R_VOLTA - 0.35
    for i in range(1, 6):
        ang = math.pi * i / 6
        x = XC + math.cos(ang) * r
        z = H_ATRIO + math.sin(ang) * r * RIBASSO
        bi.tubo("raggio%d" % i, (XC, HY - 0.13, H_ATRIO + 0.05), (x, HY - 0.13, z), 0.04, "infisso")
    st.cilindro_y("orologio_bordo", XC, OROLOGIO_Z, 0.62, HY - 0.3, HY - 0.12, "nero", PEZZI, lati=40)
    st.cilindro_y("orologio", XC, OROLOGIO_Z, 0.53, HY - 0.33, HY - 0.3, "quadrante", PEZZI, lati=40)
    # Le dieci e dieci, come in ogni fotografia di un orologio: le ore verso
    # le dieci (in alto a sinistra), i minuti verso le due.
    for nome, ang, lung in (("ore", 150.0, 0.3), ("minuti", 30.0, 0.44)):
        a = math.radians(ang)
        bi.tubo("lancetta_" + nome, (XC, HY - 0.36, OROLOGIO_Z),
                (XC + math.cos(a) * lung, HY - 0.36, OROLOGIO_Z + math.sin(a) * lung), 0.035,
                "lancette")


def schiaccia(ob, z):
    """Schiaccia in altezza una mesh intorno alla quota `z`: il mezzo cerchio
    diventa mezza ellisse, cioe' la volta ribassata."""
    ob.data.transform(Matrix.Translation((0, 0, z)) @ Matrix.Scale(RIBASSO, 4, (0, 0, 1))
                      @ Matrix.Translation((0, 0, -z)))


def tetto():
    """Le macchine sul tetto piano: condizionatori, sfiati, un paio di
    lucernari. Tenute sulla fascia dietro: davanti coprirebbero la gronda."""
    for k, (x, y, w) in enumerate(((2.2, 5.6, 1.4), (4.6, 6.8, 1.1), (7.4, 5.2, 1.4),
                                   (9.6, 7.4, 1.0), (19.4, 5.8, 1.4), (22.0, 7.2, 1.1),
                                   (24.6, 5.4, 1.4), (26.9, 7.0, 1.0))):
        bx("clima%d" % k, x - w / 2, x + w / 2, y - 0.6, y + 0.6, H - 0.05, H + 0.7, "macchina")
        bx("clima%d_griglia" % k, x - w / 2 + 0.15, x + w / 2 - 0.15, y - 0.62, y - 0.6,
           H + 0.12, H + 0.58, "infisso")
    for k, x in enumerate((3.4, 8.5, 20.6, 25.6)):
        bi.tubo("sfiato%d" % k, (x, 7.9, H - 0.05), (x, 7.9, H + 1.1), 0.12, "copertina")
        bx("sfiato%d_cap" % k, x - 0.2, x + 0.2, 7.7, 8.1, H + 1.1, H + 1.2, "copertina")


def costruisci_stazione():
    _pulisci()
    ali()
    atrio()
    tetto()
    cv.unisci(list(PEZZI), "SB_Stazione")
    cam = cv.scena()
    cv.inquadra(cam, 0.0, W)
    return cam


# ----------------------------------------------------------------------
#  la pensilina delle banchine
# ----------------------------------------------------------------------

def costruisci_pensilina():
    """Tetto piano un filo inclinato all'indietro, una fila di pali a meta'
    banchina, le luci sotto, un riparo di vetro dietro ai pali e i due
    cartelli blu appesi alle teste."""
    _pulisci()
    x0, x1 = 0.0, PL
    n = int(round((x1 - x0 - 1.0) / PASSO_PALI))
    pali = [x0 + 0.5 + (x1 - x0 - 1.0) * i / n for i in range(n + 1)]
    for k, x in enumerate(pali):
        bi.tubo("palo%d" % k, (x, 0.0, 0.0), (x, 0.0, PH + 0.1), 0.09, "palo")
        # Il braccio che regge il tetto, avanti e dietro.
        bx("trave%d" % k, x - 0.06, x + 0.06, PY0 + 0.1, PY1 - 0.1, PH - 0.05, PH + 0.12, "palo")
    # Il tetto: una lastra, piu' alta dietro di dieci centimetri, e il bordo
    # davanti che la fa sembrare spessa.
    st.prisma("tetto_pensilina", [(x0, PH + 0.12), (x1, PH + 0.12), (x1, PH + 0.3), (x0, PH + 0.3)],
              PY0, PY1, "tetto_pens", PEZZI)
    bx("tetto_bordo", x0 - 0.03, x1 + 0.03, PY0 - 0.06, PY0 + 0.04, PH + 0.02, PH + 0.36, "fascia")
    bx("tetto_colmo", x0, x1, PY1 - 0.1, PY1, PH + 0.3, PH + 0.42, "tetto_pens")
    # Le luci sotto, una fra ogni coppia di pali.
    for k in range(len(pali) - 1):
        x = (pali[k] + pali[k + 1]) / 2
        bx("luce%d" % k, x - 0.9, x + 0.9, -0.25, 0.25, PH + 0.06, PH + 0.1, "luce")
    # Il riparo: lastre di vetro dietro ai pali, alte due metri, a campate
    # alterne — tutto chiuso sembrerebbe una vetrina.
    for k in range(len(pali) - 1):
        if k % 2 == 1:
            continue
        a, b = pali[k] + 0.12, pali[k + 1] - 0.12
        bx("riparo%d" % k, a, b, 0.35, 0.39, 0.15, 2.2, "vetro_riparo")
        bx("riparo%d_a" % k, a, b, 0.33, 0.41, 2.15, 2.22, "palo")
        bx("riparo%d_b" % k, a, b, 0.33, 0.41, 0.12, 0.18, "palo")
    # I cartelli appesi alle due teste, blu come l'insegna della stazione.
    for k, x in enumerate((x0 + 1.2, x1 - 1.2)):
        bx("cartello%d" % k, x - 0.55, x + 0.55, PY0 + 0.35, PY0 + 0.42, PH - 0.6, PH - 0.05, "blu")
        bx("cartello%d_striscia" % k, x - 0.42, x + 0.42, PY0 + 0.33, PY0 + 0.35, PH - 0.42,
           PH - 0.28, "lettere")
    cv.unisci(list(PEZZI), "SB_Pensilina")
    cam = cv.scena()
    cv.inquadra(cam, x0 - 0.1, x1 + 0.1)
    return cam


# ----------------------------------------------------------------------

def _pulisci():
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


def renderizza(cosa):
    os.makedirs(OUT, exist_ok=True)
    sc = bpy.context.scene
    nome = {"stazione": "stazione_bus", "pensilina": "pensilina_bus"}[cosa]
    if cosa == "stazione":
        costruisci_stazione()
    else:
        costruisci_pensilina()
    sc.render.filepath = os.path.join(OUT, "render_%s.png" % nome)
    bpy.ops.render.render(write_still=True)
    cv.modo_luci()
    sc.render.filepath = os.path.join(OUT, "luci_%s.png" % nome)
    bpy.ops.render.render(write_still=True)
    print("STAZIONE_BUS", cosa, sc.render.resolution_x, sc.render.resolution_y)


def salva_blend(percorso):
    """La stazione e, accanto, la pensilina: per guardarle in Blender."""
    costruisci_stazione()
    stazione = bpy.data.objects["SB_Stazione"]
    testi = [ob for ob in bpy.data.objects if ob.type == "FONT"]
    # Seconda costruzione senza pulire: si tiene la stazione e si aggiunge la
    # pensilina, spostata davanti come starebbe nel piazzale.
    PEZZI.clear()
    tenuti = {stazione.name} | {t.name for t in testi}
    for ob in list(bpy.data.objects):
        if ob.name not in tenuti and ob.type in ("CAMERA", "LIGHT"):
            bpy.data.objects.remove(ob, do_unlink=True)
    x0, x1 = 0.0, PL
    n = int(round((x1 - x0 - 1.0) / PASSO_PALI))
    pali = [x0 + 0.5 + (x1 - x0 - 1.0) * i / n for i in range(n + 1)]
    for k, x in enumerate(pali):
        bi.tubo("palo%d" % k, (x, 0.0, 0.0), (x, 0.0, PH + 0.1), 0.09, "palo")
    st.prisma("tetto_pensilina", [(x0, PH + 0.12), (x1, PH + 0.12), (x1, PH + 0.3), (x0, PH + 0.3)],
              PY0, PY1, "tetto_pens", PEZZI)
    pens = cv.unisci(list(PEZZI), "SB_Pensilina")
    pens.location = ((W - PL) / 2, -12.0, 0.0)
    cv.scena()
    bpy.ops.wm.save_as_mainfile(filepath=percorso)
    print("SALVATO", percorso)


if __name__ == "__main__":
    argomenti = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if argomenti and argomenti[0] == "blend":
        salva_blend(argomenti[1])
    else:
        for cosa in (argomenti or ["stazione", "pensilina"]):
            renderizza(cosa)
