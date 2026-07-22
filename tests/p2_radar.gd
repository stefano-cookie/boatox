extends Node

## Smoke test del sistema P2 "nipote + radar" (GDD § Missioni): flusso
## della missione (NONE→ACCEPTED→CARRYING→DONE), sblocco radar, impulso
## con cooldown e finestra, potenziamenti (raggio/durata) e salvataggio.
## Stampa un verdetto per ogni sistema.
## Uso: Godot --path . --headless res://tests/p2_radar.tscn

var _main: Node
var _boat: Boat
var _npc: RescueNpc


func _ready() -> void:
	# File di salvataggio separato: i test non toccano quello vero.
	GameState.save_path = "user://save_test.json"
	GameState.reset()
	Radar.reset()
	_main = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	_boat = _main.get_node("Boat")
	_run()


func _run() -> void:
	await _wait(0.5)
	_npc = get_tree().get_first_node_in_group(&"rescue_npc") as RescueNpc

	# --- NPC presente e marker spento all'avvio ---
	print("NPC: trovato=%s, marker missione=%s (atteso false)" % [
		_npc != null, _npc.show_quest_marker()])
	print("RADAR INIZIALE: sbloccato=%s (atteso false), can_ping=%s (atteso false)" % [
		GameState.radar_unlocked, Radar.can_ping()])

	# --- Flusso missione: accetta, raccogli, consegna ---
	GameState.set_grandson_quest(GameState.GrandsonQuest.ACCEPTED)
	var marker_target := _npc.quest_marker_position()
	print("ACCETTATA: marker=%s (atteso true), bersaglio al largo=%s (atteso ~rescue_point)" % [
		_npc.show_quest_marker(), marker_target == _npc.rescue_point])
	GameState.set_grandson_quest(GameState.GrandsonQuest.CARRYING)
	print("A BORDO: bersaglio torna sull'NPC=%s (atteso true)" % [
		_npc.quest_marker_position() == _npc.global_position])
	GameState.set_grandson_quest(GameState.GrandsonQuest.DONE)
	print("CONSEGNATO: quest=%d (atteso 3=DONE), radar sbloccato=%s (atteso true), marker spento=%s (atteso false)" % [
		GameState.grandson_quest, GameState.radar_unlocked, not _npc.show_quest_marker()])

	# --- Impulso radar: attiva la finestra e avvia il cooldown ---
	print("PRE-PING: can_ping=%s (atteso true)" % Radar.can_ping())
	Radar.ping(Vector3(0, 0, 100))
	print("PING: attivo=%s (atteso true), finestra=%.0f (attesa 10), cooldown=%.0f (atteso 60), can_ping=%s (atteso false)" % [
		Radar.is_active(), Radar.window_left(), Radar.cooldown_left(), Radar.can_ping()])
	print("RAGGIO: origine=%s, frazione=%.2f (attesa 0.34 base)" % [Radar.origin(), Radar.range_fraction()])

	# --- Potenziamenti: raggio e durata salgono ---
	GameState.money = 5000
	var range_before := GameState.radar_range_fraction()
	var dur_before := GameState.radar_duration()
	GameState.buy_radar_upgrade(GameState.RadarUpgrade.RANGE)
	GameState.buy_radar_upgrade(GameState.RadarUpgrade.DURATION)
	print("UPGRADE: frazione %.2f -> %.2f (attesa in salita), durata %.0f -> %.0f (attesa in salita)" % [
		range_before, GameState.radar_range_fraction(), dur_before, GameState.radar_duration()])

	# --- Salvataggio: roundtrip di quest, sblocco e livelli radar ---
	GameState.save_game()
	GameState.grandson_quest = GameState.GrandsonQuest.NONE
	GameState.radar_unlocked = false
	GameState.radar_upgrades.clear()
	GameState.load_game()
	print("SALVATAGGIO: quest=%d (atteso 3), sbloccato=%s (atteso true), liv. raggio=%d (atteso 1), liv. durata=%d (atteso 1)" % [
		GameState.grandson_quest, GameState.radar_unlocked,
		GameState.radar_upgrade_level(GameState.RadarUpgrade.RANGE),
		GameState.radar_upgrade_level(GameState.RadarUpgrade.DURATION)])

	GameState.reset()
	Radar.reset()
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
