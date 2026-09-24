"""Costruisce in Blender lo stadio di CIVIC CENTER.

UNION PARK: il catino ovale affacciato su EAST STREET, dall'altra parte della
strada rispetto a DOWNTOWN. E' il primo edificio disegnato di CIVIC CENTER,
quindi e' anche il posto dove si decide che aspetto ha il quartiere: palette
`ST_`, stessa inclinazione e stessi contorni di tutto il resto.

## Uno stadio che ci sta dentro a un isolato

Alla scala del gioco — 22,3 px per metro, la scala del personaggio — uno
stadio VERO sarebbe largo cinquemila pixel, cioe' sei isolati: mangerebbe due
strade orizzontali e una verticale, e con loro il traffico, i lampioni e la
griglia dei percorsi. Qui invece il catino e' compresso a 29 x 23 metri e sta
dentro a un isolato solo (x 2800..3456, y 5792..6336, i 656 x 544 px che
restano fra i quattro marciapiedi).

**Si legge come uno stadio per la forma, non per la misura**, ed e' la stessa
scelta che fanno i gestionali: catino ovale, tetto ad anello, pinne verticali
sulla facciata, stemma tondo e quattro torri faro. Nessuna di queste cose ha
bisogno di centocinquanta metri per dire cos'e'.

## Perche' il campo non si vede, e perche' va bene

La camera e' inclinata di 27 gradi come per ogni altro edificio. A quella
inclinazione il tetto vicino copre tutto quello che gli sta dietro sotto una
certa quota: un raggio che parte dal bordo del tetto vicino (y -11,4, z 16,3)
arriva sul lato opposto del catino gia' a sette metri d'altezza. Il prato sta
a zero, quindi **non entra mai nell'inquadratura**.

Per vederlo servirebbe una camera dall'alto, che qui non esiste — e non si
puo' inclinare la camera di questo edificio soltanto, perche' un edificio
ripreso da un'angolazione sua si legge storto accanto ai vicini (e' la stessa
nota che ha il magazzino in `render_buildings.py`).

Quello che si vede attraverso l'apertura del tetto e' **la meta' alta della
gradinata di fondo**, coi suoi seggiolini. Ed e' quella che fa il lavoro: senza
il dentro, un anello chiuso alto quindici metri si legge come un gasometro.

## Il colore non e' quello della foto

La forma viene da uno stadio vero, i colori no: nerazzurro e' la squadra di
quello stadio. Qui la tavolozza e' **granata e crema su cemento caldo**, che
sta insieme al resto della citta' (i marroni di THE FLATS, il beige di
COMMERCIAL DISTRICT) invece di essere un corpo estraneo blu.

## Le regole del quartiere, uguali per tutti

  * camera ortografica inclinata 27 gradi sul solo asse X, nessuna imbardata;
  * 22,3 px per metro, supersampling 4;
  * Freestyle sottile (3,2 e 1,5) e mesh UNITE: mille pezzi sciolti sono mille
    contorni neri, e a questa scala si toccano fra loro;
  * **niente marciapiede, niente verde, niente arredo.** Il marciapiede lo
    disegna `city_ground.gd`, alberi e lampioni li piazza la citta'. Nello
    sprite ci sta solo lo stadio.

Uso headless:

    blender --background --python scripts_tools/blender_stadio.py -- --render

Uso da MCP: `costruisci()` lascia la scena pronta, `renderizza()` sputa i due
scatti in `assets/sprites/buildings/_source/`.
"""

import math
import os
import sys

import bpy
from mathutils import Vector

# ----------------------------------------------------------------------
#  misure
# ----------------------------------------------------------------------

INCLINAZIONE = 27.0
PX_PER_METRO = 22.3
SUPERSAMPLING = 4

FONT = "C:/Windows/Fonts/arialbd.ttf"
COLL_TESTI = "SenzaContorno"

NOME = "UNION PARK"

# Quanti punti ha ogni anello ellittico. 96 e non 48: a 22,3 px/m il catino e'
# largo 650 px, e con 48 lati la curva della facciata si vede spezzata — gli
# spigoli diventano creases e Freestyle ci disegna sopra una riga nera ognuno.
LATI = 96

# --- il catino --------------------------------------------------------
# Semiassi della facciata (la faccia ESTERNA delle pinne).
#
# **Non si scelgono a occhio: li detta l'isolato.** L'ingombro a terra e' il
# basamento, cioe' questi piu' `PODIO_FUORI` — 28,8 x 23,0 m, che a 22,3 px/m
# fanno 642 x 513 px. Nell'isolato fra FURNACE STREET e EAST STREET, tolti i
# quattro marciapiedi, ne restano 656 x 544: ci sta con sette pixel di respiro
# per parte sui fianchi e quindici davanti.
#
# Qui prima c'erano 14,6 e 11,4, presi dalla proporzione di un catino vero: il
# basamento veniva 682 px e sbordava sul marciapiede di EAST STREET, cioe'
# sopra a dove si cammina. In un isolato la misura non la decide la
# proporzione, la decide lo spazio fra i marciapiedi.
A_EXT, B_EXT = 13.7, 10.8
# Il tamburo dietro alle pinne: e' il muro vero, le pinne ci stanno davanti.
A_MURO, B_MURO = 13.0, 10.1
H_MURO = 14.6          # quota di gronda

PODIO_FUORI = 0.7      # quanto il basamento sborda oltre le pinne
H_PODIO = 0.85

PINNE = 92
PINNA_SPESSORE = 0.30
PINNA_SPORGENZA = 0.70
PINNA_Z0 = 1.00

