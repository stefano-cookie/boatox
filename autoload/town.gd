extends Node

## Bova cresce (roadmap B2): costruzione negli slot predefiniti,
## magazzino del paese, produzione a tick della flottiglia e prosperità
## a livelli. Lo stato vive in GameState.world_state (predisposizione B0:
## salvato con la partita, retrocompatibile); qui vivono regole e
## bilanciamento. Le scene (BuildSlot, TownGrowth, Fleet, pannello del
## porto) si aggiornano su town_changed / prosperity_changed: nessuna
## conosce le altre.

## Qualcosa del paese è cambiato (edificio, magazzino, punti): le UI e
## le visuali si risincronizzano su questo.
signal town_changed
## Il paese è salito di livello: la costa si trasforma (TownGrowth).
signal prosperity_changed(level: int)

## Gli edifici costruibili; unici: ognuno può esistere in un solo slot.
const BUILDINGS: Array[BuildingDefinition] = [
	preload("res://resources/buildings/molo_grande.tres"),
	preload("res://resources/buildings/conserva.tres"),
	preload("res://resources/buildings/magazzino.tres"),
	preload("res://resources/buildings/faro.tres"),
]

## Secondi tra due tick di produzione/consumo (niente catene complesse:
## la flottiglia porta pesce, la conserva lo trasforma, fine).
const TICK_SECONDS: float = 30.0
## Valore di vendita delle risorse del magazzino (il pesce della
## flottiglia vale meno di quello pescato a mano: è passivo).
const FISH_VALUE: int = 5
const CONSERVE_VALUE: int = 18
## Capienza del magazzino senza l'edificio omonimo.
const BASE_STORAGE: int = 20
## Punti prosperità: costruire vale costo/BUILD_POINTS_DIVISOR, vendere
## (carico del giocatore o produzione del paese: "bottino e produzione")
## vale importo/SALE_POINTS_DIVISOR.
const BUILD_POINTS_DIVISOR: int = 15
const SALE_POINTS_DIVISOR: int = 25
## Punti totali richiesti per ogni livello di prosperità (0..4).
const PROSPERITY_THRESHOLDS: Array[int] = [0, 120, 300, 560, 900]
const LEVEL_NAMES: Array[String] = [
	"Borgo di pescatori",
	"Paese vivo",
	"Porto operoso",
	"Perla dello Ionio",
	"Splendore dello Ionio",
]

## Colore BBCode del denaro nei pannelli (lo stesso del porto).
const MONEY_HEX: String = "8ee3a8"

var _tick_elapsed: float = 0.0
## Evita di ripetere l'avviso di magazzino pieno a ogni tick.
var _storage_full_notified: bool = false


func _ready() -> void:
	# "Bottino e produzione alzano la prosperità": ogni vendita (carico,
	# missioni, magazzino) passa da cargo_sold — un punto ogni 25 $.
	GameState.cargo_sold.connect(_on_cargo_sold)
	GameState.world_state_reset.connect(_on_world_reset)


## Il tick scorre solo in partita: title e pausa fermano l'albero, e
## l'autoload si ferma con loro (come il tempo di gioco in GameState).
func _process(delta: float) -> void:
	if fish_rate_per_tick() <= 0 and fish_stock() <= 0:
		return
	_tick_elapsed += delta
	if _tick_elapsed >= TICK_SECONDS:
		_tick_elapsed -= TICK_SECONDS
		produce_tick()


# --- Edifici -----------------------------------------------------------------

func building_def(id: StringName) -> BuildingDefinition:
	for def in BUILDINGS:
		if def.id == id:
			return def
	return null


## L'edificio nello slot: {"id": StringName, "level": int}, vuoto se
## lo slot è libero. Coercizione dei tipi: dal JSON i numeri tornano float.
func slot_building(slot_id: StringName) -> Dictionary:
	var entry: Variant = _buildings().get(String(slot_id))
	if entry == null or not entry is Dictionary:
		return {}
	return {
		"id": StringName(str(entry.get("id", ""))),
		"level": int(entry.get("level", 0)),
	}


## Slot che ospita l'edificio, &"" se non è costruito da nessuna parte.
func built_slot(building_id: StringName) -> StringName:
	var buildings := _buildings()
	for slot: String in buildings:
		if str(buildings[slot].get("id", "")) == String(building_id):
			return StringName(slot)
	return &""


func building_level(building_id: StringName) -> int:
	var slot := built_slot(building_id)
	if slot == &"":
		return 0
	return int(slot_building(slot).get("level", 0))


## Costruisce il livello 1 nello slot. Falso se lo slot è occupato,
## l'edificio esiste già altrove o i soldi non bastano. La validità
## dello slot (allowed) la verifica il pannello, che conosce la scena.
func build(slot_id: StringName, building_id: StringName) -> bool:
	var def := building_def(building_id)
	if def == null or not slot_building(slot_id).is_empty() or built_slot(building_id) != &"":
		return false
	var cost := def.next_cost(0)
	if cost < 0 or GameState.money < cost:
		return false
	GameState.money -= cost
	_buildings()[String(slot_id)] = {"id": String(building_id), "level": 1}
	GameState.money_changed.emit(GameState.money)
	GameState.post_notice("%s: costruito! Bova ringrazia" % def.display_name)
	_add_prosperity(cost / BUILD_POINTS_DIVISOR)
	town_changed.emit()
	GameState.save_game()
	return true


