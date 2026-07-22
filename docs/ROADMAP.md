# Roadmap verso la beta

Regola: una milestone è chiusa solo quando Stefano l'ha giocata e approvata. Non si apre la successiva prima.

## M0 — La barca sul mare
Fondazione del game feel. Tutto il resto poggia qui.
- [x] Piano d'acqua low-poly con shader onde semplice
- [x] Barca pilotabile con WASD/frecce (accelerazione, virata, deriva leggera)
- [x] Camera terza persona GTA-style con parametri `@export` (altezza, distanza, inclinazione, smoothing)
- [x] Cielo, luce, orizzonte: prima impressione dell'atmosfera
- [x] **Criterio di uscita**: guidare la barca per 5 minuti è piacevole di per sé

## M1 — Il mondo
- [x] Zona di mare con isole, campo di scogli, confini mappa
- [x] Boe raccoglibili al passaggio (comuni + dorate vicino ai pericoli), respawn a tempo
- [x] Collisioni e danni scafo, HUD minimo (denaro, scafo)
- [x] Porto: attracco, vendita, riparazione (UI essenziale)
- [x] **Criterio di uscita**: il ciclo esci→raccogli→rischia→rientra→ripara sta in piedi

## M2 — La progressione
- [x] 3 barche acquistabili con guida distinta
- [x] Upgrade funzionali: motore, scafo, stabilità, stiva
- [x] Meteo calmo/mosso; il mosso destabilizza davvero (cancello di progressione)
- [x] Prima curva economica completa (prezzi in `Resource`, bilanciabili senza toccare scene)
- [x] Salvataggio/caricamento
- [ ] **Criterio di uscita**: arrivare alla seconda barca è desiderabile e guadagnarsela è soddisfacente

## M2.5 — La costa (prerequisito di M3)
La mappa diventa un luogo: la baia di Bova Marina.
- [x] Costa a nord con spiaggia, paese bianco, campanile, colline e Aspromonte in foschia
- [x] Promontori rocciosi ai lati della baia, scogli sotto costa, isole al largo
- [x] Stato del mare per distanza dalla costa (battigia → calme → medie → mosse) + meteo sopra
- [x] Il mare grosso frena la barca; nelle condizioni estreme danneggia lo scafo (allarme a schermo)
- [x] Atmosfera legata al meteo: luce e foschia si incupiscono col mare mosso
- [ ] **Criterio di uscita**: la baia si legge a colpo d'occhio (costa = sicurezza, largo = rischio) e sembra Bova Marina

## M3 — Missioni, gare, pesca
- [x] Migliora la UI/UX dei pannelli. Dev'essere facile capire cosa si ha raccolto, lo shop ecc
- [x] Benzina barca, possibilità di fare rifornimento pagando e trovare la benzina in mare con 5% di probabilità
- [x] Minigioco pesca + zone di pesca + stiva
- [x] Gara a checkpoint con 2-3 IA, premi, sblocco contenuti

### Feedback playtest di Stefano (22/07/2026) — priorità: si fanno prima delle task sotto

- [x] **Mare aperto grande, a zone di vento**
  - Allargare la baia verso il largo: `World.bounds_depth` da 340 a ~700 m (e `scatter_half_width`/`bounds_half_width` in proporzione). Più punti boa, taniche e campi di scogli per non diluire la densità. Alzare `far` della camera e la nebbia in `main.tscn`; la minimappa si adatta da sola (legge gli export del World).
  - Oltre le acque medie non c'è più la fascia "mosse" uniforme: c'è il **mare aperto**, agitazione di base media che cresce con la distanza (curva continua con `@export`, non gradini) — si può passare molto tempo al largo senza tempesta perenne.
  - **Celle di vento**: 4-6 aree circolari (centro, raggio 100-200 m, intensità 0..1) che derivano lentamente e si rafforzano/spengono nel tempo (timer + rumore, gestite da un nodo `WindField` accanto a Weather). `wind_multiplier(pos)` moltiplica l'agitazione della Sea in quel punto: dentro una cella attiva il mare si ingrossa davvero, guida e danni compresi. Attenzione: la matematica CPU di `Sea.state_multiplier` e lo shader vanno tenuti allineati (uniform array di vec4: xy=centro, z=raggio, w=intensità).
  - **Affondamento**: a scafo 0 oltre le acque medie la barca affonda — carico perso e recupero a pagamento al porto. Sotto costa resta il traino attuale. È il vero rischio del mare aperto (GDD pillar 2); l'allarme a tick di danno già esistente resta il preavviso.
  - Minimappa/HUD: le celle attive si vedono in minimappa (macchie scure), l'HUD mostra lo stato locale del mare nel punto della barca.
