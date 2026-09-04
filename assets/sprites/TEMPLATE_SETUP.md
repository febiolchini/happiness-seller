# Template pixel art

Generati automaticamente via script Lua (licenza full di Aseprite), vedi `scripts_tools/`.

## template.aseprite (tile/oggetti)
- Canvas 32x32 px, color mode Indexed
- Griglia 16x16 già impostata
- Palette base a 13 colori (`palette.gpl`) già caricata
- 4 layer: `Base` → `Shading` → `Highlight` → `Outline`

## characters/character_template.aseprite (personaggi)
- Canvas 32x48 px, proporzioni "chibi" stile Sea of Stars/Eastward
- Layer `ProportionGuide` (semitrasparente, disattivabile) con linee guida a y=14 (testa/torso) e y=30 (torso/gambe)
- 4 layer di lavoro: `Base` → `Shading` → `Highlight` → `Outline`
- 4 frame taggati: `down`, `up`, `left`, `right` (un frame ciascuno, da espandere con più frame per il walk cycle)

## Rigenerare i template

```
"D:\programs\aseprite\Aseprite.exe" -b --script scripts_tools/create_template.lua
"D:\programs\aseprite\Aseprite.exe" -b --script scripts_tools/create_character_template.lua
```

## Uso

Duplica il template adatto per ogni nuovo asset invece di ripartire da un canvas vuoto, così hai già palette, griglia e layer pronti. Sul personaggio, disegna prima il layer `Base` seguendo le linee guida di `ProportionGuide`, poi nascondi/elimina quel layer prima dell'export finale.
