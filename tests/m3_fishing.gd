extends Node

## Smoke test della pesca (M3): stiva unica condivisa tra boe e pesci
## col tetto di capacità, valore e vendita del carico misto, roundtrip
## del salvataggio, zone di pesca spawnate una per fascia nel mondo.
## Uso: Godot --path . --headless res://tests/m3_fishing.tscn

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

	# --- Stiva condivisa: boe + pesci contro la stessa capacità (8) ---
	for i in 4:
		GameState.collect_fish(GameState.FishType.SARDINE)
	for i in 3:
		GameState.collect_buoy(GameState.BuoyType.YELLOW)
	GameState.collect_fish(GameState.FishType.TUNA)
	var overflow := GameState.collect_fish(GameState.FishType.BREAM)
	print("STIVA: %d/%d dopo 8 raccolte (attesi 8/8), nona rifiutata: %s (atteso false)" % [
		GameState.cargo_count(), GameState.cargo_capacity(), overflow])

	# --- Valore misto: 4 sardine (32) + 3 gialle (30) + 1 tonno (250) ---
	print("VALORE: %d $ (attesi 312) — dettaglio: %s" % [
		GameState.cargo_value(), GameState.cargo_detail_bbcode()])

	# --- Vendita: incassa tutto e svuota anche i pesci ---
	GameState.money = 0
	var earned := GameState.sell_cargo()
	print("VENDITA: +%d $ (attesi 312), stiva %d (attesa 0), pesci %d (attesi 0)" % [
		earned, GameState.cargo_count(), GameState.fish_cargo.size()])

	# --- Salvataggio: i pesci fanno il roundtrip ---
	GameState.collect_fish(GameState.FishType.AMBERJACK)
	GameState.collect_fish(GameState.FishType.AMBERJACK)
	GameState.save_game()
	GameState.fish_cargo.clear()
	GameState.load_game()
	print("SALVATAGGIO: %d ricciole (attese 2)" % GameState.fish_cargo.get(
		GameState.FishType.AMBERJACK, 0))

	# --- Mondo: una zona di pesca per fascia di mare (due al largo) ---
	var tiers: Array[int] = []
	for node in get_tree().get_nodes_in_group(&"fishing_zones"):
		tiers.append((node as FishingZone).zone_tier)
	tiers.sort()
	print("ZONE: %d nel mondo, fasce %s (attese [0, 1, 2, 2])" % [tiers.size(), tiers])

	# --- Duello (fase 2): tenere E recupera lenza ma alza la tensione ---
	GameState.reset()
	var zone := get_tree().get_first_node_in_group(&"fishing_zones") as FishingZone
	zone._fight_type = GameState.FishType.SARDINE
	zone._fight_prize = false
	zone._start_fight()
	Input.action_press("interact")
	for i in 60:
		zone._update_fight(1.0 / 30.0)
	Input.action_release("interact")
	var held_progress: float = zone._progress
	var held_tension: float = zone._tension
	for i in 30:
		zone._update_fight(1.0 / 30.0)
	print("DUELLO: dopo 2 s di recupero progresso %.2f (atteso ~0.72) e tensione %.2f (attesa ~0.95); mollando la tensione cala a %.2f" % [
		held_progress, held_tension, zone._tension])
	zone._end_fishing()

	GameState.reset()
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
