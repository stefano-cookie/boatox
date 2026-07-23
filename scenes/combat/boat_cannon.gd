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
	var aim := _aim_point()
	if not aim.is_finite():
		return
	# Il pezzo si allinea alla velocità di lancio: si vede l'alzo dell'arco.
	var muzzle := _muzzle_position()
	var launch := CannonBall.launch_velocity(muzzle, aim, definition.projectile_speed)
	if launch.length_squared() > 0.01:
		_pivot.look_at(_pivot.global_position + launch)
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


## Punto mirato: raycast dal centro della camera (le navi si colpiscono
## dove le vedi), altrimenti l'intersezione col piano dell'acqua; il tutto
## poi tagliato alla gittata. Vector3.INF senza camera o mirando al cielo.
func _aim_point() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3.INF
	var center := get_viewport().get_visible_rect().size * 0.5
	var origin := camera.project_ray_origin(center)
	var dir := camera.project_ray_normal(center)
	var aim := Vector3.INF
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * AIM_RAY_LENGTH)
	query.exclude = [boat.get_rid()]
	var hit := boat.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		aim = hit["position"]
	elif dir.y < -0.001:
		aim = origin + dir * (origin.y / -dir.y)
	else:
		# Mira sopra l'orizzonte: si spara comunque, alla gittata massima.
		var flat := Vector3(dir.x, 0.0, dir.z).normalized()
		aim = boat.global_position + flat * definition.fire_range
	# Oltre la gittata il colpo cade al limite: il mirino resta onesto.
	var muzzle := _muzzle_position()
	var offset := aim - muzzle
	offset.y = 0.0
	if offset.length() > definition.fire_range:
		aim = muzzle + offset.normalized() * definition.fire_range
		aim.y = 0.0
	return aim


func _muzzle_position() -> Vector3:
	return _pivot.global_position + -_pivot.global_transform.basis.z * 0.9


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
