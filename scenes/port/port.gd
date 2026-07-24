class_name Port
extends Node3D

## Attracco (GDD § core loop sessione): quando la barca è nella zona e
## quasi ferma, E apre il menu porto — vendita del carico, riparazione,
## cantiere (acquisto barche e upgrade funzionali, prezzi nei .tres) e
## bacheca missioni (roadmap A1). Mentre un menu è aperto l'input di
## guida è disattivato, così le frecce navigano i pulsanti. Chiudere il
## menu salva la partita.
##
## La scena è parametrica (predisposizione beta B0): i flag service_*
## accendono i singoli servizi, così l'approdo secondario di A1 è la
## stessa scena con quasi tutto spento — solo attracco e consegna.

@export_group("Identità (predisposizione B0)")
## Insegna 3D e titolo del pannello.
@export var port_display_name: String = "PORTO"
## Etichetta breve in minimappa e nei testi delle missioni.
@export var map_label: String = "Porto"
@export var faction: StringName = &"bova"
## Non ancora usati nell'alpha: arrivano con costruzione e difese (beta).
@export var defense_level: int = 0
@export var prosperity: int = 0
## Riga di colore in testa al pannello (B4): la voce della città — chi
## sei per loro, cosa offrono. Vuota = niente riga.
@export_multiline var flavor_text: String = ""

@export_group("Servizi")
@export var service_sell: bool = true
@export var service_repair: bool = true
@export var service_refuel: bool = true
@export var service_shipyard: bool = true
@export var service_tackle: bool = true
@export var service_missions: bool = true
## Pannello di costruzione di Bova (roadmap B2): solo al porto di casa.
@export var service_town: bool = true
## Vero per l'approdo che riceve le casse delle missioni di consegna.
@export var is_delivery_target: bool = false

@export_group("Attracco")
## Sopra questa velocità non si può attraccare: prima si rallenta.
@export var docking_max_speed: float = 1.5
## Rallentamento assistito in avvicinamento (feedback playtest round 2:
## arrivare e fermarsi dev'essere naturale, non un gate secco). Dentro la
## ApproachZone il cap di velocità cala col ridursi della distanza dal
## molo: da nessun limite al bordo fino a approach_min_speed all'attracco.
@export var approach_slow_radius: float = 30.0
## Cap di velocità sul molo. Sotto docking_max_speed e sotto la soglia di
## danno dello scafo (min_impact_speed = 3), così arrivare in porto non fa
## mai male, anche lanciati (feedback playtest: "al porto mi incidento").
@export var approach_min_speed: float = 1.4

var _boat: Boat = null
## La barca a cui il menu ha spento la guida: la riaccende sempre lui,
## anche se nel frattempo _boat è stato azzerato dall'uscita di zona.
var _docked_boat: Boat = null
## Barca nella zona di rallentamento (più larga della DockZone).
var _approach_boat: Boat = null
var _open: bool = false
var _shipyard_open: bool = false
var _tackle_open: bool = false
var _board_open: bool = false
var _style_open: bool = false
var _town_open: bool = false