- [x] **Barche più belle** (bassa priorità, si può fare in coda)
  - Provare i modelli del watercraft/pirate kit di Kenney (CC0) al posto dei primitivi attuali nelle tre `*_visual.tscn`; registrare i crediti in `assets/CREDITS.md`. Se non convincono, migliorare i primitivi (più mesh, dettagli: parabrezza, luci, sartiame). *Fatto coi primitivi migliorati (il sito Kenney non è scaricabile da script, idea spostata in backlog): parabordi, parabrezza, luci di via emissive, panca/casse/verricello, sartiame sul peschereccio, arco radar e battagliola sul cabinato.*
- [x] **Camera orbitabile col mouse**
  - In `chase_camera.gd`: il movimento del mouse orbita la camera attorno alla barca (yaw libero 360°, pitch limitato ~-10°..+45°), `Input.MOUSE_MODE_CAPTURED` durante la guida.
  - Ritorno automatico dietro la poppa dopo ~2 s senza input mouse (smooth). Sensibilità e tempo di ritorno `@export` da tarare.
  - Ogni pannello (porto, pesca, regata, pausa) rimette `MOUSE_MODE_VISIBLE` e resetta l'orbita; alla chiusura si ricattura. Centralizzare con un segnale/autoload per non duplicare la logica in 4 posti.
  - Zoom con rotella: in backlog, non qui.
- [x] **Gare difficili rispetto alla barca**
  - Le IA non hanno più velocità assolute: in `GameState.RACE_AI` diventano **frazioni della velocità effettiva del giocatore al via** (es. 0.90 / 0.97 / 1.03) e stabilità relativa alla sua (es. -0.1 / +0.0 / +0.15, clampata 0..1). Calcolo in `RaceCourse._spawn_racers` con `GameState.effective_max_speed()`/`effective_stability()`.
  - Così la gara resta combattuta con ogni barca e upgrade: vincere richiede traiettorie, non solo motore. Il rivale veloce (1.03×) si batte solo sfruttando le sue frenate in curva e il mare.
  - Premi scalati con la barca corrente (moltiplicatore per tier) perché la regata resti redditizia senza diventare farming facile.
  - Aggiornare `tests/m3_race.gd` di conseguenza.
- [x] **Pesca 2.0 — il duello**
  - Resta la ferrata a tempismo (fase 1, finestra anche più stretta), poi si aggiunge la **fase 2, il recupero**: il pesce tira. Tieni premuto E per recuperare (la barra progresso sale, ma sale anche la tensione della lenza); rilascia per far calare la tensione. Tensione al massimo troppo a lungo → il filo si spezza, pesce perso.
  - I pesci pregiati fanno **scatti casuali** (la tensione schizza per 1-2 s): bisogna mollare al momento giusto. Aggressività, frequenza e durata degli scatti per specie in costanti `GameState` (si bilancia senza toccare la scena).
  - Feedback: la barca beccheggia verso il pesce durante il duello, la barra tensione cambia colore (verde→giallo→rosso), piccolo shake sull'ultimo tratto.
  - Il pescato e la stiva restano come sono; cambia solo il minigioco dentro `fishing_zone.gd` (stati BITE→FIGHT→RESULT).

### Feedback playtest di Stefano — round 2 (22/07/2026)

Prima sessione giocata davvero dall'inizio. Emerso: il gioco non si spiega, l'HUD è piccolo, mancano feedback, e il bilanciamento è troppo morbido. Si fanno **prima delle "Task rimanenti"** sotto, nell'ordine di priorità qui indicato.

