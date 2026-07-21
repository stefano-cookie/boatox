class_name Boat
extends CharacterBody3D

## Guida arcade (GDD § Navigazione): accelerazione, virata dipendente
## dalla velocità, deriva leggera. Il corpo resta a y = 0 e si muove sul
## piano XZ; il nodo Visual fa beccheggio, rollio e galleggiamento
## leggendo l'altezza dell'acqua dalla Sea. I parametri di guida non
## sono più @export: arrivano dalla BoatDefinition corrente (ogni barca
## ha la sua guida), qui restano solo i valori da tarare a mano.

@export var sea: Sea

@export_group("Danni")
## Sotto questa velocità d'impatto l'urto non danneggia (sfregare non punisce).
@export var min_impact_speed: float = 3.0
@export var damage_per_speed: float = 4.0
@export var impact_cooldown: float = 0.6

@export_group("Mare agitato")
## Agitazione (zona × meteo) oltre cui il mare inizia a destabilizzare.
@export var chaos_threshold: float = 1.6
## Quanta agitazione oltre la soglia serve per il caos pieno.
@export var chaos_full_range: float = 2.5
## Sbandata del timone a caos pieno e stabilità zero.
@export var chaos_turn_deg: float = 55.0
## Spinta laterale delle onde a caos pieno (m/s²).
@export var chaos_push: float = 7.0

@export_group("Affondamento (fuori zona)")
## Quanto scende il visivo quando sink_amount arriva a 1.
@export var sink_depth: float = 0.9
@export var sink_pitch_deg: float = 6.0

@export_group("Assetto (visuale)")
@export var bank_max_deg: float = 10.0
@export var accel_pitch_deg: float = 3.0
@export var attitude_smoothing: float = 5.0
@export var bob_smoothing: float = 8.0
## Quanto la stabilità piena smorza beccheggio e rollio da onda.
@export_range(0.0, 1.0) var stability_damping: float = 0.5

var input_enabled: bool = true
## 0..1, impostato dal World fuori dai confini: la barca si abbassa
## nell'acqua e appruata, senza toccare la guida (deve restare facile
## rientrare).
var sink_amount: float = 0.0

# Guida corrente, copiata dalla BoatDefinition in _apply_definition.
var max_speed: float = 14.0
var _max_reverse_speed: float = 4.0
var _acceleration: float = 5.0
var _reverse_acceleration: float = 3.0
var _brake_force: float = 8.0
var _water_drag: float = 2.0
var _turn_speed_deg: float = 60.0
var _turn_full_speed_ratio: float = 0.35
var _grip: float = 2.5
var _stability: float = 0.2

var _speed: float = 0.0
var _impact_timer: float = 0.0
var _chaos_time: float = 0.0

var _sample_bow := Vector3(0.0, 0.0, -1.9)
var _sample_stern := Vector3(0.0, 0.0, 1.9)
var _sample_left := Vector3(-0.9, 0.0, 0.0)
var _sample_right := Vector3(0.9, 0.0, 0.0)

@onready var _visual: Node3D = $Visual
@onready var _collision: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	GameState.boat_changed.connect(func(_def: BoatDefinition) -> void: _apply_definition())
	_apply_definition()


func _physics_process(delta: float) -> void:
	_impact_timer = maxf(_impact_timer - delta, 0.0)
	var throttle := 0.0
	var steer := 0.0
	if input_enabled:
		throttle = Input.get_axis("move_back", "move_forward")
		steer = Input.get_axis("turn_right", "turn_left")
	_update_speed(throttle, delta)
	_update_heading(steer, delta)
	_apply_chaos(delta)
	_update_velocity(delta)
	var pre_impact_velocity := velocity
	move_and_slide()
	global_position.y = 0.0
	_handle_impacts(pre_impact_velocity)
	_update_attitude(throttle, steer, delta)


func current_speed() -> float:
	return _speed


func reset_motion() -> void:
	_speed = 0.0
	velocity = Vector3.ZERO


## Copia guida e dimensioni dalla barca corrente (upgrade inclusi) e
## monta il suo modello sotto Visual.
func _apply_definition() -> void:
	var def := GameState.current_def()
	max_speed = GameState.effective_max_speed()
	_acceleration = GameState.effective_acceleration()
	_stability = GameState.effective_stability()
	_max_reverse_speed = def.max_reverse_speed
	_reverse_acceleration = def.reverse_acceleration
	_brake_force = def.brake_force
	_water_drag = def.water_drag
	_turn_speed_deg = def.turn_speed_deg
	_turn_full_speed_ratio = def.turn_full_speed_ratio
	_grip = def.grip

	var shape := BoxShape3D.new()
	shape.size = def.collision_size
	_collision.shape = shape
	_collision.position.y = def.collision_size.y * 0.3
	var half_length := def.collision_size.z * 0.5
	_sample_bow = Vector3(0.0, 0.0, -(half_length - 0.8))
	_sample_stern = Vector3(0.0, 0.0, half_length - 0.8)
	_sample_left = Vector3(-def.collision_size.x * 0.5, 0.0, 0.0)
	_sample_right = Vector3(def.collision_size.x * 0.5, 0.0, 0.0)

	for child in _visual.get_children():
		child.queue_free()
	if def.visual_scene != null:
		_visual.add_child(def.visual_scene.instantiate())


