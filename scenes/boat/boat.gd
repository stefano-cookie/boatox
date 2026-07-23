class_name Boat
extends Vessel

## Guida arcade (GDD § Navigazione): accelerazione, virata dipendente
## dalla velocità, deriva leggera. Il corpo resta a y = 0 e si muove sul
## piano XZ; il nodo Visual fa beccheggio, rollio e galleggiamento
## leggendo l'altezza dell'acqua dalla Sea. I parametri di guida non
## sono più @export: arrivano dalla BoatDefinition corrente (ogni barca
## ha la sua guida), qui restano solo i valori da tarare a mano.
## Fazione, mare e lettura del caos vivono nella base Vessel (B0).

@export_group("Carburante")
## Velocità massima a serbatoio vuoto (motorino elettrico di riserva):
## si torna a casa piano, senza consumare.
@export var reserve_speed: float = 3.0

@export_group("Danni")
## Sotto questa velocità d'impatto l'urto non danneggia (sfregare non punisce).
@export var min_impact_speed: float = 3.0
@export var damage_per_speed: float = 4.0
@export var impact_cooldown: float = 0.6

@export_group("Mare agitato (guida)")
## Soglie e freno del mare grosso: nella base Vessel (condivise con le IA).
## Sbandata del timone a caos pieno e stabilità zero.
@export var chaos_turn_deg: float = 55.0
## Spinta laterale delle onde a caos pieno (m/s²).
@export var chaos_push: float = 7.0

@export_group("Tempesta (danni)")
## Agitazione oltre cui il mare picchia lo scafo (solo largo + tempesta).
@export var storm_damage_threshold: float = 3.4
## Quanta agitazione oltre la soglia serve per il danno pieno.
@export var storm_damage_range: float = 1.6
## Danni al secondo a intensità piena e stabilità zero.
@export var storm_damage_per_second: float = 5.0
## Intervallo tra i tick di danno (la barra scafo scende a scatti visibili).
@export var storm_tick: float = 0.8

@export_group("Affondamento (fuori zona)")
## Quanto scende il visivo quando sink_amount arriva a 1.
@export var sink_depth: float = 0.9
@export var sink_pitch_deg: float = 6.0

@export_group("Assetto (visuale)")
@export var bank_max_deg: float = 10.0
@export var accel_pitch_deg: float = 3.0
@export var attitude_smoothing: float = 5.0
@export var bob_smoothing: float = 8.0
## Quanto la stabilità piena smorza beccheggio e rollio da onda.
@export_range(0.0, 1.0) var stability_damping: float = 0.5

var input_enabled: bool = true
## Cap esterno alla velocità massima (m/s), impostato dal Port in
## avvicinamento: più vicino all'attracco, più basso — frenata assistita
## naturale (feedback playtest round 2). INF = nessun limite.
var approach_speed_cap: float = INF
## 0..1, impostato dal World fuori dai confini: la barca si abbassa
## nell'acqua e appruata, senza toccare la guida (deve restare facile
## rientrare).
var sink_amount: float = 0.0
## Beccheggio extra (radianti) imposto dal duello di pesca: la barca
## si inclina verso il pesce che tira. Solo visuale.
var fight_pitch: float = 0.0

# Guida corrente, copiata dalla BoatDefinition in _apply_definition
# (max_speed e stability vivono nella base Vessel).
var _max_reverse_speed: float = 4.0
var _acceleration: float = 5.0
var _reverse_acceleration: float = 3.0
var _brake_force: float = 8.0
var _water_drag: float = 2.0
var _turn_speed_deg: float = 60.0
var _turn_full_speed_ratio: float = 0.35
var _grip: float = 2.5
var _fuel_per_second: float = 0.1

var _impact_timer: float = 0.0
var _chaos_time: float = 0.0
## Caos corrente 0..1 (agitazione oltre soglia × instabilità): guida
## sbandata, spinta delle onde e rallentamento.
var _chaos: float = 0.0
## Intensità 0..1 della tempesta che danneggia lo scafo.
var _storm_intensity: float = 0.0
var _storm_accum: float = 0.0

