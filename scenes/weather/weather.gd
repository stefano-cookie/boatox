class_name Weather
extends Node

## Meteo dinamico (GDD § Navigazione): stati calmo → mosso che cambiano
## a onde temporali sopra le zone statiche del mare. Col mosso tutte le
## ampiezze salgono (moltiplicatore globale sulla Sea) e la barca poco
## stabile diventa quasi ingovernabile al largo: è il cancello di
## progressione principale. Durate e intensità sono @export da tarare
## giocando (CLAUDE.md).

signal state_changed(rough: bool)

@export var sea: Sea

@export_group("Durate (secondi)")
@export var calm_min: float = 90.0
@export var calm_max: float = 150.0
@export var rough_min: float = 45.0
@export var rough_max: float = 75.0
## Secondi perché il mare passi da uno stato all'altro.
@export var ramp_time: float = 8.0
## Preavviso a schermo prima del cambio di stato.
@export var warning_lead: float = 6.0

@export_group("Intensità")
## Moltiplicatore d'ampiezza globale quando il mare è mosso.
@export var rough_multiplier: float = 1.8

var rough: bool = false

var _time_left: float = 0.0
var _warned: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_time_left = _rng.randf_range(calm_min, calm_max)


func _process(delta: float) -> void:
	_time_left -= delta
	if not _warned and _time_left <= warning_lead:
		_warned = true
		if rough:
			GameState.post_notice("Il mare si sta calmando")
		else:
			GameState.post_notice("Il mare si sta ingrossando!")
	if _time_left <= 0.0:
		_flip_state()
	if sea != null:
		var target := rough_multiplier if rough else 1.0
		var ramp_speed := (rough_multiplier - 1.0) / maxf(ramp_time, 0.01)
		sea.weather_multiplier = move_toward(sea.weather_multiplier, target, ramp_speed * delta)


func _flip_state() -> void:
	rough = not rough
	_warned = false
	if rough:
		_time_left = _rng.randf_range(rough_min, rough_max)
	else:
		_time_left = _rng.randf_range(calm_min, calm_max)
	state_changed.emit(rough)
