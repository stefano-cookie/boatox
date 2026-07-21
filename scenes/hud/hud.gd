extends CanvasLayer

## HUD minimo di M1: denaro, barra scafo, stiva e messaggi transitori.
## Legge tutto da GameState via segnali, nessuna logica di gioco qui.

@onready var _money_label: Label = $TopLeft/VBox/MoneyLabel
@onready var _hull_bar: ProgressBar = $TopLeft/VBox/HullRow/HullBar
@onready var _cargo_label: Label = $TopLeft/VBox/CargoLabel
@onready var _notice_label: Label = $NoticeLabel
@onready var _notice_timer: Timer = $NoticeTimer


func _ready() -> void:
	GameState.money_changed.connect(_on_money_changed)
	GameState.hull_changed.connect(_on_hull_changed)
	GameState.cargo_changed.connect(_on_cargo_changed)
	GameState.notice_posted.connect(_on_notice_posted)
	_notice_timer.timeout.connect(_notice_label.hide)
	_notice_label.hide()
	_on_money_changed(GameState.money)
	_on_hull_changed(GameState.hull, GameState.HULL_MAX)
	_on_cargo_changed(GameState.cargo_common, GameState.cargo_golden)


func _on_money_changed(amount: int) -> void:
	_money_label.text = "%d $" % amount


func _on_hull_changed(current: float, max_value: float) -> void:
	_hull_bar.max_value = max_value
	_hull_bar.value = current


func _on_cargo_changed(common: int, golden: int) -> void:
	var count := common + golden
	if count == 0:
		_cargo_label.text = "Stiva: vuota"
	else:
		_cargo_label.text = "Stiva: %d boe · %d $" % [count, GameState.cargo_value()]


func _on_notice_posted(text: String) -> void:
	_notice_label.text = text
	_notice_label.show()
	_notice_timer.start()
