extends Node

## Utility di sviluppo: carica main, piazza una camera libera in punti
## panoramici e salva screenshot per la verifica visiva della mappa.
## La cartella di uscita si può reindirizzare con la variabile
## d'ambiente BOATOX_SHOT_DIR.
## Uso: Godot --path . res://tests/screenshot.tscn

var _out_dir: String = OS.get_environment("BOATOX_SHOT_DIR")

var _main: Node
var _cam: Camera3D


func _ready() -> void:
	if _out_dir.is_empty():
		_out_dir = OS.get_user_data_dir().path_join("screenshots")
		DirAccess.make_dir_recursive_absolute(_out_dir)
	GameState.save_path = "user://save_test.json"
	GameState.reset()
	_main = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.far = 800.0
	add_child(_cam)
	_run()


func _run() -> void:
	await _wait(1.5)
	_cam.make_current()
	# Il mare segue la camera libera: le viste dal largo restano oneste.
	var sea: Sea = _main.get_node("Sea")
	sea.follow_target = _cam
	await _shot(Vector3(60, 10, -60), Vector3(40, 2, -155), "coast_port.png")
	await _shot(Vector3(0, 55, 90), Vector3(0, 0, -160), "coast_wide.png")
	await _shot(Vector3(-150, 8, -80), Vector3(-260, 2, -120), "coast_west.png")
	await _shot(Vector3(0, 20, 260), Vector3(20, 0, 60), "offshore.png")
	# Tempesta al largo: onde piene e atmosfera cupa.
	var weather: Weather = _main.get_node("Weather")
	weather.rough = true
	sea.weather_multiplier = weather.rough_multiplier
	await _shot(Vector3(-40, 6, 190), Vector3(30, 0, 60), "storm.png")
	# Vista dalla barca al molo, con la chase camera vera.
	weather.rough = false
	sea.weather_multiplier = 1.0
	sea.follow_target = _main.get_node("Boat")
	(_main.get_node("ChaseCamera") as Camera3D).make_current()
	await _wait(1.0)
	await _shot_current("from_boat.png")
	get_tree().quit()


func _shot(from: Vector3, at: Vector3, name: String) -> void:
	_cam.look_at_from_position(from, at)
	await _wait(0.4)
	await _shot_current(name)


func _shot_current(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(_out_dir.path_join(name))
	print("SHOT: %s" % name)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