var _boat_buttons: Dictionary[StringName, Button] = {}
var _upgrade_buttons: Dictionary[int, Button] = {}
var _upgrade_labels: Dictionary[int, Label] = {}
var _cannon_button: Button
var _cannon_label: Label
var _gear_buttons: Dictionary[int, Button] = {}
var _paint_buttons: Dictionary[StringName, Button] = {}
var _accessory_buttons: Dictionary[StringName, Button] = {}
## Offerte correnti della bacheca: generate all'apertura, svuotate
## all'accettazione (si rigenerano alla prossima apertura).
var _offers: Array[Dictionary] = []

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
@onready var _style_button: Button = $PortUI/Shipyard/Margin/VBox/StyleButton
@onready var _style: PanelContainer = $PortUI/Style
@onready var _style_money: Label = $PortUI/Style/Margin/VBox/Money
@onready var _paints_box: VBoxContainer = $PortUI/Style/Margin/VBox/PaintsBox
@onready var _accessories_box: VBoxContainer = $PortUI/Style/Margin/VBox/AccessoriesBox
@onready var _style_back: Button = $PortUI/Style/Margin/VBox/BackButton
@onready var _tackle: PanelContainer = $PortUI/Tackle
@onready var _tackle_money: Label = $PortUI/Tackle/Margin/VBox/Money
@onready var _gear_box: VBoxContainer = $PortUI/Tackle/Margin/VBox/GearBox
@onready var _tackle_back: Button = $PortUI/Tackle/Margin/VBox/BackButton
@onready var _board_button: Button = $PortUI/Panel/Margin/VBox/BoardButton
@onready var _board: PanelContainer = $PortUI/Board
@onready var _board_info: RichTextLabel = $PortUI/Board/Margin/VBox/Info
@onready var _offers_box: VBoxContainer = $PortUI/Board/Margin/VBox/OffersBox
@onready var _abandon_button: Button = $PortUI/Board/Margin/VBox/AbandonButton
@onready var _board_back: Button = $PortUI/Board/Margin/VBox/BackButton
@onready var _town_button: Button = $PortUI/Panel/Margin/VBox/TownButton
@onready var _town: PanelContainer = $PortUI/Town
@onready var _town_info: RichTextLabel = $PortUI/Town/Margin/VBox/Info
@onready var _town_sell: Button = $PortUI/Town/Margin/VBox/SellButton
@onready var _slots_box: VBoxContainer = $PortUI/Town/Margin/VBox/SlotsBox
@onready var _town_back: Button = $PortUI/Town/Margin/VBox/BackButton


func _ready() -> void:
	add_to_group(&"ports")
	_zone.body_entered.connect(_on_zone_body_entered)
	_zone.body_exited.connect(_on_zone_body_exited)
	_approach_zone.body_entered.connect(_on_approach_entered)
	_approach_zone.body_exited.connect(_on_approach_exited)
	_sell_button.pressed.connect(_on_sell_pressed)
	_repair_button.pressed.connect(_on_repair_pressed)
	_refuel_button.pressed.connect(_on_refuel_pressed)
	_shipyard_button.pressed.connect(_open_shipyard)
	_tackle_button.pressed.connect(_open_tackle)
	_board_button.pressed.connect(_open_board)
	_leave_button.pressed.connect(_close_menu)
	_back_button.pressed.connect(_close_shipyard)
	_style_button.pressed.connect(_open_style)
	_style_back.pressed.connect(_close_style)
	_tackle_back.pressed.connect(_close_tackle)
	_board_back.pressed.connect(_close_board)
	_abandon_button.pressed.connect(_on_abandon_pressed)
	_town_button.pressed.connect(_open_town)
	_town_back.pressed.connect(_close_town)
	_town_sell.pressed.connect(_on_town_sell_pressed)
	_apply_services()
	_build_walk_deck()
	_build_shipyard_rows()
	_build_style_rows()
	_build_tackle_rows()
	_panel.hide()
	_shipyard.hide()
	_style.hide()
	_tackle.hide()
	_board.hide()
	_town.hide()
	_hint.hide()


## Insegna, titolo e bottoni seguono i flag service_* (Port parametrico,
## B0): l'approdo secondario è la stessa scena con i servizi spenti.
## Nino è il bottegaio della pesca: sta solo dove c'è la sua bottega.
func _apply_services() -> void:
	($Sign as Label3D).text = port_display_name
	($PortUI/Panel/Margin/VBox/Title as Label).text = port_display_name
	_sell_button.visible = service_sell
	_repair_button.visible = service_repair
	_refuel_button.visible = service_refuel
	_shipyard_button.visible = service_shipyard
	_tackle_button.visible = service_tackle
	_board_button.visible = service_missions
	_town_button.visible = service_town
	($Nino as Node3D).visible = service_tackle


## Piano di calpestio del molo (roadmap R7, layer 2): un collider sottile
## a filo delle assi, così a piedi si cammina sul legno vero. Il collider
## del Dock (layer 1) resta per fermare le barche: è più alto delle assi.
func _build_walk_deck() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 0.5, 12.0)
	shape.shape = box
	shape.position = Vector3(0.0, 0.425, 6.0)
	body.add_child(shape)
	add_child(body)


