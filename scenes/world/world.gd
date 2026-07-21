extends Node3D

## La zona di mare di M1: isole e porto piazzati a mano nella scena,
## scogli e punti boa sparsi proceduralmente con seed fisso (stessa mappa
## a ogni avvio, densità regolabile dall'Inspector). Le boe seguono il
## rischio della zona (GDD pillar 2): gialle in acque aperte, rosse ai
## margini dei campi di scogli, blu dentro i campi. Gestisce anche il
## confine mappa (countdown e recupero) e il traino a scafo zero.

const BUOY_SCENE: PackedScene = preload("res://scenes/buoy/buoy.tscn")
const ROCK_SCENE: PackedScene = preload("res://scenes/world/rock.tscn")

@export var boat: Boat
@export var sea: Sea

@export_group("Confini")
@export var bounds_radius: float = 240.0
## Secondi per rientrare in zona prima del recupero al porto.
@export var escape_countdown: float = 10.0

@export_group("Sparpagliamento")
@export var scatter_seed: int = 7
@export var yellow_buoy_count: int = 26
@export var red_points_per_field: int = 8
@export var blue_points_per_field: int = 6
@export var rocks_per_field: int = 9
@export var rock_field_radius: float = 13.0

var _rng := RandomNumberGenerator.new()
var _rock_positions: Array[Vector3] = []
var _buoy_positions: Array[Vector3] = []
## -1 quando la barca è dentro i confini.
var _outside_elapsed: float = -1.0

@onready var _islands: Node3D = $Islands
@onready var _rock_fields: Node3D = $RockFields
@onready var _port: Port = $Port


func _ready() -> void:
	_rng.seed = scatter_seed
	GameState.hull_depleted.connect(_on_hull_depleted)
	for field: Node3D in _rock_fields.get_children():
		_spawn_rock_field(field.global_position)
	for field: Node3D in _rock_fields.get_children():
		_spawn_field_buoys(field.global_position)
	_spawn_yellow_buoys()


func _physics_process(delta: float) -> void:
	if boat == null:
		return
	var outside := Vector2(boat.global_position.x, boat.global_position.z).length() > bounds_radius
	if outside:
		if _outside_elapsed < 0.0:
			_outside_elapsed = 0.0
		_outside_elapsed += delta
		var left := escape_countdown - _outside_elapsed
		boat.sink_amount = clampf(_outside_elapsed / escape_countdown, 0.0, 1.0)
		if left <= 0.0:
			_rescue_boat()
		else:
			GameState.set_danger("ACQUE PERICOLOSE! Torna indietro… %d" % ceili(left))
	elif _outside_elapsed >= 0.0:
		_outside_elapsed = -1.0
		boat.sink_amount = 0.0
		GameState.clear_danger()


func _on_hull_depleted() -> void:
	_tow_boat.call_deferred()


func _tow_boat() -> void:
	GameState.pay_tow()
	boat.reset_motion()
	boat.global_position = _port.tow_spawn_position()


## Recupero gratuito quando il countdown fuori zona scade: riporta al
## porto senza toccare scafo e denaro (niente punizione doppia).
func _rescue_boat() -> void:
	_outside_elapsed = -1.0
	boat.sink_amount = 0.0
	boat.reset_motion()
	boat.global_position = _port.tow_spawn_position()
	GameState.clear_danger()
	GameState.post_notice("Recuperato al largo e riportato al porto")


func _spawn_rock_field(center: Vector3) -> void:
	for i in rocks_per_field:
		var pos := _sample_ring(center, 0.0, rock_field_radius, _rock_positions, 3.0)
		if not pos.is_finite():
			continue
		var rock := ROCK_SCENE.instantiate() as Node3D
		add_child(rock)
		rock.global_position = Vector3(pos.x, _rng.randf_range(-0.5, 0.1), pos.z)
		rock.rotation.y = _rng.randf_range(0.0, TAU)
		rock.scale = Vector3.ONE * _rng.randf_range(0.7, 1.9)
		_rock_positions.append(pos)


## Blu dentro il campo di scogli, rosse nell'anello ai suoi margini.
func _spawn_field_buoys(center: Vector3) -> void:
	for i in blue_points_per_field:
		var pos := _sample_ring(center, 2.0, rock_field_radius, _buoy_positions, 5.0)
		if pos.is_finite() and _far_from(pos, _rock_positions, 2.5):
			_spawn_buoy(pos, GameState.BuoyType.BLUE)
	for i in red_points_per_field:
		var pos := _sample_ring(center, rock_field_radius + 2.0, rock_field_radius + 10.0, _buoy_positions, 6.0)
		if pos.is_finite():
			_spawn_buoy(pos, GameState.BuoyType.RED)


func _spawn_yellow_buoys() -> void:
	for i in yellow_buoy_count:
		var pos := _sample_ring(Vector3.ZERO, 25.0, bounds_radius * 0.85, _buoy_positions, 10.0)
		if pos.is_finite() and _is_open_water(pos):
			_spawn_buoy(pos, GameState.BuoyType.YELLOW)


func _spawn_buoy(pos: Vector3, type: int) -> void:
	var buoy := BUOY_SCENE.instantiate() as Buoy
	buoy.type = type
	buoy.sea = sea
	add_child(buoy)
	buoy.global_position = Vector3(pos.x, 0.0, pos.z)
	_buoy_positions.append(pos)


## Campiona un punto in un anello intorno a center, lontano almeno
## min_dist dai punti già occupati. Vector3.INF se non trova posto.
func _sample_ring(center: Vector3, r_min: float, r_max: float, taken: Array[Vector3], min_dist: float) -> Vector3:
	for attempt in 30:
		var angle := _rng.randf_range(0.0, TAU)
		var radius := _rng.randf_range(r_min, r_max)
		var pos := center + Vector3(cos(angle), 0.0, sin(angle)) * radius
		if _far_from(pos, taken, min_dist):
			return pos
	return Vector3.INF


func _far_from(pos: Vector3, points: Array[Vector3], min_dist: float) -> bool:
	for point in points:
		if pos.distance_to(point) < min_dist:
			return false
	return true


## Vero se il punto è lontano da isole, porto e campi di scogli: le boe
## gialle restano in acque tranquille.
func _is_open_water(pos: Vector3) -> bool:
	for island: Node3D in _islands.get_children():
		if pos.distance_to(island.global_position) < 14.0 * island.scale.x:
			return false
	if pos.distance_to(_port.global_position) < 26.0:
		return false
	for field: Node3D in _rock_fields.get_children():
		if pos.distance_to(field.global_position) < rock_field_radius + 12.0:
			return false
	return true
