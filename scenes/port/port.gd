class_name Port
extends Node3D

## Attracco (GDD § core loop sessione): quando la barca è nella zona e
## quasi ferma, E apre il menu porto — vendita del carico, riparazione e
## cantiere (acquisto barche e upgrade funzionali, prezzi nei .tres).
## Mentre un menu è aperto l'input di guida è disattivato, così le
## frecce navigano i pulsanti. Chiudere il menu salva la partita.

## Sopra questa velocità non si può attraccare: prima si rallenta.
@export var docking_max_speed: float = 1.5

var _boat: Boat = null
var _open: bool = false
var _shipyard_open: bool = false

var _boat_buttons: Dictionary[StringName, Button] = {}
var _upgrade_buttons: Dictionary[int, Button] = {}

@onready var _zone: Area3D = $DockZone
@onready var _tow_spawn: Marker3D = $TowSpawn
@onready var _hint: Label = $PortUI/Hint
@onready var _panel: PanelContainer = $PortUI/Panel
@onready var _info: Label = $PortUI/Panel/Margin/VBox/Info
@onready var _sell_button: Button = $PortUI/Panel/Margin/VBox/SellButton
@onready var _repair_button: Button = $PortUI/Panel/Margin/VBox/RepairButton
@onready var _shipyard_button: Button = $PortUI/Panel/Margin/VBox/ShipyardButton
@onready var _leave_button: Button = $PortUI/Panel/Margin/VBox/LeaveButton
@onready var _shipyard: PanelContainer = $PortUI/Shipyard
@onready var _shipyard_money: Label = $PortUI/Shipyard/Margin/VBox/Money
@onready var _boats_box: VBoxContainer = $PortUI/Shipyard/Margin/VBox/BoatsBox
@onready var _upgrades_title: Label = $PortUI/Shipyard/Margin/VBox/UpgradesTitle
@onready var _upgrades_box: VBoxContainer = $PortUI/Shipyard/Margin/VBox/UpgradesBox
@onready var _back_button: Button = $PortUI/Shipyard/Margin/VBox/BackButton


func _ready() -> void:
	_zone.body_entered.connect(_on_zone_body_entered)
	_zone.body_exited.connect(_on_zone_body_exited)
	_sell_button.pressed.connect(_on_sell_pressed)
	_repair_button.pressed.connect(_on_repair_pressed)
	_shipyard_button.pressed.connect(_open_shipyard)
	_leave_button.pressed.connect(_close_menu)
	_back_button.pressed.connect(_close_shipyard)
	_build_shipyard_rows()
	_panel.hide()
	_shipyard.hide()
	_hint.hide()


func _process(_delta: float) -> void:
	if _boat == null or _open:
		_hint.hide()
		return
	_hint.show()
	if absf(_boat.current_speed()) <= docking_max_speed:
		_hint.text = "Premi E per attraccare"
	else:
		_hint.text = "Rallenta per attraccare"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if _shipyard_open:
			get_viewport().set_input_as_handled()
			_close_shipyard()
		elif _open:
			get_viewport().set_input_as_handled()
			_close_menu()
		elif _boat != null and absf(_boat.current_speed()) <= docking_max_speed:
			get_viewport().set_input_as_handled()
			_open_menu()
	elif event.is_action_pressed("ui_cancel"):
		# Consumato: altrimenti lo stesso Esc aprirebbe anche la pausa.
		if _shipyard_open:
			get_viewport().set_input_as_handled()
			_close_shipyard()
		elif _open:
			get_viewport().set_input_as_handled()
			_close_menu()


func tow_spawn_position() -> Vector3:
	return _tow_spawn.global_position


func _on_zone_body_entered(body: Node3D) -> void:
	if body is Boat:
		_boat = body


func _on_zone_body_exited(body: Node3D) -> void:
	if body == _boat:
		_boat = null
		if _open:
			_close_menu()


func _open_menu() -> void:
	_open = true
	_boat.input_enabled = false
	_boat.reset_motion()
	_refresh()
	_panel.show()
	_sell_button.grab_focus()


func _close_menu() -> void:
	_open = false
	_shipyard_open = false
	_panel.hide()
	_shipyard.hide()
	GameState.save_game()
	if _boat != null:
		_boat.input_enabled = true