func _update_speed(throttle: float, delta: float) -> void:
	if throttle > 0.0:
		_speed = move_toward(_speed, max_speed * throttle, _acceleration * delta)
	elif throttle < 0.0:
		if _speed > 0.1:
			_speed = move_toward(_speed, 0.0, _brake_force * delta)
		else:
			_speed = move_toward(_speed, _max_reverse_speed * throttle, _reverse_acceleration * delta)
	else:
		_speed = move_toward(_speed, 0.0, _water_drag * delta)


func _update_heading(steer: float, delta: float) -> void:
	var reverse_sign := 1.0 if _speed >= 0.0 else -1.0
	rotation.y += steer * deg_to_rad(_turn_speed_deg) * _turn_factor() * reverse_sign * delta


## Il mare agitato destabilizza (GDD § Navigazione): oltre la soglia di
## agitazione il timone sbanda e le onde spingono di lato, in proporzione
## a quanto manca alla stabilità piena. Con la barchetta il largo in
## tempesta è quasi ingovernabile: è il cancello di progressione.
func _apply_chaos(delta: float) -> void:
	if sea == null:
		return
	var agitation := sea.agitation(global_position)
	var chaos := clampf((agitation - chaos_threshold) / chaos_full_range, 0.0, 1.0) \
		* (1.0 - _stability)
	if chaos <= 0.0:
		return
	_chaos_time += delta
	var wobble := sin(_chaos_time * 2.1) + 0.5 * sin(_chaos_time * 3.7 + 1.3)
	rotation.y += wobble * deg_to_rad(chaos_turn_deg) * chaos * delta
	velocity += sea.wave_push_direction() * chaos_push * chaos * delta


func _update_velocity(delta: float) -> void:
	var forward := -global_transform.basis.z
	var target_velocity := forward * _speed
	velocity = velocity.lerp(target_velocity, 1.0 - exp(-_grip * delta))
	velocity.y = 0.0


func _handle_impacts(pre_impact_velocity: Vector3) -> void:
	if _impact_timer > 0.0 or get_slide_collision_count() == 0:
		return
	var normal := get_slide_collision(0).get_normal()
	var impact := -pre_impact_velocity.dot(normal)
	if impact <= min_impact_speed:
		return
	_impact_timer = impact_cooldown
	_speed *= 0.3
	GameState.apply_damage((impact - min_impact_speed) * damage_per_speed)


func _turn_factor() -> float:
	return clampf(absf(_speed) / (max_speed * _turn_full_speed_ratio), 0.0, 1.0)


func _update_attitude(throttle: float, steer: float, delta: float) -> void:
	if sea == null:
		return
	var h_bow := sea.get_height(to_global(_sample_bow))
	var h_stern := sea.get_height(to_global(_sample_stern))
	var h_left := sea.get_height(to_global(_sample_left))
	var h_right := sea.get_height(to_global(_sample_right))

	var water_level := (h_bow + h_stern + h_left + h_right) / 4.0
	# La stabilità smorza la risposta alle onde: si vede oltre a sentirsi.
	var damp := 1.0 - stability_damping * _stability
	var wave_pitch := atan2(h_bow - h_stern, _sample_stern.z - _sample_bow.z) * damp
	var wave_roll := atan2(h_right - h_left, _sample_right.x - _sample_left.x) * damp

	var target_pitch := wave_pitch + deg_to_rad(accel_pitch_deg) * throttle \
		+ deg_to_rad(sink_pitch_deg) * sink_amount
	var target_roll := wave_roll + steer * deg_to_rad(bank_max_deg) * _turn_factor()

	var t_att := 1.0 - exp(-attitude_smoothing * delta)
	var t_bob := 1.0 - exp(-bob_smoothing * delta)
	_visual.rotation.x = lerp_angle(_visual.rotation.x, target_pitch, t_att)
	_visual.rotation.z = lerp_angle(_visual.rotation.z, target_roll, t_att)
	_visual.position.y = lerpf(_visual.position.y, water_level - sink_depth * sink_amount, t_bob)
