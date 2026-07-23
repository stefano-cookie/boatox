class_name ChaseCamera
extends Camera3D

## Terza persona stile GTA (GDD § Camera): resta dietro e sopra la barca,
## ruota con smorzamento verso la sua prua e guarda un punto davanti.
## In guida il mouse non tocca la visuale (niente strappi). Tenendo il tasto
## destro si entra in MIRA (reticolo libero stile navale): il mouse muove la
## direzione di mira (_aim_yaw/_aim_pitch), la camera la insegue in orizzontale
## ma resta alta, e mirando in su il reticolo sale sui bersagli alti (coste,
## città, navi). Il cannone e il mirino sparano lungo aim_ray(). Rilasciato il
## destro, tutto torna dietro la poppa. Il mouse è catturato durante la guida;
## i pannelli (porto, pesca, regata, pausa) lo liberano passando dal segnale
## GameState.ui_focus_changed. Tutti i parametri sono da tarare giocando.

@export var target: Node3D
@export var distance: float = 9.0
@export var height: float = 5.5
## Altezza del punto guardato sopra il bersaglio.
@export var look_height: float = 1.7
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
## Velocità dello smorzamento del ritorno dietro la poppa (a mira spenta).
@export var orbit_return_smoothing: float = 3.0
## La camera non scende mai sotto quest'altezza sull'acqua: tiene alta la
## vista anche orbitando di lato (senza, scende a pelo d'acqua).
@export var min_height: float = 4.5

@export_group("Modalità mira")
## Tenendo il tasto destro si entra in mira (reticolo libero stile navale):
## il mouse muove un reticolo che spara dove lo punti, la camera lo segue in
## orizzontale ma resta alta; rilasciato, tutto torna dietro la poppa.
## Decisione direttore 23/07/2026, rivista dopo playtest.
## Campo visivo in mira (più largo = più campo di battaglia).
@export var aim_fov: float = 84.0
## Quanto la camera arretra e si alza in mira (1 = come in guida).
@export var aim_zoom: float = 1.28
## Quanto in alto si può mirare (gradi sopra l'orizzonte): serve a colpire
## bersagli alti — coste, città, parti alte delle navi.
@export var aim_pitch_up_deg: float = 40.0
## Quanto in basso si può mirare (gradi sotto l'orizzonte): l'acqua vicina.
@export var aim_pitch_down_deg: float = 16.0
## Quanto la vista s'inclina in su seguendo la mira alta (m di rialzo del
## punto guardato per radiante): tiene il reticolo in quadro senza abbassare
## la camera. 0 = camera immobile e reticolo che sale libero.
@export var aim_view_gain: float = 7.0
## Velocità di entrata/uscita dalla modalità mira.
@export var aim_transition: float = 8.0

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
## Miscela 0..1 della modalità mira: 0 = vista di guida, 1 = mira piena.
## Interpola l'allargamento (FOV, arretramento) e libera l'orbita del mouse.
var _aim_blend: float = 0.0
## Campo visivo di guida, letto all'avvio; l'aim_fov ci si mescola sopra.
var _base_fov: float = 75.0
## Direzione di mira del reticolo, mossa dal mouse e slegata dal centro
## camera: _aim_yaw è lo scarto orizzontale dalla prua, _aim_pitch l'alzo
## (positivo = punti in alto). La camera li insegue in orbita ma resta alta;
## il cannone e il mirino sparano lungo questa direzione (aim_ray).
var _aim_yaw: float = 0.0
var _aim_pitch: float = 0.0