#### P0 — Bugfix (crash da sistemare subito)

- [x] **Crash classifica regata — `Out of bounds get index '7'`** (`scenes/race/race_course.gd:235`)
  - Causa: in `_process` (RACING) si chiama `_check_player_gate()` e subito dopo `_update_status()`. Quando il giocatore prende l'ultimo cancello, `_check_player_gate` porta `_player_next` a `_waypoints.size()` (7) e chiama `_finish_player()`, ma nello stesso frame `_update_status()` → `_player_rank()` legge `_waypoints[_player_next]` fuori dai limiti.
  - Fix: dopo `_check_player_gate()` proseguire con `_update_status()` **solo se** `_state == State.RACING` (uscire dal `match`/`return` se lo stato è cambiato). In più mettere in sicurezza `_player_rank()` con `mini(_player_next, _waypoints.size() - 1)` come già fa `next_gate_position()` ([race_course.gd:110](scenes/race/race_course.gd#L110)).
- [x] **Crash uscita dal porto — `Parameter "data.tree" is null`** (`scenes/port/port.gd:125`)
  - Causa: `_confirm_departure` fa `await get_tree().physics_frame`, ma se il nodo Port esce dall'albero nel frattempo (cambio scena / partenza) `get_tree()` è `null`.
  - Fix: primo statement `if not is_inside_tree(): return`, e ripetere il controllo dopo ogni `await` (il nodo può essere liberato durante l'attesa). Verificare anche il gemello in `race_course.gd`/`fishing_zone.gd` se usano lo stesso pattern di `await`.

#### P1 — Onboarding e leggibilità (il nuovo giocatore non capisce)

- [x] **Primo obiettivo chiaro all'avvio** — "non capisco cosa fare"
  - All'inizio partita (nuovo salvataggio) mostrare un obiettivo guidato leggero, non un tutorial invasivo: una riga d'aiuto contestuale che si aggiorna ("Raccogli 3 boe e torna al porto per venderle" → "Attracca al porto: rallenta ed entra in zona" → "Prova la pesca / una regata"). Testi in costanti, avanzamento tracciato in `GameState` (flag `tutorial_step`, salvato).
  - Sfrutta il `NoticeLabel`/hint già esistenti nell'HUD ([hud.tscn](scenes/hud/hud.tscn), font 28) e le zone (`DockZone`, `FishingZone`, `StartZone`) che già mostrano hint di prossimità. Non serve una macchina a stati complessa: bastano 4-5 tappe.
- [x] **HUD più grande** — "l'interfaccia è troppo piccola"
  - Ingrandire i pannelli in [hud.tscn](scenes/hud/hud.tscn): denaro (`MoneyLabel` 34→~44), titoli scafo/benzina (22→~28), barre `HullBar`/`FuelBar` (190×22 → ~240×30), `CargoInfo` (22→~28), pannello velocità `SpeedLabel` (40→~52), `ZoneLabel` (24→~30). I pannelli hanno anchor/offset fissi e **nessuno scaling dinamico** ([hud.gd:32-35](scenes/hud/hud.gd#L32)): esporre un `@export var ui_scale: float` che moltiplica i font_size all'`_ready`, così Stefano tara da Inspector senza toccare la scena.
  - Verificare che a scala maggiore i pannelli non escano dallo schermo (usare `size_flags`/margini, o scalare via `CanvasLayer`/`Control.scale`).
- [x] **Feedback di danno all'urto** — "quando sbatti non te ne accorgi"
  - Oggi l'urto applica solo `_speed *= 0.3` + calo barra scafo ([boat.gd:241-251](scenes/boat/boat.gd#L241)), nessun feedback percepibile. Aggiungere: **flash rosso** sulla barra scafo (`HullBar`) a ogni `apply_damage`, **shake camera** proporzionale alla forza d'urto (`@export` intensità/durata in `chase_camera.gd`), spruzzo/particelle e suono all'impatto.
  - È l'anticipo dell'item M4 "Feedback d'impatto" (riga in M4): tirarlo avanti qui. Agganciare al segnale `GameState.hull_changed` (delta negativo) o a un nuovo segnale `boat_hit(force)` emesso da `_handle_impacts`.
- [x] **Riferimento visivo per la regata** — "un nuovo giocatore non capisce dove si entra in gara"
  - Rendere leggibile lo `StartZone` della regata anche da lontano: un gonfiabile/arco di partenza a mesh + `Label3D` "REGATA" fluttuante (come `Nino` è un Label3D al porto), e un marker permanente in minimappa per il punto di partenza (oggi il marker regata appare **solo durante** la gara, `_draw_race_gate` con `course.is_racing()` — [minimap.gd:210-217](scenes/hud/minimap.gd#L210)).
  - Quando la barca è in zona, l'hint esiste già ("Premi E per la regata", [race_course.gd:335](scenes/race/race_course.gd#L335)); il problema è **arrivarci sapendo che c'è**.
- [x] **Spiegare gli upgrade della barca** — "non sono spiegati"
  - Nel cantiere ([port.gd:274-302](scenes/port/port.gd#L274)) ogni upgrade mostra solo "liv. N → N+1 (-X $)". Aggiungere per ciascun tipo (`MOTOR/HULL/STABILITY/CARGO`) una **riga di descrizione** dell'effetto in gioco ("Motore: +velocità di punta", "Stabilità: tieni il mare mosso", "Scafo: reggi più urti", "Stiva: porti più carico") e mostrare il **delta del prossimo livello** (es. vel 42 → 46). Testi in un dizionario `UPGRADE_DESC` in `GameState`, così stanno vicino a `UPGRADE_NAME`.

#### P1 — Navigazione e QoL

- [x] **Rallentamento automatico in avvicinamento al porto**
  - Oggi l'attracco è un *gate*: se sei sopra `docking_max_speed=1.5` leggi "Rallenta per attraccare" e basta ([port.gd:67-76](scenes/port/port.gd#L67)), nessuna frenata assistita. Aggiungere un'**Area3D di rallentamento** più larga attorno alla `DockZone` (box 18×18) che, quando la barca è dentro, applica un cap progressivo alla velocità max (più vicino al porto = cap più basso), così arrivare e fermarsi è naturale. Raggio/intensità come `@export`. *Fatto: `ApproachZone` (44×44) sul Port, cap progressivo `Boat.approach_speed_cap` da nessun limite al bordo fino a `approach_min_speed` sul molo (`approach_slow_radius`/`approach_min_speed` @export). Sfrutta il ramo `_speed > cap` già esistente → frenata assistita.*
- [x] **Abbandono gara gratuito e visibile**
  - La ritirata **esiste già** ed è gratuita (`ui_cancel`/Esc → `_retire`, [race_course.gd:94-100](scenes/race/race_course.gd#L94)), ma non è scopribile. Aggiungere un hint a schermo durante la gara ("Esc — abbandona la regata (gratis)") e verificare che funzioni anche in `COUNTDOWN`. Nessun costo/penalità: solo `post_notice` e `_cleanup`. *Fatto: hint mostrato in `_update_hint` durante COUNTDOWN e RACING (riusa il Label bottom esistente); la ritirata funzionava già in COUNTDOWN.*
- [x] **Il mare verso il largo non deve "finire" di colpo**
  - La meccanica del countdown **c'è già** (`escape_countdown=10`, `_rescue_boat`, [world.gd:79-108](scenes/world/world.gd#L79)): il problema è **visivo/percepito**, il piano d'acqua sembra terminare come un muro. Estendere il piano del mare / nebbia ben oltre `bounds_depth=700` così l'orizzonte resta acqua, e rendere la zona di countdown un passaggio graduale (foschia/colore che si scurisce avvicinandosi al confine) invece di un bordo netto. La navigazione oltre il confine resta consentita col countdown già presente. *Fatto: piano mare 900→1400 (subdiv 559, densità onde invariata), `follow_z_max` 160→500 → bordo sud oltre z=1200 (nella nebbia, `fog_depth_end=650`), bordo nord sempre sotto la costa. **Da verificare in gioco**: performance del piano più grande e sfumatura al confine.*

#### P1 — Bilanciamento

- [x] **Taniche benzina (rosse quadrate): max 1 attiva in tutta la mappa**
  - Oggi 22 punti candidati @5% con respawn a 60s che **si accumulano** ([world.gd:206-211](scenes/world/world.gd#L206), `FUEL_CAN_SPAWN_CHANCE=0.05`). Cambiare la logica: un solo `FuelCan` attivo alla volta sull'intera mappa (contatore in `World` o gruppo `&fuel_cans` con guardia in `_try_spawn`), respawn del singolo punto solo quando quello precedente è stato raccolto. *Fatto: guardia `_any_active()` sul gruppo `&fuel_cans` in `FuelCan._try_spawn` (max 1 presente).*
- [x] **Troppe boe comuni sulla mappa**
  - Le "comuni" che intasano sono le **gialle**: 28 punti @spawn certo (`yellow_buoy_count=28`, `BUOY_SPAWN_CHANCE[YELLOW]=1.0`) → sempre ~28 in acqua. Ridurre `yellow_buoy_count` (es. 28→14) e verificare in gioco con Stefano quale colore chiama "blu" (le blu vere sono già rare: 24 punti @5%, valore 150 — [game_state.gd:41-50](autoload/game_state.gd#L41)). Nota: nascondendo le boe dalla minimappa (radar, sotto) il senso di "troppe" cala già molto. *Fatto: `yellow_buoy_count` 28→14.*
- [x] **Stiva troppo capiente → il gioco è troppo facile**
  - Ridurre `cargo_capacity` base di ogni barca nei `.tres` (`resources/boats/`, campo in [boat_definition.gd:31](scripts/boat_definition.gd#L31)): oggi barchetta **8**, pescareccio **18**, cabinato **30**. Abbassare (es. 5 / 10 / 18) così tornare a vendere è più frequente (rientro = parte del loop, GDD § Boe). Ricontrollare che gli upgrade stiva (`cargo_step` 4/6/8) restino sensati con i nuovi valori. *Fatto: 8/18/30 → 5/10/18 (step invariati 4/6/8).*
- [x] **Più spot per le gare + ribilanciare la gara attuale**
  - **Semplificare la gara esistente**: l'IA "Turi" è troppo forte. Rivedere `GameState.RACE_AI` ([game_state.gd:195-202](autoload/game_state.gd#L195)) — abbassare `speed_ratio`/`turn` di Turi così la gara base è vincibile con la barchetta.
  - **Aggiungere spot di gara**: la scena `RaceCourse` è parametrica sui `Checkpoints`. Prevedere 2+ percorsi con difficoltà diversa: uno **facile sotto costa** (quello attuale, addolcito) e uno **al largo, difficile** (checkpoint nelle acque medie/aperte, IA più aggressive, premi maggiori con `RACE_PRIZE_TIER_MULT`). Ogni spot è un'istanza di `RaceCourse` con i propri waypoint e set IA. *Fatto: Turi 1.03→0.99 (tutte le IA ≤ giocatore); `RaceCourse` parametrico (`ai_hard`, `prize_multiplier` @export); `RACE_AI_HARD` (Saro/Nunzio/Peppe più veloci) per lo spot al largo `RaceCourseOffshore` (premi ×1.8). Minimappa mostra entrambi gli spot. **Da verificare in gioco**: le posizioni dei 6 checkpoint del percorso al largo (Marker3D in `world.tscn`, facili da trascinare nell'editor).*
- [x] **Ingrandire le zone di pesca**
  - Sembrano spot troppo piccoli. Aumentare il `CylinderShape3D` radius della `FishingZone` (oggi **9.0**, [fishing_zone.tscn:5-7](scenes/fishing/fishing_zone.tscn#L5)) e gli anelli visivi ripple (inner 3.4-4.0 / outer 6.4-7.0) di conseguenza — es. radius 14-16 con anelli proporzionati. Esporre il radius come `@export` per tararlo. Verificare la separazione min (60m) e `_is_clear` in `world.gd` restino coerenti col raggio maggiore. *Fatto: `zone_radius` @export (default 15) applicato a collisione + anelli + giro d'uccelli in `_apply_radius`; separazione boe-zona 16→22; raggio minimappa 9→15.*

#### P2 — Nuovo sistema: NPC "il nipote in mare" + Radar

Sostituisce la visibilità gratuita di boe e zone in minimappa con una progressione: prima non vedi nulla, poi guadagni il radar e lo potenzi. (Rientra nel GDD § Missioni ed Eventi — aggiornare il GDD quando il sistema è definito.)

- [ ] **Minimappa: boe e zone di pesca NON più visibili di default**
  - In [minimap.gd](scenes/hud/minimap.gd) `_draw_pickups` (:222) e `_draw_fishing_zones` (:199) devono disegnare boe/taniche/zone **solo quando il radar è attivo** (finestra di 10s dopo l'uso). Fuori dalla finestra la minimappa mostra solo mare, coste, scogli, isole, porto, celle di vento e la barca. Il marker regata resta come QoL (o diventa anch'esso NPC-driven — da decidere con Stefano).
- [ ] **NPC del nipote — dietro il blocco di scogli a destra della mappa**
  - Nuovo NPC ancorato al campo di scogli a est. Riusare il pattern Port/FishingZone: `Area3D` trigger + `Label3D` fluttuante + hint + pannello dialogo (CanvasLayer) con `GameState.push_ui_focus/pop_ui_focus` e `boat.input_enabled=false` durante il dialogo (nessun sistema di dialoghi esiste ancora: basta un pannello con testo e un bottone). Modello low-poly come `Nino`.
  - **Missione "Recupera mio nipote in mare"**: all'accettazione compare un marker in minimappa (stessa logica del cancello regata) su un punto al largo; lì galleggia il nipote (Area3D raccoglibile). Raccolto, il marker torna sull'NPC; riportandolo, la missione si chiude e sblocca il **radar**. Stato/progresso in `GameState` (`grandson_quest: enum {NONE, ACCEPTED, CARRYING, DONE}`), salvato.
- [ ] **Radar — sblocca la rilevazione a impulsi**
  - Parametri (costanti/`@export` in un nuovo autoload o in `GameState`, così si bilanciano):
    - **Utilizzi/cooldown**: 1 utilizzo ogni **60s** (livello base).
    - **Ampiezza**: raggio di rilevazione = **1/3 della mappa** al livello base (frazione di `bounds_depth`).
    - **Durata**: i rilevamenti restano visibili in minimappa per **10s** dopo l'impulso.
  - Input dedicato (nuova action, es. `radar_ping` su tasto R) attivo solo dopo lo sblocco; HUD mostra cooldown e finestra attiva. Durante la finestra, boe/taniche/zone entro il raggio compaiono in minimappa (integra il punto "minimappa nascosta" sopra).
  - **Potenziamenti** (nuova famiglia di upgrade, dal nipote o da Nino/porto): migliorano **ampiezza** (raggio) e **durata** della rilevazione (ed eventualmente il cooldown). Curva costi in `GameState` come gli altri upgrade (`UPGRADE_COSTS`/`FISHING_GEAR_COSTS`).

#### P2 — Inventario (stiva) su tasto I, con icone

- [ ] **Pannello inventario apribile con "I", ogni item con immagine**
  - Oggi la stiva è solo testuale (BBCode colorato in `cargo_detail_bbcode`, [game_state.gd:503-517](autoload/game_state.gd#L503)); nessuna icona esiste (`assets/` ha solo `CREDITS.md`). Nuova action `inventory` su tasto **I** che apre/chiude un pannello CanvasLayer con una **griglia di item**: per ogni tipo di boa e di pesce un'icona + quantità + valore unitario, e il totale/capacità stiva.
  - **Icone**: generarle o procurarle CC0 (una per tipo: gialla/rossa/blu, sardina/orata/ricciola/tonno). Registrare i crediti in `assets/CREDITS.md`. In assenza di asset, come primo step icone procedurali a colori (i colori già esistono in `BUOY_HEX`/`FISH_HEX`).
  - Rispettare il pattern UI: `push_ui_focus/pop_ui_focus`, `input_enabled=false` mentre è aperto, chiusura con I o Esc. Non deve aprirsi durante porto/pesca/regata/pausa (controllare lo stato focus).

### Task rimanenti

- [ ] **Missioni di consegna/recupero dai porti**
  - Nuovo **approdo secondario** sulla costa, lontano dal porto principale (scena Port ridotta: attracco e consegna, niente cantiere) — previsto dal GDD beta.
  - Bacheca nel menu porto (nuovo bottone): 2-3 missioni generate da template. **Consegna**: porta N casse all'approdo entro T minuti (le casse occupano stiva: si sceglie se rinunciare al pescato). **Recupero**: raggiungi il punto segnato in minimappa, raccogli il pacco/relitto galleggiante, riportalo al porto.
  - Ricompensa scalata su distanza e fascia di mare del punto (più a largo = più soldi, GDD pillar 2). Una missione attiva alla volta nella beta; stato e progresso in GameState, salvati.
  - Marker missione in minimappa (stessa logica del cancello regata).
- [ ] **Eventi casuali con scelta + reputazione**
  - 4-6 eventi scritti bene (GDD: battono 20 generici): barca in avaria, pescatore senza benzina, boa misteriosa, carico alla deriva, tempesta in arrivo…
  - Trigger: un tiro ogni 2-3 minuti di navigazione oltre le acque calme; l'evento apre un pannello con 2 scelte e conseguenze immediate (denaro, carburante, scafo, reputazione).
  - **Reputazione** -100..+100 in GameState (salvata): sconta o rincara riparazioni e rifornimento (±15% circa) e in futuro filtra le missioni migliori. Visibile nel pannello porto.
  - Ogni evento è un `Resource` (.tres): testo, scelte, effetti — si scrivono e bilanciano dall'Inspector senza toccare codice.
- [ ] **Criterio di uscita**: una sessione da 20 minuti offre almeno 3 attività diverse sensate

## M4 — Beta
- [ ] Customizzazione estetica (vernici, accessori)
  - Vernici = palette di tinte sui materiali del modello (per barca, salvate); accessori come nodi opzionali del visual (bandiera, luci, parabordi). Prezzi alti: è il pozzo dell'economia (GDD pillar 3). Shop nel cantiere, anteprima live sulla barca attraccata.
- [ ] Menu principale e impostazioni complete (pausa base fatta in M1: riprendi/ricomincia/fullscreen/esci)
  - Scena title con la baia sullo sfondo; impostazioni: volumi (master/musica/sfx), fullscreen, sensibilità mouse camera, azzeramento salvataggio con conferma.
- [ ] Audio: mare, motore, UI, un tema musicale
  - Bus master/musica/sfx. Loop mare con volume/pitch legati all'agitazione locale, motore legato a gas e velocità, suoni UI per raccolte/vendite/allarmi. Asset CC0 (Kenney Audio, freesound) registrati in `assets/CREDITS.md`.
- [ ] Feedback d'impatto (flash barra scafo, scuotimento camera)
  - Flash rosso sulla barra scafo a ogni danno, shake camera proporzionale alla forza d'urto (`@export` intensità/durata), spruzzo/suono all'impatto.
- [ ] Traguardo di fine beta (acquisto del primo cabinato) e schermata finale provvisoria
  - All'acquisto del Cabinato: schermata "fine beta" con statistiche di partita (tempo, denaro totale guadagnato, pesci, vittorie) e ringraziamento; poi si continua a giocare liberamente.
- [ ] Bilanciamento complessivo + bug pass
  - Passata su prezzi/premi/valori con un foglio dei tempi-per-upgrade (quanti minuti servono per ogni acquisto); sessione di playtest completa dall'inizio annotando attriti.
- [ ] Export macOS/Windows, pagina itch.io (privata) per distribuire la build
  - Preset export nei due OS (icona, nome), test su macchina pulita, pagina itch.io privata con chiave per i tester.
- [ ] **Criterio di uscita**: un estraneo la gioca dall'inizio al traguardo senza aiuto
