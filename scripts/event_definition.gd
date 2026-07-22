class_name EventDefinition
extends Resource

## Un evento casuale in mare (roadmap A1): situazione scritta bene e due
## scelte con conseguenze immediate su denaro, carburante, scafo e
## reputazione. Ogni evento è un .tres in resources/events: si scrive e
## si bilancia dall'Inspector senza toccare codice (CLAUDE.md). I costi
## vanno dichiarati anche nel testo della scelta ("-10 L"): il giocatore
## decide a carte scoperte.

@export var id: StringName
@export var title: String = ""
@export_multiline var body: String = ""

@export_group("Scelta A")
@export var choice_a: String = ""
@export var money_a: int = 0
## Litri: negativo = spesa, positivo = regalo.
@export var fuel_a: float = 0.0
## Punti scafo: negativo = danno (mai sotto GameState.EVENT_MIN_HULL).
@export var hull_a: float = 0.0
@export var rep_a: int = 0
## Esito mostrato come notice dopo la scelta ("" = nessuno).
@export var result_a: String = ""

@export_group("Scelta B")
@export var choice_b: String = ""
@export var money_b: int = 0
@export var fuel_b: float = 0.0
@export var hull_b: float = 0.0
@export var rep_b: int = 0
@export var result_b: String = ""
