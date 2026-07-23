class_name BoatCannon
extends Weapon

## Cannone del giocatore (roadmap B1): mira libera col mouse — il mirino
## sta al centro della camera orbitale, il pezzo si orienta verso il punto
## guardato e spara un CannonBall ad arco che ci ricade sopra (gittata
## permettendo). Montato dalla Boat quando il cannone è comprato
## (GameState.cannon_level); danno/gittata/cadenza dalla WeaponDefinition
## del livello corrente. Visuale costruita in codice, come gli accessori.

const CANNONBALL_SCENE: PackedScene = preload("res://scenes/combat/cannonball.tscn")
## Lunghezza del raycast di mira dalla camera.
const AIM_RAY_LENGTH: float = 400.0
## Rinculo del pezzo (m) e tempo di rientro.
const RECOIL: float = 0.22
const RECOIL_TIME: float = 0.25
## Passi d'iterazione dell'anticipo (tempo di volo → posizione futura):
## con velocità quasi costanti converge in 2-3 passi.
const LEAD_ITERATIONS: int = 3

## Sotto quest'anticipo (m) il pip di lead non si disegna: nave ferma o
## quasi, il marker basta. Da tarare giocando.
@export var lead_min_offset: float = 1.5

var boat: Boat

var _pivot: Node3D
var _barrel: Node3D
var _flash: CPUParticles3D
var _recoil_tween: Tween


func _ready() -> void:
	add_to_group(&"boat_cannon")
	_build_visual()


func _physics_process(_delta: float) -> void:
	if boat == null or definition == null:
		return
	var solved := _solve_aim()
	if solved.is_empty():
		return
	var aim: Vector3 = solved["point"]
	# 1) Oriento la bocca verso il bersaglio (alzo dell'arco visibile),
	#    calcolando l'alzo dal perno; il caso quasi verticale salta il look_at.
	var rough := CannonBall.launch_velocity(_pivot.global_position, aim, definition.projectile_speed)
	if rough.length_squared() > 0.01 and absf(rough.normalized().dot(Vector3.UP)) < 0.98:
		_pivot.look_at(_pivot.global_position + rough)
	# 2) La palla parte dalla bocca vera (dov'è il lampo) con l'alzo risolto
	#    da lì: mirino e proiettile condividono muzzle e traiettoria.
	var muzzle := _muzzle_position()
	var launch := CannonBall.launch_velocity(muzzle, aim, definition.projectile_speed)
	if _can_shoot() and Input.is_action_pressed(&"fire") and consume_cooldown():
		_shoot(muzzle, launch)


## Si spara solo in guida vera: mouse catturato (niente menu) e barca
## governabile.
func _can_shoot() -> bool:
	return boat.input_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
		and not get_tree().paused


