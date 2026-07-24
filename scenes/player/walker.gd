class_name Walker
extends CharacterBody3D

## Il giocatore a piedi (roadmap R7): prima persona, WASD + mouse, niente
## salto né arrampicata nella v1. Vive su layer/mask 2 — il mondo
## camminabile (sabbia, pianura, molo, case) espone collider dedicati su
## quel layer, così barche e piedi non si pestano. Dorme finché il
## LandingSystem non lo attiva con lo sbarco; A/D sono passo laterale
## (le stesse azioni turn_* della barca, che a guida spenta le ignora).

@export_group("Movimento")
@export var walk_speed: float = 4.2
@export var acceleration: float = 14.0
@export var gravity: float = 18.0

@export_group("Vista")
## Gradi per pixel di mouse (come la camera di mira, da tarare giocando).
@export var mouse_sensitivity: float = 0.13
@export var pitch_up_deg: float = 80.0
@export var pitch_down_deg: float = 75.0

## Spento dai dialoghi (pattern di Port/RescueNpc): fermi mentre si parla.
var input_enabled: bool = true
var active: bool = false

## Ultimo punto di sbarco: rete di sicurezza se si finisce in acqua.
var _spawn: Vector3 = Vector3.ZERO

@onready var _camera: Camera3D = $Camera3D


func _ready() -> void:
	add_to_group(&"walker")
	set_physics_process(false)


## Mette a terra il giocatore nel punto dato (un filo alto: la gravità lo
## posa) e accende la prima persona.
func activate(spot: Vector3, yaw: float) -> void:
	active = true
	_spawn = spot
	global_position = spot
	rotation.y = yaw
	_camera.rotation.x = 0.0
	velocity = Vector3.ZERO
	set_physics_process(true)
	_camera.current = true


## Torna a dormire (il LandingSystem riaccende la chase camera).
func deactivate() -> void:
	active = false
	set_physics_process(false)


## Spostamento secco con i piedi già a terra (porte dell'arsenale):
## aggiorna anche il punto di sicurezza, così la rete anti-caduta non
## riporta al vecchio sbarco.
func teleport(spot: Vector3, yaw: float) -> void:
	global_position = spot
	_spawn = spot
	rotation.y = yaw
	_camera.rotation.x = 0.0
	velocity = Vector3.ZERO


func _physics_process(delta: float) -> void:
	velocity.y -= gravity * delta
	var input := Vector2.ZERO
	if input_enabled and not GameState.ui_focus_open():
		input = Input.get_vector("turn_left", "turn_right", "move_forward", "move_back")
	var dir := global_transform.basis * Vector3(input.x, 0.0, input.y)
	dir.y = 0.0
	if dir.length_squared() > 1.0:
		dir = dir.normalized()
	velocity.x = move_toward(velocity.x, dir.x * walk_speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, dir.z * walk_speed, acceleration * delta)
	move_and_slide()
	# Finiti in acqua oltre le reti di contenimento: si torna al punto di
	# sbarco, senza punizioni (a piedi non si affoga, si torna bagnati).
	if global_position.y < _spawn.y - 8.0:
		global_position = _spawn
		velocity = Vector3.ZERO


## Mouse = testa: solo con la vista attiva, il mouse catturato (niente
## menu aperti) e la guida a piedi accesa.
func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion == null or not active or not input_enabled \
			or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var sens := deg_to_rad(mouse_sensitivity) * Audio.mouse_sensitivity_scale
	rotation.y -= motion.relative.x * sens
	_camera.rotation.x = clampf(_camera.rotation.x - motion.relative.y * sens,
		-deg_to_rad(pitch_down_deg), deg_to_rad(pitch_up_deg))
