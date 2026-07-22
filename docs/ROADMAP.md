# Roadmap

Regola: una milestone è chiusa solo quando Stefano l'ha giocata e approvata. Non si apre la successiva prima.

*Storia: M0 (game feel) → M1 (mondo e loop) → M2 (progressione) → M2.5 (la costa di Bova) → M3 (missioni, gare, pesca + due round di feedback playtest) sono completate — il dettaglio vive nella cronologia git di questo file.*

---

# ALPHA — chiudere il gioco arcade

Obiettivo: il "loop completo in piccolo" del GDD, giocabile da un estraneo dall'inizio al traguardo senza aiuto. È la fondazione su cui poggia la beta gestionale: tutto ciò che c'è qui resterà nella beta come punto di partenza.

## A1 — Contenuti mancanti

- [x] **Missioni di consegna/recupero dai porti**
	- Nuovo **approdo secondario** sulla costa ("Scalo di Ponente", a ovest): scena Port parametrica coi servizi spenti — attracco e consegna, niente cantiere. *(Primo banco di prova del Port parametrico di B0.)*
	- Bacheca nel menu porto (nuovo bottone): 3 missioni generate da template. **Consegna**: porta N casse all'approdo entro T minuti (le casse occupano stiva: si sceglie se rinunciare al pescato). **Recupero**: raggiungi il punto segnato in minimappa, raccogli il pacco/relitto galleggiante, riportalo al porto.
	- Ricompensa scalata su distanza e fascia di mare del punto (più a largo = più soldi, GDD pillar 2). Una missione attiva alla volta; stato e progresso in GameState, salvati.
	- Marker missione in minimappa (stessa logica del cancello regata).
- [x] **Eventi casuali con scelta + reputazione**
	- 6 eventi scritti bene (GDD: battono 20 generici): barca in avaria, pescatore senza benzina, boa misteriosa, carico alla deriva, muro di pioggia, rete smarrita.
	- Trigger: un tiro ogni 2-3 minuti di navigazione oltre le acque calme; l'evento apre un pannello con 2 scelte e conseguenze immediate (denaro, carburante, scafo, reputazione).
	- **Reputazione** -100..+100 in GameState (salvata): sconta o rincara riparazioni e rifornimento (±15% a fondo scala) e in futuro filtra le missioni migliori. Visibile nel pannello porto. Già strutturata per-fazione (per ora solo il porto di Bova) — diventerà la diplomazia con le città (vedi B4).
	- Ogni evento è un `Resource` (.tres in `resources/events/`): testo, scelte, effetti — si scrivono e bilanciano dall'Inspector senza toccare codice.
- [ ] **Criterio di uscita**: una sessione da 20 minuti offre almeno 3 attività diverse sensate
	- *Da verificare in gioco: leggibilità del pacco di recupero e del marker ambra; tempi limite di consegna (costante `MISSION_DELIVERY_SPEED`); frequenza e tono degli eventi; entità di sconti/rincari da reputazione.*

## A2 — Rifinitura e chiusura

- [ ] **Customizzazione estetica** (vernici, accessori)
	- Vernici = palette di tinte sui materiali del modello (per barca, salvate); accessori come nodi opzionali del visual (bandiera, luci, parabordi). Prezzi alti: è il pozzo dell'economia (GDD pillar 3). Shop nel cantiere, anteprima live sulla barca attraccata.
- [ ] **Menu principale e impostazioni complete** (pausa base fatta in M1)
	- Scena title con la baia sullo sfondo; impostazioni: volumi (master/musica/sfx — musica e sfx già fatti), fullscreen, sensibilità mouse camera, azzeramento salvataggio con conferma.
- [ ] **Audio: rifiniture**
	- Il grosso è fatto (procedurale: mare, motore, SFX, playlist). Restano: slider master e sensibilità mouse accanto ai volumi esistenti; eventuali tracce registrate CC0 al posto delle procedurali se il gusto lo chiede.
- [ ] **Verifiche playtest arretrate** (accumulate nei "da verificare in gioco")
	- Criteri di uscita mai validati: la seconda barca è desiderabile e guadagnarsela soddisfa (M2); la baia si legge a colpo d'occhio e sembra Bova Marina (M2.5).
	- Performance e sfumatura del piano mare esteso al confine sud; posizioni dei 6 checkpoint della gara al largo; posizione NPC/rescue_point e leggibilità del cerchio radar; leggibilità icone inventario; mix volumi, timbro motore/mare, gusto dei brani, tick sugli avvisi.
