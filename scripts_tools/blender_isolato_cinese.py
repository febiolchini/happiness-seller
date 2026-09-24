"""Costruisce in Blender l'isolato commerciale in mattoni con il ristorante cinese.

Non e' un edificio solo: e' il blocco americano classico, un unico fabbricato
dritto e rettangolare in mattoni con quattro attivita' affiancate che
condividono i muri e la stessa facciata — ristorante cinese d'angolo, negozio
di vestiti, negozio di cellulari e, in fondo, un piccolo condominio senza
negozio sotto. Le vetrine cambiano colore e insegna, i mattoni sopra no: e'
quello che tiene insieme il blocco e lo fa leggere come un edificio solo invece
che come quattro casette accostate.

Convenzioni prese da `render_buildings.py`, perche' lo sprite deve stare nella
stessa strada degli altri:
  * camera ortografica inclinata 27 gradi sull'asse X e nient'altro: la
    facciata resta dritta e si allinea agli altri edifici lungo la strada;
  * 22,3 px per metro (la scala la detta il personaggio, alto 39 px);
  * due linee Freestyle, contorno spesso fuori e spigoli sottili dentro;
  * nessuna vegetazione e nessun arredo urbano: quelli li piazza il gioco.
    Qui e' attaccato alla facciata solo cio' che dalla facciata non si stacca —
    scala antincendio, lanterne, insegne, condizionatori, serbatoio sul tetto.

Uso da MCP: viene eseguito dentro Blender e lascia la scena pronta con camera,
luci e inquadratura gia' fatte.
"""

import math
import os
import random

import bpy
from mathutils import Vector

# ----------------------------------------------------------------------
#  misure generali
# ----------------------------------------------------------------------

INCLINAZIONE = 27.0          # gradi sull'orizzonte, come il quartiere povero
PX_PER_METRO = 22.3

PROF = 7.4                   # profondita' del fabbricato
RIENTRO_NEG = 0.85           # quanto il piano terra dei negozi sta indietro
SP = 0.38                    # spessore della facciata forata
H_TERRA = 3.95               # altezza del piano terra commerciale
H_PIANO = 2.92               # altezza dei piani sopra
PARAPETTO = 0.85

# Moltiplicatore di risoluzione del render rispetto allo sprite finale: a 1x le
# ringhiere della scala antincendio, alte tre pixel a schermo, escono a
# scalini; renderizzate a 4x e ridotte dopo arrivano come una sfumatura.
SUPERSAMPLING = 4

FONT_CJK = "C:/Windows/Fonts/msyhbd.ttc"
FONT_LAT = "C:/Windows/Fonts/arialbd.ttf"

# Le quattro unita', da sinistra a destra, a filo sui fianchi.
# (chiave, larghezza, piani sopra il terra)
UNITA = [
    ("ristorante", 8.2, 2),
    ("vestiti", 6.6, 2),
    ("cellulari", 5.4, 2),
    ("condominio", 9.2, 3),
]

random.seed(90218)


# ----------------------------------------------------------------------
#  colore e materiali
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


def trasparente(mat, alpha):
    """Rende il materiale semitrasparente, in EEVEE vecchio e nuovo.

    Un cristallo modellato come pannello OPACO nasconde il negozio che ha
    dietro: le vetrine uscivano come rettangoli spenti, ed era quello il
    motivo, non il colore. Il nome della proprieta' e' cambiato tra le
    versioni di EEVEE, quindi si prova la nuova e si ricade sulla vecchia.
    """
    b = _bsdf(mat)
    _set(b, "Alpha", alpha)
    if hasattr(mat, "surface_render_method"):
        try:
            mat.surface_render_method = "BLENDED"
        except TypeError:
            pass
    if hasattr(mat, "blend_method"):
        try:
            mat.blend_method = "BLEND"
        except TypeError:
            pass
    if hasattr(mat, "show_transparent_back"):
        mat.show_transparent_back = False
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


# Quanti corsi di mattoni stanno in un metro, come multiplo della texture.
#
# Il nodo Brick ha corsi alti 0,17 e mattoni larghi 0,42 nelle SUE unita': con
# la mappatura a 1,55 vengono corsi da 11 cm e mattoni da 27, cioe' il passo di
# `QP_Mattone_Facciata` in `render_buildings.py`. Non e' la misura di un mattone
# vero (6,5 cm): a 22,3 px per metro un corso vero e' alto un pixel e mezzo e
# sparisce nel rumore — che e' esattamente com'era prima, con la mappatura a 7.
SCALA_MATTONE = 1.55


def mattone(name, chiaro, scuro, malta, sporco, seme=0.0,
            scala=SCALA_MATTONE, macchie=0.30):
    """Mattone procedurale con corsi irregolari e una velatura di sporco.

    Il colore va COLLEGATO al Base Color, non scritto dentro: e' la stessa cosa
    che fa `modo_luci()` di `render_buildings.py` a spegnere gli edifici di
    notte riscrivendo l'albero invece degli ingressi.
    """
    mat = _fresh(name)
    N, L = mat.node_tree.nodes, mat.node_tree.links
    b = _bsdf(mat)
    _set(b, "Roughness", 0.93)

    coord = N.new("ShaderNodeTexCoord")
    coord.location = (-1100, 0)
    map_ = N.new("ShaderNodeMapping")
    map_.location = (-920, 0)
    map_.inputs["Scale"].default_value = (scala, scala, scala)
    # Ruotato di -90 gradi sulla X. Il nodo Brick disegna i corsi sul piano XY
    # del vettore che riceve: dandogli le coordinate oggetto cosi' come sono,
    # sulla facciata — che vive su X e Z — il motivo non varia in altezza e
    # vengono fuori righe VERTICALI. Girando la Z del mondo sulla Y della
    # texture i corsi tornano orizzontali.
    map_.inputs["Rotation"].default_value = (math.radians(-90.0), 0.0, 0.0)
    L.new(coord.outputs["Object"], map_.inputs["Vector"])

    br = N.new("ShaderNodeTexBrick")
    br.location = (-720, 0)
    br.offset = 0.5
    br.offset_frequency = 2
    br.squash = 1.0
    br.squash_frequency = 2
    br.inputs["Color1"].default_value = srgb(chiaro)
    br.inputs["Color2"].default_value = srgb(scuro)
    br.inputs["Mortar"].default_value = srgb(malta)
    _set(br, "Scale", 1.0)
    _set(br, "Mortar Size", 0.030)
    _set(br, "Mortar Smooth", 0.10)
    _set(br, "Bias", 0.0)
    _set(br, "Brick Width", 0.42)
    _set(br, "Row Height", 0.17)
    L.new(map_.outputs["Vector"], br.inputs["Vector"])

    # Chiazze larghe di sporco: senza, una parete di mattoni a 250 px di sprite
    # si legge come una texture ripetuta e si vede il motivo.
    noise = N.new("ShaderNodeTexNoise")
    noise.location = (-720, -320)
    _set(noise, "Scale", 2.1)
    _set(noise, "Detail", 4.0)
    _set(noise, "Roughness", 0.55)
    _set(noise, "W", seme)
    L.new(coord.outputs["Object"], noise.inputs["Vector"])

    ramp = N.new("ShaderNodeValToRGB")
    ramp.location = (-520, -320)
    ramp.color_ramp.elements[0].position = 0.42
    ramp.color_ramp.elements[1].position = 0.74
    # Gli estremi della rampa sono il NERO e un grigio pari a `macchie`: il Fac
    # collegato ignora il valore costante dell'ingresso, e una rampa che arriva
    # a bianco moltiplica per lo sporco a tutta forza — il muro diventa fango.
    ramp.color_ramp.elements[0].color = (0.0, 0.0, 0.0, 1.0)
    ramp.color_ramp.elements[1].color = (macchie, macchie, macchie, 1.0)

    L.new(noise.outputs["Fac"], ramp.inputs["Fac"])

    mix = N.new("ShaderNodeMixRGB")
    mix.location = (-300, 0)
    mix.blend_type = "MULTIPLY"
    mix.inputs["Color2"].default_value = srgb(sporco)
    L.new(br.outputs["Color"], mix.inputs["Color1"])
    L.new(ramp.outputs["Color"], mix.inputs["Fac"])
    L.new(mix.outputs["Color"], b.inputs["Base Color"])
    return mat


PALETTE = {}