# --- fascia e tetto ---------------------------------------------------
H_FASCIA = 1.50        # la banda crema sopra le pinne
A_TETTO, B_TETTO = 14.3, 11.4       # bordo esterno del tetto
# Bordo interno: l'apertura sul campo. Larga, e non e' una scelta di stile.
# Vista da 27 gradi il tetto e' la superficie che si prende piu' spazio nello
# sprite, e l'apertura e' l'unico buco da cui si vede il DENTRO: con 9,0 x 6,5
# il tetto era una corona larga cinque metri e del catino si vedeva una
# fessura — l'edificio si leggeva come un silo col coperchio.
A_LUCE, B_LUCE = 10.2, 7.7
Z_TETTO_FUORI = 16.30
Z_TETTO_DENTRO = 15.00
SP_TETTO = 0.34
COSTOLE = 28

# --- gradinate --------------------------------------------------------
GRADONI = 11
Z_GRADONE_ALTO = 13.40
Z_GRADONE_BASSO = 1.60
A_GRAD_BASSO, B_GRAD_BASSO = 6.0, 4.1

# --- il fronte --------------------------------------------------------
Z_CANCELLO = (H_PODIO, 5.30)
Z_INSEGNA = (5.50, 6.90)
CANCELLO_MEZZA_X = 5.60
CANCELLO_CAMPATE = 5
# Quanto il corpo d'ingresso SPORGE oltre il punto piu' avanzato del tamburo.
#
# **L'ingresso sporge, non rientra**, ed e' il secondo tentativo. Il primo era
# una rientranza di 45 cm nel tamburo: non si vedeva niente, e per un motivo
# che vale per ogni edificio curvo di questo gioco. Il tamburo e' un'ELLISSE,
# quindi il suo fronte non e' piatto: a cinque metri dalla mezzeria si e' gia'
# ritirato di ottanta centimetri, cioe' piu' della rientranza stessa. La
# vetrata, piatta, finiva dietro al muro al centro e davanti al muro ai bordi —
# nel render si vedevano due strisce di luce agli estremi e in mezzo il muro.
#
# Sporgendo il problema non esiste: la vetrata sta sulla faccia anteriore di un
# corpo che esce dal catino, e davanti non ha piu' niente. In piu' il suo tetto
# piano, visto da 27 gradi, si legge come la pensilina dell'ingresso senza
# doverne aggiungere una — e una pensilina aggiunta, a questa inclinazione,
# farebbe da coperchio proprio a cio' che deve mostrare.
ATRIO_SPORGENZA = 0.95
STEMMA_Z = 10.60
STEMMA_R = 3.40

# --- torri faro -------------------------------------------------------
# Agli angoli del catino e non sui quattro punti cardinali: un palo piantato
# sulla mezzeria del fronte cade davanti allo stemma e glielo taglia in due.
FARI_T = [38.0, 142.0, 218.0, 322.0]
# 20,8 e non 24,6. Il palo deve svettare sul catino — e' quello che da lontano
# dice "stadio" — ma a 24,6 m sopra un tetto alto 16 restavano otto metri e
# mezzo di fusto nudo, cioe' centonovanta pixel di stecco: da lontano si
# leggevano come tralicci dell'alta tensione, non come fari.
Z_FARO = 20.80
PALO_MEZZO = 0.30


# ----------------------------------------------------------------------
#  materiali
# ----------------------------------------------------------------------

def srgb(hexstr, alpha=1.0):
    """Da esadecimale a lineare: i socket colore di Blender vogliono lineare."""
    h = hexstr.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    out.append(alpha)
    return tuple(out)


def _bsdf(mat):
    """Il Principled si cerca per tipo: su una UI non inglese il nome cambia."""
    return next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")


def _set(node, name, value):
    if name in node.inputs:
        try:
            node.inputs[name].default_value = value
        except (TypeError, ValueError):
            pass


def _fresh(name):
    old = bpy.data.materials.get(name)
    if old:
        bpy.data.materials.remove(old)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    return mat


def piatto(name, hexcol, rough=0.90, metal=0.0, emissivo=None, forza=0.0):
    mat = _fresh(name)
    b = _bsdf(mat)
    _set(b, "Base Color", srgb(hexcol))
    _set(b, "Roughness", rough)
    _set(b, "Metallic", metal)
    if emissivo:
        _set(b, "Emission Color", srgb(emissivo))
        _set(b, "Emission Strength", forza)
    return mat


P = {}


