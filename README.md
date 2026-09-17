# Happiness Seller

Gestionale di traffico di marijuana in stile tycoon. Godot 4, 2D pixel art.

Quasi tutta la grafica è ancora **segnaposto disegnato via codice**. Hanno già
il disegno vero: i fondali delle stanze e **tutto THE FLATS**, il quartiere
povero, costruito con otto PNG — casa iniziale, campo roulotte, palazzo
occupato, bifamiliare, retro del minimarket, bottiglieria, officina, alimentari
— ripetuti fitti lungo tutte le sue strade. Fuori di lì ci sono per ora due
edifici soli, tutti e due costruiti in Blender: la clinica dove lavora Brian in
HILLSIDE e il magazzino all'ingrosso dei semi in DOWNTOWN. Il resto dei
quartieri è terreno, strade e lampioni, in attesa dei suoi disegni: il segnaposto edificio
(rettangolo colorato con l'insegna) non c'è più, perché accanto a un disegno si
riconosceva a colpo d'occhio. L'idea è che le logiche di gioco siano già in
piedi e complete, e che la pixel art le sostituisca un pezzo per volta senza
toccarle. Ogni sezione qui sotto dice cosa va rimpiazzato e come.

Il giro di gioco è: **chiedi semi a Brian dal PC → vai all'appuntamento →
piantali nel seminterrato → annaffiali → raccogli → vendi**, all'ingrosso dal
PC o in strada ai clienti. Vedi "Coltivare e vendere".

Poi il giro si allarga: col **negozio online** si compra l'attrezzatura che lo
rende meno faticoso (attrezzatura, lampade, filtri), e a **1000 $** il
prologo si chiude e si può **assumere personale** che coltiva e vende da solo.
Vedi "Il negozio online", "La fine del prologo" e "Il personale".

Il mondo non si ferma quando si chiude il gioco: riaprendolo, il personale ha
lavorato e le piante sono cresciute. Vedi "Il tempo a gioco chiuso".

Sopra a tutto questo scorre una giornata vera: la luce cambia con l'ora, le
ombre girano col sole, al tramonto si accendono i lampioni, e ogni
mezzanotte esce il tempo del giorno dopo — che non è solo da guardare, perché
sotto la pioggia si vende meno in strada ma ci si fa anche notare meno. Vedi
"Luce, ore e meteo".

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
  autoload/       singleton globali (GameState, GameSettings, SaveData)
  data/           tabelle di bilanciamento, pianta della citta', luce, meteo, testi, chat, guida
  characters/     logica personaggi e NPC
  components/     pezzi riutilizzabili (edifici, vasi, veicoli, fontana)
  levels/         mappa e disegno del terreno
  rooms/          logica delle stanze
  systems/        sistemi di gioco (coltivazione, camera, atmosfera, meteo, tempo offline)
  ui/             HUD, sveglia, cassa, menu, telefono, guida, gestionale
  tests/          controlli automatici

tests/            scena da lanciare per i controlli automatici

resources/
  tilesets/        risorse .tres dei tileset

shaders/          shader personalizzati (.gdshader)
addons/           plugin di terze parti
```

## Setup progetto

- Viewport base 640x360 con stretch mode "canvas_items" (scaling pixel-perfect a schermo intero).
- Filtro texture di default Nearest, **senza mipmap**: le mipmap servono a rimpicciolire
  le texture in modo morbido, che è l'opposto di quello che vuole la pixel art.
- Griglia tile: 32x32 px. Personaggi: canvas 32x48 px, proporzioni "chibi" (testa ~14px, torso ~16px, gambe ~18px) in stile Sea of Stars/Eastward.

## Note tecniche

Per la profondità in stile isometrico/obliquo (tipo Eastward, Sea of Stars):
- `TileMap`/`TileMapLayer` per il terreno.
- Y-sort abilitato sui nodi con personaggi/oggetti per gestire l'ordine di disegno in base alla posizione verticale.
- Luci e ombre: **non** `PointLight2D`, per il motivo spiegato in "Luce, ore e
  meteo" — la luce è un `CanvasModulate` sulla tela del mondo, e quello che deve
  restare acceso dentro al buio si disegna con `Daylight.emissive()`.
- Shader `.gdshader` in `shaders/` per effetti custom (outline, dissolve, palette swap, ecc.).

## Mappa della cittadina

`scenes/levels/City.tscn` **contiene solo dei contenitori vuoti**. Strade,
quartieri, edifici, traffico e passanti li costruisce `city.gd::_build_city()`
leggendo due tabelle di dati: `scripts/data/city_map.gd` (la pianta) e
`scripts/data/npc_roster.gd` (chi c'è per strada).

È la stessa regola che vale già per i salvataggi — la scena si ricostruisce
dallo stato, non si salva l'albero dei nodi — estesa alla pianta della città.
Il motivo è pratico: un centinaio di edifici piazzati a mano in un `.tscn` non
si rileggono e non si spostano, mentre in una tabella un quartiere si riordina
cambiando due numeri.

### Il reticolo

Tutto è allineato alla griglia da 32 px. Le strade sono definite dal rettangolo
del loro **asfalto**; marciapiedi (32 px) e cordoli li disegna
`city_ground.gd` intorno. Sei strade orizzontali e cinque verticali formano
quarantadue isolati.

| Strada | Asfalto | |
|---|---|---|
| MAIN STREET | y 272 → 368 | |
| CROSS STREET | y 976 → 1072 | |
| FOUNDRY ROW | y 1680 → 1776 | |
| DIVISION AVENUE | y 2240 → 2336 | divide le due file di quartieri |
| PARK LANE | y 2944 → 3040 | |
| SOUTH BOULEVARD | y 3552 → 3648 | |
| MILL ROAD | x 752 → 848 | |
| DOCK STREET | x 1856 → 1952 | divide FLATS/CIVIC dal resto |
| FURNACE STREET | x 2672 → 2768 | |
| EAST STREET | x 3488 → 3584 | divide INDUSTRIAL da DOWNTOWN |
| HILL DRIVE | x 4256 → 4352 | |

Il mondo va da (-352, -352) a (4960, 4160) — 5312 x 4512 px, circa cinque
schermi per quattro — ed è il rettangolo che la camera usa come limite
(`CityMap.WORLD_BOUNDS`).

**MAIN STREET resta a y 272** apposta: tutto il quartiere povero originale è
costruito intorno a quella quota, casa iniziale compresa, e spostarla vorrebbe
dire rifare posizioni che sono già buone. La città è cresciuta intorno a quello
che c'era, non sopra.

Dove si cammina lo dicono `CityMap.SIDEWALK_N/S/W/E` (le quote dei marciapiedi,
una per strada) e `CityMap.CROSS_X` (le ascisse su cui cadono le strisce
pedonali). Sono i numeri con cui si scrivono i percorsi degli NPC.

### I cinque quartieri

| Quartiere | Area | Cosa c'è |
|---|---|---|
| THE FLATS | x -352→1856, y -352→2240 | il quartiere povero, **l'unico costruito**: un centinaio di edifici, tutti disegnati, fitti lungo ogni fronte stradale e dentro agli isolati. Gli otto punti di riferimento (casa iniziale, campo roulotte, palazzo occupato, bifamiliare, retro del minimarket, bottiglieria, officina, alimentari) più le file generate con gli stessi otto disegni; campo da football, lotti abbandonati, parcheggi e un paio di centinaia di cespugli |
| INDUSTRIAL PARK | x 1952→3488, y -352→2240 | terreno, strade e lampioni: aspetta i suoi disegni. Restano lo sfasciacarrozze, il deposito container e gli altri piazzali |
| DOWNTOWN | x 3584→4960, y -352→2240 | terreno, strade e lampioni, più **il grossista dei semi**: il magazzino all'ingrosso fra HILL DRIVE e PORT STREET, col suo parcheggio dietro (lotto `asphalt` in `LOTS`, lampioni compresi). È il primo edificio disegnato del quartiere, e quello che ne fissa la tavolozza (`DT_`) |
| CIVIC CENTER | x -352→1856, y 2336→4160 | parco centrale, giardino con **due fontane**, piazza e cortile della scuola. Gli edifici pubblici arriveranno col disegno |
| HILLSIDE | x 1952→4960, y 2336→4160 | prati, campo da tennis e piscine della zona benestante, in attesa delle ville |

La divisione è quella di sempre — tre quartieri sopra `DIVISION AVENUE`, due
sotto — con ogni quartiere grande esattamente il doppio in ciascuna direzione.

**Un quartiere solo ha gli edifici**, e `CityMap.BUILT_DISTRICTS` dice quale.
Prima ce li avevano tutti, ma erano segnaposto — rettangoli colorati con
l'insegna scritta sopra e una griglia di finestre che si accendeva la sera — e
un segnaposto accanto a un disegno si riconosce a colpo d'occhio: THE FLATS ha
finito per essere il quartiere dove si vedeva la differenza. Un quartiere vuoto
si legge come "da costruire", che è la verità; uno pieno di roba finta si legge
come "costruito male".

Ogni quartiere ha comunque un colore di terreno con una dominante sua (olive,
ruggine, blu, verde-teal, verde chiaro): serve a capire a occhio dove si è anche
con la mappa tutta zoomata fuori, e sparirà con i tileset veri.

### Nord e sud di una strada

L'origine di un edificio è il punto a terra al centro della facciata e il corpo
si sviluppa **verso l'alto**. Il campo `"front"` dice su quale lato della strada
sta l'edificio, quindi da che parte è il marciapiede:

- **nord** → base sul bordo alto del marciapiede (es. y 240 per MAIN STREET),
  il protagonista si avvicina da sotto;
- **sud** → base più in basso della strada, col corpo che arriva a toccare il
  marciapiede, e il protagonista si avvicina da sopra;
- **ovest** / **est** → lo stesso ruotato, per gli edifici affacciati su una
  strada verticale.

Da lì `city.gd::_entry_offset()` ricava dove si ferma il protagonista.
Sbagliarlo si vede subito: il personaggio va a fermarsi dietro al muro.

### Due strati di edifici

`CityMap.BUILDINGS` contiene i **punti di riferimento**: i quaranta edifici che
hanno un nome, un ruolo o una posizione che conta (la casa iniziale, la clinica
dove lavora Brian, il municipio, la fabbrica). Sono scritti a mano, uno per uno.

Tutti gli altri — le file di case e capannoni qualunque che riempiono i
blocchi, un centoventina — li genera `CityMap.all_buildings()` percorrendo i
fronti stradali. Scritti a mano non si rileggerebbero e non si sposterebbero
più, e ogni ritocco al reticolo vorrebbe dire rifarli tutti; generandoli,
spostare una strada risistema il quartiere da sé.

I fronti stradali stessi sono ricavati dal reticolo e non elencati: sono più di
cento, e ce ne sono anche sulle strade **verticali** — senza, i blocchi
risulterebbero costruiti solo sopra e sotto, con le fiancate vuote, e da lontano
la città si leggerebbe come una serie di righe invece che di isolati.

L'ordine conta: i punti di riferimento occupano il posto per primi, e il
riempimento gira intorno a quello che trova già occupato — strade, terreni
particolari, altri edifici. Uno slot occupato non interrompe la fila: si scivola
avanti di un tile e si riprova, altrimenti un solo punto di riferimento in mezzo
a un isolato lascerebbe vuoto tutto quello che viene dopo.

La generazione è **deterministica** (`CityMap.FILL_SEED`): la città è identica a
ogni avvio. Non è un requisito tecnico — gli edifici di sfondo non hanno stato
— ma una città che si rimescola a ogni lancio è disorientante.

Stessa idea per gli **alberi** (`CityMap.trees()`, sparsi nei prati) e per le
**corsie del traffico** (`CityMap.lanes()`, due per strada). Una corsia scritta
a mano che non combacia col suo asfalto si vede come un'auto che viaggia sul
marciapiede, e con undici strade prima o poi succede.

### Il rettangolo cliccabile è il muro, non il disegno

I tre edifici accanto a casa — il palazzo occupato, la casa iniziale, l'agenzia
— stanno **muro contro muro**, senza un pixel di terreno in mezzo: è così che si
legge un quartiere popolare, e un vuoto fra due facciate si legge invece come un
buco nella mappa.

Per accostarli non basta far combaciare i PNG, perché **il PNG non è l'edificio**:
i disegni con un cortile comprendono anche la recinzione e la baracca di lato.
Il palazzo è 495 px di immagine ma 324 di muro, la casa 306 contro 211.
Accostati per il bordo dell'immagine, fra i due muri restano più di cento pixel
di staccionate.

Quindi le `x` sono calcolate sui **muri**, e i cortili dei due disegni si
sovrappongono: la staccionata dell'uno passa dietro a quella dell'altro, ed è
esattamente quello che fanno due giardini confinanti.

E siccome si sovrappongono, bisogna dire **chi passa davanti**. I tre poggiano
sulla stessa riga di terra, quindi l'Y-sort non ha niente da decidere e resta
l'ordine dell'albero: il campo `in_front` della pianta dice chi va aggiunto per
ultimo, e ce l'ha la **casa iniziale**. Senza, finiva dietro all'agenzia, che le
copriva veranda e staccionata — ed è l'unico dei tre che si guarda davvero, e
l'unico in cui si entra.

Stessa regola nel click: `city.gd::_building_at()` a parità di y tiene
l'**ultimo** del gruppo, non il primo, perché il gruppo elenca i nodi nello
stesso ordine in cui l'Y-sort li disegna. Col confronto stretto il nome che
compariva passandoci sopra era quello dell'edificio nascosto dietro.

Perché tutto questo regga, il campo `click` di `CityMap.BUILDINGS` è
**l'ingombro del muro**, non il rettangolo del PNG. Non è solo l'area del mouse:
`CityMap.footprint()` legge lo stesso rettangolo, quindi `click` è anche quello
che occupa il posto nel piazzamento, quello che blocca la griglia dei percorsi e
quello che il controllo automatico usa per dire "nessun edificio sovrapposto a
un altro". Preso sul PNG intero, due edifici accostati risulterebbero
sovrapposti in tutti e tre i sensi.

### Come si chiamano le strade

Il nome di ogni via è stampato **sul marciapiede**, ripetuto ogni 900 px e
orientato con la strada (ruotato di novanta gradi sulle verticali, così si legge
dall'alto verso il basso).

Sul marciapiede e non sull'asfalto, che era il primo tentativo: lì la scritta
cade sulla mezzeria tratteggiata, ci passano sopra le auto, e su un grigio scuro
un giallo tenue non si legge comunque. Il marciapiede è chiaro, quindi basta uno
scuro poco carico per leggersi bene restando discreto — si vede quando lo si
cerca e non dà fastidio quando non lo si cerca. Ed è il posto giusto: il nome
serve dove si cammina, e gli appuntamenti con Brian si danno per strada.

Sta su un lato solo (nord per le orizzontali, ovest per le verticali): su tutti
e due sarebbe il doppio delle scritte per la stessa informazione. E si
interrompe agli incroci, come la mezzeria, perché lì il marciapiede non c'è.

### Come si riempie un quartiere

Gli edifici sono **sempre** un PNG, sia quelli scritti a mano sia quelli
generati. Ci sono due modi di aggiungerne:

- una riga in **`CityMap.FILL_ART`** (file e misura in pixel) e il riempimento
  comincia a seminare quel disegno per tutto il quartiere;
- una voce in **`CityMap.BUILDINGS`** per un edificio che deve avere un nome
  suo, una posizione precisa o un interno in cui si entra.

Il riempimento lavora in due passate. Prima le **file affacciate sulle strade**,
che partono dal marciapiede e si mettono una accanto all'altra con quattro-
quattordici pixel di stacco (`FILL_GAP`): è quello che fa la densità di una
città vera, e a distanze più larghe la stessa fila si legge come una strada di
campagna. Poi i **cuori degli isolati** (`_fill_interior()`), riempiti a righe
dall'alto in basso con quello che ci sta.

Quelli dentro agli isolati sono **fondali** (`"backdrop"`): sprite e basta,
niente script, non si cliccano e non si entra. Non per pigrizia — stanno murati
dietro alla fila che dà sulla strada, e una porta che si affaccia sul muro del
vicino non è una porta. È anche il motivo per cui il controllo automatico "da
casa si arriva a ogni edificio" li salta.

**Il verde non c'è**, né qui né dentro ai disegni. `CityMap.bushes()` è stata
tolta insieme ai segnaposto, e i rovi che stavano nei modelli di casa e
condominio sono stati tolti anche loro (2026-09-17): erano scatole grigioverdi
piazzate da un `random`, e alla scala dello sprite non si leggevano come
cespugli — si leggevano come cubi sparsi davanti agli edifici. Quando il verde
tornerà sarà roba disegnata e piazzata dal gioco, non geometria dentro
all'edificio: vedi la nota in cima a `render_buildings.py`.

Un edificio disegnato ha l'origine **a terra, al centro della facciata**, quindi
lo sprite vuole `centered = false` e
`offset = Vector2(-larghezza / 2, -altezza)`.

Due cose da sapere prima di incollare un PNG in `BUILDINGS`:

1. **Metti `"entry"`.** È dove ci si ferma davanti, e scritto a mano è comunque
   meglio del conto automatico: la porta di un disegno sta dove l'ha messa il
   disegnatore e non al centro della base.
2. **Tieni `"label"`.** Non si vede — è lo sprite a mostrarsi — ma le strade
   prendono il nome dalle insegne vicine (vedi "Come si chiamano i posti"), e
   togliendola l'edificio sparisce da quel conto. Occhio che un'insegna fra i
   `names` del quartiere conta come generica e non vale come indicazione: di
   negozietti uguali agli alimentari il riempimento ne semina venti.

I PNG vanno **ritagliati e rimpiccioliti alla scala della città** prima di
entrare: l'arte arriva a duemila pixel per lato, mentre un palazzo di sette
piani a schermo ne è alto duecentosettanta. La regola di scala è il
protagonista: è alto 48 px, quindi un piano d'abitazione ne vuole una
trentina e una roulotte una quarantina di larghezza. La base dello sprite va
fatta combaciare col **bordo inferiore del disegno**, così l'origine del nodo
cade dove il palazzo tocca terra e l'Y-sort lo ordina con tutto il resto.

Terreno, strade, prato, piazza, campo da football e alberi stanno tutti in
`scripts/levels/city_ground.gd`, che disegna e nient'altro: la pianta la legge
da `CityMap`. Andrà rimpiazzato da `TileMapLayer`. Gli **alberi** in particolare
sono disegnati piatti sul terreno (come il campo da football), quindi per ora il
giocatore ci cammina sopra; diventando sprite andranno spostati fra i nodi
Y-sortati.

Un dettaglio di `city_ground.gd` che sembra un caso ma non lo è: disegna
**prima tutti i marciapiedi e solo dopo tutto l'asfalto**. Così agli incroci i
marciapiedi restano sotto e le due strade si fondono in una piazzola, senza
dover calcolare nessuna intersezione.

## Chi c'è per strada

`scripts/data/npc_roster.gd` è l'elenco dei personaggi; `scripts/characters/npc.gd`
li fa camminare e parlare. Non sono `CharacterBody2D`: non devono urtare niente
— i percorsi passano già sui marciapiedi — e undici corpi fisici che si spingono
a vicenda costerebbero senza dare niente in cambio.

Sono **trenta**, sparsi su tutti e cinque i quartieri.

Un percorso (`route`) è una fila di punti che l'NPC ripercorre fermandosi a ogni
tappa. Le quote giuste dei marciapiedi stanno in `CityMap.SIDEWALK_N/S/W/E`, una
per strada: usarle evita di scrivere percorsi che passano dentro a un muro o in
mezzo alla carreggiata. Chi deve **attraversare** lo fa sulle ascisse di
`CityMap.CROSS_X`, che sono le uniche su cui cadono le strisce pedonali — e sono
anche marciapiede valido, quindi valgono sia per camminarci sia per attraversare.
Le pattuglie le usano tutte.

`hours` è la fascia in cui il personaggio è in giro: **fuori da quella la strada
si svuota**. È il primo uso vero dell'orologio di gioco oltre all'HUD — di notte
restano solo le due pattuglie e i clienti — e insieme ai fari delle auto è quello
che fa sentire che il tempo passa.

Cosa succede parlandogli lo decide il **ruolo**, e lo decide `npc.gd`:

| Ruolo | Chi | Cosa fa |
|---|---|---|
| `seeds` | BRIAN, solo su appuntamento | vende i semi (vedi "Comprare i semi") |
| `buyer` | otto, uno o due per quartiere | comprano erba al dettaglio |
| `cop` | quattro pattuglie | commentano in base a quanta attenzione hai addosso |
| `wander` | diciassette | comparse, due battute a caso |

I clienti sono sparsi su tutti e cinque i quartieri e su fasce orarie diverse:
la città è larga cinque schermi, e doverla attraversare tutta per trovare
qualcuno a cui vendere sarebbe solo tempo perso.

Sopra la testa di chi ha qualcosa da offrire c'è un rombo colorato (verde =
vende, giallo = compra). Senza, in una città con undici passanti non si capisce
con chi valga la pena parlare.

### Il dialogo

`scenes/ui/DialogueBox.tscn` è **generico**: non sa niente di semi, grammi o
prezzi. Chi apre il dialogo passa il testo già scritto e una lista di scelte,
dove ogni scelta è un'etichetta e una `Callable`. Così la logica di un
personaggio sta nel suo ruolo e la scena resta l'unico posto in cui si decide
come sono fatti i dialoghi.

Una scelta con `keep_open` si occupa lei di riscrivere il dialogo: è come fanno
i negozi, perché comprare tre volte di fila non deve costare tre camminate fino
alla clinica.

## Come si cammina

`scripts/systems/city_navigation.gd` è una griglia A* (`AStarGrid2D`) costruita
dalla **stessa** pianta che costruisce gli edifici, quindi le due non possono
divergere. Celle da 16 px, perché tutta la mappa è allineata a multipli di 16 e
così il bordo di un marciapiede cade su un confine fra celle invece di tagliarne
una a metà.

Costruirla costa 7 ms, e un percorso da un capo all'altro della città circa 11.

### Il costo, non solo il muro

Bloccare gli edifici non basta. Senza costi il protagonista taglierebbe in
diagonale attraverso cortili e prati perché è più corto, e non camminerebbe mai
su un marciapiede. Ogni cella ha quindi un prezzo:

| Terreno | Costo |
|---|---|
| Marciapiede | 1.0 |
| Asfalto | 2.2 |
| Tutto il resto (cortili, prati, piazzali) | 3.0 |

Il percorso più conveniente diventa così da solo quello che farebbe una persona:
si segue la via, si attraversa la carreggiata invece di percorrerla, e si taglia
per un prato solo quando il giro sarebbe molto più lungo.

Il terreno non è mai *impraticabile*, solo caro: un edificio in mezzo a un
isolato deve restare raggiungibile, e chi clicca in mezzo a un parco ci deve
andare.

### La semplificazione deve rispettare il costo

A* su una griglia restituisce una scaletta di celle: seguita così, il
personaggio cammina a zig-zag anche su una strada dritta. Si tiene quindi un
punto solo quando da quello prima non si vede più il successivo.

Ma la scorciatoia non può essere solo "il muro non c'è": **deve restare su un
terreno non più caro di quello che sostituisce**. Alla prima versione mancava
questo vincolo, e il risultato era che la semplificazione buttava via la
preferenza per i marciapiedi appena calcolata da A*: un tragitto attraverso la
città tornava a serpeggiare in diagonale dentro agli isolati, infilandosi in ogni
varco fra due palazzi.

Il tetto di spesa cresce lungo il tratto e si azzera a ogni punto tenuto: finché
si è sul marciapiede non si scende in strada, ma appena il percorso deve
attraversare, l'attraversamento in diagonale torna permesso — che è poi quello
che farebbe una persona.

### Quando un percorso non c'è

Gli estremi vengono spostati sulla cella libera più vicina: si può cliccare
sopra a un edificio, e il protagonista può ritrovarsi dentro a un muro
(riprendendo un salvataggio fatto prima che quell'edificio esistesse). Se
nonostante tutto un percorso non si trova, `city.gd` manda il personaggio in
linea retta: meglio un tragitto brutto che un click ignorato, che si legge come
un gioco rotto.

## Traffico

`scripts/components/car.gd` più le corsie di `CityMap.lanes()`, due per strada,
ricavate dalle strade stesse. Una corsia è una retta: l'auto la scorre e quando
esce da un capo rientra dall'altro. Niente fisica, e non serve. In tutto sono
ottantotto auto sulle undici strade.

Le corsie seguono la guida a destra — su una strada orizzontale chi va verso est
sta nella corsia più in basso, su una verticale chi va verso sud sta in quella
più a ovest — e le auto **frenano** se il protagonista è
davanti al muso: due righe, ma un'auto che ci passa attraverso senza rallentare
si legge subito come un bug. Di notte accendono i fari.

### Gli edifici disegnati si portano alla scala del gioco con uno script

I disegni del quartiere povero arrivano grandi — 1100-1450 px di lato — e
inquadrati ciascuno sul proprio soggetto: la casetta a un piano riempie il suo
canvas quanto il palazzo di sei piani riempie il suo. A schermo devono però
stare tutti nella stessa città, dove un personaggio è alto 48 px. La scala
giusta quindi non si ricava dal file: si decide soggetto per soggetto, ed è la
tabella `ASSETS` di `scripts_tools/import_flats_art.py` a tenerla scritta.

```
python scripts_tools/import_flats_art.py
```

Gli originali stanno in `assets/sprites/buildings/_source/`, dietro a un
`.gdignore`: sono dodici megabyte che il gioco non carica, e lasciati
nell'albero degli asset Godot li importerebbe come texture e se li porterebbe
dietro nell'export. Lo script stampa anche le righe `"offset"` e `"click"` già
pronte da incollare in `city_map.gd`, che è il modo per non sbagliarle a mano.

Due accortezze dentro allo script, tutte e due invisibili finché non mancano.
La prima è la **premoltiplicazione**: nei PNG i pixel trasparenti sono neri, e
ridimensionando l'RGBA così com'è il filtro media quel nero coi pixel opachi
vicini e lascia un bordo scuro intorno a tutto il disegno. Si moltiplica il
colore per l'alpha, si scala, e si divide di nuovo. La seconda è **ritagliare
prima di scalare**: il margine vuoto non è lo stesso in tutti i file, e
tenerlo vorrebbe dire che la stessa larghezza richiesta produce edifici di
taglia diversa.

Per guardarli dove stanno davvero — in mezzo alle strade, accanto ai vicini e
al protagonista, di giorno e di notte — c'è
`scripts_tools/FlatsShot.tscn`, che si lancia **con la finestra**:

```
Godot_v4.7.2-stable_win64_console.exe --path . scripts_tools/FlatsShot.tscn
```

La taglia di un edificio si giudica solo lì: uno per uno, fuori contesto,
sembrano tutti giusti.

### I veicoli sono sprite renderizzati

I mezzi non sono più rettangoli disegnati via codice: sono i modelli low-poly di
`assets/sprites/props/Low_Poly_Cars_DevilsWorkShop_V03` **renderizzati a sprite
visti dall'alto**, sette in tutto (tre berline, due pickup, una volante, un
autobus). `city.gd` ne pesca uno a caso per ogni auto — per strada capita di
tutto, e un ciclo regolare su un elenco si legge come una fila di modelli che si
ripete.

A renderizzarli è `scripts_tools/render_cars.py`, che gira in Blender senza
aprirlo:

```
blender --background --python scripts_tools/render_cars.py --   assets/sprites/props/Low_Poly_Cars_DevilsWorkShop_V03/Low_Poly_Cars_DevilsWorkShop_V03   assets/sprites/props/cars
```

Il punto che rende tutto semplice è che la vista sia **dritta dall'alto**: così
un render solo basta per tutte e quattro le direzioni, perché girare uno sprite
di novanta gradi è esatto. Con la camera inclinata servirebbero quattro
immagini per veicolo. Per questo i mezzi sono renderizzati **col muso verso
destra**, che è la direzione "est" di `car.gd::_forward()`, e `setup()` gira lo
sprite di conseguenza.

Sono tutti renderizzati con lo stesso rapporto fra unità di modello e pixel,
preso da `car01` a 44 px di lunghezza (la vecchia `BODY_LENGTH`): restano quindi
in scala fra loro, e il bus è davvero lungo il doppio di una berlina. Aggiungere
un mezzo vuol dire una riga in `MODELS` nello script e una in `Car.VEHICLES`.

Tre cose imparate rendendoli, che è utile sapere prima di rifarlo:

- il **view transform** di Blender va messo su `Standard`. Quello di default
  (AgX) è pensato per le foto e smorza i colori saturi: il rosso dell'auto
  usciva rosa;
- il **clipping** della camera va allargato. Di default si ferma a 100 unità,
  i modelli sono alti 225 e la camera sta mille sopra: il fotogramma usciva
  vuoto;
- serve **luce ambiente generosa**, non solo il sole. Il cassone di un pickup
  non vede il sole, e con poca luce diffusa usciva nero — mezzo veicolo era un
  buco invece di un pianale.

Nel pacchetto ci sono anche `modEngine`, `modLights`, `modPipes` e `modSpoiler`:
non sono veicoli ma **pezzi da montare**, e infatti renderizzati vengono grandi
quanto un francobollo. Sono esclusi.

Il pacchetto porta gli stessi undici texture atlas due volte, in PNG e in TGA
non compresso — 34 MB di doppioni identici pixel per pixel su 37 totali. I TGA
sono esclusi da git (`.gitignore`), e un `.gdignore` nella cartella tiene Godot
lontano dai modelli 3D: in un progetto 2D importarli è solo tempo di
caricamento.

## Salvataggi

La partita in corso vive in un autoload, `GameState` (`scripts/autoload/game_state.gd`),
che è l'unica fonte di verità: le scene leggono e scrivono `GameState.current` e
non toccano mai i file. I dati sono in `SaveData` (`scripts/autoload/save_data.gd`),
che contiene **solo dati, mai nodi** — la mappa si ricostruisce leggendo lo stato
in `city.gd::_apply_state()`, non si salva l'albero della scena.

I file stanno in `user://saves/*.json`, uno per partita (`user://` è la cartella
dati dell'utente: `res://` in un gioco esportato è di sola lettura). Sono JSON
leggibili, comodi da ispezionare mentre si sviluppa.

Dal menu principale:

- **play** riprende il salvataggio più recente sul dispositivo; se non ce n'è
  ancora nessuno avvia direttamente una partita nuova.
- **nuova partita** crea sempre una campagna da zero, in un nuovo slot.
- **salvataggi** apre `scenes/ui/SaveSlots.tscn`, che elenca le partite presenti
  e permette di caricarle o cancellarle (la cancellazione chiede conferma con un
  secondo click).

### Quando si salva

La partita si scrive su disco:

- **da sola ogni 45 secondi** di gioco effettivo (`GameState.AUTOSAVE_SECONDS`);
- **a ogni cambio di scena**: entrando in un edificio, entrando in una stanza,
  tornando in strada;
- **a mezzanotte**, quando cambiano prezzi e attenzione;
- uscendo dalla mappa con Esc e alla chiusura della finestra.

Il salvataggio automatico è agganciato all'orologio di gioco, che gira solo
mentre si gioca davvero e non nei menu: così si salva solo quando c'è qualcosa
di nuovo da salvare. Serve perché un gestionale si gioca a sessioni lunghe con
poche uscite volontarie — si pianta qualcosa, si va in giro, si torna — e senza,
chiudere il gioco in modo brusco butta via tutto quello che si è fatto
dall'avvio.

### Lo stato che vive in scena

Non tutto sta dentro a `SaveData` mentre si gioca: **dove sta il protagonista lo
sa solo la mappa**. Per questo `GameState` emette `saving` subito prima di
scrivere, e `city.gd` ci aggancia `_collect_state()`.

Senza quel gancio funzionerebbe solo il salvataggio volontario (che passava per
`city.gd`), mentre quello automatico scriverebbe una posizione vecchia e
riprendendo la partita il protagonista ricomparirebbe dove stava qualche minuto
prima. È il punto in cui agganciare qualsiasi altro stato che in futuro viva
nell'albero invece che nei dati.

### Qual è "l'ultima partita"

`play` chiama `continue_last()`, che prende il primo di `list_saves()`, ordinati
per `saved_at` decrescente. Due dettagli che sembrano pedanteria e non lo sono:

- `saved_at` è un **float**, non un intero di secondi. Due salvataggi scritti
  nello stesso secondo avevano lo stesso istante, e "l'ultima partita" diventava
  una delle due a caso.
- A parità di istante decide il **nome dello slot**, che contiene data e ora ed
  è unico. Senza il secondo criterio l'ordine dipenderebbe da come il sistema
  elenca i file, e due salvataggi potrebbero scambiarsi di posto fra un avvio e
  l'altro.

### La cartella dei salvataggi

`GameState.save_dir` è una **variabile**, non una costante, e i controlli
automatici la spostano su `user://test_saves`.

Non è una raffinatezza: ogni partita creata da un test viene salvata, e girando
sulla cartella vera una manciata di esecuzioni riempie l'elenco di partite finte
— tutte con lo stesso istante di salvataggio. `play` ne caricava una di quelle,
vuota e al giorno 1, invece della partita del giocatore. È successo davvero.

### Aggiungere un dato alla partita

1. Aggiungi il campo `@export` in `SaveData`.
2. Aggiungilo a `to_dict()` e a `from_dict()` **con un valore di default**.

Il default è la parte che conta: i salvataggi vecchi non hanno quella chiave e
devono continuare a caricarsi prendendo il default, invece di rompersi. Per
questo `CURRENT_VERSION` va alzata solo quando cambia il *significato* di un
campo esistente (e allora si aggiunge il caso in `_migrate()`), non quando se ne
aggiunge uno nuovo.

Due trappole già gestite, da tenere presenti:

- Il parser JSON restituisce **ogni numero come float**. I campi in cima sono
  convertiti con `int()`, e `_restore_ints()` fa lo stesso ricorsivamente dentro
  ai dizionari liberi (`inventory`, `properties`, `stats`), altrimenti 30 grammi
  di merce tornerebbero come `30.0`.
- Il JSON non conosce `Vector2`: `player_position` viaggia come coppia di numeri.

### Orologio di gioco

`GameState` fa scorrere `time_of_day` (ore 0-24) e `day` mentre si è in mappa,
fermandosi nei menu. Il ritmo è la costante `GAME_MINUTES_PER_SECOND`: a 4.0
una giornata dura 6 minuti reali. È il numero da girare per tarare il gioco, e
va letto insieme a `grow_hours` della varietà — sono i due che insieme decidono
quanto dura un ciclo di coltivazione in minuti di orologio da parete (a 4.0, le
29 ore di gioco di una pianta sono circa 7 minuti reali).

A mezzanotte scatta il segnale `day_started(day)`. Ci è già agganciato
`Economy.roll_new_day()` (prezzo del giorno e raffreddamento dell'attenzione), ed
è il gancio pronto per affitti, consegne e ricarico della merce.

`GameState.total_hours()` dà invece il tempo **assoluto** dall'inizio della
partita: è quello con cui ragiona la coltivazione, perché `time_of_day` riparte
da zero ogni mezzanotte e non servirebbe a niente.

## Luce, ore e meteo

Il gioco aveva già un orologio che scorreva, ma non si vedeva da nessuna parte
se non nella riga dell'HUD: mezzogiorno e mezzanotte erano lo stesso identico
schermo. Adesso l'ora si legge guardando la strada.

Le regole sono due sole, e tutto il resto viene da lì:

1. Un `CanvasModulate` (`Atmosphere`, in `City.tscn`) moltiplica **tutto quello
   che sta sulla tela del mondo** per il colore dell'ora.
2. Le cose che devono restare **accese** dentro a quel buio — lampioni, fari,
   il rombo sopra la testa di Brian — si disegnano con
   `Daylight.emissive()`, che pre-divide il colore per quella stessa luce. La
   moltiplicazione del punto 1 lo riporta esattamente dov'era.

`scripts/data/daylight.gd` è la tabella: dieci momenti della giornata con il
colore dell'aria e quello del cielo, interpolati con `smoothstep`. Come la
crescita delle piante, la luce **non è simulata**: nessuno tiene un colore vivo
e lo porta avanti un frame per volta. Si guarda che ore sono e si ricava il
colore. Ricaricare una partita alle 19:40 la ritrova nella luce del tramonto in
cui era, e nel salvataggio non c'è scritto un solo colore.

### Perché non i `PointLight2D`

Godot ha le luci 2D vere, ed era la strada maestra. Il problema è il terreno:
`city_ground.gd` disegna **tutta** la città in un nodo solo, quindi ogni luce
del mondo "tocca" quell'unico oggetto, e un oggetto può ricevere un numero
limitato di luci per volta. Con centoventi lampioni le prime sedici si
prenderebbero tutti i posti e le altre smetterebbero di illuminare il terreno a
seconda di dove guarda la camera — un errore che compare e sparisce muovendosi,
cioè il peggiore da inseguire.

Con `emissive()` invece la luce è disegno: costa qualche poligono per lampione
**acceso e inquadrato** — uno fuori schermo non disegna niente — e resta dentro
all'Y-sort, quindi chi passa davanti a un lampione ci passa davanti davvero.

Che i colori sopra a 1.0 sopravvivano alla moltiplicazione non è stato dato per
buono: è stato provato sul motore prima di costruirci sopra. Con il
`CanvasModulate` a 0.3, un rettangolo disegnato a 3.0 viene fuori a 0.898.

### Cosa cambia con l'ora

| | |
|---|---|
| colore dell'aria | dieci keyframe, dal blu della notte al bianco di mezzogiorno all'arancio delle 19 |
| ombre | girano col sole (ovest all'alba, est al tramonto), corte a mezzogiorno, lunghe agli estremi |
| lampioni | si accendono un'ora prima del tramonto e si spengono un'ora dopo l'alba, con una salita graduale |
| fari e stop | accesi quando lo sono i lampioni |
| fondale oltre i bordi | segue l'aria, molto più cupo |

La notte **non scende mai vicino al nero**: un gestionale si gioca anche di
notte, e una notte a 0.1 è una schermata nera con dentro dei soldi da contare. A
fare la differenza fra giorno e notte sono i lampioni accesi, non il buio. C'è
un controllo automatico che lo verifica ora per ora.

### Le finestre accese: sono dentro al PNG

C'erano, si sono perse, sono tornate — e stavolta nel posto giusto.

Le facevano i segnaposto: si calcolavano una griglia di finestre sulla facciata
e la accendevano la sera, una per volta, ognuna con la sua soglia. Sostituendo i
segnaposto coi disegni sono sparite, e nessuno se ne accorgeva di giorno: la
pixel art le finestre accese ce le ha già dipinte. Di notte no — lo sprite è una
texture, il `CanvasModulate` della City moltiplica tutta la tela per il colore
dell'ora, e una finestra gialla dipinta nel PNG alle nove di sera diventa
marrone insieme al muro. La città si spegneva tutta in una volta come un
disegno a cui si abbassa la luce.

Adesso ogni edificio ha **due** PNG. Il secondo — `<nome>Lit.png` — è lo stesso
edificio fotografato con la stessa camera e la stessa inquadratura, ma con
dentro solo le cose accese su fondo nero: lo scatta `render_buildings.py` con
`modo_luci()`, che spegne sole, cielo e contorni e lascia emettere i soli
materiali che il modello dichiara già emissivi (`QP_Vetro_Acceso`, `QP_Vetrina`,
`QB_Vetro_Atrio`, le lampade). **Non c'è un elenco di quali finestre sono
accese**: sono quelle che di giorno si leggono come accese, perché sono lo
stesso dato. `import_flats_art.py` gira il nero in trasparenza, aggiunge
l'alone — a 22 px/m di una finestra accesa da lontano si vede l'alone molto
prima del vetro — e lo ritaglia **con lo stesso riquadro del disegno**, o in
gioco le luci si troverebbero due pixel a fianco delle finestre.

In gioco lo appoggia sopra `building_lights.gd`: sprite figlio dell'edificio,
opacità da `Daylight.lamp_strength()` (la stessa curva dei lampioni: le luci di
casa e quelle della strada devono accendersi insieme) e colore da
`Daylight.emissive()`, che pre-divide per la luce dell'ambiente così che la
moltiplicazione della sera lo riporti dov'era. Il muro si spegne, le finestre
no.

Il campo `"lit"` va su **tutti** gli edifici della pianta, e un controllo
automatico se ne accerta: un edificio senza è una sagoma nera in mezzo a una
fila di case abitate, e non si vede finché non è notte.

Restano dove sono, e con lo stesso meccanismo, i lampioni, i fari delle auto e
i segnalini: vedi "Perché non i `PointLight2D`".

### Il meteo

`scripts/data/weather.gd`: sereno, nuvoloso, coperto, pioggia, temporale,
nebbia. Ogni voce dice insieme come si vede (tinta, pioggia, nebbia, vento,
nuvole, fulmini) e **cosa cambia in partita**.

Il tempo di domani si tira a mezzanotte insieme al prezzo del giorno, dentro a
`Economy.roll_new_day()`, e si salva — come il prezzo, e per lo stesso motivo:
ricavarlo da giorno e seme sarebbe più compatto, ma basterebbe ritoccare la
tabella perché "il giorno che pioveva" diventasse un altro giorno in tutte le
partite salvate.

Non è un dado piatto su sei voci ma una **tabella di passaggi**: si annuvola
prima di piovere e si schiarisce dopo. Coi pesi piatti si passerebbe da sereno a
temporale e di nuovo a sereno in tre giorni, e il meteo si leggerebbe come
rumore invece che come stagione.

**Un meteo che non pesa è carta da parati.** Sotto la pioggia i clienti di
strada comprano circa un terzo in meno, ma ci si fa anche notare meno — la gente
cammina a testa bassa e le pattuglie restano in macchina. Una giornata brutta
diventa così una scelta (oggi si piazza tutto all'ingrosso dal PC?) e non solo
un danno. È lo stesso mestiere che fa il prezzo del giorno: dare un motivo per
cui domani non è uguale a oggi.

Dove sta cosa:

| | |
|---|---|
| `Atmosphere` | il colore dell'aria, il fondale, i fulmini |
| `GroundWeather` | **nel mondo**, sotto a tutto: ombre delle nuvole, asfalto bagnato, pozze, cartacce nel vento |
| `WeatherLayer/WeatherView` | **a schermo**, sopra a tutto: gocce, schizzi, foschia, il lampo, il buio agli angoli |

La divisione non è estetica. Un'ombra di nuvola ha un posto nella città, quindi
sta nel mondo: ancorata allo schermo scivolerebbe sui tetti mentre ci si guarda
intorno col tasto destro. La pioggia invece non ha un posto — è fra l'occhio e
la scena — e disegnata nel mondo bisognerebbe riempire di gocce mezza mappa per
vederne trenta. Le nuvole e le pozze sono ricavate da una griglia infinita
agganciata alla camera: non esistono finché non le si guarda, e sono sempre le
stesse.

### Dentro casa

Le stanze hanno la loro atmosfera (`scripts/systems/room_ambience.gd`), che fa
lo stesso mestiere con gli stessi due attrezzi — un `CanvasModulate` e
`emissive()` — ma con regole diverse, perché **dentro non è fuori**:

- la luce dell'interno è quella della strada **smorzata**, e dopo il tramonto
  vira verso la lampadina di casa invece di andare sul blu. Copiare la luce
  esterna vorrebbe dire una cucina blu notte alle dieci di sera, quando invece a
  quell'ora una cucina è il posto più caldo della città: è il contrasto fra le
  due cose a far sentire che si è rientrati;
- dalla finestra entra un **taglio di luce** che cade nella stessa direzione
  delle ombre di fuori, quindi la stanza e la strada raccontano la stessa ora;
- **fuori dalla finestra c'è l'ora che è.** Il fondale è un disegno fisso, e nel
  disegno fuori è sempre giorno: alle dieci di sera si vedeva un cortile
  assolato dietro ai vetri, ed era la cosa che rompeva di più l'illusione in
  tutta la stanza. Adesso sopra al vetro va il cielo di quest'ora, e di notte si
  accendono tre finestre nel palazzo di fronte;
- se piove, l'acqua scende **sul vetro** e non davanti alla stanza, perché da
  dentro è lì che si vede;
- il temporale entra anche in casa: il lampo accende prima la finestra e poi la
  stanza;
- c'è del pulviscolo nell'aria, che è la sola cosa che si muove in un interno e
  gli toglie l'aria di uno screenshot.

La **cantina** non ha niente di tutto questo di proposito: `daylight = false`.
Sottoterra l'ora non si vede, ed è esattamente il motivo per cui si perde la
cognizione del tempo a coltivare di sotto — l'orologio dell'HUD diventa l'unico
modo di sapere che ore sono. Quello che cambia lì è il rosso delle lampade da
coltivazione, che prende la stanza man mano che se ne comprano, e il tremolio
lentissimo del neon.

Nome della stanza e uscite restano **sempre della stessa luminosità**: sono
interfaccia, non arredamento, e una scritta che si spegne alle dieci di sera
sembra un errore e non un effetto. Gli si rimette addosso l'inverso della tinta,
che è lo stesso giro di `emissive()`.

L'atmosfera delle stanze non sta in `Room.tscn` ma la costruisce `room.gd`:
`Entrance`, `Kitchen`, `Basement` e `Garage` sono scene ereditate che si
riferiscono ai propri nodi per indice, e aggiungere un nodo alla scena base
sposterebbe quegli indici in tutte e quattro. È la stessa regola della città — la scena si costruisce
dai dati.

### Ridisegnare senza sprecare

Edifici, lampioni, auto e persone devono ridisegnarsi quando la luce cambia, ma
sono qualche centinaio: un `_process` a testa per guardare l'orologio sarebbe
qualche centinaio di chiamate a vuoto per frame. `Atmosphere` arrotonda l'ora al
quarto d'ora di gioco e avvisa il gruppo `Daylight.LIGHT_GROUP` solo quando quel
numero cambia — meno di venti avvisi per giornata di gioco. Chi ci si iscrive
implementa `on_light_changed()` e si iscrive da solo, senza che nessuno debba
tenere un elenco in un altro file.

### Tarare la luce

`scripts_tools/LightContactSheet.tscn` fotografa la città e le stanze a una
dozzina di ore e di condizioni, e salva i PNG in `user://shots/`. Va lanciato
**con la finestra**, non headless, perché senza rendering non c'è niente da
leggere:

```
Godot_v4.7.2-stable_win64_console.exe --path . scripts_tools/LightContactSheet.tscn
```

Serve perché la luce di un gioco si aggiusta guardandola, e guardarla a mano
vorrebbe dire aprire la partita e aspettare sei minuti reali per vedere passare
una giornata.

## Le vignette, e i canali per parlare al giocatore

Il gioco dice le cose in cinque modi, e la differenza fra loro è **quanto
pesano**:

| | Dove | Quanto dura | Per cosa |
|---|---|---|---|
| messaggino (`notify()`) | riga dell'HUD | 2,6 s | fatti da leggere con la coda dell'occhio: `+40 G RACCOLTI` |
| telefono (`text_message()`) | in basso a sinistra | 5,5 s, e resta rileggibile | messaggi **da qualcuno**: il personale, Brian |
| vignetta (`vignette()`) | bordo sinistro, a mezza altezza | finché non la si chiude | i momenti della storia, detti da un **personaggio** |
| avviso (`message()`) | al centro, con la tendina | finché non la si chiude | quando non parla nessuno: la società elettrica, il personale che se ne va |
| filmato (`van_cutscene()`) | tutto lo schermo, con le bande | 3,5 s, o un click | le cose che **succedono altrove**: per ora la partenza del furgone |

La **vignetta** è `assets/sprites/props/vignetta.png`, una nuvoletta da fumetto
col testo in nero. Un fumetto dice "qualcuno ti sta parlando" prima ancora che
si legga una parola, ed è quello che separa una battuta di Brian da un avviso
di servizio.

È una **notifica, non un muro**: sta di lato, non copre lo schermo, non oscura
niente dietro e non entra nel gruppo `modal` — HUD e telefono restano al loro
posto. Si chiude con un click **in qualunque punto della nuvoletta**; la `X` in
alto a destra è lì per dirlo, non per essere centrata.

Sta attaccata al **bordo sinistro a mezza altezza**, e ne sporge fuori di
qualche decina di pixel (`OVERHANG`): deve sembrare che arrivi da fuori, non che
sia appoggiata dentro, e il taglio sul bordo è quello che lo dice. A mezza
altezza resta lontana dalla riga dell'HUD in alto e dal telefono in basso a
sinistra.

**A sinistra e non a destra** perché la coda della nuvoletta punta in basso a
sinistra, e in un fumetto la coda indica chi parla. Appoggiata al bordo destro
puntava verso il centro dello schermo, cioè verso nessuno: si leggeva al
contrario. Sul bordo sinistro punta fuori campo, dove sta chi parla.

Quanto sporge è un compromesso, non un margine a caso: il campo bianco è largo
quasi quanto la nuvoletta, quindi **ogni pixel che esce è un pixel di testo in
meno**. A metà nuvoletta fuori resterebbero venticinque caratteri per riga e i
messaggi non ci starebbero. `OVERHANG` è l'unico numero da girare per farla
sporgere di più o di meno.

Due vignette insieme non si pestano: ognuna è un `CanvasLayer` suo, la più
recente finisce sopra, e chiudendola compare quella sotto.

### Scrivere dentro a un disegno

Il PNG è 1536x1024 ma il disegno ne occupa 1159x648 in mezzo: tutto il resto è
trasparenza. Mostrandolo intero, la nuvoletta a schermo sarebbe grande il doppio
del suo contenuto e il campo bianco si ridurrebbe a una striscia — quindi il
`TextureRect` usa un `AtlasTexture` ritagliato sul contenuto vero, misurato
sull'alfa del file.

Il ritaglio entra anche di venti pixel **dentro** al contenuto su tre lati:
intorno al campo bianco il disegno ha una cornice nera di 39 px che a schermo
pesava più della nuvoletta, e tagliandone metà resta il segno senza la mazzetta.
In basso si tiene tutto, perché lì c'è la coda — ed è la coda a dire che è un
fumetto e non un riquadro.

Il testo va dentro al **rettangolo pieno** del bianco (`INK`), non a quello
circoscritto: gli angoli della nuvoletta sono smussati a scaletta, quindi il
bianco arriva più in alto e più in basso ma non per tutta la larghezza. Il primo
tentativo usava il circoscritto e le righe finivano sul nero degli angoli.
`INK` è in **frazioni** e non in pixel, così la nuvoletta si ingrandisce
cambiando solo `BALLOON_SIZE` e il testo la segue.

Due cose imparate posizionandola, che valgono per qualunque `Control` costruito
da codice: con le ancore al centro Godot si riprende posizione e dimensione al
primo passaggio di layout, e calcolare il centro dalla dimensione del viewport
manda fuori campo perché quella non è la risoluzione di progetto. La nuvoletta
è appoggiata all'angolo con ancore e scostamenti, che è giusto a qualunque
risoluzione senza chiedere niente a nessuno.

### Perché le vignette non hanno punteggiatura

Il testo delle vignette è scritto col **font del gioco**, come il resto
dell'interfaccia: una battuta dentro a un fumetto scritta col font di sistema è
una didascalia, non una voce.

Il prezzo è che `alphabet.fnt` conosce **lettere e spazio e nient'altro** —
niente virgole, niente punti, niente apostrofi, niente cifre. Quindi i corpi
delle vignette sono marcati `PIXEL` in `Strings` come le voci dei menu, e a
mandare a capo è **la riga** e non la punteggiatura. In una nuvoletta funziona
meglio della punteggiatura comunque.

L'a-capo è ammesso nel controllo automatico e non è un'eccezione alla regola:
non è un carattere che il font deve disegnare, è dove la riga finisce.

### L'ombra è dentro al font, e per questo il testo è nero pieno

`alphabet.fnt` ha l'ombra **dipinta dentro alle lettere**: ogni glifo è una
faccia chiara, un contorno nero e un'ombra sfalsata. È un font fatto per
scrivere chiaro su fondo scuro — ed è così che lo usa tutto il resto
dell'interfaccia, che sta su fondi scuri.

Godot moltiplica l'intero glifo per `font_color`, quindi **l'ombra non si può
togliere da nessuna impostazione**. Su carta bianca, con un colore appena
schiarito, faccia e ombra restano due grigi diversi e la lettera diventa una
poltiglia. A nero pieno invece l'ombra si fonde con la lettera: resta un
carattere un po' più grasso, e si legge.

È il motivo per cui `INK_TEXT` e `INK_SPEAKER` sono nero assoluto e non un nero
"da stampa" come sarebbe venuto naturale scrivere.

Ne segue anche che il traguardo del chilo dice "un chilo" a parole invece di
scrivere il numero: le cifre non si possono disegnare.

E ne segue una misura: col font del gioco, in una nuvoletta di questa taglia ci
stanno **tre righe da una quarantina di caratteri**, non di più. I primi
tentativi erano da sei righe e le ultime finivano sull'asfalto sotto alla
nuvoletta. È il vincolo che ha dato ai messaggi di Brian la forma che hanno:
tre battute secche, senza subordinate.

### Quando parla Brian

| Quando | Cosa dice |
|---|---|
| all'inizio della partita | da dove viene la casa, e a cosa serve un seminterrato |
| primo chilo di merce | smettila di venderla un grammo per volta: serve un furgone |
| fine del prologo (1000 $) | assumi qualcuno, guarda il PC |
| primi 10.000 $ | vai in giro per il quartiere a guardare i posti vecchi in vendita o in affitto |

Sono tutti traguardi che scattano **una volta sola** e restano scritti nel
salvataggio. Stanno agganciati all'orologio (`GameState._check_milestones()`) e
non al punto in cui cambiano i numeri, per lo stesso motivo della fine del
prologo: soldi e merce entrano da troppe parti — il PC, la strada, il personale,
il furgone che rientra — e ricordarsi di chiamare il controllo da ognuna vuol
dire dimenticarselo da qualcuna.

Il messaggio d'apertura non sta in `new_game()` ma anche lui sull'orologio:
`new_game()` gira anche dal menu, e un fumetto dietro ai bottoni del menu
principale, prima ancora di vedere la città, non lo legge nessuno.

L'ultimo — i posti in vendita — per ora è **solo un messaggio**: le proprietà
non ci sono ancora.

## Il telefono

`scenes/ui/Phone.tscn`: il telefono in basso a sinistra. Scivola su quando
arriva un messaggio, si apre con la **freccia su**, e aperto è un'app di
messaggi — la rubrica, e dentro la chat con Brian, da cui si chiedono i semi
senza tornare al PC in cantina e si rileggono i messaggi vecchi. Sotto ai
contatti c'è il tasto che apre la **guida**, che però non si legge lì dentro:
vedi "La guida".

La scocca è un disegno — `assets/sprites/ui/phone.png`, nel nodo `Shell` di
`Phone.tscn` — e non più il rettangolo col bordo che c'era al suo posto. Il
`_draw()` di `phone.gd` è rimasto per quello che sta **sopra** al vetro e cambia
mentre si gioca: il velo dello schermo acceso, le tacche, l'orologio, il
triangolino che pulsa. `Shell` ha `show_behind_parent`, e questo è tutto quello
che serve a tenere l'ordine giusto: il disegno sotto, il `_draw()` sopra, le
etichette del messaggio sopra ancora.

Il telefono è cresciuto passando dal segnaposto al disegno, da 132x184 a
140x258, e non per scelta: un telefono vero è molto più stretto in proporzione,
e la cornice si mangia un settimo della larghezza. Sotto ai 140 px di scocca il
vetro scende sotto ai 112 che servono al menù e "LLAMA A BRIAN" si taglia
(vedi "Chiamare Brian da qui"); l'altezza viene dietro alle proporzioni del
disegno, perché schiacciarlo per farlo stare più comodo in basso a sinistra si
vedrebbe.

Il **notch** non è decorazione gratis: il velo dello schermo acceso lo lascia
fuori apposta, ed è il pezzo che fa capire a colpo d'occhio che quello è un
telefono e non un pannello. Le tacche e l'orologio gli stanno **di fianco**,
ventisei pixel per parte, come su un telefono vero: sotto ruberebbero una riga
al messaggio.

Dove stia il vetro dentro alla scocca non è deciso a occhio.
`scripts_tools/import_phone_art.py` riduce il disegno alla taglia del gioco e
**misura** il rettangolo del vetro e quello del notch, stampandoli già nella
forma delle costanti di `phone.gd`:

```
python scripts_tools/import_phone_art.py
```

La riduzione è la stessa degli edifici (premoltiplicazione e ritaglio: vedi "Gli
edifici disegnati si portano alla scala del gioco con uno script"), e
l'originale da 1254 px sta in `assets/sprites/ui/_source/` dietro a un
`.gdignore` come gli altri. Se la scocca viene ridisegnata con la cornice un po'
più spessa, senza rilanciare quello il testo del messaggio finisce sopra al
bordo.

### Perché non bastavano i messaggini dell'HUD

L'HUD ha già i suoi (`GameState.notify()`): durano due secondi e mezzo e
servono per le cose che si leggono con la coda dell'occhio — "+40 G RACCOLTI".
Due cose non ci stanno dentro:

1. **Vengono da qualcuno.** "I semi sono finiti" lo dice il personale, "sono
   arrivato" lo dice Brian. Un messaggino senza mittente è il gioco che parla;
   un messaggio sul telefono è una persona che scrive, ed è la differenza fra un
   promemoria e un pezzo di mondo.
2. **Vanno ritrovate.** Il messaggino sparisce dopo due secondi e mezzo.
   L'ultimo messaggio arrivato resta invece dentro al telefono e si rilegge
   aprendolo.

Resta separato anche dal riquadro a tutto schermo di `phone_notice.gd`: quello
ferma tutto per le cose che non si possono perdere — la fine del prologo — e si
chiude con un bottone. Questo scivola su, si legge e se ne va da solo, senza
togliere il controllo di mano. Tre canali, tre pesi diversi.

### I tre stati

| | |
|---|---|
| chiuso | fuori resta solo la **cima del telefono** — cornice, notch e il triangolino sotto, che pulsa di verde finché c'è un messaggio non letto |
| messaggio | scivola su fin dove finisce il testo, si legge, e dopo 5,5 s torna giù da solo |
| aperto | tutto fuori, ed è un'app di messaggi: la rubrica (i contatti, e sotto il tasto della guida), e dentro a ognuno la chat |

Chiuso **non sparisce mai del tutto**: quei trentaquattro pixel di telefono che
spuntano sono l'unica cosa che si vede per la maggior parte della partita, e
sono anche l'unico posto in cui si può dire "c'è qualcosa per te". Una
scorciatoia che non si vede da nessuna parte non la trova nessuno.

Il triangolino punta **in su** quando c'è da aprire e **in giù** quando c'è da
chiudere: è la stessa freccia della tastiera, e a telefono aperto una freccia
che punta ancora in su direbbe di premere il tasto che non fa niente.

Aperto e messaggio **non si mescolano mai**: l'avviso è un messaggio solo scritto
grande sul mezzo telefono che spunta e si legge senza fare niente, la chat è
tutto il filo e chiede di fermarsi a guardarla. Farli convivere vorrebbe dire
scrivere lo stesso messaggio due volte, una sopra all'altra. Per la stessa
ragione un messaggio che arriva **a telefono già aperto** non lo fa ripiegare
per annunciarsi: è appena comparso nella chat che si sta guardando.

### Chi scrive, e quando

| Mittente | Quando |
|---|---|
| PERSONALE | i semi sono finiti e ci sono vasi fermi (`Staff.seedless_alert()`) |
| BRIAN | ha mandato la posizione ed è sul posto ad aspettare |

I mittenti sono quelli che c'erano già (`MSG_STAFF_SPEAKER`,
`MSG_COUSIN_SPEAKER`): chi scrive è la stessa persona, che il messaggio arrivi
qui o nel riquadro a tutto schermo.

L'avviso dei semi parte **una volta sola** per ogni secca, e il permesso torna
da solo appena arrivano altri semi. Il flag sta nel salvataggio
(`Staff.SEEDLESS_FLAG`), non in memoria: senza, riaprire il gioco a magazzino
vuoto lo farebbe ripartire da capo ogni volta. E se i semi sono finiti mentre il
gioco era **chiuso**, a dirlo è già il resoconto del rientro (`AWAY_IDLE`),
quindi `Offline` segna il flag e il telefono non ripete un attimo dopo una
notizia appena letta.

C'è anche un caso in cui NON si avvisa: semi a zero ma vasi tutti pieni. Non c'è
niente da segnalare, il lavoro sta andando avanti.

### La chat, e le due specie di messaggio

Aperto, il telefono è una **rubrica** — per ora un contatto, Brian — e dentro
ci sta la **chat**: il filo dei messaggi in nuvolette, le sue a sinistra e le
tue a destra, col bottone della richiesta in fondo dove in un'app di messaggi
c'è la casella da cui si scrive.

La rubrica con un contatto solo sembra un passaggio in più, e non lo è per due
motivi. Il primo è che la riga di Brian porta sotto al nome **l'ultima cosa che
si sono detti**, quindi la rubrica è già una risposta alla domanda "che mi aveva
detto?" e il click serve solo a leggere il resto. Il secondo è che aprire il
telefono dritto su una chat vorrebbe dire che il telefono *è* quella chat, e il
secondo contatto — il personale, la società elettrica — costringerebbe a
rifare la schermata e a insegnare al giocatore un posto nuovo. Così invece è
una riga in `Chat.contacts()`.

Dentro alla chat ci sono **due specie di riga**, e la differenza è tutto il
punto di `scripts/data/chat.gd`:

| | cosa sono | dove stanno |
|---|---|---|
| restano | i messaggi dei traguardi: l'apertura, la fine del prologo ai mille, il consiglio di allargarsi, il chilo, il grossista | nel salvataggio, `SaveData.chat_log` |
| non restano | il giro della richiesta di semi: "servono semi" — "ci penso io" — "ti aspetto in MILL ROAD" — "me ne vado" | da nessuna parte: si ricavano |

I primi sono pezzi di storia e si rileggono a distanza di giorni. I secondi
finito l'appuntamento non vogliono più dire niente, e tenerli vorrebbe dire che
dopo dieci chiamate la chat con Brian è una fila di richieste identiche in cui i
cinque messaggi che contano non si trovano più.

**E il modo in cui spariscono è la cosa da capire di questo file: non li
cancella nessuno.** L'appuntamento è già tutto scritto dentro a
`SaveData.seed_deal` — quando è partita la richiesta, quando arriva la
posizione, dove, se Brian ha già avvisato che sta per andarsene — e da lì
`Chat.live()` riscrive il filo ogni volta che si apre la chat. Chiuso
l'appuntamento `seed_deal` si svuota (`SeedDeal.clear()`) e quei messaggi
smettono di esistere da soli: nessuna lista che qualcuno si può dimenticare di
ripulire, e nessun modo di ritrovarsi mezzo giro di messaggi di un appuntamento
finito ieri. È lo stesso trucco delle piante e dell'appuntamento stesso — lo
stato è una funzione di quello che c'è scritto nel salvataggio — e qui in più
fa da sé il lavoro di cancellare.

Ne viene dietro una cosa gratis: i semi chiesti **dal PC in cantina** compaiono
nella chat esattamente come quelli chiesti dal telefono, perché nessuno dei due
scrive niente — aprono l'appuntamento, e il filo lo legge da lì.

Nella cronologia ci finiscono **chiavi di traduzione, non frasi**
(`{"key": "MSG_KILO_BODY", "at": 53.5}`). Una cronologia di frasi già scritte
resterebbe nella lingua in cui la partita è cominciata anche cambiando lingua
dalle impostazioni, e sarebbe l'unico posto del gioco a farlo.

C'è anche una **pausa** fra la richiesta e la risposta (`Chat.REPLY_GAP`, un
paio di secondi veri): premendo il bottone si vede partire il messaggio e poi
arrivare la risposta. Senza, le due righe comparirebbero insieme e non si
leggerebbero come una conversazione ma come un blocco di testo che si accende.
Anche quella è ricavata — è un'ora di gioco dopo `asked_at`, non un timer.

### La guida

In fondo alla rubrica, staccato dai contatti da un filetto e scritto di un
altro colore, c'è il tasto della **guida**: come funziona il giro, in sei
sezioni — le piante, i semi, andare più forte, il personale, l'ingrosso,
l'attenzione della polizia.

**Il tasto sta nel telefono, la guida no.** Quella è una finestra a tutto
schermo (`scenes/ui/GuideBook.tscn`), appesa a `GameState` come il riquadro dei
messaggi e il filmato del furgone. Il motivo è la misura: il vetro del telefono
è largo centoquattordici pixel, e sei pagine di spiegazioni lì dentro vengono
fuori a quattro parole per riga — si scorre per un minuto e non si è letto
niente. Il telefono è il posto in cui la guida si **trova** (è lì che uno va a
cercare le cose, e una guida in un menu di impostazioni non la trova nessuno);
la finestra è il posto in cui si **legge**. Due lavori diversi, due schermate.

La finestra ha la pelle del gestionale del PC (`UiTheme`) e non una nuova: sono
la stessa cosa — roba da leggere, non da guardare — e due carte diverse nello
stesso gioco si notano. Colonna delle sezioni a sinistra come nel PC, perché sei
paragrafi uno sotto l'altro si scorrono ma per ritrovare quello che serve
bisogna rileggerli tutti. Entra nel gruppo `modal`, quindi HUD e telefono si
tolgono di mezzo da soli e tornano quando si chiude.

Una cosa che vale la pena sapere: un paragrafo che comincia con una parola
**tutta maiuscola seguita da un punto** diventa un occhiello in grassetto
("PIÙ VASI.", "GROW TOOLKIT.", "LAMPADE."). È un trucco tipografico e non una
struttura dati, e deve restare tale — il testo si scrive in `Strings` come si
scriverebbe comunque, e chi traduce non deve imparare nessuna convenzione.

**Perché una guida e non un tutorial.** Questo è un gestionale, e un gestionale
si gioca su dei numeri che il giocatore non può indovinare: che una pianta ci
metta venti ore, che la sete tolga due terzi del raccolto, che una lampada valga
per **un** vaso solo e non per tutti. Senza quelle cose scritte da qualche parte
i primi giorni di partita sono lenti e sembrano rotti — si pianta, si aspetta,
si raccoglie meno del previsto, e non c'è modo di capire perché. Un tutorial le
direbbe una volta all'inizio, quando non servono ancora e infatti non le legge
nessuno; la guida sta sempre lì e si apre quando ci si impantana, che è il
momento in cui uno ha una domanda — l'unico in cui una risposta si legge
davvero.

È anche il motivo per cui il **messaggio d'apertura** di Brian la nomina: "all
inizio cresce piano non mollare, nel telefono trovi una guida e me". Il
messaggio dice che la lentezza è normale, la guida dice cosa farci. Un controllo
automatico verifica che quel messaggio nomini la guida in tutte e tre le lingue:
chi riscrive il messaggio e si dimentica quella riga lascia la guida dove nessuno
la cerca.

Quel messaggio è anche il più lungo che il gioco manda, ed è il primo che si
legge: è lui a decidere quanto il telefono resta fuori durante un avviso
(`PEEK`, centonovantaquattro pixel). A centosettantotto perdeva l'ultima riga,
che è proprio quella che manda alla guida.

**Dentro la guida niente è PIXEL.** È l'unico posto del gioco in cui si scrivono
dei numeri di bilanciamento per esteso — 154$, il 15%, dodici ore — e per
quelli serve il font di sistema, che le cifre ce le ha (il font disegnato del
gioco resta per il titolo della finestra, come nel gestionale). Il che vuol dire
anche che quei numeri devono restare allineati a `Economy`, `Shop`, `Grow` e
`Staff`: **quando si ritocca il bilanciamento, la guida è la tabella da
rileggere.** Una guida che dice il falso è peggio di nessuna guida. Un controllo
automatico verifica almeno che tutte le chiavi esistano, perché una che manca
non avvisa: `tr()` restituisce la chiave, e a schermo comparirebbe
`GUIDE_HEAT_BODY` al posto di un paragrafo.

### Chiamare Brian da qui

Il menù ha per ora una voce sola, ed è la stessa cosa che fa il bottone nella
scheda GROW del PC. **Non è un doppione per sbaglio**: i semi finiscono mentre
si è in giro per la città, e prima l'unico modo di chiederne altri era tornare
in cantina ad aprire il PC — cioè attraversare la mappa per premere un bottone.

Come nel PC è **un bottone solo che cambia faccia** invece di tre che si
accendono a turno: `CHIAMA BRIAN`, `CI PENSA LUI` mentre si aspetta, `TI
ASPETTA` quando è sul posto, spento quando non c'è niente da fare.

Quelle tre scritte hanno un **tetto di lunghezza vero** (`Strings.PHONE_MENU_CHARS`,
tredici caratteri): il vetro del telefono è largo 116 px e il bottone taglia
quello che avanza. È già successo — "BRIAN CI PENS" — e adesso c'è un controllo
automatico che lo verifica, perché a leggerle nella tabella sembrano tutte corte
uguali.

### Uno per scena, il testo no

Il telefono è un nodo di scena: sta in `City.tscn`, e nelle stanze lo costruisce
`room.gd` da codice (stessa ragione dell'atmosfera — `Room.tscn` è la scena base
delle altre tre e aggiungerci un nodo sposterebbe i loro indici).

Quello che c'è **scritto dentro** invece non sta nel telefono, e sta in due posti
diversi a seconda di quanto deve durare. L'**ultimo avviso** vive su
`GameState.last_text`: un messaggio arrivato in cantina si rilegge uscendo di
casa, ma non finisce nel salvataggio — è quello che è appena successo, non un
pezzo di partita. La **chat** invece sta nel salvataggio (`SaveData.chat_log`) e
nell'appuntamento, ed è il motivo per cui il telefono può essere un nodo di
scena senza portarsi dietro niente: ne esiste uno per stanza, e trovano tutti le
stesse cose scritte.

## HUD

`scenes/ui/HUD.tscn`: quello che sta addosso alla città mentre si gioca, e i
messaggini che scorrono sotto. Quattro cose, e ognuna sta dove sta per un
motivo — la **cassa** in cima al centro, la **sveglia** in alto a destra, il
**tasto a tre righe** in alto a sinistra, e sotto alla sveglia una riga che
compare solo quando c'è qualcosa da dire (per ora: il posto dove aspetta Brian,
finché aspetta). Sta sia in strada sia **dentro agli edifici** — è figlio di
`Room.tscn`, quindi tutte le stanze se lo ritrovano senza che vadano toccate una
per una.

```
 ≡              4.820 $              [ 15:40  DAY 20 ]

 (col menu aperto)
 ┌────────────────────┐
 │ SCORTA      340 g │
 │ SEMI            6 │
 │ SPACCIATORE     1 │
 │ COLTIVATORE     2 │
 └────────────────────┘
```

### La cassa

`scripts/ui/money_badge.gd`. Tutto il resto dell'HUD sta negli angoli; il centro
in alto è il posto che l'occhio trova senza cercarlo, e in un gestionale c'è
**un** numero che merita quel posto.

Per un giro la cassa era finita dentro al menu insieme alla scorta, ed era
troppo: la scorta è una cosa che si va a controllare, i soldi sono la cosa che
dice se quello che stai facendo sta funzionando. Sono tornati fuori, ma non dove
stavano prima — in un angolo, accanto ad altri quattro numeri, diventavano
arredamento.

**È scritta in rilievo, e non è decorazione.** Sta sopra alla città senza fondo,
e sotto ci passa di tutto: un muro chiaro, l'asfalto, il cielo, un lampione
acceso. Una scritta piatta con un'ombra sola su certi fondali si legge male e su
altri sparisce. Il rilievo si fa in tre passate:

1. una **sagoma scura** che copre il blocco intero — faccia e fianchi insieme —
   allargata di un pixel in tutte le direzioni;
2. i **fianchi**, dal più lontano al più vicino (disegnati al contrario si
   coprirebbero fra loro e il rilievo verrebbe alto un pixel);
3. la **faccia**.

I fianchi sono due pixel a corpo diciannove. A tre il rilievo si vedeva prima
del numero — quasi un sesto dell'altezza della cifra, e le lettere diventavano
oggetti invece che scritte; a uno il fianco si confonde col filo nero della
sagoma e resta solo una scritta col bordo.

La prima passata è quella che il primo tentativo non aveva, e senza di lei i
fianchi si leggevano come un'ombra sfocata invece che come lo spessore della
lettera: serve sia a non far toccare mai il fondale al numero, sia a mettere un
filo nero fra la faccia chiara e il fianco scuro. La sagoma si fa a mano,
ripetendo la scritta sui nove intorni di ogni posizione, e **non** con
`draw_string_outline()`: quello traccia il contorno di *una* passata, quindi
seguirebbe la faccia e lascerebbe i fianchi fuori.

Il colore dei fianchi è quello della faccia **scurito**, non nero: un'ombra nera
si legge come un'ombra portata, il colore scurito si legge come lo spessore
della stessa lettera. È la differenza fra una scritta con l'ombra e una scritta
di plastica.

### Il menu a tre righe

`scripts/ui/hud_menu.gd`. Dentro c'è **com'è messa la produzione**: la merce
pronta, i semi in mano, quanti vendono e quanti coltivano. Sono le quattro cose
che dicono se la macchina sta girando, e hanno in comune di essere tutte cose
che **si vanno a controllare** — nessuna cambia mentre si cammina per strada, e
nessuna chiede di essere guardata di continuo.

I nomi dei ruoli sono quelli del PC (`Staff.ROLES`, quindi SPACCIATORE e
COLTIVATORE) e non due parole scritte nel menu: nel gestionale si assume
"SPACCIATORE", e trovarselo chiamato in un altro modo qui vorrebbe dire due
mestieri invece di uno.

**Il pannello è un interruttore, non un tasto da tenere premuto**: si apre e
resta aperto finché non lo si chiude. Chi vuole quei numeri sempre davanti se li
tiene aperti, chi non li vuole ha uno schermo che è tutto città.

Sta a sinistra perché a destra c'è già la sveglia e sotto ci passano i
messaggini: è l'unico angolo in alto rimasto vuoto, ed è anche quello in cui un
menu si cerca per abitudine. Da chiuso è tre righe, da aperto diventa una X —
il pannello dice che c'è qualcosa di aperto ma non dice **dove si clicca per
chiuderlo**, e tre righe che non cambiano sembrano un tasto che non ha fatto
niente.

È anche l'unico pezzo dell'HUD con un fondo, e non contraddice il "niente fondo"
del resto: quella regola vale per le cose che stanno lì sempre, mentre questo è
un cassetto che si apre, e un cassetto senza pareti non si legge come aperto.
(La cassa in cima non ha un fondo neanche lei: a tenerla staccata dalla città
c'è il rilievo.)

Una cosa da sapere se ci si aggiunge una riga: **la misura del pannello si
chiede al pannello, non si scrive**. Si allarga col numero che ha dentro
("1.250.000 $" è metà più largo di "4.820 $") e il rettangolo del nodo è quello
che si mangia i click — se resta della misura scritta a mano, cliccare sulla
parte di pannello che avanza manda il protagonista a camminare sotto al menu.

### La sveglia

`scripts/ui/digital_clock.gd`, col disegno in `assets/sprites/ui/clock.png`.

L'ora e il giorno erano una voce come le altre: "GIORNO 6  15:36", stesso font e
stesso colore di tutto il resto. Funzionava e non diceva niente — due numeri in
mezzo ad altri numeri, che si smettono di vedere dopo dieci minuti. In un
gestionale dove **il tempo è la risorsa** (le piante crescono a ore di gioco,
Brian aspetta a ore di gioco, le paghe scattano a mezzanotte) l'orologio merita
di essere una cosa che si guarda. Adesso è una sveglia da comodino rossa, con
`15:40` grande a sinistra e `DAY 20` piccolo a destra, dove sta il display
secondario di una sveglia vera.

È **78x52 px**, e per un giro è stata 108x69: in un angolo dello schermo
diventava l'oggetto più grande dell'interfaccia, e questo è un gioco in cui si
guarda la strada. Rimpicciolirla di un terzo non ha però fatto perdere un pixel
alle cifre, che sono alte quindici come prima — quasi tutto quello che si è
tolto era **vetro sprecato intorno**. Il margine di sicurezza con cui lo script
ritagliava il display (`INSET`) era il doppio del necessario, e quei due pixel su
quindici sono la differenza fra leggere una cifra e indovinarla.

**Le cifre sono disegnate a sette segmenti, non scritte con un font.** Tre
motivi, in ordine di peso: è il display che rende la sveglia una sveglia (un
font di sistema dentro a quel buco nero resta un font di sistema dentro a un
buco nero); i **segmenti spenti** si intravedono anche quando non sono accesi,
ed è il dettaglio che fa leggere l'oggetto come acceso invece che come
un'immagine dell'oggetto — con un font non si possono disegnare, non esistono
come glifo; e non c'è nessun file da aggiungere.

La scritta **DAY** invece è a pixel e non a segmenti, ed è come sono fatti gli
apparecchi veri: le cifre sono a segmenti perché devono cambiare, la parola è
stampata sul vetro e non cambia mai. C'è anche una ragione pratica, scoperta
mettendola a schermo: una "A" a sette segmenti alta cinque pixel viene fuori
come tre macchie. Non passa dalle traduzioni, come i nomi delle strade — e
comunque "GIORNO" a sette segmenti non esiste, perché la G, la R e la N non si
scrivono. Il giorno a parole, tradotto, c'è già nel gestionale del PC.

**Il vetro è storto e le cifre pure.** La sveglia è disegnata di tre quarti,
quindi il display non è un rettangolo ma un parallelogramma che scende verso
destra: una riga di cifre orizzontale là dentro si legge come un adesivo
appiccicato sopra. Tutto quello che finisce nel display passa da una
trasformazione inclinata, e la pendenza non è presa a occhio — la misura
`scripts_tools/import_clock_art.py` sul disegno mentre lo riduce alla taglia del
gioco, insieme al rettangolo del vetro:

```
python scripts_tools/import_clock_art.py
```

Il vetro lo trova col riempimento e non a soglia: il contorno nero della scocca
è scuro quanto il display e gira intorno a tutto il disegno, quindi una soglia
sola li prenderebbe insieme. Lo script stampa `SIZE`, `GLASS` e `SHEAR` già
pronti da ricopiare nelle costanti di `digital_clock.gd`.

Le misure dentro al display non sono scalabili a piacere. La regola è che
**altezza meno tratto dev'essere pari**: è quello che tiene il segmento di mezzo
centrato su un pixel intero (metà di 16-2 fa 7), e sbagliandola cadrebbe a metà
pixel e sfocherebbe.

Il **tratto è due e non uno**, che a schermo è la differenza fra cifre disegnate
e cifre accese: con un pixel i segmenti sono dei fili e il display si legge come
una scritta, con due sono barre e si legge come un apparecchio. Costa però tre
pixel per cifra, e il vetro è largo cinquantasei — l'orario ne prende
trentotto, i margini due, e quello che resta deve bastare al giorno **anche a
tre cifre**. Per questo le cifre del giorno sono larghe quattro e non cinque:
a cinque il blocco farebbe diciassette e andrebbe a toccare l'orario, come era
successo la prima volta (`23:58128`).

Le cifre sono **verdi** da quando la sveglia è rossa. Erano ambra finché la
scocca era verde oliva — lì l'ambra era il complementare e il verde sarebbe
sparito dentro al suo stesso colore. Sul rosso vale l'opposto: l'ambra gli stava
addosso, nella stessa famiglia calda, e a un metro di distanza il display si
perdeva nella scocca. È anche il motivo per cui il colore è una costante e non
un valore scritto dentro alle funzioni di disegno: dipende dal disegno della
scocca, e i disegni cambiano.

I due punti **lampeggiano sul secondo vero**, non su quello di gioco:
l'orologio del gioco corre quattro minuti al secondo, e due punti che
lampeggiano a quel ritmo sembrano un guasto. È l'unica cosa del nodo che segue
il tempo reale, ed è giusto così — è il battito dell'oggetto, non della
partita. Da spenti restano **bassi ma visibili** e non spenti del tutto: a due
pixel di lato, un lampeggio vero faceva diventare l'orario "15 40" con un buco
in mezzo, che si legge come un display rotto.

### Perché il resto non ha un fondo

Prima era un riquadro con bordo e sfondo, coi valori impilati dentro. Un
pannello in un angolo è una finestra piccola: ruba spazio anche quando non ha
niente da dire, e in un gioco dove si guarda la strada e si clicca sulle cose,
il bordo continua a segnare un rettangolo che non è parte del mondo. A tenere le
scritte leggibili sopra a qualunque fondale c'è l'ombra dura sotto a ognuna.

Per un giro c'è stata una pastiglia di carta chiara dietro, per farla intonare
col gestionale: sopra alla città diventava un rettangolo bianco piantato in un
angolo, cioè esattamente il pannello che si era tolto. **La sveglia è
l'eccezione, ed è voluta**: non è una cassa dietro a del testo, è un oggetto.

### Cosa NON c'è più

L'**attenzione della polizia** era l'unica voce che non fosse un numero ma uno
*stato* scritto a parole ("SORVEGLIATO"), e in un angolo pieno di cifre si
leggeva come un allarme acceso a metà partita e poi mai più guardato. Il dato
non è sparito: sta nella scheda OVERVIEW del PC (`PC_ATTENTION`), che è il posto
in cui uno va a guardare come sta andando.

Il **tempo che fa** era l'unica voce che raccontasse una cosa **già a schermo**:
se piove, piove addosso alla città (`weather_view.gd`), e la parola "PIOGGIA" in
un angolo non aggiungeva niente a quello che si sta già guardando. Cosa cambi il
tempo — si vende meno in strada, ci si fa notare meno — lo spiega la guida, che
è il posto delle regole.

Quello che resta nella riga sotto alla sveglia compare solo quando ha qualcosa
da dire, e la regola per aggiungercene altre è una sola: **ci va solo roba che
serve mentre si cammina**. Tutto quello che si guarda per decidere — la scorta,
i semi, il personale, l'attenzione — sta dietro al menu o dentro al PC. La
differenza è fra un'informazione che si legge muovendosi e una che si legge
fermi.

I **messaggini** (`GameState.notify()`) restano quello che erano: compaiono in
basso a destra sotto all'angolo, ne stanno quattro alla volta e se ne vanno da
soli dopo due secondi e mezzo. Servono perché in un gestionale la maggior parte
delle azioni cambia solo un numero da qualche parte: senza un riscontro
immediato il giocatore non sa se il click ha fatto qualcosa.

## Entrare negli edifici

Cliccando sulla casa questa si schiaccia un istante come un pulsante, il
protagonista ci cammina davanti, svanisce nella porta e si apre la stanza.

Il pezzo riutilizzabile è `scripts/components/enterable_building.gd`, che
`city.gd` attacca allo `Sprite2D` dell'edificio — così la schiacciata al click
agisce sul disegno vero. Ce l'hanno tutti gli edifici che danno su una strada:
quelli senza `interior_scene` fanno solo avvicinare il protagonista, e rendere
visitabile il minimarket vuol dire aggiungere `"interior"` alla sua voce in
`CityMap.BUILDINGS`, niente altro. Non ce l'hanno i **fondali** dentro agli
isolati, che sono sprite e basta: vedi "Come si riempie un quartiere".

### Le proprietà si aprono comprandole

Una voce con `"owned": true` ha un interno che esiste già ma resta chiuso finché
quell'edificio non è fra le proprietà della partita. È il caso del **garage su
CROSS STREET**: prima dell'acquisto ci si cammina davanti e basta, e l'HUD dice
perché; comprato dall'agenzia, la porta si apre come quella di casa.

La chiave è l'`id` della pianta, che è già quello con cui l'agenzia vende
(`real_estate.gd`) e quello con cui la partita segna il posseduto
(`SaveData.owns()`). Non c'è nessun elenco in più da tenere allineato: **una
proprietà nuova è una riga di dati**, un annuncio in `RealEstate.LISTINGS` e un
`"interior"` con `"owned": true` nella sua voce di `CityMap.BUILDINGS`.

Per adesso l'interno del garage è una stanza a **fondale vuoto**: nome in alto,
protagonista, uscita. Il disegno arriverà come è arrivato quello delle altre
stanze, senza toccare niente di questo.

### Il nome sotto al puntatore

Passando il mouse sopra a un edificio compare la sua insegna, appesa al
puntatore. Serve perché la città è fatta di disegni e non di cartelli: una
palazzina come un'altra non dice se è l'agenzia, il garage in vendita o casa, e
senza un nome l'unico modo di saperlo era cliccarci sopra e vedere dove si
finiva.

Il nome è il campo `label` di `CityMap.BUILDINGS`, lo stesso con cui Brian dà gli
appuntamenti: sono tutti e due "come si chiama quel posto", e tenerne due
versioni vorrebbe dire vederle divergere. Un edificio senza `label` resta
cliccabile e semplicemente non dice niente.

Il corpo è **8**, lo stesso dei nomi che gli NPC si portano sopra la testa
(`npc.gd`): sono la stessa informazione — come si chiama quello che c'è sotto al
puntatore — e a corpi diversi si leggerebbero come due cose diverse. È anche la
misura giusta per una scritta che compare e sparisce muovendo il mouse: più
grande si mette a gridare sopra a una città in cui tutto il resto è disegnato.

L'etichetta sta su una tela sua (layer 4, sotto all'HUD e sotto alle finestre)
perché segue il puntatore in coordinate di **schermo**: con la camera che si
muove e zooma, un nodo del mondo dovrebbe rifare quel conto al contrario a ogni
fotogramma. Vicino al bordo destro o in cima si ribalta dall'altra parte del
puntatore invece di essere tagliata.

### Le insegne dipinte sugli edifici

L'agenzia ha **REAL ESTATE** scritto sulla fascia sopra le vetrine. È quello che
la fa riconoscere da fuori: senza, è una palazzina come le altre.

La scritta è un PNG a parte (`assets/sprites/buildings/signs/`), appeso
all'edificio dai campi `"sign"` e `"sign_at"` della pianta e aggiunto da
`city.gd::_make_building()` come **figlio** dello sprite — così segue la
schiacciata del click e la luce dell'ora come fosse dipinta sul muro.

Un file a parte e non due pennellate sul disegno dell'edificio, per due motivi:
i PNG degli edifici li riscrive `import_flats_art.py` partendo da Blender, e una
scritta dipinta sopra sparirebbe al primo re-import senza che nessuno se ne
accorga; e un'insegna è testo, cambia perché cambia il gioco, non perché cambia
il modello 3D.

Le lettere le disegna `scripts_tools/make_signs.py`, con un alfabeto 7x9 scritto
lì dentro. Non usa `alphabet.fnt`, che è alto 53 px e antialiasato: rimpicciolito
agli undici pixel di una fascia diventa una macchia grigia. Nell'alfabeto ci
sono solo le lettere che servono, e una che manca alza un errore invece di
lasciare un buco nella parola.

Che un edificio non sia pavimento su cui passare è voluto: cliccarci sopra
significa "vacci", non "attraversalo".

Il click viene risolto da `city.gd::_building_at()`, che interroga il gruppo
`enterable` invece di usare aree fisiche: niente layer di collisione da tarare,
e se due edifici si sovrappongono vince quello più in basso, cioè quello che
l'Y-sort disegna davanti — quello che il giocatore crede di aver cliccato.
`city.gd::_npc_at()` fa la stessa cosa con le persone, che hanno la precedenza:
chi clicca su un passante fermo davanti a un negozio vuole il passante.

Un click vuol dire quindi tre cose diverse — "vai lì", "vai a parlargli", "vai a
entrarci" — e in tutti e tre i casi prima si cammina. Quello che succede
all'arrivo se lo ricordano `_talking_to` / `_entering` e lo esegue
`_on_player_arrived()`.

## Stanze

`scenes/rooms/Room.tscn` è la stanza base; `Entrance`, `Kitchen`, `Basement` e
`Garage` sono **scene ereditate** che cambiano solo `room_name`,
`background_color`, `exits`, e i due campi della luce — `daylight` e
`window_rect`. La logica sta
tutta in `scripts/rooms/room.gd`, una volta sola.

`window_rect` dice dove sta la finestra **come si vede a schermo**, non sul PNG:
il `Backdrop` ritaglia l'immagine (`keep_aspect_covered`), quindi va misurato su
uno screenshot e non sul file. Un rettangolo vuoto vuol dire nessuna finestra.
`daylight = false` è la cantina, che sottoterra non ha né ora né tempo. Cosa ne
segue sta in "Luce, ore e meteo" → "Dentro casa".

Sopra a `Background` (il colore pieno di ripiego) c'è `Backdrop`, un
`TextureRect` in `keep_aspect_covered`: gli si assegna il PNG del fondale nella
scena ereditata e riempie i 640x360 ritagliando quel che avanza. Senza texture
resta invisibile e si vede il colore, come prima.

Il `Basement` è la prima stanza con fondale vero
(`assets/sprites/buildings/basementBack.png`, 1254x1254 isometrico): il
personaggio sta a scala 4.6x sul pavimento libero a destra del tavolo, con un
`modulate` leggermente scuro/caldo per stare nella luce della stanza. Il nodo `Shadow` sotto a `Character` (un `Polygon2D` ellittico con
`z_index = -1`) gli fa da ombra a terra e lo « appoggia » sul pavimento.

È anche il posto di lavoro: ci stanno i **sei vasi** (`Plot0`..`Plot5`,
istanze di `scenes/components/GrowPlot.tscn` con l'indice del vaso in `index`) e
il **PC** del gestionale.

I vasi sono appoggiati **sul tavolo del fondale**, due file da tre. Il piano del
tavolo è un parallelogramma in prospettiva isometrica, misurato sul disegno:
angolo sinistro in (135, 235), asse verso il fondo-destra (180, -50), asse verso
il davanti-destra (117, 40). Le posizioni dei sei vasi sono calcolate su quei due
assi, non messe a occhio — è il motivo per cui le file seguono la prospettiva
invece di essere orizzontali, e la formula è quella da rifare se il fondale
cambia.

Le due file si sovrappongono in verticale, com'è giusto in prospettiva: la fila
davanti (`Plot3`..`Plot5`) deve stare **dopo** nell'albero della scena, altrimenti
verrebbe disegnata dietro a quella di fondo. Per lo stesso motivo le etichette
hanno un contorno scuro, e lo stato "bloccato" è appena accennato invece che
pieno: tre riquadri grigi opachi su un tavolo coprirebbero mezzo fondale.

`Entrance` e `Kitchen` hanno anche loro il fondale vero
(`ingressoback.png` 1254x1254, `kitchenBack.png` 1402x1122). Le stanze senza
fondale mostrano solo il protagonista in grande e fermo, il nome della stanza in
alto e le uscite in basso.

**Il `Character` delle stanze è centrato su `position`**, a differenza del Player
in città che ha l'origine ai piedi. I piedi cadono quindi a
`position.y + 19.5 * scale`, e li si vuole intorno a **y 296**: sul pavimento e
sopra alla fila delle uscite (y 308-340). Sbagliare questo conto mette il
personaggio con le scarpe dentro ai tasti.

La mappatura fra pixel del disegno e pixel di schermo dipende dal formato del
PNG, perché `Backdrop` è in `keep_aspect_covered`:

| Fondale | Formato | Da immagine a schermo |
|---|---|---|
| `basementBack.png` | 1254x1254 | `img * 0.5104 - (0, 140)` |
| `ingressoback.png` | 1254x1254 | `img * 0.5104 - (0, 140)` |
| `kitchenBack.png` | 1402x1122 | `img * 0.4565 - (0, 76)` |
| `garageBack.png` | 1448x1086 | `img * 0.4420 - (0, 60)` |

È la formula da usare per piazzare qualcosa su un dettaglio preciso del disegno.
Il modo più rapido per ricavarla su un fondale nuovo è sovrapporre una griglia di
coordinate e misurare.

#### I due banconi del garage

`garageBack.png` non è un fondale muto: i **due banconi** sono i vasi, sei per
bancone su **due file da tre**. Il disegno li mostra dall'alto, quindi il piano
è un parallelogramma con profondità vera, e le sei posizioni non si scrivono a
mano: si prendono i **quattro angoli** del piano e si interpola.

| Bancone | angoli del piano (dietro-sx, dietro-dx, davanti-dx, davanti-sx) |
|---|---|
| sinistro | (154,181) (290,168) (297,222) (152,229) |
| destro | (332,168) (492,179) (487,216) (326,223) |

Le colonne stanno a `u = 1/6, 1/2, 5/6`, le due file a `v = 0.30` e `v = 0.86`.
Interpolare invece di scrivere dodici coppie di numeri vuol dire che se il
disegno cambia si rimisurano **quattro punti per tavolo** e le sei posizioni
escono da sé — ed è già successo una volta, quando il fondale è stato
ridisegnato dalla vista frontale a quella dall'alto.

Nella scena la fila **dietro viene prima**: i nodi si disegnano nell'ordine in
cui stanno, e un vaso davanti deve coprire quello dietro, non il contrario.

##### Il vaso si clicca, la pianta no

Mettendoli su due file è saltato fuori un errore che non si vede guardando la
stanza: **tutti e sei i vasi della fila dietro erano inservibili**.

La cornice di un vaso è alta quarantadue pixel perché lì dentro ci cresce la
pianta, ma il vaso disegnato sta nei venti pixel in fondo. Il resto è aria — e
su due file quell'aria cade esattamente sopra al vaso della fila dietro. Godot
sceglie per rettangolo, non per pixel disegnato, quindi cliccando un vaso della
fila dietro rispondeva quello davanti, che lì non ha niente di visibile.

`grow_plot.gd::_has_point()` limita ora l'area sensibile ai `HIT_HEIGHT` pixel in
fondo alla cornice: si clicca il vaso, non le foglie. Vale per il click e per
l'hover insieme, perché accendere il riquadro di un vaso passando sopra alla
pianta di un altro si leggerebbe come un errore di disegno.

Il controllo automatico **"i vasi nelle stanze"** apre le scene vere di cantina e
garage e chiede a ogni vaso chi risponde al click sul proprio disegno. Spostare
un vaso di dieci pixel può renderlo inservibile senza che niente lo dica, e
questo è l'unico modo di accorgersene senza provarli a mano uno per uno.

##### Il resto della stanza

Le **scritte di stato** sotto ai vasi compaiono solo col mouse sopra quando la
cornice è più stretta di `CAPTION_MIN_WIDTH` (`grow_plot.gd`): sei parole lunghe
quanto "FIORITURA" a quarantasei pixel di distanza diventano una striscia di
lettere attaccate. Quello che serve a colpo d'occhio resta disegnato — la pianta
cresce, la barra si riempie, quella pronta pulsa d'oro, quella assetata ha la
goccia — e l'elenco per esteso sta nella scheda GROW del PC.

Il **PC** è sul banco degli attrezzi a sinistra (x 120-176, y 76-102), sopra la
riga dei vasi e senza toccarla: apre lo stesso `ManagementWindow.tscn` di quello
in cantina. Non è una copia, è lo stesso gestionale: da qualunque PC si vedono
tutti i vasi, di tutte e due le proprietà.

Il protagonista sta apposta a destra (x 556), davanti alla serranda, e non in
mezzo alla stanza: i vasi si disegnano **sopra** di lui — sono nodi aggiunti dopo
`Character` nella scena — e uno in mezzo ai banconi si ritroverebbe le piante
davanti alla faccia. È la stessa ragione per cui in cantina sta a x 478 mentre i
vasi stanno fra 162 e 408.

A differenza della cantina il garage **vede la luce**: la finestra rotta in alto a
sinistra (`window_rect`) e i vetri della serranda, quindi `daylight` resta acceso
e la stanza cambia colore con l'ora. Non è solo atmosfera: è anche il motivo per
cui lì **le lampade non si appendono** (vedi "Dove si coltiva").

Aggiungere una stanza: duplica una delle tre scene ereditate, cambia i tre campi
(più la texture di `Backdrop` e posizione/scala di `Character`, se ha un
fondale) e aggiungila alle `exits` delle altre. Le uscite sono un dizionario
`etichetta -> scena`, e l'ordine mostrato è quello di inserimento.

Le scritte delle stanze sono in inglese e di sole lettere, quindi possono usare
il font del gioco (vedi la sezione sul font più sotto).

L'orologio di gioco continua a scorrere dentro alle stanze, gestionale aperto
compreso: le piante crescono mentre si fanno i conti.

### Oggetti cliccabili in una stanza

`scenes/components/RoomHotspot.tscn` è il segnaposto cliccabile da appoggiare
sopra al fondale: un tasto con la cornice giallina, l'hover di tutti gli altri
tasti del gioco (eredita da `scripts/ui/interactive_button.gd`) e una sola
proprietà, `window_scene`, cioè la finestra da aprire.

In cantina c'è il primo: il nodo `PC` sulla scrivania, che apre
`scenes/ui/ManagementWindow.tscn`. Aggiungerne altri — il telefono, la
cassaforte, il banco di lavoro — vuol dire istanziare la stessa scena, spostarla
sopra all'oggetto giusto del fondale e cambiare testo e `window_scene`.

La finestra viene appesa alla **scena corrente**, non al segnaposto: così copre
tutto lo schermo anche se l'oggetto cliccato è in un angolo, e si chiude
semplicemente con `queue_free()` senza che la stanza sotto sappia che esiste.
Il segnaposto tiene il riferimento all'istanza aperta, quindi un doppio click
non ne apre due sovrapposte.

Le coordinate sono quelle dei 640x360 del viewport, non quelle del PNG: la
conversione da pixel del disegno a pixel di schermo è nella tabella dei fondali,
poco sopra.

### La finestra del gestionale

`scenes/ui/ManagementWindow.tscn` è la schermata da cui si tiene d'occhio
l'attività e si piazza la merce senza uscire di casa. Tre schede:

- **OVERVIEW** — soldi, giorno e ora, scorta, semi, vasi in uso, piante pronte,
  attenzione della polizia, e i totali della campagna.
- **GROW** — una riga per vaso con stadio, avanzamento, resa prevista e se ha
  sete; poi `WATER ALL`, `HARVEST ALL` e `OPEN NEW POT` col prezzo.
- **MARKET** — prezzo del giorno, prezzo di strada per confronto, valore della
  scorta, e i tagli di vendita.

Il contenuto è **creato dal codice**, non dalla scena: le righe dipendono dalla
partita (quanti vasi hai, quali tagli ti puoi permettere) e sarebbero comunque
da riempire a runtime, quindi tenerle anche nella scena vorrebbe dire mantenere
due volte la stessa lista.

Vengono però **costruite una volta per scheda e poi solo aggiornate**: `_fields`
e `_actions` tengono la Label o il Button insieme alla funzione che ne ricava il
testo. È lo stesso schema dell'HUD, e serve a non ricreare i bottoni sotto al
mouse mentre il giocatore ci sta cliccando sopra.

Esc chiude la finestra: dentro a una stanza Esc non era usato, e qui deve fare
il gesto più vicino, un passo indietro e non uscire dalla partita.

### Dove si trova il giocatore

`SaveData.current_room` contiene la scena della stanza in cui si è, `""` quando
si è in strada. Ogni stanza lo scrive entrando e `city.gd` lo azzera, perché la
mappa *è* il fuori: nessuno dei due deve sapere niente dell'altro. Riprendendo
una partita, `GameState.scene_for_current_state()` riapre la stanza giusta — e
se quella stanza nel frattempo è stata rinominata o cancellata si torna in
strada invece di schiantarsi.

## Coltivare e vendere

Il giro completo è: **chiedi semi a Brian dal PC → vai all'appuntamento →
pianta in cantina → annaffia → raccogli → vendi**. Tutti i numeri stanno in un posto solo,
`scripts/data/economy.gd`, perché tarare un tycoon vuol dire cambiare venti
volte gli stessi dieci numeri: se sono sparsi nelle scene non si ritrovano più.

| Cosa | Dove | Valore di partenza |
|---|---|---|
| Soldi iniziali | `Economy.STARTING_CASH` | 120 $ |
| Semi iniziali | `Economy.STARTING_SEEDS` | 2 |
| Costo di un seme | `STRAINS.regular.seed_price` | 40 $ |
| Resa di una pianta curata | `STRAINS.regular.grams` | 20 g |
| Prezzo base al grammo | `STRAINS.regular.base_price` | 10 $ |
| Durata di un ciclo | `STRAINS.regular.grow_hours` | 29 ore di gioco |
| Vasi all'inizio / al massimo | `START_PLOTS` / `MAX_PLOTS` | 3 / 6 |
| Costo dei vasi in più | `PLOT_COSTS` | 210, 560, 1260 $ |

Una pianta rende quindi circa 200 $ per 40 $ di seme: il primo ciclo si paga da
sé cinque volte, ed è la rampa che serve a far partire la cosa.

### Comprare i semi

**Una pianta non fa semi.** L'erba da fumare è sinsemilla, cioè piante femmina
non impollinate: `Grow.harvest()` restituisce grammi e svuota il vaso, e basta.
È anche la scelta di gioco giusta — se il raccolto ripagasse i semi il ciclo si
chiuderebbe su sé stesso, e comprarli smetterebbe di essere una spesa da
mettere in conto.

I semi arrivano da **Brian**, il cugino del protagonista, che lavora alla
clinica dove l'erba la danno ai malati. Non sta a un indirizzo: si chiede e si
va all'appuntamento. Tutto in `scripts/systems/seed_deal.gd`.

Il giro è:

1. dal PC in cantina, scheda **GROW**, si clicca `ASK BRIAN FOR SEEDS`;
2. dopo **2-4 ore di gioco** (`SeedDeal.WAIT_HOURS`, circa 30-60 secondi reali)
   arriva la notifica con il posto: `BRIAN: MAIN STREET BY THE LAUNDROMAT`;
3. Brian compare lì, col rombo verde sopra la testa come ogni venditore, e ci
   si parla per comprare;
4. finiti i semi che aveva addosso se ne va, e se ne può chiedere un altro
   carico.

Quanti ne porta non è fisso: `SEEDS_PER_RUN` è un intervallo, **da 6 a 12**,
tirato quando si chiede e scritto nell'appuntamento, così il numero non cambia
sotto ai piedi se nel frattempo si salva e si riapre. Brian non è un magazzino —
quanti ne riesce a far uscire dalla clinica cambia da una volta all'altra — e
non saperlo prima di arrivare è quello che rende l'appuntamento un fatto invece
di un ritiro. Il minimo è quello che c'era prima, quindi una chiamata non è mai
peggio di com'era; il massimo è il doppio.

Va letto insieme a `Staff.POTS_PER_GROWER` (sei): un coltivatore consuma un seme
per vaso a ogni ciclo, quindi una consegna copre da uno a due cicli di
seminterrato pieno. È il numero che decide **ogni quanto si deve uscire di
casa**, ed è lì che questo gioco vuole tenere il giocatore.

Un venditore fermo a un indirizzo sarebbe stato un distributore automatico: sai
dov'è, ci vai quando serve, e la cosa smette di esistere come scelta.
L'appuntamento invece occupa un pezzo di giornata — chiedi adesso, ti muovi
dopo — e obbliga a decidere *quando* chiamare, non solo quanto comprare. È il
motivo per cui `NpcRoster` non ha nessun personaggio con ruolo `seeds`: Brian
esiste solo finché c'è un appuntamento, e a tirarlo su è `city.gd` leggendo
`SeedDeal`.

Brian **non aspetta per sempre**: dopo ventiquattro ore di gioco
(`MEET_HOURS`) se ne va e l'appuntamento si chiude. Serve che scada — un
appuntamento eterno non è un appuntamento, e bloccherebbe l'unica fonte di semi
in un'attesa senza fine — ma serve soprattutto che la finestra sia **larga**.

Erano dieci ore, ed era un errore di conto. L'orologio corre 240 volte il tempo
vero (vedi "Il tempo"), quindi dieci ore di gioco sono **due minuti e mezzo
veri**, e ci si arriva dopo altri trenta-sessanta secondi di attesa. Bastano ad
attraversare la mappa, come diceva il commento di allora — ma non bastano a fare
*qualsiasi altra cosa nel frattempo*: si chiede dal PC, si annaffia, si
raccoglie, si esce, e Brian se n'è già andato. Il giocatore lo vede come "a
volte sparisce", che è esattamente come è stato segnalato. Ventiquattro ore sono
una giornata piena, cioè sei minuti veri, e un controllo automatico verifica che
la finestra non scenda mai sotto i cinque.

E non se ne va più **in silenzio**: sei ore di gioco prima della scadenza
(`LEAVING_HOURS`) manda un messaggio sul telefono — "non ci posso restare tutto
il giorno cugino" — una volta sola, segnata nell'appuntamento con un flag
`warned` che sopravvive al salvataggio. Un'ora e mezza vera di preavviso è il
tempo di chiudere quello che si sta facendo e uscire. Va sul telefono e non fra
i messaggini dell'HUD perché è una cosa che *qualcuno dice*, e perché non deve
sparire dopo due secondi e mezzo mentre si sta guardando altrove.

Come per la coltivazione, **l'attesa non è simulata**: l'appuntamento salva
l'ora in cui la posizione arriva e quella in cui Brian se ne va, e lo stato è
una funzione di che ore sono adesso. Scorre col gioco chiuso, e ricaricare un
salvataggio non azzera niente. L'unico pezzo spinto avanti è il passaggio da
attesa ad appuntamento fissato, perché è lì che si sceglie il posto e si avvisa
il giocatore: se ne occupa `SeedDeal.tick()`, chiamata da `GameState` mentre
l'orologio gira.

Dove Brian può dare appuntamento lo decide `CityMap.meet_spots()`, che i posti
li **ricava dal reticolo** invece di elencarli: percorre i marciapiedi entro uno
o due isolati da casa (`MEET_MIN_DISTANCE` 220 px, `MEET_MAX_DISTANCE` 900 px) e
tiene quelli buoni. Al momento sono ventisei.

#### Come si dice dove ci si vede

Il nome del posto (`CityMap.place_name()`) è la strada più un riferimento: una
coppia di coordinate non direbbe niente a nessuno. È senza punteggiatura di
proposito — solo lettere e spazi si possono scrivere anche col font del gioco —
e resta in inglese come le insegne degli edifici, perché è una cittadina
americana inventata.

La prima versione diceva strada + **insegna più vicina entro 320 px**, e
sbagliava in due modi che si vedevano solo giocando:

1. **L'insegna poteva stare su un'altra strada.** Un appuntamento a (736, -64),
   su MILL ROAD, veniva annunciato `MILL ROAD BY THE LAUNDROMAT` perché la
   lavanderia era a 314 px in linea d'aria — ma la lavanderia sta su MAIN
   STREET, tre isolati più in basso. Chi ci andava si trovava davanti alla
   lavanderia con Brian fuori inquadratura, e non aveva **nessun motivo di
   sospettare di essere nel posto sbagliato**: il gioco gli aveva detto proprio
   quello. È il difetto peggiore di tutti — non sembra un difetto.
2. **Lo stesso nome copriva posti diversi.** Ventisei posti finivano in undici
   nomi, e uno solo ne copriva sette, distanti fra loro fino a 286 px.

Adesso un'insegna si usa solo se è vicina davvero (`MEET_SIGN_RANGE`, 150 px),
se sta **sulla stessa strada** del punto, e se non è un'insegna che in città
esiste in più copie — `HOUSE` e `CORNER STORE` stanno fra i `names` di THE
FLATS, e di case e negozietti col loro stesso disegno il riempimento ne semina
una ventina: manderebbero alla copia sbagliata. Quando non c'è un'insegna
che serva si dà l'incrocio **col verso**: `MILL ROAD NORTH OF MAIN STREET`. In
una città a reticolo è un indirizzo vero e c'è sempre; il verso non è un vezzo,
perché fra due incroci ci sono settecento pixel e senza sapere da che parte si è
metà delle volte si cammina nella direzione sbagliata.

Un controllo automatico verifica adesso che ogni nome dica il vero: che cominci
con la strada su cui si è davvero, e che se nomina un'insegna quell'insegna sia
vicina, sulla stessa strada, e unica in città.

#### La freccia

Il nome onesto risolve metà del problema: dice il quartiere, non l'indirizzo.
Fra due incroci ci stanno due schermi, e più appuntamenti diversi continuano a
chiamarsi nello stesso modo — è una conseguenza del reticolo, non un difetto da
sistemare a parole.

Il resto lo fa `scripts/systems/spot_pointer.gd`: finché Brian aspetta e il
punto è **fuori dallo schermo**, una freccia verde scorre lungo il bordo
indicando da che parte sta, più grande e più piena man mano che ci si avvicina.
Appena il punto entra in vista la freccia sparisce, perché lì c'è già il rombo
verde sopra la testa di Brian e due indicatori per la stessa cosa sono uno di
troppo.

Sta su una tela sua (`SpotLayer`, fra il meteo e l'HUD), quindi disegna in
coordinate schermo e la tinta della notte non la tocca: è un segnale al
giocatore, non un oggetto della città, e deve restare dello stesso verde alle
due di notte sotto la pioggia. Il margine in alto è più grande degli altri per
non finire sopra all'HUD, e in più la freccia **scansa l'angolo in alto a
destra** (`HUD_CORNER`): da quando lì c'è la sveglia quel blocco è alto un
centinaio di pixel, e spingere giù la cornice intera vorrebbe dire perdere
ottanta pixel di bordo anche a sinistra, dove non c'è niente. Come l'HUD, si
toglie di mezzo davanti alle finestre modali.

C'è un numero che sembra arbitrario e non lo è, `MEET_CLEARANCE` (28 px): non
basta che un punto sia fuori dai muri, perché la griglia dei percorsi si tiene
otto pixel di margine dagli edifici e lavora a celle da sedici. Un punto a filo
di una facciata finisce quindi su una cella che la griglia considera piena. Vale
per **tutta la quota dei marciapiedi a sud di una strada**, dove gli edifici
hanno il corpo che sale fino a toccarli: ci si passa, ma non ci si può stare.
Senza quel margine trentatré dei cinquantanove posti generati erano appuntamenti
in cui il giocatore non sarebbe mai potuto arrivare — e ad accorgersene è stato
il controllo automatico, non l'occhio.

Il posto dell'appuntamento resta scritto **nell'HUD** finché Brian aspetta. Il
messaggino che lo annuncia se ne va dopo due secondi e mezzo, e senza quella
riga l'unico modo di ripescare l'indirizzo sarebbe tornare in cantina a riaprire
il PC, cioè attraversare la città al contrario. La riga dice dove, la freccia
dice da che parte.

### Dove si coltiva

Due posti: la **cantina** di casa e, comprandolo dall'agenzia, il **garage**. La
tabella e' `GrowSites.SITES`, e dice per ognuno l'edificio da possedere, quanti
vasi ci stanno e da che indice partono.

`SaveData.plots` resta **un elenco solo**, e un posto e' una fetta di
quell'elenco: la cantina sono i vasi 0-5, il garage i 6-17. Non c'e' un array di
vasi per stanza e non deve esserci — i vasi sono gia' salvati, gia' cresciuti e
gia' contati da `Grow` e da `Staff` senza sapere dove stanno, e spezzarli in due
elenchi vorrebbe dire rifare tutto quel giro per guadagnarci niente.

Ne segue l'ordine in cui si comprano: `plot_slots` e' un contatore unico, quindi
si riempie prima la cantina e poi il garage. E' il verso giusto — il garage
costa trentacinquemila dollari, e chi lo compra ha gia' la cantina piena.

**Un posto chiuso non esiste.** Finche' il garage non e' tuo,
`Economy.next_plot_cost()` restituisce -1 anche se di vasi in tabella ce ne sono
ancora dodici: il PC non offre il prossimo vaso, la scheda GROW non mostra il
posto, e non ci si puo' mandare nessuno a lavorare. E' quello che rende il
garage un traguardo invece di un rettangolo in piu' sulla mappa.

I due posti non sono la stessa cosa in grande:

| | Cantina | Garage |
|---|---|---|
| vasi | 6 | 12 |
| luce di fuori | no | si' |
| lampade | una per vaso | non si appendono |

Le **lampade** sono il sole che manca sottoterra, quindi restano un attrezzo
della cantina (`Shop.ITEMS.lamps`, tetto sei). Il garage offre il **posto**, non
la velocita': dodici vasi a tempo di listino contro sei con l'8% in meno. A chi
ha tutti e due conviene tenere sotto casa le varieta' che ci mettono di piu'.

### La crescita non è simulata

**Questo è il punto centrale del sistema.** Un vaso salva l'ora di gioco in cui
è stato piantato, e lo stadio è una funzione pura di quanto tempo è passato da
allora (`scripts/systems/grow.gd`). Nessuno tiene il conto frame per frame,
quindi:

- le piante crescono anche mentre si è in giro per la città o col gioco chiuso;
- ricaricare un salvataggio non azzera e non salta niente;
- non c'è nessun processo da ricordarsi di far partire quando si entra in cantina.

Il tempo assoluto lo dà `GameState.total_hours()`: serve un numero che cresce
sempre, perché `time_of_day` riparte da zero ogni mezzanotte.

Gli stadi sono `SEEDLING → VEGETATIVE → FLOWERING → READY`, con le soglie in
`Grow.STAGE_STARTS`.

### La sete, e perché è l'unica cosa che va "spinta avanti"

La resa piena arriva solo a una pianta annaffiata. La sete però si **accumula**,
e non si può ricavare dai soli timestamp: annaffiare due volte non deve
cancellare la sete di ieri. Per questo il vaso tiene `dry_hours` e `checked_at`,
e `Grow.sync(plot, now)` porta il conto avanti fino ad adesso.

`sync()` si chiama pigramente, ogni volta che un vaso viene letto. È idempotente
e monotona, quindi chiamarla spesso o di rado dà lo stesso risultato — ed è
esattamente quello che il test verifica, avanzando lo stesso ciclo a passi di
un'ora e mezza invece che in un colpo solo.

A 12 ore di gioco fra un'annaffiatura e l'altra (`Grow.WATER_HOURS`) servono due
passaggi per ciclo, uno ogni tre minuti reali circa. Abbassare quel numero vuol
dire trasformare la coltivazione in una guardia a vista, che non è il gioco che
si vuole.

### Un click fa la cosa giusta

I vasi (`scripts/components/grow_plot.gd`) non aprono nessun menu: capiscono da
soli cos'è sensato fare adesso — piantare, annaffiare, raccogliere — e lo fanno.
In un gestionale si finisce a cliccare gli stessi vasi centinaia di volte, e ogni
finestra in mezzo è un dazio da pagare ogni volta.

Sono dei `Button` con un `_draw()` addosso: la parte difficile di un oggetto
cliccabile in una stanza è il click, non il disegno, così hover e pressione li
gestisce Godot.

### Vendere, e l'attenzione della polizia

Due strade, con un compromesso vero in mezzo:

- **All'ingrosso, dal PC**: al prezzo del giorno, tutto in un colpo, nessuno ti
  vede.
- **In strada, ai clienti**: `RETAIL_MULTIPLIER` più (oggi +40%), ma un cliente
  alla volta, ognuno con la sua domanda giornaliera, e ogni grammo che passa di
  mano alza `heat`.

#### Dove si vende conta

In **HILLSIDE**, il quartiere delle ville, la stessa roba si paga il **10% in
più** (`Economy.DISTRICT_PRICE`): lassù nessuno sta a contare i centesimi.

È la prima ragione per **attraversare la città invece di vendere sotto casa**.
Fino a qui un cliente valeva l'altro, e una mappa larga cinquemila pixel era
solo una distanza da percorrere; adesso la distanza si paga.

Due dettagli che non sono dimenticanze:

- **Il personale non prende la maggiorazione.** Un dealer assunto non ha una
  posizione sulla mappa: vende "da qualche parte", quindi al prezzo base.
  Andarci di persona è l'unica cosa che quel dieci per cento lo porta a casa.
- **Il cliente lo dice.** Quando il quartiere paga di più, nel dialogo compare
  una riga in più. Senza, l'aumento resterebbe un numero che cambia senza che
  si capisca perché — e nessuno andrebbe mai apposta in collina.

La tabella sta in `Economy` e non in `CityMap` perché è bilanciamento e non
geografia; che i nomi dei quartieri combacino fra le due lo verifica un
controllo automatico, altrimenti un nome scritto male passerebbe in silenzio
come "nessun aumento".

Più avanti qui ci andrà il rovescio della medaglia: in collina la polizia è più
attenta, e quel dieci per cento si pagherà in attenzione. Per ora no.

`heat` va da 0 a 100, scende di 9 ogni notte e per ora **non fa ancora niente**:
la si vede nell'HUD e nel PC, e le pattuglie la commentano. È il gancio pronto
per le retate.

Il prezzo del giorno lo tira `Economy.roll_new_day()` a mezzanotte, agganciata
al segnale `day_started` di `GameState`, e viene **salvato**: ricalcolarlo al
caricamento farebbe cambiare il mercato sotto il naso al giocatore.

La domanda di un cliente invece **non** è salvata: si ricava da id e giorno con
un hash (`Economy.street_demand()`), così il salvataggio non si gonfia di una
riga per ogni NPC e la domanda resta identica se si ricarica la partita. Di
salvato c'è solo quanto ha già comprato oggi (`SaveData.npc_state`).

### L'ingrosso: il chilo, il furgone, il viaggio

Prima l'ingrosso era un bottone sempre acceso nel PC: dieci grammi, cinquanta,
tutto. Comodo, e per questo sbagliato — c'era un modo di vendere che non chiedeva
niente a nessuno, e la strada (che paga il 40% in più, ma un cliente alla volta e
alzando l'attenzione) diventava la scelta strana.

Adesso è una **fase** della partita, e si apre in due passi:

1. aver avuto in mano **un chilo** almeno una volta (`Delivery.UNLOCK_GRAMS`):
   è il punto in cui la merce non ci sta più nelle tasche, e Brian lo dice con
   una vignetta;
2. comprare il **furgone** (5000 $): un chilo non si porta in giro a piedi.

Il primo è un traguardo, il secondo una spesa. Il traguardo si raggiunge
producendo, quindi l'ingrosso arriva quando serve e non prima. Il furgone è nel
negozio come tutto quello che si compra una volta e resta, ma il bottone compare
anche nella scheda MARKET — è lì che ci si accorge di averne bisogno, com'è già
per il vaso in più fra SHOP e GROW.

Si spedisce a **1, 2, 5 o 10 kg**: un furgone non esce per cinquanta grammi, e i
tagli sono quello che glielo dicono.

#### Il viaggio non è simulato

Come tutto il resto (vedi `Grow`, `Staff`, `SeedDeal`): la consegna salva l'ora
di gioco in cui il furgone torna, e lo stato è una funzione di che ore sono
adesso. Niente timer, quindi il viaggio va avanti in cantina, in un'altra
stanza, e col gioco chiuso.

**La merce parte subito, i soldi arrivano al ritorno.** È la differenza fra un
bottone e un viaggio: per qualche ora il magazzino è vuoto e il denaro non c'è
ancora, ed è lì che l'ingrosso costa qualcosa oltre al margine più basso.

Il prezzo si fissa **alla partenza**: è l'accordo preso con chi compra, e un
prezzo che cambia mentre il furgone è in viaggio sarebbe una scommessa che il
giocatore non ha fatto — lo stesso motivo per cui il prezzo del giorno si salva
invece di ricalcolarlo. C'è un controllo automatico apposta.

#### Dove si vede il furgone

Il mezzo si vede in tre momenti diversi, e ognuno risponde a una domanda
diversa.

**Fermo.** Comprato e non in viaggio, il furgone sta parcheggiato **nel
vialetto a fianco di casa**, nella striscia fra la casa e il palazzo accanto,
col **muso verso la strada** (`CityMap.van_parking()` e `VAN_PARK_ANGLE`). Al
bordo dell'asfalto — dov'era finito al primo tentativo — sembrava un'auto del
traffico che si era fermata lì: un mezzo di proprietà sta a casa, non in
carreggiata. E il muso verso la strada lo dice a colpo d'occhio: è fermo ma
pronto a uscire, non parcheggiato di traverso. Prima esisteva solo dentro all'animazione della
partenza: chi lo comprava dal PC in cantina usciva di casa e trovava la strada
identica a prima, cioè una spesa da cinquemila dollari senza faccia.
Parcheggiato lì invece si vede a colpo d'occhio se il furgone c'è ed è fermo, o
se è fuori con un carico. A tenerlo in vita è `city.gd`, che guarda `Delivery` e
lo mette o lo toglie entrando in strada, alla partenza e al rientro — non a ogni
fotogramma: lo stato cambia solo in quei tre momenti.

Il posto è **a lato della porta e non davanti**: lo zerbino è dove si esce e
dove a volte aspetta Brian, e un furgone in mezzo sembrerebbe un ostacolo. Un
controllo automatico verifica che il punto non cada in carreggiata, che stia fra
la casa e l'asfalto, che sia lontano dalla porta e comunque a fianco di casa: è
scritto come uno scarto dallo zerbino, quindi spostare la casa o allargare la
strada lo manderebbe dentro a un muro senza che nessuno se ne accorga.

**Che parte.** La partenza si ordina dal PC, e il PC sta **in cantina**: in
strada, nell'istante in cui si preme il bottone, non ci si è. Per questo la
partenza ha un **filmato** (`scripts/ui/van_cutscene.gd`), appeso a `GameState`
come le vignette, quindi visibile da qualunque stanza: bande nere, la strada di
campagna vista dall'alto che scorre, il furgone al centro, una riga sotto. Dura
tre secondi e mezzo, si chiude da sola e un click la chiude subito.

È un **segnaposto dichiarato**: lo sprite è quello del pickup del traffico e la
campagna sono rettangoli. Ma è disegnata **dall'alto**, come tutto il resto del
gioco, e non di profilo: di profilo servirebbero un orizzonte, un cielo e delle
facciate, cioè tre cose che il gioco non ha e che a rettangoli stonerebbero con
la pixel art. Il colore però non è inventato — cielo, campagna e asfalto sono
moltiplicati per `Daylight.air()`, la stessa tinta con cui `Atmosphere` tinge la
città, quindi una partenza all'alba e una a mezzanotte sono diverse.

**Che rientra.** Al ritorno **non** c'è filmato, ed è voluto: si torna a casa, e
a raccontarlo basta il furgone che rientra da est lungo la corsia e parcheggia
al suo posto. Un filmato a ogni consegna diventerebbe una cosa da saltare, e
saltare è il contrario di quello che un filmato dovrebbe ottenere.

In tutti e tre i casi l'animazione (`scripts/components/delivery_van.gd`) è solo
la faccia di una cosa già successa nei dati: chi manda un carico e poi scende in
cantina ritrova i soldi lo stesso. È la ciliegina, non il meccanismo. Entrando e
uscendo il furgone fa una **manovra in due tempi** — dal vialetto alla corsia, e
poi via — perché il posto in sosta non è in carreggiata: partire dritti vorrebbe
dire teletrasportarsi in mezzo alla strada nel primo fotogramma. Il muso gira
**durante** quella tratta e non prima, e anche l'ombra a terra gira col mezzo:
in sosta è di traverso, e un'ombra rimasta larga come in marcia gli spunterebbe
dai fianchi.

Lo sprite è il pickup **marrone** (`pickupTruck02.png`): era il viola, che
sembrava un'auto del traffico finita lì per sbaglio.

#### Il carburante

Un pieno fa **dieci consegne** e costa 180 $. È di proposito una spesa piccola —
un carico da un chilo vale cento volte un pieno — perché non è lì per pesare sul
bilancio ma perché un furgone che non consuma niente non è un furgone. Quello
che fa davvero è costringere a ripassare dal PC ogni tanto. Il furgone arriva
col pieno fatto: far comprare un mezzo da cinquemila dollari e poi dire "adesso
però mettici la benzina" è un secondo bottone per la stessa decisione.

#### E il personale?

Finché l'ingrosso non è aperto, la quota all'ingrosso dei dealer è **zero
qualunque cosa dica il salvataggio**: il canale non esiste ancora per nessuno, e
lasciare che ce la piazzassero loro vorrebbe dire aggirare lo sblocco assumendo
qualcuno. Il numero scelto dal giocatore non si perde — resta scritto e torna
valido appena il chilo arriva.

Il **furgone** invece serve solo al giocatore: i dealer hanno i loro giri, non le
chiavi del mezzo.

### La bolletta della luce

Il seminterrato consuma. Ogni **30 giorni di gioco** (`Economy.BILL_DAYS`)
arriva la bolletta: **100 $** di quota fissa più **10 $ per ogni lampada**
accesa. A sei lampade sono 160 $ al mese.

Si paga per le lampade e non per i vasi, perché un vaso al buio non consuma
niente — ed è anche il motivo per cui comprare la sesta lampada è una scelta e
non un acquisto ovvio: accorcia la crescita e allunga la bolletta.

È una spesa con un **tempo diverso** da quello delle paghe, ed è per questo che
esiste: le paghe mordono ogni notte, la bolletta si vede arrivare da lontano e
si prepara. Un gestionale ha bisogno di tutti e due i ritmi.

Nel salvataggio c'è `power_billed_day`, il giorno dell'ultima bolletta, e non un
conto alla rovescia: un traguardo si ritrova intatto ricaricando, un contatore
va tenuto in vita da qualcuno. Il conto riparte da quando la bolletta è
**scaduta** e non da oggi, quindi attraversando più mesi in un colpo solo — il
recupero del tempo a gioco chiuso — non se ne salta e non se ne accavalla
nessuna.

Se la cassa non basta si paga quello che c'è, come per le paghe del personale, e
arriva un messaggio sul telefono. Restare al buio è la conseguenza naturale da
scrivere quando ci sarà qualcosa da spegnere; per ora un buco che si allarga in
silenzio sarebbe peggio di un conto pagato a metà.

## Il negozio online

Una scheda del PC in cantina (`SHOP`): l'attrezzatura che si compra una volta e
resta. Il catalogo e gli effetti stanno tutti in `scripts/data/shop.gd`, per lo
stesso motivo per cui i prezzi stanno in `economy.gd` — sono manopole di
bilanciamento, e vanno girate in un posto solo.

| Voce | Costo | Quanti | Cosa fa |
|---|---|---|---|
| GROW TOOLKIT | 154 $ | 1 | +15% di resa per pianta |
| RED GROW LAMPS | 315 $ | 3 | -8% sul tempo di crescita, per set |
| CARBON FILTER | 420 $ | 1 | -40% di attenzione per grammo venduto in strada |
| WORK VAN | 5000 $ | 1 | senza, l'ingrosso non si fa (vedi "L'ingrosso") |

C'era anche un `SELF-WATERING POT`, un vaso che non aveva più sete. È stato
tolto: un coltivatore assunto pianta, annaffia e raccoglie i suoi vasi da solo,
quindi il serbatoio comprava una cosa che il personale regala già — due modi di
pagare per non annaffiare, con quello più caro che fa anche il resto.

Il vaso in più (`Economy.buy_plot()`) compare sia qui sia nella scheda `GROW`:
è lo stesso bottone e la stessa logica, messa nei due posti in cui al giocatore
viene in mente di cercarla.

Quello che si possiede sta in `SaveData.upgrades` — "id" -> quanti pezzi. Un id
che non c'è vale zero, quindi una partita salvata prima del negozio si carica
senza niente addosso invece di rompersi.

#### Quello che il negozio promette dev'essere comprabile

Due righe della scheda NEGOZIO dicono numeri che dipendono da cosa possiedi, e
tutte e due erano rimaste indietro quando i vasi sono passati da sei a diciotto:

- la nota sotto al vaso in più mostra `GrowSites.reachable_slots()`, cioè il
  tetto di **questa partita** (sei senza garage, diciotto con), non
  `Economy.MAX_PLOTS`, che è il tetto del gioco. Con quello scritto lì, il
  negozio prometteva dodici vasi che non si potevano comprare;
- il bottone distingue **"non ci sta altro"** da **"qui è pieno, serve un altro
  posto"**. La prima è la fine della strada, la seconda vuol dire che i vasi che
  restano stanno in una proprietà che non è ancora tua. Senza distinguerle,
  riempita la cantina il negozio sembra esaurito e non c'è più niente che mandi
  in agenzia — che è esattamente il passo successivo.

Le **lampade** restano sei e la loro nota lo dice: sono i vasi della cantina, e
il perché è in "Dove si coltiva". Il resto del negozio non ha bisogno di
saperlo — il tetto di una voce è già un campo del catalogo (`max`), e il
bottone mostra `(2 / 6)` e si spegne da solo arrivato in fondo.

### La fotografia al momento della semina

Lampade e toolkit cambiano la durata del ciclo e la resa, cioè esattamente i due
numeri da cui `Grow` ricava tutto. Ma la crescita **deve restare una funzione
pura dei timestamp del vaso** (vedi "La crescita non è simulata"), e se
l'effetto si rileggesse dall'attrezzatura posseduta *adesso*, comprare le
lampade a metà ciclo accorcerebbe una pianta già a due terzi del percorso: il
conto alla rovescia mostrato salterebbe all'indietro sotto gli occhi del
giocatore.

Quindi `Shop.grow_mods()` fa una **fotografia** — `hours` e `grams` — e
`Grow.plant()` la attacca al vaso. Le lampade valgono per le piante messe da lì
in avanti, e una pianta già in terra finisce il suo ciclo com'era partita.
I due campi mancano nei vasi piantati prima del negozio, e lì `Grow` ricade da
solo sui valori della varietà.

### Le lampade nel seminterrato

`scenes/components/GrowLamp.tscn` è il segnaposto disegnato a mano: **sei**
lampade appese sopra ai vasi in `Basement.tscn`, una per vaso. La prima si
accende col primo acquisto, la seconda col secondo e così via, così la cantina
si riempie man mano invece di passare da buia a illuminata in un colpo solo.

Le tre della fila davanti (`Lamp3`..`Lamp5`) pendono più in basso e più a
destra di quelle di fondo, seguendo la prospettiva isometrica del tavolo: in
quella vista una lampada più vicina si disegna più giù, e i coni si
sovrappongono come si sovrappongono davvero. Stanno dopo le altre nell'albero,
quindi passano davanti — che è quello che devono fare.

Ognuna aggiunge 10 $ alla bolletta del mese: vedi "La bolletta della luce".

Spenta resta comunque disegnata, in grigio: è il modo in cui un gestionale fa
vedere al giocatore la roba che non ha ancora comprato. Le lampade stanno dopo i
vasi nell'albero, quindi il cono di luce cade **sopra** alle piante — che è
quello che deve fare. Non sono cliccabili, e infatti sono `Control` e non
`Button`: si comprano dal PC, qui si vede solo se ci sono.

**Da sostituire con la pixel art**: il `_draw()` diventa una texture (corpo
della lampada + cono di luce). Chi decide se è accesa e dove sta appesa non
cambia.

## La fine del prologo

La prima volta che la cassa tocca `Economy.PROLOGUE_CASH` (1000 $) il prologo si
chiude: `chapter` passa da `prologo` a `capitolo_uno`, il flag `staff_unlocked`
va a true, arriva un messaggio del cugino sul telefono e nel PC compare la
scheda `STAFF`.

Il controllo sta in `GameState._check_prologue()`, agganciato all'orologio e non
alla vendita. I soldi entrano da troppe parti — il PC, i clienti in strada, un
domani gli affitti — e ricordarsi di chiamarlo da ognuna vuol dire dimenticarselo
da qualcuna. Attaccato all'orologio scatta comunque, qualunque strada abbiano
fatto i soldi per arrivare. Succede **una volta sola**: riscendere sotto i 1000 $
non riapre il prologo, perché a decidere è il capitolo e non la cassa di adesso.

### Il messaggio sul telefono

`scenes/ui/PhoneNotice.tscn` è il riquadro per le cose che il giocatore non deve
perdersi. I messaggini dell'HUD non bastano: durano due secondi e mezzo, e
soprattutto **l'HUD non c'è dentro alle stanze** — mentre il seminterrato davanti
al PC è proprio il posto in cui si è quando questa roba succede.

Per questo è un `CanvasLayer` appeso a `GameState`, che è un autoload e quindi
sta nell'albero sopra alla scena corrente: il messaggio compare uguale in strada
e in cantina, e non sparisce se nel frattempo si cambia stanza. Si apre con
`GameState.message(speaker, body)`.

## Il personale

Sbloccato dalla fine del prologo. Due ruoli, che sono i due lati del gioco:

| Ruolo | Assunzione | Come si paga | Cosa fa |
|---|---|---|---|
| GROWER | 420 $ | 81 $/giorno | pianta, annaffia e raccoglie; segue **sei vasi**, cioè tutto il seminterrato |
| DEALER | 560 $ | **5% di quello che piazza** | piazza la merce, 2 g per ora di gioco |

### Due modi di pagare, e sono due mestieri diversi

Il **coltivatore** prende una paga fissa: il suo lavoro non produce soldi da
solo, produce piante. Pagarlo a percentuale vorrebbe dire legarlo a una vendita
che non fa lui, e lasciarlo a bocca asciutta per i tre giorni in cui una pianta
cresce.

Il **dealer** non prende paga: trattiene una quota di quello che piazza, scalata
sul posto al momento della vendita e non a mezzanotte come le paghe. È il modo
in cui si paga davvero chi vende, e in partita cambia più di quanto sembri —
**un dealer fermo non costa niente**, mentre un coltivatore senza semi costa
uguale ogni notte. Il costo di assunzione resta per tutti e due: è il rischio
che ci si prende in anticipo.

La quota **non dipende da quanti sono**: la merce piazzata è la stessa, divisa
fra loro. Assumerne un altro aumenta quanto si riesce a piazzare in un'ora, non
la percentuale. Per ora è fissa in `Staff.ROLES["dealer"]["cut"]`; sta nella
tabella dei ruoli e non in una costante a parte proprio perché un domani dovrà
cambiare (reputazione, trattative, un dealer migliore di un altro).

### Chi lavora dove

Un coltivatore sta in **una** stanza e segue i vasi di quella, fino a
`GrowSites.POTS_PER_GROWER`. `SaveData.grower_sites` tiene "chiave del posto" ->
quanti, e la scheda PERSONALE del PC ha una riga per posto con due bottoni.

Sta a parte da `staff` e non dentro, perche' sono due domande diverse: quanti ne
paghi e dove li mandi. I dealer non compaiono li' — la strada e' una sola.

La sezione **compare solo da quando i posti aperti sono due**: con la sola
cantina l'unica assegnazione possibile la fa gia' il gioco da solo, e due
bottoni che portano sempre allo stesso risultato sono rumore. Stessa regola
della ripartizione delle vendite, che compare col canale dell'ingrosso.

Quanti ne regge un posto dipende dai vasi che ci sono **aperti**, non da quelli
che ci starebbero: il garage ne regge due, ma solo dal settimo vaso in poi.
Finche' in garage ce ne sono sei, un secondo coltivatore li' starebbe a guardare
a ottantuno dollari a notte — e' la stessa regola che in cantina fa dire `NON
SERVE NESSUN ALTRO`. Per questo la riga mostra **aperti e totali** (`4/12 vasi`):
con scritto solo "4 vasi" il tetto sembra una proprieta' fissa del posto invece
che qualcosa che si alza spendendo.

**Chi si assume va subito dove c'e' spazio**, non resta in panchina aspettando
che qualcuno se ne accorga: si paga ogni notte, e uno pagato per non fare niente
si legge come un bug. Spostarlo e' un click. Se i posti sono tutti pieni resta
senza posto, e quella riga e' l'unica della sezione che si colora di allarme.

Due invarianti, e le rimette a posto `Staff.sync_sites()` invece di difendersi
in ogni punto che legge:

1. la somma degli assegnati non supera i coltivatori assunti;
2. nessun posto ne ha piu' di quanti ne regge.

Servono perche' sotto cambia tutto: si assume, si licenzia, si compra un vaso
(la capienza sale), si compra il garage (il posto si apre), si vende una
proprieta' (il posto si chiude e chi c'era torna in panchina). `sync_sites()` e'
chiamata da `hire()`, `fire()`, `Economy.buy_plot()` e `RealEstate.buy()`.

Il lavoro poi gira **posto per posto** (`Staff._growers_work()`), e ognuno copre
solo la sua fetta dell'elenco. Prima era un ciclo solo sui primi
`coltivatori x 6` vasi, e con una stanza sola voleva dire la stessa cosa: con
due no, perche' due assunti in cantina coprivano i vasi 0-11, cioe' anche i
primi sei del garage, dove non c'era nessuno.

### Quanti se ne possono avere

I dealer sono al massimo tre: il personale è un moltiplicatore, non un
sostituto del giocatore.

Per i coltivatori il tetto **non è scritto da nessuna parte**: lo dice il posto
che c'è. Un coltivatore segue `GrowSites.POTS_PER_GROWER` vasi (sei), e
`Staff.max_for()` somma le capienze dei posti **aperti**: con la sola cantina ne
basta uno, e il PC lo dice (`NON SERVE NESSUN ALTRO`) invece di lasciare che il
giocatore spenda quattrocentoventi dollari per uno che sta a guardare. Col
garage pieno diventano tre — uno sotto casa e due sui banconi.

È una somma per posto e non un conto sul totale dei vasi, e la differenza si
vede coi numeri scomodi: sei vasi in cantina e **uno solo** aperto in garage
fanno due coltivatori, non uno, perché nessuno lavora in due stanze insieme.
Che il tetto salga da solo comprando vasi e proprietà era il piano fin
dall'inizio; il garage è la prima volta che succede davvero.

### Le paghe, e chi se ne va

Si scalano a mezzanotte (`Staff.pay_wages()`, agganciata a `day_started`); se la
cassa non basta se ne va uno, e per primo quello che costa di più — lasciare il
giocatore in rosso con l'organico intatto vorrebbe dire un buco che si allarga
da solo ogni notte, senza niente che lo fermi.

I dealer non entrano mai in questo conto e **non se ne vanno mai per soldi**:
uno che si tiene una quota di quello che vende non ha niente da riscuotere nelle
notti in cui non ha venduto niente. A restare senza lavoro sono i coltivatori,
che è anche il verso giusto — sono loro il costo fisso che affonda una partita.

### Quanto tenere da parte

**I dealer battono solo la strada.** L'ingrosso è il furgone, e il furgone è del
giocatore: i dealer hanno i loro giri, non le chiavi del mezzo.

`SaveData.wholesale_share` (0-100) non dice quindi ai dealer dove vendere, dice
**quanto del raccolto mettere da parte perché non lo vendano loro**. A 30/70, di
cento grammi raccolti trenta restano fermi in magazzino ad aspettare un carico e
settanta sono quelli che i dealer possono piazzare. Quella parte ferma la muove
solo il giocatore.

Prima la stessa percentuale voleva dire "i dealer piazzano il 30% del loro giro
all'ingrosso", ed era un'altra cosa: il canale dell'ingrosso passava anche a
loro, il furgone non serviva a niente, e la scelta si riduceva a quale dei due
prezzi preferire. Adesso è una scelta fra **incassare subito** — la strada, che
però paga il dealer e fa salire `heat` mentre il giocatore non sta guardando — e
**tenere da parte per il carico grosso**, che rende meno al grammo ma bisogna
esserci e guidarcelo.

#### La riserva è un numero, non una percentuale

`SaveData.wholesale_reserve` sono **grammi**, non una quota ricalcolata al volo.
Ricalcolarla si svuoterebbe da sola: i dealer piazzano il 70%, sulla rimanenza
il 30% è un terzo di quel che era, loro ne piazzano di nuovo il 70%, e via così
fino a zero.

Quindi: **cresce a ogni raccolto** (`Staff.reserve_harvest()`, chiamata da tutti
e tre i modi di raccogliere — il vaso in cantina, "raccogli tutto" dal PC, il
coltivatore assunto) e **cala solo quando parte un carico**
(`Staff.release_reserved()`, da `Delivery.dispatch()`). In lettura è limitata
alla scorta (`Staff.reserved()`), quindi vendendo di persona si intacca la
riserva per ultima: la roba da parte è del giocatore, non se la porta via da
solo finché ha dell'altro da vendere.

Cambiare la quota al PC **ritara subito** la riserva sulla scorta di adesso
(`Staff.retarget_reserve()`), nei due versi: alzandola si mette via altra roba
fra quella che c'è già, abbassandola se ne libera. Senza, la quota nuova
varrebbe solo dal raccolto dopo, e chi abbassa la percentuale apposta per far
vendere i dealer si ritroverebbe il magazzino bloccato come prima. Stessa
chiamata quando l'ingrosso si apre (`Delivery.check_unlock()`): lì in magazzino
c'è già un chilo, e senza ritarare i dealer se lo piazzerebbero tutto prima che
la scelta appena comparsa al PC voglia dire qualcosa.

#### La scelta esiste solo a ingrosso aperto

Finché il chilo non è arrivato, `Staff.wholesale_share()` restituisce **zero
qualunque cosa dica il salvataggio** — mettere da parte merce per un furgone che
non c'è vorrebbe dire bloccare il magazzino senza motivo — e al PC la riga **non
compare proprio** (`management_window.gd::_build_split()`).

Prima c'era comunque, coi suoi due bottoni, e chiedeva di ripartire le vendite
fra due canali di cui uno non esisteva ancora: qualunque cosa si scegliesse il
risultato era lo stesso, e l'unica cosa che si imparava era che quel comando non
faceva niente. Un comando che non fa niente è peggio di un comando che non c'è,
perché il giocatore ci torna sopra a cercare cosa ha sbagliato. Il numero scelto
non si perde comunque: resta scritto nel salvataggio e torna valido col chilo.

Nel PC sono due bottoni a passi di dieci e non uno slider: a passi di dieci le
scelte sono undici, e undici scelte non hanno bisogno di un controllo continuo —
uno slider a 640x360 sarebbe largo sessanta pixel e impossibile da mirare. Sotto
alla percentuale c'è la riga in **grammi** (quanti fermi, quanti ai dealer):
la percentuale dice la regola, i grammi dicono il risultato, ed è il risultato a
decidere se il furgone può partire.

### Nemmeno il lavoro è simulato

Come la coltivazione. `Staff.work()` guarda che ore sono adesso, le confronta con
`SaveData.staff_checked_at` e fa quello che nel frattempo andava fatto. Quindi il
personale lavora anche mentre il giocatore è dall'altra parte della città, ed è
idempotente: chiamarla a ogni frame o una volta ogni tanto dà lo stesso risultato
— ed è quello che il test verifica, avanzando venti mezz'ore invece di dieci ore
in un colpo solo.

Il resoconto di `work()` tiene **tre** numeri sui soldi e servono tutti e tre:
`gross` è quello che la merce ha fatto, `commission` la quota trattenuta dai
dealer, `revenue` quello che è arrivato davvero in cassa. Il messaggino in
partita mostra `revenue`, perché deve dire quello che la cassa ha visto; il
resoconto di quando si rientra mostra il conto per esteso, perché "piazzato per
294 e in cassa 280" senza la riga di mezzo si legge come un errore.

Due dettagli che vengono da lì:

- **Le ore avanzate non si perdono.** I grammi sono interi, quindi
  `staff_checked_at` avanza solo per le ore davvero consumate: un dealer che in
  mezz'ora non arriva a un grammo intero se la ritrova al giro dopo.
- **Senza nessuno assunto il segnaposto avanza lo stesso.** Altrimenti il primo
  assunto si troverebbe addosso tutte le ore passate dall'inizio della partita e
  svuoterebbe il magazzino al primo giro.

C'è anche una soglia, `MIN_BATCH_GRAMS`: sotto ai cinque grammi il dealer non
esce. Non è bilanciamento, è rumore — senza, il primo grammo intero verrebbe
piazzato appena maturato, cioè un messaggino ogni sette secondi reali da lì alla
fine della partita.

`work()` restituisce anche `idle`: quanti vasi seguiti dal personale sono fermi
perché **i semi sono finiti**. A gioco aperto non serve dirlo, il vaso vuoto si
vede; a gioco chiuso è l'unica spiegazione del perché la produzione si è
fermata. Vedi "Il tempo a gioco chiuso".

## Il tempo a gioco chiuso

Chiudere il gioco non mette in pausa il mondo: riaprendolo, il personale ha
lavorato, le piante sono cresciute e le mezzanotti passate hanno fatto il loro
mestiere.

**Non c'è niente di simulato**, ed è il punto. Coltivazione, lavoro del
personale e appuntamento con Brian erano già funzioni del tempo: nessuno tiene
un conto frame per frame, si guarda che ore sono e si fa quello che nel
frattempo andava fatto. L'unica cosa che si ferma chiudendo il gioco è
**l'orologio**. `scripts/systems/offline.gd` lo sposta avanti e lascia lavorare
i sistemi che c'erano già — per questo costa un file solo.

Il recupero parte da `GameState.load_slot()`, **prima** di `game_started`: chi
si aggancia a quel segnale costruisce la scena dallo stato, e lo stato deve
essere già quello recuperato, o la mappa nascerebbe all'ora di ieri sera e
salterebbe avanti un attimo dopo.

### Perché a passi e non in un salto

Portare l'orologio da 8:00 a 56:00 in un colpo e chiamare `Staff.work()` una
volta sbaglierebbe in due modi:

1. Un coltivatore raccoglie e ripianta **una volta per chiamata**. In due giorni
   di gioco un vaso completa un ciclo e mezzo: con una chiamata sola se ne
   perderebbe metà, e chi lascia il gioco aperto raccoglierebbe più di chi lo
   chiude per lo stesso tempo.
2. I dealer venderebbero tutto il magazzino al prezzo di **oggi**, mentre il
   prezzo cambia a ogni mezzanotte. Due giorni di merce piazzata al prezzo di un
   giorno solo è una scommessa che il giocatore non ha fatto.

Quindi si avanza a mezz'ore di gioco, spezzando il passo esatto sulla mezzanotte
perché paghe, prezzo del giorno e meteo cadano al momento giusto. Sono un
centinaio di giri per il recupero più lungo possibile: non si sente. Il controllo
automatico verifica proprio questo — che in quarantotto ore i vasi vengano
**ripiantati** e non seminati una volta sola.

### Il tetto è in ore di gioco, non in ore vere

È la decisione che conta. L'orologio della partita corre **duecentoquaranta
volte** più veloce del nostro: a `GAME_MINUTES_PER_SECOND` = 4 una giornata di
gioco dura sei minuti veri. Stare via due ore vere vorrebbe dire venti giorni di
gioco — più di quanto duri una partita intera fin qui. Contarli tutti non
sarebbe generoso: sarebbe dire al giocatore che il modo migliore di giocare è
non aprire il gioco.

`Offline.MAX_GAME_HOURS` vale **48**, cioè due giornate. Ci si arriva stando via
dodici minuti veri; oltre, si trova sempre quello — tornare dopo una settimana
dà quanto tornare dopo un quarto d'ora. È l'unico numero da girare per rendere
il ritorno più o meno ricco, e sta in ore di gioco perché quella è l'unità in
cui si ragiona di bilanciamento (cicli, paghe, prezzo del giorno) ed è l'unica
che resta giusta se un domani si cambia il ritmo dell'orologio.

Sotto al minuto non succede niente: chi riapre il gioco subito dopo averlo
chiuso non deve beccarsi un riquadro a tutto schermo per venti secondi.
Un salvataggio nel **futuro** — orologio di sistema spostato indietro, file
copiato da un'altra macchina — dà zero e non un numero negativo, o l'orologio
della partita camminerebbe all'indietro.

### Cosa NON succede a gioco chiuso

Lavora solo il personale. Il giocatore no: non annaffia i vasi che i coltivatori
non seguono, non vende in strada a mano, e soprattutto **non compra semi** —
quelli si prendono solo da Brian, di persona. Finiti i semi i vasi restano vuoti
e la produzione si ferma da sola.

È questo, più del tetto, a tenere il conto onesto: **non serve un moltiplicatore
che dimezzi la resa offline**, perché a gioco chiuso manca già metà del gioco.
Un coltivatore segue due vasi, gli altri restano a secco, e la sete si porta via
un pezzo di raccolto esattamente come a gioco aperto (mai sotto a
`Grow.MIN_QUALITY`: una notte via non azzera niente).

Anche l'appuntamento con Brian scorre. Chiedere i semi e chiudere il gioco non è
un modo di mettere in pausa Brian: se la finestra scade, se ne va. Non costa
niente — i semi si pagano al momento — ma il resoconto lo dice, ed era l'unica
cosa che rendeva la scadenza un problema: uscire di casa, non trovare nessuno e
non sapere perché.

### Il resoconto

Rientrando arriva un messaggio sul telefono (`MENTRE ERI VIA`). Le prime due
righe ci sono sempre e servono a spiegare il salto dell'orologio — senza, si
riaprirebbe il gioco al giorno 5 ricordandosi di averlo chiuso al giorno 3:

```
Sei stato via 45m.
GIORNO 3 21:24  ->  GIORNO 5 21:24
Si recuperano al massimo 48 ore di gioco.

Raccolto: 40 g
Piazzato: 35 g per 294 $
Quota dei dealer: -15 $
Paghe: -162 $
Vasi da annaffiare: 1
```

Le altre righe compaiono solo quando hanno qualcosa da dire, come i segmenti
dell'HUD. Sono scritte come **etichetta: valore** e non come frasi ("2 vasi sono
rimasti a secco") apposta: così non c'è nessun singolare da sbagliare quando il
numero è 1, in nessuna delle tre lingue.

Il corpo del riquadro usa il font di **sistema** (solo chi parla e il bottone
usano `alphabet.fnt`), quindi lì le cifre si possono scrivere.

Subito dopo il resoconto la partita **si salva**: il recupero è già stato speso,
e chiudere il gioco senza salvare farebbe sparire un raccolto che il giocatore
aveva già letto.

## Le tre lingue

Il gioco parla inglese, italiano e spagnolo. Si sceglie dalle impostazioni, e il
cambio è immediato: si clicca e la schermata è già nell'altra lingua, senza un
tasto "applica" da premere dopo.

Tutto il testo sta in `scripts/data/strings.gd`, una tabella
`chiave -> [inglese, italiano, spagnolo]`. È una tabella di dati come `CityMap` e
`NpcRoster`, per lo stesso motivo: le traduzioni sono contenuto, non logica, e
sparse fra le scene non si ritrovano più. Così invece una riga sola tiene le tre
versioni della stessa frase una sotto l'altra, ed è l'unico posto da guardare per
sapere se ne manca una.

### Come arrivano a schermo

`GameSettings._install_translations()` riversa la tabella nel
`TranslationServer` all'avvio, una `Translation` per lingua. Da lì in poi:

- nel codice si scrive `tr("CHIAVE")` (o `TranslationServer.translate()` dentro
  a una funzione statica, perché `tr()` è un metodo di `Node`);
- nelle **scene** si scrive direttamente la chiave nel campo del testo: Godot
  traduce da solo il testo dei `Control`. È il motivo per cui in `Main.tscn` c'è
  `text = "MENU_NEW_GAME"` e non "nuova partita".

Costruite in codice e non importate da un CSV: in questo progetto i dati stanno
in tabelle GDScript, e un CSV sarebbe l'unico file di contenuto che non si legge
insieme al codice che lo usa. In cambio non c'è nessun passaggio di importazione
da ricordarsi — si aggiunge una riga e al riavvio c'è.

### Due regole, e il controllo che le verifica

1. **Una chiave che non c'è viene mostrata così com'è.** `tr()` non avvisa e non
   torna vuota: restituisce la chiave. Una voce dimenticata si vede a schermo
   come `PC_TAB_SHOP`, ed è un errore che si scopre tardi e per caso — solo se
   qualcuno apre il gioco proprio in quella lingua.

2. **Le stringhe scritte col font del gioco possono contenere solo lettere e
   spazio.** `alphabet.fnt` ha cinquantatré caratteri: A-Z, a-z e lo spazio.
   Niente cifre, niente accenti, niente apostrofi — una "à" o una "ñ" lì dentro
   non si disegna e lascia un buco nella parola. È per questo che le impostazioni
   dicono "ESPANOL" e non "ESPAÑOL", e che le etichette del PC sono
   "GESTIONE ATTIVITA" senza accento.

Le chiavi soggette alla regola 2 sono elencate in `Strings.PIXEL_KEYS` —
l'elenco è scritto a mano perché è una proprietà di **dove finisce** la stringa,
non della stringa: la stessa frase in un'altra Label andrebbe benissimo. Il
controllo automatico "le tre lingue" verifica tutte e due le regole.

### Cosa non si traduce

I **nomi propri** (Brian, Tony, gli agenti) e le **insegne degli edifici** in
`CityMap`. Sono nomi di posti e di persone di una cittadina americana inventata:
tradurli la sposterebbe altrove. Per lo stesso motivo il nome di ogni lingua
nelle impostazioni è scritto nella lingua stessa e non si traduce — chi apre le
impostazioni per uscire da una lingua che non capisce deve poter riconoscere la
sua.

### Dove sta la scelta

In `user://settings.cfg`, **fuori** dai salvataggi. La lingua è una proprietà di
chi gioca, non della partita: dentro a `SaveData` vorrebbe dire che caricare un
salvataggio vecchio rimette il gioco nella lingua in cui era stato iniziato, e
che una partita nuova non sa in che lingua leggevi un minuto prima. Al primo
avvio si parte dalla lingua del sistema, se è una delle tre.

Chi ha del testo già composto a schermo si aggancia a
`GameSettings.locale_changed`: le Label dei `Control` le ritraduce Godot, ma una
stringa messa insieme con `%` — "GIORNO 3  08:40" — l'abbiamo scritta noi e va
rifatta. È quello che fa l'HUD.

## Controlli automatici

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . tests/Tests.tscn
```

Dopo aver aggiunto un file con un `class_name` nuovo va fatto prima un giro di
importazione, una volta sola:

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . --import
```

I `class_name` stanno in `.godot/global_script_class_cache.cfg`, che si aggiorna
quando il progetto viene importato — non quando si lancia una scena. Senza,
l'autoload non compila, la scena dei test nemmeno, e il gioco **resta lì fermo
senza stampare niente**: non è un blocco, è tutto morto in partenza. Va saputo
perché sembra un altro problema.

Il runner stampa il nome di ogni controllo prima di lanciarlo, con quanto ci ha
messo. Alcuni durano secondi — la griglia dei percorsi si costruisce due volte e
si provano centinaia di tragitti — e senza quelle righe uno che si pianta è
indistinguibile da uno lento.

`scripts/tests/game_tests.gd` controlla il ciclo di coltivazione, la sete che
rovina la resa, le vendite, i clienti di strada, l'ampliamento del seminterrato,
il giro completo di salvataggio e ricaricamento, e la mezzanotte.

Dell'**ingrosso** controlla tutta la catena: che a canale chiuso non si spedisca
niente, che il chilo lo apra una volta sola e che svuotare il magazzino non lo
richiuda, che senza furgone non si parta, che la merce esca subito e i soldi
arrivino solo al ritorno, che un prezzo del giorno che cambia a furgone in
viaggio non tocchi l'accordo già preso, che un pieno valga esattamente dieci
consegne, che si offrano solo i carichi che ci stanno in magazzino, e che un
viaggio in corso sopravviva al giro del salvataggio con l'ora del ritorno ancora
un float. E dove il furgone parcheggia: sull'asfalto, non davanti alla porta, e
comunque a fianco di casa.

Del **telefono** controlla la cosa che può sbagliare in silenzio: quando parte
l'avviso dei semi. Che non parta coi semi in mano, che non parta a vasi tutti
pieni, che parta una volta sola e non a ogni giro, che non riparta ricaricando
la partita, e che riparta invece dopo che i semi sono arrivati e finiti di
nuovo. Più il tetto di lunghezza delle voci del menù, che finisce dentro a
`Strings.problems()` insieme alle altre regole del testo.

Della **chat** controlla l'altra cosa che sbaglierebbe in silenzio: quali
messaggi restano. Che i traguardi si ritrovino ricaricando la partita e con
dentro la chiave invece della frase; che la richiesta compaia subito e la
risposta un attimo dopo; che il posto finisca dentro al messaggio; e soprattutto
che chiuso l'appuntamento il giro dei semi sparisca — anche dopo dieci chiamate
di fila, che è il caso in cui una cronologia che cresce si vedrebbe. Più
l'ordine, perché un traguardo che scatta con un appuntamento aperto deve andare
al suo posto e non in fondo.

Controlla anche che **in collina si paghi di più**: che i nomi dei quartieri
maggiorati esistano davvero sulla mappa, che l'aumento sia quello della tabella,
che un quartiere sconosciuto non regali niente, e che la stessa vendita fatta
lassù incassi più che sotto casa. E la **bolletta della luce**: che non arrivi
prima della scadenza né due volte nello stesso mese, che valga la quota fissa
più le lampade, che a cassa vuota si paghi quel che c'è senza andare sotto zero,
e che attraversando sessanta giorni arrivino due bollette — non una e non tre.

Del personale controlla che i due ruoli si paghino nei due modi giusti: che il
dealer non abbia paga e non entri nel conto delle mezzanotti, che si tenga la
percentuale della tabella e che quella percentuale non cambi assumendone un
altro, che a cassa vuota se ne vada il coltivatore e **non** il dealer (che non
aveva niente da riscuotere), e che un coltivatore copra tutti i vasi che ci sono
e non due.

Controlla anche **come si chiamano i posti d'incontro**: che il nome cominci con
la strada su cui si è davvero, e che quando nomina un'insegna quell'insegna sia
entro `MEET_SIGN_RANGE`, sulla stessa strada, e non una di quelle che in città
esistono in più copie. È il controllo che blocca il difetto raccontato in
"Comprare i semi": un nome che manda dall'altra parte non si vede leggendo il
codice, si vede solo arrivando sul posto e non trovando nessuno.

Dell'**appuntamento** controlla anche la finestra: che l'avviso "sto per
andarmene" parta solo verso la fine, una volta sola, e che non sia l'addio —
Brian è ancora lì. E che `MEET_HOURS` valga almeno cinque minuti veri: è un
numero in ore di gioco, e senza un controllo che lo converta nessuno si accorge
che dieci ore sono due minuti e mezzo, che è esattamente com'era finita.

Controlla anche il **tempo passato a gioco chiuso**: che riaprire subito non
faccia scattare niente, che un salvataggio nel futuro non regali tempo, che due
minuti veri diventino otto ore di gioco, che il tetto tenga (una settimana vale
quanto un quarto d'ora), che il personale pianti, raccolga, venda e si prenda le
paghe, che senza semi non si pianti niente e i semi non compaiano da soli, che
l'appuntamento con Brian scada, e che i vasi lasciati soli restino a secco senza
però scendere sotto alla resa minima. Gira senza aspettare: i secondi veri sono
un parametro di `Offline.catch_up()`, non l'orologio del sistema.

Controlla anche la **luce** e il **meteo**, che sono funzioni pure dell'ora e
del giorno e quindi si provano senza scena e senza aspettare: che il colore non
salti a mezzanotte, che la notte non diventi mai illeggibile, che l'ombra giri
da una parte all'altra col sole e si accorci a mezzogiorno, che col cielo
coperto sbiadisca restando però attaccata al terreno, e che il giro di
`emissive()` — diviso per la luce, poi moltiplicato dal `CanvasModulate` —
restituisca esattamente il colore di partenza. Del meteo controlla che il tiro
del giorno nuovo non esca mai dalla tabella nemmeno partendo da una chiave
sconosciuta, e soprattutto **che pesi**: che sotto la pioggia una giornata
incassi meno di una di sole e lasci meno tracce.

Controlla anche i **percorsi**: che dentro a un edificio non si cammini, che da
casa si arrivi alla porta di ognuno dei centosessanta, che nessun percorso
attraversi un muro, che un edificio grosso venga aggirato invece che attraversato
e che il tragitto più lungo resti semplificato. È roba che si scopre solo
camminandoci sopra, e per accorgersi che un edificio in fondo alla mappa è
diventato irraggiungibile bisognerebbe andarci apposta.

Controlla anche la **pianta della città**: che nessuno dei centosessanta edifici
finisca sull'asfalto o sopra a un altro, che nessun terreno particolare invada
una strada, che ogni corsia cada dentro al suo asfalto, che nessun NPC si fermi
in mezzo alla carreggiata e che ogni posto in cui Brian può dare appuntamento
sia calpestabile e raggiungibile da casa. Sono controlli
che a occhio non si fanno: un capannone in mezzo alla strada in fondo alla mappa
si nota solo passando di lì per caso, e con quarantadue isolati quel caso non
capita mai. Alla prima esecuzione ha trovato cinque edifici, cinque terreni e un
NPC fuori posto.

Il primo controllo che fa è **caricare ogni script e ogni scena del progetto**.
Serve perché un errore di sintassi si vede solo quando qualcosa carica quel
file: un pezzo di UI aperto solo dal PC in cantina può restare rotto per giorni
senza che nessuna prova lo tocchi. È già servito una volta.

Il tempo di gioco si fa passare a mano, non aspettando l'orologio: un ciclo di
coltivazione dura minuti reali, e un test che se li sta ad aspettare non lo
lancia più nessuno.

## Comandi

- **Click sinistro** sulla mappa: il protagonista ci va **seguendo le strade**
  (vedi "Come si cammina"), con un'onda che segnala la destinazione
  (`scenes/components/ClickRipple.tscn`). Oltre i 320 px di distanza **corre**
  (`run_speed`), sotto torna a camminare: la città è larga più di cinquemila
  pixel e attraversarla a passo d'uomo sarebbe un minuto e mezzo di niente, ma
  l'ultimo tratto — quello in cui si mira a una porta o a una persona — deve
  restare preciso.
- **Click sinistro su un edificio**: ci si va davanti, e se ha un interno ci si
  entra. Un click altrove mentre si sta andando annulla tutto.
- **Click sinistro su una persona**: ci si va accanto e ci si parla.
- **Tasto destro trascinando**: pan della camera. La camera segue il
  protagonista, e guardarsi intorno la stacca finché non si dà un nuovo ordine
  di movimento — con una città larga qualche migliaio di pixel, una camera ferma
  la renderebbe inservibile.
- **Rotellina**: zoom a scatti pixel-perfect (scale nette 1x → 8x, un passo per intero).
- **Freccia su**: apre e chiude il telefono (vedi "Il telefono"). Si può anche
  cliccare la linguetta in basso a sinistra.
- **Esc**: chiude il telefono se è aperto, altrimenti torna al menu principale.

## Perché lo zoom va a scatti interi

La nitidezza dipende dalla **scala netta** = `zoom della camera x stretch della
finestra`. Se è intera un pixel dello sprite copre un numero esatto di pixel a
schermo; se è frazionaria (es. 1.5) alcuni pixel ne coprono 1 e altri 2, e
l'immagine sfarfalla appena ci si muove. Per questo `net_scales` in
`scripts/systems/camera_zoom.gd` contiene **solo interi da 1 a 8**: sono già
tutti i passi possibili, fra 1x e 2x non esiste una via di mezzo che resti
pulita. Sotto 1x invece si perderebbe proprio dettaglio, perché lo sprite
verrebbe rimpicciolito.

Tre cose lavorano insieme per non perdere mai risoluzione, e vanno tenute tutte:

1. `rendering/textures/canvas_textures/default_texture_filter = 0` (Nearest).
2. `mipmaps/generate = false` su tutte le texture (e negli `importer_defaults`,
   così vale anche per i PNG che aggiungerai in futuro).
3. La camera è agganciata a coordinate mondo intere (`_snap()`): con una camera
   ferma a 320.37 il campionamento si sfalsa e gli sprite sbavano lo stesso.
