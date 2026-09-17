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
    ("render_agenzia.png", "realEstate", None, 334),
    ("render_garage.png", "garage", None, 197),
    ("render_bodega.png", "bodega", None, 255),
    ("render_lavanderia.png", "laundry", None, 249),
    ("render_liquori.png", "liquorStore", None, 248),
    ("render_officina.png", "autoRepair", None, 219),
    ("render_caseggiato.png", "rowBlock", None, 391),
    ("render_pensione.png", "rooming", None, 329),
    # Primo edificio del quartiere benestante: la clinica dove lavora Brian.
    ("render_clinica.png", "clinic", None, 428),
    # Primo edificio di DOWNTOWN: il grossista dei semi. L'altezza e' l'ingombro
    # NETTO e non i 413 che stampa `render_buildings.py`, che sono
    # l'inquadratura MARGINE COMPRESO. Il numero esatto non va stimato: il
    # render e' gia' a 22,3 px/m per quattro, quindi e' l'altezza del ritaglio
    # sull'alpha diviso il supersampling, 1196 / 4.
    ("render_magazzino.png", "wholesale", None, 299),
    # Le strutture del campo da football abbandonato. Non sono edifici: entrano
    # in città come props (vedi `CityMap.field_props()`). L'erba del campo non
    # è qui perché non è un PNG — la disegna uno shader di Godot.
    # ATTENZIONE alle altezze: `render_buildings.py` stampa un numero ricavato
    # dall'inquadratura MARGINE COMPRESO, mentre qui si ritaglia il margine
    # prima di scalare. Su un edificio grande la differenza e' il tre per
    # cento; su una porta da calcio alta tre metri il margine e' un quarto
    # dell'inquadratura, e la porta veniva fuori larga undici metri invece di
    # sette. Questi tre numeri vengono dall'ingombro NETTO.
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


def main():
    for source, name, width, height in ASSETS:
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
