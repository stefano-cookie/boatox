extends Node

## Smoke test di M1: istanzia main.tscn, guida la barca con input
## simulato e stampa un verdetto per camera, boe, danni e traino.
## Uso: Godot --path . --headless res://tests/m1_smoke.tscn

var _main: Node
var _boat: Boat
var _camera: Camera3D
var _towed: bool = false


func _ready() -> void:
	_main = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	_boat = _main.get_node("Boat")
	_camera = _main.get_node("ChaseCamera")
	GameState.hull_depleted.connect(func() -> void: _towed = true)
	_run()


func _run() -> void:
	await _wait(0.5)

	# --- Camera: deve seguire la barca mentre guida e vira ---
	var cam_start: Vector3 = _camera.global_position
	_boat.rotation.y = PI
	Input.action_press("move_forward")
	await _wait(5.0)
	var moved := cam_start.distance_to(_camera.global_position)
	var dist := _camera.global_position.distance_to(_boat.global_position)
	print("CAMERA: spostamento=%.1f m, distanza dalla barca=%.1f m (attesa ~10)" % [moved, dist])
	Input.action_press("turn_left")
	await _wait(3.0)
	Input.action_release("turn_left")
	dist = _camera.global_position.distance_to(_boat.global_position)
	print("CAMERA dopo virata: distanza=%.1f m, barca=%s, camera=%s" % [dist, _boat.global_position, _camera.global_position])
	Input.action_release("move_forward")

	# --- Boa: teleport sopra una boa, la raccolta deve scattare ---
	_boat.reset_motion()
	var buoy := _find_buoy()
	if buoy == null:
		print("BOE: nessuna boa spawnata!")
	else:
		_boat.global_position = buoy.global_position
		await _wait(0.5)
		print("BOE: in stiva=%d (attese >0)" % GameState.cargo_count())

	# --- Danni: speronate ripetute contro un'isola fino al traino ---
	_boat.reset_motion()
	_boat.global_position = Vector3(90, 0.0, 80)
	_boat.rotation.y = -PI / 2  # prua verso Island3 (120, 80)
	var rams := 0
	while not _towed and rams < 12:
		Input.action_press("move_forward")
		await _wait(3.5)
		Input.action_release("move_forward")
		Input.action_press("move_back")
		await _wait(1.8)
		Input.action_release("move_back")
		_boat.rotation.y = -PI / 2
		rams += 1
		print("DANNI: speronata %d -> scafo %.1f" % [rams, GameState.hull])
	if _towed:
		print("TRAINO: ok, scafo=%.1f, denaro=%d, posizione=%s (atteso vicino a (46,-44))" % [GameState.hull, GameState.money, _boat.global_position])
	else:
		print("TRAINO: MAI SCATTATO dopo %d speronate, scafo=%.1f" % [rams, GameState.hull])
	get_tree().quit()


func _find_buoy() -> Buoy:
	for child in _main.get_node("World").get_children():
		if child is Buoy:
			return child
	return null


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
