# Roadmap

Regola: una milestone è chiusa solo quando Stefano l'ha giocata e approvata. Non si apre la successiva prima.

*Storia: M0 (game feel) → M1 (mondo e loop) → M2 (progressione) → M2.5 (la costa di Bova) → M3 (missioni, gare, pesca) sono completate. Completati anche i contenuti di A1/A2 (missioni dai porti, eventi con scelta, reputazione, vernici e accessori, menu dei mondi, impostazioni, traguardo di fine alpha), B0 (predisposizioni architetturali: Vessel, Diplomacy, Damageable/Weapon, world_state, Port parametrico), B1 (cannone a mira libera, mercantili e predoni, bottino galleggiante, feedback d'impatto) e B2 (slot di costruzione, prosperità di Bova, flottiglia di pesca, produzione a tick) e le prime due tranche di B4 (mappa 5200×4000, Catania e Il Cairo come coste modellate ostili, scali di rifornimento, minimappa a due viste, mondi di prova) — il dettaglio vive nella cronologia git di questo file.*

---

# ALPHA — code da chiudere

- [ ] **Criterio di uscita A1**: una sessione da 20 minuti offre almeno 3 attività diverse sensate
	- *Da verificare in gioco: leggibilità del pacco di recupero e del marker ambra; tempi limite di consegna (`MISSION_DELIVERY_SPEED`); frequenza e tono degli eventi; entità di sconti/rincari da reputazione.*
- [ ] **Verifiche playtest arretrate** (accumulate nei "da verificare in gioco")
	- Criteri di uscita mai validati: la seconda barca è desiderabile e guadagnarsela soddisfa (M2); la baia si legge a colpo d'occhio e sembra Bova Marina (M2.5).
	- Performance e sfumatura del piano mare esteso al confine sud; posizioni dei 6 checkpoint della gara al largo; posizione NPC/rescue_point e leggibilità del cerchio radar; leggibilità icone inventario; mix volumi, timbro motore/mare, gusto dei brani, tick sugli avvisi.
	- Da A2: prezzi/gusto di vernici e accessori (proporzioni sui tre modelli); leggibilità del title sopra la baia; escursione dello slider sensibilità; leggibilità delle righe del menu mondi, focus/navigazione con le frecce, doppio caricamento su Continua (se pesa, si ottimizza).
- [ ] **Bilanciamento complessivo + bug pass**
	- Foglio dei tempi-per-upgrade pronto in `docs/BALANCE.md` (prezzi reali + stime $/min da validare). Resta la sessione di playtest completa dall'inizio annotando attriti, poi la passata sui valori.
- [ ] **Export macOS/Windows, pagina itch.io (privata)** per distribuire la build ai tester
	- `export_presets.cfg` pronto. Restano: installare gli export template 4.7 nell'editor, lanciare i due export, creare la pagina itch.io privata e caricare le build (serve l'account di Stefano).
- [ ] **Criterio di uscita**: un estraneo la gioca dall'inizio al traguardo senza aiuto

---

# BETA — il gestionale d'azione: "Bova è casa"

## Visione

> Bova Marina è casa tua: la fai crescere, la difendi, e il mare la nutre. Salpi per predare navi in mare aperto, commerci o fai guerra con città lontane, e ogni ricchezza che porti a casa **si vede**: il paese cresce, si illumina, si fortifica. Torni sempre a casa — ma il gioco si vive in mare.

Il gestionale è **incarnato**: niente fogli di calcolo, la barca resta l'avatar di tutto. Le attività dell'alpha (pesca, boe) si **automatizzano** con la crescita di Bova — flottiglie che lavorano per te — e il giocatore sale di ruolo: da pescatore a comandante. Riferimenti: Dave the Diver (loop azione + meta gestionale), Sid Meier's Pirates! (preda e diplomazia), il feedback visivo dei city builder.

**Tono**: fantasia leggera stilizzata, arcade spensierato — nello spirito di un Risiko. Le fazioni di mare (predoni, mercanti) restano immaginarie; le due città lontane portano nomi reali di piazze mediterranee (**Catania**, **Il Cairo**) — scelta di Stefano (23/07/2026): con questa grafica stilizzata sono caselle di gioco, non un aggancio politico. La fonte di verità del tono resta il GDD.

