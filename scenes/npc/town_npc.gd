class_name TownNpc
extends Node3D

## Datore di missioni a terra (roadmap R5/R7): un personaggio fisico nel
## paese — gli si parla a piedi (E dentro la sua zona), mai da menu. Offre
## gli incarichi raccogli-e-consegna del suo catalogo (GameState.NPC_MISSIONS,
## per npc_id), uno attivo alla volta; si consegna tornando da lui con la
## roba in stiva. Riusa i pattern di RescueNpc: Area3D + Label3D + pannello
## con push_ui_focus, e input_enabled spento sul Walker mentre si parla.
## La figura è nello stile dei paesani di TownGrowth, camicia @export.

@export var npc_id: StringName = &"mastro_cola"
@export var npc_display_name: String = "Mastro Cola"
@export var shirt_color: Color = Color(0.78, 0.32, 0.24)
## Battuta d'apertura del dialogo (chi è, cosa cerca).
@export_multiline var greeting: String = ""

var _walker: Walker = null
## Walker a cui il dialogo ha spento i passi: li riaccende sempre lui.
var _talk_walker: Walker = null
var _open: bool = false

@onready var _zone: Area3D = $TalkZone
@onready var _name_label: Label3D = $NameLabel
@onready var _hint: Label = $DialogUI/Hint
@onready var _panel: PanelContainer = $DialogUI/Panel
@onready var _title: Label = $DialogUI/Panel/Margin/VBox/Title
@onready var _body: RichTextLabel = $DialogUI/Panel/Margin/VBox/Body
@onready var _offers_box: VBoxContainer = $DialogUI/Panel/Margin/VBox/OffersBox
@onready var _deliver_button: Button = $DialogUI/Panel/Margin/VBox/DeliverButton
@onready var _abandon_button: Button = $DialogUI/Panel/Margin/VBox/AbandonButton
@onready var _close_button: Button = $DialogUI/Panel/Margin/VBox/CloseButton


func _ready() -> void:
	add_to_group(&"town_npcs")
	_build_figure()
	_name_label.text = npc_display_name
	_zone.body_entered.connect(_on_zone_entered)
	_zone.body_exited.connect(_on_zone_exited)
	_deliver_button.pressed.connect(_on_deliver_pressed)
	_abandon_button.pressed.connect(_on_abandon_pressed)
	_close_button.pressed.connect(_close_dialog)
	_panel.hide()
	_hint.hide()


func _process(_delta: float) -> void:
	if _walker == null or _open or GameState.ui_focus_open():
		_hint.hide()
		return
	_hint.show()
	if _is_my_mission() and GameState.npc_needs_met():
		_hint.text = "Premi E per consegnare a %s" % npc_display_name
	else:
		_hint.text = "Premi E per parlare con %s" % npc_display_name


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if _open:
			get_viewport().set_input_as_handled()
			_close_dialog()
		elif _walker != null and not GameState.ui_focus_open():
			get_viewport().set_input_as_handled()
			_open_dialog()
	elif event.is_action_pressed("ui_cancel") and _open:
		# Consumato: altrimenti lo stesso Esc aprirebbe anche la pausa.
		get_viewport().set_input_as_handled()
		_close_dialog()


func _on_zone_entered(body: Node3D) -> void:
	if body is Walker:
		_walker = body


func _on_zone_exited(body: Node3D) -> void:
	if body == _walker:
		_walker = null


func _open_dialog() -> void:
	_open = true
	_talk_walker = _walker
	_talk_walker.input_enabled = false
	GameState.push_ui_focus()
	_refresh()
	_panel.show()


func _close_dialog() -> void:
	_open = false
	_panel.hide()
	GameState.pop_ui_focus()
	if _talk_walker != null:
		_talk_walker.input_enabled = true
		_talk_walker = null


func _is_my_mission() -> bool:
	return GameState.mission_type() == GameState.MissionType.NPC_FETCH \
		and str(GameState.active_mission.get("npc_id", "")) == String(npc_id)


