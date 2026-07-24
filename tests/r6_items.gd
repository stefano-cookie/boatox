extends Node

## Smoke test di R6 (item e fonti in mare): catalogo merci/tesori,
## raccolta generica per id con round-trip di salvataggio, merce delle
## prede per fazione, relitti nel mondo con casse di merci/tesori, e
## probabilità della pesca speciale. Stampa un verdetto per ogni controllo.
## Uso: Godot --path . --headless res://tests/r6_items.tscn

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

	# --- Catalogo: le 6 merci e i 4 tesori esistono e sono vendibili ---
	var ids: Array[StringName] = [
		&"goods_legno", &"goods_ferro", &"goods_stoffa", &"goods_spezie",
		&"goods_agrumi", &"goods_datteri",
		&"treasure_anfora", &"treasure_perla", &"treasure_carta", &"treasure_statuetta",
	]
	var missing := 0
	for id in ids:
		var def := GameState.item_def(id)
		if def == null or not def.sellable or def.base_value <= 0:
			missing += 1
			print("  CATALOGO KO: %s" % id)
	print("CATALOGO: %d/10 item validi (atteso 10)" % (ids.size() - missing))

	# --- Raccolta generica: stiva, valore, toast via segnale ---
	var toasts: Array[StringName] = []
	GameState.item_collected.connect(func(id: StringName) -> void: toasts.append(id))
	GameState.collect_item(&"goods_spezie")
	GameState.collect_item(&"treasure_perla")
	print("RACCOLTA: stiva=%d (atteso 2), valore=%d (atteso %d), toast=%d (atteso 2)" % [
		GameState.cargo_count(), GameState.cargo_value(),
		GameState.item_def(&"goods_spezie").base_value + GameState.item_def(&"treasure_perla").base_value,
		toasts.size()])
	print("SCONOSCIUTO: collect_item(xyz)=%s (atteso false)" % GameState.collect_item(&"xyz"))

	# --- Round-trip salvataggio ---
	GameState.save_game()
	var spezie := GameState.item_count(&"goods_spezie")
	GameState.inventory.clear()
	GameState.load_game()
	print("SALVATAGGIO: spezie dopo il round-trip=%d (atteso %d), perle=%d (atteso 1)" % [
		GameState.item_count(&"goods_spezie"), spezie, GameState.item_count(&"treasure_perla")])

	# --- Merce delle prede: fazione di città → merce tipica nel mix ---
	var pool: Array[StringName] = [&"goods_legno", &"goods_ferro"]
	var typical := 0
	for i in 200:
		if GameState.ship_goods_item(GameState.FACTION_CATANIA, pool) == &"goods_agrumi":
			typical += 1
	print("PREDE CATANIA: agrumi %d/200 (atteso ~120, peso 0.6)" % typical)
	var generic := GameState.ship_goods_item(&"predoni", pool)
	print("PREDE GENERICHE: item=%s (atteso nel pool)" % generic)
	print("POOL VUOTO: item=\"%s\" (atteso vuoto)" % GameState.ship_goods_item(&"predoni", []))

	# --- Estrazione a peso: mai id fuori catalogo ---
	var bad := 0
	for i in 300:
		if GameState.item_def(GameState.pick_weighted_item(GameState.TREASURE_WEIGHTS)) == null:
			bad += 1
	print("PESO: estrazioni fuori catalogo=%d (atteso 0)" % bad)

	# --- Relitti nel mondo: spawnati e con casse allo scoperto ---
	var wrecks := get_tree().get_nodes_in_group(&"wrecks")
	print("RELITTI: %d in acqua (atteso 5: 2 baia + 3 traversata)" % wrecks.size())
	if not wrecks.is_empty():
		var wreck := wrecks[0] as Wreck
		var before := get_tree().get_nodes_in_group(&"loot_crates").size()
		wreck._spill_crates()
		await _wait(0.2)
		var after := get_tree().get_nodes_in_group(&"loot_crates").size()
		print("RELITTO SACCHEGGIATO: casse +%d (atteso 4-6), has_loot=%s (atteso false)" % [
			after - before, wreck.has_loot()])
		var with_item := 0
		for node in get_tree().get_nodes_in_group(&"loot_crates"):
			if (node as LootCrate).item_id != &"":
				with_item += 1
		print("CASSE RELITTO: %d/%d con item_id (attese tutte le nuove)" % [with_item, after])

	# --- Pesca speciale: probabilità 0 sotto costa, > 0 al largo profondo ---
	var sea: Sea = _main.get_node("World").sea
	var near := GameState.fishing_treasure_chance(Vector3(0, 0, sea.shore_z + 30.0), sea)
	var far := GameState.fishing_treasure_chance(
		Vector3(0, 0, sea.shore_z + 2500.0), sea)
	print("PESCA SPECIALE: sotto costa=%.3f (atteso 0), largo=%.3f (atteso >0.1, max %.2f)" % [
		near, far, GameState.FISHING_TREASURE_CHANCE_MAX])

	GameState.reset()
	Radar.reset()
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