func _process(_delta: float) -> void:
	_update_approach_cap()
	# A piedi (roadmap R7) il molo non invita ad attraccare: la barca è
	# ferma lì sotto, ma il menu si apre solo dal timone.
	if _boat == null or _open or GameState.on_foot:
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
		if _style_open:
			get_viewport().set_input_as_handled()
			_close_style()
		elif _shipyard_open:
			get_viewport().set_input_as_handled()
			_close_shipyard()
		elif _tackle_open:
			get_viewport().set_input_as_handled()
			_close_tackle()
		elif _board_open:
			get_viewport().set_input_as_handled()
			_close_board()
		elif _town_open:
			get_viewport().set_input_as_handled()
			_close_town()
		elif _open:
			get_viewport().set_input_as_handled()
			_close_menu()
		elif _boat != null and not GameState.on_foot \
				and absf(_boat.current_speed()) <= docking_max_speed:
			get_viewport().set_input_as_handled()
			_open_menu()
	elif event.is_action_pressed("ui_cancel"):
		# Consumato: altrimenti lo stesso Esc aprirebbe anche la pausa.
		if _style_open:
			get_viewport().set_input_as_handled()
			_close_style()
		elif _shipyard_open:
			get_viewport().set_input_as_handled()
			_close_shipyard()
		elif _tackle_open:
			get_viewport().set_input_as_handled()
			_close_tackle()
		elif _board_open:
			get_viewport().set_input_as_handled()
			_close_board()
		elif _town_open:
			get_viewport().set_input_as_handled()
			_close_town()
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
	# Consegna automatica all'attracco (roadmap A1): casse all'approdo
	# giusto, pacco recuperato al porto principale.
	GameState.try_complete_mission_at_port(is_delivery_target)
	_refresh()
	_panel.show()
	if service_sell:
		_sell_button.grab_focus()
	else:
		_leave_button.grab_focus()


func _close_menu() -> void:
	_open = false
	_shipyard_open = false
	_tackle_open = false
	_board_open = false
	_style_open = false
	_town_open = false
	GameState.clear_paint_preview()
	_panel.hide()
	_shipyard.hide()
	_style.hide()
	_tackle.hide()
	_board.hide()
	_town.hide()
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
	var flavor := ""
	if flavor_text != "":
		flavor = "[i][color=#aab7c4]%s[/color][/i]\n" % flavor_text
	_info.text = flavor + "Denaro: [color=#8ee3a8]%d $[/color]\nBarca: %s\nScafo: %d%%  ·  Benzina: %d/%d L\nStiva %d/%d: %s\n%s" % [
		GameState.money,
		GameState.current_def().display_name,
		roundi(GameState.hull / GameState.hull_max() * 100.0),
		ceili(GameState.fuel), ceili(GameState.fuel_capacity()),
		GameState.cargo_count(), GameState.cargo_capacity(),
		cargo_text,
		_reputation_bbcode(),
	]
	_sell_button.text = "Vendi il carico (+%d $)" % GameState.cargo_value()
	_sell_button.disabled = GameState.cargo_value() <= 0
	var cost := GameState.repair_cost()
	_repair_button.text = "Ripara lo scafo (-%d $)" % cost
	_repair_button.disabled = cost <= 0 or GameState.money <= 0
	var fuel_cost := GameState.refuel_cost()
	_refuel_button.text = "Fai il pieno (-%d $)" % fuel_cost
	_refuel_button.disabled = fuel_cost <= 0 or GameState.money <= 0


## Riga reputazione del pannello (roadmap A1): valore ed effetto sui
## prezzi, così lo sconto/rincaro non è mai un mistero.
func _reputation_bbcode() -> String:
	var rep := GameState.reputation_value(faction)
	var effect := roundi((1.0 - GameState.price_multiplier(faction)) * 100.0)
	var effect_text := "prezzi pieni"
	if effect > 0:
		effect_text = "sconto %d%%" % effect
	elif effect < 0:
		effect_text = "rincaro %d%%" % -effect
	var hex := "8ee3a8" if rep > 0 else ("ff8f7a" if rep < 0 else "aab7c4")
	return "Reputazione: [color=#%s]%+d[/color] · %s" % [hex, rep, effect_text]


