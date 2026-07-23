class_name RaiderShip
extends Ship

## Predone (roadmap B1): pattuglia il mare aperto e, se il giocatore gli
## naviga nel raggio, lo punta — sperona a contatto e spara palle ad arco
## con l'anticipo sulla rotta. Molla la presa se il giocatore rientra
## nelle acque medie (i predoni non si avvicinano a costa: il porto resta
## un rifugio) o se lo semina.

enum State { PATROL, CHASE }

const CANNONBALL_SCENE: PackedScene = preload("res://scenes/combat/cannonball.tscn")

const WAYPOINT_RADIUS: float = 18.0
## Oltre aggro_radius × questo, l'inseguimento si spegne.
const GIVE_UP_MULT: float = 1.8
## Distanza di speronamento e secondi tra due speronate.
const RAM_DISTANCE: float = 5.5
const RAM_COOLDOWN: float = 2.5

## Il bersaglio (la barca del giocatore), assegnato dallo ShipDirector.
var target_boat: Boat

var _waypoints: Array[Vector3] = []
var _next: int = 0
var _state: State = State.PATROL
var _weapon: Weapon
var _ram_timer: float = 0.0


func set_route(waypoints: Array[Vector3]) -> void:
	_waypoints = waypoints
	_next = 0


func _ready() -> void:
	super()
	if definition.weapon != null:
		_weapon = Weapon.new()
		_weapon.definition = definition.weapon
		add_child(_weapon)


func _physics_process(delta: float) -> void:
	_ram_timer = maxf(_ram_timer - delta, 0.0)
	match _state:
		State.PATROL:
			if not _waypoints.is_empty() \
					and steer_towards(_waypoints[_next], delta, 0.55) <= WAYPOINT_RADIUS:
				_next = (_next + 1) % _waypoints.size()
			if _player_huntable() and _player_distance() <= definition.aggro_radius:
				_state = State.CHASE
		State.CHASE:
			if not _player_huntable() \
					or _player_distance() > definition.aggro_radius * GIVE_UP_MULT:
				_state = State.PATROL
				return
			var dist := steer_towards(target_boat.global_position, delta)
			_try_ram(dist)
			_try_fire(dist)


## Sparato addosso: il predone risponde puntando chi spara, ovunque sia.
func notify_attacked(_from: Vector3) -> void:
	if _player_huntable():
		_state = State.CHASE


## Il predone caccia solo oltre le acque medie: sotto costa non si
## avventura (il rientro è la via di fuga del giocatore).
func _player_huntable() -> bool:
	return target_boat != null and sea != null \
		and sea.shore_distance(target_boat.global_position) > sea.medium_width


func _player_distance() -> float:
	return global_position.distance_to(target_boat.global_position)


## Speronata a contatto: danno secco e feedback da urto (flash + shake),
## poi il predone perde abbrivio — niente frullatore.
func _try_ram(dist: float) -> void:
	if dist > RAM_DISTANCE or _ram_timer > 0.0:
		return
	_ram_timer = RAM_COOLDOWN
	target_boat.take_damage(definition.ram_damage)
	GameState.report_boat_hit(8.0)
	_speed *= 0.35


## Colpo con l'anticipo: mira dove la barca sarà quando la palla arriva.
func _try_fire(dist: float) -> void:
	if _weapon == null or dist > _weapon.definition.fire_range \
			or not _weapon.consume_cooldown():
		return
	var muzzle := global_position + Vector3.UP * (definition.collision_size.y + 0.6)
	var flight_time := dist / maxf(_weapon.definition.projectile_speed, 1.0)
	var lead := target_boat.velocity * flight_time
	var aim := target_boat.global_position + Vector3(lead.x, 0.0, lead.z)
	var ball := CANNONBALL_SCENE.instantiate() as CannonBall
	ball.shooter = self
	ball.shooter_faction = faction
	ball.damage = _weapon.definition.damage
	ball.velocity = CannonBall.launch_velocity(muzzle, aim, _weapon.definition.projectile_speed)
	ball.sea = sea
	get_parent().add_child(ball)
	ball.global_position = muzzle
	GameState.report_cannon_fired()


## Sagoma del predone: scafo scuro e affilato, cabina bassa, albero con
## vessillo rosso e un cannoncino in coperta — si riconosce come minaccia.
func _build_visual() -> void:
	var size := definition.collision_size
	var hull := MeshInstance3D.new()
	var hull_mesh := BoxMesh.new()
	hull_mesh.size = Vector3(size.x, size.y * 0.5, size.z * 0.75)
	hull.mesh = hull_mesh
	hull.material_override = Ship.flat(definition.hull_color)
	hull.position.y = size.y * 0.25
	_visual.add_child(hull)
	var bow := MeshInstance3D.new()
	var bow_mesh := PrismMesh.new()
	bow_mesh.size = Vector3(size.x, size.y * 0.5, size.z * 0.3)
	bow.mesh = bow_mesh
	bow.material_override = Ship.flat(definition.hull_color)
	bow.rotation.x = deg_to_rad(-90.0)
	bow.position = Vector3(0.0, size.y * 0.25, -size.z * 0.5)
	_visual.add_child(bow)
	var cabin := MeshInstance3D.new()
	var cabin_mesh := BoxMesh.new()
	cabin_mesh.size = Vector3(size.x * 0.6, size.y * 0.45, size.z * 0.2)
	cabin.mesh = cabin_mesh
	cabin.material_override = Ship.flat(definition.hull_color.lightened(0.15))
	cabin.position = Vector3(0.0, size.y * 0.7, size.z * 0.22)
	_visual.add_child(cabin)
	var gun := MeshInstance3D.new()
	var gun_mesh := CylinderMesh.new()
	gun_mesh.top_radius = 0.08
	gun_mesh.bottom_radius = 0.11
	gun_mesh.height = 0.8
	gun.mesh = gun_mesh
	gun.material_override = Ship.flat(Color(0.15, 0.15, 0.17))
	gun.rotation.x = deg_to_rad(-80.0)
	gun.position = Vector3(0.0, size.y * 0.65, -size.z * 0.18)
	_visual.add_child(gun)
	var mast := MeshInstance3D.new()
	var mast_mesh := BoxMesh.new()
	mast_mesh.size = Vector3(0.1, 2.4, 0.1)
	mast.mesh = mast_mesh
	mast.material_override = Ship.flat(Color(0.3, 0.25, 0.22))
	mast.position = Vector3(0.0, size.y * 0.5 + 1.2, size.z * 0.05)
	_visual.add_child(mast)
	var flag := MeshInstance3D.new()
	var flag_mesh := BoxMesh.new()
	flag_mesh.size = Vector3(0.05, 0.4, 0.7)
	flag.mesh = flag_mesh
	flag.material_override = Ship.flat(definition.accent_color)
	flag.position = Vector3(0.0, size.y * 0.5 + 2.2, size.z * 0.05 - 0.35)
	_visual.add_child(flag)
