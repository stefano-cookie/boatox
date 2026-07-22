extends Node

## Stato di partita e valori di bilanciamento dell'economia (CLAUDE.md:
## prezzi e curve vivono qui o nei .tres, mai nelle scene). Le boe sono
## item: vanno in stiva e diventano denaro solo vendendole al porto
## (GDD § core loop). Da M2 gestisce anche la flotta: barche possedute,
## upgrade per barca e salvataggio su file.

signal money_changed(amount: int)
signal hull_changed(current: float, max_value: float)
signal fuel_changed(current: float, max_value: float)
signal cargo_changed
signal hull_depleted
signal boat_changed(def: BoatDefinition)
signal notice_posted(text: String)
signal danger_changed(text: String)
signal danger_cleared
## Vero quando almeno un pannello con puntatore (porto, pesca, regata,
## pausa) è aperto: la ChaseCamera rilascia/ricattura il mouse su questo
## segnale, senza duplicare la logica in ogni pannello.
signal ui_focus_changed(open: bool)

## Tipologie di boa legate al rischio della zona (GDD pillar 2):
## gialla in acque tranquille, rossa ai margini degli scogli, blu
## rarissima dentro i campi di scogli.
enum BuoyType { YELLOW, RED, BLUE }

## Upgrade funzionali (GDD § Upgrade): ognuno si sente nella guida.
enum UpgradeType { MOTOR, HULL, STABILITY, CARGO }

## Specie di pesce (GDD § Pesca): ogni fascia di mare ha una specie
## comune e una pregiata che premia il tempismo perfetto.
enum FishType { SARDINE, BREAM, AMBERJACK, TUNA }

const BUOY_VALUE: Dictionary[int, int] = {
	BuoyType.YELLOW: 10,
	BuoyType.RED: 40,
	BuoyType.BLUE: 150,
}
## Probabilità che il punto boa sia occupato a ogni tentativo di spawn.
const BUOY_SPAWN_CHANCE: Dictionary[int, float] = {
	BuoyType.YELLOW: 1.0,
	BuoyType.RED: 0.3,
	BuoyType.BLUE: 0.05,
}
const BUOY_RESPAWN: Dictionary[int, float] = {
	BuoyType.YELLOW: 45.0,
	BuoyType.RED: 90.0,
	BuoyType.BLUE: 120.0,
}
const BUOY_NAME: Dictionary[int, String] = {
	BuoyType.YELLOW: "gialla",
	BuoyType.RED: "rossa",
	BuoyType.BLUE: "blu",
}
const BUOY_NAME_PLURAL: Dictionary[int, String] = {
	BuoyType.YELLOW: "gialle",
	BuoyType.RED: "rosse",
	BuoyType.BLUE: "blu",
}
## Colori BBCode per il dettaglio stiva (HUD e porto).
const BUOY_HEX: Dictionary[int, String] = {
	BuoyType.YELLOW: "ffd43b",
	BuoyType.RED: "ff7b6b",
	BuoyType.BLUE: "7da2ff",
}

const FISH_VALUE: Dictionary[int, int] = {
	FishType.SARDINE: 8,
	FishType.BREAM: 30,
	FishType.AMBERJACK: 90,
	FishType.TUNA: 250,
}
const FISH_NAME: Dictionary[int, String] = {
	FishType.SARDINE: "sardina",
	FishType.BREAM: "orata",
	FishType.AMBERJACK: "ricciola",
	FishType.TUNA: "tonno",
}
const FISH_NAME_PLURAL: Dictionary[int, String] = {
	FishType.SARDINE: "sardine",
	FishType.BREAM: "orate",
	FishType.AMBERJACK: "ricciole",
	FishType.TUNA: "tonni",
}
## Colori BBCode per il dettaglio stiva (HUD e porto).
const FISH_HEX: Dictionary[int, String] = {
	FishType.SARDINE: "b8c7d4",
	FishType.BREAM: "e8c37a",
	FishType.AMBERJACK: "8fd4c8",
	FishType.TUNA: "e07a7a",
}

