class_name BuildingDefinition
extends Resource

## Scheda di un edificio di Bova (roadmap B2): costi per livello ed
## effetti come curve indicizzate dal livello (indice 0 = non costruito,
## quindi ogni curva è lunga costs.size() + 1). Tutto il bilanciamento
## vive nei .tres in resources/buildings/, si regola dall'Inspector.

@export var id: StringName
@export var display_name: String = ""
## Cosa fa in gioco, mostrato nel pannello di costruzione del porto.
@export var desc: String = ""
## Costo del prossimo livello (la lunghezza è il numero di livelli).
@export var costs: Array[int] = []

@export_group("Effetti per livello (indice = livello, 0 = non costruito)")
## Barche della flottiglia di pesca visibili in mare.
@export var fleet_boats: Array[int] = []
## Pescato portato al magazzino a ogni tick di produzione.
@export var fish_per_tick: Array[int] = []
## Pesci trasformati in conserve a ogni tick.
@export var convert_per_tick: Array[int] = []
## Capienza aggiunta al magazzino del paese.
@export var storage_bonus: Array[int] = []
## Moltiplicatore della resa della flottiglia.
@export var yield_mult: Array[float] = []


func max_level() -> int:
	return costs.size()


## Costo del livello successivo a `level`; -1 se già al massimo.
func next_cost(level: int) -> int:
	if level >= costs.size():
		return -1
	return costs[level]


func boats_at(level: int) -> int:
	return _int_at(fleet_boats, level)


func fish_at(level: int) -> int:
	return _int_at(fish_per_tick, level)


func convert_at(level: int) -> int:
	return _int_at(convert_per_tick, level)


func storage_at(level: int) -> int:
	return _int_at(storage_bonus, level)


func yield_at(level: int) -> float:
	if yield_mult.is_empty():
		return 1.0
	return yield_mult[clampi(level, 0, yield_mult.size() - 1)]


## Indice clampato alla curva: un salvataggio con livelli fuori scala
## non esplode (stesso criterio delle curve in GameState).
func _int_at(curve: Array[int], level: int) -> int:
	if curve.is_empty():
		return 0
	return curve[clampi(level, 0, curve.size() - 1)]
