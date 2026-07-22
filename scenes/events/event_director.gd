class_name EventDirector
extends Node

## Eventi casuali con scelta (roadmap A1): ogni 2-3 minuti di navigazione
## oltre le acque calme si tira un dado; se esce, la barca si ferma e un
## pannello propone la situazione con 2 scelte e conseguenze immediate
## (denaro, carburante, scafo, reputazione — applicate da GameState).
## Gli eventi sono Resource .tres (resources/events): si scrivono e si
## bilanciano dall'Inspector. Un sacchetto mescolato evita le repliche
## finché non li hai visti tutti.

@export var boat: Boat
@export var sea: Sea
@export var events: Array[EventDefinition] = []
## Secondi di navigazione (oltre le acque calme) tra un tiro e l'altro.
@export var roll_interval_min: float = 120.0
@export var roll_interval_max: float = 180.0
## Probabilità che il tiro faccia scattare davvero un evento.
@export_range(0.0, 1.0) var trigger_chance: float = 0.65

var _sail_time: float = 0.0
var _next_roll: float = 0.0
## Sacchetto degli eventi non ancora usciti in questo giro.
var _bag: Array[EventDefinition] = []
var _current: EventDefinition = null
## Barca a cui il pannello ha spento la guida (pattern del Port).
var _event_boat: Boat = null
var _open: bool = false

@onready var _panel: PanelContainer = $EventUI/Panel
@onready var _title: Label = $EventUI/Panel/Margin/VBox/Title
@onready var _body: RichTextLabel = $EventUI/Panel/Margin/VBox/Body
@onready var _choice_a: Button = $EventUI/Panel/Margin/VBox/ChoiceA
@onready var _choice_b: Button = $EventUI/Panel/Margin/VBox/ChoiceB


func _ready() -> void:
	_choice_a.pressed.connect(_on_choice.bind(true))
	_choice_b.pressed.connect(_on_choice.bind(false))
	_panel.hide()
	_arm()


func _arm() -> void:
	_sail_time = 0.0
	_next_roll = randf_range(roll_interval_min, roll_interval_max)


## Il tempo scorre solo navigando davvero: niente eventi nelle acque
## calme (lì è zona sicura), coi pannelli aperti, in regata o a guida
## spenta (attracco, dialoghi, affondamento).
func _process(delta: float) -> void:
	if _open or boat == null or sea == null or events.is_empty():
		return
	if not boat.input_enabled or GameState.ui_focus_open() or _racing():
		return
	if sea.zone_index(boat.global_position) < 1:
		return
	_sail_time += delta
	if _sail_time < _next_roll:
		return
	if randf() > trigger_chance:
		_arm()
		return
	_trigger()


func _racing() -> bool:
	for node in get_tree().get_nodes_in_group(&"race_course"):
		var course := node as RaceCourse
		if course != null and course.is_racing():
			return true
	return false


func _trigger() -> void:
	if _bag.is_empty():
		_bag = events.duplicate()
		_bag.shuffle()
	_current = _bag.pop_back()
	_open = true
	_event_boat = boat
	_event_boat.input_enabled = false
	_event_boat.reset_motion()
	GameState.push_ui_focus()
	_title.text = _current.title
	_body.text = _current.body
	_setup_choice(_choice_a, _current.choice_a, _current.money_a, _current.fuel_a)
	_setup_choice(_choice_b, _current.choice_b, _current.money_b, _current.fuel_b)
	_panel.show()
	if not _choice_a.disabled:
		_choice_a.grab_focus()
	else:
		_choice_b.grab_focus()


## Una scelta che costa denaro o benzina che non hai si vede ma non si
## preme: gli eventi sono scritti con almeno una scelta sempre gratuita.
func _setup_choice(button: Button, text: String, money_delta: int, fuel_delta: float) -> void:
	button.text = text
	button.disabled = (money_delta < 0 and GameState.money < -money_delta) \
		or (fuel_delta < 0.0 and GameState.fuel < -fuel_delta)


func _on_choice(first: bool) -> void:
	if _current != null:
		if first:
			GameState.apply_event_choice(_current.money_a, _current.fuel_a,
				_current.hull_a, _current.rep_a)
			if not _current.result_a.is_empty():
				GameState.post_notice(_current.result_a)
		else:
			GameState.apply_event_choice(_current.money_b, _current.fuel_b,
				_current.hull_b, _current.rep_b)
			if not _current.result_b.is_empty():
				GameState.post_notice(_current.result_b)
	_current = null
	_open = false
	_panel.hide()
	GameState.pop_ui_focus()
	if _event_boat != null:
		_event_boat.input_enabled = true
		_event_boat = null
	_arm()
