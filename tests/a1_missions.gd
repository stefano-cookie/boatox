extends Node

## Test A1: reputazione (prezzi scontati/rincarati), bacheca missioni
## (consegna con casse in stiva, recupero col pacco, timeout, salvataggio)
## ed effetti degli eventi casuali. Stampa un verdetto per sistema.
## Uso: Godot --path . --headless res://tests/a1_missions.tscn

var _main: Node
var _world: World


func _ready() -> void:
	# File di salvataggio separato: i test non toccano quello vero.
	GameState.save_path = "user://save_test.json"
	GameState.reset()
	_main = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	_world = _main.get_node("World")
	_run()


func _run() -> void:
	await _wait(0.5)

	# --- Reputazione: ±15% a fondo scala sui prezzi di porto ---
	GameState.add_reputation(50)
	print("REPUTAZIONE: valore=%d (atteso 50), moltiplicatore=%.3f (atteso 0.925)" % [
		GameState.reputation_value(), GameState.price_multiplier()])
	GameState.add_reputation(-200)
	print("REPUTAZIONE: clamp a %d (atteso -100), moltiplicatore=%.3f (atteso 1.150)" % [
		GameState.reputation_value(), GameState.price_multiplier()])
	GameState.add_reputation(100)  # torna a 0

	# --- Bacheca: 3 offerte generate (consegna + 2 recuperi) ---
	var offers := GameState.generate_mission_offers(_world)
	var types: Array[int] = []
	for offer in offers:
		types.append(int(offer.type))
	print("BACHECA: %d offerte (attese 3), tipi=%s (atteso [0, 1, 1])" % [offers.size(), types])

	# --- Consegna: le casse occupano stiva, si consegna solo all'approdo ---
	var delivery: Dictionary = offers[0]
	var accepted := GameState.accept_mission(delivery)
	print("CONSEGNA: accettata=%s, stiva=%d (attese %d casse), tempo=%.0f s" % [
		accepted, GameState.cargo_count(), int(delivery.crates), GameState.mission_time_left])
	var wrong_port := GameState.try_complete_mission_at_port(false)
	var money_before := GameState.money
	var right_port := GameState.try_complete_mission_at_port(true)
	print("CONSEGNA: al porto sbagliato=%s (atteso false), all'approdo=%s, +%d $ (atteso %d), rep=%d (atteso 5)" % [
		wrong_port, right_port, GameState.money - money_before, int(delivery.reward),
		GameState.reputation_value()])

	# --- Consegna rifiutata a stiva piena ---
	for i in GameState.cargo_capacity():
		GameState.collect_buoy(GameState.BuoyType.YELLOW)
	var full_accept := GameState.accept_mission(offers[0])
	print("STIVA PIENA: accettata=%s (atteso false)" % full_accept)
	GameState.inventory.clear()
	GameState.cargo_changed.emit()

	# --- Recupero: pacco spawna, si raccoglie, si riconsegna al porto ---
	var recovery: Dictionary = offers[1]
	GameState.accept_mission(recovery)
	await _wait(0.2)
	var pickups := get_tree().get_nodes_in_group(&"mission_pickups").size()
	print("RECUPERO: accettato, pacchi in acqua=%d (atteso 1), marker=%s (atteso %s)" % [
		pickups, GameState.mission_marker_position(), recovery.target])
	GameState.mission_pickup_collected()
	await _wait(0.2)
	var pickups_after := 0
	for node in get_tree().get_nodes_in_group(&"mission_pickups"):
		if not node.is_queued_for_deletion():
			pickups_after += 1
	var marker_home := GameState.mission_marker_position() == (recovery.get("return") as Vector3)
	money_before = GameState.money
	var landing_refuses := GameState.try_complete_mission_at_port(true)
	var home_accepts := GameState.try_complete_mission_at_port(false)
	print("RECUPERO: pacco a bordo (in acqua=%d, atteso 0), marker sul porto=%s, approdo=%s (atteso false), porto=%s, +%d $ (atteso %d)" % [
		pickups_after, marker_home, landing_refuses, home_accepts,
		GameState.money - money_before, int(recovery.reward)])

	# --- Timeout consegna: missione fallita, reputazione giù ---
	var rep_before := GameState.reputation_value()
	var offers2 := GameState.generate_mission_offers(_world)
	GameState.accept_mission(offers2[0])
	GameState.mission_time_left = 0.1
	await _wait(0.5)
	print("TIMEOUT: missione attiva=%s (atteso false), stiva=%d (attesa 0), rep %d -> %d (atteso -5)" % [
		GameState.mission_active(), GameState.cargo_count(), rep_before, GameState.reputation_value()])

	# --- Salvataggio: la missione sopravvive al roundtrip (Vector3 inclusi) ---
	var offers3 := GameState.generate_mission_offers(_world)
	GameState.accept_mission(offers3[1])
	var target_saved: Vector3 = GameState.active_mission.target
	GameState.save_game()
	GameState.active_mission.clear()
	GameState.load_game()
	print("SALVATAGGIO: tipo=%d (atteso 1), target=%s (atteso %s), rep=%d" % [
		GameState.mission_type(), GameState.active_mission.get("target"), target_saved,
		GameState.reputation_value()])
	GameState.abandon_mission()

	# --- Eventi: effetti applicati con i clamp (scafo mai sotto 5) ---
	GameState.money = 100
	var fuel_before := GameState.fuel
	GameState.apply_event_choice(-10, -5.0, -500.0, 3)
	print("EVENTI: denaro=%d (atteso 90), benzina %.0f -> %.0f (atteso -5), scafo=%.0f (atteso 5), rep +3=%d" % [
		GameState.money, fuel_before, GameState.fuel, GameState.hull, GameState.reputation_value()])
	var director: EventDirector = _main.get_node("EventDirector")
	print("EVENTI: %d eventi caricati (attesi 6), primo=%s" % [
		director.events.size(), director.events[0].title if director.events.size() > 0 else "-"])

	GameState.reset()
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
