class_name ChaseCamera
extends Camera3D

## Terza persona stile GTA (GDD § Camera): resta dietro e sopra il
## bersaglio, ruota con smorzamento verso la sua prua e guarda un punto
## davanti alla barca. Il mouse orbita liberamente attorno alla barca
## (feedback playtest M3) e dopo un po' senza input la camera torna da
## sola dietro la poppa. Il mouse è catturato durante la guida; i
## pannelli (porto, pesca, regata, pausa) lo liberano tutti passando dal
## segnale GameState.ui_focus_changed. Tutti i parametri sono da tarare
## giocando.

@export var target: Node3D
@export var distance: float = 9.0
@export var height: float = 4.5
## Altezza del punto guardato sopra il bersaglio.
@export var look_height: float = 1.2
## Metri davanti alla prua verso cui guarda la camera.
@export var look_ahead: float = 4.0
@export var position_smoothing: float = 4.0
@export var yaw_smoothing: float = 3.0

@export_group("Orbita mouse")
## Gradi di orbita per pixel di movimento del mouse (basso = lento).
@export var mouse_sensitivity: float = 0.12
## Quanto in fretta la camera insegue il bersaglio d'orbita del mouse:
## più basso = più morbido e ritardato (meno mal di testa).
@export var orbit_smoothing: float = 6.0
@export var pitch_min_deg: float = -10.0
@export var pitch_max_deg: float = 45.0
## Secondi senza input mouse prima del ritorno dietro la poppa.
@export var orbit_return_delay: float = 2.0
## Velocità dello smorzamento del ritorno automatico.
@export var orbit_return_smoothing: float = 2.5
## La camera non scende mai sotto quest'altezza sull'acqua.
@export var min_height: float = 1.2

@export_group("Scuotimento urto")
## Spostamento massimo (m) della camera a impatto pieno.
@export var shake_max_offset: float = 0.7
## Secondi di durata dello scuotimento.
@export var shake_duration: float = 0.4
## Velocità d'impatto (m/s) oltre cui lo shake è al massimo.
@export var shake_force_ref: float = 12.0

var _yaw: float = 0.0
## Scuotimento da urto: _shake_time scende a 0, _shake_amount è l'intensità
## 0..1 dell'ultimo impatto (feedback playtest round 2).
var _shake_time: float = 0.0
var _shake_amount: float = 0.0
## Scarto d'orbita del mouse rispetto alla poppa (0 = dietro la barca):
## _orbit_yaw insegue con smorzamento _target_orbit_yaw, mosso dal mouse.
var _orbit_yaw: float = 0.0
var _target_orbit_yaw: float = 0.0
## Beccheggio della camera; a riposo vale _base_pitch. Anche qui il mouse
## muove il bersaglio e la camera ci arriva morbida.
var _pitch: float = 0.0
var _target_pitch: float = 0.0
var _base_pitch: float = 0.0
var _radius: float = 1.0
var _idle_time: float = 1000.0


func _ready() -> void:
	# ALWAYS: in pausa la camera deve comunque sapere del focus UI (il
	# mouse va liberato anche a scena ferma).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_radius = Vector2(distance, height).length()
	_base_pitch = atan2(height, distance)
	_pitch = _base_pitch
	_target_pitch = _base_pitch
	GameState.ui_focus_changed.connect(_on_ui_focus_changed)
	GameState.boat_hit.connect(_on_boat_hit)
	_on_ui_focus_changed.call_deferred(GameState.ui_focus_open())
	if target == null:
		return
	_yaw = target.global_rotation.y
	global_position = _desired_position()
	_look()


func _physics_process(delta: float) -> void:
	if target == null or get_tree().paused:
		return
	_idle_time += delta
	_yaw = lerp_angle(_yaw, target.global_rotation.y, 1.0 - exp(-yaw_smoothing * delta))
	# Passato il tempo di inattività, il bersaglio d'orbita torna dietro
	# la poppa; il resto del tempo resta dove il mouse l'ha lasciato.
	if _idle_time >= orbit_return_delay:
		var t_return := 1.0 - exp(-orbit_return_smoothing * delta)
		_target_orbit_yaw = lerp_angle(_target_orbit_yaw, 0.0, t_return)
		_target_pitch = lerpf(_target_pitch, _base_pitch, t_return)
	# La camera insegue il bersaglio con smorzamento: niente scatti
	# pixel-per-pixel del mouse, il movimento resta morbido e un filo
	# ritardato (meno mal di testa).
	var t_orbit := 1.0 - exp(-orbit_smoothing * delta)
	_orbit_yaw = lerp_angle(_orbit_yaw, _target_orbit_yaw, t_orbit)
	_pitch = lerpf(_pitch, _target_pitch, t_orbit)
	var t := 1.0 - exp(-position_smoothing * delta)
	global_position = global_position.lerp(_desired_position(), t)
	if _shake_time > 0.0:
		_shake_time -= delta
		# Decadimento quadratico (trauma²): scuote forte all'inizio e si
		# spegne morbido, senza sobbalzi a fine effetto.
		var trauma := _shake_amount * maxf(_shake_time / shake_duration, 0.0)
		var mag := shake_max_offset * trauma * trauma
		global_position += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)) * mag
	_look()


## Focus della finestra: uscendo (Cmd-Tab, click su un'altra app o sul
## desktop) il mouse si libera — così in modalità finestra si può afferrare
## il bordo e ridimensionare. Rientrando si ricattura, ma solo se si sta
## davvero guidando (nessun pannello aperto, gioco non in pausa): in pausa o
## coi menu il cursore resta libero come già fa ui_focus_changed.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		if is_inside_tree() and not GameState.ui_focus_open() and not get_tree().paused:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Urto della barca: avvia lo scuotimento, con intensità sulla forza.
func _on_boat_hit(force: float) -> void:
	_shake_amount = clampf(force / shake_force_ref, 0.0, 1.0)
	_shake_time = shake_duration


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion == null or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	_idle_time = 0.0
	# Sensibilità di design (@export, da tarare) × preferenza del giocatore
	# (slider impostazioni, salvata dall'Audio autoload).
	var sens := deg_to_rad(mouse_sensitivity) * Audio.mouse_sensitivity_scale
	_target_orbit_yaw -= motion.relative.x * sens
	_target_pitch = clampf(_target_pitch + motion.relative.y * sens,
		deg_to_rad(pitch_min_deg), deg_to_rad(pitch_max_deg))


## Un pannello si è aperto/chiuso: mouse libero coi menu, catturato in
## guida. All'apertura l'orbita si azzera: alla chiusura si riparte
## sempre da dietro la poppa.
func _on_ui_focus_changed(open: bool) -> void:
	if open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_orbit_yaw = 0.0
		_target_orbit_yaw = 0.0
		_pitch = _base_pitch
		_target_pitch = _base_pitch
		_idle_time = orbit_return_delay
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _desired_position() -> Vector3:
	var yaw := _yaw + _orbit_yaw
	var dir := Vector3(sin(yaw) * cos(_pitch), sin(_pitch), cos(yaw) * cos(_pitch))
	var pos := target.global_position + dir * _radius
	pos.y = maxf(pos.y, min_height)
	return pos


func _look() -> void:
	var yaw := _yaw + _orbit_yaw
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	look_at(target.global_position + forward * look_ahead + Vector3.UP * look_height)
