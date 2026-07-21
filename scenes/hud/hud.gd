extends CanvasLayer

## HUD di M1: denaro, barra scafo, stiva, tachimetro in nodi, messaggi
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

@export var boat: Boat
@export var sea: Sea

@onready var _money_label: Label = $TopLeft/VBox/MoneyLabel
@onready var _hull_bar: ProgressBar = $TopLeft/VBox/HullRow/HullBar
@onready var _cargo_label: Label = $TopLeft/VBox/CargoLabel
@onready var _notice_label: Label = $NoticeLabel
@onready var _notice_timer: Timer = $NoticeTimer
@onready var _danger_label: Label = $DangerLabel
@onready var _speed_label: Label = $SpeedBox/SpeedLabel
@onready var _speed_bar: ProgressBar = $SpeedBox/SpeedBar
@onready var _zone_label: Label = $SpeedBox/ZoneLabel


func _ready() -> void:
	GameState.money_changed.connect(_on_money_changed)
	GameState.hull_changed.connect(_on_hull_changed)
	GameState.cargo_changed.connect(_on_cargo_changed)
	GameState.notice_posted.connect(_on_notice_posted)
	GameState.danger_changed.connect(_on_danger_changed)
	GameState.danger_cleared.connect(_danger_label.hide)
	_notice_timer.timeout.connect(_notice_label.hide)
	_notice_label.hide()
	_danger_label.hide()
	if boat != null:
		_speed_bar.max_value = boat.max_speed
	_on_money_changed(GameState.money)
	_on_hull_changed(GameState.hull, GameState.HULL_MAX)
	_on_cargo_changed()


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
	if count == 0:
		_cargo_label.text = "Stiva: vuota"
	else:
		_cargo_label.text = "Stiva: %d boe · %d $" % [count, GameState.cargo_value()]


func _on_notice_posted(text: String) -> void:
	_notice_label.text = text
	_notice_label.show()
	_notice_timer.start()


func _on_danger_changed(text: String) -> void:
	_danger_label.text = text
	_danger_label.show()
