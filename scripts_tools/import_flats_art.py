"""Porta i disegni grezzi del quartiere povero alla scala del gioco.

I PNG che arrivano dal disegnatore sono grandi (1100-1450 px di lato) e
inquadrati ciascuno sul proprio soggetto: la casetta a un piano occupa il suo
canvas quanto il palazzo di sei piani occupa il suo. A schermo devono invece
stare tutti nella stessa citta', e la scala giusta non si ricava dal file: e'
quello che fa la tabella `ASSETS`.

**Per i disegni la taglia si decide, per i render no.** Gli edifici costruiti in
Blender escono da `render_buildings.py`, che li fotografa a 22,3 px per metro —
la scala del personaggio, che e' alto 39 px per 1,75 m. Per quelli l'altezza da
scrivere qui sotto non si sceglie a occhio: la stampa lo script, ed e' una
conseguenza dell'ingombro reale in metri. Sceglierla a mano vuol dire rimettere
gli edifici fuori scala rispetto alla gente che ci cammina davanti, che e'
esattamente l'errore che aveva la prima versione.

Due accortezze, senza le quali il risultato e' sporco in modo poco ovvio:

- **Premoltiplicazione.** Nei PNG i pixel trasparenti sono neri (RGB 0,0,0 con
  alpha 0). Ridimensionando l'RGBA cosi' com'e', il filtro media quel nero coi
  pixel opachi vicini e lascia un bordo scuro tutto intorno al disegno. Quindi
  si moltiplica il colore per l'alpha, si scala, e si divide di nuovo.
- **Ritaglio prima di scalare.** Il margine vuoto non e' lo stesso in tutti i
  file: tenerlo vorrebbe dire che la stessa richiesta di larghezza produce
  edifici di taglia diversa. Si taglia sull'alpha e la larghezza richiesta e'
  quella del disegno vero.

Dove accanto al render c'e' anche lo scatto delle luci (`luci_<nome>.png`, vedi
`modo_luci()` in `render_buildings.py`) esce un secondo PNG, `<nome>Lit.png`:
le finestre accese su fondo trasparente, con lo STESSO ritaglio e la stessa
taglia del disegno, che in gioco ci si appoggia sopra.

Uso:
  python scripts_tools/import_flats_art.py
"""

import glob
import os

import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
BUILDINGS = os.path.join(HERE, os.pardir, "assets", "sprites", "buildings")
# Gli originali stanno in una sottocartella con dentro un `.gdignore`, e non
# accanto agli sprite finiti: sono dodici megabyte che il gioco non carica, e
# lasciati nell'albero degli asset Godot li importerebbe come texture e se li
# porterebbe dietro nell'export.
SOURCE = os.path.join(BUILDINGS, "_source")

# Sotto a questo alpha un pixel e' margine vuoto, non disegno: serve a
# ritagliare senza tenersi le sfumature di bordo, che arrivano quasi a zero ma
# non a zero.
TRIM_ALPHA = 8

