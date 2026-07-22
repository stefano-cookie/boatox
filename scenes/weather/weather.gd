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

@export_group("Atmosfera")
## Se assegnati, il cielo si incupisce col mare mosso: luce più fredda e
## debole, foschia più fitta e vicina. Tutto in scala con la rampa del
## mare, così il cambio è graduale come le onde.
@export var environment: WorldEnvironment
@export var sun: DirectionalLight3D
@export var rough_sun_energy: float = 0.7
@export var rough_fog_color: Color = Color(0.52, 0.56, 0.6)
@export var rough_fog_depth_end: float = 220.0
## Col mosso la foschia mangia anche il cielo: niente tempesta col sole.
@export var rough_fog_sky_affect: float = 0.55

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

# Valori di cielo sereno, letti dalla scena all'avvio.
var _calm_sun_energy: float = 1.0
var _calm_fog_color: Color = Color.WHITE
var _calm_fog_depth_end: float = 240.0
var _calm_fog_sky_affect: float = 0.15


func _ready() -> void:
	_time_left = _rng.randf_range(calm_min, calm_max)
	if sun != null:
		_calm_sun_energy = sun.light_energy
	if environment != null:
		_calm_fog_color = environment.environment.fog_light_color
		_calm_fog_depth_end = environment.environment.fog_depth_end
		_calm_fog_sky_affect = environment.environment.fog_sky_affect


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
		_update_atmosphere()


## Incupisce cielo e luce in proporzione a quanto il mare è già salito:
## atmosfera e onde raccontano la stessa cosa nello stesso momento.
func _update_atmosphere() -> void:
	var t := clampf((sea.weather_multiplier - 1.0) / maxf(rough_multiplier - 1.0, 0.01), 0.0, 1.0)
	if sun != null:
		sun.light_energy = lerpf(_calm_sun_energy, rough_sun_energy, t)
	if environment != null:
		environment.environment.fog_light_color = _calm_fog_color.lerp(rough_fog_color, t)
		environment.environment.fog_depth_end = lerpf(_calm_fog_depth_end, rough_fog_depth_end, t)
		environment.environment.fog_sky_affect = lerpf(_calm_fog_sky_affect, rough_fog_sky_affect, t)


func _flip_state() -> void:
	rough = not rough
	_warned = false
	if rough:
		_time_left = _rng.randf_range(rough_min, rough_max)
	else:
		_time_left = _rng.randf_range(calm_min, calm_max)
	state_changed.emit(rough)
