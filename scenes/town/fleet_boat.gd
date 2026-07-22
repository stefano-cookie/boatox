class_name FleetBoat
extends Node3D

## Barca della flottiglia di pesca (roadmap B2): visuale pura, niente
## collisioni — fa la spola casa → zona di pesca, gira in tondo mentre
## "lavora" e torna. La resa economica vive nei tick dell'autoload Town:
## qui solo il feedback visivo (le barche si vedono lavorare in mare).
## Costruita e configurata dal Fleet manager.

enum State { OUT, WORK, BACK, REST }

const SPEED: float = 5.0
const TURN_SPEED: float = 1.6
const WORK_TIME: float = 22.0
const REST_TIME: float = 10.0
## Raggio del giro di pesca intorno alla zona.
const WORK_RADIUS: float = 8.0

var sea: Sea
var home: Vector3
var spot: Vector3
## Tinta dello scafo (varia da barca a barca, la assegna il Fleet).
var hull_color: Color = Color(0.85, 0.85, 0.8)

var _state: State = State.REST
var _timer: float = 0.0
var _work_angle: float = 0.0


func _ready() -> void:
	_build_visual()
	global_position = home
	# Partenze sfalsate: la flottiglia non esce in fila indiana.
	_timer = randf_range(0.0, REST_TIME)


func _process(delta: float) -> void:
	match _state:
		State.REST:
			_timer -= delta
			if _timer <= 0.0:
				_state = State.OUT
		State.OUT:
			if _move_towards(spot, delta):
				_state = State.WORK
				_timer = WORK_TIME
				_work_angle = randf_range(0.0, TAU)
		State.WORK:
			_timer -= delta
			_work_angle += delta * SPEED * 0.35 / WORK_RADIUS * TAU * 0.5
			var target := spot + Vector3(cos(_work_angle), 0.0, sin(_work_angle)) * WORK_RADIUS
			_move_towards(target, delta, 0.45)
			if _timer <= 0.0:
				_state = State.BACK
		State.BACK:
			if _move_towards(home, delta):
				_state = State.REST
				_timer = REST_TIME
	# Galleggiamento: l'acqua decide la quota, come per le boe.
	if sea != null:
		global_position.y = sea.get_height(global_position)


## Avanza verso il punto (solo x/z) virando dolcemente; vero se arrivata.
func _move_towards(target: Vector3, delta: float, speed_scale: float = 1.0) -> bool:
	var to := target - global_position
	to.y = 0.0
	if to.length() < 2.0:
		return true
	var desired := atan2(-to.x, -to.z)
	rotation.y = lerp_angle(rotation.y, desired, TURN_SPEED * delta)
	# Si muove nella direzione della prua: le virate disegnano archi veri.
	var forward := -global_transform.basis.z
	forward.y = 0.0
	global_position += forward.normalized() * SPEED * speed_scale * delta
	return false


## Peschereccio in miniatura: scafo tinto, cabina bianca, alberello con
## bandierina — leggibile anche da lontano.
func _build_visual() -> void:
	var hull := MeshInstance3D.new()
	var hull_mesh := BoxMesh.new()
	hull_mesh.size = Vector3(1.4, 0.6, 3.6)
	hull.mesh = hull_mesh
	hull.material_override = _flat(hull_color)
	hull.position.y = 0.3
	add_child(hull)
	var bow := MeshInstance3D.new()
	var bow_mesh := PrismMesh.new()
	bow_mesh.size = Vector3(1.4, 0.6, 0.9)
	bow.mesh = bow_mesh
	bow.material_override = _flat(hull_color)
	bow.rotation.x = deg_to_rad(-90.0)
	bow.position = Vector3(0.0, 0.3, -2.2)
	add_child(bow)
	var cabin := MeshInstance3D.new()
	var cabin_mesh := BoxMesh.new()
	cabin_mesh.size = Vector3(1.0, 0.7, 1.1)
	cabin.mesh = cabin_mesh
	cabin.material_override = _flat(Color(0.93, 0.91, 0.86))
	cabin.position = Vector3(0.0, 0.95, 0.6)
	add_child(cabin)
	var mast := MeshInstance3D.new()
	var mast_mesh := BoxMesh.new()
	mast_mesh.size = Vector3(0.08, 1.6, 0.08)
	mast.mesh = mast_mesh
	mast.material_override = _flat(Color(0.42, 0.3, 0.2))
	mast.position = Vector3(0.0, 1.6, -0.6)
	add_child(mast)
	var flag := MeshInstance3D.new()
	var flag_mesh := BoxMesh.new()
	flag_mesh.size = Vector3(0.04, 0.25, 0.5)
	flag.mesh = flag_mesh
	flag.material_override = _flat(Color(0.85, 0.3, 0.25))
	flag.position = Vector3(0.0, 2.2, -0.35)
	add_child(flag)


static func _flat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	return mat
