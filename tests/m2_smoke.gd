extends Node

## Smoke test di M2: flotta, upgrade, limite stiva, salvataggio e meteo
## con destabilizzazione. Stampa un verdetto per ogni sistema.
## Uso: Godot --path . --headless res://tests/m2_smoke.tscn

var _main: Node
var _boat: Boat


func _ready() -> void:
	# File di salvataggio separato: i test non toccano quello vero.
	GameState.save_path = "user://save_test.json"
	GameState.reset()
	_main = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	_boat = _main.get_node("Boat")
	_run()


func _run() -> void:
	await _wait(0.5)

	# --- Flotta: listino e acquisto con guida distinta ---
	print("FLOTTA: %d barche a listino (attese 3)" % GameState.BOAT_DEFS.size())
	var speed_before := _boat.max_speed
	GameState.money = 5000
	var bought := GameState.buy_boat(&"fishing_boat")
	await _wait(0.2)
	print("ACQUISTO: riuscito=%s, denaro=%d (atteso 4400), vel barca %.1f -> %.1f (attesa 16)" % [
		bought, GameState.money, speed_before, _boat.max_speed])

	# --- Upgrade motore: la velocità effettiva deve salire ---
	var upgraded := GameState.buy_upgrade(GameState.UpgradeType.MOTOR)
	await _wait(0.2)
	print("UPGRADE: riuscito=%s, livello=%d, vel effettiva=%.1f (attesa 17.8)" % [
		upgraded, GameState.upgrade_level(GameState.UpgradeType.MOTOR), _boat.max_speed])

	# --- Stiva: a capacità piena la raccolta viene rifiutata ---
	GameState.cargo.clear()
	var capacity := GameState.cargo_capacity()
	var accepted := 0
	for i in capacity + 3:
		if GameState.collect_buoy(GameState.BuoyType.YELLOW):
			accepted += 1
	print("STIVA: accettate %d boe su %d tentativi (capacità %d)" % [
		accepted, capacity + 3, capacity])

	# --- Salvataggio: roundtrip completo ---
	GameState.save_game()
	var money_saved := GameState.money
	GameState.money = 0
	GameState.cargo.clear()
	GameState.current_boat_id = &"dinghy"
	GameState.load_game()
	print("SALVATAGGIO: denaro=%d (atteso %d), stiva=%d (attesa %d), barca=%s (attesa fishing_boat), upgrade motore=%d (atteso 1)" % [
		GameState.money, money_saved, GameState.cargo_count(), capacity,
		GameState.current_boat_id, GameState.upgrade_level(GameState.UpgradeType.MOTOR)])

	# --- Meteo: il mosso alza il moltiplicatore del mare ---
	var weather: Weather = _main.get_node("Weather")
	var sea: Sea = _main.get_node("Sea")
	weather._flip_state()
	await _wait(3.0)
	print("METEO: mosso=%s, moltiplicatore=%.2f (atteso >1 e crescente)" % [
		weather.rough, sea.weather_multiplier])

	# --- Caos: la barchetta al largo col mosso perde la prua da sola,
	# --- il mare la frena e la tempesta le mangia lo scafo ---
	GameState.select_boat(&"dinghy")
	await _wait(0.2)
	_boat.reset_motion()
	# Mare aperto profondo: con la curva continua il danno da tempesta
	# scatta solo molto al largo (o dentro una cella di vento).
	_boat.global_position = Vector3(0, 0.0, 480)
	_boat.rotation.y = 0.0
	var hull_before := GameState.hull
	Input.action_press("move_forward")
	await _wait(4.0)
	var storm_speed := absf(_boat.current_speed())
	Input.action_release("move_forward")
	var drift := absf(wrapf(_boat.rotation.y, -PI, PI))
	print("CAOS: deriva di prua %.2f rad senza sterzare (attesa >0.05 con la barchetta)" % drift)
	print("TEMPESTA: vel %.1f su max %.1f (attesa ~metà), scafo %.1f -> %.1f (atteso in calo)" % [
		storm_speed, _boat.max_speed, hull_before, GameState.hull])

	GameState.reset()
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