def palette():
    P = PALETTE
    # --- mattoni: due cotture diverse per staccare il condominio dai negozi,
    #     ma della stessa famiglia, perche' il blocco e' uno solo.
    P["mattone"] = mattone("IC_Mattone", "#B06450", "#94513F", "#D3C0A9",
                           "#7E6457", seme=1.0)
    P["mattone_condo"] = mattone("IC_Mattone_Condo", "#A4584A", "#84463A",
                                 "#C7B39A", "#75594D", seme=5.0, macchie=0.38)
    P["mattone_lato"] = mattone("IC_Mattone_Lato", "#8E5244", "#6E3D33",
                                "#B5A38C", "#6A5348", seme=9.0, macchie=0.46)
    # Una cottura per unita'. Nella via di riferimento due edifici attaccati
    # non hanno mai lo stesso mattone: e' quello che fa leggere le unita'
    # dentro a un fabbricato solo, senza staccarle in quattro casette.
    P["mattone_rist"] = mattone("IC_Mattone_Rist", "#8E463C", "#743830",
                                "#B39C86", "#6E5348", seme=2.0, macchie=0.40)
    P["mattone_vest"] = mattone("IC_Mattone_Vest", "#C49670", "#A87C58",
                                "#D9CBB4", "#8A7560", seme=3.0, macchie=0.28)
    P["mattone_cell"] = mattone("IC_Mattone_Cell", "#A85E4A", "#8A4A3A",
                                "#CDB79C", "#7A6052", seme=4.0, macchie=0.32)

    # --- facciate dei negozi
    P["fronte_rist"] = piatto("IC_Fronte_Ristorante", "#6E312A", rough=0.62)
    P["fronte_vest"] = piatto("IC_Fronte_Vestiti", "#E4D8C0", rough=0.70)
    P["fronte_cell"] = piatto("IC_Fronte_Cellulari", "#1E3352", rough=0.60)
    P["zoccolo"] = piatto("IC_Zoccolo", "#3A322C", rough=0.85)

    # --- insegne
    P["ins_rossa"] = piatto("IC_Insegna_Rossa", "#8E1512", rough=0.55)
    P["ins_gialla"] = piatto("IC_Insegna_Gialla", "#D8A526", rough=0.55)
    P["ins_blu"] = piatto("IC_Insegna_Blu", "#16467E", rough=0.55)
    P["testo_giallo"] = piatto("IC_Testo_Giallo", "#F2C63A", rough=0.40,
                               emissivo="#F2C63A", forza=1.30)
    P["testo_bianco"] = piatto("IC_Testo_Bianco", "#F3EDE0", rough=0.40,
                               emissivo="#F3EDE0", forza=1.10)
    P["testo_rosso"] = piatto("IC_Testo_Rosso", "#D6342A", rough=0.40,
                              emissivo="#D6342A", forza=1.30)
    P["neon"] = piatto("IC_Neon", "#FF4438", rough=0.30,
                       emissivo="#FF5A3C", forza=3.2)
    P["neon_verde"] = piatto("IC_Neon_Verde", "#49E08A", rough=0.30,
                             emissivo="#49E08A", forza=2.8)

    # --- vetri. L'emissivo e' quello che di notte resta acceso nel secondo
    #     scatto: una vetrina accesa di giorno deve essere la stessa di notte.
    # Il cristallo e' scuro: la luce del negozio sta DIETRO, nel fondo e nelle
    # insegne. Un vetro emissivo a tutta forza e' una lastra bianca in cui non
    # si legge piu' niente, ed e' esattamente come usciva prima.
    P["vetrina"] = trasparente(
        piatto("IC_Vetrina", "#3E4640", rough=0.10, metal=0.20,
               emissivo="#C9A86A", forza=0.22), 0.28)
    P["interno"] = piatto("IC_Interno", "#8A6E48", rough=0.92,
                          emissivo="#E8C07A", forza=1.85)
    P["interno_scuro"] = piatto("IC_Interno_Scuro", "#241F1B", rough=0.95)
    P["plafoniera"] = piatto("IC_Plafoniera", "#F0DCA8", rough=0.30,
                             emissivo="#FFE9BC", forza=3.0)
    P["vetro"] = piatto("IC_Vetro", "#5E6B72", rough=0.10, metal=0.25)
    P["vetro_acceso"] = piatto("IC_Vetro_Acceso", "#C8A362", rough=0.12,
                               emissivo="#E2BB72", forza=0.70)
    P["vetro_atrio"] = trasparente(
        piatto("IC_Vetro_Atrio", "#8FA08A", rough=0.12,
               emissivo="#B9C79A", forza=0.55), 0.55)

    # --- ferro, legno, cemento
    P["ferro"] = piatto("IC_Ferro", "#2A2420", rough=0.62, metal=0.55)
    P["ferro_rosso"] = piatto("IC_Ferro_Rosso", "#8E4032", rough=0.66,
                              metal=0.40)
    P["alluminio"] = piatto("IC_Alluminio", "#8C8A85", rough=0.42, metal=0.80)
    P["legno"] = piatto("IC_Legno", "#5C4632", rough=0.88)
    P["cemento"] = piatto("IC_Cemento", "#8E877C", rough=0.95)
    P["cornicione"] = piatto("IC_Cornicione", "#6B5346", rough=0.88)
    P["lanterna"] = piatto("IC_Lanterna", "#C4201B", rough=0.45,
                           emissivo="#FF4B28", forza=1.9)
    P["tenda"] = piatto("IC_Tenda", "#7A1B16", rough=0.80)
    P["catrame"] = piatto("IC_Catrame", "#4A453F", rough=0.97)
    return P


# ----------------------------------------------------------------------
#  primitive
# ----------------------------------------------------------------------

def pulisci():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for blocco in (bpy.data.meshes, bpy.data.curves, bpy.data.materials,
                   bpy.data.lights, bpy.data.cameras):
        for dato in list(blocco):
            if dato.users == 0:
                blocco.remove(dato)


def box(nome, centro, misure, materiale=None, rot=None):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=centro)
    ob = bpy.context.active_object
    ob.name = nome
    ob.scale = (misure[0], misure[1], misure[2])
    if rot:
        ob.rotation_euler = rot
    bpy.ops.object.transform_apply(location=False, rotation=bool(rot),
                                   scale=True)
    if materiale:
        ob.data.materials.append(materiale)
    return ob