func _ready() -> void:
	# ALWAYS: in pausa la camera deve comunque sapere del focus UI (il
	# mouse va liberato anche a scena ferma).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_radius = Vector2(distance, height).length()
	_base_pitch = atan2(height, distance)
	_pitch = _base_pitch
	_target_pitch = _base_pitch
	_base_fov = fov
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
	# Modalità mira: attiva solo col tasto destro tenuto in guida vera.
	var aiming := _aiming()
	_aim_blend = move_toward(_aim_blend, 1.0 if aiming else 0.0, aim_transition * delta)
	_yaw = lerp_angle(_yaw, target.global_rotation.y, 1.0 - exp(-yaw_smoothing * delta))
	if aiming:
		# La camera segue la mira in orizzontale (pan verso il bersaglio) ma
		# la sua altezza resta quella di guida: mirare non abbassa mai la
		# vista. Il beccheggio del reticolo vive in _look, non nella camera.
		_target_orbit_yaw = _aim_yaw
		_target_pitch = _base_pitch
	else:
		# Fuori mira tutto torna dietro la poppa: navigare in avanti è vista
		# normale (feedback direttore). Anche la mira si riazzera.
		var t_return := 1.0 - exp(-orbit_return_smoothing * delta)
		_aim_yaw = lerp_angle(_aim_yaw, 0.0, t_return)
		_aim_pitch = lerpf(_aim_pitch, 0.0, t_return)
		_target_orbit_yaw = lerp_angle(_target_orbit_yaw, 0.0, t_return)
		_target_pitch = lerpf(_target_pitch, _base_pitch, t_return)
	# La camera insegue il bersaglio con smorzamento: niente scatti
	# pixel-per-pixel del mouse, il movimento resta morbido e un filo
	# ritardato (meno mal di testa).
	var t_orbit := 1.0 - exp(-orbit_smoothing * delta)
	_orbit_yaw = lerp_angle(_orbit_yaw, _target_orbit_yaw, t_orbit)
	_pitch = lerpf(_pitch, _target_pitch, t_orbit)
	# In mira la camera si allarga: campo visivo e distanza crescono con la
	# miscela, così la scena di battaglia si apre attorno al mirino.
	fov = lerpf(_base_fov, aim_fov, _aim_blend)
	_radius = Vector2(distance, height).length() * lerpf(1.0, aim_zoom, _aim_blend)
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


## In mira (tasto destro tenuto) solo durante la guida vera: col mouse
## catturato e nessun pannello aperto.
func _aiming() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
		and Input.is_action_pressed(&"camera_orbit")


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion == null or not _aiming():
		return
	# In mira il mouse muove il reticolo (direzione di mira), non la camera:
	# la camera lo insegue da sola. Fuori mira la visuale non si tocca.
	# Sensibilità di design (@export, da tarare) × preferenza del giocatore
	# (slider impostazioni, salvata dall'Audio autoload).
	var sens := deg_to_rad(mouse_sensitivity) * Audio.mouse_sensitivity_scale
	_aim_yaw -= motion.relative.x * sens
	# Mouse su = miri in alto (bersagli alti): _aim_pitch positivo.
	_aim_pitch = clampf(_aim_pitch - motion.relative.y * sens,
		-deg_to_rad(aim_pitch_down_deg), deg_to_rad(aim_pitch_up_deg))


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
		_aim_yaw = 0.0
		_aim_pitch = 0.0
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
	# Mirando in alto il punto guardato sale (aim_view_gain): la vista si
	# inclina in su per tenere in quadro il reticolo alto, senza spostare la
	# camera (che resta alta). Mira bassa/di guida: incorniciatura normale.
	var lh := look_height + maxf(_aim_pitch, 0.0) * aim_view_gain
	look_at(target.global_position + forward * look_ahead + Vector3.UP * lh)


## Raggio di mira del reticolo: origine sulla camera, direzione data da
## _aim_yaw/_aim_pitch (slegata dal centro schermo). Il cannone spara lungo
## questo raggio e il mirino ci disegna il marker → si colpisce dove punti,
## anche in alto sui bersagli fuori dall'acqua.
func aim_ray() -> Dictionary:
	return {"origin": global_position, "dir": _aim_world_dir()}


func _aim_world_dir() -> Vector3:
	var yaw := _yaw + _aim_yaw
	var cp := cos(_aim_pitch)
	return Vector3(-sin(yaw) * cp, sin(_aim_pitch), -cos(yaw) * cp)