# --- Bacheca missioni (roadmap A1) -------------------------------------------

func _open_board() -> void:
	_board_open = true
	_panel.hide()
	_refresh_board()
	_board.show()
	_board_back.grab_focus()


func _close_board() -> void:
	_board_open = false
	_board.hide()
	_refresh()
	_panel.show()
	_board_button.grab_focus()


## Le righe delle offerte si ricostruiscono a ogni apertura: a differenza
## del cantiere le offerte cambiano (si rigenerano quando la bacheca è
## vuota e nessuna missione è in corso).
func _refresh_board() -> void:
	for child in _offers_box.get_children():
		child.queue_free()
	if GameState.mission_active():
		_board_info.text = "Missione in corso: [b]%s[/b]\n%s\nRicompensa: [color=#8ee3a8]%d $[/color]" % [
			str(GameState.active_mission.get("title", "")),
			GameState.mission_status_text(),
			int(GameState.active_mission.get("reward", 0)),
		]
		_abandon_button.show()
		return
	_abandon_button.hide()
	if _offers.is_empty():
		var world := get_tree().get_first_node_in_group(&"world") as World
		if world != null:
			_offers = GameState.generate_mission_offers(world)
	if _offers.is_empty():
		_board_info.text = "Nessun incarico oggi: riprova più tardi."
		return
	_board_info.text = "Incarichi dai moli: uno alla volta, il mare non aspetta."
	for offer in _offers:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var label := Label.new()
		label.text = "%s\n%s" % [str(offer.get("title", "")), str(offer.get("desc", ""))]
		label.add_theme_font_size_override("font_size", 18)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var button := Button.new()
		button.add_theme_font_size_override("font_size", 22)
		button.custom_minimum_size = Vector2(190, 0)
		button.text = "Accetta (+%d $)" % int(offer.get("reward", 0))
		button.pressed.connect(_on_offer_accepted.bind(offer))
		row.add_child(button)
		_offers_box.add_child(row)


func _on_offer_accepted(offer: Dictionary) -> void:
	if GameState.accept_mission(offer):
		_offers.clear()
	_refresh_board()
	_board_back.grab_focus()


func _on_abandon_pressed() -> void:
	GameState.abandon_mission()
	_refresh_board()
	_board_back.grab_focus()


# --- Bova cresce: costruzione e magazzino (roadmap B2) -----------------------

func _open_town() -> void:
	_town_open = true
	_panel.hide()
	_refresh_town()
	_town.show()
	_town_back.grab_focus()


func _close_town() -> void:
	_town_open = false
	_town.hide()
	_refresh()
	_panel.show()
	_town_button.grab_focus()


func _on_town_sell_pressed() -> void:
	Town.sell_warehouse()
	_refresh_town()
	_town_back.grab_focus()


func _on_build_pressed(slot_id: StringName, building_id: StringName) -> void:
	Town.build(slot_id, building_id)
	_refresh_town()
	_town_back.grab_focus()


func _on_slot_upgrade_pressed(slot_id: StringName) -> void:
	Town.upgrade(slot_id)
	_refresh_town()
	_town_back.grab_focus()


## Le righe si ricostruiscono a ogni refresh, come la bacheca: cambiano
## forma con lo stato (slot libero → bottoni di costruzione, occupato →
## potenziamento), non conviene tenerle vive.
func _refresh_town() -> void:
	var next_threshold := Town.next_level_threshold()
	var progress_text := "al massimo splendore"
	if next_threshold > 0:
		progress_text = "%d/%d punti per crescere" % [Town.prosperity_points(), next_threshold]
	_town_info.text = "Prosperità: [b]%s[/b] (liv. %d/%d) · %s\nMagazzino: %d pesce · %d conserve (capienza %d)\nFlottiglia: %d barche · %d pesce ogni %d s\nDenaro: [color=#%s]%d $[/color]" % [
		Town.level_name(), Town.prosperity_level(), Town.max_prosperity_level(),
		progress_text,
		Town.fish_stock(), Town.conserve_stock(), Town.storage_capacity(),
		Town.fleet_boat_count(), Town.fish_rate_per_tick(), int(Town.TICK_SECONDS),
		Town.MONEY_HEX, GameState.money,
	]
	_town_sell.text = "Vendi la produzione (+%d $)" % Town.warehouse_value()
	_town_sell.disabled = Town.warehouse_value() <= 0
	for child in _slots_box.get_children():
		child.queue_free()
	for node in get_tree().get_nodes_in_group(&"build_slots"):
		var slot := node as BuildSlot
		if slot == null:
			continue
		_slots_box.add_child(_build_slot_row(slot))