def bx(nome, x0, x1, y0, y1, z0, z1, materiale=None):
    """Scatola dagli estremi: leggere una facciata per estremi e' piu' sicuro
    che per centro e misura, perche' i fori si descrivono cosi'."""
    return box(nome,
               ((x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0),
               (abs(x1 - x0), abs(y1 - y0), abs(z1 - z0)), materiale)


def cilindro(nome, centro, raggio, altezza, materiale=None, lati=14, rot=None):
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


def unisci(pezzi, nome):
    """Unisce i pezzi in una mesh sola e riporta l'origine a (0,0,0).

    **Senza questo passaggio il Freestyle disegna il contorno spesso intorno a
    OGNI scatola.** La linea "Contorno" seleziona la silhouette, e la
    silhouette e' una proprieta' dell'oggetto: seicento scatole sciolte sono
    seicento silhouette, quindi ogni telaio, ogni davanzale e ogni architrave
    si ritrova un bordo nero da due pixel tutto attorno. Uniti, la silhouette
    e' una sola — il profilo dell'edificio — e dentro restano solo le linee di
    piega, sottili e a meta' opacita'. E' lo stesso motivo per cui
    `render_buildings.py` unisce i suoi pezzi: gli edifici del quartiere povero
    hanno quell'aria pulita perche' sono quattro mesh, non quattrocento.

    L'origine conta e va rimessa a zero: il mattone procedurale legge le
    coordinate OGGETTO, e finche' ogni scatola ha la sua origine il disegno dei
    corsi riparte da capo su ogni pilastro. Con un'origine sola i corsi corrono
    continui su tutta la facciata, come in un muro vero.
    """
    pezzi = [p for p in pezzi if p.name in bpy.data.objects]
    if not pezzi:
        return None
    bpy.ops.object.select_all(action="DESELECT")
    for p in pezzi:
        p.select_set(True)
    bpy.context.view_layer.objects.active = pezzi[0]
    if len(pezzi) > 1:
        bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = nome
    bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    bpy.ops.object.select_all(action="DESELECT")
    return obj


def muro_forato(nome, x0, x1, z0, z1, y0, y1, materiale, fori):
    """Un muro solo, bucato con una booleana. NON una fila di scatole.

    **E' la differenza fra una facciata e una griglia di rettangoli neri.** La
    linea "Contorno" del Freestyle disegna la silhouette, e la silhouette e' di
    ogni oggetto e di ogni scatola dentro all'oggetto: un muro composto da
    pilastri e fasce sopra e sotto le finestre si ritrova un bordo nero spesso
    intorno a OGNI pezzo, e a ventidue pixel per metro quei bordi si toccano
    fra loro e anneriscono meta' facciata. Bucato con la booleana il muro e'
    una superficie continua, il contorno gli gira solo intorno, e dentro
    restano le linee di piega — sottili, a meta' opacita' — sugli spigoli veri.

    E' anche il motivo per cui `render_buildings.py` ha `_scava()`: gli edifici
    del quartiere povero hanno la facciata pulita perche' i loro muri sono
    scavati, non assemblati.
    """
    muro = bx(nome, x0, x1, y0, y1, z0, z1, materiale)
    tagli = []
    for i, (fa, fb, za, zb) in enumerate(fori):
        # Il cutter sfonda oltre lo spessore del muro: con le facce davanti e
        # dietro complanari la booleana lascia una pellicola di muro dentro al
        # foro, che in render si vede come un vetro opaco.
        tagli.append(bx("%s_cut%d" % (nome, i), max(fa, x0), min(fb, x1),
                        y0 - 0.06, y1 + 0.06, za, zb))
    if not tagli:
        return muro
    cutter = unisci(tagli, "%s_cutter" % nome)
    bpy.context.view_layer.objects.active = muro
    mod = muro.modifiers.new("Aperture", "BOOLEAN")
    mod.operation, mod.solver, mod.object = "DIFFERENCE", "EXACT", cutter
    bpy.ops.object.modifier_apply(modifier="Aperture")
    bpy.data.objects.remove(cutter, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    muro.select_set(True)
    bpy.context.view_layer.objects.active = muro
    bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    return muro


COLL_TESTI = "SenzaContorno"


def collezione(nome):
    c = bpy.data.collections.get(nome)
    if c is None:
        c = bpy.data.collections.new(nome)
        bpy.context.scene.collection.children.link(c)
    return c


def scritta(nome, testo, x, y, z, altezza, materiale, font=FONT_LAT,
            estrusione=0.05, allinea="CENTER"):
    """Testo vero estruso: le insegne di un blocco cinese sono per meta' testo,
    e un rettangolo colorato al posto della scritta si legge come segnaposto."""
    curva = bpy.data.curves.new(nome, type="FONT")
    curva.body = testo
    curva.align_x = allinea
    curva.align_y = "CENTER"
    curva.extrude = estrusione
    try:
        curva.font = bpy.data.fonts.load(font, check_existing=True)
    except RuntimeError:
        pass
    ob = bpy.data.objects.new(nome, curva)
    # Le scritte vanno in una collezione a parte perche' il Freestyle le deve
    # saltare: una lettera alta nove pixel con intorno un contorno nero spesso
    # due non e' piu' una lettera, e' una macchia.
    collezione(COLL_TESTI).objects.link(ob)
    if materiale:
        ob.data.materials.append(materiale)
    # La dimensione del font non e' l'altezza delle lettere: si misura il
    # risultato e si scala, cosi' due insegne con font diversi si equivalgono.
    # La misura va presa sulla copia VALUTATA dal depsgraph: `ob.dimensions` di
    # un testo appena creato e' ancora il riquadro vuoto, e scalando su quello
    # le insegne uscivano cinque volte troppo grandi.
    dg = bpy.context.evaluated_depsgraph_get()
    dg.update()
    alta = max(ob.evaluated_get(dg).dimensions.y, 1e-4)
    curva.size = altezza / alta
    # Il testo nasce sdraiato sul piano XY: va alzato e girato verso la strada.
    ob.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    ob.location = (x, y, z)
    return ob


# ----------------------------------------------------------------------
#  pezzi ricorrenti di facciata
# ----------------------------------------------------------------------

def finestra(nome, xa, xb, za, zb, acceso=False, tenda=False, condiz=False,
             P=None):
    """Infisso a ghigliottina: vetro arretrato, telaio, davanzale, traversa."""
    vetro = P["vetro_acceso"] if acceso else P["vetro"]
    bx(nome + "_Vetro", xa, xb, SP - 0.06, SP - 0.02, za, zb, vetro)
    t = 0.07
    bx(nome + "_TelSx", xa, xa + t, 0.02, SP - 0.02, za, zb, P["legno"])
    bx(nome + "_TelDx", xb - t, xb, 0.02, SP - 0.02, za, zb, P["legno"])
    bx(nome + "_TelSu", xa, xb, 0.02, SP - 0.02, zb - t, zb, P["legno"])
    # La traversa centrale: e' il dettaglio che a 250 px distingue una finestra
    # americana da un buco quadrato.
    zm = (za + zb) / 2.0
    bx(nome + "_Traversa", xa, xb, 0.02, SP - 0.02, zm - 0.04, zm + 0.04,
       P["legno"])
    bx(nome + "_Davanzale", xa - 0.10, xb + 0.10, -0.12, SP, za - 0.11, za,
       P["cemento"])
    # Architrave in mattoni a coltello sopra l'apertura.
    # Architrave in pietra chiara e non in mattone scuro: e' il contrasto che
    # a questa scala fa leggere la finestra come finestra invece che come una
    # macchia scura dentro al muro.
    bx(nome + "_Arco", xa - 0.13, xb + 0.13, -0.08, SP, zb, zb + 0.22,
       P["cemento"])
    if tenda:
        bx(nome + "_Tenda", xa + t, xb - t, SP - 0.07, SP - 0.03,
           zb - (zb - za) * 0.42, zb - t, P["tenda"])
    if condiz:
        # Sporge meno e riempie tutta la luce della finestra. Prima sporgeva 42
        # cm e, proiettato a 27 gradi, si sdraiava dentro al vetro: nello
        # sprite era una sbavatura scura in mezzo alla finestra invece che un
        # condizionatore appoggiato al davanzale.
        bx(nome + "_Condiz", xa + 0.06, xb - 0.06, -0.26, 0.06,
           za + 0.02, za + 0.56, P["alluminio"])
        bx(nome + "_CondizGr", xa + 0.10, xb - 0.10, -0.28, -0.25,
           za + 0.10, za + 0.50, P["ferro"])


def vetrina(nome, xa, xb, z0, ztop, P, colore, porta_x=None, grate=False):
    """Vetrina di negozio: zoccolo, cristallo arretrato, montanti, soglia."""
    zoccolo = 0.55
    bx(nome + "_Zoccolo", xa, xb, -0.04, 0.34, z0, z0 + zoccolo, P["zoccolo"])
    # Il cristallo sta indietro di un terzo di metro: e' il rientro che fa
    # l'ombra sotto l'insegna e stacca il piano terra dal muro di mattoni.
    #
    # Non di piu'. Con la camera inclinata di 27 gradi tutto cio' che sta
    # dietro si alza sullo schermo di 0,45 volte la sua profondita': con mezzo
    # metro di rientro e il fondo del negozio a un metro e dieci, il soffitto
    # della nicchia si proiettava davanti alla vetrina e la copriva quasi tutta
    # — i due negozi in mezzo uscivano come rettangoli neri.
    rientro = 0.32
    bx(nome + "_Vetro", xa + 0.10, xb - 0.10, rientro, rientro + 0.05,
       z0 + zoccolo, ztop - 0.10, P["vetrina"])
    # Fondo del negozio: una parete illuminata dietro al cristallo. Serve a
    # dare profondita', senza di essa la vetrina e' un buco nero.
    bx(nome + "_Fondo", xa, xb, RIENTRO_NEG - 0.06, RIENTRO_NEG, z0, ztop,
       P["interno"])
    # Plafoniera al soffitto del negozio: e' la riga di luce che si vede dalla
    # strada sopra la merce, e da sola dice "aperto" meglio di un vetro giallo.
    bx(nome + "_Plafo", xa + 0.25, xb - 0.25, rientro + 0.10,
       RIENTRO_NEG - 0.06, ztop - 0.30, ztop - 0.18, P["plafoniera"])
    # Banco in controluce: una sagoma scura davanti al fondo acceso. Senza,
    # la vetrina e' una superficie sola e non si legge la profondita'.
    bx(nome + "_Banco", xa + 0.25, xb - 0.25, rientro + 0.18,
       RIENTRO_NEG - 0.08, z0, z0 + 1.00, P["interno_scuro"])
    # Soffitto e pavimento del rientro, altrimenti si vede dentro al nulla.
    bx(nome + "_Soffitto", xa, xb, 0.0, RIENTRO_NEG, ztop - 0.12, ztop,
       colore)
    bx(nome + "_Soglia", xa, xb, 0.0, RIENTRO_NEG, z0 - 0.02, z0 + 0.04,
       P["cemento"])
    for x in (xa, xb):
        bx(nome + "_Mont%.2f" % x, x - 0.09, x + 0.09, 0.0, RIENTRO_NEG,
           z0, ztop, colore)
    # Montanti interni del serramento.
    n = max(1, int((xb - xa) / 1.45))
    for i in range(1, n):
        x = xa + (xb - xa) * i / n
        bx(nome + "_Div%d" % i, x - 0.045, x + 0.045, rientro - 0.02,
           rientro + 0.07, z0 + zoccolo, ztop - 0.10, P["alluminio"])
    if grate:
        # Quattro barre e non nove. Ogni barra si porta dietro il suo contorno
        # Freestyle: a nove, i contorni si toccavano tra loro e la vetrina
        # usciva come un rettangolo nero pieno. La grata si legge lo stesso.
        for i in range(0, 4):
            z = z0 + zoccolo + (ztop - 0.30 - z0 - zoccolo) * i / 3.0
            bx(nome + "_Grata%d" % i, xa + 0.10, xb - 0.10, rientro - 0.09,
               rientro - 0.03, z - 0.035, z + 0.035, P["ferro"])
    if porta_x is not None:
        pw = 0.95
        bx(nome + "_Porta", porta_x - pw / 2, porta_x + pw / 2,
           rientro + 0.02, rientro + 0.07, z0, z0 + 2.35, P["vetro_atrio"])
        for dx in (-pw / 2, pw / 2):
            bx(nome + "_PortaMont%.2f" % dx, porta_x + dx - 0.06,
               porta_x + dx + 0.06, rientro, rientro + 0.09, z0, z0 + 2.45,
               P["alluminio"])
        bx(nome + "_PortaArch", porta_x - pw / 2 - 0.06, porta_x + pw / 2 + 0.06,
           rientro, rientro + 0.09, z0 + 2.35, z0 + 2.45, P["alluminio"])


def fascia_insegna(nome, xa, xb, z0, z1, P, colore):
    """Il cassone dell'insegna: sporge dal filo facciata e porta le scritte."""
    bx(nome + "_Cassa", xa, xb, -0.26, 0.18, z0, z1, colore)
    bx(nome + "_BordoSu", xa, xb, -0.30, 0.18, z1 - 0.09, z1, P["ferro"])
    bx(nome + "_BordoGiu", xa, xb, -0.30, 0.18, z0, z0 + 0.09, P["ferro"])
    # Due faretti a collo d'oca: illuminano l'insegna e sono la firma
    # dell'insegna dipinta americana.
    for f in (0.25, 0.75):
        x = xa + (xb - xa) * f
        cilindro(nome + "_Braccio%.2f" % f, (x, -0.34, z1 + 0.22), 0.035, 0.55,
                 P["ferro"], lati=8, rot=(math.radians(58), 0, 0))
        cilindro(nome + "_Faro%.2f" % f, (x, -0.52, z1 + 0.12), 0.11, 0.16,
                 P["alluminio"], lati=10, rot=(math.radians(58), 0, 0))


def lanterna(nome, x, z, P, raggio=0.34):
    """Lanterna rossa appesa sotto l'insegna.

    Larga e schiacciata, senza nappa e senza filo sottile. Nello sprite e' un
    cerchio di quindici pixel: la nappa (sei centimetri) diventava un pixel
    nero in mezzo alla palla, e il filo spariva lasciando la lanterna per aria.
    L'emissione e' bassa apposta — a 4,5 il rosso si bruciava sul bianco e
    restava un bollo chiaro, che e' quello che si vedeva ingrandendo.
    """
    bx(nome + "_Filo", x - 0.025, x + 0.025, -0.33, -0.28,
       z + raggio * 0.55, z + 0.62, P["ferro"])
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=10,
                                         radius=raggio, location=(x, -0.34, z))
    ob = bpy.context.active_object
    ob.name = nome
    ob.scale = (1.0, 0.85, 0.80)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ob.data.materials.append(P["lanterna"])
    # La lanterna sta nella collezione senza contorno: un contorno nero attorno
    # a una palla di trenta centimetri la trasforma in un punto scuro.
    for c in list(ob.users_collection):
        c.objects.unlink(ob)
    collezione(COLL_TESTI).objects.link(ob)
    return ob


def scala_antincendio(x0, x1, z_piani, P):
    """Scala antincendio in ferro sulla facciata: ballatoi, parapetti pieni e
    rampe diagonali. E' l'elemento che dice "palazzo americano di mattoni"
    prima ancora delle insegne.

    I parapetti sono pannelli PIENI e non ringhiere a stecche. A 22 pixel per
    metro una stecca e' larga mezzo pixel e si porta dietro il suo contorno
    nero: messe in fila diventano una macchia scura, e la scala non si legge
    piu' come una scala. Un pannello pieno con sopra il corrimano da' le due
    righe orizzontali che la raccontano.
    """
    sp = 0.95          # sporgenza dal filo facciata
    for i, z in enumerate(z_piani):
        bx("Scala_Pian%d" % i, x0, x1, -sp, -0.02, z, z + 0.09, P["ferro_rosso"])
        bx("Scala_Pann%d" % i, x0, x1, -sp, -sp + 0.07, z + 0.08, z + 0.80,
           P["ferro_rosso"])
        bx("Scala_Corr%d" % i, x0 - 0.04, x1 + 0.04, -sp - 0.04, -sp + 0.09,
           z + 0.80, z + 0.92, P["ferro"])
        for lato in (x0, x1):
            bx("Scala_Fian%d_%.2f" % (i, lato), lato - 0.04, lato + 0.04,
               -sp, -0.02, z + 0.08, z + 0.92, P["ferro_rosso"])
        if i + 1 < len(z_piani):
            # Rampa: una lastra inclinata da un ballatoio all'altro, sul lato
            # che si alterna, come nelle scale vere.
            zs = z_piani[i + 1]
            dy = sp - 0.35
            lung = math.hypot(zs - z, dy)
            ang = math.atan2(zs - z, dy)
            xr = x0 + 0.85 if i % 2 == 0 else x1 - 0.85
            box("Scala_Rampa%d" % i, (xr, -sp + dy / 2.0, (z + zs) / 2.0 + 0.1),
                (0.90, lung, 0.08), P["ferro_rosso"], rot=(-ang, 0.0, 0.0))
            box("Scala_RampaCorr%d" % i,
                (xr - 0.45, -sp + dy / 2.0, (z + zs) / 2.0 + 0.62),
                (0.07, lung, 0.07), P["ferro"], rot=(-ang, 0.0, 0.0))
    # Scaletta di sbarco verso la strada, appesa sotto al primo ballatoio.
    z = z_piani[0]
    bx("Scala_Sbarco", x1 - 1.30, x1 - 0.45, -sp + 0.10, -sp + 0.18,
       z - 1.35, z, P["ferro"])


# ----------------------------------------------------------------------
#  l'isolato
# ----------------------------------------------------------------------

def quote(chiavi=None):
    """Posizioni in x dei tagli tra le unita' e altezze dei piani.

    `chiavi` sceglie quali unita' costruire. Una sola unita' viene centrata in
    x = 0; piu' unita' restano nell'ordine e nelle larghezze dell'isolato, cosi'
    il blocco intero e i pezzi singoli sono esattamente la stessa geometria.
    """
    voci = [u for u in UNITA if chiavi is None or u[0] in chiavi]
    larg = sum(u[1] for u in voci)
    x = -larg / 2.0
    fette = []
    for chiave, w, piani in voci:
        h = H_TERRA + piani * H_PIANO
        fette.append(dict(chiave=chiave, x0=x, x1=x + w, w=w, piani=piani,
                          h=h, tetto=h + PARAPETTO))
        x += w
    return fette, larg


def mat_unita(chiave, P):
    """Il mattone dell'unita': una cottura diversa per ciascuna."""
    return {"ristorante": P["mattone_rist"], "vestiti": P["mattone_vest"],
            "cellulari": P["mattone_cell"],
            "condominio": P["mattone_condo"]}[chiave]


def facciata_piani(f, P):
    """Mattoni e finestre dei piani sopra il negozio, unita' per unita'."""
    mat = mat_unita(f["chiave"], P)
    n = {"ristorante": 3, "vestiti": 3, "cellulari": 2, "condominio": 4}[
        f["chiave"]]
    larg_f, alt_f = 1.12, 1.62
    passo = f["w"] / n
    for p in range(f["piani"]):
        z0 = H_TERRA + p * H_PIANO
        z1 = z0 + H_PIANO
        fori = []
        assi = []
        for i in range(n):
            cx = f["x0"] + passo * (i + 0.5)
            fori.append((cx - larg_f / 2, cx + larg_f / 2,
                         z0 + 0.95, z0 + 0.95 + alt_f))
            assi.append(cx)
        muro_forato("Mur_%s_%d" % (f["chiave"], p), f["x0"], f["x1"], z0, z1,
                    0.0, SP, mat, fori)
        for i, cx in enumerate(assi):
            acceso = random.random() < (0.55 if f["chiave"] == "condominio"
                                        else 0.35)
            finestra("Fin_%s_%d_%d" % (f["chiave"], p, i),
                     cx - larg_f / 2, cx + larg_f / 2,
                     z0 + 0.95, z0 + 0.95 + alt_f,
                     acceso=acceso,
                     tenda=(f["chiave"] == "condominio" and random.random() < 0.4),
                     condiz=(random.random() < 0.18), P=P)
        # Fascia marcapiano tra un piano e l'altro: due centimetri di sporto,
        # ma sono quelli che danno la riga d'ombra orizzontale.
        bx("Marca_%s_%d" % (f["chiave"], p), f["x0"], f["x1"], -0.07, 0.0,
           z0 - 0.10, z0 + 0.04, P["cornicione"])


def cornicione(f, P):
    """Cornicione e parapetto: il coronamento e' quello che chiude la sagoma."""
    z = f["h"]
    bx("Corn_%s_A" % f["chiave"], f["x0"], f["x1"], -0.30, 0.0, z, z + 0.22,
       P["cornicione"])
    bx("Corn_%s_B" % f["chiave"], f["x0"], f["x1"], -0.18, 0.0, z + 0.22,
       z + 0.38, P["cornicione"])
    # Dentelli: una fila di piccoli blocchi sotto il cornicione.
    n = max(3, int(f["w"] / 0.62))
    for i in range(n):
        cx = f["x0"] + f["w"] * (i + 0.5) / n
        bx("Dent_%s_%d" % (f["chiave"], i), cx - 0.13, cx + 0.13, -0.24, 0.0,
           z - 0.22, z, P["cornicione"])
    bx("Para_%s" % f["chiave"], f["x0"], f["x1"], -0.05, 0.42, z + 0.38,
       f["tetto"], P["mattone_lato"])
    bx("Copri_%s" % f["chiave"], f["x0"] - 0.03, f["x1"] + 0.03, -0.09, 0.46,
       f["tetto"], f["tetto"] + 0.10, P["cemento"])


def fronte_ristorante(f, P):
    """Il ristorante cinese: fascia bruno-rossa a tutta larghezza, scritte in
    giallo e rosso, caratteri cinesi, neon in vetrina e lanterne appese."""
    z_ins0, z_ins1 = 2.62, H_TERRA
    vetrina("Vet_Rist", f["x0"] + 0.18, f["x1"] - 0.18, 0.0, z_ins0 - 0.06, P,
            P["fronte_rist"], porta_x=f["x0"] + 1.35)
    fascia_insegna("Ins_Rist", f["x0"], f["x1"], z_ins0, z_ins1, P,
                   P["fronte_rist"])

    cx = (f["x0"] + f["x1"]) / 2.0
    # Impaginato dell'insegna di riferimento, su due righe dentro la fascia: in
    # alto \u798f, il nome e i due caratteri cinesi, sotto la riga piccola. Le
    # scritte in alto non possono stare alla quota del sottotitolo: la fascia
    # e' alta 1,33 m e con una riga sola si sovrapponevano tutte.
    z_riga1 = z_ins0 + (z_ins1 - z_ins0) * 0.64
    z_riga2 = z_ins0 + (z_ins1 - z_ins0) * 0.22
    scritta("Txt_Rist_Fu", "\u798f", f["x0"] + 0.55, -0.32, z_riga1,
            0.44, P["testo_rosso"], font=FONT_CJK, allinea="LEFT")
    scritta("Txt_Rist_Nome", "FOOD KING", f["x0"] + 1.45, -0.32, z_riga1,
            0.44, P["testo_giallo"], allinea="LEFT")
    scritta("Txt_Rist_Cn", "\u91d1\u9f8d", f["x1"] - 0.35, -0.32, z_riga1,
            0.56, P["testo_giallo"], font=FONT_CJK, allinea="RIGHT")
    scritta("Txt_Rist_Sub", "CHINESE FOOD", f["x0"] + 0.55, -0.32,
            z_riga2, 0.30, P["testo_bianco"], allinea="LEFT")
    # "TAKE OUT ORDERS" sul vetro non c'e' piu'. Era alto 18 cm, cioe' QUATTRO
    # pixel nello sprite: a quella misura una scritta non e' piccola, e'
    # illeggibile — ingrandendo si vede solo la poltiglia che resta dopo la
    # riduzione. Sotto i sei pixel di corpo, nel quartiere, le scritte non si
    # renderizzano: si appendono come PNG disegnato al pixel, vedi
    # `scripts_tools/make_signs.py` e il campo `sign` in `city_map.gd`.

    # Un neon solo, orizzontale e grande abbastanza da leggersi: 1,6 x 0,34 m
    # sono 36 x 8 pixel nello sprite. I due di prima — uno verde stretto e uno
    # rosso — erano macchie di colore da otto pixel che ingrandendo si
    # leggevano come errori di disegno, non come insegne.
    # Dentro a UNA campata, non a cavallo di un montante: il montante gli
    # passava davanti e nello sprite il neon si leggeva come un rettangolo
    # spezzato a meta'.
    nx = f["x0"] + 3.46
    bx("Neon_Rist", nx - 0.50, nx + 0.50, 0.40, 0.43, 1.92, 2.26, P["neon"])
    bx("Neon_Rist_Bordo", nx - 0.55, nx + 0.55, 0.43, 0.46, 1.88, 2.30,
       P["ferro"])

    for i, fr in enumerate((0.30, 0.70)):
        lanterna("Lant_Rist_%d" % i, f["x0"] + f["w"] * fr, z_ins0 - 0.38, P)

    # Insegna verticale appesa al braccio di ferro. Il pannello e' PARALLELO
    # alla facciata e non perpendicolare: di fronte, un cartello a bandiera si
    # vede di taglio e resta una stecca di due pixel.
    xb = f["x1"] - 0.95
    bx("Bandiera_Braccio", xb - 0.45, xb + 0.45, -0.58, -0.50,
       H_TERRA + 1.55, H_TERRA + 1.65, P["ferro"])
    bx("Bandiera_Attacco", xb - 0.05, xb + 0.05, -0.58, 0.0,
       H_TERRA + 1.55, H_TERRA + 1.65, P["ferro"])
    for dx in (-0.34, 0.34):
        bx("Bandiera_Tirante%.2f" % dx, xb + dx - 0.03, xb + dx + 0.03,
           -0.56, -0.52, H_TERRA + 1.32, H_TERRA + 1.56, P["ferro"])
    bx("Bandiera_Pann", xb - 0.42, xb + 0.42, -0.56, -0.50,
       H_TERRA - 0.30, H_TERRA + 1.34, P["ins_rossa"])
    bx("Bandiera_Bordo", xb - 0.46, xb + 0.46, -0.58, -0.52,
       H_TERRA - 0.34, H_TERRA - 0.24, P["ins_gialla"])
    scritta("Bandiera_Txt1", "\u4e2d", xb, -0.62, H_TERRA + 0.88, 0.52,
            P["testo_giallo"], font=FONT_CJK)
    scritta("Bandiera_Txt2", "\u83dc", xb, -0.62, H_TERRA + 0.24, 0.52,
            P["testo_giallo"], font=FONT_CJK)


def fronte_vestiti(f, P):
    """Negozio di vestiti: vetrina larga, insegna chiara, tenda sopra."""
    z_ins0, z_ins1 = 2.78, H_TERRA - 0.16
    vetrina("Vet_Vest", f["x0"] + 0.16, f["x1"] - 0.16, 0.0, z_ins0 - 0.06, P,
            P["fronte_vest"], porta_x=f["x1"] - 1.25)
    fascia_insegna("Ins_Vest", f["x0"], f["x1"], z_ins0, z_ins1, P,
                   P["ins_gialla"])
    cx = (f["x0"] + f["x1"]) / 2.0
    scritta("Txt_Vest", "GOLDEN THREAD", cx, -0.32,
            z_ins0 + (z_ins1 - z_ins0) * 0.62, 0.38, P["testo_bianco"])
    scritta("Txt_Vest_Sub", "TAILORING", cx, -0.32,
            z_ins0 + (z_ins1 - z_ins0) * 0.20, 0.28, P["testo_bianco"])
    # Tenda a falda sopra la vetrina.
    # Tenda corta: una tenda da un metro, proiettata a 27 gradi, si sdraiava
    # sulla vetrina e la spegneva. Mezzo metro basta a leggerla come tenda.
    box("Tenda_Vest", (cx, -0.24, z_ins0 - 0.20),
        (f["w"] - 0.6, 0.52, 0.06), P["tenda"],
        rot=(math.radians(-24.0), 0.0, 0.0))
    bx("Tenda_Vest_Bordo", f["x0"] + 0.30, f["x1"] - 0.30, -0.50, -0.44,
       z_ins0 - 0.40, z_ins0 - 0.26, P["ins_gialla"])
    # Manichini: due sagome semplici dietro al cristallo. Sono dentro il
    # negozio, quindi restano nel modello.
    for i, fr in enumerate((0.32, 0.55)):
        x = f["x0"] + f["w"] * fr
        cilindro("Manich_%d_Busto" % i, (x, 0.62, 1.55), 0.17, 0.75,
                 P["fronte_cell"] if i else P["ins_rossa"], lati=10)
        cilindro("Manich_%d_Gambe" % i, (x, 0.62, 0.80), 0.13, 0.80,
                 P["zoccolo"], lati=10)


def fronte_cellulari(f, P):
    """Negozio di cellulari: insegna blu stretta, vetrina con grata."""
    z_ins0, z_ins1 = 2.70, H_TERRA - 0.10
    vetrina("Vet_Cell", f["x0"] + 0.16, f["x1"] - 0.16, 0.0, z_ins0 - 0.06, P,
            P["fronte_cell"], porta_x=f["x0"] + 1.15, grate=True)
    fascia_insegna("Ins_Cell", f["x0"], f["x1"], z_ins0, z_ins1, P,
                   P["ins_blu"])
    cx = (f["x0"] + f["x1"]) / 2.0
    scritta("Txt_Cell", "CITY MOBILE", cx, -0.32,
            z_ins0 + (z_ins1 - z_ins0) * 0.62, 0.36, P["testo_bianco"])
    scritta("Txt_Cell_Sub", "REPAIRS", cx, -0.32,
            z_ins0 + (z_ins1 - z_ins0) * 0.20, 0.28, P["testo_giallo"])
    # Due cartelli soltanto, e grandi. Ce n'erano tre da mezzo metro — undici
    # pixel — e alla riduzione diventavano tre macchie storte sul vetro.
    for i, (fx, fz, w, h) in enumerate([(0.26, 1.90, 0.95, 1.15),
                                        (0.72, 1.95, 0.80, 1.00)]):
        x = f["x0"] + f["w"] * fx
        bx("Cart_Cell_%d" % i, x - w / 2, x + w / 2, 0.26, 0.29,
           fz - h / 2, fz + h / 2,
           [P["ins_gialla"], P["ins_rossa"]][i])


def fronte_condominio(f, P):
    """Il piccolo condominio: niente negozio, portone arretrato con gradini,
    una targa dei campanelli e due finestre sbarrate."""
    mat = P["mattone_condo"]
    porta_x = f["x0"] + 2.0
    pw, ph = 1.35, 2.55
    fin = [(f["x0"] + 4.6, f["x0"] + 5.8, 1.15, 2.60),
           (f["x0"] + 6.8, f["x0"] + 8.0, 1.15, 2.60)]
    fori = [(porta_x - pw / 2, porta_x + pw / 2, 0.0, ph)] + \
           [(a, b, c, d) for (a, b, c, d) in fin]
    muro_forato("Mur_condo_terra", f["x0"], f["x1"], 0.0, H_TERRA, 0.0, SP,
                mat, fori)
    # Atrio acceso dietro al portone e alle finestre sbarrate: senza, il piano
    # terra del condominio e' una fila di buchi neri.
    bx("Condo_Atrio", f["x0"] + 0.3, f["x1"] - 0.3, 1.66, 1.72, 0.0,
       H_TERRA - 0.25, P["interno"])
    bx("Condo_AtrioSoff", f["x0"] + 0.3, f["x1"] - 0.3, SP, 1.72,
       H_TERRA - 0.30, H_TERRA - 0.18, P["zoccolo"])
    # Plafoniera dell'androne: la luce delle scale che si vede dalla strada.
    bx("Condo_AtrioLuce", f["x0"] + 1.1, f["x1"] - 1.1, 1.20, 1.62,
       H_TERRA - 0.62, H_TERRA - 0.50, P["plafoniera"])

    # Portone: cassa arretrata, due battenti a vetro, lunetta e numero civico.
    r = 0.72
    # Il vano del portone e' una FODERA, non un pieno: prima qui c'era una
    # scatola intera che tappava il buco, e l'ingresso usciva nero.
    for dx in (-pw / 2, pw / 2):
        bx("Condo_Vano%.2f" % dx, porta_x + dx - 0.07, porta_x + dx + 0.07,
           SP, r + 0.10, 0.0, ph, P["zoccolo"])
    bx("Condo_VanoSu", porta_x - pw / 2, porta_x + pw / 2, SP, r + 0.10,
       ph - 0.10, ph, P["zoccolo"])
    bx("Condo_VanoGiu", porta_x - pw / 2, porta_x + pw / 2, SP, r + 0.10,
       0.0, 0.05, P["cemento"])
    bx("Condo_Porta", porta_x - pw / 2 + 0.05, porta_x + pw / 2 - 0.05,
       r, r + 0.06, 0.0, ph - 0.55, P["vetro_atrio"])
    bx("Condo_PortaMont", porta_x - 0.04, porta_x + 0.04, r - 0.01, r + 0.08,
       0.0, ph - 0.55, P["legno"])
    bx("Condo_Lunetta", porta_x - pw / 2 + 0.05, porta_x + pw / 2 - 0.05,
       r, r + 0.06, ph - 0.50, ph - 0.10, P["vetro_atrio"])
    bx("Condo_Architrave", porta_x - pw / 2 - 0.22, porta_x + pw / 2 + 0.22,
       -0.16, SP, ph, ph + 0.34, P["cemento"])
    bx("Condo_Stipite_S", porta_x - pw / 2 - 0.22, porta_x - pw / 2,
       -0.10, SP, 0.0, ph, P["cemento"])
    bx("Condo_Stipite_D", porta_x + pw / 2, porta_x + pw / 2 + 0.22,
       -0.10, SP, 0.0, ph, P["cemento"])
    scritta("Condo_Civico", "546", porta_x, -0.18, ph + 0.17, 0.20,
            P["testo_bianco"])
    bx("Condo_Campanelli", porta_x + pw / 2 + 0.26, porta_x + pw / 2 + 0.50,
       -0.05, SP, 1.35, 1.95, P["alluminio"])
    # Gradini d'ingresso.
    for i in range(3):
        bx("Condo_Grad%d" % i, porta_x - pw / 2 - 0.30, porta_x + pw / 2 + 0.30,
           -0.20 - 0.22 * i, r, 0.0 - 0.14 * (i + 1), 0.0 - 0.14 * i,
           P["cemento"])

    for i, (a, b, za, zb) in enumerate(fin):
        finestra("Condo_FinT%d" % i, a, b, za, zb, acceso=True, P=P)
        for g in range(4):
            x = a + (b - a) * g / 3.0
            bx("Condo_Sbarra%d_%d" % (i, g), x - 0.04, x + 0.04, -0.13,
               -0.07, za, zb, P["ferro"])
        bx("Condo_SbarraH%d" % i, a, b, -0.12, -0.08, (za + zb) / 2 - 0.03,
           (za + zb) / 2 + 0.03, P["ferro"])


def guscio(f, P, testata_sx=False, testata_dx=False):
    """Il volume del fabbricato dietro alla facciata di UNA unita'.

    Le testate — i due muri ciechi di spalla — le mette solo chi sta alle
    estremita' del blocco intero. Su un pezzo singolo non ci vanno: le facce
    laterali devono restare a filo esatto della larghezza, o due sprite
    affiancati in Godot non combaciano piu' al pixel.
    """
    if f["chiave"] == "condominio":
        # Anche qui il piano terra e' cavo: dietro al portone e alle finestre
        # sbarrate ci deve stare l'atrio, altrimenti si guarda dentro alla
        # faccia interna del pieno e sono tre buchi neri.
        bx("Corpo_%s_terra" % f["chiave"], f["x0"], f["x1"], 1.75, PROF,
           0.0, H_TERRA, P["zoccolo"])
        bx("Corpo_%s" % f["chiave"], f["x0"], f["x1"], SP, PROF, H_TERRA,
           f["h"], P["mattone_lato"])
    else:
        # Piano terra: il pieno comincia dopo il rientro, cosi' dietro al
        # cristallo c'e' il vuoto del negozio e non il muro. Senza questo la
        # vetrina e' modellata dentro alla massa e non si vede.
        bx("Corpo_%s_terra" % f["chiave"], f["x0"], f["x1"], RIENTRO_NEG,
           PROF, 0.0, H_TERRA, P["zoccolo"])
        bx("Corpo_%s" % f["chiave"], f["x0"], f["x1"], SP, PROF, H_TERRA,
           f["h"], P["mattone_lato"])
        # Divisori tra un negozio e l'altro dentro al rientro.
        for xd in (f["x0"], f["x1"]):
            bx("Divis_%s_%.2f" % (f["chiave"], xd), xd - 0.11, xd + 0.11,
               SP, RIENTRO_NEG, 0.0, H_TERRA, mat_unita(f["chiave"], P))
    bx("Tetto_%s" % f["chiave"], f["x0"], f["x1"], SP, PROF,
       f["h"], f["h"] + 0.12, P["catrame"])
    # Parapetto sugli altri tre lati del tetto.
    bx("ParaR_%s" % f["chiave"], f["x0"], f["x1"], PROF - 0.34, PROF,
       f["h"], f["tetto"] - 0.25, P["mattone_lato"])
    if testata_sx:
        bx("Testata_Sx", f["x0"] - 0.22, f["x0"], -0.05, PROF, 0.0,
           f["tetto"], P["mattone_lato"])
    if testata_dx:
        bx("Testata_Dx", f["x1"], f["x1"] + 0.22, -0.05, PROF, 0.0,
           f["tetto"], P["mattone_lato"])
    # Niente marciapiede (2026-09-21). Qui c'era una lastra profonda 2,60 m
    # davanti a ogni unita', larga quanto il pezzo, che serviva ad appoggiare
    # l'edificio e a far combaciare le unita' affiancate.
    #
    # E' uscita con quelle di tutti gli altri modelli, e la regola adesso e'
    # una sola: **il marciapiede lo disegna il gioco** (`city_ground.gd`).
    # Uno disegnato dentro allo sprite e' una seconda lastra, con un grigio
    # suo, appoggiata sopra a quella vera — e il bordo fra i due si vede.
    #
    # Le unita' continuano a combaciare senza: erano larghe uguali al pezzo,
    # quindi non e' la lastra a tenerle allineate ma la `base.x` che hanno in
    # `city_map.gd`. Quello che cambia e' il bordo INFERIORE dello sprite, che
    # adesso e' la riga di terra del muro invece di una lastra un metro piu'
    # avanti: e va rifatta l'altezza in `ASSETS` di `import_flats_art.py`.


def tetto(fette, P):
    """Quello che si vede del tetto con la camera a 27 gradi: torrino scale,
    condizionatori, comignoli e il serbatoio d'acqua in legno."""
    for f in fette:
        z = f["h"] + 0.12
        cx = (f["x0"] + f["x1"]) / 2.0
        bx("Torrino_%s" % f["chiave"], cx - 1.05, cx + 0.35, PROF - 3.4,
           PROF - 1.9, z, z + 2.05, P["mattone_lato"])
        bx("TorrinoT_%s" % f["chiave"], cx - 1.15, cx + 0.45, PROF - 3.5,
           PROF - 1.8, z + 2.05, z + 2.17, P["catrame"])
        for i in range(2):
            x = cx + 1.1 + i * 1.3
            if x > f["x1"] - 0.5:
                continue
            bx("Unita_%s_%d" % (f["chiave"], i), x - 0.55, x + 0.55,
               PROF - 3.0, PROF - 1.9, z, z + 0.72, P["alluminio"])
        cilindro("Comignolo_%s" % f["chiave"],
                 (f["x0"] + 0.7, PROF - 1.2, z + 0.75), 0.16, 1.5, P["ferro"],
                 lati=10)

    # Serbatoio in legno sul tetto del negozio di vestiti: e' la silhouette che
    # fa New York. Sta su una sola unita', e se quella non c'e' non si disegna:
    # un serbatoio replicato su ogni pezzo, rimessi in fila, diventa quattro.
    f = next((x for x in fette if x["chiave"] == "vestiti"), None)
    if f is None:
        return
    cx = (f["x0"] + f["x1"]) / 2.0 + 0.4
    z = f["h"] + 0.12
    for dx in (-0.75, 0.75):
        for dy in (-0.75, 0.75):
            bx("Serb_Gamba%.1f%.1f" % (dx, dy), cx + dx - 0.09, cx + dx + 0.09,
               PROF - 5.0 + dy - 0.09, PROF - 5.0 + dy + 0.09, z, z + 1.35,
               P["ferro"])
    cilindro("Serbatoio", (cx, PROF - 5.0, z + 2.30), 1.02, 1.95, P["legno"],
             lati=16)
    for zz in (z + 1.60, z + 2.95):
        cilindro("Serb_Cerchio%.2f" % zz, (cx, PROF - 5.0, zz), 1.06, 0.09,
                 P["ferro"], lati=16)
    bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=1.16, radius2=0.06,
                                    depth=0.62,
                                    location=(cx, PROF - 5.0, z + 3.58))
    cono = bpy.context.active_object
    cono.name = "Serb_Cappello"
    cono.data.materials.append(P["ferro"])


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
    cam.rotation_euler = (math.radians(90.0 - INCLINAZIONE), 0.0, 0.0)
    sc.camera = cam

    sole = bpy.data.lights.new("SUN", type="SUN")
    sole.energy = 3.4
    sole.color = (1.0, 0.95, 0.88)
    sole.angle = math.radians(1.0)
    ob = bpy.data.objects.new("SUN", sole)
    sc.collection.objects.link(ob)
    ob.rotation_euler = (math.radians(58), 0.0, math.radians(-46))

    riemp = bpy.data.lights.new("FILL", type="SUN")
    riemp.energy = 0.95
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

    try:
        sc.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        try:
            sc.render.engine = "BLENDER_EEVEE"
        except TypeError:
            pass
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
    sc.view_settings.view_transform = "Standard"

    # Freestyle: contorno spesso fuori, spigoli sottili dentro.
    sc.render.use_freestyle = True
    sc.render.line_thickness_mode = "ABSOLUTE"
    sc.render.line_thickness = 1.0
    fs = bpy.context.view_layer.freestyle_settings
    fs.mode = "EDITOR"
    for ls in list(fs.linesets):
        fs.linesets.remove(ls)
    fs.crease_angle = math.radians(85.0)
    fuori = fs.linesets.new("Contorno")
    for a in ("select_crease", "select_ridge_valley", "select_suggestive_contour",
              "select_material_boundary", "select_edge_mark"):
        setattr(fuori, a, False)
    fuori.select_silhouette = True
    fuori.select_border = True
    fuori.linestyle.color = (0.030, 0.023, 0.019)
    # 3,2 e non 6,5 come nel quartiere povero. Il numero non si copia da un
    # altro edificio: dipende da quanti spigoli ha il modello. Gli edifici di
    # `render_buildings.py` sono quattro mesh lisce e reggono una linea spessa;
    # qui ogni finestra ha telaio, davanzale e architrave, e a ventidue pixel
    # per metro una finestra e' alta sedici pixel — con la linea a 6,5 i
    # contorni dei dettagli si toccavano fra loro e la facciata usciva nera.
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


