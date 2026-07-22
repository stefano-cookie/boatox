class_name RescueNpc
extends Node3D

## L'NPC dietro gli scogli a est (GDD § Missioni): Zu' Vito ha perso il
## nipote in mare. Fermati vicino e premi E per parlare. Accettata la
## missione, un marker in minimappa segna il punto al largo dove galleggia
## il ragazzo; raccolto (ci passi sopra), il marker torna sull'NPC:
## riportandolo, la missione si chiude e sblocca il radar. Da lì Zu' Vito
## vende i potenziamenti del radar. Stato e progresso in GameState
## (grandson_quest), salvati. Riusa i pattern di Port/FishingZone:
## Area3D + Label3D + pannello con push_ui_focus e input_enabled=false.

## Punto al largo dove galleggia il nipote (coordinate mondo, @export così
## si trascina da Inspector). Deve stare oltre le acque calme: è il rischio.
@export var rescue_point: Vector3 = Vector3(150.0, 0.0, 360.0)
## Sopra questa velocità non si parla: prima ci si avvicina piano.
@export var talk_max_speed: float = 4.0

## Assegnata dal World (come le RaceCourse): serve al galleggiamento.
var sea: Sea

var _boat: Boat = null
## Barca a cui il dialogo ha spento la guida: la riaccende sempre lui
## (pattern del Port).
var _talk_boat: Boat = null
var _open: bool = false
var _time: float = 0.0

@onready var _raft: Node3D = $Raft
@onready var _grandson: Area3D = $Grandson
@onready var _talk_zone: Area3D = $TalkZone
@onready var _hint: Label = $DialogUI/Hint
@onready var _panel: PanelContainer = $DialogUI/Panel
@onready var _title: Label = $DialogUI/Panel/Margin/VBox/Title
@onready var _body: RichTextLabel = $DialogUI/Panel/Margin/VBox/Body
@onready var _action_button: Button = $DialogUI/Panel/Margin/VBox/ActionButton
@onready var _range_button: Button = $DialogUI/Panel/Margin/VBox/RangeButton
@onready var _duration_button: Button = $DialogUI/Panel/Margin/VBox/DurationButton
@onready var _close_button: Button = $DialogUI/Panel/Margin/VBox/CloseButton


func _ready() -> void:
	add_to_group(&"rescue_npc")
	_talk_zone.body_entered.connect(_on_zone_entered)
	_talk_zone.body_exited.connect(_on_zone_exited)
	_grandson.body_entered.connect(_on_grandson_reached)
	_action_button.pressed.connect(_on_action_pressed)
	_range_button.pressed.connect(_on_range_pressed)
	_duration_button.pressed.connect(_on_duration_pressed)
	_close_button.pressed.connect(_close_dialog)
	_grandson.global_position = rescue_point
	_panel.hide()
	_hint.hide()
	_apply_quest_state()


func _process(delta: float) -> void:
	_time += delta
	_float_on_waves()
	_update_hint()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if _open:
			get_viewport().set_input_as_handled()
			_close_dialog()
		elif _can_talk():
			get_viewport().set_input_as_handled()
			_open_dialog()
	elif event.is_action_pressed("ui_cancel") and _open:
		# Consumato: altrimenti lo stesso Esc aprirebbe anche la pausa.
		get_viewport().set_input_as_handled()
		_close_dialog()


# --- Stato per la minimappa --------------------------------------------------

## Vero quando c'è un marker missione da disegnare (fuori da NONE/DONE).
func show_quest_marker() -> bool:
	var q := GameState.grandson_quest
	return q == GameState.GrandsonQuest.ACCEPTED or q == GameState.GrandsonQuest.CARRYING


## Dove punta il marker: il nipote al largo se da raggiungere, l'NPC se il
## nipote è già a bordo (riportalo).
func quest_marker_position() -> Vector3:
	if GameState.grandson_quest == GameState.GrandsonQuest.CARRYING:
		return global_position
	return rescue_point


# --- Galleggiamento ----------------------------------------------------------

func _float_on_waves() -> void:
	if sea == null:
		return
	_raft.position.y = sea.get_height(global_position)
	if _grandson.visible:
		_grandson.position.y = sea.get_height(rescue_point) + 0.1 + 0.05 * sin(_time * 2.0)


# --- Missione e dialogo ------------------------------------------------------

## Il nipote galleggia (visibile e raccoglibile) solo mentre la missione è
## ACCEPTED; il marker lo gestisce la minimappa leggendo lo stato.
func _apply_quest_state() -> void:
	var accepted := GameState.grandson_quest == GameState.GrandsonQuest.ACCEPTED
	_grandson.visible = accepted
	_grandson.set_deferred("monitoring", accepted)


func _can_talk() -> bool:
	return _boat != null and not _open \
		and absf(_boat.current_speed()) <= talk_max_speed


