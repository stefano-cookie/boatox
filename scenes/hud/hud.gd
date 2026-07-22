extends CanvasLayer

## HUD: denaro, barre scafo e benzina, stiva dettagliata per tipo di boa,
## barca corrente, tachimetro in nodi, zona di mare, stato del meteo,
## messaggi transitori e alert persistente (countdown fuori zona). Legge
## tutto da GameState via segnali e dalla barca per la velocità: nessuna
## logica di gioco qui.

const MS_TO_KNOTS: float = 1.94384
const ZONE_NAMES: Array[String] = ["Acque calme", "Acque medie", "Mare aperto"]
## Stato locale del mare nel punto della barca (feedback playtest M3):
## soglie di agitazione (zona × vento × meteo) e nomi/colori affiancati.
## Le soglie alte ricalcano quelle di caos e danni della barca.
const SEA_STATE_STEPS: Array[float] = [1.1, 1.9, 2.8, 3.4]
const SEA_STATE_NAMES: Array[String] = [
	"calmo", "increspato", "agitato", "grosso", "tempesta",
]
const SEA_STATE_COLORS: Array[Color] = [
	Color(0.75, 0.95, 0.85),
	Color(0.85, 0.95, 0.6),
	Color(1.0, 0.85, 0.4),
	Color(1.0, 0.6, 0.35),
	Color(1.0, 0.4, 0.3),
]
const WEATHER_CALM_COLOR := Color(0.75, 0.95, 0.85)
const WEATHER_ROUGH_COLOR := Color(1.0, 0.45, 0.35)
const FUEL_OK_COLOR := Color(0.85, 0.9, 0.95)
const FUEL_LOW_COLOR := Color(1.0, 0.35, 0.3)
## Sotto questa frazione di serbatoio la scritta benzina diventa rossa.
const FUEL_LOW_RATIO: float = 0.2

@export var boat: Boat
@export var sea: Sea
@export var weather: Weather
@export var world: World
## Moltiplica i font_size di tutti i pannelli all'avvio (feedback playtest
## round 2: "l'interfaccia è troppo piccola"). 1.0 = dimensioni base della
## scena; si tara da Inspector senza toccare i singoli nodi.
@export var ui_scale: float = 1.0

## Flash rosso della barra scafo a ogni urto.
const HULL_FLASH_COLOR := Color(1.0, 0.3, 0.25)
const HULL_FLASH_TIME: float = 0.4

## Stato del radar (visibile solo dopo lo sblocco dalla missione del nipote).
const RADAR_READY_COLOR := Color(0.55, 0.9, 1.0)
const RADAR_ACTIVE_COLOR := Color(0.5, 1.0, 0.6)
const RADAR_COOLDOWN_COLOR := Color(0.7, 0.75, 0.82)

@onready var _money_label: Label = $TopLeft/Margin/VBox/MoneyLabel
@onready var _boat_label: Label = $TopLeft/Margin/VBox/BoatLabel
@onready var _hull_bar: ProgressBar = $TopLeft/Margin/VBox/HullRow/HullBar
@onready var _fuel_bar: ProgressBar = $TopLeft/Margin/VBox/FuelRow/FuelBar
@onready var _fuel_title: Label = $TopLeft/Margin/VBox/FuelRow/FuelTitle
@onready var _fuel_label: Label = $TopLeft/Margin/VBox/FuelRow/FuelLabel
@onready var _cargo_info: RichTextLabel = $TopLeft/Margin/VBox/CargoInfo
@onready var _notice_label: Label = $NoticeLabel
@onready var _notice_timer: Timer = $NoticeTimer
@onready var _danger_label: Label = $DangerLabel
@onready var _speed_label: Label = $SpeedBox/Margin/VBox/SpeedLabel
@onready var _speed_bar: ProgressBar = $SpeedBox/Margin/VBox/SpeedBar
@onready var _zone_label: Label = $SpeedBox/Margin/VBox/ZoneLabel
@onready var _weather_label: Label = $SpeedBox/Margin/VBox/WeatherLabel
@onready var _radar_label: Label = $SpeedBox/Margin/VBox/RadarLabel
@onready var _goal_box: PanelContainer = $GoalBox
@onready var _goal_label: Label = $GoalBox/GoalMargin/GoalLabel
@onready var _minimap: Minimap = $Minimap