def inquadra(cam, fette, margine=0.30):
    """Inquadratura che fa combaciare i pezzi rimessi in fila.

    In orizzontale il riquadro NON si stringe sull'ingombro: vale esattamente
    la larghezza dell'unita', senza margine. Cosi' lo sprite e' largo
    `larghezza * PX_PER_METRO` e due sprite affiancati in Godot si toccano
    dove si toccavano i muri. Stringendosi sui pixel disegnati, il pezzo con
    l'insegna sporgente uscirebbe piu' largo del suo lotto e la fila si
    sfalserebbe.

    In verticale il riquadro segue l'ingombro, perche' le unita' sono alte
    diverse; in gioco si allineano sul bordo basso, che e' lo stesso per tutte
    — il marciapiede.
    """
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    punti = []
    for obj in bpy.data.objects:
        if obj.type not in ("MESH", "FONT") or obj.hide_render:
            continue
        # Sui VERTICI e non sul bound box. Il riquadro di un oggetto e' un
        # parallelepipedo allineato agli assi, e con la camera inclinata i suoi
        # spigoli finti — "il marciapiede davanti all'altezza del tetto" — sono
        # piu' in alto di qualunque pezzo vero: unita in una mesh sola, le
        # quattro unita' si portavano dietro un metro di cielo vuoto in cima.
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
    miny, maxy = min(p.y for p in vista), max(p.y for p in vista)
    # Senza imbardata la x della camera e' la x del mondo: i bordi del lotto si
    # prendono direttamente dalle fette invece che dal bounding box.
    minx, maxx = fette[0]["x0"], fette[-1]["x1"]
    larg = maxx - minx
    alt = (maxy - miny) + 2 * margine
    cam.location = cam.matrix_world @ Vector(
        ((minx + maxx) / 2.0, (miny + maxy) / 2.0, 120.0))
    cam.data.ortho_scale = max(larg, alt)
    sc = bpy.context.scene
    sc.render.resolution_x = int(round(larg * PX_PER_METRO))
    sc.render.resolution_y = int(round(alt * PX_PER_METRO))
    return larg, alt


