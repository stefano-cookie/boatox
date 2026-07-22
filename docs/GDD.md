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

Terza persona stile GTA: dietro e sopra la barca, inclinata verso il basso — si vedono barca, mare circostante, oggetti e orizzonte. Col mouse si orbita attorno alla barca (guardare dietro e di lato); dopo qualche secondo senza input la camera torna da sola dietro la poppa. Altezza/distanza/inclinazione/sensibilità esposte come `@export` e tarate col playtest.

## Core loop

- **Minuto per minuto**: navighi, valuti rischi (scogli, meteo), raccogli boe, peschi.
- **Sessione**: torni al porto → vendi il pescato → ripari i danni → scegli upgrade, gara o missione.
- **Lungo periodo**: barche migliori → zone e gare prima impossibili → yacht personalizzato.

## Sistemi

### Navigazione e meteo
- Guida arcade: accelerazione, virata, deriva leggera. Niente simulazione velica.
- La mappa è una baia grande: costa a nord (spiaggia, paese, porto), mare aperto vasto a sud — il giocatore può passarci molto tempo. Lo stato del mare cresce con la distanza dalla costa: **battigia** (risacca minima), **acque calme** sotto costa, **acque medie**, poi il **mare aperto**, dove l'agitazione di base è media e continua a crescere col largo (curva continua, non gradini). L'HUD mostra sempre lo stato locale; sotto costa si è sempre al sicuro.
- **Celle di vento** sul mare aperto: aree circolari che derivano lentamente, si rafforzano e si spengono nel tempo. Dentro una cella attiva il mare si ingrossa davvero (guida e danni compresi): il largo non è sempre grosso, ma non è mai prevedibile.
- Geografia del rischio: scogli vicino a costa e promontori, isole e campi di scogli al largo nelle acque medie/mosse.
- Meteo dinamico (M2): stati calmo → mosso che cambiano a onde temporali sopra le fasce statiche; cielo, luce e foschia si incupiscono insieme alle onde.
- Il mare mosso spinge (verso costa, mai al largo), destabilizza e **frena**: la velocità massima cala con l'agitazione, mitigata dalla stabilità. Con la barchetta iniziale il largo in tempesta è quasi ingovernabile; con upgrade di stabilità diventa attraversabile. È il cancello di progressione principale.
- Nelle condizioni estreme (mare aperto + cella di vento attiva) il mare **danneggia lo scafo** a tick visibili, con allarme a schermo: restare al largo in tempesta è una scommessa, la costa è la salvezza.
- A scafo zero **al largo la barca affonda**: carico perso e recupero a pagamento. Sotto costa resta il traino. Il mare aperto deve poter punire davvero (pillar 2), senza però cancellare la progressione (denaro e upgrade restano).
- Uscire dai confini mappa avvia un countdown visibile con affondamento progressivo; se non rientri in tempo, recupero gratuito al porto.

### Boe (item da vendere)
- Sparse sulla mappa, raccolta al passaggio; vanno in stiva e diventano denaro vendendole al porto: rientrare fa parte del loop.
- Tre tipologie legate alla zona di mare (pillar 2): **gialla** nelle acque calme (spawn certo), **rossa** nelle acque medie (30% di spawn), **blu** rarissima nelle acque mosse (5%). Valore crescente con il rischio; i campi di scogli stanno in acque medie/mosse.
- Ogni punto boa ritenta lo spawn a ogni ciclo di respawn con la probabilità della sua tipologia.

### Pesca
- Zone di pesca visibili (uccelli, increspature). Minigioco in due fasi: **ferrata** a tempismo, poi il **duello** — il pesce tira, tieni premuto per recuperare ma la tensione della lenza sale; troppo a lungo al massimo e il filo si spezza. I pregiati strattonano a scatti: bisogna mollare al momento giusto.
- La difficoltà cresce con la fascia di mare: al largo finestra di ferrata più stretta, pesci pregiati (ricciola, tonno) con duelli lunghi e strappi aggressivi. È rischio-ricompensa (pillar 2): i pesci che valgono di più stanno dove pescare è più duro.
- Pesci con rarità e prezzi diversi; la stiva limita quanto porti (upgrade stiva).
- **Attrezzatura da pesca** (Nino, al porto): canna, mulinello, lenza. È l'anello di progressione della pesca — senza attrezzatura i pesci del largo sono ostici, con l'attrezzatura giusta si domano. Personale (vale su tutte le barche), altra uscita per l'economia.

