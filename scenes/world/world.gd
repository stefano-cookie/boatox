class_name World
extends Node3D

## La baia di gioco: la costa a nord (scena Coast), isole e porto
## piazzati a mano, scogli e punti boa sparsi proceduralmente con seed
## fisso (stessa mappa a ogni avvio, densità regolabile dall'Inspector).
## Le boe seguono le fasce di mare della Sea (GDD pillar 2): gialle
## nelle acque calme sotto costa, rosse nelle medie, blu nelle mosse al
## largo — dove stanno anche isole e campi di scogli. Gestisce anche il
## confine mappa (countdown e recupero), l'allarme tempesta e il traino
## a scafo zero.

const BUOY_SCENE: PackedScene = preload("res://scenes/buoy/buoy.tscn")
const ROCK_SCENE: PackedScene = preload("res://scenes/world/rock.tscn")
const FUEL_CAN_SCENE: PackedScene = preload("res://scenes/fuel/fuel_can.tscn")
const FISHING_ZONE_SCENE: PackedScene = preload("res://scenes/fishing/fishing_zone.tscn")

@export var boat: Boat
@export var sea: Sea

@export_group("Confini")
## Distanza massima dalla costa prima del countdown di recupero.
@export var bounds_depth: float = 700.0
## Mezza larghezza della baia giocabile (oltre i promontori si è fuori).
@export var bounds_half_width: float = 450.0
## Secondi per rientrare in zona prima del recupero al porto.
@export var escape_countdown: float = 10.0

@export_group("Affondamento")
## A scafo zero oltre le acque medie la barca affonda (feedback playtest
## M3): carico perso e recupero a pagamento. Sotto costa resta il traino.
@export var sink_time: float = 2.0

@export_group("Sparpagliamento")
@export var scatter_seed: int = 7
## Feedback playtest round 2: le gialle intasavano la mappa (28 → 14).
@export var yellow_buoy_count: int = 14
@export var red_point_count: int = 18
@export var blue_point_count: int = 24
## Punti tanica di benzina, sparsi su tutta la baia (spawn al 5%).
@export var fuel_point_count: int = 22
## Zone di pesca per fascia di mare (GDD beta: 2-3 zone in tutto).
@export var fishing_zones_per_band: int = 1
## Le boe vengono campionate con |x| entro questo limite, per non
## finire dentro i promontori.
@export var scatter_half_width: float = 255.0
## Al largo i promontori sono lontani: si campiona più largo, per non
## diluire la densità della baia profonda.
@export var scatter_half_width_open: float = 400.0
@export var rocks_per_field: int = 9
@export var rock_field_radius: float = 13.0

var _rng := RandomNumberGenerator.new()
var _rock_positions: Array[Vector3] = []
var _buoy_positions: Array[Vector3] = []
var _fishing_positions: Array[Vector3] = []
## -1 quando la barca è dentro i confini.
var _outside_elapsed: float = -1.0
var _storm_alarmed: bool = false
var _sinking: bool = false

@onready var _islands: Node3D = $Islands
@onready var _rock_fields: Node3D = $RockFields
@onready var _port: Port = $Port


func _ready() -> void:
	_rng.seed = scatter_seed
	# Ogni spot di gara (sotto costa + al largo) ha bisogno della Sea per
	# IA e classifica: i figli sono già in gruppo (add_to_group in _ready).
	for node in get_tree().get_nodes_in_group(&"race_course"):
		(node as RaceCourse).sea = sea
	GameState.hull_depleted.connect(_on_hull_depleted)
	for field: Node3D in _rock_fields.get_children():
		_spawn_rock_field(field.global_position)
	# Le zone di pesca prima delle boe: prendono posto pulito e le boe
	# non finiscono dentro gli anelli.
	_spawn_fishing_zones()
	_spawn_zone_buoys()


