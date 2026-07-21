class_name ChaseCamera
extends Camera3D

## Terza persona stile GTA (GDD § Camera): resta dietro e sopra il
## bersaglio, ruota con smorzamento verso la sua prua e guarda un punto
## davanti alla barca. Tutti i parametri sono da tarare giocando.

@export var target: Node3D
@export var distance: float = 9.0
@export var height: float = 4.5
## Altezza del punto guardato sopra il bersaglio.
@export var look_height: float = 1.2
## Metri davanti alla prua verso cui guarda la camera.
@export var look_ahead: float = 4.0
@export var position_smoothing: float = 4.0
@export var yaw_smoothing: float = 3.0

var _yaw: float = 0.0


func _ready() -> void:
	if target == null:
		return
	_yaw = target.global_rotation.y
	global_position = _desired_position()
	_look()


func _physics_process(delta: float) -> void:
	if target == null:
		return
	_yaw = lerp_angle(_yaw, target.global_rotation.y, 1.0 - exp(-yaw_smoothing * delta))
	var t := 1.0 - exp(-position_smoothing * delta)
	global_position = global_position.lerp(_desired_position(), t)
	_look()


func _desired_position() -> Vector3:
	var behind := Vector3(sin(_yaw), 0.0, cos(_yaw))
	return target.global_position + behind * distance + Vector3.UP * height


func _look() -> void:
	var forward := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	look_at(target.global_position + forward * look_ahead + Vector3.UP * look_height)
