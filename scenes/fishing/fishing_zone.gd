class_name FishingZone
extends Area3D

## Zona di pesca (GDD § Pesca): un punto visibile da lontano — uccelli in
## cerchio e anelli d'increspatura sull'acqua — dove fermarsi e pescare
## con E. Minigioco di tempismo: lanci la lenza, aspetti l'abboccata, poi
## fermi il cursore nella finestra verde; il centro dorato vale il pesce
## pregiato della fascia. Esaurito lo stock gli uccelli se ne vanno e la
## zona riposa. Specie, valori e difficoltà per fascia in GameState.

## Fascia di mare della zona: decide specie e difficoltà (0 = calme).
@export_range(0, 2) var zone_tier: int = 0
## Sopra questa velocità non si pesca: prima ci si ferma.
@export var fishing_max_speed: float = 1.5
## Attesa dell'abboccata, tra minimo e massimo.
@export var bite_wait_min: float = 0.8
@export var bite_wait_max: float = 2.4
## Traversate del cursore concesse prima che il pesce scappi.
@export var bite_sweeps: float = 4.0
## Secondi di permanenza del risultato a schermo.
@export var result_time: float = 1.6

enum State { IDLE, WAITING, BITE, RESULT }

## Assegnata da chi la spawna: serve per le increspature sull'acqua.
var sea: Sea

var _state: State = State.IDLE
var _boat: Boat = null
## La barca a cui il minigioco ha spento la guida: la riaccende sempre
## lui, anche se _boat si azzera uscendo dalla zona (pattern del Port).
var _fishing_boat: Boat = null
var _stock: int = GameState.FISHING_STOCK
var _resting: bool = false
var _wait_left: float = 0.0
var _bite_left: float = 0.0
var _result_left: float = 0.0
var _cursor_time: float = 0.0
var _window_center: float = 0.5
var _time: float = 0.0

@onready var _visual: Node3D = $Visual
@onready var _birds_pivot: Node3D = $Visual/BirdsPivot
@onready var _ripple_inner: MeshInstance3D = $Visual/RippleInner
@onready var _ripple_outer: MeshInstance3D = $Visual/RippleOuter
@onready var _hint: Label = $FishUI/Hint
@onready var _panel: PanelContainer = $FishUI/Panel
@onready var _info: Label = $FishUI/Panel/Margin/VBox/Info
@onready var _bar: Control = $FishUI/Panel/Margin/VBox/Bar
@onready var _window_rect: ColorRect = $FishUI/Panel/Margin/VBox/Bar/Window
@onready var _prize_rect: ColorRect = $FishUI/Panel/Margin/VBox/Bar/Prize
@onready var _cursor_rect: ColorRect = $FishUI/Panel/Margin/VBox/Bar/Cursor


func _ready() -> void:
	add_to_group(&"fishing_zones")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_panel.hide()
	_hint.hide()


func _process(delta: float) -> void:
	_time += delta
	_animate_visual()
	_update_hint()
	match _state:
		State.WAITING:
			_wait_left -= delta
			if _wait_left <= 0.0:
				_start_bite()
		State.BITE:
			_cursor_time += delta
			_bite_left -= delta
			_place_cursor()
			if _bite_left <= 0.0:
				_show_result("Scappato! Riprova…")
		State.RESULT:
			_result_left -= delta
			if _result_left <= 0.0:
				_end_fishing()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if _state == State.BITE:
			get_viewport().set_input_as_handled()
			_strike()
		elif _state == State.IDLE and _can_start():
			get_viewport().set_input_as_handled()
			_start_fishing()
	elif event.is_action_pressed("ui_cancel") and _state != State.IDLE:
		# Consumato: altrimenti lo stesso Esc aprirebbe anche la pausa.
		get_viewport().set_input_as_handled()
		_end_fishing()


## Vero mentre la zona riposa: la minimappa non la disegna.
func is_resting() -> bool:
	return _resting


func _can_start() -> bool:
	return _boat != null and not _resting \
		and absf(_boat.current_speed()) <= fishing_max_speed


func _on_body_entered(body: Node3D) -> void:
	if body is Boat:
		_boat = body


func _on_body_exited(body: Node3D) -> void:
	if body == _boat:
		_boat = null
		# Le onde possono spingere la barca fuori a lenza calata.
		if _state != State.IDLE:
			_end_fishing()