## Decisioni di design

Fissate il 22/07/2026:

| Tema | Decisione |
|---|---|
| Baricentro | Gestionale incarnato: la barca resta il loop attivo, il gestionale è il meta-layer |
| Mondo | **Mappa unica allargata**: un solo mare continuo, le città sono fisicamente lontane, ci si naviga in tempo reale (il viaggio è gioco: carburante, meteo, incontri) |
| Combattimento | **Mira libera col mouse**: mirino sulla camera orbitale esistente, spari dove guardi |
| Difesa di Bova | **Tempo reale con preavviso**: allarme → l'attacco arriva dopo X minuti → puoi rientrare a difendere; le difese costruite combattono comunque |
| Attività alpha | **Si automatizzano**: flottiglie di pesca/raccolta passive sbloccate dalla crescita di Bova; il giocatore fa azione, la base genera economia |
| Costruzione | **Slot predefiniti** disegnati a mano su costa e isole: scegli cosa costruire lì, non dove — la baia resta bella e leggibile |
| Città lontane | **2 nella beta**, coste modellate: **Catania** a sud-ovest (vicina) e **Il Cairo** a sud-est (lontana), **entrambe ostili all'inizio**: la diplomazia le apre. Scali di rifornimento neutrali riempiono la traversata |
| Diplomazia | **Solo col giocatore**: relazione per città (estende la reputazione dell'alpha); le rivalità tra città sono raccontate, non simulate |
| Fine beta | **Doppio traguardo**: Bova al massimo splendore E ogni città risolta (alleata o sottomessa) |

Fissate il 23/07/2026 (feedback del direttore):

| Tema | Decisione |
|---|---|
| Camera | Orbita **solo col tasto destro premuto**; rilasciato, ritorno morbido dietro la poppa. In combattimento il ritorno automatico è **sospeso** |
| Missioni attive | **Una alla volta va bene**: è l'interfaccia a mancare — tracker sempre visibile con counter n/N e completamenti celebrati |
| Direzione di gioco | **Gestionale d'azione**: più tipi di item, missioni raccogli-e-consegna per NPC in cambio di denaro e item rari — è il **motore del B4 restante** (accordi/missioni di Catania e Il Cairo) |
| Terraferma | **Esplorazione in prima persona ovunque**, ma si parte da un prototipo su Bova |

## Criteri di uscita aperti di B1/B2

- [ ] **B1**: inseguire e predare un mercantile è divertente quanto vincere una regata
	- *Da verificare in gioco: mira e arco del proiettile (gravità 18, tempo minimo di volo); posizione/proporzioni del cannone sui tre modelli; velocità e aggressività del predone (aggro 95 m, speronata 12); fuga del mercantile; valori del bottino vs boe blu; leggibilità di mirino e barra salute; suono del cannone.* → R1 attacca direttamente mirino e camera.
- [ ] **B2**: si distingue a colpo d'occhio una Bova povera da una ricca, e viene voglia di arricchirla
	- *Da verificare in gioco: leggibilità dei cartelli-lotto e degli edifici; posizioni degli slot; ritmo dei tick e valori di pesce/conserve; soglie di prosperità (120/300/560/900 punti); l'effetto del faro; il colpo d'occhio povera → ricca.*

## R — Rifiniture dal feedback del 23/07/2026

*R1-R4 (sessioni di codice, ognuna chiusa con build giocabile) e R5 (design) completate — restano i "da validare in playtest". Dalla sessione di design sono nate R6 e R7, da fare prima di riprendere B3/B4.*

### R1 — Combattimento e camera

- [x] **Mirino e sparo — sistema definitivo** (analisi Fable 5 + ricerca su WoWs/Sea of Thieves/artillery games): balistica a **modello d'artiglieria** in `cannonball.gd::launch_velocity` (velocità fissa `projectile_speed`, risolve l'angolo d'alzo teso per centrare il punto; fuori portata → 45°; `can_reach` dice se il punto è balisticamente raggiungibile). `projectile_speed` alzate (40/44/48 giocatore, 36 predone) perché `fire_range` (60/75/90/50) fosse dentro la gittata balistica `v²/g` con margine (~teso a fondo gittata). **Regola d'oro**: non si mira mai a mezz'aria — `_solve_aim` spara sempre verso un punto su una superficie. Mirino sdoppiato (`crosshair.gd`): **puntatore** (rombo = dove punti, segue sempre, mai bloccato all'orizzonte) + **marker** veritiero (dove cade davvero la palla, simulato Euler semi-implicito). Cielo/oltre gittata → la mira **satura al limite di gittata sull'acqua** (niente lob verticale), marker rosso + chevron + filo tratteggiato al puntatore ("punti lì → cadi qui"). **Pip d'anticipo** azzurro sulle navi in moto (indicazione, non auto-mira). La palla parte dalla bocca vera. *Da validare in playtest.*
- [x] **Camera: modalità mira col tasto destro — reticolo libero** (azione `camera_orbit` = tasto destro): il mouse muove una **direzione di mira** slegata dal centro schermo (`_aim_yaw`/`_aim_pitch` in `chase_camera.gd`); la camera la insegue in orizzontale (pan) ma **resta sempre alta** (l'altezza non dipende più dalla mira → niente vista bassa). Mirando in su il **reticolo sale sui bersagli alti** (coste, città, navi): il cannone spara lungo `aim_ray()`, non più dal centro schermo. FOV/arretramento in mira via `aim_fov`/`aim_zoom`; limiti mira `aim_pitch_up_deg`/`aim_pitch_down_deg`; inclinazione vista `aim_view_gain`. Rilasciato il destro, tutto torna dietro la poppa (guida = vista normale). *Riscrittura post-feedback Stefano: da "camera-mira" a reticolo libero navale.*
- [x] **Camera più alta in orizzontale**: alzati i default `@export` (`min_height` 2.0, `height` 5.5, `look_height` 1.7); in mira sale ancora con `aim_zoom`/`aim_pitch_min_deg`. *Taratura fine in playtest con Stefano.*
- [x] **Fumo scafo danneggiato**: due `CPUParticles3D` sul corpo barca (`boat.gd::_build_smoke`, pilotati da `hull_changed`): fumo grigio sotto `smoke_threshold` (0.5), nero + scintille sotto `heavy_smoke_threshold` (0.33), soglie `@export`. Quota di coperta dalla `BoatDefinition`. *Navi IA: rinviato (richiede toccare la scena nave).*
- [x] **Gli eventi casuali fermano il tempo**: `EventDirector` ora fa `get_tree().paused = true` al trigger (CanvasLayer `EventUI` in `process_mode` ALWAYS, così i pulsanti restano attivi) e lo rilascia alla scelta — il timer consegne è pausable, quindi non scorre più sotto l'evento.
- [ ] **Criterio di uscita**: mirare è preciso e prevedibile, la camera non ti strappa mai la mira di mano, e un duello col predone si legge tutto (fumo compreso)

### R2 — HUD 2.0 (un solo ridisegno coerente)

*L'angolo basso-sinistra oggi ospita minimappa + box mare + chip stiva posizionati l'uno relativo all'altro (`hud.gd::_position_bottom_left`): spostare la minimappa impone di ridisegnare il layout intero, e si fa in un colpo solo.*

- [x] **Minimappa in alto a destra**, più grande e più chiara: compatta spostata top-right (`minimap.gd::_apply_layout`), `small_height` 190→240. Celle di vento ora leggibili — da quasi-nere (`WIND_COLOR` 0.03,0.07,0.16) a azzurro chiaro con anello marcato + anello interno "increspato". *Da validare in playtest.*
- [x] **Toast di raccolta in basso a destra** (`hud.gd::_push_toast`): stack (pastiglia colore + nome + valore) alimentato dai segnali granulari — boe, pesci, loot, taniche (nuovo segnale `fuel_collected`), denaro (`cargo_sold`). Comparsa/attesa/dissolvenza in tween, tetto `MAX_TOASTS`. La `NoticeLabel` centrale resta solo per avvisi di gioco. *Da validare in playtest.*
- [x] **Tracker missione centro-destra** (`hud.gd::_rebuild_mission_tracker`): pannello sempre visibile — titolo, tappa, progresso, countdown consegna (⏱, rosso sotto 30 s) — al posto del testo nel `GoalBox`. Completamento celebrato: pop centrale (`_on_mission_completed`, nuovo segnale `mission_completed`) + fanfara (`chime` in `audio.gd`). Costruito come **lista** (dati da `GameState::active_missions()`), pronto per le missioni NPC di R5. *Da validare in playtest.*
- [x] **Carta nautica (M) navigabile** (`minimap.gd`): rotella = zoom verso il cursore (`_zoom_chart`), sinistro trascina = pan (`_chart_center`), **C** ricentra sulla barca; mouse rilasciato all'apertura e ricatturato in chiusura. Indicatore giocatore grande e pulsante (16 px + alone). Zoom 1×–9× (`@export`). *Da validare in playtest.*
- [x] **Meteo onesto** (`hud.gd::_update_sea_state`): l'indicatore principale è ora lo **stato locale** del mare (`sea.agitation`, soglie `SEA_STATE_STEPS`), non più il globale `Weather`. Entrando in acque da danno (`boat.storm_damage_threshold`) lampeggia un allarme rosso "⚠ TEMPESTA". Zona come contesto secondario. *Da validare in playtest.*
- [ ] **Criterio di uscita**: si naviga 10 minuti senza mai chiedersi "dove sono, cosa sto facendo, perché sto prendendo danni"

### R3 — Il mare aperto più ricco

- [x] **Boe rosse anche al largo**: banda di rosse in mare aperto come riempitivo tra le blu (`world.gd::_spawn_zone_buoys`, nuovo `@export open_red_point_count = 14`, stessa fascia delle blu `medium_width+15 → bay_depth-60` con `scatter_half_width_open`). Verificato: spingersi fuori non è più un vuoto di raccolta. *Da tarare in playtest (densità).*
- [x] **Zone attività randomiche al largo**: due leve, entrambe randomizzate col `_mission_rng` (non il seed fisso), quindi **posizioni nuove a ogni partita**. (1) `_spawn_open_activity_zones` semina `open_activity_zones = 2` zone di pesca tier 2 nel largo profondo. (2) `RaceCourse` reso **spawnabile**: flag `procedural` + `_generate_checkpoints` genera l'anello di cancelli attorno all'origine da `proc_seed` (traguardo sulla linea di partenza); `world.gd::_spawn_open_races` ne semina `open_race_count = 1` in un punto casuale del largo, IA aggressive, premio scalato dal fattore difficoltà. Verificato headless: spot procedurale a ~575 m dalla costa, premio 2.2×, minimappa/gara funzionanti. *La "rigenerazione a giorno di gioco" (in-partita) resta per un ciclo giorno/notte futuro.*
- [x] **Ricompense per acque difficili**: `GameState::difficulty_multiplier(world_pos, sea)` — fattore continuo 1.0 → `DIFFICULTY_REWARD_MAX` (2.0) da distanza oltre le acque medie (peso 0.6) + agitazione locale `sea.agitation` incluse le celle di vento (peso 0.4), costanti in GameState. Applicato dove il premio ha posizione nota senza toccare il modello stiva/vendita: **bottino** (più casse dalle prede affondate lontano e col mare grosso, `ship.gd::_drop_loot`) e **regate al largo** (prize_multiplier scalato allo spawn). Boe/pesca scalano già per collocazione (rosse al largo, zone tier 2). *Il fattore continuo sul valore di boe/pesce arriva col modello item generico di R4.*
- [x] **Upgrade recupero radar "Condensatori"**: terza voce `RadarUpgrade.COOLDOWN` (pattern Antenna/Ricevitore). `RADAR_COOLDOWN` fisso → `RADAR_COOLDOWN_STEPS = [60, 45, 30, 20, 15]`, `radar_cooldown()` funzione del livello (usata da `radar.gd::ping`), costi 500/1000/1900/3200 $. Bottone "Condensatori" nel negozio di Zu' Vito (`rescue_npc`). Verificato: cooldown 60 → 45 al primo livello, roundtrip di salvataggio ok.
- [ ] **Criterio di uscita**: spingersi al largo col mare grosso è una scelta golosa, non solo rischiosa

### R4 — Inventario generico (fondazione della direzione item)

*Fatto: i quattro dizionari dedicati (`cargo`, `fish_cargo`, `loot_cargo`, `mission_crates`) e le costanti parallele di valore/nome/colore sono confluiti in un catalogo `ItemDefinition` + un inventario unico. Aggiungere un item ora è un solo `.tres`.*

- [x] **`ItemDefinition` (Resource)** (`scripts/item_definition.gd`): id, nome/plurale, valore base, categoria (`BUOY`/`FISH`/`LOOT`/`GOODS`/`MISSION`), colore e forma dell'icona (`BUOY`/`FISH`/`CRATE`), vendibile sì/no. Un `.tres` per item in `resources/items/` — 11 item (3 boe, 4 pesci, 3 bottini, cassa missione). Catalogo in `GameState.ITEM_DEFS`; gli enum di gameplay (spawn boe, specie di pesca, tier del bottino) restano e si agganciano all'item con le mappe `BUOY_ITEM`/`FISH_ITEM`/`LOOT_ITEM`.
- [x] **Inventario unico in GameState**: `inventory: Dictionary[StringName, int]` al posto dei quattro contenitori (le casse missione sono l'item non vendibile `mission_crate`). Rifatti `collect_*`, `cargo_count`, `cargo_value` (solo item vendibili), `sell_cargo`/`_clear_sellable`, `cargo_detail_bbcode` (dal catalogo), salvataggio (chiave `inventory`) e **migrazione retrocompatibile** (`_migrate_legacy_cargo`: i mondi pre-R4 confluiscono senza perdere niente — verificato headless).
- [x] **Pannello inventario a griglia unica** (`inventory_panel.gd`): sezioni costruite dal catalogo per categoria, bottino e casse missione finalmente visibili (icona a baule); toast (R2), porto e minimappa leggono anch'essi l'`ItemDefinition`. *Da validare in playtest.*
- [x] **Criterio di uscita**: aggiungere un item nuovo = un file `.tres`, e appare ovunque (stiva, toast, vendita, missioni). *Da validare in playtest con Stefano.*

### R5 — Sessione di design con Stefano (niente codice prima)

*Svolta il 24/07/2026 — decisioni fissate qui sotto, design esteso in `docs/GDD.md` § Beta.*

- [x] **Catalogo item nuovi**: ~8-10 item — 4-6 merci comuni (materiali e commercio) + 3-4 tesori rari, con **doppio ruolo**: le merci sono ingredienti di costruzione (edifici/difese costano soldi + materiali), i tesori la moneta delle missioni NPC. Fonti: **tutte e quattro** — relitti semisommersi al largo (casse galleggianti, visibili al radar), isolette da sbarco (raccolta a piedi), prede navali con merci vere (tipiche della città di provenienza), pesca speciale nelle acque difficili (anfore, perle).
- [x] **Sistema missioni NPC**: datori **solo NPC fisici a terra** — niente bacheche né menu porto; lo sbarco è quindi prerequisito delle missioni. Ogni datore offre **2-3 richieste**, una sola attiva alla volta (tracker di R2). Ricompense: mix di denaro, item rari, reputazione e sblocchi unici (progetti di difesa, accessi). Città lontane: **catene scritte a mano di 4-6 tappe** per città che scandiscono la diplomazia ostile → neutrale → alleata.
- [x] **Prima persona**: sbarco al **molo e sulle spiagge basse** (prompt dove l'acqua è bassa), rientro alla barca allo stesso modo. V1 su Bova: 2-3 NPC datori con dialogo a riquadro, item raccoglibili a terra, ingresso nell'arsenale, il paese che mostra la prosperità da vicino. Sequenza: **prototipo su Bova → sbarco in città e scali → missioni B4**.
- [x] **Arsenale di B3**: edificio fisico a Bova in cui si entra a piedi; dentro, la mappa della baia con **slot difensivi dedicati** (promontori, imboccatura della rada, isolotti). Catalogo completo: torre d'avvistamento, batteria costiera, scogli/ostacoli, pattuglia alleata. Costi in **soldi + materiali**; le difese avanzate si sbloccano come **progetti** dalle catene NPC.

*Ordine di lavoro risultante: R6 (item e fonti in mare) → R7 (prima persona su Bova) → B3 (difese e attacchi) → sbarco nelle città (in B4) → catene di missioni e diplomazia di B4.*

### R6 — Item e fonti in mare

*Prima tranche della direzione item decisa in R5. Si appoggia tutta sull'inventario generico di R4: ogni item nuovo è un `.tres`.*

- [x] **Nuovi `ItemDefinition`**: 6 merci (legno 20 $, stoffa 30, ferro 45, agrumi di Catania 55, datteri del Cairo 65, spezie 70 — categoria `GOODS`) e 4 tesori (anfora antica 240, perla 320, carta nautica antica 450, statuetta dorata 600 — nuova categoria `TREASURE`, sezione "Tesori" nell'inventario). Icone procedurali nuove in `item_icon.gd` (sacco, anfora, perla in conchiglia, rotolo con rotta, statuetta). *Nomi/valori proposti sui prezzi esistenti (boa rossa 40, blu 150, tonno 250): da validare con Stefano in playtest, si ritoccano nei `.tres`.*
- [x] **Relitti semisommersi al largo** (`scenes/world/wreck.gd`): 2 nel mare aperto della baia + 3 sulla traversata, posizioni casuali a ogni partita (`_mission_rng`), rivelati dal radar (✕ color legno in minimappa, voce in legenda, smorzata a saccheggio avvenuto). Sotto i 45 m il carico affiora: 4-6 casse `LootCrate` in anello — merci dal pool relitti, tesoro con probabilità 0.1→0.4 scalata da `difficulty_multiplier`. La cassa generica ora porta un item per id (coperchio del colore dell'item, i tesori luccicano).
- [x] **Prede con merci vere**: metà delle casse mollate è merce dal `goods_pool` della `ShipDefinition` (mercantile: legno/ferro/stoffa/spezie; predone: stoffa/spezie); le navi con fazione di città portano al 60% la merce tipica di casa (`FACTION_GOODS`: Catania → agrumi, Il Cairo → datteri).
- [x] **Pesca speciale**: nelle zone tier 2 una cattura può tirare su anfore o perle — probabilità 0 → 0.25 scalata dal fattore difficoltà del punto (`fishing_treasure_chance`), campanellino della boa blu al colpo. Segnale generico `item_collected` per toast e audio di tutti gli item per id.
- [ ] *Le isolette da sbarco (quarta fonte decisa in R5) arrivano dopo R7: servono i piedi a terra*
- [ ] **Criterio di uscita**: una battuta al largo riempie la stiva di roba nuova e varia, e si capisce a colpo d'occhio cosa vale e dove rivenderla
	- *Da verificare in gioco: valori delle merci vs boe/pesci; densità dei relitti e raggio di scoperta; quota merci/bottino delle prede (50%); frequenza tesori in pesca (max 25%); leggibilità di casse colorate, icone nuove e ✕ del relitto in minimappa.*

### R7 — Prima persona: prototipo su Bova

*Architettura pensata per sbarcare ovunque poi (città, scali, isolette); si valida tutto su Bova prima di estendere.*

- [ ] **Sbarco e rientro**: prompt al molo e sulle spiagge basse (dove l'acqua è bassa), la barca resta dov'è; stesso prompt per risalire a bordo
- [ ] **Controller a piedi**: WASD + mouse, camera in prima persona, niente salto/arrampicata nella v1
- [ ] **2-3 NPC datori** con dialogo a riquadro e 2-3 richieste ciascuno: la v1 del sistema missioni NPC (raccogli-e-consegna, ricompense miste), mostrata dal tracker di R2
- [ ] **Item raccoglibili a terra** (casse, ceste sparse nel paese): il seme delle isolette da sbarco
- [ ] **L'edificio arsenale** sul molo: ci si entra (la mappa delle difese dentro arriva con B3)
- [ ] **Il paese da vicino**: la prosperità di B2 si legge anche a piedi (dettagli, luci, gente per livello)
- [ ] **Criterio di uscita**: attraccare, girare il paese, accettare una missione e ripartire è naturale e senza attriti — e viene voglia di scendere a terra

## B3 — Difendere casa

*Design fissato in R5 (24/07/2026): l'**arsenale** è un edificio fisico a Bova in cui si entra a piedi (prima persona) — dentro, la mappa della baia con **slot difensivi dedicati** disegnati a mano (promontori, imboccatura della rada, isolotti), separati dagli slot di costruzione di B2. Costi in soldi + materiali del catalogo item; le difese avanzate arrivano come **progetti** sbloccati dalle catene NPC. Prerequisito: il prototipo prima persona su Bova.*

- [ ] **Difese costruibili** negli slot dedicati: torre d'avvistamento (allunga il preavviso), batteria costiera (spara con `Weapon`), **scogli/ostacoli** semisommersi che danneggiano/rallentano le navi in rotta d'attacco, pattuglia (nave `Vessel` alleata in rada)
- [ ] **Attacchi dei predoni**: allarme (campana + HUD + marker minimappa) → i predoni arrivano dopo X minuti → le difese combattono da sole, il giocatore può rientrare e fare la differenza
- [ ] Se l'attacco riesce: **razzia** — prosperità e magazzino calano, nessun game over (la progressione non si cancella, come per l'affondamento)
- [ ] Frequenza/forza degli attacchi scalate sulla ricchezza di Bova (più sei ricco più fai gola) e sulle provocazioni (vedi B4)
- [ ] **Criterio di uscita**: sentire la campana e correre a casa è un momento di tensione vera, non una seccatura

## B4 — Il mare grande e le due città

*Prime due tranche fatte (23/07/2026): mappa grande, Catania e Il Cairo come coste modellate ostili, scali di rifornimento, traversata densificata, tre mondi di prova — dettaglio nella cronologia git. Restano diplomazia attiva, commercio e guerra; le missioni delle città si costruiranno sul sistema item+NPC di R5.*

- [ ] **Diplomazia solo col giocatore**: relazione -100..+100 per città (estende la reputazione di A1); predare le sue navi la peggiora, missioni e accordi la migliorano; soglie leggibili (alleata / neutrale / ostile / in guerra)
	- *Predisposto*: fazioni `catania`/`cairo` in GameState (relazioni iniziali -40, salvate), navi marchiate con la fazione, `Diplomacy` già a soglie. *Resta*: far muovere la relazione da predazioni/missioni/accordi e mostrarla.
- [ ] **Sbarco in città e scali**: la prima persona di R7 portata a Catania, Il Cairo e agli scali di rifornimento (banchina percorribile, NPC datori al porto) — prerequisito delle catene di missioni
- [ ] **Accordi, prezzi e missioni delle città**: catene raccogli-e-consegna scritte a mano (4-6 tappe per città, sistema di R5) date da **NPC fisici a terra**; aprono i porti e migliorano i prezzi; razzie e blocchi navali dal lato ostile
- [ ] **Commercio**: accordi che aprono rotte automatizzate (le tue navi mercantili viaggiano visibili sulla rotta e rendono passivamente — e sono attaccabili: da difendere o scortare)
- [ ] **Guerra**: attaccare il porto nemico (difese sue speculari alle tue), rappresaglie su Bova, fino alla sottomissione (tributo o cessate il fuoco)
- [ ] **Criterio di uscita**: scegliere tra la via del mercante e quella del corsaro cambia davvero la partita
- [ ] *Le città interagiscono solo col giocatore nella beta; simulazione città-vs-città in BACKLOG*
- [ ] *Da verificare in gioco (tranche fatte)*: durata e noia della traversata (distanza città, `compact_span` della minimappa); consumo carburante sul viaggio (il gommone non ce la fa andata e ritorno: giusto così?); frequenza/forza di celle di vento e danni tempesta in mare aperto; l'arrivo in città (la nebbia a 650 m nasconde la costa fino all'ultimo: serve un faro/landmark visibile prima?); tono dei due porti ostili e dei predoni di pattuglia; leggibilità delle coste modellate e delle personalità cromatiche; gli scali di rifornimento (posizione, che si capisca che lì si vende/rifornisce); densità della traversata; i tre mondi di prova nel menu.

## B5 — Chiusura beta

- [ ] **Doppio traguardo**: Bova all'ultimo livello di prosperità e difese **E** entrambe le città risolte (alleata o sottomessa) → schermata finale con statistiche
- [ ] Bilanciamento complessivo del meta (tempi di crescita, rendimenti passivi vs attivi, curva degli attacchi)
- [ ] Onboarding del gestionale (le tappe guidate esistenti si estendono: primo edificio, prima difesa, primo viaggio lontano)
- [ ] **Criterio di uscita**: un estraneo gioca dall'alpha alla fine della beta capendo da solo quando pescare, quando predare, quando costruire
