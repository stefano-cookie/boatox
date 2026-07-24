class_name LandingSystem
extends Node

## Sbarco e rientro (roadmap R7): con la barca quasi ferma al molo o
## sulle acque basse della baia, F mette i piedi a terra — la barca resta
## dov'è; lo stesso F vicino alla barca riporta a bordo. Gestisce lo
## scambio barca ↔ Walker: input, camera e flag GameState.on_foot (che
## spegne porto, mirino, radar ed eventi mentre si cammina). Pensato per
## sbarcare ovunque poi (città, scali): oggi le superfici camminabili
## esistono solo a Bova, quindi lo sbarco è recintato nella baia di casa.

@export var boat: Boat
@export var walker: Walker
@export var chase_camera: ChaseCamera
@export var sea: Sea
@export var world: World

@export_group("Sbarco")
## Sopra questa velocità non si scende: prima si accosta piano.
@export var max_disembark_speed: float = 2.0
## Distanza massima dalla costa (m) per lo sbarco in spiaggia: acqua bassa.
@export var shallow_distance: float = 16.0
## Raggio intorno al molo di casa in cui si sbarca sulle assi.
@export var dock_radius: float = 20.0
## Mezza larghezza della zona sbarcabile (dentro i promontori della baia).
@export var bay_half_width: float = 290.0
## A piedi, distanza massima dalla barca per risalire a bordo.
@export var board_radius: float = 12.0

var _hint: Label


func _ready() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	_hint = Label.new()
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_left = -400.0
	_hint.offset_right = 400.0
	_hint.offset_top = -150.0
	_hint.offset_bottom = -110.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 28)
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", 6)
	ui.add_child(_hint)
	_hint.hide()


func _process(_delta: float) -> void:
	if GameState.on_foot:
		if _can_board():
			_hint.text = "Premi F per tornare a bordo"
			_hint.show()
		else:
			_hint.hide()
	elif _can_disembark():
		_hint.text = "Premi F per sbarcare"
		_hint.show()
	else:
		_hint.hide()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("disembark"):
		return
	if GameState.on_foot and _can_board():
		get_viewport().set_input_as_handled()
		_board()
	elif not GameState.on_foot and _can_disembark():
		get_viewport().set_input_as_handled()
		_disembark()


## Si sbarca con la barca governabile e quasi ferma, al molo di casa o
## dove l'acqua è bassa (vicino alla spiaggia, dentro la baia).
func _can_disembark() -> bool:
	if boat == null or sea == null or GameState.ui_focus_open() or get_tree().paused:
		return false
	if not boat.input_enabled or absf(boat.current_speed()) > max_disembark_speed:
		return false
	return _near_dock() or _in_shallows()


func _near_dock() -> bool:
	return boat.global_position.distance_to(world.port_position()) <= dock_radius


func _in_shallows() -> bool:
	var pos := boat.global_position
	return sea.shore_distance(pos) <= shallow_distance and absf(pos.x) <= bay_half_width


func _can_board() -> bool:
	return walker.active and walker.input_enabled and not GameState.ui_focus_open() \
		and walker.global_position.distance_to(boat.global_position) <= board_radius


## La barca resta dov'è (motore spento), i piedi toccano il molo o la
## battigia: da lì si risale allo stesso modo.
func _disembark() -> void:
	GameState.on_foot = true
	boat.input_enabled = false
	boat.reset_motion()
	walker.activate(_landing_spot(), 0.0)
	GameState.save_game()


## Dove si toccano terra: le assi del molo se si è attraccati lì, la
## battigia davanti alla barca altrimenti (un filo alto: la gravità posa).
func _landing_spot() -> Vector3:
	if _near_dock():
		return world.port_position() + Vector3(0.0, 1.2, 6.0)
	var x := clampf(boat.global_position.x, -bay_half_width + 20.0, bay_half_width - 20.0)
	return Vector3(x, 1.2, sea.shore_z - 11.0)


func _board() -> void:
	walker.deactivate()
	chase_camera.make_current()
	boat.input_enabled = true
	GameState.on_foot = false
	GameState.save_game()
