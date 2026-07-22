class_name Port
extends Node3D

## Attracco (GDD § core loop sessione): quando la barca è nella zona e
## quasi ferma, E apre il menu porto — vendita del carico, riparazione e
## cantiere (acquisto barche e upgrade funzionali, prezzi nei .tres).
## Mentre un menu è aperto l'input di guida è disattivato, così le
## frecce navigano i pulsanti. Chiudere il menu salva la partita.

## Sopra questa velocità non si può attraccare: prima si rallenta.
@export var docking_max_speed: float = 1.5
## Rallentamento assistito in avvicinamento (feedback playtest round 2:
## arrivare e fermarsi dev'essere naturale, non un gate secco). Dentro la
## ApproachZone il cap di velocità cala col ridursi della distanza dal
## molo: da nessun limite al bordo fino a approach_min_speed all'attracco.
@export var approach_slow_radius: float = 22.0
@export var approach_min_speed: float = 3.0

var _boat: Boat = null
## La barca a cui il menu ha spento la guida: la riaccende sempre lui,
## anche se nel frattempo _boat è stato azzerato dall'uscita di zona.
var _docked_boat: Boat = null
## Barca nella zona di rallentamento (più larga della DockZone).
var _approach_boat: Boat = null
var _open: bool = false
var _shipyard_open: bool = false
var _tackle_open: bool = false

var _boat_buttons: Dictionary[StringName, Button] = {}
var _upgrade_buttons: Dictionary[int, Button] = {}
var _upgrade_labels: Dictionary[int, Label] = {}
var _gear_buttons: Dictionary[int, Button] = {}

@onready var _zone: Area3D = $DockZone
@onready var _approach_zone: Area3D = $ApproachZone
@onready var _tow_spawn: Marker3D = $TowSpawn
@onready var _hint: Label = $PortUI/Hint
@onready var _panel: PanelContainer = $PortUI/Panel
@onready var _info: RichTextLabel = $PortUI/Panel/Margin/VBox/Info
@onready var _sell_button: Button = $PortUI/Panel/Margin/VBox/SellButton
@onready var _repair_button: Button = $PortUI/Panel/Margin/VBox/RepairButton
@onready var _refuel_button: Button = $PortUI/Panel/Margin/VBox/RefuelButton
@onready var _shipyard_button: Button = $PortUI/Panel/Margin/VBox/ShipyardButton
@onready var _tackle_button: Button = $PortUI/Panel/Margin/VBox/TackleButton
@onready var _leave_button: Button = $PortUI/Panel/Margin/VBox/LeaveButton
@onready var _shipyard: PanelContainer = $PortUI/Shipyard
@onready var _shipyard_money: Label = $PortUI/Shipyard/Margin/VBox/Money
@onready var _boats_box: VBoxContainer = $PortUI/Shipyard/Margin/VBox/BoatsBox
@onready var _upgrades_title: Label = $PortUI/Shipyard/Margin/VBox/UpgradesTitle
@onready var _upgrades_box: VBoxContainer = $PortUI/Shipyard/Margin/VBox/UpgradesBox
@onready var _back_button: Button = $PortUI/Shipyard/Margin/VBox/BackButton
@onready var _tackle: PanelContainer = $PortUI/Tackle
@onready var _tackle_money: Label = $PortUI/Tackle/Margin/VBox/Money
@onready var _gear_box: VBoxContainer = $PortUI/Tackle/Margin/VBox/GearBox
@onready var _tackle_back: Button = $PortUI/Tackle/Margin/VBox/BackButton


func _ready() -> void:
	_zone.body_entered.connect(_on_zone_body_entered)
	_zone.body_exited.connect(_on_zone_body_exited)
	_approach_zone.body_entered.connect(_on_approach_entered)
	_approach_zone.body_exited.connect(_on_approach_exited)
	_sell_button.pressed.connect(_on_sell_pressed)
	_repair_button.pressed.connect(_on_repair_pressed)
	_refuel_button.pressed.connect(_on_refuel_pressed)
	_shipyard_button.pressed.connect(_open_shipyard)
	_tackle_button.pressed.connect(_open_tackle)
	_leave_button.pressed.connect(_close_menu)
	_back_button.pressed.connect(_close_shipyard)
	_tackle_back.pressed.connect(_close_tackle)
	_build_shipyard_rows()
	_build_tackle_rows()
	_panel.hide()
	_shipyard.hide()
	_tackle.hide()
	_hint.hide()


