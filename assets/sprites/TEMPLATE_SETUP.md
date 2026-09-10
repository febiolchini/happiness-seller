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

## buildings/*_template.aseprite (edifici happiness seller)
- Griglia tile **32x32** (allineata a `character_template.aseprite`, non alla griglia 16px di `template.aseprite` che è per tile di terreno/oggetti piccoli), stessa palette a 13 colori, layer `Base` → `Shading` → `Highlight` → `Outline`
- Layer `GroundLine` (semitrasparente, disattivabile) segna la riga dove la base dell'edificio tocca la griglia, più tacche verticali ogni tile per il footprint in larghezza
- Scala pensata per uno stile tipo Sea of Stars/Eastward: un edificio piccolo è già alto quanto 3-4 personaggi impilati, tetti/piani superiori sviluppano molto in overflow sopra la GroundLine
- 4 taglie, canvas multiplo di 32px in larghezza:

| Template | Canvas | Footprint (tile) | Note |
|---|---|---|---|
| `small_house_shop_template.aseprite` | 128x176 | 4x3 | casa/negozio base, 1-2 piani + tetto grande |
| `medium_building_template.aseprite` | 192x240 | 6x4 | ristorante/cinema/palestra, 2-4 piani |
| `tall_condo_template.aseprite` | 160x480 | 5x4 | condominio alto, stesso footprint del medio ma molto più alto (tanti piani) |
| `mall_large_template.aseprite` | 384x340 | 12x9 | centro commerciale, esteso molto in orizzontale/profondità, basso |

Il footprint (tile) è la dimensione logica da usare in Godot per occupazione griglia/collisioni; l'edificio va posizionato come Sprite2D/Node2D indipendente (non un tile vero) con Y-sort basato sulla riga di `GroundLine`, non sull'altezza totale dello sprite.

## Rigenerare i template

```
"D:\programs\aseprite\Aseprite.exe" -b --script scripts_tools/create_template.lua
"D:\programs\aseprite\Aseprite.exe" -b --script scripts_tools/create_character_template.lua
"D:\programs\aseprite\Aseprite.exe" -b --script scripts_tools/create_building_templates.lua
```

## Uso

Duplica il template adatto per ogni nuovo asset invece di ripartire da un canvas vuoto, così hai già palette, griglia e layer pronti. Sul personaggio, disegna prima il layer `Base` seguendo le linee guida di `ProportionGuide`, poi nascondi/elimina quel layer prima dell'export finale.
