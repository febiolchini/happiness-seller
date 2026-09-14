# Happiness Seller

Gestionale di traffico di marijuana in stile tycoon. Godot 4, 2D pixel art.

Tutta la grafica è ancora **segnaposto disegnato via codice**, tranne la casa
iniziale e il fondale della cantina: l'idea è che le logiche di gioco siano già
in piedi e complete, e che la pixel art le sostituisca un pezzo per volta senza
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
ombre girano col sole, al tramonto si accendono lampioni e finestre, e ogni
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
  data/           tabelle di bilanciamento, pianta della citta', luce, meteo, testi
  characters/     logica personaggi e NPC
  components/     pezzi riutilizzabili (edifici, vasi, veicoli, fontana)
  levels/         mappa e disegno del terreno
  rooms/          logica delle stanze
  systems/        sistemi di gioco (coltivazione, camera, atmosfera, meteo, tempo offline)
  ui/             HUD, telefono, dialoghi, gestionale, formattazione
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
Il motivo è pratico: trentacinque segnaposto scritti a mano in un `.tscn` non
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
| THE FLATS | x -352→1856, y -352→2240 | il quartiere povero: casa iniziale (PNG vero), campo roulotte, condominio occupato, case popolari, banco dei pegni, minimarket, chop shop, campo da football, motel, chiesa, palestra, dormitorio |
| INDUSTRIAL PARK | x 1952→3488, y -352→2240 | fabbrica, silo, centrale, magazzino, banchina di carico, deposito camion, sfasciacarrozze, deposito container |
| DOWNTOWN | x 3584→4960, y -352→2240 | **clinica** (è lì che lavora Brian, il cugino dei semi), centro commerciale, banca, bar, ferramenta, tavola calda, piazza del mercato, parcheggi |
| CIVIC CENTER | x -352→1856, y 2336→4160 | municipio con piazza, parco centrale e giardino con **due fontane**, polizia, biblioteca, tribunale, posta, cortile della scuola |
| HILLSIDE | x 1952→4960, y 2336→4160 | zona benestante: ville, country club, campo da tennis, piscine |

La divisione è quella di sempre — tre quartieri sopra `DIVISION AVENUE`, due
sotto — con ogni quartiere grande esattamente il doppio in ciascuna direzione.

Ogni quartiere ha un colore di terreno con una dominante sua (olive, ruggine,
blu, verde-teal, verde chiaro): serve a capire a occhio dove si è anche con la
mappa tutta zoomata fuori, e sparirà con i tileset veri. Ha anche una **tavolozza**
e un elenco di **insegne** propri, che sono quelli a dare carattere agli edifici
di sfondo: le villette basse e larghe della collina non si confondono con i
capannoni grigi della zona industriale.

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

### Sostituire un segnaposto con la pixel art