var _hull_flash: Tween


func _ready() -> void:
	GameState.money_changed.connect(_on_money_changed)
	GameState.hull_changed.connect(_on_hull_changed)
	GameState.fuel_changed.connect(_on_fuel_changed)
	GameState.cargo_changed.connect(_on_cargo_changed)
	GameState.boat_changed.connect(_on_boat_changed)
	GameState.notice_posted.connect(_on_notice_posted)
	GameState.danger_changed.connect(_on_danger_changed)
	GameState.danger_cleared.connect(_danger_label.hide)
	GameState.tutorial_changed.connect(_on_tutorial_changed)
	GameState.boat_hit.connect(_on_boat_hit)
	if weather != null:
		weather.state_changed.connect(_on_weather_changed)
		_on_weather_changed(weather.rough)
	_minimap.setup(boat, sea, world)
	_notice_timer.timeout.connect(_notice_label.hide)
	_notice_label.hide()
	_danger_label.hide()
	_on_money_changed(GameState.money)
	_on_hull_changed(GameState.hull, GameState.hull_max())
	_on_fuel_changed(GameState.fuel, GameState.fuel_capacity())
	_on_cargo_changed()
	_on_boat_changed(GameState.current_def())
	_apply_ui_scale()
	_on_tutorial_changed(GameState.tutorial_step, GameState.tutorial_hint())
	_update_radar()


## Impulso radar (tasto R): rivela boe e zone in minimappa. Attivo solo
## dopo lo sblocco e a cooldown scaduto (guardie in Radar.can_ping);
## nessun altro pannello lo usa, quindi non c'è conflitto con Esc/E.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("radar_ping") and boat != null and Radar.can_ping():
		get_viewport().set_input_as_handled()
		Radar.ping(boat.global_position)


func _process(_delta: float) -> void:
	if boat == null:
		return
	var speed := absf(boat.current_speed())
	_speed_label.text = "%d nodi" % roundi(speed * MS_TO_KNOTS)
	_speed_bar.value = speed
	if sea != null:
		var zone := sea.zone_index(boat.global_position)
		var state := _sea_state_index(sea.agitation(boat.global_position))
		_zone_label.text = "%s · %s" % [ZONE_NAMES[zone], SEA_STATE_NAMES[state]]
		_zone_label.modulate = SEA_STATE_COLORS[state]
	_update_radar()


## Riga di stato del radar in basso a destra: nascosta finché è bloccato,
## poi pronto / attivo (finestra) / in cooldown.
func _update_radar() -> void:
	if not GameState.radar_unlocked:
		_radar_label.hide()
		return
	_radar_label.show()
	if Radar.is_active():
		_radar_label.text = "Radar attivo · %d s" % ceili(Radar.window_left())
		_radar_label.modulate = RADAR_ACTIVE_COLOR
	elif Radar.cooldown_left() > 0.0:
		_radar_label.text = "Radar: %d s" % ceili(Radar.cooldown_left())
		_radar_label.modulate = RADAR_COOLDOWN_COLOR
	else:
		_radar_label.text = "Radar: pronto (R)"
		_radar_label.modulate = RADAR_READY_COLOR


## Indice dello stato locale del mare a partire dall'agitazione.
func _sea_state_index(agitation: float) -> int:
	for i in SEA_STATE_STEPS.size():
		if agitation < SEA_STATE_STEPS[i]:
			return i
	return SEA_STATE_STEPS.size()


func _on_money_changed(amount: int) -> void:
	_money_label.text = "%d $" % amount