def palette():
    """Granata e crema su cemento caldo.

    Non e' la tavolozza della foto ed e' voluto: quello stadio e' nerazzurro
    perche' nerazzurra e' la squadra che ci gioca. Il granata invece sta
    insieme ai marroni di THE FLATS e al beige del quartiere commerciale, e da
    lontano lo stadio si legge come un pezzo di questa citta'.
    """
    P.clear()
    P["cemento"] = piatto("ST_Cemento", "#9A948A", rough=0.93)
    P["cemento_scuro"] = piatto("ST_Cemento_Scuro", "#7A746B", rough=0.94)
    # Il tamburo dietro alle pinne porta un'emissione bassa e calda, e non e'
    # un effetto: e' il modo in cui lo stadio di riferimento si illumina, con
    # i proiettori NASCOSTI dietro al rivestimento. Di notte `modo_luci()`
    # rende il tamburo e lascia nere le pinne, che gli stanno davanti: viene
    # fuori la rigatura verticale controluce, cioe' la facciata che si accende.
    # Senza, di notte lo stadio e' una sagoma nera con quattro fari sopra.
    # `forza` bassa perche' di GIORNO non si deve vedere: il colore lo decide
    # la notte, la forza decide quanto sporca il giorno.
    P["muro"] = piatto("ST_Rivestimento", "#3C322E", rough=0.88,
                       emissivo="#6B4028", forza=0.22)
    P["pinna"] = piatto("ST_Pinna", "#8E443C", rough=0.80)
    P["pinna_scura"] = piatto("ST_Pinna_Scura", "#6E342E", rough=0.82)
    P["crema"] = piatto("ST_Crema", "#C9BCA4", rough=0.84)
    # Il crema dello stemma e' illuminato, quello delle cornici no. Di notte
    # uno stemma spento e' un disco nero in mezzo alla facciata accesa, cioe'
    # un buco: gli stemmi degli stadi veri sono la prima cosa che si accende.
    P["crema_acceso"] = piatto("ST_Crema_Acceso", "#C9BCA4", rough=0.84,
                               emissivo="#A89878", forza=0.45)
    # La banda crema di gronda prende un filo di emissione: di notte e' la
    # riga che dice dove finisce il catino, e spenta del tutto lo stadio
    # diventa una macchia nera con quattro lampioni sopra.
    P["fascia"] = piatto("ST_Fascia", "#C9BCA4", rough=0.84,
                         emissivo="#8A7A5E", forza=0.35)
    # Il dorso del tetto e' la superficie piu' grande dello sprite: a 27 gradi
    # si prende un terzo dell'immagine. A #4E5154 era una macchia nera larga
    # seicento pixel e lo stadio si leggeva come un barile col coperchio. Una
    # guaina vera, vista dall'alto e in pieno sole, e' chiara.
    P["tetto"] = piatto("ST_Tetto", "#7E807C", rough=0.90)
    P["costola"] = piatto("ST_Costola", "#9C9E98", rough=0.80)
    P["acciaio"] = piatto("ST_Acciaio", "#9BA3A8", rough=0.40, metal=0.80)
    P["seggiolino"] = piatto("ST_Seggiolino", "#8E443C", rough=0.78)
    P["seggiolino_b"] = piatto("ST_Seggiolino_B", "#C9BCA4", rough=0.78)
    P["erba"] = piatto("ST_Erba", "#4A7638", rough=0.95)
    P["erba_b"] = piatto("ST_Erba_B", "#3F6A30", rough=0.95)
    P["linee"] = piatto("ST_Linee", "#D8DCD2", rough=0.88)
    # --- quello che di notte resta acceso -------------------------------
    # Non c'e' un elenco di cosa si accende: si accende quello che il modello
    # dichiara emissivo, ed e' lo stesso dato che di giorno lo fa piu' chiaro
    # del resto. Vedi `modo_luci()`.
    # `forza` tara il GIORNO, il colore tara la NOTTE: `modo_luci()` rende
    # l'emissione a forza 1.0 fissa e legge solo il colore. Quindi si abbassa
    # la forza finche' di giorno il vetro torna vetro, senza toccare la notte.
    # A 1,6 le ante dell'ingresso erano cinque rettangoli di luce piatta anche
    # a mezzogiorno: un lightbox, non una vetrata.
    P["vetro"] = piatto("ST_Vetro", "#6B5F4C", rough=0.18, metal=0.15,
                        emissivo="#E8C98A", forza=0.45)
    P["accento"] = piatto("ST_Accento", "#8A6A3A", rough=0.60,
                          emissivo="#E8B268", forza=0.70)
    P["faro"] = piatto("ST_Faro", "#E8E2CE", rough=0.30,
                       emissivo="#FFF2D0", forza=3.2)
    P["insegna"] = piatto("ST_Insegna", "#D8D2C4", rough=0.55,
                          emissivo="#D8D2C4", forza=0.9)
    return P


# ----------------------------------------------------------------------
#  primitive
# ----------------------------------------------------------------------

def pulisci():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for blocco in (bpy.data.meshes, bpy.data.curves, bpy.data.materials,
                   bpy.data.lights, bpy.data.cameras, bpy.data.collections):
        for dato in list(blocco):
            if dato.users == 0:
                blocco.remove(dato)


def collezione(nome):
    c = bpy.data.collections.get(nome)
    if c is None:
        c = bpy.data.collections.new(nome)
        bpy.context.scene.collection.children.link(c)
    return c


def box(nome, centro, misure, materiale=None, rot=None):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=centro)
    ob = bpy.context.active_object
    ob.name = nome
    ob.scale = misure
    if rot:
        ob.rotation_euler = rot
    bpy.ops.object.transform_apply(location=False, rotation=bool(rot),
                                   scale=True)
    if materiale:
        ob.data.materials.append(materiale)
    return ob


