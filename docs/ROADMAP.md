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

## M3 — Missioni, gare, pesca
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
