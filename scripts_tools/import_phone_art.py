"""Porta la scocca del telefono alla scala del gioco, e misura dov'e' il vetro.

Il disegno che arriva e' un telefono da 1254 px su un canvas trasparente; a
schermo deve stare in un angolo di una finestra 640x360. La riduzione e' la
stessa degli edifici — si importa da `import_flats_art.py`, premoltiplicazione e
ritaglio compresi, perche' l'alone nero intorno all'alpha e' un problema di
questo PNG come di quelli.

**Quello che qui c'e' in piu' e' la misura del vetro.** `phone.gd` non disegna
piu' la scocca, ma continua a disegnare quello che sta *sopra* — il velo dello
schermo acceso, le tacche, l'orologio, il triangolino — e le etichette del
messaggio stanno in `Phone.tscn` a coordinate fisse. Quelle coordinate devono
cadere dentro al vetro **del disegno**, non dentro a un rettangolo deciso a
occhio: basta che la scocca venga ridisegnata con la cornice un po' piu' spessa
e il testo finisce sopra al bordo. Quindi lo script stampa il rettangolo del
vetro e quello del notch alla taglia finale, e quei numeri si ricopiano nelle
costanti in cima a `phone.gd`.

Uso:
  python scripts_tools/import_phone_art.py
"""

import os

import numpy as np
from PIL import Image

from import_flats_art import scale, trim

HERE = os.path.dirname(os.path.abspath(__file__))
UI = os.path.join(HERE, os.pardir, "assets", "sprites", "ui")
SOURCE = os.path.join(UI, "_source")

# Larghezza a schermo. Non e' scelta a occhio: il menu del telefono deve tenere
# tredici caratteri del font di gioco a corpo 12 (`Strings.PHONE_MENU_CHARS`),
# cioe' 112 px di scritta, e il vetro e' l'83% della scocca. Sotto ai 140 px
# "LLAMA A BRIAN" si taglia. L'altezza viene dietro: un telefono e' alto quasi
# il doppio di quanto e' largo, e schiacciarlo per farlo stare piu' comodo in
# basso a sinistra si vedrebbe.
WIDTH = 140

# Come si riconosce il vetro. Le tre zone del disegno hanno tre luminosita'
# separate e non si sovrappongono: la cornice di metallo prende luce ed e'
# chiarissima, il bordo nero e il notch sono quasi a zero, il vetro sta in
# mezzo. Cercare "il pixel scuro piu' a sinistra" non funzionerebbe — il bordo
# nero e' piu' scuro del vetro, non piu' chiaro.
GLASS_LOW = 20
GLASS_HIGH = 90

# La riga su cui si misura la larghezza del notch, contata da dove comincia il
# vetro, e quanto puo' essere largo un buco chiaro li' dentro prima di contare
# come fine del notch. La riga non e' la prima: in cima gli angoli del notch
# sono arrotondati.
NOTCH_ROW = 4
NOTCH_GAP = 6


def _luma(im):
	return np.asarray(im, dtype=np.float64)[:, :, :3].mean(axis=2)


def _close(mask, gap):
	"""Tappa i buchi corti di una riga accesa.

	Dentro al notch ci sono un puntino di fotocamera e una griglia di
	altoparlante, e sono piu' chiari del nero intorno: a contarli per quello che
	sono spezzerebbero il notch in tre pezzi e il tratto piu' lungo dei tre
	sarebbe meno della meta' del buco vero. Sono buchi nel buco, non la fine del
	buco.
	"""
	out = list(mask)
	start = 0
	while start < len(out):
		if out[start]:
			start += 1
			continue
		end = start
		while end < len(out) and not out[end]:
			end += 1
		# Un buco che tocca il bordo non e' un buco: e' il fuori.
		if start > 0 and end < len(out) and end - start <= gap:
			out[start:end] = [True] * (end - start)
		start = end
	return out


def _run(mask):
	"""Inizio e fine (esclusa) del tratto acceso piu' lungo di una riga."""
	best = (0, 0)
	start = None
	for i, on in enumerate(list(mask) + [False]):
		if on and start is None:
			start = i
		elif not on and start is not None:
			if i - start > best[1] - best[0]:
				best = (start, i)
			start = None
	return best


def _glass(lum):
	"""Il rettangolo dello schermo dentro alla scocca gia' ritagliata.

	Orizzontale a meta' altezza e verticale a un quinto della larghezza: la
	prima riga senza tasti laterali, la seconda senza il notch, che altrimenti
	il tratto piu' lungo lo spezzerebbe in due.
	"""
	glass = (lum >= GLASS_LOW) & (lum <= GLASS_HIGH)
	left, right = _run(glass[lum.shape[0] // 2])
	top, bottom = _run(glass[:, int(lum.shape[1] * 0.2)])
	return left, top, right, bottom


def _notch(lum, top):
	"""Il buco della fotocamera: quanto e' largo e fin dove scende.

	Si misura dal buio, non dal vetro: quello che c'e' dentro al notch e' chiaro
	quanto lo schermo, e un conto fatto sul vetro se lo conterebbe come schermo.
	"""
	dark = lum < GLASS_LOW
	left, right = _run(_close(dark[top + NOTCH_ROW], NOTCH_GAP))
	# Fin dove scende si guarda in mezzo, dove il notch e' piu' profondo: agli
	# angoli e' arrotondato e finirebbe due pixel piu' in su.
	column = _close(dark[:, (left + right) // 2], NOTCH_GAP)
	bottom = top
	while bottom < lum.shape[0] and column[bottom]:
		bottom += 1
	return left, right, bottom


def main():
	art = trim(Image.open(os.path.join(SOURCE, "phone.png")).convert("RGBA"))
	small = scale(art, WIDTH, None)
	small.save(os.path.join(UI, "phone.png"))

	lum = _luma(small)
	left, top, right, bottom = _glass(lum)
	notch_left, notch_right, notch_bottom = _notch(lum, top)
	print("const SIZE := Vector2(%d.0, %d.0)" % (small.width, small.height))
	print("const GLASS := Rect2(%d.0, %d.0, %d.0, %d.0)"
		% (left, top, right - left, bottom - top))
	print("const NOTCH := Rect2(%d.0, %d.0, %d.0, %d.0)"
		% (notch_left, top, notch_right - notch_left, notch_bottom - top))


if __name__ == "__main__":
	main()