var _sample_bow := Vector3(0.0, 0.0, -1.9)
var _sample_stern := Vector3(0.0, 0.0, 1.9)
var _sample_left := Vector3(-0.9, 0.0, 0.0)
var _sample_right := Vector3(0.9, 0.0, 0.0)

@onready var _visual: Node3D = $Visual
@onready var _collision: CollisionShape3D = $CollisionShape3D

## Spruzzo d'acqua all'urto (feedback playtest round 2): creato in codice
## per non toccare la scena, piazzato al punto d'impatto e fatto ripartire.
var _splash: CPUParticles3D
## Cannone di bordo (roadmap B1), montato sul Visual quando è comprato:
## segue beccheggio e rollio come il resto della coperta.
var _cannon: BoatCannon


func _ready() -> void:
	GameState.boat_changed.connect(func(_def: BoatDefinition) -> void: _apply_definition())
	# Vernice o accessori cambiati (cantiere, anteprima inclusa): si
	# rimonta il modello da zero, così togliere una vernice è gratis.
	GameState.customization_changed.connect(_apply_definition)
	GameState.cannon_changed.connect(_mount_cannon)
	_build_splash()
	_apply_definition()


func _physics_process(delta: float) -> void:
	_impact_timer = maxf(_impact_timer - delta, 0.0)
	var throttle := 0.0
	var steer := 0.0
	if input_enabled:
		throttle = Input.get_axis("move_back", "move_forward")
		steer = Input.get_axis("turn_right", "turn_left")
	if throttle != 0.0 and GameState.fuel > 0.0:
		GameState.consume_fuel(_fuel_per_second * absf(throttle) * delta)
	_update_sea_stress(delta)
	_update_speed(throttle, delta)
	_update_heading(steer, delta)
	_apply_chaos(delta)
	_update_velocity(delta)
	var pre_impact_velocity := velocity
	move_and_slide()
	global_position.y = 0.0
	_handle_impacts(pre_impact_velocity)
	_update_attitude(throttle, steer, delta)
	_update_audio(throttle)


## Regime motore e volume del mare all'Audio autoload (loop continui pilotati
## da qui: la barca è l'unica a conoscere velocità, gas e agitazione locale).
func _update_audio(throttle: float) -> void:
	var speed01 := clampf(absf(_speed) / maxf(max_speed, 0.01), 0.0, 1.0)
	var drive := throttle if input_enabled else 0.0
	Audio.update_engine(speed01, drive)
	if sea != null:
		Audio.update_sea(sea.agitation(global_position))


## Vero quando il mare sta danneggiando lo scafo: il World lo usa per
## l'allarme a schermo.
func storm_alarm() -> bool:
	return _storm_intensity > 0.0


## Lo scafo del giocatore vive in GameState (per-barca, con upgrade):
## ogni danno — urti, tempesta, e in B1 i colpi delle armi — passa da qui.
func take_damage(amount: float) -> void:
	GameState.apply_damage(amount)


func reset_motion() -> void:
	_speed = 0.0
	velocity = Vector3.ZERO


## Copia guida e dimensioni dalla barca corrente (upgrade inclusi) e
## monta il suo modello sotto Visual.
func _apply_definition() -> void:
	var def := GameState.current_def()
	max_speed = GameState.effective_max_speed()
	_acceleration = GameState.effective_acceleration()
	stability = GameState.effective_stability()
	_max_reverse_speed = def.max_reverse_speed
	_reverse_acceleration = def.reverse_acceleration
	_brake_force = def.brake_force
	_water_drag = def.water_drag
	_turn_speed_deg = def.turn_speed_deg
	_turn_full_speed_ratio = def.turn_full_speed_ratio
	_grip = def.grip
	_fuel_per_second = def.fuel_per_second

	var shape := BoxShape3D.new()
	shape.size = def.collision_size
	_collision.shape = shape
	_collision.position.y = def.collision_size.y * 0.3
	var half_length := def.collision_size.z * 0.5
	_sample_bow = Vector3(0.0, 0.0, -(half_length - 0.8))
	_sample_stern = Vector3(0.0, 0.0, half_length - 0.8)
	_sample_left = Vector3(-def.collision_size.x * 0.5, 0.0, 0.0)
	_sample_right = Vector3(def.collision_size.x * 0.5, 0.0, 0.0)

	for child in _visual.get_children():
		child.queue_free()
	_cannon = null
	if def.visual_scene != null:
		var model := def.visual_scene.instantiate() as Node3D
		_visual.add_child(model)
		BoatCustomization.apply(model, def)
	_mount_cannon()


