# Setup template pixel art (Aseprite trial)

Lo scripting/CLI di Aseprite è bloccato in trial, quindi questi passaggi vanno fatti a mano una volta sola dentro l'app:

1. **Nuovo file**: File > New — 32x32 px, Color Mode: Indexed, sfondo trasparente.
2. **Importa la palette**: apri il pannello Palette > menu (freccia in alto a destra) > Load Palette > seleziona `assets/sprites/palette.gpl`.
3. **Griglia pixel-perfect**: View > Grid > Grid Settings — imposta 16x16 (o 8x8 se vuoi lavorare più in dettaglio), poi View > Grid > Show Grid.
4. **Layer di lavoro** (ordine dal basso in alto, workflow classico pixel art):
   - `Base` — colori piatti principali
   - `Shading` — ombre
   - `Highlight` — luci
   - `Outline` — contorno nero/scuro sopra tutto
5. **Salva come template**: File > Save As > `assets/sprites/template.aseprite` (nota: in trial il salvataggio potrebbe aggiungere un watermark o essere limitato — se blocca completamente, esporta in PNG mentre valuti se acquistare la licenza).

Una volta impostato, duplica questo file ogni volta che inizi un nuovo sprite/personaggio invece di ripartire da zero.