func _shoot(muzzle: Vector3, launch: Vector3) -> void:
	var ball := CANNONBALL_SCENE.instantiate() as CannonBall
	ball.shooter = boat
	ball.shooter_faction = boat.faction
	ball.damage = definition.damage
	ball.velocity = launch
	ball.sea = boat.sea
	boat.get_parent().add_child(ball)
	ball.global_position = muzzle
	GameState.report_cannon_fired()
	_flash.restart()
	_flash.emitting = true
	# Rinculo: il tubo scatta indietro e rientra morbido.
	if _recoil_tween != null and _recoil_tween.is_valid():
		_recoil_tween.kill()
	_barrel.position.z = RECOIL
	_recoil_tween = create_tween()
	_recoil_tween.tween_property(_barrel, "position:z", 0.0, RECOIL_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Risolve la mira dal raggio del reticolo (ChaseCamera.aim_ray). Regola
## d'oro (stile World of Warships): si spara sempre verso un punto SU UNA
## SUPERFICIE, mai a mezz'aria. Ordine: 1) geometria colpita dal raggio —
## navi, coste, città, anche sopra l'orizzonte; 2) piano dell'acqua se punti
## in giù; 3) cielo vuoto → la mira satura al limite di gittata sull'acqua,
## lungo il rilevamento. Un punto oltre la gittata piana resta "puntato"
## (pointed: il reticolo lo segue, non si blocca mai) ma il colpo parte al
## limite e il mirino mostra entrambe le cose. Un punto alto e vicino fuori
## portata balistica si ingaggia col 45° di launch_velocity (il massimo
## possibile, mai verticale). Fallback al centro schermo senza ChaseCamera.
## Ritorna { point, pointed, target, muzzle, in_range } o vuoto senza camera.
func _solve_aim() -> Dictionary:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return {}
	var origin: Vector3
	var dir: Vector3
	var chase := camera as ChaseCamera
	if chase != null:
		var ray := chase.aim_ray()
		origin = ray["origin"]
		dir = ray["dir"]
	else:
		var center := get_viewport().get_visible_rect().size * 0.5
		origin = camera.project_ray_origin(center)
		dir = camera.project_ray_normal(center)
	var muzzle := _muzzle_position()
	# Dove PUNTI (l'ancora del reticolo): geometria colpita, acqua, o un
	# punto lontano lungo il raggio se davanti c'è solo cielo. Il puntatore
	# segue sempre il mouse: mai più bloccato all'orizzonte.
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * AIM_RAY_LENGTH)
	query.exclude = [boat.get_rid()]
	var hit := boat.get_world_3d().direct_space_state.intersect_ray(query)
	var pointed: Vector3
	var sky := false
	if not hit.is_empty():
		pointed = hit["position"]
	elif dir.y < -0.001:
		pointed = origin + dir * (origin.y / -dir.y)
	else:
		pointed = origin + dir * AIM_RAY_LENGTH
		sky = true
	# Dove SPARI: il punto puntato se è una superficie in gittata; sennò il
	# punto al limite di gittata sull'acqua, sullo stesso rilevamento.
	var aim := pointed
	var offset := Vector3(aim.x - muzzle.x, 0.0, aim.z - muzzle.z)
	var flat_dist := offset.length()
	var bearing := offset / flat_dist if flat_dist > 0.01 \
		else Vector3(dir.x, 0.0, dir.z).normalized()
	if bearing.is_zero_approx():
		# Mira a piombo (mai coi limiti di pitch attuali, ma difendiamoci):
		# si tiene la prua della barca.
		bearing = Vector3(-sin(boat.global_rotation.y), 0.0, -cos(boat.global_rotation.y))
	var in_flat_range := not sky and flat_dist <= definition.fire_range
	var reachable := CannonBall.can_reach(muzzle, aim, definition.projectile_speed)
	if not in_flat_range:
		# Cielo vuoto o superficie oltre gittata: il colpo parte al limite.
		# Niente più punti a mezz'aria (il lob verticale nasceva da lì) e
		# niente y=0 forzato sui bersagli in quota raggiungibili.
		aim = muzzle + bearing * definition.fire_range
		aim.y = 0.0
	return {
		"point": aim,
		"pointed": pointed,
		"target": hit.get("collider"),
		"muzzle": muzzle,
		"in_range": in_flat_range and reachable,
	}


## Anticipo sul bersaglio mobile: se il reticolo punta una nave, stima il
## punto dove palla e nave s'incontrano (itera tempo di volo → posizione
## futura) e lo ritorna per il pip del mirino. È solo un'indicazione: il
## colpo parte dove punti, l'anticipo resta un gesto del giocatore (niente
## auto-mira). Null se non punti una nave nemica in gittata, se è ferma o
## se l'anticipo è sotto lead_min_offset.
func lead_point(solved: Dictionary) -> Variant:
	var in_range: bool = solved["in_range"]
	var vessel := solved.get("target") as Vessel
	if vessel == null or not in_range or vessel.faction == boat.faction:
		return null
	var vel := vessel.velocity
	vel.y = 0.0
	if vel.length_squared() < 0.25:
		return null
	var muzzle: Vector3 = solved["muzzle"]
	var aim: Vector3 = solved["point"]
	var future := aim
	for i: int in range(LEAD_ITERATIONS):
		var launch := CannonBall.launch_velocity(muzzle, future, definition.projectile_speed)
		var flat_speed := Vector2(launch.x, launch.z).length()
		var flat_dist := Vector2(future.x - muzzle.x, future.z - muzzle.z).length()
		var t := flat_dist / maxf(flat_speed, 1.0)
		future = aim + vel * t
	if future.distance_to(aim) < lead_min_offset:
		return null
	return future