## (Ri)monta il cannone in coperta se è comprato: sul Visual, così ondeggia
## con la barca. Livello salito = definizione nuova, si ricrea da zero.
func _mount_cannon() -> void:
	if _cannon != null:
		_cannon.queue_free()
		_cannon = null
	if not GameState.cannon_owned():
		return
	var def := GameState.current_def()
	_cannon = BoatCannon.new()
	_cannon.boat = self
	_cannon.definition = GameState.cannon_def()
	_visual.add_child(_cannon)
	# In coperta, poco a poppavia del centro; quote da tarare guardando
	# i tre modelli (nota playtest B1).
	_cannon.position = Vector3(0.0, def.collision_size.y * 0.75, def.collision_size.z * 0.08)


## Agitazione del mare nel punto della barca, tradotta in caos (guida)
## e intensità di tempesta (danni). Il danno scatta solo oltre la soglia
## estrema — in pratica al largo col mare mosso — ed è mitigato dalla
## stabilità: è la seconda metà del cancello di progressione.
func _update_sea_stress(delta: float) -> void:
	_chaos = 0.0
	_storm_intensity = 0.0
	if sea == null:
		return
	var agitation := sea.agitation(global_position)
	_chaos = chaos01()
	_storm_intensity = clampf((agitation - storm_damage_threshold) / storm_damage_range, 0.0, 1.0)
	if _storm_intensity <= 0.0 or GameState.hull <= 0.0:
		_storm_accum = 0.0
		return
	_storm_accum += delta
	if _storm_accum >= storm_tick:
		_storm_accum -= storm_tick
		take_damage(storm_damage_per_second * _storm_intensity \
			* (1.0 - 0.75 * stability) * storm_tick)


func _update_speed(throttle: float, delta: float) -> void:
	# Il mare grosso frena: la velocità massima raggiungibile cala col
	# caos, e se eri lanciato il mare ti rallenta lui. A serbatoio vuoto
	# comanda la riserva d'emergenza.
	var cap := max_speed * (1.0 - rough_slow_max * _chaos)
	if GameState.fuel <= 0.0:
		cap = minf(cap, reserve_speed)
	# In avvicinamento al porto il cap scende: se eri lanciato, il ramo
	# _speed > cap qui sotto frena da solo (arrivo naturale, non un muro).
	cap = minf(cap, approach_speed_cap)
	if _speed > cap:
		_speed = move_toward(_speed, cap, (_water_drag + _brake_force * 0.5) * delta)
	if throttle > 0.0:
		_speed = move_toward(_speed, minf(max_speed * throttle, cap), _acceleration * delta)
	elif throttle < 0.0:
		if _speed > 0.1:
			_speed = move_toward(_speed, 0.0, _brake_force * delta)
		else:
			_speed = move_toward(_speed, _max_reverse_speed * throttle, _reverse_acceleration * delta)
	else:
		_speed = move_toward(_speed, 0.0, _water_drag * delta)


func _update_heading(steer: float, delta: float) -> void:
	var reverse_sign := 1.0 if _speed >= 0.0 else -1.0
	rotation.y += steer * deg_to_rad(_turn_speed_deg) * _turn_factor() * reverse_sign * delta


## Il mare agitato destabilizza (GDD § Navigazione): oltre la soglia di
## agitazione il timone sbanda e le onde spingono verso costa, in
## proporzione a quanto manca alla stabilità piena. Con la barchetta il
## largo in tempesta è quasi ingovernabile: è il cancello di progressione.
func _apply_chaos(delta: float) -> void:
	if sea == null or _chaos <= 0.0:
		return
	_chaos_time += delta
	var wobble := sin(_chaos_time * 2.1) + 0.5 * sin(_chaos_time * 3.7 + 1.3)
	rotation.y += wobble * deg_to_rad(chaos_turn_deg) * _chaos * delta
	velocity += sea.wave_push_direction() * chaos_push * _chaos * delta