func _open_shipyard() -> void:
	_shipyard_open = true
	_panel.hide()
	_refresh_shipyard()
	_shipyard.show()
	_back_button.grab_focus()


func _close_shipyard() -> void:
	_shipyard_open = false
	_shipyard.hide()
	_refresh()
	_panel.show()
	_shipyard_button.grab_focus()


func _on_sell_pressed() -> void:
	GameState.sell_cargo()
	_refresh()


func _on_repair_pressed() -> void:
	GameState.repair_hull()
	_refresh()


func _refresh() -> void:
	var cargo_text := "vuota"
	if GameState.cargo_count() > 0:
		var parts: Array[String] = []
		for type: int in GameState.cargo:
			if GameState.cargo[type] > 0:
				parts.append("%d× %s" % [GameState.cargo[type], GameState.BUOY_NAME[type]])
		cargo_text = "%s (%d $)" % [", ".join(parts), GameState.cargo_value()]
	_info.text = "Denaro: %d $\nBarca: %s\nStiva: %s\nScafo: %d%%" % [
		GameState.money,
		GameState.current_def().display_name,
		cargo_text,
		roundi(GameState.hull / GameState.hull_max() * 100.0),
	]
	_sell_button.text = "Vendi il carico (+%d $)" % GameState.cargo_value()
	_sell_button.disabled = GameState.cargo_value() <= 0
	var cost := GameState.repair_cost()
	_repair_button.text = "Ripara lo scafo (-%d $)" % cost
	_repair_button.disabled = cost <= 0 or GameState.money <= 0


# --- Cantiere ----------------------------------------------------------------

## Le righe (una per barca, una per upgrade) si costruiscono una volta
## sola: _refresh_shipyard aggiorna solo testi e disabled, così il focus
## non si perde a ogni acquisto.
func _build_shipyard_rows() -> void:
	for def in GameState.BOAT_DEFS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var label := Label.new()
		label.text = "%s\nvel %d · scafo %d · stiva %d · stab %d%%" % [
			def.display_name, roundi(def.max_speed), roundi(def.hull_max),
			def.cargo_capacity, roundi(def.stability * 100.0),
		]
		label.add_theme_font_size_override("font_size", 20)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var button := Button.new()
		button.add_theme_font_size_override("font_size", 22)
		button.custom_minimum_size = Vector2(190, 0)
		button.pressed.connect(_on_boat_row_pressed.bind(def.id))
		row.add_child(button)
		_boats_box.add_child(row)
		_boat_buttons[def.id] = button
	for type: int in GameState.UPGRADE_NAME:
		var button := Button.new()
		button.add_theme_font_size_override("font_size", 22)
		button.pressed.connect(_on_upgrade_pressed.bind(type))
		_upgrades_box.add_child(button)
		_upgrade_buttons[type] = button


func _on_boat_row_pressed(id: StringName) -> void:
	if GameState.owns_boat(id):
		GameState.select_boat(id)
	else:
		GameState.buy_boat(id)
	_refresh_shipyard()


func _on_upgrade_pressed(type: int) -> void:
	GameState.buy_upgrade(type)
	_refresh_shipyard()


func _refresh_shipyard() -> void:
	_shipyard_money.text = "Denaro: %d $" % GameState.money
	for def in GameState.BOAT_DEFS:
		var button := _boat_buttons[def.id]
		if def.id == GameState.current_boat_id:
			button.text = "In uso"
			button.disabled = true
		elif GameState.owns_boat(def.id):
			button.text = "Usa"
			button.disabled = false
		else:
			button.text = "Compra (%d $)" % def.price
			button.disabled = GameState.money < def.price
	_upgrades_title.text = "Upgrade — %s" % GameState.current_def().display_name
	for type: int in _upgrade_buttons:
		var button := _upgrade_buttons[type]
		var level := GameState.upgrade_level(type)
		var cost := GameState.upgrade_cost(type)
		if cost < 0:
			button.text = "%s liv. %d — MAX" % [GameState.UPGRADE_NAME[type], level]
			button.disabled = true
		else:
			button.text = "%s liv. %d → %d (-%d $)" % [
				GameState.UPGRADE_NAME[type], level, level + 1, cost,
			]
			button.disabled = GameState.money < cost