- [ ] **Traguardo di fine alpha** (acquisto del primo cabinato) e schermata finale provvisoria
	- All'acquisto del Cabinato: schermata "fine alpha" con statistiche di partita (tempo, denaro totale, pesci, vittorie) e ringraziamento; poi si continua a giocare liberamente.
- [ ] **Bilanciamento complessivo + bug pass**
	- Passata su prezzi/premi/valori con un foglio dei tempi-per-upgrade; sessione di playtest completa dall'inizio annotando attriti.
- [ ] **Export macOS/Windows, pagina itch.io (privata)** per distribuire la build ai tester
- [ ] **Criterio di uscita**: un estraneo la gioca dall'inizio al traguardo senza aiuto

---

# BETA — il gestionale d'azione: "Bova è casa"

## Visione

> Bova Marina è casa tua: la fai crescere, la difendi, e il mare la nutre. Salpi per predare navi in mare aperto, commerci o fai guerra con città lontane, e ogni ricchezza che porti a casa **si vede**: il paese cresce, si illumina, si fortifica. Torni sempre a casa — ma il gioco si vive in mare.

Il gestionale è **incarnato**: niente fogli di calcolo, la barca resta l'avatar di tutto. Le attività dell'alpha (pesca, boe) si **automatizzano** con la crescita di Bova — flottiglie che lavorano per te — e il giocatore sale di ruolo: da pescatore a comandante. Riferimenti: Dave the Diver (loop azione + meta gestionale), Sid Meier's Pirates! (preda e diplomazia), il feedback visivo dei city builder.

**Tono**: fantasia leggera stilizzata — fazioni immaginarie (predoni, mercanti, città rivali), nessun aggancio storico o contemporaneo sensibile. Arcade spensierato.

## Decisioni di design (fissate il 22/07/2026)

