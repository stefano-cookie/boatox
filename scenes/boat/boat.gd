class_name Boat
extends CharacterBody3D

## Guida arcade (GDD § Navigazione): accelerazione, virata dipendente
## dalla velocità, deriva leggera. Il corpo resta a y = 0 e si muove sul
## piano XZ; il nodo Visual fa beccheggio, rollio e galleggiamento
## leggendo l'altezza dell'acqua dalla Sea.

@export var sea: Sea

@export_group("Guida")
@export var max_speed: float = 14.0
@export var max_reverse_speed: float = 4.0
@export var acceleration: float = 5.0
@export var reverse_acceleration: float = 3.0
@export var brake_force: float = 8.0
@export var water_drag: float = 2.0
@export var turn_speed_deg: float = 60.0
## Frazione di max_speed oltre cui la virata è piena.
@export var turn_full_speed_ratio: float = 0.35
## Quanto in fretta la velocità si allinea alla prua: basso = più deriva.
@export var grip: float = 2.5

@export_group("Danni")
## Sotto questa velocità d'impatto l'urto non danneggia (sfregare non punisce).
@export var min_impact_speed: float = 3.0
@export var damage_per_speed: float = 4.0
@export var impact_cooldown: float = 0.6

@export_group("Confini mappa")
## Impostato dal World in _ready: oltre questo raggio dal centro la
## corrente spinge dolcemente la barca verso l'interno.
@export var bounds_radius: float = 240.0
@export var bounds_push: float = 8.0

@export_group("Assetto (visuale)")
@export var bank_max_deg: float = 10.0
@export var accel_pitch_deg: float = 3.0
@export var attitude_smoothing: float = 5.0
@export var bob_smoothing: float = 8.0

const _SAMPLE_BOW := Vector3(0.0, 0.0, -1.9)
const _SAMPLE_STERN := Vector3(0.0, 0.0, 1.9)
const _SAMPLE_LEFT := Vector3(-0.9, 0.0, 0.0)
const _SAMPLE_RIGHT := Vector3(0.9, 0.0, 0.0)

var input_enabled: bool = true

var _speed: float = 0.0
var _impact_timer: float = 0.0

@onready var _visual: Node3D = $Visual


func _physics_process(delta: float) -> void:
	_impact_timer = maxf(_impact_timer - delta, 0.0)
	var throttle := 0.0
	var steer := 0.0
	if input_enabled:
		throttle = Input.get_axis("move_back", "move_forward")
		steer = Input.get_axis("turn_right", "turn_left")
	_update_speed(throttle, delta)
	_update_heading(steer, delta)
	_update_velocity(delta)
	_apply_bounds_push()
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


func _update_speed(throttle: float, delta: float) -> void:
	if throttle > 0.0:
		_speed = move_toward(_speed, max_speed * throttle, acceleration * delta)
	elif throttle < 0.0:
		if _speed > 0.1:
			_speed = move_toward(_speed, 0.0, brake_force * delta)
		else:
			_speed = move_toward(_speed, max_reverse_speed * throttle, reverse_acceleration * delta)
	else:
		_speed = move_toward(_speed, 0.0, water_drag * delta)


func _update_heading(steer: float, delta: float) -> void:
	var reverse_sign := 1.0 if _speed >= 0.0 else -1.0
	rotation.y += steer * deg_to_rad(turn_speed_deg) * _turn_factor() * reverse_sign * delta


func _update_velocity(delta: float) -> void:
	var forward := -global_transform.basis.z
	var target_velocity := forward * _speed
	velocity = velocity.lerp(target_velocity, 1.0 - exp(-grip * delta))
	velocity.y = 0.0


func _apply_bounds_push() -> void:
	var flat := Vector3(global_position.x, 0.0, global_position.z)
	var overshoot := flat.length() - bounds_radius
	if overshoot > 0.0:
		velocity += -flat.normalized() * bounds_push * clampf(overshoot / 10.0, 0.2, 2.0)


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
	return clampf(absf(_speed) / (max_speed * turn_full_speed_ratio), 0.0, 1.0)


func _update_attitude(throttle: float, steer: float, delta: float) -> void:
	if sea == null:
		return
	var h_bow := sea.get_height(to_global(_SAMPLE_BOW))
	var h_stern := sea.get_height(to_global(_SAMPLE_STERN))
	var h_left := sea.get_height(to_global(_SAMPLE_LEFT))
	var h_right := sea.get_height(to_global(_SAMPLE_RIGHT))

	var water_level := (h_bow + h_stern + h_left + h_right) / 4.0
	var wave_pitch := atan2(h_bow - h_stern, _SAMPLE_STERN.z - _SAMPLE_BOW.z)
	var wave_roll := atan2(h_right - h_left, _SAMPLE_RIGHT.x - _SAMPLE_LEFT.x)

	var target_pitch := wave_pitch + deg_to_rad(accel_pitch_deg) * throttle
	var target_roll := wave_roll + steer * deg_to_rad(bank_max_deg) * _turn_factor()

	var t_att := 1.0 - exp(-attitude_smoothing * delta)
	var t_bob := 1.0 - exp(-bob_smoothing * delta)
	_visual.rotation.x = lerp_angle(_visual.rotation.x, target_pitch, t_att)
	_visual.rotation.z = lerp_angle(_visual.rotation.z, target_roll, t_att)
	_visual.position.y = lerpf(_visual.position.y, water_level, t_bob)
