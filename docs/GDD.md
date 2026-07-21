# boatox — Game Design Document

*Versione leggera: questo documento è la bussola, non un contratto. Si aggiorna quando il playtest smentisce il design.*

## Pitch

Gioco 3D low-poly per PC. Parti con una barchetta scassata e arrivi allo yacht: navighi con WASD un mare aperto con boe da raccogliere, zone di pesca, scogli e mare mosso; guadagni, potenzi la barca, la personalizzi e vinci regate. Idle nell'anima gestionale, arcade nella guida.

## Pillars (le 3 regole che decidono ogni dubbio di design)

1. **La progressione si sente, non si legge** — ogni upgrade cambia come la barca si guida o cosa può fare, mai solo un numero.
2. **Rischio-ricompensa ovunque** — il bottino migliore sta sempre vicino al pericolo (scogli, mare grosso, rotte lunghe).
3. **La barca è tua** — la customizzazione estetica è il trofeo della progressione e il pozzo dell'economia.

## Controlli

- `W/S` o `↑/↓`: acceleratore / retro
- `A/D` o `←/→`: timone
- Pochi tasti azione (interagisci, pesca, mappa, menu porto). Niente combo complesse: tutto giocabile con una mano sulla tastiera.

## Camera

Terza persona stile GTA: dietro e sopra la barca, inclinata verso il basso — si vedono barca, mare circostante, oggetti e orizzonte. Altezza/distanza/inclinazione esposte come `@export` e tarate col playtest.

## Core loop

- **Minuto per minuto**: navighi, valuti rischi (scogli, meteo), raccogli boe, peschi.
- **Sessione**: torni al porto → vendi il pescato → ripari i danni → scegli upgrade, gara o missione.
- **Lungo periodo**: barche migliori → zone e gare prima impossibili → yacht personalizzato.

## Sistemi

### Navigazione e meteo
- Guida arcade: accelerazione, virata, deriva leggera. Niente simulazione velica.
- Il mare è diviso in tre anelli concentrici statici dal centro mappa: **acque calme** (porto e partenza), **acque medie**, **acque mosse** al largo, con onde progressivamente più grosse. L'HUD mostra sempre la zona corrente.
- Meteo dinamico (M2): stati calmo → mosso che cambiano a onde temporali sopra le zone statiche.
- Il mare mosso spinge e destabilizza (M2): con la barchetta iniziale è quasi ingovernabile, con upgrade di stabilità diventa attraversabile. È il cancello di progressione principale.
- Uscire dai confini mappa avvia un countdown visibile con affondamento progressivo; se non rientri in tempo, recupero gratuito al porto.

### Boe (item da vendere)
- Sparse sulla mappa, raccolta al passaggio; vanno in stiva e diventano denaro vendendole al porto: rientrare fa parte del loop.
- Tre tipologie legate alla zona di mare (pillar 2): **gialla** nelle acque calme (spawn certo), **rossa** nelle acque medie (30% di spawn), **blu** rarissima nelle acque mosse (5%). Valore crescente con il rischio; i campi di scogli stanno in acque medie/mosse.
- Ogni punto boa ritenta lo spawn a ogni ciclo di respawn con la probabilità della sua tipologia.

### Pesca
- Zone di pesca visibili (uccelli, increspature). Minigioco breve di tempismo a tasti.
- Pesci con rarità e prezzi diversi; la stiva limita quanto porti (upgrade stiva).

### Danni e riparazione
- Urti su scogli e tempeste danneggiano lo scafo; a zero scafo → traino al porto a pagamento (niente game over punitivo).
- Riparare costa: è la valvola di sfogo dell'economia.

### Economia
- Entrate: boe, vendita pesce, premi gara, ricompense missioni/eventi.
- Uscite: riparazioni, upgrade funzionali, barche nuove, estetica (prezzi alti, pozzo finale).
- Curva di progressione: ogni barca/upgrade successivo costa ~2-3× il precedente; da bilanciare col playtest.

### Upgrade
- **Funzionali** (per barca): motore (velocità), scafo (resistenza), stabilità (tenuta col mare mosso), stiva (capacità pesca). Ognuno percepibile nella guida.
- **Estetici**: vernici, vele, bandiere, luci, accessori. Nessun effetto sul gameplay, costi alti.
- **Barche**: 2-3 nella beta (barchetta → pescareccio → primo cabinato), ognuna con guida distinta.

### Corse
- Regate a checkpoint (boe da toccare) contro 2-3 avversari IA su percorso fisso.
- Motore e stabilità contano davvero: sono il banco di prova degli upgrade.
- Premi in denaro; vincere una gara può sbloccare zone/contenuti (cancello di progressione).

### Eventi e reputazione
- Eventi casuali in mare con scelta (es. barca in avaria: aiuti o ignori) e conseguenze su denaro e reputazione.
- La reputazione modifica prezzi e missioni offerte nei porti.
- Sistema volutamente leggero nella beta: 4-6 eventi scritti bene battono 20 generici.

## Contenuto della beta ("loop completo in piccolo")

- 1 zona di mare con 1 porto principale (+ 1 approdo secondario), isole, campi di scogli, 2-3 zone di pesca
- 3 barche di progressione, 4 tipi di upgrade funzionali, un set base di estetica
- 1 percorso di gara con 2-3 IA
- 4-6 eventi con scelta, una manciata di missioni di consegna/recupero
- Meteo a 2 stati (calmo/mosso), ciclo giorno sera facoltativo
- Salvataggio, menu, audio di base
- Un "traguardo": l'acquisto del primo cabinato chiude la beta con un finale provvisorio

## Fuori scope beta

Vedi `BACKLOG.md`. In particolare: finanza/commercio tra porti, tema narrativo migranti (da trattare con cura dedicata, non come evento qualunque), tempesta come terzo stato meteo, più zone, port web/mobile.

## Direzione estetica

- Low-poly stilizzato, flat color, luce curata: il mare e il cielo fanno l'atmosfera (riferimenti: Dredge per tono e struttura, Sailwind per il mare, eSail solo come ispirazione atmosferica).
- Asset di partenza: Kenney (pirate/watercraft kit), Quaternius. Tutto CC0/CC-BY, crediti in `assets/CREDITS.md`.
