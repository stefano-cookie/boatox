class_name ShipDirector
extends Node3D

## Popola il mare aperto (roadmap B1): tiene in acqua un numero fisso di
## mercantili (rotte tra le acque medie e il largo) e predoni (pattuglie
## solo al largo), e rimpiazza le navi affondate dopo una pausa — mai
## addosso al giocatore. Creato dal World, che gli passa mare, barca e
## confini della baia.

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
## Recinto di navigazione: mezzo lato x e profondità massima z della baia.
var half_width: float = 400.0
var depth_max: float = 600.0
var merchant_count: int = 2
var raider_count: int = 2

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for i in merchant_count:
		_spawn_merchant()
	for i in raider_count:
		_spawn_raider()


func _spawn_merchant() -> void:
	var ship := MERCHANT_SCENE.instantiate() as MerchantShip
	_setup_ship(ship, sea.calm_width + 40.0)
	ship.set_route(_make_route(sea.calm_width + 40.0))
	add_child(ship)
	ship.global_position = _spawn_point(ship)


func _spawn_raider() -> void:
	var ship := RAIDER_SCENE.instantiate() as RaiderShip
	_setup_ship(ship, sea.medium_width + 50.0)
	ship.target_boat = boat
	ship.set_route(_make_route(sea.medium_width + 50.0))
	add_child(ship)
	ship.global_position = _spawn_point(ship)


func _setup_ship(ship: Ship, z_min: float) -> void:
	ship.sea = sea
	ship.roam_min = Vector3(-half_width, 0.0, sea.shore_z + z_min)
	ship.roam_max = Vector3(half_width, 0.0, sea.shore_z + depth_max)
	ship.sunk.connect(_on_ship_sunk)


## Rotta ad anello di punti casuali nella fascia consentita.
func _make_route(z_min: float) -> Array[Vector3]:
	var route: Array[Vector3] = []
	for i in ROUTE_POINTS:
		route.append(Vector3(
			_rng.randf_range(-half_width, half_width), 0.0,
			sea.shore_z + _rng.randf_range(z_min, depth_max)))
	return route


## Primo waypoint della nave... ma mai addosso al giocatore: si ritenta
## qualche volta, poi pazienza (la baia è grande).
func _spawn_point(ship: Ship) -> Vector3:
	for attempt in 12:
		var pos := Vector3(
			_rng.randf_range(ship.roam_min.x, ship.roam_max.x), 0.0,
			_rng.randf_range(ship.roam_min.z, ship.roam_max.z))
		if boat == null or pos.distance_to(boat.global_position) >= SPAWN_CLEARANCE:
			return pos
	return Vector3(ship.roam_max.x * 0.8, 0.0, ship.roam_max.z * 0.9)


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