func _on_zone_entered(body: Node3D) -> void:
	if body is Boat:
		_boat = body


func _on_zone_exited(body: Node3D) -> void:
	if body == _boat:
		_boat = null


## Il nipote raccolto al largo: da qui va riportato all'NPC.
func _on_grandson_reached(body: Node3D) -> void:
	if not body is Boat or GameState.grandson_quest != GameState.GrandsonQuest.ACCEPTED:
		return
	GameState.set_grandson_quest(GameState.GrandsonQuest.CARRYING)
	GameState.post_notice("Nipote a bordo! Riportalo a Zu' Vito (marker in minimappa)")
	_apply_quest_state()


func _open_dialog() -> void:
	_open = true
	_talk_boat = _boat
	_talk_boat.input_enabled = false
	_talk_boat.reset_motion()
	GameState.push_ui_focus()
	_refresh_dialog()
	_panel.show()


func _close_dialog() -> void:
	_open = false
	_panel.hide()
	GameState.pop_ui_focus()
	if _talk_boat != null:
		_talk_boat.input_enabled = true
		_talk_boat = null


## Testo e bottoni cambiano con la tappa della missione.
func _refresh_dialog() -> void:
	_title.text = "Zu' Vito"
	_range_button.hide()
	_duration_button.hide()
	match GameState.grandson_quest:
		GameState.GrandsonQuest.NONE:
			_body.text = "Ragazzo mio, il mio nipote Totò è uscito in mare e non è più tornato. Le onde l'hanno portato al largo. Me lo vai a riprendere? Ti do il mio [color=#8fd4ff]radar[/color] da pesca."
			_action_button.text = "Vai a riprendere Totò"
			_action_button.show()
		GameState.GrandsonQuest.ACCEPTED:
			_body.text = "Totò è là fuori, al largo. Segui il [color=#ff8fe0]marker[/color] in minimappa, passaci sopra con la barca e riportamelo."
			_action_button.hide()
		GameState.GrandsonQuest.CARRYING:
			_body.text = "L'hai trovato! Grazie al cielo. Consegnamelo e il radar è tuo."
			_action_button.text = "Consegna Totò"
			_action_button.show()
		_:
			_body.text = "Grazie ancora, ragazzo. Il [color=#8fd4ff]radar[/color] è tuo: premi [b]R[/b] in mare per lanciare un impulso. Se vuoi te lo miglioro."
			_action_button.hide()
			_range_button.show()
			_duration_button.show()
			_refresh_radar_shop()
	_close_button.grab_focus()


func _refresh_radar_shop() -> void:
	_refresh_radar_button(_range_button, GameState.RadarUpgrade.RANGE)
	_refresh_radar_button(_duration_button, GameState.RadarUpgrade.DURATION)


func _refresh_radar_button(button: Button, upgrade: int) -> void:
	var level := GameState.radar_upgrade_level(upgrade)
	var cost := GameState.radar_upgrade_cost(upgrade)
	var up_name := GameState.RADAR_UPGRADE_NAME[upgrade]
	var desc := GameState.RADAR_UPGRADE_DESC[upgrade]
	if cost < 0:
		button.text = "%s liv. %d — MAX (%s)" % [up_name, level, desc]
		button.disabled = true
	else:
		button.text = "%s liv. %d → %d — %s (-%d $)" % [up_name, level, level + 1, desc, cost]
		button.disabled = GameState.money < cost


func _on_action_pressed() -> void:
	match GameState.grandson_quest:
		GameState.GrandsonQuest.NONE:
			GameState.set_grandson_quest(GameState.GrandsonQuest.ACCEPTED)
			_apply_quest_state()
			GameState.post_notice("Missione: recupera Totò al largo (marker in minimappa)")
			_close_dialog()
		GameState.GrandsonQuest.CARRYING:
			GameState.set_grandson_quest(GameState.GrandsonQuest.DONE)
			GameState.post_notice("Totò è a casa! Radar sbloccato: premi R in mare")
			_refresh_dialog()


func _on_range_pressed() -> void:
	GameState.buy_radar_upgrade(GameState.RadarUpgrade.RANGE)
	_refresh_dialog()


func _on_duration_pressed() -> void:
	GameState.buy_radar_upgrade(GameState.RadarUpgrade.DURATION)
	_refresh_dialog()


func _update_hint() -> void:
	if _boat == null or _open:
		_hint.hide()
		return
	_hint.show()
	if absf(_boat.current_speed()) > talk_max_speed:
		_hint.text = "Rallenta per parlare con Zu' Vito"
		return
	match GameState.grandson_quest:
		GameState.GrandsonQuest.CARRYING:
			_hint.text = "Premi E per consegnare Totò"
		GameState.GrandsonQuest.DONE:
			_hint.text = "Premi E — potenzia il radar"
		_:
			_hint.text = "Premi E per parlare con Zu' Vito"
