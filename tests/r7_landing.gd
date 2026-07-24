extends Node

## Smoke test di R7 (prima persona su Bova): catalogo incarichi NPC,
## accettazione/progresso/consegna con regalo, round-trip di salvataggio,
## nodi della Bova a piedi (walker, datori, item a terra, arsenale) e
## ciclo sbarco/rientro col LandingSystem. Stampa un verdetto per riga.
## Uso: Godot --path . --headless res://tests/r7_landing.tscn

var _main: Node


func _ready() -> void:
	# File di salvataggio separato: i test non toccano quello vero.
	GameState.save_path = "user://save_test.json"
	GameState.reset()
	Radar.reset()
	_main = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	_run()


func _run() -> void:
	await _wait(0.8)

	# --- Catalogo incarichi: 3 datori, richieste su item veri, paga giusta ---
	var npc_count := 0
	var bad_offers := 0
	for npc_id: StringName in GameState.NPC_MISSIONS:
		npc_count += 1
		for offer: Dictionary in GameState.NPC_MISSIONS[npc_id]:
			var needs: Dictionary = offer.get("needs", {})
			var sell_value := 0
			for id: String in needs:
				var def := GameState.item_def(StringName(id))
				if def == null:
					bad_offers += 1
					print("  CATALOGO KO: item sconosciuto %s in %s" % [id, offer.get("id")])
					continue
				sell_value += def.base_value * int(needs[id])
			var gift := str(offer.get("reward_item", ""))
			if gift != "" and GameState.item_def(StringName(gift)) == null:
				bad_offers += 1
				print("  CATALOGO KO: regalo sconosciuto %s" % gift)
			var reward := int(offer.get("reward", 0))
			var gift_value := 0
			if gift != "":
				gift_value = GameState.item_def(StringName(gift)).base_value
			if reward + gift_value <= sell_value:
				bad_offers += 1
				print("  CATALOGO KO: %s paga %d ma la roba vale %d" % [
					offer.get("id"), reward + gift_value, sell_value,
				])
	print("CATALOGO NPC: %d datori, offerte non valide %d (atteso 3 e 0)" % [npc_count, bad_offers])

	# --- Accetta, raccogli, tracker ---
	var offer: Dictionary = GameState.NPC_MISSIONS[&"mastro_cola"][0]
	var accepted := GameState.accept_npc_mission(&"mastro_cola", "Mastro Cola", offer)
	var second := GameState.accept_npc_mission(&"donna_rosa", "Donna Rosa",
		GameState.NPC_MISSIONS[&"donna_rosa"][0])
	print("ACCETTAZIONE: prima %s, seconda rifiutata %s (atteso true true)" % [accepted, not second])
	GameState.collect_item(&"goods_legno")
	var mid_progress := GameState.npc_needs_progress()
	GameState.collect_item(&"goods_legno")
	GameState.collect_item(&"goods_legno")
	var tracker := GameState.active_missions()
	print("PROGRESSO: 1/3 a metà %s, completo %s, tracker '%s' (atteso true true e riga con 3/3)" % [
		mid_progress == Vector2i(1, 3), GameState.npc_needs_met(),
		tracker[0].get("progress", "") if not tracker.is_empty() else "",
	])

	# --- Round-trip salvataggio con incarico attivo ---
	GameState.save_game()
	GameState.load_game()
	var after_type := GameState.mission_type()
	var after_met := GameState.npc_needs_met()
	print("SALVATAGGIO: tipo %d, richiesta ancora completa %s (atteso 2 true)" % [after_type, after_met])

	# --- Consegna: denaro, reputazione, spunta, offerta sparita ---
	var money_before := GameState.money
	var rep_before := GameState.reputation_value()
	var delivered := GameState.deliver_npc_mission(&"mastro_cola")
	var gained := GameState.money - money_before
	var offers_left := GameState.npc_offers(&"mastro_cola").size()
	print("CONSEGNA: %s, +%d $ (atteso %d), rep +%d, legno rimasto %d, offerte restanti %d (atteso 2)" % [
		delivered, gained, int(offer.get("reward", 0)),
		GameState.reputation_value() - rep_before,
		GameState.item_count(&"goods_legno"), offers_left,
	])

	# --- Regalo: gli agrumi di Donna Rosa fruttano un'anfora ---
	GameState.accept_npc_mission(&"donna_rosa", "Donna Rosa",
		GameState.NPC_MISSIONS[&"donna_rosa"][2])
	GameState.collect_item(&"goods_agrumi")
	GameState.collect_item(&"goods_agrumi")
	GameState.deliver_npc_mission(&"donna_rosa")
	print("REGALO: anfora in stiva %s (atteso true)" % (GameState.item_count(&"treasure_anfora") == 1))

	# --- La Bova a piedi esiste: walker, datori, item a terra, arsenale ---
	var walker := _main.get_node("Walker") as Walker
	var npcs := get_tree().get_nodes_in_group(&"town_npcs").size()
	var items := 0
	var landing_root := _main.get_node("World/BovaLanding")
	for child in landing_root.get_children():
		if child is GroundItem:
			items += 1
	var arsenal_found := false
	for child in landing_root.get_children():
		if child is Arsenal:
			arsenal_found = true
	print("PAESE A PIEDI: walker %s, datori %d, item a terra %d, arsenale %s (atteso true 3 6 true)" % [
		walker != null, npcs, items, arsenal_found,
	])

	# --- Sbarco al molo e rientro ---
	var landing := _main.get_node("Landing") as LandingSystem
	var boat := _main.get_node("Boat") as Boat
	var world := _main.get_node("World") as World
	boat.reset_motion()
	boat.global_position = world.port_position() + Vector3(-4.0, 0.0, 6.0)
	await _wait(0.3)
	var can_disembark: bool = landing._can_disembark()
	landing._disembark()
	await _wait(0.5)
	var ashore := GameState.on_foot and walker.active
	var walker_y := walker.global_position.y
	var can_board: bool = landing._can_board()
	landing._board()
	var back := not GameState.on_foot and boat.input_enabled
	print("SBARCO: possibile %s, a terra %s (y=%.2f), rientro possibile %s, a bordo %s (atteso tutti true, y sulle assi ~0.7)" % [
		can_disembark, ashore, walker_y, can_board, back,
	])

	print("R7 TEST: fine")
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