Basta aggiungere `"texture"` (e l'eventuale `"offset"`) alla voce dell'edificio
in `CityMap.BUILDINGS`: lo spawner costruisce uno `Sprite2D` invece del
rettangolo, nella stessa posizione, con lo stesso script e lo stesso
comportamento al click. `FirstHouse` è già così, ed è il modello da copiare.
Un edificio di sfondo che merita un disegno suo va prima **promosso a punto di
riferimento**, cioè scritto in `BUILDINGS`.

`BuildingPlaceholder` ha l'origine **a terra, al centro della facciata**, quindi
lo sprite equivalente vuole `centered = false` e
`offset = Vector2(-larghezza / 2, -altezza)`.

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
2. Le cose che devono restare **accese** dentro a quel buio — lampioni, finestre,
   fari, il rombo sopra la testa di Brian — si disegnano con
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
| finestre | una curva di palazzo vero: poche di giorno, tantissime dopo cena, poche alle tre di notte |
| fari e stop | accesi quando lo sono i lampioni |
| fondale oltre i bordi | segue l'aria, molto più cupo |

La notte **non scende mai vicino al nero**: un gestionale si gioca anche di
notte, e una notte a 0.1 è una schermata nera con dentro dei soldi da contare. A
fare la differenza fra giorno e notte sono i lampioni accesi e le finestre, non
il buio. C'è un controllo automatico che lo verifica ora per ora.

### Le finestre degli edifici

I segnaposto degli edifici adesso hanno le finestre, e sono il pezzo che fa più
lavoro di tutti: di giorno danno la scala a quello che altrimenti resta un
rettangolo colorato, di notte trasformano una fila di scatole spente in una
città abitata.

**Quali** sono accese lo decide l'ora, ma **quale finestra** si accende prima
delle altre è deciso una volta per sempre dalla sua posizione nel mondo: ogni
finestra ha la sua soglia e si accende quando la quota dell'ora la supera. Non
c'è niente da tenere in vita e niente da salvare, e soprattutto le finestre non
sfarfallano — le accende e le spegne il passare delle ore, sempre nello stesso
ordine. Tre tinte: il giallo delle lampade, l'ambra delle stanze sul retro, e il
bluastro di chi sta guardando la TV.

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
`Entrance`, `Kitchen` e `Basement` sono scene ereditate che si riferiscono ai
propri nodi per indice, e aggiungere un nodo alla scena base sposterebbe quegli
indici in tutte e tre. È la stessa regola della città — la scena si costruisce
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

## Il telefono

`scenes/ui/Phone.tscn`: il telefono in basso a sinistra. Scivola su quando
arriva un messaggio, si apre con la **freccia su**, e da lì si può chiamare
Brian per i semi senza tornare al PC in cantina.

Come tutto il resto è disegnato a mano: quando arriverà la pixel art il
`_draw()` diventa una texture e nient'altro cambia.

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
| chiuso | fuori resta solo la **linguetta** col triangolino, che pulsa di verde finché c'è un messaggio non letto |
| messaggio | scivola su fin dove finisce il testo, si legge, e dopo 5,5 s torna giù da solo |
| aperto | tutto fuori: il messaggio in cima, e sotto il menù |

Chiuso **non sparisce mai del tutto**: la linguetta è l'unica cosa che si vede
del telefono per la maggior parte della partita, ed è anche l'unico posto in cui
si può dire "c'è qualcosa per te". Una scorciatoia che non si vede da nessuna
parte non la trova nessuno.

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

### Chiamare Brian da qui

Il menù ha per ora una voce sola, ed è la stessa cosa che fa il bottone nella
scheda GROW del PC. **Non è un doppione per sbaglio**: i semi finiscono mentre
si è in giro per la città, e prima l'unico modo di chiederne altri era tornare
in cantina ad aprire il PC — cioè attraversare la mappa per premere un bottone.

Come nel PC è **un bottone solo che cambia faccia** invece di tre che si
accendono a turno: `CHIAMA BRIAN`, `CI PENSA LUI` mentre si aspetta, `TI
ASPETTA` quando è sul posto, spento quando non c'è niente da fare.

Quelle tre scritte hanno un **tetto di lunghezza vero** (`Strings.PHONE_MENU_CHARS`,
tredici caratteri): lo schermo del telefono è largo 112 px e il bottone taglia
quello che avanza. È già successo — "BRIAN CI PENS" — e adesso c'è un controllo
automatico che lo verifica, perché a leggerle nella tabella sembrano tutte corte
uguali.

### Uno per scena, il testo no

Il telefono è un nodo di scena: sta in `City.tscn`, e nelle stanze lo costruisce
`room.gd` da codice (stessa ragione dell'atmosfera — `Room.tscn` è la scena base
delle altre tre e aggiungerci un nodo sposterebbe i loro indici).

Quello che c'è **scritto dentro** invece vive su `GameState.last_text`, non nel
telefono: un messaggio arrivato in cantina si rilegge uscendo di casa. Non
finisce nel salvataggio — è quello che è appena successo, non un pezzo di
partita.

## HUD

`scenes/ui/HUD.tscn`: una riga sola in alto a destra, e i messaggini che
scorrono sotto. Sta sia in strada sia **dentro agli edifici** — è figlio di
`Room.tscn`, quindi tutte le stanze se lo ritrovano senza che vadano toccate
una per una.

```
4.200 $  ·  GIORNO 3  12:41  ·  PIOGGIA  ·  75 g  ·  SORVEGLIATO
```

### Perché una riga e non un pannello

Prima era un riquadro con bordo e sfondo, coi valori impilati dentro. Un
pannello in un angolo è una finestra piccola: ruba spazio anche quando non ha
niente da dire, e in un gioco in cui si guarda la strada e si clicca sulle cose,
quel bordo continua a segnare un rettangolo che non fa parte del mondo.

Adesso è una riga sola senza sfondo: i soldi in evidenza, il resto più piccolo e
più spento, separato da punti. A tenerla leggibile sopra a qualunque fondale è
l'**ombra dura** sotto a ogni scritta, non una cassa dietro.

### I segmenti compaiono quando servono

La scorta quando ce n'è, l'attenzione quando è salita sopra 10, il tempo che fa
quando non è sereno, il posto dove aspetta Brian finché aspetta. A inizio partita la riga è due voci e si allunga
man mano che la partita cresce. Il punto di separazione va messo solo *fra* due
segmenti accesi: quello davanti al primo resterebbe appeso nel vuoto, ed è
l'unico pezzo di logica che c'è nel disegno della riga.

Aggiungerne uno (proprietà, debiti, reputazione) vuol dire infilare una voce in
`_segments`: Label, punto e aggiornamento a schermo vengono da soli.

### Si toglie di mezzo davanti alle finestre

Il gestionale del PC è un `Control` dentro alla scena, quindi sta su una tela
più bassa di quella dell'HUD (`layer = 5`): senza far niente, l'HUD gli
comparirebbe **sopra**, a metà della schermata. Per questo si nasconde finché
c'è qualcuno nel gruppo `modal`, e sono le finestre a mettercisi da sole
(`management_window.gd`, `phone_notice.gd`). Elencarle nell'HUD vorrebbe dire
che una finestra nuova funziona solo se qualcuno si ricorda di un file diverso
da quello che sta scrivendo.

### Font e cifre

`assets/sprites/ui/alphabet.fnt` contiene **solo A-Z, a-z e lo spazio: nessuna
cifra e nessuna punteggiatura**, anche se `FONT_CHARMAP.md` ne prevede. Per
questo tutto ciò che contiene numeri usa il font di sistema — HUD, valori del
gestionale, testo dei dialoghi, righe dei salvataggi — mentre titoli, nomi dei
personaggi, etichette e tasti, che sono di sole lettere, usano quello del gioco.

`scripts/ui/ui_format.gd` raccoglie **come** si scrivono soldi, orari e durate:
gli stessi numeri compaiono nell'HUD, nel PC, nei vasi e nella gestione
salvataggi, e la prima volta che se ne scrive una copia in più le due versioni
prima o poi si allontanano, e lo stesso valore finisce scritto in due modi
diversi nella stessa schermata.

Quando aggiungerai `0-9` e la punteggiatura al font, si potrà uniformare tutto.

## Entrare negli edifici

Cliccando sulla casa questa si schiaccia un istante come un pulsante, il
protagonista ci cammina davanti, svanisce nella porta e si apre la stanza.

Il pezzo riutilizzabile è `scripts/components/enterable_building.gd`, che sta
sul nodo che *disegna* l'edificio — così la schiacciata al click agisce sul
disegno vero. `BuildingPlaceholder` lo **estende**, quindi ogni edificio della
città è cliccabile: quelli senza `interior_scene` fanno solo avvicinare il
protagonista, e rendere visitabile il minimarket vuol dire aggiungere
`"interior"` alla sua voce in `CityMap.BUILDINGS`, niente altro.

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

`scenes/rooms/Room.tscn` è la stanza base; `Entrance`, `Kitchen` e `Basement`
sono **scene ereditate** che cambiano solo `room_name`, `background_color`,
`exits`, e i due campi della luce — `daylight` e `window_rect`. La logica sta
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

È la formula da usare per piazzare qualcosa su un dettaglio preciso del disegno.
Il modo più rapido per ricavarla su un fondale nuovo è sovrapporre una griglia di
coordinate e misurare.

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

Brian **non aspetta per sempre**: dopo dieci ore di gioco (`MEET_HOURS`) se ne
va e l'appuntamento si chiude. Serve che sia generoso — dieci ore bastano ad
attraversare la mappa più volte — perché un appuntamento perso per essersi
trovati dall'altra parte della città punirebbe l'aver giocato, non una scelta
sbagliata. E serve che scada: un appuntamento eterno che non si riesce a
raggiungere bloccherebbe per sempre l'unica fonte di semi.

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
esiste in più copie — `MOTEL`, `HOUSE` e `WAREHOUSE` sono anche nomi generati
dai quartieri, e manderebbero alla copia sbagliata. Quando non c'è un'insegna
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
non finire sopra alla riga dell'HUD, e si toglie di mezzo davanti alle finestre
modali, come l'HUD.

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

### Quanti se ne possono avere

I dealer sono al massimo tre: il personale è un moltiplicatore, non un
sostituto del giocatore.

Per i coltivatori il tetto **non è scritto da nessuna parte**: lo dice il posto
che c'è. Un coltivatore segue `POTS_PER_GROWER` vasi (sei), e in cantina i vasi
sono al massimo sei, quindi finché la coltivazione sta lì sotto ne basta **uno**
— e il PC lo dice (`NON SERVE NESSUN ALTRO`) invece di lasciare che il giocatore
spenda quattrocentoventi dollari per uno che sta a guardare. `Staff.max_for()`
lo ricava dai vasi sbloccati, quindi quando ci sarà una seconda proprietà il
tetto salirà da solo senza che nessuno debba ricordarsene.

### Le paghe, e chi se ne va

Si scalano a mezzanotte (`Staff.pay_wages()`, agganciata a `day_started`); se la
cassa non basta se ne va uno, e per primo quello che costa di più — lasciare il
giocatore in rosso con l'organico intatto vorrebbe dire un buco che si allarga
da solo ogni notte, senza niente che lo fermi.

I dealer non entrano mai in questo conto e **non se ne vanno mai per soldi**:
uno che si tiene una quota di quello che vende non ha niente da riscuotere nelle
notti in cui non ha venduto niente. A restare senza lavoro sono i coltivatori,
che è anche il verso giusto — sono loro il costo fisso che affonda una partita.

### Ingrosso o strada

`SaveData.wholesale_share` (0-100) decide come i dealer dividono la merce: il
resto va in strada, che paga il 40% in più e alza l'attenzione. Nel PC sono due
bottoni a passi di dieci e non uno slider: a passi di dieci le scelte sono
undici, e undici scelte non hanno bisogno di un controllo continuo — uno slider
a 640x360 sarebbe largo sessanta pixel e impossibile da mirare.

È **la scelta vera** di questa parte del gestionale: la vendita automatica in
strada rende di più ma fa salire `heat` mentre il giocatore non sta guardando.

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

Del **telefono** controlla la cosa che può sbagliare in silenzio: quando parte
l'avviso dei semi. Che non parta coi semi in mano, che non parta a vasi tutti
pieni, che parta una volta sola e non a ogni giro, che non riparta ricaricando
la partita, e che riparta invece dopo che i semi sono arrivati e finiti di
nuovo. Più il tetto di lunghezza delle voci del menù, che finisce dentro a
`Strings.problems()` insieme alle altre regole del testo.

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