def bx(nome, x0, x1, y0, y1, z0, z1, materiale=None):
    """Scatola dagli estremi: una facciata si legge per estremi, non per centro."""
    return box(nome, ((x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0),
               (abs(x1 - x0), abs(y1 - y0), abs(z1 - z0)), materiale)


def cilindro(nome, centro, raggio, altezza, materiale=None, lati=16, rot=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=lati, radius=raggio,
                                        depth=altezza, location=centro)
    ob = bpy.context.active_object
    ob.name = nome
    if rot:
        ob.rotation_euler = rot
        bpy.ops.object.transform_apply(location=False, rotation=True,
                                       scale=False)
    if materiale:
        ob.data.materials.append(materiale)
    return ob


def mesh_da(nome, punti, facce, materiale=None):
    me = bpy.data.meshes.new(nome)
    me.from_pydata([Vector(p) for p in punti], [], facce)
    me.update()
    ob = bpy.data.objects.new(nome, me)
    bpy.context.scene.collection.objects.link(ob)
    if materiale:
        ob.data.materials.append(materiale)
    return ob


def unisci(pezzi, nome):
    """Unisce e riporta l'origine a (0,0,0).

    Il Freestyle disegna la silhouette di ogni OGGETTO: novantadue pinne
    sciolte sono novantadue contorni neri, e a 22,3 px/m una pinna e' larga
    sette pixel — i contorni si toccherebbero e la facciata verrebbe fuori
    nera. Unite, il contorno gira solo intorno allo stadio.
    """
    pezzi = [p for p in pezzi if p and p.name in bpy.data.objects]
    if not pezzi:
        return None
    bpy.ops.object.select_all(action="DESELECT")
    for p in pezzi:
        p.select_set(True)
    bpy.context.view_layer.objects.active = pezzi[0]
    if len(pezzi) > 1:
        bpy.ops.object.join()
    ob = bpy.context.active_object
    ob.name = nome
    bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    bpy.ops.object.select_all(action="DESELECT")
    return ob


def scritta(nome, testo, x, y, z, altezza, materiale, estrusione=0.04,
            allinea="CENTER"):
    """Testo vero estruso, fuori dal Freestyle.

    Una lettera alta venti pixel con intorno un contorno nero da tre non e'
    piu' una lettera: le scritte stanno in una collezione che le due linee
    saltano.
    """
    curva = bpy.data.curves.new(nome, type="FONT")
    curva.body = testo
    curva.align_x = allinea
    curva.align_y = "CENTER"
    curva.extrude = estrusione
    try:
        curva.font = bpy.data.fonts.load(FONT, check_existing=True)
    except RuntimeError:
        pass
    ob = bpy.data.objects.new(nome, curva)
    collezione(COLL_TESTI).objects.link(ob)
    if materiale:
        ob.data.materials.append(materiale)
    # La misura si prende sulla copia VALUTATA: `dimensions` di un testo appena
    # creato e' ancora il riquadro vuoto, e scalando su quello le insegne
    # escono cinque volte troppo grandi.
    dg = bpy.context.evaluated_depsgraph_get()
    dg.update()
    alta = max(ob.evaluated_get(dg).dimensions.y, 1e-4)
    curva.size = altezza / alta
    ob.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    ob.location = (x, y, z)
    return ob


# ----------------------------------------------------------------------
#  anelli ellittici
# ----------------------------------------------------------------------
#
# Tutto il catino — facciata, fascia, tetto, gradoni — e' una pila di ANELLI
# fra due ellissi. Costruirli come bande di quad invece che come scatole non
# e' un vezzo: una scatola per gradone per settore sarebbero duemila oggetti,
# e ogni spigolo in piu' e' una riga nera di Freestyle sulla curva.

def anello_punti(a, b, z, fase=0.0):
    return [(a * math.cos(t + fase), b * math.sin(t + fase), z)
            for t in (2.0 * math.pi * i / LATI for i in range(LATI))]


def banda(nome, giu, su, materiale, verso_fuori=True):
    """La superficie fra due anelli con lo stesso numero di punti.

    `verso_fuori` gira le normali: un anello con le normali dalla parte
    sbagliata, in EEVEE con le ombre accese, si illumina al contrario e si
    legge come un buco.
    """
    n = len(giu)
    punti = list(giu) + list(su)
    facce = []
    for i in range(n):
        j = (i + 1) % n
        if verso_fuori:
            facce.append((i, j, n + j, n + i))
        else:
            facce.append((j, i, n + i, n + j))
    return mesh_da(nome, punti, facce, materiale)


def tappo(nome, bordo_a, bordo_b, materiale, verso_su=True):
    """Chiude la corona fra due anelli alla stessa quota (o quasi)."""
    return banda(nome, bordo_a, bordo_b, materiale, verso_fuori=not verso_su)


def normale(a, b, t):
    """L'angolo della normale uscente dell'ellisse nel punto `t`.

    Non e' `t`: su un'ellisse la normale non passa per il centro, e le pinne
    orientate su `t` verrebbero fuori storte sui fianchi, dove la curvatura e'
    massima. E' li' che si vedrebbe.
    """
    return math.atan2(a * math.sin(t), b * math.cos(t))


# ----------------------------------------------------------------------
#  i pezzi
# ----------------------------------------------------------------------

def podio(pezzi):
    """Il basamento su cui poggia il catino.

    Non e' un marciapiede: il marciapiede lo disegna la citta'. E' lo zoccolo
    dello stadio, quello che in una piazza vera ci separa dal terreno, e sborda
    settanta centimetri oltre le pinne perche' un catino che nasce a filo del
    suolo sembra appoggiato invece che costruito.
    """
    a, b = A_EXT + PODIO_FUORI, B_EXT + PODIO_FUORI
    pezzi.append(banda("ST_podio_fianco", anello_punti(a, b, 0.0),
                       anello_punti(a, b, H_PODIO), P["cemento"]))
    pezzi.append(tappo("ST_podio_sopra", anello_punti(a, b, H_PODIO),
                       anello_punti(A_MURO, B_MURO, H_PODIO),
                       P["cemento_scuro"]))


def facciata(pezzi):
    """Il tamburo scuro e le pinne granata che ci stanno davanti.

    **Le pinne sono geometria, non una texture.** A 22,3 px/m una pinna e'
    larga sette pixel e ne sporge quindici: sono loro a prendere il sole su un
    lato e l'ombra sull'altro, ed e' quel rigato che fa leggere la curva del
    catino. Dipinte su un muro piatto la facciata resta un cilindro liscio e
    la curva sparisce.
    """
    pezzi.append(banda("ST_muro", anello_punti(A_MURO, B_MURO, H_PODIO),
                       anello_punti(A_MURO, B_MURO, H_MURO), P["muro"]))

    punti, facce = [], []
    for i in range(PINNE):
        t = 2.0 * math.pi * i / PINNE
        cx, cy = A_MURO * math.cos(t), B_MURO * math.sin(t)
        ang = normale(A_MURO, B_MURO, t)
        nx, ny = math.cos(ang), math.sin(ang)
        # tangente: la pinna e' larga lungo il bordo, non lungo il raggio
        tx, ty = -ny, nx
        # Davanti al cancello le pinne cominciano sopra all'insegna: una pinna
        # che scende fino a terra attraverserebbe l'ingresso, e un ingresso
        # sbarrato da una grata non e' un ingresso.
        davanti = cy < 0.0 and abs(cx) < CANCELLO_MEZZA_X + 0.6
        z0 = Z_INSEGNA[1] + 0.30 if davanti else PINNA_Z0
        z1 = H_MURO - 0.20
        hs = PINNA_SPESSORE / 2.0
        base = len(punti)
        for dz in (z0, z1):
            for dr, dt in ((0.0, -hs), (PINNA_SPORGENZA, -hs),
                           (PINNA_SPORGENZA, hs), (0.0, hs)):
                punti.append((cx + nx * dr + tx * dt,
                              cy + ny * dr + ty * dt, dz))
        facce += [
            (base + 0, base + 1, base + 2, base + 3),
            (base + 7, base + 6, base + 5, base + 4),
            (base + 0, base + 4, base + 5, base + 1),
            (base + 1, base + 5, base + 6, base + 2),
            (base + 2, base + 6, base + 7, base + 3),
            (base + 3, base + 7, base + 4, base + 0),
        ]
    pezzi.append(mesh_da("ST_pinne", punti, facce, P["pinna"]))

    # La riga di luce alla base delle pinne. E' l'unica cosa che di notte
    # disegna la CURVA del catino: i fari illuminano il cielo, la fascia di
    # gronda e' una riga sola in cima, e senza questa lo stadio di notte e' una
    # sagoma nera. Vedi `modo_luci()`.
    pezzi.append(banda("ST_accento",
                       anello_punti(A_MURO + 0.06, B_MURO + 0.06, PINNA_Z0 - 0.45),
                       anello_punti(A_MURO + 0.06, B_MURO + 0.06, PINNA_Z0),
                       P["accento"]))


def gronda(pezzi):
    """La fascia crema sopra le pinne e il tetto ad anello.

    La fascia non e' decorazione: e' la riga orizzontale che chiude in alto
    quindici metri di rigatura verticale. Senza, le pinne finiscono nel nulla e
    il catino si legge come una palizzata.
    """
    a1, b1 = A_EXT + 0.10, B_EXT + 0.10
    pezzi.append(banda("ST_fascia", anello_punti(a1, b1, H_MURO),
                       anello_punti(a1, b1, H_MURO + H_FASCIA), P["fascia"]))

    fuori_su = anello_punti(A_TETTO, B_TETTO, Z_TETTO_FUORI)
    dentro_su = anello_punti(A_LUCE, B_LUCE, Z_TETTO_DENTRO)
    fuori_giu = anello_punti(A_TETTO, B_TETTO, Z_TETTO_FUORI - SP_TETTO)
    dentro_giu = anello_punti(A_LUCE, B_LUCE, Z_TETTO_DENTRO - SP_TETTO)

    pezzi.append(tappo("ST_tetto_sopra", fuori_su, dentro_su, P["tetto"]))
    pezzi.append(tappo("ST_tetto_sotto", fuori_giu, dentro_giu, P["cemento_scuro"],
                       verso_su=False))
    pezzi.append(banda("ST_tetto_bordo", fuori_giu, fuori_su, P["crema"]))
    pezzi.append(banda("ST_tetto_luce", dentro_giu, dentro_su, P["crema"],
                       verso_fuori=False))
    # Il raccordo fra la fascia e il bordo del tetto: senza, il tetto resta a
    # mezz'aria sopra al catino e si vede il vuoto fra i due.
    pezzi.append(banda("ST_gronda_sotto",
                       anello_punti(a1, b1, H_MURO + H_FASCIA),
                       anello_punti(A_TETTO, B_TETTO, Z_TETTO_FUORI - SP_TETTO),
                       P["cemento_scuro"]))

    # Le costole radiali sul dorso. Il tetto e' la superficie piu' grande e
    # piatta dello sprite, e vista da 27 gradi e' anche quella che si prende
    # piu' spazio: liscia e' una macchia grigia larga seicento pixel.
    #
    # **Seguono la pendenza.** Prima erano scatole orizzontali piazzate alla
    # quota media fra il bordo esterno e quello interno: il tetto pero'
    # scende di 1,30 m verso il campo, quindi meta' di ogni costola sprofondava
    # nella guaina e meta' galleggiava sopra. Ne restavano dei trattini
    # sparsi — che e' peggio del tetto liscio, perche' sembra sporcizia invece
    # che struttura.
    dz = Z_TETTO_FUORI - Z_TETTO_DENTRO
    for i in range(COSTOLE):
        t = 2.0 * math.pi * i / COSTOLE
        xa, ya = A_TETTO * math.cos(t), B_TETTO * math.sin(t)
        xb, yb = A_LUCE * math.cos(t), B_LUCE * math.sin(t)
        mx, my = (xa + xb) / 2.0, (ya + yb) / 2.0
        lun = math.hypot(xa - xb, ya - yb)
        # Euler XYZ vale Rz @ Ry @ Rx: la Y inclina la costola lungo la sua
        # lunghezza, la Z la punta nella direzione radiale. Segno negativo
        # perche' con Ry positiva il +X locale scenderebbe invece di salire, e
        # la costola verrebbe inclinata dalla parte sbagliata.
        pezzi.append(box("ST_costola%d" % i,
                         (mx, my, (Z_TETTO_FUORI + Z_TETTO_DENTRO) / 2.0 + 0.14),
                         (math.hypot(lun, dz), 0.34, 0.22), P["costola"],
                         rot=(0.0, -math.atan2(dz, lun),
                              math.atan2(ya - yb, xa - xb))))


def gradinate(pezzi):
    """Il dentro: la meta' alta della gradinata di fondo, che e' cio' che si vede.

    Il tetto vicino copre tutto quello che gli sta dietro sotto i sette metri
    (vedi la nota in cima), quindi i gradoni bassi e il prato non entrano mai
    nell'inquadratura. Si costruiscono lo stesso, e per due motivi: da soli
    costano poche facce, e il giorno in cui la camera cambiasse non ci sarebbe
    un catino vuoto da riempire.

    I seggiolini vanno a FASCE di tre gradoni e non a scacchiera: a 22,3 px/m
    un gradone e' alto ventiquattro pixel, e una scacchiera a quella misura si
    legge come rumore. Tre gradoni granata e tre crema si leggono come i
    settori di uno stadio.
    """
    for i in range(GRADONI):
        f0 = i / float(GRADONI)
        f1 = (i + 1) / float(GRADONI)
        z0 = Z_GRADONE_ALTO + (Z_GRADONE_BASSO - Z_GRADONE_ALTO) * f0
        z1 = Z_GRADONE_ALTO + (Z_GRADONE_BASSO - Z_GRADONE_ALTO) * f1
        a0 = A_LUCE + (A_GRAD_BASSO - A_LUCE) * f0
        b0 = B_LUCE + (B_GRAD_BASSO - B_LUCE) * f0
        a1 = A_LUCE + (A_GRAD_BASSO - A_LUCE) * f1
        b1 = B_LUCE + (B_GRAD_BASSO - B_LUCE) * f1
        mat = P["seggiolino"] if (i // 3) % 2 == 0 else P["seggiolino_b"]
        # l'alzata, vista dal campo
        pezzi.append(banda("ST_alzata%d" % i, anello_punti(a0, b0, z1),
                           anello_punti(a0, b0, z0), mat, verso_fuori=False))
        # la pedata
        pezzi.append(tappo("ST_pedata%d" % i, anello_punti(a0, b0, z1),
                           anello_punti(a1, b1, z1), P["cemento_scuro"]))


def campo(pezzi):
    """Il prato. Non si vede, e si fa comunque: costa otto facce.

    Le righe della rasatura sono geometria e non una texture perche' a questa
    scala una texture su una superficie che non si vede e' lavoro buttato due
    volte.
    """
    lx, ly = A_GRAD_BASSO - 0.5, B_GRAD_BASSO - 0.5
    strisce = 8
    for i in range(strisce):
        x0 = -lx + 2.0 * lx * i / strisce
        x1 = -lx + 2.0 * lx * (i + 1) / strisce
        pezzi.append(bx("ST_erba%d" % i, x0, x1, -ly, ly, 0.0, 0.14,
                        P["erba"] if i % 2 == 0 else P["erba_b"]))
    pezzi.append(bx("ST_linea_mezzo", -0.06, 0.06, -ly, ly, 0.14, 0.16,
                    P["linee"]))
    pezzi.append(cilindro("ST_cerchio", (0, 0, 0.15), 1.5, 0.02, P["linee"],
                          lati=24))


def fronte(pezzi):
    """Il cancello, l'insegna e lo stemma tondo.

    Sono le tre cose che dicono che quello e' uno stadio e non un deposito
    cilindrico, e stanno impilate sul fronte in quest'ordine: si entra in
    basso, il nome sta sopra la porta, lo stemma domina la facciata. E' la
    gerarchia di uno stadio vero, e da lontano si legge dal basso verso l'alto.
    """
    yf = -B_MURO
    ya = yf - ATRIO_SPORGENZA           # la faccia anteriore dell'ingresso

    # --- il corpo dell'ingresso -----------------------------------------
    z0, z1 = Z_CANCELLO
    x0, x1 = -CANCELLO_MEZZA_X, CANCELLO_MEZZA_X
    # Il corpo entra nel tamburo di 60 cm: alle sue x il tamburo si e' gia'
    # ritirato di ottanta, quindi senza quel rientro i due volumi non si
    # toccherebbero e l'ingresso resterebbe staccato dal catino.
    pezzi.append(bx("ST_atrio", x0, x1, ya, yf + 0.60, z0, z1,
                    P["cemento_scuro"]))
    # Il bordo del tetto piano dell'atrio: e' la riga che, vista da 27 gradi,
    # lo fa leggere come pensilina invece che come scatola.
    pezzi.append(bx("ST_atrio_cornice", x0 - 0.18, x1 + 0.18, ya - 0.14,
                    yf + 0.60, z1, z1 + 0.20, P["crema"]))

    # Vetrata e montanti sulla STESSA griglia di campate. Presi da due conti
    # diversi non combaciavano, e i montanti cadevano in mezzo alle ante.
    passo = (x1 - x0) / CANCELLO_CAMPATE
    for i in range(CANCELLO_CAMPATE):
        pezzi.append(bx("ST_anta%d" % i, x0 + passo * i + 0.16,
                        x0 + passo * (i + 1) - 0.16, ya - 0.04, ya + 0.12,
                        z0 + 0.22, z1 - 0.34, P["vetro"]))
    for i in range(CANCELLO_CAMPATE + 1):
        px = x0 + passo * i
        pezzi.append(bx("ST_montante%d" % i, px - 0.13, px + 0.13, ya - 0.16,
                        ya + 0.02, z0, z1 - 0.20, P["acciaio"]))

    # --- la banda dell'insegna ------------------------------------------
    iz0, iz1 = Z_INSEGNA
    pezzi.append(bx("ST_banda", x0 - 0.60, x1 + 0.60, yf - 0.30, yf + 0.05,
                    iz0, iz1, P["crema"]))
    scritta("ST_nome", NOME, 0.0, yf - 0.36, (iz0 + iz1) / 2.0, 0.80,
            P["insegna"])

    # --- lo stemma ------------------------------------------------------
    # Grande: quasi sette metri, mezza facciata. Uno stemma piccolo e centrato
    # si legge come un orologio; uno che occupa mezza facciata si legge come
    # l'identita' dell'edificio, ed e' cosi' anche sullo stadio di riferimento.
    ys_st = yf - PINNA_SPORGENZA - 0.10
    pezzi.append(cilindro("ST_stemma_bordo", (0.0, ys_st - 0.16, STEMMA_Z),
                          STEMMA_R, 0.32, P["crema_acceso"], lati=48,
                          rot=(math.radians(90.0), 0.0, 0.0)))
    pezzi.append(cilindro("ST_stemma_campo", (0.0, ys_st - 0.34, STEMMA_Z),
                          STEMMA_R - 0.45, 0.22, P["pinna_scura"], lati=48,
                          rot=(math.radians(90.0), 0.0, 0.0)))
    scritta("ST_stemma_lettera", "U", 0.0, ys_st - 0.50, STEMMA_Z + 0.45, 2.60,
            P["insegna"])
    scritta("ST_stemma_anno", "1904", 0.0, ys_st - 0.50, STEMMA_Z - 1.85, 0.70,
            P["insegna"])


def fari(pezzi):
    """Le quattro torri faro.

    Sono la parte che si vede da lontano: il catino e' alto sedici metri come
    un palazzo di cinque piani e da mezza citta' non si distingue da un
    palazzo. I pali a venticinque no — sono l'unica cosa in giro che fa quella
    sagoma, e sono quello che dice "stadio" prima ancora che si legga
    l'insegna.
    """
    for gradi in FARI_T:
        t = math.radians(gradi)
        x, y = (A_TETTO - 0.8) * math.cos(t), (B_TETTO - 0.8) * math.sin(t)
        pezzi.append(bx("ST_palo_%d" % gradi, x - PALO_MEZZO, x + PALO_MEZZO,
                        y - PALO_MEZZO, y + PALO_MEZZO, Z_TETTO_FUORI - 1.0,
                        Z_FARO, P["acciaio"]))
        # La traversa guarda il campo: e' verso il centro che punta un faro.
        ang = math.atan2(-y, -x)
        pezzi.append(box("ST_traversa_%d" % gradi, (x, y, Z_FARO + 0.25),
                         (2.80, 0.30, 0.34), P["acciaio"],
                         rot=(0.0, 0.0, ang + math.pi / 2.0)))
        for k in range(6):
            d = -1.15 + 2.30 * k / 5.0
            lx = x + math.cos(ang + math.pi / 2.0) * d
            ly = y + math.sin(ang + math.pi / 2.0) * d
            pezzi.append(box("ST_lampada_%d_%d" % (gradi, k),
                             (lx, ly, Z_FARO + 0.62),
                             (0.34, 0.30, 0.40), P["faro"],
                             rot=(0.0, 0.0, ang)))


# ----------------------------------------------------------------------
#  scena, luci, camera
# ----------------------------------------------------------------------

def scena():
    sc = bpy.context.scene
    sc.unit_settings.system = "METRIC"

    dati = bpy.data.cameras.new("CAM_Front")
    dati.type = "ORTHO"
    dati.clip_start, dati.clip_end = 0.1, 500.0
    cam = bpy.data.objects.new("CAM_Front", dati)
    sc.collection.objects.link(cam)
    # Solo rotazione X: nessuna imbardata, la facciata resta dritta.
    cam.rotation_euler = (math.radians(90.0 - INCLINAZIONE), 0.0, 0.0)
    sc.camera = cam

    sole = bpy.data.lights.new("SUN", type="SUN")
    sole.energy = 3.2
    sole.color = (1.0, 0.95, 0.88)
    sole.angle = math.radians(1.0)
    ob = bpy.data.objects.new("SUN", sole)
    sc.collection.objects.link(ob)
    ob.rotation_euler = (math.radians(58), 0.0, math.radians(-46))

    riemp = bpy.data.lights.new("FILL", type="SUN")
    riemp.energy = 1.05
    riemp.color = (0.70, 0.78, 0.94)
    riemp.angle = math.radians(30)
    ob = bpy.data.objects.new("FILL", riemp)
    sc.collection.objects.link(ob)
    ob.rotation_euler = (math.radians(108), 0.0, math.radians(30))

    mondo = bpy.data.worlds.new("World")
    sc.world = mondo
    mondo.use_nodes = True
    N, L = mondo.node_tree.nodes, mondo.node_tree.links
    N.clear()
    uscita = N.new("ShaderNodeOutputWorld")
    sfondo = N.new("ShaderNodeBackground")
    sfondo.inputs["Color"].default_value = srgb("#8FA3B6")
    _set(sfondo, "Strength", 0.95)
    L.new(sfondo.outputs["Background"], uscita.inputs["Surface"])

    # `engine` e' un enum dinamico e RNA lo sotto-riporta: si prova e si
    # guarda l'eccezione, invece di leggere una lista che non contiene i motori
    # registrati dagli add-on.
    for motore in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
        try:
            sc.render.engine = motore
            break
        except TypeError:
            continue
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    for attr, val in [("taa_render_samples", 128), ("use_raytracing", True),
                      ("use_shadows", True), ("shadow_ray_count", 2),
                      ("shadow_step_count", 6)]:
        if hasattr(sc.eevee, attr):
            try:
                setattr(sc.eevee, attr, val)
            except (AttributeError, TypeError):
                pass
    # Standard e non AgX: AgX e' fatto per il fotorealismo e sbiadisce i colori
    # piatti, e a questa scala il granata diventerebbe rosa.
    sc.view_settings.view_transform = "Standard"

    sc.render.use_freestyle = True
    sc.render.line_thickness_mode = "ABSOLUTE"
    sc.render.line_thickness = 1.0
    fs = bpy.context.view_layer.freestyle_settings
    fs.mode = "EDITOR"
    for ls in list(fs.linesets):
        fs.linesets.remove(ls)
    # 88 gradi e non 85: sotto quella soglia ogni giunzione fra due dei 96 lati
    # dell'anello diventa una crease, e la facciata curva viene fuori rigata di
    # nero per tutta la sua altezza.
    fs.crease_angle = math.radians(88.0)

    fuori = fs.linesets.new("Contorno")
    for a in ("select_crease", "select_ridge_valley", "select_suggestive_contour",
              "select_material_boundary", "select_edge_mark"):
        setattr(fuori, a, False)
    fuori.select_silhouette = True
    fuori.select_border = True
    fuori.linestyle.color = (0.030, 0.023, 0.019)
    fuori.linestyle.thickness = 3.2
    _salta_testi(fuori)

    dentro = fs.linesets.new("Spigoli")
    for a in ("select_silhouette", "select_border", "select_ridge_valley",
              "select_suggestive_contour", "select_material_boundary",
              "select_edge_mark"):
        setattr(dentro, a, False)
    dentro.select_crease = True
    dentro.linestyle.color = (0.075, 0.058, 0.046)
    dentro.linestyle.alpha = 0.45
    dentro.linestyle.thickness = 1.5
    _salta_testi(dentro)
    return cam


def _salta_testi(lineset):
    coll = bpy.data.collections.get(COLL_TESTI)
    if coll is None:
        return
    lineset.select_by_collection = True
    lineset.collection = coll
    lineset.collection_negation = "EXCLUSIVE"


def inquadra(cam, margine=0.30):
    """Stringe l'inquadratura sull'ingombro vero, in spazio camera.

    Sui VERTICI e non sul bound box: il riquadro di un oggetto e' allineato
    agli assi, e con la camera inclinata gli spigoli finti di un anello largo
    trenta metri stanno piu' in alto di qualunque pezzo vero.
    """
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    punti = []
    for obj in bpy.data.objects:
        if obj.type not in ("MESH", "FONT") or obj.hide_render:
            continue
        val = obj.evaluated_get(dg)
        mesh = val.to_mesh() if obj.type == "FONT" else val.data
        if mesh is None:
            continue
        for v in mesh.vertices:
            punti.append(obj.matrix_world @ v.co)
        if obj.type == "FONT":
            val.to_mesh_clear()
    inv = cam.matrix_world.inverted()
    vista = [inv @ p for p in punti]
    minx, maxx = min(p.x for p in vista), max(p.x for p in vista)
    miny, maxy = min(p.y for p in vista), max(p.y for p in vista)
    larg = (maxx - minx) + 2 * margine
    alt = (maxy - miny) + 2 * margine
    cam.location = cam.matrix_world @ Vector(
        ((minx + maxx) / 2.0, (miny + maxy) / 2.0, 140.0))
    cam.data.ortho_scale = max(larg, alt)
    sc = bpy.context.scene
    sc.render.resolution_x = int(round(larg * PX_PER_METRO))
    sc.render.resolution_y = int(round(alt * PX_PER_METRO))
    return larg, alt


def modo_luci():
    """Riduce la scena a quello che di notte resta acceso.

    Stessa logica di `render_buildings.modo_luci()`: di notte il
    `CanvasModulate` della citta' moltiplica lo sprite per il blu della sera, e
    una luce dipinta gialla viene fuori marrone. Il secondo scatto e' lo stesso
    stadio, stessa camera e stessa inquadratura, con dentro solo cio' che il
    modello dichiara gia' emissivo, su fondo nero.
    """
    sc = bpy.context.scene
    sc.render.use_freestyle = False
    for luce in bpy.data.lights:
        luce.energy = 0.0
    for nodo in sc.world.node_tree.nodes:
        if nodo.type == "BACKGROUND":
            _set(nodo, "Strength", 0.0)
    for mat in bpy.data.materials:
        if not mat.use_nodes or mat.node_tree is None:
            continue
        bsdf = next((n for n in mat.node_tree.nodes
                     if n.type == "BSDF_PRINCIPLED"), None)
        acceso = None
        if bsdf is not None and "Emission Strength" in bsdf.inputs:
            forza = float(bsdf.inputs["Emission Strength"].default_value)
            if forza > 0.001 and "Emission Color" in bsdf.inputs:
                acceso = tuple(bsdf.inputs["Emission Color"].default_value)
        N, L = mat.node_tree.nodes, mat.node_tree.links
        N.clear()
        uscita = N.new("ShaderNodeOutputMaterial")
        if acceso is None:
            nero = N.new("ShaderNodeBsdfDiffuse")
            nero.inputs["Color"].default_value = (0.0, 0.0, 0.0, 1.0)
            L.new(nero.outputs[0], uscita.inputs["Surface"])
        else:
            luce = N.new("ShaderNodeEmission")
            luce.inputs["Color"].default_value = acceso
            luce.inputs["Strength"].default_value = 1.0
            L.new(luce.outputs[0], uscita.inputs["Surface"])


# ----------------------------------------------------------------------
#  costruzione e render
# ----------------------------------------------------------------------

def costruisci():
    pulisci()
    palette()
    collezione(COLL_TESTI)
    pezzi = []
    campo(pezzi)
    gradinate(pezzi)
    podio(pezzi)
    facciata(pezzi)
    gronda(pezzi)
    fronte(pezzi)
    fari(pezzi)
    unisci(pezzi, "STADIO")
    cam = scena()
    return inquadra(cam)


def renderizza(cartella=None):
    """Due scatti: il disegno e le luci della notte, stessa inquadratura."""
    if cartella is None:
        cartella = os.path.abspath(os.path.join(
            os.path.dirname(os.path.abspath(__file__)), os.pardir, "assets",
            "sprites", "buildings", "_source"))
    os.makedirs(cartella, exist_ok=True)
    larg, alt = costruisci()
    sc = bpy.context.scene
    sc.render.resolution_percentage = SUPERSAMPLING * 100
    sc.render.filepath = os.path.join(cartella, "render_stadio.png")
    bpy.ops.render.render(write_still=True)
    # Va dopo il primo e non prima: `modo_luci()` riscrive i materiali e non li
    # rimette a posto.
    modo_luci()
    sc.render.filepath = os.path.join(cartella, "luci_stadio.png")
    bpy.ops.render.render(write_still=True)
    facce = sum(len(o.data.polygons) for o in bpy.data.objects
                if o.type == "MESH")
    print("STADIO  %.1f x %.1f m  render %dx%d  %d facce"
          % (larg, alt, sc.render.resolution_x, sc.render.resolution_y, facce))
    return larg, alt


if __name__ == "__main__":
    if "--render" in sys.argv:
        renderizza()
    else:
        print("STADIO", costruisci())
