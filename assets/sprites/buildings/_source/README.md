# Disegni originali del quartiere povero

Gli otto PNG da cui escono gli sprite del quartiere, alla risoluzione a cui
sono stati disegnati (1100-1450 px di lato). Non li carica il gioco: stanno
dietro a un `.gdignore` perche' Godot importerebbe 12 MB di texture che
nessuno usa, e finirebbero nell'export.

Gli sprite veri si rigenerano da qui:

    python scripts_tools/import_flats_art.py

La tabella `ASSETS` in quello script dice quale originale diventa quale sprite
e con che larghezza a schermo.