func _process(_delta: float) -> void:
	_update_approach_cap()
	if _boat == null or _open:
		_hint.hide()
		return
	_hint.show()
	if absf(_boat.current_speed()) <= docking_max_speed:
		_hint.text = "Premi E per attraccare"
	else:
		_hint.text = "Rallenta per attraccare"


## Cap di velocità progressivo in avvicinamento: nessun limite al bordo
## della zona, sceso ad approach_min_speed sul molo. Col menu aperto la
## guida è già spenta, quindi non tocchiamo il cap.
func _update_approach_cap() -> void:
	if _approach_boat == null or _open:
		return
	var d := _approach_boat.global_position.distance_to(_dock_center())
	if d >= approach_slow_radius:
		_approach_boat.approach_speed_cap = INF
	else:
		var t := d / approach_slow_radius
		_approach_boat.approach_speed_cap = lerpf(approach_min_speed, _approach_boat.max_speed, t)


## Centro dell'attracco in coordinate mondo (la DockZone è a z+6 locale).
func _dock_center() -> Vector3:
	return to_global(Vector3(0.0, 0.0, 6.0))


func _on_approach_entered(body: Node3D) -> void:
	if body is Boat:
		_approach_boat = body


func _on_approach_exited(body: Node3D) -> void:
	if body == _approach_boat:
		_approach_boat.approach_speed_cap = INF
		_approach_boat = null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if _shipyard_open:
			get_viewport().set_input_as_handled()
			_close_shipyard()
		elif _tackle_open:
			get_viewport().set_input_as_handled()
			_close_tackle()
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
		elif _tackle_open:
			get_viewport().set_input_as_handled()
			_close_tackle()
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
		_confirm_departure(body)


## Il cambio barca sostituisce la collision shape e questo fa scattare
## un body_exited fasullo con rientro immediato: prima di chiudere il
## menu si aspetta un giro di fisica e si riverifica che la barca sia
## davvero fuori dalla zona.
func _confirm_departure(body: Node3D) -> void:
	# Il nodo può uscire dall'albero durante l'attesa (cambio scena /
	# partenza): senza questa guardia get_tree() è null e crasha.
	if not is_inside_tree():
		return
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	if not is_instance_valid(body) or _zone.overlaps_body(body):
		return
	_boat = null
	if _open:
		_close_menu()


func _open_menu() -> void:
	_open = true
	_docked_boat = _boat
	_docked_boat.input_enabled = false
	_docked_boat.reset_motion()
	GameState.push_ui_focus()
	_refresh()
	_panel.show()
	_sell_button.grab_focus()


func _close_menu() -> void:
	_open = false
	_shipyard_open = false
	_tackle_open = false
	_panel.hide()
	_shipyard.hide()
	_tackle.hide()
	GameState.pop_ui_focus()
	GameState.save_game()
	if _docked_boat != null:
		_docked_boat.input_enabled = true
		_docked_boat = null


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


func _open_tackle() -> void:
	_tackle_open = true
	_panel.hide()
	_refresh_tackle()
	_tackle.show()
	_tackle_back.grab_focus()


func _close_tackle() -> void:
	_tackle_open = false
	_tackle.hide()
	_refresh()
	_panel.show()
	_tackle_button.grab_focus()


func _on_sell_pressed() -> void:
	GameState.sell_cargo()
	_refresh()


func _on_repair_pressed() -> void:
	GameState.repair_hull()
	_refresh()


func _on_refuel_pressed() -> void:
	GameState.refuel()
	_refresh()


func _refresh() -> void:
	var cargo_text := "vuota"
	if GameState.cargo_count() > 0:
		cargo_text = "%s — vale [color=#8ee3a8]%d $[/color]" % [
			GameState.cargo_detail_bbcode(), GameState.cargo_value(),
		]
	_info.text = "Denaro: [color=#8ee3a8]%d $[/color]\nBarca: %s\nScafo: %d%%  ·  Benzina: %d/%d L\nStiva %d/%d: %s" % [
		GameState.money,
		GameState.current_def().display_name,
		roundi(GameState.hull / GameState.hull_max() * 100.0),
		ceili(GameState.fuel), ceili(GameState.fuel_capacity()),
		GameState.cargo_count(), GameState.cargo_capacity(),
		cargo_text,
	]
	_sell_button.text = "Vendi il carico (+%d $)" % GameState.cargo_value()
	_sell_button.disabled = GameState.cargo_value() <= 0
	var cost := GameState.repair_cost()
	_repair_button.text = "Ripara lo scafo (-%d $)" % cost
	_repair_button.disabled = cost <= 0 or GameState.money <= 0
	var fuel_cost := GameState.refuel_cost()
	_refuel_button.text = "Fai il pieno (-%d $)" % fuel_cost
	_refuel_button.disabled = fuel_cost <= 0 or GameState.money <= 0