### Danni e riparazione
- Urti su scogli e tempeste danneggiano lo scafo; a zero scafo sotto costa → traino al porto a pagamento, al largo → affondamento con perdita del carico (vedi Navigazione).
- Riparare costa: è la valvola di sfogo dell'economia.

### Economia
- Entrate: boe, vendita pesce, premi gara, ricompense missioni/eventi.
- Uscite: riparazioni, upgrade funzionali, barche nuove, estetica (prezzi alti, pozzo finale).
- Curva di progressione: ogni barca/upgrade successivo costa ~2-3× il precedente; da bilanciare col playtest.

### Upgrade
- **Funzionali** (per barca): motore (velocità), scafo (resistenza), stabilità (tenuta col mare mosso), stiva (capacità pesca). Ognuno percepibile nella guida.
- **Attrezzatura da pesca** (personale, non per barca): canna (ferrata più facile), mulinello (recupero più rapido), lenza (regge di più, doma gli strappi). Comprata da Nino al porto. Rende il minigioco della pesca una progressione, non solo abilità.
- **Estetici**: vernici, vele, bandiere, luci, accessori. Nessun effetto sul gameplay, costi alti.
- **Barche**: 2-3 nell'alpha (barchetta → pescareccio → primo cabinato), ognuna con guida distinta.

### Corse
- Regate a checkpoint (boe da toccare) contro 2-3 avversari IA su percorso fisso.
- Le IA si scalano sulla barca del giocatore al via (velocità e stabilità relative alle sue): la gara è combattuta a ogni tier, si vince con le traiettorie, non comprando velocità.
- Motore e stabilità contano davvero: sono il banco di prova degli upgrade.
- Premi in denaro; vincere una gara può sbloccare zone/contenuti (cancello di progressione).

### Missioni ed esplorazione
- La minimappa **non** mostra boe e zone di pesca di default: il mare va esplorato. La rilevazione è una progressione, non un dato gratuito.
- **Radar** a impulsi (tasto R): un impulso rivela boe, taniche e zone entro un raggio (frazione della mappa) per una finestra di secondi, poi cooldown. Si sblocca completando una missione, si potenzia (raggio e durata) come famiglia di upgrade a sé.
- **Missione del nipote** (Zu' Vito, l'NPC dietro gli scogli a est): recupera il nipote che galleggia al largo (marker in minimappa) e riportalo; completata, sblocca il radar e apre la sua bottega di potenziamenti. Prototipo del formato missione recupero (marker + raccolta + consegna) della bacheca del porto.

### Eventi e reputazione
- Eventi casuali in mare con scelta (es. barca in avaria: aiuti o ignori) e conseguenze su denaro e reputazione.
- La reputazione modifica prezzi e missioni offerte nei porti.
- Sistema volutamente leggero nell'alpha: 4-6 eventi scritti bene battono 20 generici.

## Contenuto dell'alpha ("loop completo in piccolo")

- 1 zona di mare con 1 porto principale (+ 1 approdo secondario), isole, campi di scogli, 2-3 zone di pesca
- 3 barche di progressione, 4 tipi di upgrade funzionali, un set base di estetica
- 1 percorso di gara con 2-3 IA
- 4-6 eventi con scelta, una manciata di missioni di consegna/recupero
- Meteo a 2 stati (calmo/mosso), ciclo giorno sera facoltativo
- Salvataggio, menu, audio di base
- Un "traguardo": l'acquisto del primo cabinato chiude l'alpha con un finale provvisorio

## Beta — il gestionale d'azione ("Bova è casa")

> Bova Marina è casa tua: la fai crescere, la difendi, e il mare la nutre. Salpi per predare navi in mare aperto, commerci o fai guerra con città lontane, e ogni ricchezza che porti a casa **si vede**: il paese cresce, si illumina, si fortifica. Torni sempre a casa — ma il gioco si vive in mare.

Il gestionale è **incarnato**: niente fogli di calcolo, la barca resta l'avatar di tutto. Le attività dell'alpha (pesca, boe) si **automatizzano** con la crescita di Bova — flottiglie che lavorano per te — e il giocatore sale di ruolo: da pescatore a comandante. I tre pillars restano validi e decidono anche qui. Riferimenti: Dave the Diver (loop azione + meta gestionale), Sid Meier's Pirates! (preda e diplomazia), il feedback visivo dei city builder.