# sorgente -> (nome finale, larghezza a schermo in px)
#
# La larghezza e' la misura buona da decidere per tutti tranne il palazzo: gli
# altri sono lotti visti di fronte, e quanto occupano di fronte strada e' la
# cosa che va guardata accanto ai vicini. Il palazzo invece va deciso in
# altezza — e' il pezzo piu' alto del quartiere, e quanto svetta e' il punto —
# quindi per lui si scrive l'altezza e la larghezza viene dietro.
# Il condominio non e' piu' un disegno ma un render: lo costruisce e lo
# fotografa `render_buildings.py`, e da qui in poi passa per la stessa riduzione
# degli altri. Il disegno verde di partenza resta in `_source/` come
# "asset quartiere povero.png": per tornare indietro basta rimettere quel nome
# qui sotto.
ASSETS = [
    # Condominio e casa: 694 e 361 e non 692 e 359, e la differenza non e' una
    # taglia nuova — e' la STESSA taglia dopo aver tolto i rovi dal cortile.
    # Le scatole di erbaccia sbordavano dai lati del lotto, quindi entravano nel
    # ritaglio: tolte quelle, il ritaglio si stringe, e chiedendo la stessa
    # altezza di prima l'edificio dentro sarebbe venuto piu' piccolo del vicino
    # a cui ha il muro attaccato. I due numeri vengono dalla larghezza del corpo
    # misurata sul PNG vecchio (310 px e 211 px): sono quelli che la riportano
    # identica.
    ("render_condominio.png", "tenement", None, 694),
    ("render_casa.png", "flatsHouse", None, 361),
    # --- la schiera, dopo che i modelli hanno perso il marciapiede ---------
    #
    # Queste otto altezze sono cambiate il 2026-09-21, e **non e' una taglia
    # nuova**: e' la stessa taglia senza la lastra di marciapiede che i modelli
    # si portavano dentro allo sprite (vedi la nota in cima a
    # `render_buildings.py`). L'edificio a schermo e' identico a prima, gli e'
    # sparita da sotto una striscia di trenta pixel.
    #
    # **Non sono il ritaglio netto diviso quattro**, che sarebbe la regola per
    # un render nuovo, e il motivo e' che questi otto non ci sono mai stati: i
    # valori vecchi venivano dal numero stampato da `render_buildings.py`, che
    # e' l'inquadratura MARGINE COMPRESO, quindi stavano un 7% sopra ai 22,3
    # px/m. Ricalcolarli sul netto li avrebbe rimpiccioliti tutti di quel 7% —
    # e l'agenzia ha il muro ATTACCATO a quello di casa (vedi `BUILDINGS` in
    # `city_map.gd`), che invece resta a 361. Fra i due si sarebbe aperto un
    # buco.
    #
    # Il conto e' quindi a proporzione, sul ritaglio: la lastra valeva 120 px
    # di render (2,70 m di profondita' e 14 cm di spessore visti a 27 gradi,
    # per 22,3 px/m per quattro), quindi
    #
    #     nuova = vecchia * netto / (netto + 120)
    #
    # che e' esattamente cio' che tiene ferma anche la LARGHEZZA, perche' la
    # lastra era larga quanto l'edificio e il ritaglio in orizzontale non e'
    # cambiato. Le larghezze finali infatti sono le stesse di prima, a meno di
    # un pixel: 227, 196, 210, 181, 161, 263, 283, 223.
    ("render_agenzia.png", "realEstate", None, 301),
    ("render_garage.png", "garage", None, 163),
    ("render_bodega.png", "bodega", None, 222),
    ("render_lavanderia.png", "laundry", None, 216),
    ("render_liquori.png", "liquorStore", None, 215),
    ("render_officina.png", "autoRepair", None, 185),
    ("render_caseggiato.png", "rowBlock", None, 359),
    ("render_pensione.png", "rooming", None, 296),
    # Primo edificio del quartiere benestante: la clinica dove lavora Brian.
    ("render_clinica.png", "clinic", None, 428),
    # Primo edificio di DOWNTOWN: il grossista dei semi. L'altezza e' l'ingombro
    # NETTO e non quello che stampa `render_buildings.py`, che e'
    # l'inquadratura MARGINE COMPRESO. Il numero esatto non va stimato: il
    # render e' gia' a 22,3 px/m per quattro, quindi e' l'altezza del ritaglio
    # sull'alpha diviso il supersampling, 1160 / 4.
    #
    # Era 299 (1196 / 4) e adesso e' 290, per il marciapiede tolto dal modello.
    # Qui il conto resta quello del netto — a differenza della schiera, questo
    # era gia' calcolato bene — e cambia anche la LARGHEZZA, da 645 a 631: la
    # lastra era larga 28,8 m contro i 21,6 dell'edificio, quindi sbordava di
    # tre metri e mezzo per parte. E' per quello che `click` in `city_map.gd`
    # doveva essere piu' corto dello sprite; adesso non piu'.
    ("render_magazzino.png", "wholesale", None, 290),
    # Le strutture del campo da football abbandonato. Non sono edifici: entrano
    # in città come props (vedi `CityMap.field_props()`). L'erba del campo non
    # è qui perché non è un PNG — la disegna uno shader di Godot.
    # ATTENZIONE alle altezze: `render_buildings.py` stampa un numero ricavato
    # dall'inquadratura MARGINE COMPRESO, mentre qui si ritaglia il margine
    # prima di scalare. Su un edificio grande la differenza e' il tre per
    # cento; su una porta da calcio alta tre metri il margine e' un quarto
    # dell'inquadratura, e la porta veniva fuori larga undici metri invece di
    # sette. Questi tre numeri vengono dall'ingombro NETTO.
    # L'isolato cinese: quattro unita' di uno stesso fabbricato, renderizzate
    # separate da `blender_isolato_cinese.py` perche' in gioco alcune si
    # cliccano e altre no (vedi la nota su `costruisci()` li' dentro).
    #
    # Qui si scrive la LARGHEZZA e non l'altezza, e i numeri non si scelgono:
    # sono la larghezza del lotto in metri per 22,3 px/m — 8,2 / 6,6 / 5,4 /
    # 9,2 metri. E' quello che le fa ricombaciare quando in citta' si rimettono
    # una di fianco all'altra: cambiarne uno "a occhio" sfalsa la fila di
    # qualche pixel, e il muro in comune si vede doppio o si sovrappone.
    #
    # L'altezza viene dietro da se', ed e' giusto che sia diversa: il render di
    # ogni unita' ha lo stesso margine sotto, quindi i quattro PNG hanno la
    # riga di terra alla stessa quota e in citta' basta dare a tutte la stessa
    # `base.y`.
    ("render_cinese_ristorante.png", "chineseRestaurant", 183, None),
    ("render_cinese_vestiti.png", "clothesShop", 147, None),
    ("render_cinese_cellulari.png", "phoneShop", 120, None),
    ("render_cinese_condominio.png", "smallApartments", 205, None),
    # I due grattacieli di DOWNTOWN. Oltre al disegno e alle luci hanno un
    # terzo scatto, `vetro_*.png`: la maschera che dice allo shader dove il
    # vetro guarda a est, a sud e a ovest. Vedi `blender_grattacieli.py`.
    ("render_meridian.png", "meridianTower", 305, None),
    ("render_harbor.png", "harborHeights", 272, None),
    # HOLLY LOFTS, il condominio d'angolo accanto ai grattacieli
    # (`blender_holly_lofts.py`). 597 non e' scelto: e' il ritaglio netto del
    # render diviso il supersampling (2390 / 4), cioe' i 26,6 m dell'edificio
    # (tetto a sbalzo compreso) a 22,3 px/m.
    ("render_holly.png", "hollyLofts", 597, None),
    # La casa gialla di CROSS STREET. L'altezza e' il ritaglio NETTO del render
    # diviso il supersampling (1348 / 4), non quella che stampa lo script. Ha anche
    # le strisce delle cose che si muovono (girandola, bandiera): vedi
    # `animazioni()` qui sotto.
    ("render_casa_gialla.png", "yellowHouse", None, 337),
    # Il negozio di bici accanto al garage, su CROSS STREET
    # (`blender_bici.py`). La LARGHEZZA e' il lotto: dal muro del garage al
    # marciapiede di MILL ROAD, 322 px. Ha tre strisce animate: la ruota sul
    # cavalletto, l'insegna appesa, il neon OPEN.
    ("render_bici.png", "bikeShop", 322, None),
    # L'aeroporto di CIVIC CENTER (`blender_aeroporto.py`): due hangar e la
    # torre di controllo, larghi quanto i loro lotti a 22,3 px/m.
    ("render_aero_hangar_grande.png", "hangarLarge", 424, None),
    ("render_aero_hangar_piccolo.png", "hangarSmall", 290, None),
    ("render_aero_torre.png", "controlTower", 178, None),
    # Il negozio di videogiochi e il cinema del COMMERCIAL DISTRICT: due unita'
    # di uno stesso fabbricato, come l'isolato cinese
    # (`blender_cinema_videogiochi.py`). La LARGHEZZA e' il lotto a 22,3 px/m —
    # 8,6 e 11,4 m — ed e' quella che le fa ricombaciare in citta'.
    ("render_videogiochi.png", "gameShop", 192, None),
    ("render_cinema.png", "cinema", 254, None),
    # Lo STAR CASINO (`blender_casino.py`): largo l'isolato intero fra EAST
    # STREET e HILL DRIVE, 27,2 m a 22,3 px/m.
    ("render_casino.png", "casino", 606, None),
    # L'isolato commerciale di DOWNTOWN, quattro unita' di un fabbricato solo
    # (`blender_isolato_downtown.py`): le larghezze sono i lotti a 22,3 px/m e
    # fanno 656, l'isolato intero fra LOCK STREET e SEVENTH STREET.
    ("render_dt_agenzia.png", "primeRealty", 192, None),
    ("render_dt_lavanderia.png", "laundromat", 152, None),
    ("render_dt_vestiti.png", "clothingStore", 170, None),
    ("render_dt_diner.png", "diner", 142, None),
    # L'officina e' una STRISCIA di fotogrammi e non un PNG solo: la stella nel
    # nome sorgente e' quello che lo dice. Dodici scatti della stessa
    # inquadratura con la serranda a diverse altezze — vedi
    # `blender_officina.py` — che in gioco scorrono con l'ora
    # (`shop_shutter.gd`). La taglia scritta qui e' quella del SINGOLO
    # fotogramma; il PNG finito e' dodici volte piu' largo.
    ("render_officina_*.png", "autoShop", 272, None),
    # Lo stadio di CIVIC CENTER, da `blender_stadio.py`. Qui si scrive la
    # LARGHEZZA e non l'altezza, ed e' l'unico edificio per cui ha senso: di
    # tutti gli altri conta quanto svettano, di questo conta che stia
    # nell'isolato. 646 px e' il ritaglio netto del render diviso il
    # supersampling (2584 / 4), quindi non e' una taglia scelta — e' l'ingombro
    # vero a 22,3 px/m. L'altezza viene dietro da se': 628.
    ("render_stadio.png", "stadium", 646, None),
    ("render_gradinata.png", "terrace", None, 124),
    ("render_torre_faro.png", "floodlight", None, 356),
    ("render_porta_campo.png", "goal", None, 63),
]