## Pesca per fascia di mare (GDD pillar 2): più al largo pesci migliori,
## finestra di tempismo più stretta e cursore più rapido. Chiave: indice
## fascia di Sea.zone_index (0 = calme, 1 = medie, 2 = mosse).
const FISHING_COMMON: Dictionary[int, int] = {
	0: FishType.SARDINE,
	1: FishType.BREAM,
	2: FishType.AMBERJACK,
}
const FISHING_PRIZE: Dictionary[int, int] = {
	0: FishType.BREAM,
	1: FishType.AMBERJACK,
	2: FishType.TUNA,
}
## Larghezza della finestra di cattura, in frazione della barra (più
## stretta dal feedback playtest M3: la ferrata è solo la fase 1).
const FISHING_WINDOW: Dictionary[int, float] = {
	0: 0.22,
	1: 0.16,
	2: 0.12,
}
## Secondi per una traversata completa del cursore.
const FISHING_SWEEP_TIME: Dictionary[int, float] = {
	0: 1.1,
	1: 0.9,
	2: 0.7,
}
## Quota centrale della finestra che vale il pesce pregiato.
const FISHING_PRIZE_FRACTION: float = 0.4
## Catture per zona prima che i pesci se ne vadano, e secondi di riposo.
const FISHING_STOCK: int = 3
const FISHING_REST: float = 150.0

## Fase 2 della pesca, il duello (feedback playtest M3): tieni premuto E
## per recuperare, molla per far calare la tensione; a tensione piena
## troppo a lungo il filo si spezza. Per specie: reel_time = secondi di
## recupero effettivo, rise = tensione/s mentre si recupera, surge_* =
## scatti casuali (i pregiati strappano: bisogna mollare al momento
## giusto). Tutto qui, si bilancia senza toccare la scena.
const FISH_FIGHT: Dictionary[int, Dictionary] = {
	FishType.SARDINE: {"reel_time": 3.0, "rise": 0.35,
		"surge_interval": 0.0, "surge_duration": 0.0, "surge_rise": 0.0},
	FishType.BREAM: {"reel_time": 4.5, "rise": 0.45,
		"surge_interval": 3.2, "surge_duration": 1.0, "surge_rise": 0.6},
	FishType.AMBERJACK: {"reel_time": 6.0, "rise": 0.5,
		"surge_interval": 2.6, "surge_duration": 1.4, "surge_rise": 0.7},
	FishType.TUNA: {"reel_time": 8.0, "rise": 0.6,
		"surge_interval": 2.2, "surge_duration": 1.8, "surge_rise": 0.85},
}
## Discesa della tensione a lenza mollata, in frazione/s.
const FISH_TENSION_FALL: float = 0.9
## Il pesce riprende lenza mentre molli: progresso perso in frazione/s.
const FISH_PROGRESS_DECAY: float = 0.05
## Secondi concessi a tensione piena prima che il filo si spezzi.
const FISH_SNAP_GRACE: float = 0.45

## Regata (GDD § Corse): premi per piazzamento e avversari IA. Le IA non
## hanno velocità assolute ma frazioni della velocità effettiva del
## giocatore al via (feedback playtest M3): la gara resta combattuta con
## ogni barca e upgrade — vincere richiede traiettorie, non solo motore.
## speed_ratio moltiplica effective_max_speed(), stability_delta si somma
## a effective_stability() (clampata 0..1).
const RACE_PRIZES: Array[int] = [300, 120, 50]
## Moltiplicatore dei premi per tier di barca (indice in BOAT_DEFS): la
## regata resta redditizia senza diventare farming facile.
const RACE_PRIZE_TIER_MULT: Array[float] = [1.0, 1.6, 2.4]
const RACE_AI: Array[Dictionary] = [
	{"name": "Ciccio", "visual": "res://scenes/boat/visuals/dinghy_visual.tscn",
		"speed_ratio": 0.90, "stability_delta": -0.1, "turn": 60.0},
	{"name": "Rosa", "visual": "res://scenes/boat/visuals/dinghy_visual.tscn",
		"speed_ratio": 0.97, "stability_delta": 0.0, "turn": 55.0},
	{"name": "Turi", "visual": "res://scenes/boat/visuals/fishing_visual.tscn",
		"speed_ratio": 1.03, "stability_delta": 0.15, "turn": 50.0},
]

const UPGRADE_NAME: Dictionary[int, String] = {
	UpgradeType.MOTOR: "Motore",
	UpgradeType.HULL: "Scafo",
	UpgradeType.STABILITY: "Stabilità",
	UpgradeType.CARGO: "Stiva",
}

## Ordine di progressione: è anche l'ordine di listino del cantiere.
const BOAT_DEFS: Array[BoatDefinition] = [
	preload("res://resources/boats/dinghy.tres"),
	preload("res://resources/boats/fishing_boat.tres"),
	preload("res://resources/boats/cruiser.tres"),
]