# --- Cantiere ----------------------------------------------------------------

## Le righe (una per barca, una per upgrade) si costruiscono una volta
## sola: _refresh_shipyard aggiorna solo testi e disabled, così il focus
## non si perde a ogni acquisto.
func _build_shipyard_rows() -> void:
	for def in GameState.BOAT_DEFS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var label := Label.new()
		label.text = "%s\nvel %d · scafo %d · stiva %d · stab %d%% · serb %d L" % [
			def.display_name, roundi(def.max_speed), roundi(def.hull_max),
			def.cargo_capacity, roundi(def.stability * 100.0), roundi(def.fuel_capacity),
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
	# Ogni upgrade come riga: a sinistra nome, effetto in gioco e delta del
	# prossimo livello (feedback playtest round 2: "non sono spiegati"), a
	# destra il bottone d'acquisto. Come le righe barca e la bottega di Nino.
	for type: int in GameState.UPGRADE_NAME:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 18)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var button := Button.new()
		button.add_theme_font_size_override("font_size", 22)
		button.custom_minimum_size = Vector2(210, 0)
		button.pressed.connect(_on_upgrade_pressed.bind(type))
		row.add_child(button)
		_upgrades_box.add_child(row)
		_upgrade_buttons[type] = button
		_upgrade_labels[type] = label


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
		elif not GameState.boat_unlocked(def.id):
			button.text = "Vinci la regata"
			button.disabled = true
		else:
			button.text = "Compra (%d $)" % def.price
			button.disabled = GameState.money < def.price
	_upgrades_title.text = "Upgrade — %s" % GameState.current_def().display_name
	for type: int in _upgrade_buttons:
		var button := _upgrade_buttons[type]
		var label := _upgrade_labels[type]
		var level := GameState.upgrade_level(type)
		var cost := GameState.upgrade_cost(type)
		var up_name := GameState.UPGRADE_NAME[type]
		var desc := GameState.UPGRADE_DESC[type]
		if cost < 0:
			label.text = "%s — %s" % [up_name, desc]
			button.text = "liv. %d — MAX" % level
			button.disabled = true
		else:
			var delta := GameState.upgrade_delta_preview(type)
			label.text = "%s — %s\n[%s]" % [up_name, desc, delta]
			button.text = "liv. %d → %d (-%d $)" % [level, level + 1, cost]
			button.disabled = GameState.money < cost


# --- Bottega di Nino (attrezzatura da pesca) ---------------------------------

## Una riga per attrezzo (canna, mulinello, lenza): descrizione a
## sinistra, bottone d'acquisto a destra. Costruite una volta sola, come
## le righe del cantiere.
func _build_tackle_rows() -> void:
	for gear: int in GameState.FISHING_GEAR_NAME:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var label := Label.new()
		label.text = "%s\n%s" % [GameState.FISHING_GEAR_NAME[gear], GameState.FISHING_GEAR_DESC[gear]]
		label.add_theme_font_size_override("font_size", 20)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var button := Button.new()
		button.add_theme_font_size_override("font_size", 22)
		button.custom_minimum_size = Vector2(190, 0)
		button.pressed.connect(_on_gear_pressed.bind(gear))
		row.add_child(button)
		_gear_box.add_child(row)
		_gear_buttons[gear] = button


func _on_gear_pressed(gear: int) -> void:
	GameState.buy_fishing_gear(gear)
	_refresh_tackle()


func _refresh_tackle() -> void:
	_tackle_money.text = "Denaro: %d $" % GameState.money
	for gear: int in _gear_buttons:
		var button := _gear_buttons[gear]
		var level := GameState.fishing_gear_level(gear)
		var cost := GameState.fishing_gear_cost(gear)
		if cost < 0:
			button.text = "%s liv. %d — MAX" % [GameState.FISHING_GEAR_NAME[gear], level]
			button.disabled = true
		else:
			button.text = "%s liv. %d → %d (-%d $)" % [
				GameState.FISHING_GEAR_NAME[gear], level, level + 1, cost,
			]
			button.disabled = GameState.money < cost