func _physics_process(delta: float) -> void:
	if boat == null or _sinking:
		return
	var pos := boat.global_position
	var outside := sea.shore_distance(pos) > bounds_depth or absf(pos.x) > bounds_half_width
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
		return
	if _outside_elapsed >= 0.0:
		_outside_elapsed = -1.0
		boat.sink_amount = 0.0
		GameState.clear_danger()
	# Allarme tempesta: il mare sta danneggiando lo scafo (la logica del
	# danno vive nella barca, qui solo il messaggio — la priorità resta
	# al countdown fuori zona).
	if boat.storm_alarm():
		_storm_alarmed = true
		GameState.set_danger("TEMPESTA! Lo scafo sta cedendo: punta verso la costa!")
	elif _storm_alarmed:
		_storm_alarmed = false
		GameState.clear_danger()


# --- Dati per la minimappa ---------------------------------------------------

func port_position() -> Vector3:
	return _port.global_position


func map_islands() -> Array[Node]:
	return _islands.get_children()


func map_rocks() -> Array[Vector3]:
	return _rock_positions


## Scafo a zero: sotto costa arriva il traino, oltre le acque medie la
## barca affonda davvero — carico perso e recupero a pagamento (feedback
## playtest M3: è il rischio del mare aperto, GDD pillar 2).
func _on_hull_depleted() -> void:
	if _sinking:
		return
	if sea.shore_distance(boat.global_position) > sea.medium_width:
		_sink_boat.call_deferred()
	else:
		_tow_boat.call_deferred()


func _tow_boat() -> void:
	GameState.pay_tow()
	boat.reset_motion()
	boat.global_position = _port.tow_spawn_position()


## Piccola sequenza di affondamento (riusa il sink_amount del fuori
## zona), poi il recupero: niente teletrasporto secco a scafo zero.
func _sink_boat() -> void:
	_sinking = true
	boat.input_enabled = false
	boat.reset_motion()
	GameState.set_danger("LA BARCA AFFONDA!")
	var tween := create_tween()
	tween.tween_property(boat, "sink_amount", 1.0, sink_time)
	tween.tween_interval(0.6)
	tween.tween_callback(_finish_sinking)


func _finish_sinking() -> void:
	_sinking = false
	boat.sink_amount = 0.0
	boat.reset_motion()
	boat.global_position = _port.tow_spawn_position()
	boat.input_enabled = true
	GameState.clear_danger()
	GameState.salvage_after_sinking()


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
		var pos := _sample_disc(center, rock_field_radius, _rock_positions, 3.0)
		if not pos.is_finite():
			continue
		var rock := ROCK_SCENE.instantiate() as Node3D
		add_child(rock)
		rock.global_position = Vector3(pos.x, _rng.randf_range(-0.5, 0.1), pos.z)
		rock.rotation.y = _rng.randf_range(0.0, TAU)
		rock.scale = Vector3.ONE * _rng.randf_range(0.7, 1.9)
		_rock_positions.append(pos)


## Ogni tipologia vive nella sua fascia di mare (GDD § Boe): gialle
## nelle acque calme sotto costa, rosse nelle medie, blu al largo.
func _spawn_zone_buoys() -> void:
	for i in yellow_buoy_count:
		var pos := _sample_band(18.0, sea.calm_width - 15.0, _buoy_positions, 10.0)
		if pos.is_finite() and _is_clear(pos):
			_spawn_buoy(pos, GameState.BuoyType.YELLOW)
	for i in red_point_count:
		var pos := _sample_band(sea.calm_width + 5.0, sea.medium_width - 10.0, _buoy_positions, 10.0)
		if pos.is_finite() and _is_clear(pos):
			_spawn_buoy(pos, GameState.BuoyType.RED)
	for i in blue_point_count:
		var pos := _sample_band(sea.medium_width + 15.0, bounds_depth - 60.0,
			_buoy_positions, 12.0, scatter_half_width_open)
		if pos.is_finite() and _is_clear(pos):
			_spawn_buoy(pos, GameState.BuoyType.BLUE)
	# Le taniche vagano su tutta la baia: la fortuna può capitare ovunque.
	for i in fuel_point_count:
		var wide := i % 2 == 1
		var pos := _sample_band(20.0, bounds_depth - 60.0, _buoy_positions, 10.0,
			scatter_half_width_open if wide else -1.0)
		if pos.is_finite() and _is_clear(pos):
			_spawn_fuel_can(pos)