def riquadro(im):
    """Il rettangolo del disegno dentro al canvas, sull'alpha e non sul colore.

    Torna il riquadro invece dell'immagine ritagliata perche' serve DUE volte:
    una per il disegno e una per il suo scatto delle luci, che va ritagliato
    esattamente allo stesso modo. Ritagliandoli ognuno sul proprio alpha si
    otterrebbero due immagini di dimensioni diverse — lo scatto delle luci e'
    quasi tutto nero e il suo alpha copre anche i pixel spenti, ma i contorni
    Freestyle ci sono solo nel primo — e in gioco le finestre accese si
    troverebbero due pixel a fianco delle finestre.
    """
    alpha = np.asarray(im.getchannel("A"))
    rows = np.where(alpha.max(axis=1) >= TRIM_ALPHA)[0]
    cols = np.where(alpha.max(axis=0) >= TRIM_ALPHA)[0]
    return (cols[0], rows[0], cols[-1] + 1, rows[-1] + 1)


def scale(im, width, height):
    """Riduce alla taglia chiesta senza l'alone nero dei bordi.

    Il lato non specificato segue le proporzioni del disegno ritagliato: sono
    disegni, non atlanti, e deformarli per far tornare un numero tondo si
    vedrebbe.
    """
    if width is None:
        width = max(1, round(im.width * height / im.height))
    if height is None:
        height = max(1, round(im.height * width / im.width))

    rgba = np.asarray(im, dtype=np.float64) / 255.0
    a = rgba[:, :, 3:4]
    premultiplied = np.concatenate([rgba[:, :, :3] * a, a], axis=2)

    small = Image.fromarray(
        (np.clip(premultiplied, 0.0, 1.0) * 255.0).round().astype(np.uint8), "RGBA"
    ).resize((width, height), Image.LANCZOS)

    out = np.asarray(small, dtype=np.float64) / 255.0
    a = out[:, :, 3:4]
    # Dove non e' rimasto niente di opaco il colore e' indefinito: dividere per
    # zero darebbe NaN, e il pixel e' invisibile comunque.
    rgb = np.divide(out[:, :, :3], a, out=np.zeros_like(out[:, :, :3]), where=a > 0)
    result = np.concatenate([np.clip(rgb, 0.0, 1.0), a], axis=2)
    return Image.fromarray((result * 255.0).round().astype(np.uint8), "RGBA")


