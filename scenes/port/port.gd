class_name Port
extends Node3D

## Attracco (GDD § core loop sessione): quando la barca è nella zona e
## quasi ferma, E apre il menu porto — vendita del carico e riparazione.
## Mentre il menu è aperto l'input di guida è disattivato, così le frecce
## navigano i pulsanti.

## Sopra questa velocità non si può attraccare: prima si rallenta.
@export var docking_max_speed: float = 1.5

var _boat: Boat = null
var _open: bool = false

@onready var _zone: Area3D = $DockZone
@onready var _tow_spawn: Marker3D = $TowSpawn
@onready var _hint: Label = $PortUI/Hint
@onready var _panel: PanelContainer = $PortUI/Panel
@onready var _info: Label = $PortUI/Panel/Margin/VBox/Info
@onready var _sell_button: Button = $PortUI/Panel/Margin/VBox/SellButton
@onready var _repair_button: Button = $PortUI/Panel/Margin/VBox/RepairButton
@onready var _leave_button: Button = $PortUI/Panel/Margin/VBox/LeaveButton


func _ready() -> void:
	_zone.body_entered.connect(_on_zone_body_entered)
	_zone.body_exited.connect(_on_zone_body_exited)
	_sell_button.pressed.connect(_on_sell_pressed)
	_repair_button.pressed.connect(_on_repair_pressed)
	_leave_button.pressed.connect(_close_menu)
	_panel.hide()
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
		if _open:
			get_viewport().set_input_as_handled()
			_close_menu()
		elif _boat != null and absf(_boat.current_speed()) <= docking_max_speed:
			get_viewport().set_input_as_handled()
			_open_menu()
	elif _open and event.is_action_pressed("ui_cancel"):
		# Consumato: altrimenti lo stesso Esc aprirebbe anche la pausa.
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
	_panel.hide()
	if _boat != null:
		_boat.input_enabled = true


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
	_info.text = "Denaro: %d $\nStiva: %s\nScafo: %d%%" % [
		GameState.money,
		cargo_text,
		roundi(GameState.hull / GameState.HULL_MAX * 100.0),
	]
	_sell_button.text = "Vendi il carico (+%d $)" % GameState.cargo_value()
	_sell_button.disabled = GameState.cargo_value() <= 0
	var cost := GameState.repair_cost()
	_repair_button.text = "Ripara lo scafo (-%d $)" % cost
	_repair_button.disabled = cost <= 0 or GameState.money <= 0
