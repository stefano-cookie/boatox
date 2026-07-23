class_name FishingZone
extends Area3D

## Zona di pesca (GDD § Pesca): un punto visibile da lontano — uccelli in
## cerchio e anelli d'increspatura sull'acqua — dove fermarsi e pescare
## con E. Minigioco in due fasi (feedback playtest M3): la ferrata a
## tempismo (cursore nella finestra verde, centro dorato = pesce
## pregiato), poi il duello — il pesce tira, tieni premuto E per
## recuperare ma la tensione sale; molla per farla calare. Tensione al
## massimo troppo a lungo e il filo si spezza. I pregiati fanno scatti
## casuali: bisogna mollare al momento giusto. Esaurito lo stock gli
## uccelli se ne vanno e la zona riposa. Specie, valori, difficoltà e
## parametri del duello per specie in GameState.

## Fascia di mare della zona: decide specie e difficoltà (0 = calme).
@export_range(0, 2) var zone_tier: int = 0
## Raggio della zona (feedback playtest round 2: sembravano spot troppo
## piccoli, 9 → 15). Guida il CylinderShape3D e la scala degli anelli
## visivi all'_ready — si tara da Inspector senza toccare la scena.
@export var zone_radius: float = 15.0
## Sopra questa velocità non si pesca: prima ci si ferma.
@export var fishing_max_speed: float = 1.5
## Attesa dell'abboccata, tra minimo e massimo.
@export var bite_wait_min: float = 0.8
@export var bite_wait_max: float = 2.4
## Traversate del cursore concesse prima che il pesce scappi.
@export var bite_sweeps: float = 4.0
## Secondi di permanenza del risultato a schermo.
@export var result_time: float = 1.6

enum State { IDLE, WAITING, BITE, FIGHT, RESULT }

## Angolo di beccheggio della barca a tensione piena durante il duello.
const FIGHT_PITCH_DEG: float = -4.5
## Colori della barra tensione: verde → giallo → rosso.
const TENSION_OK := Color(0.3, 0.85, 0.45)
const TENSION_WARN := Color(1.0, 0.84, 0.3)
const TENSION_DANGER := Color(0.95, 0.3, 0.25)

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
# Stato del duello (fase 2).
var _fight_type: int = GameState.FishType.SARDINE
var _fight_prize: bool = false
var _progress: float = 0.0
var _tension: float = 0.0
var _snap_time: float = 0.0
var _surge_left: float = 0.0
var _surge_timer: float = 0.0

## Scala degli anelli e del giro d'uccelli rispetto al raggio base (9 m).
var _ripple_factor: float = 1.0

@onready var _collision: CollisionShape3D = $CollisionShape3D
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
@onready var _fight_box: VBoxContainer = $FishUI/Panel/Margin/VBox/FightBox
@onready var _reel_bar: Control = $FishUI/Panel/Margin/VBox/FightBox/ReelBar
@onready var _reel_fill: ColorRect = $FishUI/Panel/Margin/VBox/FightBox/ReelBar/Fill
@onready var _tension_bar: Control = $FishUI/Panel/Margin/VBox/FightBox/TensionBar
@onready var _tension_fill: ColorRect = $FishUI/Panel/Margin/VBox/FightBox/TensionBar/Fill
@onready var _tip: Label = $FishUI/Panel/Margin/VBox/Tip


func _ready() -> void:
	add_to_group(&"fishing_zones")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_apply_radius()
	_panel.hide()
	_hint.hide()


## Adatta collisione e anelli visivi al zone_radius (9 = base della scena).
## Duplica la shape per non mutare la sottorisorsa condivisa tra istanze.
func _apply_radius() -> void:
	var shape := (_collision.shape as CylinderShape3D).duplicate() as CylinderShape3D
	shape.radius = zone_radius
	_collision.shape = shape
	_ripple_factor = zone_radius / 9.0
	_birds_pivot.scale = Vector3(_ripple_factor, 1.0, _ripple_factor)


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
		State.FIGHT:
			_update_fight(delta)
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
	GameState.push_ui_focus()
	_state = State.WAITING
	_wait_left = randf_range(bite_wait_min, bite_wait_max)
	_info.text = "Lenza in acqua… aspetta l'abboccata"
	_tip.text = "E per ferrare  ·  Esc per annullare"
	_window_rect.hide()
	_prize_rect.hide()
	_cursor_rect.hide()
	_fight_box.hide()
	_bar.show()
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


## Ferrata riuscita: non si incassa subito, inizia il duello (fase 2).
func _strike() -> void:
	var offset := absf(_cursor_position() - _window_center)
	var half := _window_width() * 0.5
	if offset > half:
		_show_result("Scappato! Riprova…")
		return
	_fight_prize = offset <= half * GameState.FISHING_PRIZE_FRACTION
	_fight_type = GameState.FISHING_PRIZE[zone_tier] if _fight_prize \
		else GameState.FISHING_COMMON[zone_tier]
	_start_fight()


# --- Fase 2: il duello -------------------------------------------------------

func _start_fight() -> void:
	_state = State.FIGHT
	_progress = 0.05
	_tension = 0.25
	_snap_time = 0.0
	_surge_left = 0.0
	_surge_timer = _next_surge_delay()
	_info.text = "ABBOCCATO! Il pesce combatte"
	_tip.text = "Tieni premuto E per recuperare  ·  molla per la tensione"
	_bar.hide()
	_fight_box.show()
	_refresh_fight_bars()