## Una zona di pesca per fascia di mare (GDD § Pesca): specie e
## difficoltà crescono col rischio, come le boe. Il mare aperto è
## profondo il doppio delle altre fasce: ha due bande di zone.
func _spawn_fishing_zones() -> void:
	# x = distanza min dalla costa, y = distanza max, z = fascia (tier).
	var bands: Array[Vector3] = [
		Vector3(25.0, sea.calm_width - 20.0, 0.0),
		Vector3(sea.calm_width + 15.0, sea.medium_width - 15.0, 1.0),
		Vector3(sea.medium_width + 20.0, sea.medium_width + 220.0, 2.0),
		Vector3(sea.medium_width + 280.0, bounds_depth - 70.0, 2.0),
	]
	for band in bands:
		var tier := int(band.z)
		for i in fishing_zones_per_band:
			var pos := _sample_band(band.x, band.y, _fishing_positions, 60.0,
				scatter_half_width_open if tier >= 2 else -1.0)
			if pos.is_finite() and _is_clear(pos):
				_spawn_fishing_zone(pos, tier)


func _spawn_fishing_zone(pos: Vector3, tier: int) -> void:
	var zone := FISHING_ZONE_SCENE.instantiate() as FishingZone
	zone.zone_tier = tier
	zone.sea = sea
	add_child(zone)
	zone.global_position = Vector3(pos.x, 0.0, pos.z)
	_fishing_positions.append(pos)


func _spawn_buoy(pos: Vector3, type: int) -> void:
	var buoy := BUOY_SCENE.instantiate() as Buoy
	buoy.type = type
	buoy.sea = sea
	add_child(buoy)
	buoy.global_position = Vector3(pos.x, 0.0, pos.z)
	_buoy_positions.append(pos)


func _spawn_fuel_can(pos: Vector3) -> void:
	var can := FUEL_CAN_SCENE.instantiate() as FuelCan
	can.sea = sea
	add_child(can)
	can.global_position = Vector3(pos.x, 0.0, pos.z)
	_buoy_positions.append(pos)


## Campiona un punto nella fascia di mare tra d_min e d_max metri dalla
## costa, lontano almeno min_dist dai punti già occupati. Vector3.INF se
## non trova posto. half_width < 0 usa scatter_half_width (i default dei
## parametri non possono leggere altre proprietà).
func _sample_band(d_min: float, d_max: float, taken: Array[Vector3],
		min_dist: float, half_width: float = -1.0) -> Vector3:
	if half_width < 0.0:
		half_width = scatter_half_width
	for attempt in 30:
		var pos := Vector3(_rng.randf_range(-half_width, half_width), 0.0,
			sea.shore_z + _rng.randf_range(d_min, d_max))
		if _far_from(pos, taken, min_dist):
			return pos
	return Vector3.INF


## Campiona un punto in un disco intorno a center (per i campi di scogli).
func _sample_disc(center: Vector3, radius: float, taken: Array[Vector3], min_dist: float) -> Vector3:
	for attempt in 30:
		var angle := _rng.randf_range(0.0, TAU)
		var pos := center + Vector3(cos(angle), 0.0, sin(angle)) * _rng.randf_range(0.0, radius)
		if _far_from(pos, taken, min_dist):
			return pos
	return Vector3.INF


func _far_from(pos: Vector3, points: Array[Vector3], min_dist: float) -> bool:
	for point in points:
		if pos.distance_to(point) < min_dist:
			return false
	return true


## Vero se il punto non finisce dentro isole, porto, scogli o zone di pesca.
func _is_clear(pos: Vector3) -> bool:
	for island: Node3D in _islands.get_children():
		if pos.distance_to(island.global_position) < 14.0 * island.scale.x:
			return false
	if pos.distance_to(_port.global_position) < 26.0:
		return false
	# Le zone di pesca ora sono più larghe (raggio ~15): niente boe dentro.
	if not _far_from(pos, _fishing_positions, 22.0):
		return false
	return _far_from(pos, _rock_positions, 3.0)