func _start_fishing() -> void:
	if GameState.cargo_count() >= GameState.cargo_capacity():
		GameState.post_notice("Stiva piena! Vendi al porto")
		return
	_fishing_boat = _boat
	_fishing_boat.input_enabled = false
	_fishing_boat.reset_motion()
	_state = State.WAITING
	_wait_left = randf_range(bite_wait_min, bite_wait_max)
	_info.text = "Lenza in acqua… aspetta l'abboccata"
	_window_rect.hide()
	_prize_rect.hide()
	_cursor_rect.hide()
	_panel.show()


func _start_bite() -> void:
	_state = State.BITE
	_cursor_time = 0.0
	_bite_left = bite_sweeps * _sweep_time()
	var half := _window_width() * 0.5
	_window_center = randf_range(half, 1.0 - half)
	_info.text = "ABBOCCA! Ferma il cursore nella finestra"
	var bar_w := _bar.size.x
	_window_rect.position.x = (_window_center - half) * bar_w
	_window_rect.size.x = _window_width() * bar_w
	var prize_half := half * GameState.FISHING_PRIZE_FRACTION
	_prize_rect.position.x = (_window_center - prize_half) * bar_w
	_prize_rect.size.x = prize_half * 2.0 * bar_w
	_window_rect.show()
	_prize_rect.show()
	_cursor_rect.show()
	_place_cursor()


func _strike() -> void:
	var offset := absf(_cursor_position() - _window_center)
	var half := _window_width() * 0.5
	if offset > half:
		_show_result("Scappato! Riprova…")
		return
	var prize := offset <= half * GameState.FISHING_PRIZE_FRACTION
	var type: int = GameState.FISHING_PRIZE[zone_tier] if prize \
		else GameState.FISHING_COMMON[zone_tier]
	if not GameState.collect_fish(type):
		_show_result("Stiva piena! Vendi al porto")
		return
	_stock -= 1
	var label := "Pesce pregiato: %s! (+%d $ in stiva)" if prize else "Preso: %s (+%d $ in stiva)"
	_show_result(label % [GameState.FISH_NAME[type], GameState.FISH_VALUE[type]])


## Il cursore resta fermo dov'è stato colpito: si vede quanto ci si è
## andati vicino.
func _show_result(text: String) -> void:
	_state = State.RESULT
	_result_left = result_time
	_info.text = text


func _end_fishing() -> void:
	_state = State.IDLE
	_panel.hide()
	if _fishing_boat != null:
		_fishing_boat.input_enabled = true
		_fishing_boat = null
	if _stock <= 0:
		_start_rest()


func _start_rest() -> void:
	_resting = true
	_visual.hide()
	GameState.post_notice("Zona esaurita: gli uccelli volano via")
	await get_tree().create_timer(GameState.FISHING_REST).timeout
	if not is_inside_tree():
		return
	_stock = GameState.FISHING_STOCK
	_resting = false
	_visual.show()


func _sweep_time() -> float:
	return GameState.FISHING_SWEEP_TIME[zone_tier]


func _window_width() -> float:
	return GameState.FISHING_WINDOW[zone_tier]


## Posizione del cursore 0..1: avanti e indietro sulla barra.
func _cursor_position() -> float:
	return pingpong(_cursor_time / _sweep_time(), 1.0)


func _place_cursor() -> void:
	_cursor_rect.position.x = _cursor_position() * (_bar.size.x - _cursor_rect.size.x)


func _animate_visual() -> void:
	if _resting:
		return
	_birds_pivot.rotation.y = _time * 0.7
	_ripple_inner.scale = Vector3.ONE * (1.0 + 0.10 * sin(_time * 1.8))
	_ripple_outer.scale = Vector3.ONE * (1.0 + 0.06 * sin(_time * 1.3 + 1.7))
	if sea != null:
		# Segue le onde solo in parte: gli anelli restano leggibili anche
		# col mare grosso.
		_visual.position.y = 0.06 + sea.get_height(global_position) * 0.4


func _update_hint() -> void:
	if _boat == null or _resting or _state != State.IDLE:
		_hint.hide()
		return
	_hint.show()
	if absf(_boat.current_speed()) <= fishing_max_speed:
		_hint.text = "Premi E per pescare"
	else:
		_hint.text = "Rallenta per pescare"
