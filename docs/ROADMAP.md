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

*Priorità corrente: quattro sessioni (ognuna chiusa con build giocabile) prima di riprendere B3/B4, poi una sessione di design. Analisi tecnica fatta: ogni punto sotto ha causa/aggancio già individuati nel codice.*

### R1 — Combattimento e camera

- [x] **Mirino e sparo — sistema definitivo** (analisi Fable 5 + ricerca su WoWs/Sea of Thieves/artillery games): balistica a **modello d'artiglieria** in `cannonball.gd::launch_velocity` (velocità fissa `projectile_speed`, risolve l'angolo d'alzo teso per centrare il punto; fuori portata → 45°; `can_reach` dice se il punto è balisticamente raggiungibile). `projectile_speed` alzate (40/44/48 giocatore, 36 predone) perché `fire_range` (60/75/90/50) fosse dentro la gittata balistica `v²/g` con margine (~teso a fondo gittata). **Regola d'oro**: non si mira mai a mezz'aria — `_solve_aim` spara sempre verso un punto su una superficie. Mirino sdoppiato (`crosshair.gd`): **puntatore** (rombo = dove punti, segue sempre, mai bloccato all'orizzonte) + **marker** veritiero (dove cade davvero la palla, simulato Euler semi-implicito). Cielo/oltre gittata → la mira **satura al limite di gittata sull'acqua** (niente lob verticale), marker rosso + chevron + filo tratteggiato al puntatore ("punti lì → cadi qui"). **Pip d'anticipo** azzurro sulle navi in moto (indicazione, non auto-mira). La palla parte dalla bocca vera. *Da validare in playtest.*
- [x] **Camera: modalità mira col tasto destro — reticolo libero** (azione `camera_orbit` = tasto destro): il mouse muove una **direzione di mira** slegata dal centro schermo (`_aim_yaw`/`_aim_pitch` in `chase_camera.gd`); la camera la insegue in orizzontale (pan) ma **resta sempre alta** (l'altezza non dipende più dalla mira → niente vista bassa). Mirando in su il **reticolo sale sui bersagli alti** (coste, città, navi): il cannone spara lungo `aim_ray()`, non più dal centro schermo. FOV/arretramento in mira via `aim_fov`/`aim_zoom`; limiti mira `aim_pitch_up_deg`/`aim_pitch_down_deg`; inclinazione vista `aim_view_gain`. Rilasciato il destro, tutto torna dietro la poppa (guida = vista normale). *Riscrittura post-feedback Stefano: da "camera-mira" a reticolo libero navale.*
- [x] **Camera più alta in orizzontale**: alzati i default `@export` (`min_height` 2.0, `height` 5.5, `look_height` 1.7); in mira sale ancora con `aim_zoom`/`aim_pitch_min_deg`. *Taratura fine in playtest con Stefano.*
- [x] **Fumo scafo danneggiato**: due `CPUParticles3D` sul corpo barca (`boat.gd::_build_smoke`, pilotati da `hull_changed`): fumo grigio sotto `smoke_threshold` (0.5), nero + scintille sotto `heavy_smoke_threshold` (0.33), soglie `@export`. Quota di coperta dalla `BoatDefinition`. *Navi IA: rinviato (richiede toccare la scena nave).*
- [x] **Gli eventi casuali fermano il tempo**: `EventDirector` ora fa `get_tree().paused = true` al trigger (CanvasLayer `EventUI` in `process_mode` ALWAYS, così i pulsanti restano attivi) e lo rilascia alla scelta — il timer consegne è pausable, quindi non scorre più sotto l'evento.
- [ ] **Criterio di uscita**: mirare è preciso e prevedibile, la camera non ti strappa mai la mira di mano, e un duello col predone si legge tutto (fumo compreso)

### R2 — HUD 2.0 (un solo ridisegno coerente)

*L'angolo basso-sinistra oggi ospita minimappa + box mare + chip stiva posizionati l'uno relativo all'altro (`hud.gd::_position_bottom_left`): spostare la minimappa impone di ridisegnare il layout intero, e si fa in un colpo solo.*

- [ ] **Minimappa in alto a destra**, più grande e più chiara: meno rumore, porti/marker prioritari, celle di vento leggibili (vedi meteo sotto).
- [ ] **Toast di raccolta in basso a destra**: stack di notifiche (icona + nome + valore) per ogni pickup — boe, pesci, loot, taniche, casse, denaro. I segnali granulari esistono già in GameState (`buoy_collected`, `fish_caught`, `loot_collected`, …): oggi passano tutti dall'unica `NoticeLabel` centrale. La label centrale resta solo per avvisi di gioco (tempesta, missione fallita, stiva piena).
- [ ] **Tracker missione centro-destra**: pannello sempre visibile con la missione attiva — titolo, counter n/N (casse consegnate, progresso recupero), countdown consegna — al posto del testo nel `GoalBox` centro-alto. Completamento celebrato (animazione + suono, non solo un toast). Costruito come **lista** anche se oggi la missione è una sola: pronto per le missioni NPC di R5.
- [ ] **Carta nautica (M) navigabile**: zoom con rotella, pan trascinando, tasto per ricentrare sulla barca; indicatore giocatore grande e pulsante (oggi triangolo da 11 px su 5,2 km di mappa). Tutto in `minimap.gd` (`_view_rect`/`_apply_layout` già parametrici).
- [ ] **Meteo onesto**: il label "Mare mosso/calmo" legge solo lo stato globale di `Weather`, ma il pericolo vero è `sea.agitation` locale (zona × meteo × **celle di vento**): oggi puoi prendere danni da tempesta con l'HUD che dice "calmo". L'indicatore principale diventa lo **stato locale** (soglie `SEA_STATE_STEPS` già in `hud.gd`), con allarme visivo entrando in acque da danno (`storm_damage_threshold`); le celle di vento diventano leggibili in minimappa e carta nautica (oggi macchie scure quasi invisibili).
- [ ] **Criterio di uscita**: si naviga 10 minuti senza mai chiedersi "dove sono, cosa sto facendo, perché sto prendendo danni"

### R3 — Il mare aperto più ricco

- [ ] **Boe rosse anche al largo**: oggi lo spawn è a fasce rigide (`world.gd::_spawn_zone_buoys`: gialle in acque calme, rosse in medie, blu in aperto). Aggiungere una banda di rosse in mare aperto come riempitivo tra le blu (conteggio `@export`).
- [ ] **Zone attività randomiche al largo**: le zone di pesca sono già procedurali per fascia — estenderle al largo profondo con **rigenerazione periodica** (posizioni nuove a ogni partita/giorno di gioco); le **regate sono fisse in scena** → rendere `RaceCourse` spawnabile in punti casuali del largo (checkpoint generati attorno al punto).
- [ ] **Ricompense per acque difficili**: le ricompense scalano già per fascia (missioni, loot, pesca, gare) — aggiungere un fattore **distanza dalla costa + agitazione locale** (`sea.agitation`) sulle attività, così i punti più lontani e più mossi rendono di più (GDD pillar 2). Costanti in GameState, non nei nodi.
- [ ] **Upgrade recupero radar**: nuova voce nella famiglia radar esistente (`RadarUpgrade`, pattern Antenna/Ricevitore) — es. "Condensatori": cooldown 60 → 45 → 30 → 20 → **15 s**, prezzi indicativi 500/1000/1900/3200 $ (oggi `RADAR_COOLDOWN = 60.0` fisso in GameState; va reso funzione del livello).
- [ ] **Criterio di uscita**: spingersi al largo col mare grosso è una scelta golosa, non solo rischiosa

### R4 — Inventario generico (fondazione della direzione item)

*Oggi ogni categoria ha il suo dizionario dedicato in GameState (`cargo`, `fish_cargo`, `loot_cargo`, `mission_crates`) con costanti e rami UI paralleli: aggiungere un item nuovo tocca 8 punti. E il loot non compare nemmeno nel pannello inventario.*

- [ ] **`ItemDefinition` (Resource)**: id, nome/plurale, valore base, categoria (boa/pesce/bottino/merce/missione), icona/colore, vendibile sì/no. Un `.tres` per item in `resources/items/` — item nuovi senza toccare codice.
- [ ] **Inventario unico in GameState**: `Dictionary[StringName, int]` al posto dei quattro contenitori; refactor di `collect_*`/`cargo_count`/`cargo_value`/`sell_cargo`/`cargo_detail_bbcode` su ItemDefinition. **Migrazione salvataggi retrocompatibile** (i mondi esistenti non si perdono niente).
- [ ] **Pannello inventario a griglia unica** per categoria, loot e casse missione finalmente visibili; toast (R2) e tracker già pronti a mostrare qualsiasi item.
- [ ] **Criterio di uscita**: aggiungere un item nuovo = un file `.tres`, e appare ovunque (stiva, toast, vendita, missioni)

### R5 — Sessione di design con Stefano (niente codice prima)

*Da preparare con proposte concrete, decidere insieme:*

- [ ] **Catalogo item nuovi**: quali merci/tesori/materiali, dove si trovano (relitti, isole, prede, fondali), rarità.
- [ ] **Sistema missioni NPC** (raccogli-e-consegna): NPC che chiedono N item in cambio di denaro, item rari o reputazione. È il **motore del B4 restante**: le missioni/accordi di Catania e Il Cairo diventano catene di raccolta-consegna che muovono la diplomazia. Tracker di R2 già pronto a mostrarle.
- [ ] **Prima persona**: prototipo su **Bova** (sbarco al molo, si gira il paese, 2-3 NPC, qualcosa da raccogliere), con architettura pensata per sbarcare **ovunque** poi (città, isole, scali). Da decidere: controlli, cosa si fa a terra nella v1, come si rientra in barca.
- [ ] **Arsenale di B3**: mappa di Bova su cui piazzare le difese + catalogo difese (vedi B3 sotto — impegno preso il 23/07).

## B3 — Difendere casa

*Rimandata dopo la prima tranche di B4 (deciso il 23/07/2026). Direzione di design fissata col feedback di Stefano, da definire insieme in R5 prima di partire:*
- *Niente cartelli svolazzanti sugli slot e niente costruzione dispersa nel pannello porto (oggi è difficile da capire): serve un luogo dedicato, un **arsenale**, con una **mappa di Bova** su cui scegliere e piazzare le difese, che poi appaiono nel mondo reale.*
- *Catalogo difese da definire insieme: cannone/batteria costiera, un sistema di **scogli/ostacoli** che danneggiano le navi nemiche in rotta, torre d'avvistamento, pattuglia… (sessione di design con Stefano prima di scrivere codice).*

- [ ] **Difese costruibili** negli slot: torre d'avvistamento (allunga il preavviso), batteria costiera (spara con `Weapon`), pattuglia (nave `Vessel` alleata in rada)
- [ ] **Attacchi dei predoni**: allarme (campana + HUD + marker minimappa) → i predoni arrivano dopo X minuti → le difese combattono da sole, il giocatore può rientrare e fare la differenza
- [ ] Se l'attacco riesce: **razzia** — prosperità e magazzino calano, nessun game over (la progressione non si cancella, come per l'affondamento)
- [ ] Frequenza/forza degli attacchi scalate sulla ricchezza di Bova (più sei ricco più fai gola) e sulle provocazioni (vedi B4)
- [ ] **Criterio di uscita**: sentire la campana e correre a casa è un momento di tensione vera, non una seccatura

## B4 — Il mare grande e le due città

*Prime due tranche fatte (23/07/2026): mappa grande, Catania e Il Cairo come coste modellate ostili, scali di rifornimento, traversata densificata, tre mondi di prova — dettaglio nella cronologia git. Restano diplomazia attiva, commercio e guerra; le missioni delle città si costruiranno sul sistema item+NPC di R5.*

- [ ] **Diplomazia solo col giocatore**: relazione -100..+100 per città (estende la reputazione di A1); predare le sue navi la peggiora, missioni e accordi la migliorano; soglie leggibili (alleata / neutrale / ostile / in guerra)
	- *Predisposto*: fazioni `catania`/`cairo` in GameState (relazioni iniziali -40, salvate), navi marchiate con la fazione, `Diplomacy` già a soglie. *Resta*: far muovere la relazione da predazioni/missioni/accordi e mostrarla.
- [ ] **Accordi, prezzi e missioni delle città**: catene raccogli-e-consegna (sistema di R5) che aprono i porti e migliorano i prezzi; razzie e blocchi navali dal lato ostile
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