## Potenzia l'edificio nello slot di un livello. Falso se non c'è nulla,
## è già al massimo o i soldi non bastano.
func upgrade(slot_id: StringName) -> bool:
	var info := slot_building(slot_id)
	if info.is_empty():
		return false
	var def := building_def(info["id"])
	var level: int = info["level"]
	var cost := def.next_cost(level)
	if cost < 0 or GameState.money < cost:
		return false
	GameState.money -= cost
	_buildings()[String(slot_id)] = {"id": String(def.id), "level": level + 1}
	GameState.money_changed.emit(GameState.money)
	GameState.post_notice("%s: livello %d" % [def.display_name, level + 1])
	_add_prosperity(cost / BUILD_POINTS_DIVISOR)
	town_changed.emit()
	GameState.save_game()
	return true


# --- Produzione e magazzino --------------------------------------------------

func fish_stock() -> int:
	return int(_warehouse().get("fish", 0))


func conserve_stock() -> int:
	return int(_warehouse().get("conserve", 0))


func storage_capacity() -> int:
	var def := building_def(&"magazzino")
	return BASE_STORAGE + def.storage_at(building_level(&"magazzino"))


func fleet_boat_count() -> int:
	var def := building_def(&"molo_grande")
	return def.boats_at(building_level(&"molo_grande"))


## Pesce portato al magazzino a ogni tick: la resa del molo per il
## moltiplicatore del faro.
func fish_rate_per_tick() -> int:
	var molo := building_def(&"molo_grande")
	var faro := building_def(&"faro")
	var base := molo.fish_at(building_level(&"molo_grande"))
	return roundi(base * faro.yield_at(building_level(&"faro")))


func convert_rate_per_tick() -> int:
	var def := building_def(&"conserva")
	return def.convert_at(building_level(&"conserva"))


func warehouse_value() -> int:
	return fish_stock() * FISH_VALUE + conserve_stock() * CONSERVE_VALUE


## Un tick di produzione/consumo: la flottiglia porta pesce (fin dove
## c'è posto), la conserva trasforma pesce in conserve (1:1, il posto
## occupato non cambia). Chiamato dal timer interno; pubblico perché i
## test headless lo pilotano senza aspettare il tempo reale.
func produce_tick() -> void:
	var warehouse := _warehouse()
	var space := storage_capacity() - fish_stock() - conserve_stock()
	var caught := clampi(fish_rate_per_tick(), 0, maxi(space, 0))
	if caught > 0:
		warehouse["fish"] = fish_stock() + caught
		_storage_full_notified = false
	var converted := mini(convert_rate_per_tick(), fish_stock())
	if converted > 0:
		warehouse["fish"] = fish_stock() - converted
		warehouse["conserve"] = conserve_stock() + converted
	if fish_rate_per_tick() > 0 and space <= 0 and not _storage_full_notified:
		_storage_full_notified = true
		GameState.post_notice("Magazzino pieno! La flottiglia aspetta: vendi la produzione al porto")
	if caught > 0 or converted > 0:
		town_changed.emit()


## Vende tutto il magazzino: il denaro entra, la vendita alza la
## prosperità via cargo_sold (come ogni bottino che torna a casa).
func sell_warehouse() -> int:
	var earned := warehouse_value()
	if earned <= 0:
		return 0
	var warehouse := _warehouse()
	warehouse["fish"] = 0
	warehouse["conserve"] = 0
	GameState.money += earned
	GameState.total_earned += earned
	_storage_full_notified = false
	GameState.money_changed.emit(GameState.money)
	GameState.post_notice("Produzione di Bova venduta: +%d $" % earned)
	GameState.cargo_sold.emit(earned)
	town_changed.emit()
	GameState.save_game()
	return earned


# --- Prosperità --------------------------------------------------------------

func prosperity_level() -> int:
	return int(GameState.world_state.get("bova_prosperity", 0))


func prosperity_points() -> int:
	return int(GameState.world_state.get("prosperity_points", 0))


func max_prosperity_level() -> int:
	return PROSPERITY_THRESHOLDS.size() - 1


func level_name(level: int = prosperity_level()) -> String:
	return LEVEL_NAMES[clampi(level, 0, LEVEL_NAMES.size() - 1)]


## Punti totali richiesti per il prossimo livello; -1 se già al massimo.
func next_level_threshold() -> int:
	var level := prosperity_level()
	if level >= max_prosperity_level():
		return -1
	return PROSPERITY_THRESHOLDS[level + 1]


func _add_prosperity(points: int) -> void:
	if points <= 0:
		return
	GameState.world_state["prosperity_points"] = prosperity_points() + points
	var level := _level_for(prosperity_points())
	# Il livello non scende mai: la prosperità guadagnata resta (la
	# razzia di B3 la abbasserà esplicitamente, non per aritmetica).
	if level > prosperity_level():
		GameState.world_state["bova_prosperity"] = level
		GameState.post_notice("Bova cresce: ora è \"%s\"!" % level_name(level))
		prosperity_changed.emit(level)
	town_changed.emit()


func _level_for(points: int) -> int:
	var level := 0
	for i in PROSPERITY_THRESHOLDS.size():
		if points >= PROSPERITY_THRESHOLDS[i]:
			level = i
	return level


func _on_cargo_sold(amount: int) -> void:
	_add_prosperity(amount / SALE_POINTS_DIVISOR)


## Azzeramento partita (GameState.reset): il world_state è già tornato ai
## default, qui si risvegliano le scene in ascolto.
func _on_world_reset() -> void:
	_tick_elapsed = 0.0
	_storage_full_notified = false
	town_changed.emit()
	prosperity_changed.emit(prosperity_level())


# --- Accesso allo stato (in GameState.world_state, salvato da B0) ------------

func _buildings() -> Dictionary:
	if not GameState.world_state.has("buildings"):
		GameState.world_state["buildings"] = {}
	return GameState.world_state["buildings"]


func _warehouse() -> Dictionary:
	if not GameState.world_state.has("warehouse"):
		GameState.world_state["warehouse"] = {}
	return GameState.world_state["warehouse"]
