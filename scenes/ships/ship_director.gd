class_name ShipDirector
extends Node3D

## Popola una zona di mare (roadmap B1, allargato in B4): tiene in acqua
## un numero fisso di mercantili (rotte ad anello) e predoni (pattuglie)
## dentro un recinto rettangolare, e rimpiazza le navi affondate dopo una
## pausa — mai addosso al giocatore. Creato dal World, che ne monta uno
## per zona: la baia di Bova, la traversata di mezzo e le acque delle due
## città lontane, ognuno col suo recinto e la sua fazione.

const MERCHANT_SCENE: PackedScene = preload("res://scenes/ships/merchant_ship.tscn")
const RAIDER_SCENE: PackedScene = preload("res://scenes/ships/raider_ship.tscn")

## Secondi (min/max) prima che una nave affondata venga rimpiazzata.
const RESPAWN_MIN: float = 50.0
const RESPAWN_MAX: float = 110.0
## Le navi non spawnano mai più vicine di così al giocatore.
const SPAWN_CLEARANCE: float = 90.0
## Waypoint per rotta.
const ROUTE_POINTS: int = 4

## Impostati dal World prima di add_child.
var sea: Sea
var boat: Boat
## Recinto di navigazione in coordinate mondo (x e z; y ignorata).
var area_min: Vector3 = Vector3(-400.0, 0.0, 0.0)
var area_max: Vector3 = Vector3(400.0, 0.0, 600.0)
var merchant_count: int = 2
var raider_count: int = 2
## Fazione delle navi di questa zona (vuota = quella della definizione):
## le città di B4 marchiano le proprie flotte, la diplomazia le leggerà.
var faction_override: StringName = &""

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for i in merchant_count:
		_spawn_merchant()
	for i in raider_count:
		_spawn_raider()


## I mercantili restano fuori dalle acque calme sotto costa, i predoni
## anche fuori dalle medie: nel recinto della baia il clamp morde, nelle
## zone lontane dal litorale è un no-op (il recinto è già al largo).
func _spawn_merchant() -> void:
	var ship := MERCHANT_SCENE.instantiate() as MerchantShip
	_setup_ship(ship, sea.shore_z + sea.calm_width + 40.0)
	ship.set_route(_make_route(ship.roam_min.z))
	_launch_ship(ship)


func _spawn_raider() -> void:
	var ship := RAIDER_SCENE.instantiate() as RaiderShip
	_setup_ship(ship, sea.shore_z + sea.medium_width + 50.0)
	ship.target_boat = boat
	ship.set_route(_make_route(ship.roam_min.z))
	_launch_ship(ship)


func _setup_ship(ship: Ship, z_min_abs: float) -> void:
	ship.sea = sea
	ship.roam_min = Vector3(area_min.x, 0.0, maxf(area_min.z, z_min_abs))
	ship.roam_max = Vector3(area_max.x, 0.0, area_max.z)
	ship.sunk.connect(_on_ship_sunk)


## La fazione si marchia dopo add_child: il _ready della nave la prende
## dalla definizione e sovrascriverebbe l'override della zona.
func _launch_ship(ship: Ship) -> void:
	add_child(ship)
	if faction_override != &"":
		ship.faction = faction_override
	ship.global_position = _spawn_point(ship)


## Rotta ad anello di punti casuali nel recinto.
func _make_route(z_min: float) -> Array[Vector3]:
	var route: Array[Vector3] = []
	for i in ROUTE_POINTS:
		route.append(Vector3(
			_rng.randf_range(area_min.x, area_max.x), 0.0,
			_rng.randf_range(z_min, area_max.z)))
	return route


## Primo waypoint della nave... ma mai addosso al giocatore: si ritenta
## qualche volta, poi pazienza (il mare è grande).
func _spawn_point(ship: Ship) -> Vector3:
	for attempt in 12:
		var pos := Vector3(
			_rng.randf_range(ship.roam_min.x, ship.roam_max.x), 0.0,
			_rng.randf_range(ship.roam_min.z, ship.roam_max.z))
		if boat == null or pos.distance_to(boat.global_position) >= SPAWN_CLEARANCE:
			return pos
	return Vector3(lerpf(ship.roam_min.x, ship.roam_max.x, 0.8), 0.0,
		lerpf(ship.roam_min.z, ship.roam_max.z, 0.9))


## Nave affondata: dopo una pausa ne salpa una nuova dello stesso tipo.
func _on_ship_sunk(ship: Ship) -> void:
	var is_raider := ship is RaiderShip
	var timer := get_tree().create_timer(_rng.randf_range(RESPAWN_MIN, RESPAWN_MAX))
	timer.timeout.connect(_respawn.bind(is_raider))


func _respawn(is_raider: bool) -> void:
	if not is_inside_tree():
		return
	if is_raider:
		_spawn_raider()
	else:
		_spawn_merchant()