def luci(im):
    """Da "nero con dentro le cose accese" a "solo le cose accese".

    Lo scatto delle luci di `render_buildings.py` e' un'immagine opaca: fondo
    nero e sopra le finestre accese. Appoggiata cosi' com'e' sull'edificio lo
    coprirebbe di nero. Qui il nero diventa trasparenza — l'opacita' di ogni
    pixel e' quanto quel pixel e' luminoso — e il colore resta quello della
    luce, riportato a piena intensita' perche' a deciderne la forza ci pensa
    il gioco a seconda dell'ora.
    """
    rgb = np.asarray(im.convert("RGB"), dtype=np.float64) / 255.0
    a = rgb.max(axis=2, keepdims=True)
    colore = np.divide(rgb, a, out=np.zeros_like(rgb), where=a > 0.0)
    out = np.concatenate([np.clip(colore, 0.0, 1.0), a], axis=2)
    return Image.fromarray((out * 255.0).round().astype(np.uint8), "RGBA")


## Raggio dell'alone intorno alle finestre accese, in pixel dello sprite.
ALONE = 2.2
## Quanto e' forte. Sopra 0,5 le finestre di un palazzo si saldano in una
## macchia sola e il palazzo sembra in fiamme invece che abitato.
ALONE_FORZA = 0.42


