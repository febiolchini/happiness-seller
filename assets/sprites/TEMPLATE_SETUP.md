# Template pixel art

`template.aseprite` è generato automaticamente via script Lua (licenza full di Aseprite) — vedi `scripts_tools/create_template.lua`.

Contiene:
- Canvas 32x32 px, color mode Indexed
- Griglia 16x16 già impostata
- Palette base a 13 colori (`palette.gpl`) già caricata
- 4 layer nell'ordine di lavoro classico: `Base` → `Shading` → `Highlight` → `Outline`

## Rigenerare il template

Se modifichi lo script e vuoi rigenerare il file:

```
"D:\programs\aseprite\Aseprite.exe" -b --script scripts_tools/create_template.lua
```

## Uso

Duplica `template.aseprite` per ogni nuovo sprite/personaggio invece di ripartire da un canvas vuoto, così hai già palette, griglia e layer pronti.