## Riga di uno slot: nome e stato a sinistra; a destra il bottone di
## potenziamento (se costruito) o un bottone per ogni edificio ammesso
## ancora da costruire (se libero).
func _build_slot_row(slot: BuildSlot) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 18)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var info := Town.slot_building(slot.slot_id)
	if not info.is_empty():
		var def: BuildingDefinition = Town.building_def(info["id"])
		var level: int = info["level"]
		label.text = "%s — %s liv. %d/%d\n%s" % [
			slot.display_name, def.display_name, level, def.max_level(), def.desc,
		]
		var button := Button.new()
		button.add_theme_font_size_override("font_size", 20)
		button.custom_minimum_size = Vector2(200, 0)
		var cost := def.next_cost(level)
		if cost < 0:
			button.text = "MAX"
			button.disabled = true
		else:
			button.text = "Potenzia (-%d $)" % cost
			button.disabled = GameState.money < cost
			button.pressed.connect(_on_slot_upgrade_pressed.bind(slot.slot_id))
		row.add_child(button)
		return row
	label.text = "%s — libero" % slot.display_name
	var any_option := false
	for def in Town.BUILDINGS:
		if not slot.can_host(def.id) or Town.built_slot(def.id) != &"":
			continue
		any_option = true
		var button := Button.new()
		button.add_theme_font_size_override("font_size", 20)
		button.custom_minimum_size = Vector2(200, 0)
		var cost := def.next_cost(0)
		button.text = "%s (-%d $)" % [def.display_name, cost]
		button.tooltip_text = def.desc
		button.disabled = GameState.money < cost
		button.pressed.connect(_on_build_pressed.bind(slot.slot_id, def.id))
		row.add_child(button)
	if not any_option:
		label.text = "%s — libero (niente da costruire qui, per ora)" % slot.display_name
	return row


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
	# Il cannone di bordo (roadmap B1): una riga come gli upgrade, ma è
	# personale — vale su tutte le barche, come l'attrezzatura da pesca.
	var cannon_row := HBoxContainer.new()
	cannon_row.add_theme_constant_override("separation", 12)
	_cannon_label = Label.new()
	_cannon_label.add_theme_font_size_override("font_size", 18)
	_cannon_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cannon_row.add_child(_cannon_label)
	_cannon_button = Button.new()
	_cannon_button.add_theme_font_size_override("font_size", 22)
	_cannon_button.custom_minimum_size = Vector2(210, 0)
	_cannon_button.pressed.connect(_on_cannon_pressed)
	cannon_row.add_child(_cannon_button)
	_upgrades_box.add_child(cannon_row)


func _on_cannon_pressed() -> void:
	GameState.buy_cannon()
	_refresh_shipyard()


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
	_refresh_cannon_row()


## Riga del cannone: stato attuale (o "disarmato") a sinistra, acquisto o
## potenziamento a destra. Su tutte le barche: si compra una volta sola.
func _refresh_cannon_row() -> void:
	var current := GameState.cannon_def()
	if current == null:
		_cannon_label.text = "Cannone — predare le navi in mare aperto\n[disarmato]"
	else:
		_cannon_label.text = "Cannone — %s (su ogni barca)\n[danno %d · gittata %d m · colpo ogni %.1f s]" % [
			current.display_name, roundi(current.damage),
			roundi(current.fire_range), current.fire_interval,
		]
	var cost := GameState.cannon_cost()
	if cost < 0:
		_cannon_button.text = "liv. %d — MAX" % GameState.cannon_level
		_cannon_button.disabled = true
	else:
		var next := GameState.CANNON_DEFS[GameState.cannon_level]
		var action := "Compra" if current == null else "liv. %d → %d" % [
			GameState.cannon_level, GameState.cannon_level + 1,
		]
		_cannon_button.text = "%s (-%d $)" % [action, cost]
		_cannon_button.tooltip_text = "%s: danno %d, gittata %d m" % [
			next.display_name, roundi(next.damage), roundi(next.fire_range),
		]
		_cannon_button.disabled = GameState.money < cost