func _update_velocity(delta: float) -> void:
	var forward := -global_transform.basis.z
	var target_velocity := forward * _speed
	velocity = velocity.lerp(target_velocity, 1.0 - exp(-_grip * delta))
	velocity.y = 0.0


func _handle_impacts(pre_impact_velocity: Vector3) -> void:
	if _impact_timer > 0.0 or get_slide_collision_count() == 0:
		return
	var collision := get_slide_collision(0)
	var normal := collision.get_normal()
	var impact := -pre_impact_velocity.dot(normal)
	if impact <= min_impact_speed:
		return
	_impact_timer = impact_cooldown
	_speed *= 0.3
	take_damage((impact - min_impact_speed) * damage_per_speed)
	# Feedback percepibile: HUD (flash scafo) e camera (shake) via segnale,
	# spruzzo qui al punto di contatto, scalato sulla forza dell'urto.
	GameState.report_boat_hit(impact)
	_spawn_splash(collision.get_position(), impact)


func _build_splash() -> void:
	_splash = CPUParticles3D.new()
	_splash.emitting = false
	_splash.one_shot = true
	_splash.amount = 20
	_splash.lifetime = 0.6
	_splash.explosiveness = 0.9
	_splash.direction = Vector3.UP
	_splash.spread = 55.0
	_splash.initial_velocity_min = 3.0
	_splash.initial_velocity_max = 6.0
	_splash.gravity = Vector3(0.0, -9.0, 0.0)
	_splash.scale_amount_min = 0.12
	_splash.scale_amount_max = 0.25
	_splash.color = Color(0.8, 0.92, 1.0, 0.9)
	add_child(_splash)


## Spruzzo all'impatto: più particelle e più veloci quanto più forte l'urto.
func _spawn_splash(pos: Vector3, impact: float) -> void:
	var strength := clampf((impact - min_impact_speed) / max_speed, 0.15, 1.0)
	_splash.global_position = Vector3(pos.x, 0.2, pos.z)
	_splash.amount = roundi(lerpf(10.0, 30.0, strength))
	_splash.initial_velocity_max = lerpf(4.0, 8.0, strength)
	_splash.restart()
	_splash.emitting = true


func _turn_factor() -> float:
	return clampf(absf(_speed) / (max_speed * _turn_full_speed_ratio), 0.0, 1.0)


func _update_attitude(throttle: float, steer: float, delta: float) -> void:
	if sea == null:
		return
	var h_bow := sea.get_height(to_global(_sample_bow))
	var h_stern := sea.get_height(to_global(_sample_stern))
	var h_left := sea.get_height(to_global(_sample_left))
	var h_right := sea.get_height(to_global(_sample_right))

	var water_level := (h_bow + h_stern + h_left + h_right) / 4.0
	# La stabilità smorza la risposta alle onde: si vede oltre a sentirsi.
	var damp := 1.0 - stability_damping * stability
	var wave_pitch := atan2(h_bow - h_stern, _sample_stern.z - _sample_bow.z) * damp
	var wave_roll := atan2(h_right - h_left, _sample_right.x - _sample_left.x) * damp

	var target_pitch := wave_pitch + deg_to_rad(accel_pitch_deg) * throttle \
		+ deg_to_rad(sink_pitch_deg) * sink_amount + fight_pitch
	var target_roll := wave_roll + steer * deg_to_rad(bank_max_deg) * _turn_factor()

	var t_att := 1.0 - exp(-attitude_smoothing * delta)
	var t_bob := 1.0 - exp(-bob_smoothing * delta)
	_visual.rotation.x = lerp_angle(_visual.rotation.x, target_pitch, t_att)
	_visual.rotation.z = lerp_angle(_visual.rotation.z, target_roll, t_att)
	_visual.position.y = lerpf(_visual.position.y, water_level - sink_depth * sink_amount, t_bob)
