extends Node

## Smoke test di B4 (il mare grande): confini allargati, le due città-costa
## con rada calma, gli scali di rifornimento neutrali della traversata, il
## piano del mare che segue libero oltre la baia, le fazioni delle città
## (Catania e Il Cairo ostili dal primo giorno, anche a freddo), i direttori
## navali per zona e i pickup della traversata. Stampa un verdetto per ogni
## controllo.
## Uso: Godot --path . --headless res://tests/b4_world.tscn

var _main: Node


func _ready() -> void:
	# File di salvataggio separato: i test non toccano quello vero.
	GameState.save_path = "user://save_test.json"
	GameState.reset()
	_main = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	_run()


func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	var sea: Sea = _main.get_node("Sea")
	var world: World = _main.get_node("World")

	# --- Fazioni: le due città sono ostili dal primo giorno ---
	print("FAZIONI: catania=%d (atteso -40, ostile=%s), cairo=%d (atteso -40, ostile=%s)" % [
		GameState.reputation_value(&"catania"), Diplomacy.is_hostile(&"catania"),
		GameState.reputation_value(&"cairo"), Diplomacy.is_hostile(&"cairo")])

	# --- Porti, città, rade e scali in mappa ---
	var ports := get_tree().get_nodes_in_group(&"ports")
	var cities := get_tree().get_nodes_in_group(&"cities")
	var harbors := get_tree().get_nodes_in_group(&"calm_harbors")
	var supply := get_tree().get_nodes_in_group(&"supply_islands")
	print("MAPPA: porti=%d (attesi 7), città=%d (attese 2), scali=%d (attesi 3), rade=%d (attese 5), confini=%dx%d" % [
		ports.size(), cities.size(), supply.size(), harbors.size(),
		roundi(world.bounds_half_width * 2.0), roundi(world.bounds_depth)])

	# --- Rada calma: davanti a Catania il mare è delle acque calme, al largo no ---
	var rada := Vector3(-1650.0, 0.0, 2440.0)
	var largo := Vector3(0.0, 0.0, 2000.0)
	print("RADA: moltiplicatore in rada=%.2f (atteso ~0.6-1.3), al largo=%.2f (atteso >2), zona in rada=%d (attesa 0)" % [
		sea.state_multiplier(rada), sea.state_multiplier(largo), sea.zone_index(rada)])

	# --- Scalo di rifornimento: anche lo Scalo di Mezzo ha la sua rada calma ---
	var scalo := Vector3(200.0, 0.0, 1350.0)
	print("SCALO: rada allo Scalo di Mezzo=%.2f (attesa ~0.6), al largo lì accanto=%.2f (atteso >2)" % [
		sea.state_multiplier(scalo), sea.state_multiplier(Vector3(600.0, 0.0, 1350.0))])

	# --- Piano del mare: segue libero oltre la baia, resta agganciato sotto costa ---
	# _process chiamato a mano: al title l'albero è in pausa e il piano
	# non seguirebbe mai (in gioco vero segue ogni frame).
	var dummy := Node3D.new()
	add_child(dummy)
	var old_target := sea.follow_target
	sea.follow_target = dummy
	dummy.global_position = Vector3(0.0, 0.0, 2500.0)
	sea._process(0.016)
	var far_z := sea.global_position.z
	dummy.global_position = Vector3(0.0, 0.0, 560.0)
	sea._process(0.016)
	var near_z := sea.global_position.z
	sea.follow_target = old_target
	print("PIANO MARE: al largo z=%.0f (atteso ~2500), sotto costa z=%.0f (atteso 500)" % [far_z, near_z])

	# --- Navi: ogni zona ha le sue, le città marchiano la fazione ---
	var ships: Array[Ship] = []
	_collect_ships(world, ships)
	var catania := 0
	var cairo := 0
	var catania_pos := Vector3(-1650.0, 0.0, 2500.0)
	var cairo_pos := Vector3(1950.0, 0.0, 3550.0)
	var catania_vicini := true
	var cairo_vicini := true
	for ship in ships:
		if ship.faction == &"catania":
			catania += 1
			if ship.global_position.distance_to(catania_pos) > 1000.0:
				catania_vicini = false
		elif ship.faction == &"cairo":
			cairo += 1
			if ship.global_position.distance_to(cairo_pos) > 1000.0:
				cairo_vicini = false
	print("NAVI: totali=%d (attese 13), predoni Catania=%d (attesi 2, vicini=%s), predoni Cairo=%d (attesi 2, vicini=%s)" % [
		ships.size(), catania, catania_vicini, cairo, cairo_vicini])

	# --- Traversata: taniche e boe blu anche oltre la baia ---
	var route_cans := 0
	for node in get_tree().get_nodes_in_group(&"fuel_cans"):
		if sea.shore_distance((node as Node3D).global_position) > world.bay_depth:
			route_cans += 1
	print("TRAVERSATA: taniche oltre la baia=%d (attese >8)" % route_cans)

	# --- Salvataggio: le relazioni sopravvivono, i default non le schiacciano ---
	GameState.add_reputation(15, &"catania")
	GameState.add_reputation(10, &"cairo")
	GameState.save_game()
	GameState.reputation.clear()
	GameState.load_game()
	print("SALVATAGGIO: catania=%d (atteso -25), cairo=%d (atteso -30)" % [
		GameState.reputation_value(&"catania"), GameState.reputation_value(&"cairo")])

	get_tree().quit()


func _collect_ships(node: Node, out: Array[Ship]) -> void:
	for child in node.get_children():
		if child is Ship:
			out.append(child)
		_collect_ships(child, out)