func _on_hull_changed(current: float, max_value: float) -> void:
	_hull_bar.max_value = max_value
	_hull_bar.value = current


func _on_fuel_changed(current: float, max_value: float) -> void:
	_fuel_bar.max_value = max_value
	_fuel_bar.value = current
	_fuel_label.text = "%d L" % ceili(current)
	var low := current <= max_value * FUEL_LOW_RATIO
	_fuel_title.modulate = FUEL_LOW_COLOR if low else Color.WHITE
	_fuel_label.modulate = FUEL_LOW_COLOR if low else FUEL_OK_COLOR


func _on_cargo_changed() -> void:
	var count := GameState.cargo_count()
	var capacity := GameState.cargo_capacity()
	if count == 0:
		_cargo_info.text = "Stiva %d/%d: vuota" % [count, capacity]
	else:
		_cargo_info.text = "Stiva %d/%d: %s — vale [color=#8ee3a8]%d $[/color]" % [
			count, capacity, GameState.cargo_detail_bbcode(), GameState.cargo_value(),
		]


func _on_boat_changed(def: BoatDefinition) -> void:
	_boat_label.text = def.display_name
	if boat != null:
		_speed_bar.max_value = GameState.effective_max_speed()
	_on_fuel_changed(GameState.fuel, GameState.fuel_capacity())


func _on_weather_changed(rough: bool) -> void:
	if rough:
		_weather_label.text = "Mare mosso"
		_weather_label.modulate = WEATHER_ROUGH_COLOR
	else:
		_weather_label.text = "Mare calmo"
		_weather_label.modulate = WEATHER_CALM_COLOR


func _on_notice_posted(text: String) -> void:
	_notice_label.text = text
	_notice_label.show()
	_notice_timer.start()


func _on_danger_changed(text: String) -> void:
	_danger_label.text = text
	_danger_label.show()


## Obiettivo guidato: mostra la riga della tappa, nasconde il pannello a
## tutorial finito.
func _on_tutorial_changed(step: int, text: String) -> void:
	if step >= GameState.TUTORIAL_DONE or text.is_empty():
		_goal_box.hide()
		return
	_goal_label.text = text
	_goal_box.show()


## Flash rosso della barra scafo a ogni urto (feedback playtest round 2:
## "quando sbatti non te ne accorgi"). La forza qui non serve: il flash è
## uguale, sono lo shake camera e le particelle a scalare con l'impatto.
func _on_boat_hit(_force: float) -> void:
	if _hull_flash != null and _hull_flash.is_valid():
		_hull_flash.kill()
	_hull_bar.modulate = HULL_FLASH_COLOR
	_hull_flash = create_tween()
	_hull_flash.tween_property(_hull_bar, "modulate", Color.WHITE, HULL_FLASH_TIME)


# --- Scala UI ----------------------------------------------------------------

## Moltiplica i font (e le dimensioni minime delle barre) dei pannelli per
## ui_scale. I pannelli sono Container e si ridimensionano al contenuto,
## quindi crescono senza uscire dallo schermo (restano ancorati agli angoli).
func _apply_ui_scale() -> void:
	if is_equal_approx(ui_scale, 1.0):
		return
	for root: Node in [$TopLeft, $SpeedBox, $GoalBox]:
		_scale_control_tree(root)
	_scale_font(_notice_label)
	_scale_font(_danger_label)


func _scale_control_tree(node: Node) -> void:
	for child in node.get_children():
		if child is ProgressBar:
			(child as ProgressBar).custom_minimum_size *= ui_scale
		elif child is Label or child is RichTextLabel:
			_scale_font(child)
		_scale_control_tree(child)


func _scale_font(control: Control) -> void:
	var key := "normal_font_size" if control is RichTextLabel else "font_size"
	var size := control.get_theme_font_size(key)
	control.add_theme_font_size_override(key, roundi(size * ui_scale))
