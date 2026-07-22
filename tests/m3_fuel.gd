extends Node

## Smoke test della benzina (M3): consumo col gas, riserva d'emergenza a
## serbatoio vuoto, tanica con tetto al pieno, rifornimento pieno e
## parziale, salvataggio. Stampa un verdetto per ogni sistema.
## Uso: Godot --path . --headless res://tests/m3_fuel.tscn

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

	# --- Consumo: il gas svuota il serbatoio ---
	var fuel_before := GameState.fuel
	Input.action_press("move_forward")
	await _wait(3.0)
	Input.action_release("move_forward")
	print("CONSUMO: benzina %.2f -> %.2f L (attesa in calo di ~0.3)" % [
		fuel_before, GameState.fuel])

	# --- Riserva: a serbatoio vuoto la velocità è quella d'emergenza ---
	GameState.fuel = 0.0
	_boat.reset_motion()
	Input.action_press("move_forward")
	await _wait(4.0)
	var reserve_actual := absf(_boat.current_speed())
	Input.action_release("move_forward")
	print("RISERVA: vel %.2f m/s a secco (attesa <= %.2f)" % [
		reserve_actual, _boat.reserve_speed + 0.3])

	# --- Tanica: riempie di 15 L e non oltre il pieno ---
	GameState.fuel = 0.0
	GameState.add_fuel(GameState.FUEL_CAN_LITERS)
	var after_can := GameState.fuel
	GameState.add_fuel(9999.0)
	print("TANICA: 0 -> %.1f L (attesi %.1f), overflow -> %.1f (attesa capacità %.1f)" % [
		after_can, GameState.FUEL_CAN_LITERS, GameState.fuel, GameState.fuel_capacity()])

	# --- Rifornimento pieno: costo = litri mancanti × prezzo ---
	GameState.fuel = GameState.fuel_capacity() * 0.5
	GameState.money = 1000
	var expected_cost := ceili((GameState.fuel_capacity() - GameState.fuel) \
		* GameState.FUEL_PRICE_PER_LITER)
	var cost := GameState.refuel_cost()
	GameState.refuel()
	print("PIENO: costo %d (atteso %d), benzina %.1f/%.1f, denaro %d (atteso %d)" % [
		cost, expected_cost, GameState.fuel, GameState.fuel_capacity(), GameState.money,
		1000 - expected_cost])

	# --- Rifornimento parziale: coi soldi contati si riempie quel che si può ---
	GameState.fuel = 0.0
	GameState.money = 10
	GameState.refuel()
	print("PARZIALE: benzina %.1f L (attesi 10), denaro %d (atteso 0)" % [
		GameState.fuel, GameState.money])

	# --- Salvataggio: la benzina fa il roundtrip ---
	GameState.fuel = 17.0
	GameState.save_game()
	GameState.fuel = 1.0
	GameState.load_game()
	print("SALVATAGGIO: benzina %.1f L (attesi 17)" % GameState.fuel)

	GameState.reset()
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