# --- Estetica: vernici e accessori (roadmap A2) ------------------------------

func _open_style() -> void:
	_style_open = true
	_shipyard_open = false
	_shipyard.hide()
	_refresh_style()
	_style.show()
	_style_back.grab_focus()


## Chiudere azzera l'anteprima: sulla barca resta solo ciò che è pagato.
func _close_style() -> void:
	_style_open = false
	GameState.clear_paint_preview()
	_style.hide()
	_open_shipyard()


## Una riga per vernice (tacca di colore, nome, bottone) e una per
## accessorio. Costruite una volta, come le righe del cantiere; passare
## col mouse o col focus su una vernice la prova subito sulla barca
## attraccata (anteprima live, roadmap A2).
func _build_style_rows() -> void:
	for paint in GameState.PAINTS:
		var paint_id: StringName = paint["id"]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var swatch := ColorRect.new()
		swatch.color = paint["hull"]
		swatch.custom_minimum_size = Vector2(26, 26)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
		var label := Label.new()
		label.text = String(paint["name"])
		label.add_theme_font_size_override("font_size", 20)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var button := Button.new()
		button.add_theme_font_size_override("font_size", 20)
		button.custom_minimum_size = Vector2(190, 0)
		button.pressed.connect(_on_paint_pressed.bind(paint_id))
		button.mouse_entered.connect(GameState.set_paint_preview.bind(paint_id))
		button.focus_entered.connect(GameState.set_paint_preview.bind(paint_id))
		row.add_child(button)
		_paints_box.add_child(row)
		_paint_buttons[paint_id] = button
	for accessory in GameState.ACCESSORIES:
		var accessory_id: StringName = accessory["id"]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var label := Label.new()
		label.text = "%s\n%s" % [String(accessory["name"]), String(accessory["desc"])]
		label.add_theme_font_size_override("font_size", 18)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var button := Button.new()
		button.add_theme_font_size_override("font_size", 20)
		button.custom_minimum_size = Vector2(190, 0)
		button.pressed.connect(_on_accessory_pressed.bind(accessory_id))
		row.add_child(button)
		_accessories_box.add_child(row)
		_accessory_buttons[accessory_id] = button


func _on_paint_pressed(id: StringName) -> void:
	if GameState.owns_paint(id):
		GameState.apply_paint(id)
	else:
		GameState.buy_paint(id)
	_refresh_style()


func _on_accessory_pressed(id: StringName) -> void:
	GameState.buy_accessory(id)
	_refresh_style()


func _refresh_style() -> void:
	_style_money.text = "Denaro: %d $ — %s" % [
		GameState.money, GameState.current_def().display_name,
	]
	for paint in GameState.PAINTS:
		var paint_id: StringName = paint["id"]
		var button := _paint_buttons[paint_id]
		if GameState.applied_paint() == paint_id:
			button.text = "Applicata"
			button.disabled = true
		elif GameState.owns_paint(paint_id):
			button.text = "Applica"
			button.disabled = false
		else:
			button.text = "Compra (%d $)" % int(paint["price"])
			button.disabled = GameState.money < int(paint["price"])
	for accessory in GameState.ACCESSORIES:
		var accessory_id: StringName = accessory["id"]
		var button := _accessory_buttons[accessory_id]
		if GameState.owns_accessory(accessory_id):
			button.text = "A bordo"
			button.disabled = true
		else:
			button.text = "Compra (%d $)" % int(accessory["price"])
			button.disabled = GameState.money < int(accessory["price"])


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