## Riparare tutto lo scafo da zero costa hull_max * questo valore.
const REPAIR_COST_PER_POINT: float = 0.5
const FUEL_PRICE_PER_LITER: float = 1.0
## Litri restituiti da una tanica trovata in mare.
const FUEL_CAN_LITERS: float = 15.0
## Probabilità che un punto tanica sia occupato a ogni ciclo (roadmap: 5%).
const FUEL_CAN_SPAWN_CHANCE: float = 0.05
const FUEL_CAN_RESPAWN: float = 60.0
const TOW_FEE: int = 30
## Scafo restituito dal traino: quanto basta per ripartire, non di più.
const TOW_HULL_RESTORE: float = 20.0
## Recupero dopo l'affondamento al largo (feedback playtest M3): più caro
## del traino, e il carico è perso — il vero rischio del mare aperto.
const SALVAGE_FEE: int = 100

const SAVE_VERSION: int = 1
## Var e non const: i test headless la reindirizzano su un file proprio
## per non toccare (e cancellare!) il salvataggio vero del giocatore.
var save_path: String = "user://save.json"

var money: int = 0
var hull: float = 100.0
var fuel: float = 40.0
## Conteggio boe in stiva per tipologia (chiave: BuoyType).
var cargo: Dictionary[int, int] = {}
## Conteggio pesci in stiva per specie (chiave: FishType); condivide la
## capacità con le boe: la stiva è una sola (GDD § Pesca).
var fish_cargo: Dictionary[int, int] = {}

## Vittorie in regata: la prima sblocca le barche con requires_race_win.
var race_wins: int = 0

var owned_boats: Array[StringName] = [&"dinghy"]
var current_boat_id: StringName = &"dinghy"
## Livelli upgrade per barca: id barca -> { UpgradeType -> livello }.
var upgrades: Dictionary[StringName, Dictionary] = {}


func _ready() -> void:
	load_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


# --- Flotta e statistiche effettive -----------------------------------------

func boat_def(id: StringName) -> BoatDefinition:
	for def in BOAT_DEFS:
		if def.id == id:
			return def
	push_error("Barca sconosciuta: %s" % id)
	return BOAT_DEFS[0]


func current_def() -> BoatDefinition:
	return boat_def(current_boat_id)


func owns_boat(id: StringName) -> bool:
	return owned_boats.has(id)


func upgrade_level(type: int, boat_id: StringName = current_boat_id) -> int:
	var boat_upgrades: Dictionary = upgrades.get(boat_id, {})
	return boat_upgrades.get(type, 0)


func upgrade_max_level(type: int, boat_id: StringName = current_boat_id) -> int:
	return _upgrade_costs(boat_def(boat_id), type).size()


## Costo del prossimo livello; -1 se l'upgrade è già al massimo.
func upgrade_cost(type: int, boat_id: StringName = current_boat_id) -> int:
	var costs := _upgrade_costs(boat_def(boat_id), type)
	var level := upgrade_level(type, boat_id)
	if level >= costs.size():
		return -1
	return costs[level]


func effective_max_speed() -> float:
	var def := current_def()
	return def.max_speed + upgrade_level(UpgradeType.MOTOR) * def.motor_speed_step


func effective_acceleration() -> float:
	var def := current_def()
	return def.acceleration + upgrade_level(UpgradeType.MOTOR) * def.motor_accel_step


func hull_max() -> float:
	var def := current_def()
	return def.hull_max + upgrade_level(UpgradeType.HULL) * def.hull_step


func effective_stability() -> float:
	var def := current_def()
	return clampf(def.stability + upgrade_level(UpgradeType.STABILITY) * def.stability_step, 0.0, 1.0)


func cargo_capacity() -> int:
	var def := current_def()
	return def.cargo_capacity + upgrade_level(UpgradeType.CARGO) * def.cargo_step


func fuel_capacity() -> float:
	return current_def().fuel_capacity


## Vero se la barca è acquistabile: alcune chiedono una vittoria in
## regata (GDD § Corse: vincere sblocca contenuti).
func boat_unlocked(id: StringName) -> bool:
	return not boat_def(id).requires_race_win or race_wins > 0


func buy_boat(id: StringName) -> bool:
	var def := boat_def(id)
	if owns_boat(id) or money < def.price or not boat_unlocked(id):
		return false
	money -= def.price
	owned_boats.append(id)
	money_changed.emit(money)
	post_notice("%s acquistato!" % def.display_name)
	select_boat(id)
	return true


