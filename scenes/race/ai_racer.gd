class_name AIRacer
extends Node3D

## Avversario IA della regata (GDD § Corse): niente fisica, guida
## cinematica — vira verso il prossimo checkpoint, molla il gas in curva
## e viene frenato dal mare grosso in base alla sua stabilità, con le
## stesse soglie del giocatore: gli upgrade si confrontano ad armi pari.
## I parametri delle IA vivono in GameState.RACE_AI; qui la guida.

signal finished_course(racer: AIRacer)

## Impostati da chi lo spawna, prima di add_child.
var racer_name: String = ""
var max_speed: float = 12.0
var stability: float = 0.3
var turn_speed_deg: float = 55.0
var sea: Sea
var visual_scene: PackedScene

## Le IA vanno sempre a tutto gas: conta solo il tetto di velocità.
const ACCELERATION: float = 4.0
const PASS_RADIUS: float = 15.0
## Le stesse soglie di Boat per il rallentamento da mare grosso.
const CHAOS_THRESHOLD: float = 1.6
const CHAOS_FULL_RANGE: float = 2.5
const ROUGH_SLOW_MAX: float = 0.55
## Tetto di velocità in curva stretta: traiettorie credibili.
const TURN_SLOW: float = 0.65

var _waypoints: Array[Vector3] = []
var _next: int = 0
var _speed: float = 0.0
var _racing: bool = false
var _finished: bool = false
## Scarto personale sui cancelli intermedi: le IA non si impilano.
var _offset := Vector3.ZERO
var _visual: Node3D


func _ready() -> void:
	_visual = visual_scene.instantiate() as Node3D
	add_child(_visual)
	var label := Label3D.new()
	label.text = racer_name
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 64
	label.outline_size = 12
	label.pixel_size = 0.01
	label.position.y = 3.2
	add_child(label)


func _physics_process(delta: float) -> void:
	if sea != null and _visual != null:
		_visual.position.y = sea.get_height(global_position)
	if not _racing or _finished:
		return
	var target := _current_target()
	var to_target := target - global_position
	to_target.y = 0.0
	var target_angle := atan2(-to_target.x, -to_target.z)
	var diff := angle_difference(rotation.y, target_angle)
	var max_step := deg_to_rad(turn_speed_deg) * delta
	rotation.y += clampf(diff, -max_step, max_step)
	var cap := max_speed * (1.0 - ROUGH_SLOW_MAX * _chaos())
	if absf(diff) > 0.6:
		cap *= TURN_SLOW
	_speed = move_toward(_speed, cap, ACCELERATION * delta)
	global_position += -global_transform.basis.z * _speed * delta
	global_position.y = 0.0
	if _visual != null:
		var t := 1.0 - exp(-5.0 * delta)
		_visual.rotation.z = lerpf(_visual.rotation.z, clampf(-diff * 0.6, -0.22, 0.22), t)
	if to_target.length() <= PASS_RADIUS:
		_next += 1
		if _next >= _waypoints.size():
			_finished = true
			finished_course.emit(self)


## Riceve il percorso e si mette in griglia puntando il primo cancello;
## si parte solo al via (go).
func begin_course(waypoints: Array[Vector3]) -> void:
	_waypoints = waypoints
	_next = 0
	_offset = Vector3(randf_range(-6.0, 6.0), 0.0, randf_range(-6.0, 6.0))
	var to_first := _waypoints[0] - global_position
	rotation.y = atan2(-to_first.x, -to_first.z)


func go() -> void:
	_racing = true


func has_finished() -> bool:
	return _finished


## Avanzamento in gara per la classifica: cancelli presi, poi distanza
## dal prossimo (stessa formula del giocatore in RaceCourse).
func progress() -> float:
	if _finished:
		return INF
	return float(_next) * 10000.0 - global_position.distance_to(_current_target())


## Il traguardo si prende preciso, i cancelli intermedi con lo scarto
## personale.
func _current_target() -> Vector3:
	var target := _waypoints[_next]
	if _next < _waypoints.size() - 1:
		target += _offset
	return target


func _chaos() -> float:
	if sea == null:
		return 0.0
	return clampf((sea.agitation(global_position) - CHAOS_THRESHOLD) / CHAOS_FULL_RANGE, 0.0, 1.0) \
		* (1.0 - stability)