def modo_luci():
    """Riduce la scena a quello che di notte resta acceso, per il secondo PNG.

    Stessa logica di `render_buildings.modo_luci()`: di notte il
    `CanvasModulate` della citta' moltiplica lo sprite per il blu della sera e
    una finestra dipinta gialla viene fuori marrone. Il secondo scatto e' lo
    stesso edificio, stessa camera e stessa inquadratura, con dentro solo cio'
    che il modello dichiara gia' emissivo — vetrine, plafoniere, neon,
    lanterne, insegne — su fondo nero.

    L'albero del materiale si riscrive invece di spegnere gli ingressi uno per
    uno, perche' i mattoni hanno il colore COLLEGATO al Base Color e un valore
    scritto sopra a un ingresso collegato non lo guarda nessuno.
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
        # Il vetro semitrasparente torna pieno: una vetrina accesa vista
        # attraverso un'altra vetrina accesa raddoppia la luce.
        if hasattr(mat, "surface_render_method"):
            try:
                mat.surface_render_method = "DITHERED"
            except TypeError:
                pass
        if hasattr(mat, "blend_method"):
            try:
                mat.blend_method = "OPAQUE"
            except TypeError:
                pass


def _in_collezione(chiave, oggetti_prima):
    """Mette in una collezione propria tutto quello che l'unita' ha creato.

    I negozi sono cose separate anche dentro Blender: in gioco alcuni si
    cliccano e altri no, quindi ognuno deve potersi selezionare, esportare e
    spostare da solo senza pescare le sue scatole in mezzo a quelle dei vicini.
    """
    coll = collezione("ISO_" + chiave)
    for ob in bpy.data.objects:
        if ob in oggetti_prima or ob.type not in ("MESH", "FONT"):
            continue
        if coll not in ob.users_collection:
            coll.objects.link(ob)
        for altra in list(ob.users_collection):
            if altra is not coll and altra.name != COLL_TESTI:
                altra.objects.unlink(ob)
    return coll


def costruisci(chiavi=None):
    """Costruisce le unita' chieste; senza argomenti, l'isolato intero.

    Ogni unita' finisce in una collezione sua (`ISO_<nome>`) e, costruita da
    sola, e' gia' centrata e inquadrata per il suo render. E' lo stesso codice
    per il pezzo singolo e per il blocco: le misure non possono divergere.
    """
    pulisci()
    P = palette()
    fette, larg = quote(chiavi)
    intero = len(fette) == len(UNITA)
    per_fronte = {"ristorante": fronte_ristorante, "vestiti": fronte_vestiti,
                  "cellulari": fronte_cellulari,
                  "condominio": fronte_condominio}
    for i, f in enumerate(fette):
        prima = set(bpy.data.objects)
        guscio(f, P, testata_sx=(intero and i == 0),
               testata_dx=(intero and i == len(fette) - 1))
        facciata_piani(f, P)
        cornicione(f, P)
        if f["chiave"] != "condominio":
            # Muro di mattoni del piano terra ai lati della vetrina: la vetrina
            # non arriva ai muri divisori, il mattone si vede.
            muro_forato("Mur_%s_terra" % f["chiave"], f["x0"], f["x1"], 0.0,
                        H_TERRA, 0.0, SP, mat_unita(f["chiave"], P),
                        [(f["x0"] + 0.10, f["x1"] - 0.10, 0.0, H_TERRA - 0.10)])
        per_fronte[f["chiave"]](f, P)
        if f["chiave"] == "condominio":
            # Scala antincendio sul condominio e non sul ristorante. Col
            # ballatoio che sporge di un metro e la camera inclinata di 27
            # gradi, il pianerottolo del primo livello si proietta mezzo metro
            # piu' in basso di dove sta: sul ristorante tagliava a meta' la
            # scritta dell'insegna. Sul condominio cade su muro cieco, ed e'
            # anche il posto dove una scala antincendio si vede davvero.
            scala_antincendio(
                f["x0"] + 4.2, f["x0"] + 8.2,
                [H_TERRA + i * H_PIANO for i in range(f["piani"])], P)
        tetto([f], P)
        # Una mesh sola per unita': e' quello che toglie il bordo nero da ogni
        # singola scatola e fa correre il mattone su tutta la facciata. Vedi
        # `unisci()`. Restano fuori le scritte e le lanterne, che stanno nella
        # collezione senza contorno e non devono finire dentro alla silhouette.
        corpo = [ob for ob in bpy.data.objects
                 if ob not in prima and ob.type == "MESH"
                 and COLL_TESTI not in [c.name for c in ob.users_collection]]
        unisci(corpo, "ISO_%s_corpo" % f["chiave"])
        _in_collezione(f["chiave"], prima)
    cam = scena()
    return inquadra(cam, fette)


def renderizza(cartella=None, luci=True):
    """Un PNG per unita', piu' l'isolato intero, alla risoluzione di gioco.

    Il ridimensionamento e il ritaglio non si fanno qui: come per gli altri
    edifici il render va in `_source/` a risoluzione piena, e ci pensa
    `import_flats_art.py`, che sa gia' premoltiplicare l'alpha.
    """
    if cartella is None:
        cartella = os.path.abspath(os.path.join(
            os.path.dirname(os.path.abspath(__file__)), os.pardir, "assets",
            "sprites", "buildings", "_source"))
    os.makedirs(cartella, exist_ok=True)
    fatti = []
    lavori = [(u[0], [u[0]]) for u in UNITA] + [("isolato", None)]
    for nome, chiavi in lavori:
        costruisci(chiavi)
        sc = bpy.context.scene
        sc.render.resolution_percentage = SUPERSAMPLING * 100
        sc.render.filepath = os.path.join(cartella,
                                          "render_cinese_%s.png" % nome)
        bpy.ops.render.render(write_still=True)
        fatti.append((nome, sc.render.resolution_x, sc.render.resolution_y))
        if luci:
            modo_luci()
            sc.render.filepath = os.path.join(cartella,
                                              "luci_cinese_%s.png" % nome)
            bpy.ops.render.render(write_still=True)
    return fatti


if __name__ == "__main__":
    print("ISOLATO", costruisci())