## Cambio barca: scafo e benzina mantengono la percentuale (niente
## riparazioni o pieni gratis facendo avanti e indietro tra le barche).
func select_boat(id: StringName) -> void:
	if not owns_boat(id) or id == current_boat_id:
		return
	var hull_ratio := hull / hull_max()
	var fuel_ratio := fuel / fuel_capacity()
	current_boat_id = id
	hull = hull_ratio * hull_max()
	fuel = fuel_ratio * fuel_capacity()
	boat_changed.emit(current_def())
	hull_changed.emit(hull, hull_max())
	fuel_changed.emit(fuel, fuel_capacity())
	cargo_changed.emit()
	save_game()


func buy_upgrade(type: int) -> bool:
	var cost := upgrade_cost(type)
	if cost < 0 or money < cost:
		return false
	money -= cost
	var boat_upgrades: Dictionary = upgrades.get(current_boat_id, {})
	boat_upgrades[type] = boat_upgrades.get(type, 0) + 1
	upgrades[current_boat_id] = boat_upgrades
	if type == UpgradeType.HULL:
		# I punti scafo aggiunti arrivano integri: il danno resta assoluto.
		hull += current_def().hull_step
	money_changed.emit(money)
	boat_changed.emit(current_def())
	hull_changed.emit(hull, hull_max())
	cargo_changed.emit()
	post_notice("%s livello %d installato" % [UPGRADE_NAME[type], upgrade_level(type)])
	save_game()
	return true


func _upgrade_costs(def: BoatDefinition, type: int) -> Array[int]:
	match type:
		UpgradeType.MOTOR:
			return def.motor_costs
		UpgradeType.HULL:
			return def.hull_costs
		UpgradeType.STABILITY:
			return def.stability_costs
		_:
			return def.cargo_costs


# --- Stiva e denaro ----------------------------------------------------------

## Falso se la stiva è piena: la boa resta in acqua (il limite di stiva
## è il senso dell'upgrade omonimo).
func collect_buoy(type: int) -> bool:
	if cargo_count() >= cargo_capacity():
		post_notice("Stiva piena! Vendi al porto")
		return false
	cargo[type] = cargo.get(type, 0) + 1
	if type == BuoyType.BLUE:
		post_notice("Boa blu! Rarissima: +%d $ di carico" % BUOY_VALUE[type])
	cargo_changed.emit()
	return true


## Falso a stiva piena, come per le boe: il pesce resta in acqua.
func collect_fish(type: int) -> bool:
	if cargo_count() >= cargo_capacity():
		post_notice("Stiva piena! Vendi al porto")
		return false
	fish_cargo[type] = fish_cargo.get(type, 0) + 1
	cargo_changed.emit()
	return true


func cargo_count() -> int:
	var total := 0
	for type in cargo:
		total += cargo[type]
	for type in fish_cargo:
		total += fish_cargo[type]
	return total


func cargo_value() -> int:
	var total := 0
	for type in cargo:
		total += cargo[type] * BUOY_VALUE[type]
	for type in fish_cargo:
		total += fish_cargo[type] * FISH_VALUE[type]
	return total


## Dettaglio stiva in BBCode ("2× gialle · 1× tonno"), condiviso da HUD
## e pannello del porto: cosa hai raccolto si capisce a colpo d'occhio.
func cargo_detail_bbcode() -> String:
	var parts: Array[String] = []
	for type: int in BuoyType.values():
		var count: int = cargo.get(type, 0)
		if count <= 0:
			continue
		var buoy_name: String = BUOY_NAME[type] if count == 1 else BUOY_NAME_PLURAL[type]
		parts.append("[color=#%s]%d× %s[/color]" % [BUOY_HEX[type], count, buoy_name])
	for type: int in FishType.values():
		var count: int = fish_cargo.get(type, 0)
		if count <= 0:
			continue
		var fish_name: String = FISH_NAME[type] if count == 1 else FISH_NAME_PLURAL[type]
		parts.append("[color=#%s]%d× %s[/color]" % [FISH_HEX[type], count, fish_name])
	return " · ".join(parts)


func sell_cargo() -> int:
	var earned := cargo_value()
	if earned <= 0:
		return 0
	money += earned
	cargo.clear()
	fish_cargo.clear()
	money_changed.emit(money)
	cargo_changed.emit()
	post_notice("Carico venduto: +%d $" % earned)
	return earned


func repair_cost() -> int:
	return ceili((hull_max() - hull) * REPAIR_COST_PER_POINT)


