# Foglio di bilanciamento — tempi-per-upgrade (alpha)

Supporto alla passata di bilanciamento di A2. I **prezzi** sono letti dal codice/`.tres`
(fonte di verità: `autoload/game_state.gd` e `resources/boats/*.tres`); i **guadagni al
minuto** sono stime da banco, da sostituire coi tempi veri della sessione di playtest
annotata. Se un numero qui non torna col gioco, vince il gioco: aggiornare questo file.

## Entrate stimate ($/min per attività, da validare giocando)

| Attività | Stima | Assunzioni |
|---|---|---|
| Boe in acque calme | ~15–20 | gialle da 10 $, respawn 45 s, stiva 5+ e rotta efficiente |
| Boe ai margini/scogli | ~30–45 | mix gialle/rosse (40 $), più rischio scafo |
| Pesca fascia 1 | ~20–30 | sardine 8 $ / orate 30 $, stock 3 e riposo 150 s |
| Pesca fascia 2–3 | ~45–90 | ricciole 90 $ / tonni 250 $, duello più lungo, rischio meteo |
| Regata sotto costa (vinta) | ~100 | premio 300 $ × tier, ~2–3 min a gara, non farmabile all'infinito |
| Missioni bacheca | ~35–60 | consegna 45 $/cassa + 0.15 $/m; recupero fino a ×1.5 al largo |

Assunzione di lavoro per le tabelle sotto: **~40 $/min** a metà progressione
(barchetta potenziata / pescareccio), al netto di benzina e riparazioni (~10–15%).

## Pozzi dell'economia (prezzi reali)

| Voce | Prezzo | Minuti a ~40 $/min |
|---|---|---|
| Pescareccio | 600 | 15 |
| Cabinato (dopo 1ª vittoria) | 1800 | 45 (ma a quel punto si guadagna di più) |
| Upgrade barchetta (tot. 4 famiglie ×3 liv.) | 2 380 | — si comprano a pezzi, 60→480 |
| Upgrade pescareccio (tot.) | 5 610 | 130→1 100 a livello |
| Upgrade cabinato (tot.) | 13 550 | 280→2 800 a livello |
| Attrezzatura pesca (tot.) | 5 170 | 200→1 100 a livello |
| Radar (tot.) | 5 850 | 350→1 800 a livello |
| Vernici (per barca) | 400–600 | ~10–15 min l'una |
| Accessori (per barca) | 300–550 | bandiera 300, parabordi 350, luci 550 |

## Traguardo alpha (acquisto Cabinato)

Percorso minimo: barchetta → qualche upgrade (~300 $) → pescareccio (600 $) →
vittoria in regata → 1800 $ → **Cabinato**. Totale speso ~2 700–3 000 $:
**~60–75 minuti** a guadagni misti — in linea col target "loop completo in piccolo".

## Da annotare nella sessione di playtest completa

- $/min reali per attività (cronometrare 5 min per ciascuna) → correggere la colonna stime.
- Minuti reali all'acquisto del pescareccio e del Cabinato partendo da zero.
- La customizzazione tenta davvero da pozzo? (si compra una vernice prima del Cabinato?)
- Attriti: dove ci si annoia, dove il denaro si accumula senza scelte.
