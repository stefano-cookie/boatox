extends Node

## Stato di partita e valori di bilanciamento dell'economia (CLAUDE.md:
## prezzi e curve vivono qui, mai nelle scene). Le boe raccolte vanno in
## stiva e diventano denaro solo vendendole al porto: rientrare fa parte
## del loop (GDD § core loop).

signal money_changed(amount: int)
signal hull_changed(current: float, max_value: float)
signal cargo_changed(common: int, golden: int)
signal hull_depleted
signal notice_posted(text: String)

const HULL_MAX: float = 100.0

const BUOY_COMMON_VALUE: int = 10
const BUOY_GOLDEN_VALUE: int = 50
const BUOY_COMMON_RESPAWN: float = 45.0
const BUOY_GOLDEN_RESPAWN: float = 150.0

## Riparare tutto lo scafo da zero costa HULL_MAX * questo valore.
const REPAIR_COST_PER_POINT: float = 0.5
const TOW_FEE: int = 30
## Scafo restituito dal traino: quanto basta per ripartire, non di più.
const TOW_HULL_RESTORE: float = 20.0

var money: int = 0
var hull: float = HULL_MAX
var cargo_common: int = 0
var cargo_golden: int = 0


func collect_buoy(golden: bool) -> void:
	if golden:
		cargo_golden += 1
		post_notice("Boa dorata in stiva! (+%d $ di carico)" % BUOY_GOLDEN_VALUE)
	else:
		cargo_common += 1
	cargo_changed.emit(cargo_common, cargo_golden)


func cargo_count() -> int:
	return cargo_common + cargo_golden


func cargo_value() -> int:
	return cargo_common * BUOY_COMMON_VALUE + cargo_golden * BUOY_GOLDEN_VALUE


func sell_cargo() -> int:
	var earned := cargo_value()
	if earned <= 0:
		return 0
	money += earned
	cargo_common = 0
	cargo_golden = 0
	money_changed.emit(money)
	cargo_changed.emit(cargo_common, cargo_golden)
	post_notice("Carico venduto: +%d $" % earned)
	return earned


func repair_cost() -> int:
	return ceili((HULL_MAX - hull) * REPAIR_COST_PER_POINT)


func repair_hull() -> void:
	var missing := HULL_MAX - hull
	if missing <= 0.0 or money <= 0:
		return
	var full_cost := repair_cost()
	if money >= full_cost:
		money -= full_cost
		hull = HULL_MAX
	else:
		hull += float(money) / REPAIR_COST_PER_POINT
		money = 0
	money_changed.emit(money)
	hull_changed.emit(hull, HULL_MAX)


func apply_damage(amount: float) -> void:
	if hull <= 0.0 or amount <= 0.0:
		return
	hull = maxf(hull - amount, 0.0)
	hull_changed.emit(hull, HULL_MAX)
	if hull <= 0.0:
		hull_depleted.emit()


func pay_tow() -> void:
	money = maxi(money - TOW_FEE, 0)
	hull = TOW_HULL_RESTORE
	money_changed.emit(money)
	hull_changed.emit(hull, HULL_MAX)
	post_notice("Scafo a pezzi: rimorchiato al porto (-%d $)" % TOW_FEE)


func post_notice(text: String) -> void:
	notice_posted.emit(text)