## Dati per il mirino (roadmap R1): simula la parabola vera dal muzzle e
## ritorna il punto di caduta reale (il marker è veritiero), più l'ancora
## puntata, l'eventuale anticipo e lo stato del pezzo.
## Ritorna { point, pointed, lead, in_range, ready } o vuoto.
func predicted_impact() -> Dictionary:
	if boat == null or definition == null:
		return {}
	var solved := _solve_aim()
	if solved.is_empty():
		return {}
	var muzzle: Vector3 = solved["muzzle"]
	var aim: Vector3 = solved["point"]
	var launch := CannonBall.launch_velocity(muzzle, aim, definition.projectile_speed)
	return {
		"point": _simulate_impact(muzzle, launch),
		"pointed": solved["pointed"],
		"lead": lead_point(solved),
		"in_range": solved["in_range"],
		"ready": cooldown_fraction() <= 0.0,
	}


## Integra la balistica del CannonBall finché il colpo tocca un corpo (nave,
## isola, costa) o ricade in acqua: quel primo contatto è l'impatto. Stesso
## ordine d'integrazione della palla (velocità prima, poi posizione: Euler
## semi-implicito) così marker e proiettile coincidono.
func _simulate_impact(from: Vector3, launch: Vector3) -> Vector3:
	var space := boat.get_world_3d().direct_space_state
	var pos := from
	var vel := launch
	# Passo un po' più grosso del fisico (1/60) per non fare troppi raycast:
	# a parità d'ordine lo scarto sul punto d'impatto resta sotto il metro.
	var dt := 1.0 / 30.0
	var elapsed := 0.0
	while elapsed < CannonBall.MAX_LIFETIME:
		vel.y -= CannonBall.GRAVITY * dt
		var next := pos + vel * dt
		# Ostacolo lungo il tratto (stessa selezione del CannonBall: i corpi,
		# non le Area dei pickup): il mirino lo mostra come punto di caduta.
		var query := PhysicsRayQueryParameters3D.create(pos, next)
		query.exclude = [boat.get_rid()]
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			return hit["position"]
		# Ricaduta in acqua (quota d'onda vera se c'è la Sea).
		var water_y := boat.sea.get_height(next) if boat.sea != null else 0.0
		if vel.y < 0.0 and next.y <= water_y:
			return Vector3(next.x, water_y, next.z)
		pos = next
		elapsed += dt
	return pos


## La bocca vera: la posizione del lampo (in punta al tubo), così la palla
## parte esattamente da dove la vedi sparare e il mirino simula da lì.
func _muzzle_position() -> Vector3:
	return _flash.global_position


## Pezzo low-poly: basamento, perno e tubo. Il perno ruota per mirare,
## il tubo rincula sparando.
func _build_visual() -> void:
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.28
	base_mesh.bottom_radius = 0.34
	base_mesh.height = 0.22
	base.mesh = base_mesh
	base.material_override = _metal(Color(0.35, 0.33, 0.3))
	base.position.y = 0.11
	add_child(base)
	_pivot = Node3D.new()
	_pivot.position.y = 0.3
	add_child(_pivot)
	_barrel = Node3D.new()
	_pivot.add_child(_barrel)
	var tube := MeshInstance3D.new()
	var tube_mesh := CylinderMesh.new()
	tube_mesh.top_radius = 0.09
	tube_mesh.bottom_radius = 0.13
	tube_mesh.height = 0.95
	tube.mesh = tube_mesh
	tube.material_override = _metal(Color(0.2, 0.2, 0.23))
	tube.rotation.x = deg_to_rad(-90.0)
	tube.position.z = -0.35
	_barrel.add_child(tube)
	_flash = CPUParticles3D.new()
	_flash.emitting = false
	_flash.one_shot = true
	_flash.amount = 12
	_flash.lifetime = 0.25
	_flash.explosiveness = 1.0
	_flash.direction = Vector3(0, 0, -1)
	_flash.spread = 25.0
	_flash.initial_velocity_min = 5.0
	_flash.initial_velocity_max = 9.0
	_flash.gravity = Vector3.ZERO
	_flash.scale_amount_min = 0.1
	_flash.scale_amount_max = 0.25
	_flash.color = Color(1.0, 0.85, 0.4, 0.9)
	_flash.position.z = -0.9
	_barrel.add_child(_flash)


static func _metal(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	mat.metallic = 0.3
	return mat
