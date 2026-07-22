extends Node

## Smoke test di B2 (Bova cresce): costruzione negli slot (unicità e
## costi), tick di produzione della flottiglia con conversione della
## conserva e tetto del magazzino, vendita della produzione, salita di
## prosperità (da costruzione e vendite) e round-trip di salvataggio del
## world_state. Stampa un verdetto per ogni controllo.
## Uso: Godot --path . --headless res://tests/b2_town.tscn

var _levels_seen: Array[int] = []


func _ready() -> void:
	# File di salvataggio separato: i test non toccano quello vero.
	GameState.save_path = "user://save_test.json"
	GameState.reset()
	Town.prosperity_changed.connect(func(level: int) -> void: _levels_seen.append(level))
	_run()


func _run() -> void:
	GameState.money = 10000

	# --- Costruzione: molo al livello 1, denaro giù, punti su ---
	var ok := Town.build(&"molo", &"molo_grande")
	print("COSTRUZIONE: molo=%s (atteso true), denaro=%d (atteso 9400), livello=%d (atteso 1), punti=%d (atteso 40)" % [
		ok, GameState.money, Town.building_level(&"molo_grande"), Town.prosperity_points()])

	# --- Unicità: lo stesso edificio non sorge in due slot ---
	var dup := Town.build(&"lungomare", &"molo_grande")
	var occupied := Town.build(&"molo", &"conserva")
	print("UNICITÀ: doppione=%s (atteso false), slot occupato=%s (atteso false)" % [dup, occupied])

	# --- Tick: la flottiglia porta pesce (molo liv. 1 = 1/tick) ---
	Town.produce_tick()
	print("TICK: pesce=%d (atteso 1), conserve=%d (atteso 0)" % [
		Town.fish_stock(), Town.conserve_stock()])

	# --- Conserva: converte 1:1 il pesce in conserve ---
	Town.build(&"lungomare", &"conserva")
	Town.produce_tick()
	print("CONSERVA: pesce=%d (atteso 1), conserve=%d (attesa 1)" % [
		Town.fish_stock(), Town.conserve_stock()])

	# --- Potenziamento: molo liv. 2 → 2 pesci/tick ---
	ok = Town.upgrade(&"molo")
	print("POTENZIAMENTO: ok=%s (atteso true), livello=%d (atteso 2), resa=%d (attesa 2)" % [
		ok, Town.building_level(&"molo_grande"), Town.fish_rate_per_tick()])

	# --- Faro: la resa sale del 50% (2 → 3) ---
	Town.build(&"promontorio", &"faro")
	print("FARO: resa=%d (attesa 3)" % Town.fish_rate_per_tick())

	# --- Tetto del magazzino: senza edificio la capienza è 20 ---
	GameState.world_state["warehouse"] = {"fish": 19, "conserve": 0}
	Town.produce_tick()
	print("MAGAZZINO PIENO: totale=%d (atteso 20, capienza %d)" % [
		Town.fish_stock() + Town.conserve_stock(), Town.storage_capacity()])
	Town.build(&"paese", &"magazzino")
	print("MAGAZZINO: capienza=%d (attesa 50)" % Town.storage_capacity())

	# --- Vendita: denaro su, magazzino vuoto, punti dalla vendita ---
	GameState.world_state["warehouse"] = {"fish": 10, "conserve": 5}
	var points_before := Town.prosperity_points()
	var earned := Town.sell_warehouse()
	print("VENDITA: incasso=%d (atteso 140), pesce=%d (atteso 0), punti +%d (attesi +5)" % [
		earned, Town.fish_stock(), Town.prosperity_points() - points_before])

	# --- Prosperità: le soglie alzano il livello e lo notificano ---
	var level := Town.prosperity_level()
	print("PROSPERITÀ: punti=%d, livello=%d (atteso %d dalle soglie), notifiche=%s" % [
		Town.prosperity_points(), level,
		_expected_level(Town.prosperity_points()), _levels_seen])

	# --- Round-trip di salvataggio del world_state ---
	GameState.save_game()
	GameState.world_state = {}
	GameState.load_game()
	print("SALVATAGGIO: molo liv.=%d (atteso 2), faro liv.=%d (atteso 1), capienza=%d (attesa 50), livello=%d (atteso %d), punti=%d" % [
		Town.building_level(&"molo_grande"), Town.building_level(&"faro"),
		Town.storage_capacity(), Town.prosperity_level(), level, Town.prosperity_points()])

	GameState.reset()
	print("RESET: livello=%d (atteso 0), edifici=%d (attesi 0), pesce=%d (atteso 0)" % [
		Town.prosperity_level(), GameState.world_state["buildings"].size(), Town.fish_stock()])
	get_tree().quit()


func _expected_level(points: int) -> int:
	var level := 0
	for i in Town.PROSPERITY_THRESHOLDS.size():
		if points >= Town.PROSPERITY_THRESHOLDS[i]:
			level = i
	return level
