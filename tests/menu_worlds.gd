extends Node

## Smoke test del menu dei mondi (title screen stile Minecraft): crea,
## elenca, cambia ed elimina mondi tramite l'API di GameState, su una
## cartella separata (quella vera del giocatore non si tocca). La UI non
## si testa headless: qui si verifica la meccanica sotto.
## Uso: Godot --path . --headless res://tests/menu_worlds.tscn

func _ready() -> void:
	# Percorsi separati: i test non toccano salvataggi e mondi veri.
	GameState.save_path = "user://save_test.json"
	GameState.worlds_dir = "user://worlds_test"
	_clean_worlds_dir()
	GameState.reset()
	_run()


func _run() -> void:
	# --- Creazione: file col nome giusto, slug pulito dal nome ---
	GameState.create_world("Mondo Uno")
	var first_path := GameState.save_path
	GameState.money = 500
	GameState.save_game()
	print("CREAZIONE: file=%s (atteso .../mondo-uno.json), nome=%s (atteso Mondo Uno), mondi=%d (atteso 1)" % [
		first_path.get_file(), GameState.world_name, GameState.list_worlds().size()])

	# --- Secondo mondo: slug con caratteri strani, lista ordinata ---
	await get_tree().create_timer(1.1).timeout  # last_played deve differire
	GameState.create_world("  La Baia... Segreta!  ")
	var second_path := GameState.save_path
	print("SLUG: file=%s (atteso la-baia-segreta.json), denaro=%d (atteso 0, partita nuova)" % [
		second_path.get_file(), GameState.money])
	var worlds := GameState.list_worlds()
	print("LISTA: mondi=%d (attesi 2), più recente=%s (atteso il secondo)" % [
		worlds.size(), str(worlds[0]["name"])])

	# --- Cambio mondo: lo stato del primo torna com'era ---
	GameState.switch_world(first_path)
	print("CAMBIO: nome=%s (atteso Mondo Uno), denaro=%d (atteso 500)" % [
		GameState.world_name, GameState.money])

	# --- Nome duplicato: file distinto, niente sovrascritture ---
	GameState.create_world("Mondo Uno")
	print("DUPLICATO: file=%s (atteso mondo-uno-2.json), mondi=%d (attesi 3)" % [
		GameState.save_path.get_file(), GameState.list_worlds().size()])

	# --- Eliminazione di un altro mondo: il corrente resta ---
	GameState.delete_world(second_path)
	print("ELIMINA ALTRO: mondi=%d (attesi 2), corrente=%s (atteso mondo-uno-2.json)" % [
		GameState.list_worlds().size(), GameState.save_path.get_file()])

	# --- Eliminazione del corrente: si passa al più recente rimasto ---
	GameState.delete_world(GameState.save_path)
	print("ELIMINA CORRENTE: mondi=%d (atteso 1), nome=%s (atteso Mondo Uno), denaro=%d (atteso 500)" % [
		GameState.list_worlds().size(), GameState.world_name, GameState.money])

	# --- Ultimo mondo eliminato: stato vergine, senza file ---
	GameState.delete_world(GameState.save_path)
	print("ULTIMO: mondi=%d (attesi 0), denaro=%d (atteso 0), file esiste=%s (atteso false)" % [
		GameState.list_worlds().size(), GameState.money,
		FileAccess.file_exists(GameState.save_path)])

	_clean_worlds_dir()
	get_tree().quit()


## Svuota la cartella dei mondi di test (e la toglie), per partire puliti.
func _clean_worlds_dir() -> void:
	var dir := DirAccess.open(GameState.worlds_dir)
	if dir == null:
		return
	for file_name in dir.get_files():
		dir.remove(file_name)
	DirAccess.remove_absolute(GameState.worlds_dir)
