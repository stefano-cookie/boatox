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
- [ ] Minigioco pesca + zone di pesca + stiva
- [ ] Gara a checkpoint con 2-3 IA, premi, sblocco contenuti
- [ ] Missioni di consegna/recupero dai porti
- [ ] Eventi casuali con scelta + reputazione
- [ ] **Criterio di uscita**: una sessione da 20 minuti offre almeno 3 attività diverse sensate

## M4 — Beta
- [ ] Customizzazione estetica (vernici, accessori)
- [ ] Menu principale e impostazioni complete (pausa base fatta in M1: riprendi/ricomincia/fullscreen/esci)
- [ ] Audio: mare, motore, UI, un tema musicale
- [ ] Feedback d'impatto (flash barra scafo, scuotimento camera)
- [ ] Traguardo di fine beta (acquisto del primo cabinato) e schermata finale provvisoria
- [ ] Bilanciamento complessivo + bug pass
- [ ] Export macOS/Windows, pagina itch.io (privata) per distribuire la build
- [ ] **Criterio di uscita**: un estraneo la gioca dall'inizio al traguardo senza aiuto
