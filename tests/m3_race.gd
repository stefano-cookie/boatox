extends Node

## Smoke test della regata (M3): premi per piazzamento, conteggio
## vittorie col salvataggio, sblocco del Cabinato dopo la prima vittoria,
## percorso montato nel mondo e IA che partono al via e avanzano.
## Uso: Godot --path . --headless res://tests/m3_race.tscn

var _main: Node


func _ready() -> void:
	# File di salvataggio separato: i test non toccano quello vero.
	GameState.save_path = "user://save_test.json"
	GameState.reset()
	_main = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	_run()


func _run() -> void:
	await _wait(0.5)

	# --- Sblocco: il Cabinato chiede una vittoria, anche coi soldi ---
	GameState.money = 5000
	var locked_buy := GameState.buy_boat(&"cruiser")
	print("BLOCCO: cabinato sbloccato %s (atteso false), acquisto %s (atteso false)" % [
		GameState.boat_unlocked(&"cruiser"), locked_buy])

	# --- Premi: 2° posto +120, poi vittoria +300 e sblocco ---
	GameState.money = 0
	GameState.record_race_result(2, 4)
	var second_money := GameState.money
	GameState.record_race_result(1, 4)
	print("PREMI: 2° -> %d $ (attesi 120), poi 1° -> %d $ (attesi 420), vittorie %d (attesa 1)" % [
		second_money, GameState.money, GameState.race_wins])
	print("SBLOCCO: cabinato sbloccato %s (atteso true)" % GameState.boat_unlocked(&"cruiser"))

	# --- Premi scalati col tier: col peschereccio il 2° vale 120 × 1.6 ---
	GameState.owned_boats.append(&"fishing_boat")
	GameState.select_boat(&"fishing_boat")
	var tier_prize := GameState.race_prize(2)
	print("PREMI TIER: 2° col peschereccio %d $ (attesi 192), fuori podio %d (atteso 0)" % [
		tier_prize, GameState.race_prize(4)])
	GameState.select_boat(&"dinghy")

	# --- Salvataggio: le vittorie fanno il roundtrip ---
	GameState.save_game()
	GameState.race_wins = 0
	GameState.load_game()
	print("SALVATAGGIO: vittorie %d (attesa 1)" % GameState.race_wins)

	# --- Mondo: percorso montato con 7 cancelli ---
	var course := get_tree().get_first_node_in_group(&"race_course") as RaceCourse
	print("PERCORSO: presente %s (atteso true), cancelli %d (attesi 7)" % [
		course != null, course._waypoints.size()])

	# --- Gara dal vivo: conto alla rovescia, poi le IA avanzano ---
	var boat := _main.get_node("Boat") as Boat
	course._boat = boat
	course._start_race()
	print("PARTENZA: IA in griglia %d (attese 3), stato %d (atteso COUNTDOWN=1)" % [
		course._racers.size(), course._state])

	# --- IA relative: velocità come frazioni di quella del giocatore ---
	var player_speed := GameState.effective_max_speed()
	var ratios: Array[String] = []
	for racer: AIRacer in course._racers:
		ratios.append("%.2f" % (racer.max_speed / player_speed))
	print("IA RELATIVE: rapporti %s (attesi [0.90, 0.97, 1.03])" % [ratios])
	await _wait(3.5)
	var start_positions: Array[Vector3] = []
	for racer: AIRacer in course._racers:
		start_positions.append(racer.global_position)
	await _wait(3.0)
	var moved := 0
	for i in course._racers.size():
		if course._racers[i].global_position.distance_to(start_positions[i]) > 5.0:
			moved += 1
	print("VIA: stato %d (atteso RACING=2), IA in movimento %d/3 (attese 3)" % [
		course._state, moved])
	course._retire("test")

	GameState.reset()
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
