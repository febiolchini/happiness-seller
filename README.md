# Happiness Seller

Progetto Godot 4 (2D pixel art) — struttura di base pronta per iniziare lo sviluppo.

## Struttura cartelle

```
assets/
  sprites/
    characters/   sprite pixel art dei personaggi
    tiles/        tileset per mappe/livelli
    props/        oggetti/decorazioni
    ui/           elementi interfaccia
  audio/
    music/
    sfx/
  fonts/

scenes/
  main/           scena di ingresso del gioco
  levels/         scene delle mappe/livelli
  characters/     scene player/npc/nemici
  ui/             menu, HUD, dialoghi
  components/     scene riutilizzabili (es. hitbox, interactable)

scripts/
  autoload/       singleton globali (game manager, ecc.)
  characters/     logica personaggi
  systems/        sistemi di gioco (inventario, dialoghi, save, ecc.)

resources/
  tilesets/        risorse .tres dei tileset

shaders/          shader personalizzati (.gdshader)
addons/           plugin di terze parti
```

## Setup progetto

- Viewport base 640x360 con stretch mode "viewport" (scaling pixel-perfect a schermo intero).
- Filtro texture di default impostato su Nearest (niente sfocatura sui pixel).
- Griglia tile: 32x32 px. Personaggi: canvas 32x48 px, proporzioni "chibi" (testa ~14px, torso ~16px, gambe ~18px) in stile Sea of Stars/Eastward.

## Note tecniche

Per la profondità in stile isometrico/obliquo (tipo Eastward, Sea of Stars):
- `TileMap`/`TileMapLayer` per il terreno.
- Y-sort abilitato sui nodi con personaggi/oggetti per gestire l'ordine di disegno in base alla posizione verticale.
- `PointLight2D` / `DirectionalLight2D` + `LightOccluder2D` per luci e ombre dinamiche.
- Shader `.gdshader` in `shaders/` per effetti custom (outline, dissolve, palette swap, ecc.).