## Testo e bottoni seguono lo stato: incarico mio in corso (consegna o
## lista della spesa), incarico altrui (torna dopo), offerte aperte,
## catalogo esaurito.
func _refresh() -> void:
	_title.text = npc_display_name
	_deliver_button.hide()
	_abandon_button.hide()
	for child in _offers_box.get_children():
		child.queue_free()
	if _is_my_mission():
		_abandon_button.show()
		if GameState.npc_needs_met():
			_body.text = "Ce l'hai fatta! Hai tutto quello che serviva: [b]%s[/b]." \
				% GameState.npc_needs_text()
			_deliver_button.text = "Consegna (+%d $)" \
				% int(GameState.active_mission.get("reward", 0))
			_deliver_button.show()
			_deliver_button.grab_focus()
		else:
			_body.text = "%s\n\nMi manca ancora roba: [b]%s[/b]. Il mare provvede, tu raccogli." % [
				str(GameState.active_mission.get("desc", "")), GameState.npc_needs_text(),
			]
			_close_button.grab_focus()
		return
	if GameState.mission_active():
		_body.text = "Hai già un impegno per mano, si vede. Finisci quello, poi ne riparliamo."
		_close_button.grab_focus()
		return
	var offers := GameState.npc_offers(npc_id)
	if offers.is_empty():
		_body.text = "Per ora non mi serve nient'altro. Grazie di tutto, il paese se lo ricorda."
		_close_button.grab_focus()
		return
	_body.text = greeting
	for offer in offers:
		_offers_box.add_child(_build_offer_row(offer))
	_close_button.grab_focus()


## Riga di un'offerta: titolo, richiesta e ricompense a sinistra, Accetta
## a destra (pattern della bacheca del porto).
func _build_offer_row(offer: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = "%s\n%s\nServe: %s" % [
		str(offer.get("title", "")), str(offer.get("desc", "")), _needs_line(offer),
	]
	label.add_theme_font_size_override("font_size", 18)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var button := Button.new()
	button.add_theme_font_size_override("font_size", 20)
	button.custom_minimum_size = Vector2(190, 0)
	button.text = "Accetta (+%d $%s)" % [
		int(offer.get("reward", 0)), _gift_suffix(offer),
	]
	button.pressed.connect(_on_offer_accepted.bind(offer))
	row.add_child(button)
	return row


## "3× legno · 2× ferro" dal dizionario needs dell'offerta.
func _needs_line(offer: Dictionary) -> String:
	var parts: PackedStringArray = []
	var needs: Dictionary = offer.get("needs", {})
	for id: String in needs:
		var def := GameState.item_def(StringName(id))
		parts.append("%d× %s" % [int(needs[id]), def.display_name if def != null else id])
	return " · ".join(parts)


func _gift_suffix(offer: Dictionary) -> String:
	var gift := str(offer.get("reward_item", ""))
	if gift == "":
		return ""
	var def := GameState.item_def(StringName(gift))
	return " e %s" % (def.display_name if def != null else gift)


func _on_offer_accepted(offer: Dictionary) -> void:
	GameState.accept_npc_mission(npc_id, npc_display_name, offer)
	_refresh()


func _on_deliver_pressed() -> void:
	GameState.deliver_npc_mission(npc_id)
	_refresh()


func _on_abandon_pressed() -> void:
	GameState.abandon_mission()
	_refresh()


## La figura del datore, nello stile dei paesani di TownGrowth: gambe,
## busto col colore della camicia, testa.
func _build_figure() -> void:
	var legs := MeshInstance3D.new()
	var legs_mesh := BoxMesh.new()
	legs_mesh.size = Vector3(0.36, 0.5, 0.26)
	legs.mesh = legs_mesh
	legs.material_override = _flat(Color(0.24, 0.28, 0.36))
	legs.position.y = 0.25
	add_child(legs)
	var torso := MeshInstance3D.new()
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.22
	torso_mesh.height = 0.9
	torso.mesh = torso_mesh
	torso.material_override = _flat(shirt_color)
	torso.position.y = 0.83
	add_child(torso)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.16
	head_mesh.height = 0.32
	head.mesh = head_mesh
	head.material_override = _flat(Color(0.83, 0.62, 0.46))
	head.position.y = 1.22
	add_child(head)


static func _flat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	return mat
