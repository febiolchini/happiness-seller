# Mappa caratteri — font_template.aseprite

Griglia 8x8 px per carattere, 16 colonne x 3 righe (letta da sinistra a destra, riga per riga).

```
Riga 1: A B C D E F G H I J K L M N O P
Riga 2: Q R S T U V W X Y Z 0 1 2 3 4 5
Riga 3: 6 7 8 9 . , ! ? ' - :  (celle rimanenti libere/vuote)
```

Il carattere spazio non va disegnato: gestiscilo come larghezza fissa nell'import del font.

## Come disegnare

- Layer `Base`: disegna la lettera piena (1-2 colori, es. bianco/crema).
- Layer `Outline`: bordo scuro attorno alla lettera per farla leggere bene su sfondi diversi.
- Layer `GridGuide`: solo guida visiva (righe rosse trasparenti), nascondila prima di esportare.
- Ogni carattere deve stare dentro la sua cella 8x8: lascia 1 px di margine per non farli toccare quando li affianchi nel testo.

## Rigenerare il template

```
"D:\programs\aseprite\Aseprite.exe" -b --script scripts_tools/create_font_template.lua
```

## Export per Godot

Una volta disegnati tutti i caratteri:
1. Esporta come sprite sheet PNG (mantenendo la griglia 8x8, 16x3 celle).
2. In Godot, crea un `FontFile` di tipo bitmap importando lo sprite sheet, definendo per ogni carattere il rettangolo nella griglia e l'associazione al codice ASCII/unicode corrispondente.
3. Usalo su `Label`/`RichTextLabel` impostando questo font come `Theme Override > Fonts`.
