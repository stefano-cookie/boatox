extends Node

## Radar a impulsi (GDD § Missioni): sbloccato dalla missione del nipote,
## rivela boe, taniche e zone di pesca in minimappa per una finestra di
## tempo dopo l'impulso, poi si spegne fino al cooldown. Qui vive solo lo
## stato runtime (cooldown, finestra attiva, origine dell'impulso): i
## valori di bilanciamento e i livelli dei potenziamenti stanno in
## GameState (RADAR_*). L'input (tasto R) e l'HUD lo pilotano; la
## minimappa legge origin()/detection_radius_fraction()/is_active() per
## disegnare i rilevamenti. Autoload perché sia HUD sia minimappa lo
## interrogano, senza duplicare lo stato.

var _cooldown_left: float = 0.0
var _window_left: float = 0.0
var _origin: Vector3 = Vector3.ZERO
## Frazione di mappa fotografata al momento dell'impulso (un potenziamento
## comprato dopo non allarga un impulso già in corso).
var _range_fraction: float = 0.0


func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if _window_left > 0.0:
		_window_left = maxf(_window_left - delta, 0.0)


## Vero se si può lanciare un impulso: radar sbloccato, nessun pannello
## aperto e cooldown scaduto.
func can_ping() -> bool:
	return GameState.radar_unlocked and not GameState.ui_focus_open() and _cooldown_left <= 0.0


## Lancia l'impulso dall'origine data (posizione della barca): fotografa
## raggio e durata dai potenziamenti correnti e avvia cooldown e finestra.
func ping(origin: Vector3) -> void:
	if not can_ping():
		return
	_origin = origin
	_range_fraction = GameState.radar_range_fraction()
	_window_left = GameState.radar_duration()
	_cooldown_left = GameState.RADAR_COOLDOWN
	GameState.post_notice("Radar: impulso lanciato")


## Vero mentre i rilevamenti sono visibili in minimappa.
func is_active() -> bool:
	return _window_left > 0.0


func window_left() -> float:
	return _window_left


func cooldown_left() -> float:
	return _cooldown_left


func origin() -> Vector3:
	return _origin


func range_fraction() -> float:
	return _range_fraction


## Ripristina lo stato (usato dal "Ricomincia" della pausa, che ricarica
## la scena ma non gli autoload).
func reset() -> void:
	_cooldown_left = 0.0
	_window_left = 0.0
	_range_fraction = 0.0
