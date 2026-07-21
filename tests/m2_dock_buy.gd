extends Node

## Regressione M2: comprare una barca dal cantiere mentre si è attraccati
## sostituisce la collision shape e faceva scattare un body_exited fasullo
## dalla DockZone — il menu si chiudeva da solo lasciando la guida
## disabilitata per sempre. Qui si verifica che il cantiere resti aperto
## e che dopo la chiusura la barca risponda.
## Uso: Godot --path . --headless res://tests/m2_dock_buy.tscn

var _main: Node
var _boat: Boat
var _port: Port


func _ready() -> void:
	# File di salvataggio separato: i test non toccano quello vero.
	GameState.save_path = "user://save_test.json"
	GameState.reset()
	GameState.money = 1000
	_main = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	_boat = _main.get_node("Boat")
	_port = _main.get_node("World/Port")
	_run()


func _run() -> void:
	await _wait(0.5)
	_boat.global_position = _port.tow_spawn_position()
	_boat.reset_motion()
	await _wait(0.5)
	_press("interact")
	await _wait(0.3)
	print("MENU: aperto=%s (atteso true)" % _port._open)
	_port._open_shipyard()
	await _wait(0.2)
	var ok := GameState.buy_boat(&"fishing_boat")
	await _wait(0.5)
	print("ACQUISTO: ok=%s, menu ancora aperto=%s, cantiere aperto=%s (attesi true/true/true)" % [
		ok, _port._open, _port._shipyard_open])
	# Anche l'upgrade rimonta la collision shape: stesso rischio di
	# body_exited fasullo, stesso controllo.
	var upgraded := GameState.buy_upgrade(GameState.UpgradeType.HULL)
	await _wait(0.5)
	print("UPGRADE: ok=%s, menu ancora aperto=%s, cantiere aperto=%s (attesi true/true/true)" % [
		upgraded, _port._open, _port._shipyard_open])
	_press("interact")
	await _wait(0.2)
	_press("interact")
	await _wait(0.3)
	print("CHIUSURA: input_enabled=%s (atteso true)" % _boat.input_enabled)
	var start := _boat.global_position
	Input.action_press("move_forward")
	await _wait(3.0)
	Input.action_release("move_forward")
	print("MOVIMENTO: spostamento=%.2f m (atteso >5)" % start.distance_to(_boat.global_position))
	GameState.reset()
	get_tree().quit()


func _press(action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = action
	Input.parse_input_event(release)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