**Tono**: fantasia leggera stilizzata — fazioni immaginarie (predoni, mercanti, città rivali), nessun aggancio storico o contemporaneo sensibile. Arcade spensierato.

### Il mondo

- **Mappa unica allargata**: un solo mare continuo, molto più vasto; la baia di Bova resta il cuore dettagliato. Le città sono fisicamente lontane e ci si naviga in tempo reale: il viaggio è gioco (carburante, celle di vento, incontri), non uno schermo di caricamento.
- **Due città lontane**, ognuna con costa, porto, flotta e personalità: una **commerciale** (accordi, prezzi migliori, missioni), una **ostile** (predoni al suo soldo, razzie, blocchi navali).

### Combattimento navale

- Arma di bordo con **mira libera col mouse**: mirino sulla camera orbitale esistente, proiettile ad arco — spari dove guardi. Cadenza/danno/gittata sono una famiglia di upgrade come motore e scafo.
- Navi IA in mare aperto: **mercantili** (rotta + fuga se attaccati) e **predoni** (ti puntano, speronano o sparano).
- Affondare una nave lascia **bottino galleggiante** da raccogliere; prede migliori dove il mare è più duro (pillar 2).

### Bova cresce

- **Slot di costruzione predefiniti** disegnati a mano su costa e isole: scegli *cosa* costruire lì, non *dove* — la baia resta bella e leggibile. Molo grande, conserva, cantiere di guerra, magazzino, faro, difese…
- **Prosperità** a livelli: bottino e produzione la alzano, e ogni livello trasforma visivamente il paese — più case, luci di notte, barche ormeggiate, gente sul molo. L'economia si vede, non si legge.
- **Automazione**: flottiglie passive (pesca, raccolta) sbloccate dalla crescita; le barche si vedono lavorare in mare. Produzione/consumo a tick semplici, 3-4 risorse leggibili.

### Difendere casa

- **Attacchi dei predoni in tempo reale con preavviso**: allarme → l'attacco arriva dopo X minuti → puoi rientrare a difendere; le difese costruite (torri, batterie, pattuglie) combattono comunque.
- Se la razzia riesce: prosperità e magazzino calano, nessun game over — la progressione non si cancella.
- Frequenza e forza scalate sulla ricchezza di Bova: più sei ricco, più fai gola.

### Diplomazia, commercio, guerra

- **Relazione solo col giocatore**, -100..+100 per città (estende la reputazione dell'alpha); soglie leggibili: alleata / neutrale / ostile / in guerra. Le rivalità tra città sono raccontate, non simulate.
- **Via del mercante**: accordi che aprono rotte automatizzate — le tue navi viaggiano visibili e rendono passivamente, ma sono attaccabili: da difendere o scortare.
- **Via del corsaro**: predare peggiora la relazione, fino alla guerra aperta — attaccare il porto nemico, subire rappresaglie, imporre la sottomissione (tributo o cessate il fuoco).
- Le due vie devono cambiare davvero la partita: è il criterio di uscita della beta.

### Traguardo di fine beta

Doppio: Bova al massimo splendore (prosperità e difese) **e** ogni città risolta (alleata o sottomessa) → schermata finale con statistiche.

## Fuori scope

Vedi `BACKLOG.md`. In particolare: tema narrativo migranti (da trattare con cura dedicata, non come evento qualunque), simulazione città-vs-città, tempesta come terzo stato meteo, port web/mobile.

## Direzione estetica

- Low-poly stilizzato, flat color, luce curata: il mare e il cielo fanno l'atmosfera (riferimenti: Dredge per tono e struttura, Sailwind per il mare, eSail solo come ispirazione atmosferica).
- L'ambientazione è la costa ionica di **Bova Marina** (Calabria): spiaggia chiara con acqua turchese sul bagnasciuga, paesino bianco coi tetti in terracotta sul lungomare, campanile, colline secche mediterranee (pini e cipressi) e l'Aspromonte sfumato nella foschia alle spalle; due promontori rocciosi chiudono la baia.
- Asset di partenza: Kenney (pirate/watercraft kit), Quaternius. Tutto CC0/CC-BY, crediti in `assets/CREDITS.md`.
