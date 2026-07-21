extends Node3D

## La zona di mare di M1: isole e porto piazzati a mano nella scena,
## scogli e boe sparsi proceduralmente con seed fisso (stessa mappa a
## ogni avvio, ma densità regolabile dall'Inspector). Le boe comuni
## stanno in acque aperte, le dorate dentro i campi di scogli (GDD
## pillar 2: il bottino migliore vicino al pericolo). Gestisce anche il
## traino al porto quando lo scafo va a zero.

const BUOY_SCENE: PackedScene = preload("res://scenes/buoy/buoy.tscn")
const ROCK_SCENE: PackedScene = preload("res://scenes/world/rock.tscn")

@export var boat: Boat
@export var sea: Sea

@export_group("Confini")
@export var bounds_radius: float = 240.0

@export_group("Sparpagliamento")
@export var scatter_seed: int = 7
@export var common_buoy_count: int = 26
@export var golden_per_field: int = 3
@export var rocks_per_field: int = 9
@export var rock_field_radius: float = 13.0

var _rng := RandomNumberGenerator.new()
var _rock_positions: Array[Vector3] = []
var _buoy_positions: Array[Vector3] = []

@onready var _islands: Node3D = $Islands
@onready var _rock_fields: Node3D = $RockFields
@onready var _port: Port = $Port


func _ready() -> void:
	_rng.seed = scatter_seed
	if boat != null:
		boat.bounds_radius = bounds_radius
	GameState.hull_depleted.connect(_on_hull_depleted)
	for field: Node3D in _rock_fields.get_children():
		_spawn_rock_field(field.global_position)
	for field: Node3D in _rock_fields.get_children():
		_spawn_golden_buoys(field.global_position)
	_spawn_common_buoys()


func _on_hull_depleted() -> void:
	_tow_boat.call_deferred()


func _tow_boat() -> void:
	GameState.pay_tow()
	boat.reset_motion()
	boat.global_position = _port.tow_spawn_position()


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


func _spawn_golden_buoys(center: Vector3) -> void:
	for i in golden_per_field:
		var pos := _sample_ring(center, 4.0, rock_field_radius + 3.0, _buoy_positions, 5.0)
		if not pos.is_finite() or not _far_from(pos, _rock_positions, 2.5):
			continue
		_spawn_buoy(pos, true)


func _spawn_common_buoys() -> void:
	for i in common_buoy_count:
		var pos := _sample_ring(Vector3.ZERO, 25.0, bounds_radius * 0.85, _buoy_positions, 10.0)
		if pos.is_finite() and _is_open_water(pos):
			_spawn_buoy(pos, false)


func _spawn_buoy(pos: Vector3, golden: bool) -> void:
	var buoy := BUOY_SCENE.instantiate() as Buoy
	buoy.golden = golden
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
## comuni restano in acque sicure.
func _is_open_water(pos: Vector3) -> bool:
	for island: Node3D in _islands.get_children():
		if pos.distance_to(island.global_position) < 14.0 * island.scale.x:
			return false
	if pos.distance_to(_port.global_position) < 26.0:
		return false
	for field: Node3D in _rock_fields.get_children():
		if pos.distance_to(field.global_position) < rock_field_radius + 8.0:
			return false
	return true