def alone(im):
    """Aggiunge la sfumatura intorno alle luci.

    A ventidue pixel per metro una finestra e' alta quattro pixel, e da lontano
    di una finestra accesa si vede l'alone molto prima del vetro: senza, le
    luci sono puntini netti che sembrano pixel morti. Lo faceva anche il
    segnaposto (`building_placeholder.gd`), disegnando un rettangolo sfumato
    intorno a ogni vetro.

    La sfocatura va fatta col colore premoltiplicato per l'alpha: sfocando
    l'RGBA cosi' com'e', il nero dei pixel trasparenti si mescola al colore e
    l'alone esce sporco di grigio.
    """
    src = np.asarray(im, dtype=np.float64) / 255.0
    a = src[:, :, 3:4]
    pre = Image.fromarray(
        (np.clip(np.concatenate([src[:, :, :3] * a, a], axis=2), 0.0, 1.0)
         * 255.0).round().astype(np.uint8), "RGBA")
    sfocato = np.asarray(pre.filter(ImageFilter.GaussianBlur(ALONE)),
                         dtype=np.float64) / 255.0
    ga = sfocato[:, :, 3:4]
    grgb = np.divide(sfocato[:, :, :3], ga, out=np.zeros_like(sfocato[:, :, :3]),
                     where=ga > 0.0)
    velo = Image.fromarray((np.concatenate(
        [np.clip(grgb, 0.0, 1.0), ga * ALONE_FORZA], axis=2)
        * 255.0).round().astype(np.uint8), "RGBA")
    return Image.alpha_composite(velo, im)


def riquadro_comune(immagini):
    """Il ritaglio buono per TUTTI i fotogrammi di una striscia.

    Uno per fotogramma non va: la serranda che scende cambia di poco l'ingombro
    opaco, e ogni fotogramma verrebbe ritagliato e scalato in modo diverso. In
    gioco l'edificio si metterebbe a ballare di un pixel mentre la serranda si
    chiude. Si prende l'unione, e vale per tutti.
    """
    box = None
    for im in immagini:
        b = riquadro(im)
        box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]),
                                     max(box[2], b[2]), max(box[3], b[3]))
    return box


def striscia(sorgenti, width, height):
    """Mette i fotogrammi uno di fianco all'altro, tutti della stessa taglia."""
    interi = [Image.open(f).convert("RGBA") for f in sorgenti]
    box = riquadro_comune(interi)
    pezzi = [scale(im.crop(box), width, height) for im in interi]
    w, h = pezzi[0].size
    tela = Image.new("RGBA", (w * len(pezzi), h), (0, 0, 0, 0))
    for i, pezzo in enumerate(pezzi):
        tela.paste(pezzo, (i * w, 0))
    return tela, box, (w, h)