func repair_hull() -> void:
	var missing := hull_max() - hull
	if missing <= 0.0 or money <= 0:
		return
	var full_cost := repair_cost()
	if money >= full_cost:
		money -= full_cost
		hull = hull_max()
	else:
		hull += float(money) / REPAIR_COST_PER_POINT
		money = 0
	money_changed.emit(money)
	hull_changed.emit(hull, hull_max())


# --- Regata ------------------------------------------------------------------

## Tier della barca: il suo indice nell'ordine di progressione BOAT_DEFS.
func boat_tier(id: StringName = current_boat_id) -> int:
	for i in BOAT_DEFS.size():
		if BOAT_DEFS[i].id == id:
			return i
	return 0


## Premio per piazzamento, scalato col tier della barca corrente
## (feedback playtest M3): la regata rende anche a fine progressione.
func race_prize(rank: int) -> int:
	if rank - 1 >= RACE_PRIZES.size():
		return 0
	return roundi(RACE_PRIZES[rank - 1] * RACE_PRIZE_TIER_MULT[boat_tier()])


## Piazzamento a fine gara: accredita il premio e conta le vittorie
## (la prima sblocca il Cabinato in cantiere).
func record_race_result(rank: int, total: int) -> void:
	var prize := race_prize(rank)
	if prize > 0:
		money += prize
		money_changed.emit(money)
	if rank == 1:
		race_wins += 1
		if race_wins == 1:
			post_notice("Prima vittoria! Il Cabinato è sbloccato in cantiere")
		else:
			post_notice("Regata vinta: +%d $" % prize)
	else:
		post_notice("Regata: %d° su %d (+%d $)" % [rank, total, prize])
	save_game()


# --- Carburante --------------------------------------------------------------

func consume_fuel(amount: float) -> void:
	if fuel <= 0.0 or amount <= 0.0:
		return
	fuel = maxf(fuel - amount, 0.0)
	fuel_changed.emit(fuel, fuel_capacity())
	if fuel <= 0.0:
		post_notice("Serbatoio vuoto! Vai in riserva d'emergenza: torna al porto")


## Tanica trovata in mare (o rifornimento parziale): non oltre il pieno.
func add_fuel(amount: float) -> void:
	if amount <= 0.0:
		return
	fuel = minf(fuel + amount, fuel_capacity())
	fuel_changed.emit(fuel, fuel_capacity())


func refuel_cost() -> int:
	return ceili((fuel_capacity() - fuel) * FUEL_PRICE_PER_LITER)


## Pieno al porto; se i soldi non bastano si riempie quel che si può.
func refuel() -> void:
	var missing := fuel_capacity() - fuel
	if missing <= 0.0 or money <= 0:
		return
	var full_cost := refuel_cost()
	if money >= full_cost:
		money -= full_cost
		fuel = fuel_capacity()
	else:
		fuel += float(money) / FUEL_PRICE_PER_LITER
		money = 0
	money_changed.emit(money)
	fuel_changed.emit(fuel, fuel_capacity())


func apply_damage(amount: float) -> void:
	if hull <= 0.0 or amount <= 0.0:
		return
	hull = maxf(hull - amount, 0.0)
	hull_changed.emit(hull, hull_max())
	if hull <= 0.0:
		hull_depleted.emit()


func pay_tow() -> void:
	money = maxi(money - TOW_FEE, 0)
	hull = TOW_HULL_RESTORE
	money_changed.emit(money)
	hull_changed.emit(hull, hull_max())
	post_notice("Scafo a pezzi: rimorchiato al porto (-%d $)" % TOW_FEE)


## Affondamento al largo (feedback playtest M3): il carico va perso e il
## recupero costa più del traino. Chiamato dal World a barca già in porto.
func salvage_after_sinking() -> void:
	var lost := cargo_value()
	cargo.clear()
	fish_cargo.clear()
	money = maxi(money - SALVAGE_FEE, 0)
	hull = TOW_HULL_RESTORE
	money_changed.emit(money)
	hull_changed.emit(hull, hull_max())
	cargo_changed.emit()
	if lost > 0:
		post_notice("Affondato! Carico perso (%d $) · recupero -%d $" % [lost, SALVAGE_FEE])
	else:
		post_notice("Affondato! Recupero al porto -%d $" % SALVAGE_FEE)
	save_game()


# --- Salvataggio -------------------------------------------------------------