## Il tira-e-molla: E premuto recupera lenza ma alza la tensione, mollare
## la fa calare (e il pesce riprende un po' di lenza). Gli scatti alzano
## la tensione anche a lenza mollata: vanno assecondati. Parametri per
## specie in GameState.FISH_FIGHT.
func _update_fight(delta: float) -> void:
	var params: Dictionary = GameState.FISH_FIGHT[_fight_type]
	# Il mulinello velocizza il recupero e frena la salita di tensione, la
	# lenza ammorbidisce gli strappi (attrezzatura comprata da Nino).
	var reel_time: float = params["reel_time"] * GameState.fishing_reel_time_mult()
	var rise: float = params["rise"] * GameState.fishing_reel_rise_mult()
	var surge_interval: float = params["surge_interval"]
	var surge_duration: float = params["surge_duration"]
	var surge_rise: float = params["surge_rise"] * GameState.fishing_surge_mult()
	var holding := Input.is_action_pressed("interact")
	if _surge_left > 0.0:
		_surge_left -= delta
		if _surge_left <= 0.0:
			_info.text = "Il pesce combatte"
	elif surge_interval > 0.0:
		_surge_timer -= delta
		if _surge_timer <= 0.0:
			_surge_left = surge_duration * randf_range(0.8, 1.2)
			_surge_timer = _next_surge_delay()
			_info.text = "STRAPPO! Molla la lenza!"
	var surging := _surge_left > 0.0
	if holding:
		_progress = minf(_progress + delta / reel_time, 1.0)
		_tension += rise * delta
	else:
		_progress = maxf(_progress - GameState.FISH_PROGRESS_DECAY * delta, 0.0)
		_tension -= GameState.FISH_TENSION_FALL * delta
	if surging:
		_tension += surge_rise * delta
	_tension = clampf(_tension, 0.0, 1.0)
	if _tension >= 0.999:
		_snap_time += delta
		if _snap_time >= GameState.fishing_snap_grace():
			_show_result("Il filo si spezza! Pesce perso…")
			return
	else:
		_snap_time = 0.0
	# La barca si inclina verso il pesce che tira: si sente il duello.
	if _fishing_boat != null:
		_fishing_boat.fight_pitch = deg_to_rad(FIGHT_PITCH_DEG) * (0.35 + 0.65 * _tension)
	if _progress >= 1.0:
		_finish_catch()
		return
	_refresh_fight_bars()


func _finish_catch() -> void:
	if not GameState.collect_fish(_fight_type):
		_show_result("Stiva piena! Vendi al porto")
		return
	_stock -= 1
	var label := "Pesce pregiato: %s! (+%d $ in stiva)" if _fight_prize \
		else "Preso: %s (+%d $ in stiva)"
	var fish := GameState.fish_item(_fight_type)
	_show_result(label % [fish.display_name, fish.base_value])


func _refresh_fight_bars() -> void:
	_reel_fill.size.x = _progress * _reel_bar.size.x
	_tension_fill.size.x = _tension * _tension_bar.size.x
	if _tension < 0.55:
		_tension_fill.color = TENSION_OK
	elif _tension < 0.8:
		_tension_fill.color = TENSION_WARN
	else:
		_tension_fill.color = TENSION_DANGER
	# Piccolo shake sull'ultimo tratto del recupero: il pesce è quasi su.
	_panel.pivot_offset = _panel.size * 0.5
	_panel.rotation = randf_range(-0.006, 0.006) if _progress > 0.82 else 0.0


func _next_surge_delay() -> float:
	var surge_interval: float = GameState.FISH_FIGHT[_fight_type]["surge_interval"]
	if surge_interval <= 0.0:
		return INF
	return surge_interval * randf_range(0.7, 1.4)


## Il cursore resta fermo dov'è stato colpito: si vede quanto ci si è
## andati vicino.
func _show_result(text: String) -> void:
	_state = State.RESULT
	_result_left = result_time
	_info.text = text
	_panel.rotation = 0.0
	if _fishing_boat != null:
		_fishing_boat.fight_pitch = 0.0


func _end_fishing() -> void:
	_state = State.IDLE
	_panel.hide()
	_panel.rotation = 0.0
	GameState.pop_ui_focus()
	if _fishing_boat != null:
		_fishing_boat.fight_pitch = 0.0
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


## Finestra di ferrata: base della fascia più il bonus della canna
## (clampata così il centro resta piazzabile sulla barra).
func _window_width() -> float:
	return clampf(GameState.FISHING_WINDOW[zone_tier] + GameState.fishing_window_bonus(), 0.05, 0.6)


## Posizione del cursore 0..1: avanti e indietro sulla barra.
func _cursor_position() -> float:
	return pingpong(_cursor_time / _sweep_time(), 1.0)


func _place_cursor() -> void:
	_cursor_rect.position.x = _cursor_position() * (_bar.size.x - _cursor_rect.size.x)


func _animate_visual() -> void:
	if _resting:
		return
	_birds_pivot.rotation.y = _time * 0.7
	_ripple_inner.scale = Vector3.ONE * _ripple_factor * (1.0 + 0.10 * sin(_time * 1.8))
	_ripple_outer.scale = Vector3.ONE * _ripple_factor * (1.0 + 0.06 * sin(_time * 1.3 + 1.7))
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