def animazioni(source, name, box, art):
    """Le cose che si muovono sopra a un edificio: girandola, bandiera.

    `render_buildings.py` le fotografa da sole, fotogramma per fotogramma, con
    la stessa camera del disegno (`anim_<edificio>_<cosa>_NN.png`). Qui ogni
    fotogramma passa dallo STESSO ritaglio e dalla stessa riduzione del
    disegno — o in gioco la girandola girerebbe un pixel a fianco del suo palo
    — e poi si tiene solo il riquadro in cui la cosa si muove, comune a tutti i
    fotogrammi, messi in fila in una striscia `<nome><Cosa>.png`.

    Stampa la voce da mettere in `anims` in `city_map.gd`: `at` e' l'angolo in
    alto a sinistra della striscia rispetto alla base dell'edificio.
    """
    base = source.replace("render_", "anim_").replace(".png", "")
    gruppi = {}
    for f in sorted(glob.glob(os.path.join(SOURCE, base + "_*_[0-9][0-9].png"))):
        cosa = os.path.basename(f)[len(base) + 1:-7]
        gruppi.setdefault(cosa, []).append(f)
    for cosa, fotogrammi in gruppi.items():
        pezzi = [scale(Image.open(f).convert("RGBA").crop(box), art.width, art.height)
                 for f in fotogrammi]
        riq = riquadro_comune(pezzi)
        pezzi = [p.crop(riq) for p in pezzi]
        w, h = pezzi[0].size
        tela = Image.new("RGBA", (w * len(pezzi), h), (0, 0, 0, 0))
        for i, p in enumerate(pezzi):
            tela.paste(p, (i * w, 0))
        file = name + cosa[:1].upper() + cosa[1:]
        tela.save(os.path.join(BUILDINGS, file + ".png"))
        print('%-16s   anim %-10s {"texture": "res://assets/sprites/buildings/%s.png", '
              '"at": Vector2(%d, %d), "frames": %d}'
              % (name, cosa, file, -art.width // 2 + riq[0], -art.height + riq[1],
                 len(pezzi)))


def main():
    for source, name, width, height in ASSETS:
        if "*" in source:
            sorgenti = sorted(glob.glob(os.path.join(SOURCE, source)))
            if not sorgenti:
                print("%-16s nessun fotogramma per %s" % (name, source))
                continue
            art, box, (fw, fh) = striscia(sorgenti, width, height)
            art.save(os.path.join(BUILDINGS, name + ".png"))
            acceso = os.path.join(
                SOURCE, source.replace("render_", "luci_").replace("_*", ""))
            if os.path.isfile(acceso):
                lit = luci(Image.open(acceso).convert("RGB").crop(box))
                lit = alone(scale(lit, fw, fh))
                if np.asarray(lit.getchannel("A")).max() >= TRIM_ALPHA:
                    lit.save(os.path.join(BUILDINGS, name + "Lit.png"))
            print('%-16s %3dx%-3d x%d  "offset": Vector2(%d, %d), '
                  '"click": Rect2(%d, %d, %d, %d), "frames": %d'
                  % (name, fw, fh, len(sorgenti), -fw // 2, -fh,
                     -fw // 2, -fh, fw, fh, len(sorgenti)))
            continue
        path = os.path.join(SOURCE, source)
        intero = Image.open(path).convert("RGBA")
        box = riquadro(intero)
        art = scale(intero.crop(box), width, height)
        out = os.path.join(BUILDINGS, name + ".png")
        art.save(out)
        # Lo scatto delle luci, se c'e': stesso ritaglio e stessa taglia del
        # disegno, o in gioco si appoggia storto.
        acceso = os.path.join(SOURCE, source.replace("render_", "luci_"))
        if os.path.isfile(acceso):
            lit = luci(Image.open(acceso).convert("RGB").crop(box))
            lit = alone(scale(lit, art.width, art.height))
            if np.asarray(lit.getchannel("A")).max() >= TRIM_ALPHA:
                lit.save(os.path.join(BUILDINGS, name + "Lit.png"))
        # La maschera del vetro, se c'e': stesso ritaglio e stessa taglia del
        # disegno, come per le luci. Qui pero' NON si passa da `luci()` ne' da
        # `alone()`: quelli servono a trasformare del nero in trasparenza e ad
        # aggiungere un alone, e questo file non e' un'immagine da guardare —
        # e' un dato che lo shader legge canale per canale. Sfumarlo vorrebbe
        # dire dire allo shader che il vetro guarda un po' dappertutto.
        vetro = os.path.join(SOURCE, source.replace("render_", "vetro_"))
        if os.path.isfile(vetro):
            maschera = scale(Image.open(vetro).convert("RGBA").crop(box),
                             art.width, art.height)
            maschera.save(os.path.join(BUILDINGS, name + "Glass.png"))

        animazioni(source, name, box, art)

        # Le coordinate da incollare in `city_map.gd`: l'origine di un edificio
        # e' il punto a terra al centro della facciata, quindi il disegno sta
        # tutto sopra e mezzo per parte.
        print(
            '%-16s %3dx%-3d  "offset": Vector2(%d, %d), "click": Rect2(%d, %d, %d, %d)'
            % (
                name, art.width, art.height,
                -art.width // 2, -art.height,
                -art.width // 2, -art.height, art.width, art.height,
            )
        )


if __name__ == "__main__":
    main()