func save_game() -> void:
	var cargo_out: Dictionary = {}
	for type in cargo:
		cargo_out[str(type)] = cargo[type]
	var fish_out: Dictionary = {}
	for type in fish_cargo:
		fish_out[str(type)] = fish_cargo[type]
	var upgrades_out: Dictionary = {}
	for boat_id in upgrades:
		var levels: Dictionary = {}
		for type in upgrades[boat_id]:
			levels[str(type)] = upgrades[boat_id][type]
		upgrades_out[String(boat_id)] = levels
	var owned_out: Array[String] = []
	for id in owned_boats:
		owned_out.append(String(id))
	var data := {
		"version": SAVE_VERSION,
		"money": money,
		"hull": hull,
		"fuel": fuel,
		"cargo": cargo_out,
		"fish": fish_out,
		"race_wins": race_wins,
		"owned_boats": owned_out,
		"current_boat": String(current_boat_id),
		"upgrades": upgrades_out,
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("Salvataggio fallito: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data, "\t"))


## Carica il salvataggio se esiste e non emette segnali: si chiama solo
## all'avvio dell'autoload, prima che le scene si registrino.
func load_game() -> void:
	if not FileAccess.file_exists(save_path):
		hull = hull_max()
		fuel = fuel_capacity()
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	var data: Variant = JSON.parse_string(file.get_as_text())
	if data == null or not data is Dictionary:
		push_error("Salvataggio corrotto, si riparte da zero")
		hull = hull_max()
		fuel = fuel_capacity()
		return
	money = int(data.get("money", 0))
	race_wins = int(data.get("race_wins", 0))
	current_boat_id = StringName(data.get("current_boat", "dinghy"))
	owned_boats.clear()
	for id: String in data.get("owned_boats", ["dinghy"]):
		owned_boats.append(StringName(id))
	if not owns_boat(&"dinghy"):
		owned_boats.append(&"dinghy")
	if not owns_boat(current_boat_id):
		current_boat_id = &"dinghy"
	upgrades.clear()
	var upgrades_in: Dictionary = data.get("upgrades", {})
	for boat_id: String in upgrades_in:
		var levels: Dictionary = {}
		for type: String in upgrades_in[boat_id]:
			levels[int(type)] = int(upgrades_in[boat_id][type])
		upgrades[StringName(boat_id)] = levels
	cargo.clear()
	var cargo_in: Dictionary = data.get("cargo", {})
	for type: String in cargo_in:
		cargo[int(type)] = int(cargo_in[type])
	fish_cargo.clear()
	var fish_in: Dictionary = data.get("fish", {})
	for type: String in fish_in:
		fish_cargo[int(type)] = int(fish_in[type])
	hull = clampf(float(data.get("hull", hull_max())), 0.0, hull_max())
	# Salvataggi pre-benzina: si riparte col pieno.
	fuel = clampf(float(data.get("fuel", fuel_capacity())), 0.0, fuel_capacity())


func delete_save() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)


## Riporta la partita allo stato iniziale e cancella il salvataggio
## (usato dal "Ricomincia" della pausa: gli autoload sopravvivono al
## reload della scena).
func reset() -> void:
	money = 0
	race_wins = 0
	cargo.clear()
	fish_cargo.clear()
	owned_boats.clear()
	owned_boats.append(&"dinghy")
	current_boat_id = &"dinghy"
	upgrades.clear()
	hull = hull_max()
	fuel = fuel_capacity()
	_ui_focus_count = 0
	delete_save()
	money_changed.emit(money)
	hull_changed.emit(hull, hull_max())
	fuel_changed.emit(fuel, fuel_capacity())
	cargo_changed.emit()
	boat_changed.emit(current_def())
	clear_danger()


func post_notice(text: String) -> void:
	notice_posted.emit(text)


# --- Focus UI (mouse) --------------------------------------------------------

## Conteggio dei pannelli aperti: le chiamate vanno sempre in coppia
## (aperto/chiuso) da ogni pannello.
var _ui_focus_count: int = 0


func push_ui_focus() -> void:
	_ui_focus_count += 1
	if _ui_focus_count == 1:
		ui_focus_changed.emit(true)


func pop_ui_focus() -> void:
	if _ui_focus_count <= 0:
		return
	_ui_focus_count -= 1
	if _ui_focus_count == 0:
		ui_focus_changed.emit(false)


func ui_focus_open() -> bool:
	return _ui_focus_count > 0


## Avviso persistente a schermo (es. countdown fuori zona), aggiornato
## dal chiamante finché la condizione dura.
func set_danger(text: String) -> void:
	danger_changed.emit(text)


func clear_danger() -> void:
	danger_cleared.emit()
