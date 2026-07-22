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