| Tema | Decisione |
|---|---|
| Baricentro | Gestionale incarnato: la barca resta il loop attivo, il gestionale è il meta-layer |
| Mondo | **Mappa unica allargata**: un solo mare continuo, le città sono fisicamente lontane, ci si naviga in tempo reale (il viaggio è gioco: carburante, meteo, incontri) |
| Combattimento | **Mira libera col mouse**: mirino sulla camera orbitale esistente, spari dove guardi |
| Difesa di Bova | **Tempo reale con preavviso**: allarme → l'attacco arriva dopo X minuti → puoi rientrare a difendere; le difese costruite combattono comunque |
| Attività alpha | **Si automatizzano**: flottiglie di pesca/raccolta passive sbloccate dalla crescita di Bova; il giocatore fa azione, la base genera economia |
| Costruzione | **Slot predefiniti** disegnati a mano su costa e isole: scegli cosa costruire lì, non dove — la baia resta bella e leggibile |
| Città lontane | **2 nella beta**: una a vocazione commerciale, una ostile/aggressiva (gli archi accordo e guerra esistono entrambi col minimo scope) |
| Diplomazia | **Solo col giocatore**: relazione per città (estende la reputazione dell'alpha); le rivalità tra città sono raccontate, non simulate |
| Fine beta | **Doppio traguardo**: Bova al massimo splendore E ogni città risolta (alleata o sottomessa) |

## B0 — Predisposizioni architetturali

*Si fanno opportunisticamente già durante l'alpha, quando si tocca quel codice: nessuna feature nuova, solo forme che evitano di riscrivere dopo.*

- [ ] **GDD**: nuova sezione "Beta — il gestionale d'azione" con questa visione (il GDD resta la fonte di verità; questa roadmap indica il *quando*, il GDD il *cosa*)
- [ ] **`Vessel`**: base comune (hp, velocità, stabilità, fazione) da cui discendono la barca del giocatore e le navi IA — oggi `Boat` e le IA di regata non condividono nulla
- [ ] **`owner_faction`** su porti e navi (per ora sempre player/neutrale) + autoload `Diplomacy` embrionale (mappa fazione → relazione, la reputazione di A1 ne è il primo caso)
- [ ] **`Damageable` + `Weapon`** (raggio, danno, cadenza): astrazione condivisa che useranno cannoni di bordo, torri e batterie costiere
- [ ] **`world_state`** in GameState: prosperità di Bova, difese costruite, relazioni — salvato accanto a denaro/upgrade
- [ ] **Port parametrico**: `faction`, `services`, `defense_level`, `prosperity` come `@export` (l'approdo secondario di A1 è il primo banco di prova)

## B1 — Il cannone (combattimento navale)

*Prima il divertimento: se predare non è divertente, il resto non regge.*

- [ ] Arma di bordo con **mira libera**: mirino sulla camera orbitale, proiettile ad arco, `Input.MOUSE_MODE_CAPTURED` già gestito; cadenza/danno/gittata in `Resource` (famiglia di upgrade come motore/scafo)
- [ ] Navi IA in mare aperto: **mercantile** (rotta + fuga se attaccato) e **predone** (ti punta e sperona/spara) — primi figli di `Vessel`
- [ ] Danneggiare/affondare una nave → **bottino galleggiante** da raccogliere (riusa il pattern boe); prede migliori dove il mare è più duro (GDD pillar 2)
- [ ] Feedback d'impatto sui colpi (riusa flash/shake/SFX esistenti), salute della preda leggibile
- [ ] **Criterio di uscita**: inseguire e predare un mercantile è divertente quanto vincere una regata

## B2 — Bova cresce (costruzione, prosperità, automazione)

*Il cuore del feedback visivo: l'economia si vede, non si legge.*

- [ ] **Slot di costruzione** predefiniti sulla costa (e sulle isole): pannello al porto per costruire/potenziare — molo grande, conserva (trasforma pesce in prodotto di valore ×N), cantiere di guerra, magazzino, faro…
- [ ] **Prosperità di Bova** (0..N livelli): il bottino e la produzione la alzano; ogni livello trasforma visivamente il paese — più case, luci di notte, barche ormeggiate, gente sul molo, il campanile che si abbellisce
- [ ] **Automazione**: la flottiglia di pesca (sbloccata con un edificio) pesca passivamente nelle zone conosciute; le barche si vedono lavorare in mare; rendimento e capienza potenziabili
- [ ] Produzione/consumo a tick semplici (niente catene complesse: 3-4 risorse leggibili), tutto in `Resource` bilanciabili
- [ ] **Criterio di uscita**: si distingue a colpo d'occhio una Bova povera da una ricca, e viene voglia di arricchirla

## B3 — Difendere casa

- [ ] **Difese costruibili** negli slot: torre d'avvistamento (allunga il preavviso), batteria costiera (spara con `Weapon`), pattuglia (nave `Vessel` alleata in rada)
- [ ] **Attacchi dei predoni**: allarme (campana + HUD + marker minimappa) → i predoni arrivano dopo X minuti → le difese combattono da sole, il giocatore può rientrare e fare la differenza
- [ ] Se l'attacco riesce: **razzia** — prosperità e magazzino calano, nessun game over (la progressione non si cancella, come per l'affondamento)
- [ ] Frequenza/forza degli attacchi scalate sulla ricchezza di Bova (più sei ricco più fai gola) e sulle provocazioni (vedi B4)
- [ ] **Criterio di uscita**: sentire la campana e correre a casa è un momento di tensione vera, non una seccatura

## B4 — Il mare grande e le due città

- [ ] **Allargamento della mappa**: mare continuo molto più vasto (la baia di Bova resta il cuore dettagliato); il viaggio lungo è gioco vero — carburante, celle di vento, incontri; verifiche performance (LOD, streaming dei chunk se serve)
- [ ] **Due città lontane**, ognuna con costa modellata, porto, flotta e personalità: una **commerciale** (accordi, prezzi migliori per le tue merci, missioni), una **ostile** (predoni al suo soldo, razzie, blocchi navali)
- [ ] **Diplomazia solo col giocatore**: relazione -100..+100 per città (estende la reputazione di A1); predare le sue navi la peggiora, missioni e accordi la migliorano; soglie leggibili (alleata / neutrale / ostile / in guerra)
- [ ] **Commercio**: accordi che aprono rotte automatizzate (le tue navi mercantili viaggiano visibili sulla rotta e rendono passivamente — e sono attaccabili: da difendere o scortare)
- [ ] **Guerra**: attaccare il porto nemico (difese sue speculari alle tue), rappresaglie su Bova, fino alla sottomissione (tributo o cessate il fuoco)
- [ ] **Criterio di uscita**: scegliere tra la via del mercante e quella del corsaro cambia davvero la partita
- [ ] *Le città interagiscono solo col giocatore nella beta; simulazione città-vs-città in BACKLOG*

## B5 — Chiusura beta

- [ ] **Doppio traguardo**: Bova all'ultimo livello di prosperità e difese **E** entrambe le città risolte (alleata o sottomessa) → schermata finale con statistiche
- [ ] Bilanciamento complessivo del meta (tempi di crescita, rendimenti passivi vs attivi, curva degli attacchi)
- [ ] Onboarding del gestionale (le tappe guidate esistenti si estendono: primo edificio, prima difesa, primo viaggio lontano)
- [ ] **Criterio di uscita**: un estraneo gioca dall'alpha alla fine della beta capendo da solo quando pescare, quando predare, quando costruire
