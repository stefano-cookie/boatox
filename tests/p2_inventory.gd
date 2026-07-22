extends Node

## Smoke test del pannello inventario (roadmap P2 § Inventario): apertura e
## chiusura col tasto I, pausa + focus UI mentre è aperto, guardia di
## mutua esclusione con gli altri pannelli, e conteggi/valori corretti nella
## griglia. Stampa un verdetto per ogni controllo.
## Uso: Godot --path . --headless res://tests/p2_inventory.tscn

var _main: Node
var _panel: CanvasLayer


func _ready() -> void:
	# File di salvataggio separato: i test non toccano quello vero.
	GameState.save_path = "user://save_test.json"
	GameState.reset()
	Radar.reset()
	_main = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	_panel = _main.get_node("InventoryPanel")
	_run()


func _run() -> void:
	await _wait(0.5)

	# --- Stato iniziale: chiuso, gioco non in pausa ---
	print("INIZIALE: pannello=%s (atteso true), aperto=%s (atteso false), pausa=%s (atteso false)" % [
		_panel != null, _panel._open, get_tree().paused])

	# --- Carico di prova ---
	GameState.collect_buoy(GameState.BuoyType.YELLOW)
	GameState.collect_buoy(GameState.BuoyType.YELLOW)
	GameState.collect_fish(GameState.FishType.TUNA)

	# --- Apertura con I: pausa + focus, griglia aggiornata ---
	_panel._unhandled_input(_press("inventory"))
	var yellow_qty: Label = _panel._buoy_cells[GameState.BuoyType.YELLOW]["qty"]
	var tuna_qty: Label = _panel._fish_cells[GameState.FishType.TUNA]["qty"]
	print("APERTO: aperto=%s (atteso true), pausa=%s (atteso true), focus=%s (atteso true), visibile=%s (atteso true)" % [
		_panel._open, get_tree().paused, GameState.ui_focus_open(), _panel._root.visible])
	print("GRIGLIA: gialle=%s (atteso ×2), tonno=%s (atteso ×1)" % [yellow_qty.text, tuna_qty.text])

	# --- Chiusura con Esc: niente pausa, focus rilasciato ---
	_panel._unhandled_input(_press("ui_cancel"))
	print("CHIUSO (Esc): aperto=%s (atteso false), pausa=%s (atteso false), focus=%s (atteso false)" % [
		_panel._open, get_tree().paused, GameState.ui_focus_open()])

	# --- Guardia: non si apre se un altro pannello ha il focus ---
	GameState.push_ui_focus()
	_panel._unhandled_input(_press("inventory"))
	print("GUARDIA: con altro pannello aperto, inventario aperto=%s (atteso false)" % _panel._open)
	GameState.pop_ui_focus()

	GameState.reset()
	Radar.reset()
	get_tree().quit()


func _press(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
