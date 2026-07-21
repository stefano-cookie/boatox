extends CanvasLayer

## HUD: denaro, barra scafo, stiva con capacità, barca corrente,
## tachimetro in nodi, zona di mare, stato del meteo, messaggi
## transitori e alert persistente (countdown fuori zona). Legge tutto da
## GameState via segnali e dalla barca per la velocità: nessuna logica
## di gioco qui.

const MS_TO_KNOTS: float = 1.94384
const ZONE_NAMES: Array[String] = ["Acque calme", "Acque medie", "Acque mosse"]
const ZONE_COLORS: Array[Color] = [
	Color(0.75, 0.95, 0.85),
	Color(1.0, 0.85, 0.4),
	Color(1.0, 0.45, 0.35),
]
const WEATHER_CALM_COLOR := Color(0.75, 0.95, 0.85)
const WEATHER_ROUGH_COLOR := Color(1.0, 0.45, 0.35)

@export var boat: Boat
@export var sea: Sea
@export var weather: Weather

@onready var _money_label: Label = $TopLeft/VBox/MoneyLabel
@onready var _boat_label: Label = $TopLeft/VBox/BoatLabel
@onready var _hull_bar: ProgressBar = $TopLeft/VBox/HullRow/HullBar
@onready var _cargo_label: Label = $TopLeft/VBox/CargoLabel
@onready var _notice_label: Label = $NoticeLabel
@onready var _notice_timer: Timer = $NoticeTimer
@onready var _danger_label: Label = $DangerLabel
@onready var _speed_label: Label = $SpeedBox/SpeedLabel
@onready var _speed_bar: ProgressBar = $SpeedBox/SpeedBar
@onready var _zone_label: Label = $SpeedBox/ZoneLabel
@onready var _weather_label: Label = $SpeedBox/WeatherLabel


func _ready() -> void:
	GameState.money_changed.connect(_on_money_changed)
	GameState.hull_changed.connect(_on_hull_changed)
	GameState.cargo_changed.connect(_on_cargo_changed)
	GameState.boat_changed.connect(_on_boat_changed)
	GameState.notice_posted.connect(_on_notice_posted)
	GameState.danger_changed.connect(_on_danger_changed)
	GameState.danger_cleared.connect(_danger_label.hide)
	if weather != null:
		weather.state_changed.connect(_on_weather_changed)
		_on_weather_changed(weather.rough)
	_notice_timer.timeout.connect(_notice_label.hide)
	_notice_label.hide()
	_danger_label.hide()
	_on_money_changed(GameState.money)
	_on_hull_changed(GameState.hull, GameState.hull_max())
	_on_cargo_changed()
	_on_boat_changed(GameState.current_def())


func _process(_delta: float) -> void:
	if boat == null:
		return
	var speed := absf(boat.current_speed())
	_speed_label.text = "%d nodi" % roundi(speed * MS_TO_KNOTS)
	_speed_bar.value = speed
	if sea != null:
		var zone := sea.zone_index(boat.global_position)
		_zone_label.text = ZONE_NAMES[zone]
		_zone_label.modulate = ZONE_COLORS[zone]


func _on_money_changed(amount: int) -> void:
	_money_label.text = "%d $" % amount


func _on_hull_changed(current: float, max_value: float) -> void:
	_hull_bar.max_value = max_value
	_hull_bar.value = current


func _on_cargo_changed() -> void:
	var count := GameState.cargo_count()
	var capacity := GameState.cargo_capacity()
	if count == 0:
		_cargo_label.text = "Stiva: 0/%d" % capacity
	else:
		_cargo_label.text = "Stiva: %d/%d · %d $" % [count, capacity, GameState.cargo_value()]


func _on_boat_changed(def: BoatDefinition) -> void:
	_boat_label.text = def.display_name
	if boat != null:
		_speed_bar.max_value = GameState.effective_max_speed()


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
