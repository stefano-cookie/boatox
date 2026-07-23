class_name MerchantShip
extends Ship

## Mercantile (roadmap B1): fa la spola lungo una rotta di waypoint e, se
## attaccato, molla la rotta e fugge dall'aggressore per un po' — è la
## preda: lenta ma capiente, il bottino migliore. La rotta gliela assegna
## lo ShipDirector.

enum State { SAIL, FLEE }

## Distanza a cui un waypoint si considera raggiunto.
const WAYPOINT_RADIUS: float = 16.0
## Quanto lontano punta la fuga a ogni colpo ricevuto.
const FLEE_DISTANCE: float = 150.0

var _waypoints: Array[Vector3] = []
var _next: int = 0
var _state: State = State.SAIL
var _flee_target := Vector3.ZERO
var _flee_left: float = 0.0


func set_route(waypoints: Array[Vector3]) -> void:
	_waypoints = waypoints
	_next = 0


func _physics_process(delta: float) -> void:
	if _waypoints.is_empty():
		return
	match _state:
		State.SAIL:
			if steer_towards(_waypoints[_next], delta) <= WAYPOINT_RADIUS:
				_next = (_next + 1) % _waypoints.size()
		State.FLEE:
			steer_towards(_flee_target, delta, definition.flee_speed_mult)
			_flee_left -= delta
			if _flee_left <= 0.0:
				_state = State.SAIL


## Colpito: scappa dritto dall'aggressore (ricalcolato a ogni colpo, così
## inseguirlo lo tiene in fuga), senza uscire dal recinto della baia.
func notify_attacked(from: Vector3) -> void:
	var away := global_position - from
	away.y = 0.0
	if away.length_squared() < 1.0:
		away = -global_transform.basis.z
	_flee_target = clamp_to_roam(global_position + away.normalized() * FLEE_DISTANCE)
	_flee_left = definition.flee_time
	_state = State.FLEE


## Sagoma del mercantile: scafo largo, prua a cuneo, plancia a poppa e
## casse colorate in coperta — la stazza si legge da lontano.
func _build_visual() -> void:
	var size := definition.collision_size
	var hull := MeshInstance3D.new()
	var hull_mesh := BoxMesh.new()
	hull_mesh.size = Vector3(size.x, size.y * 0.55, size.z * 0.78)
	hull.mesh = hull_mesh
	hull.material_override = Ship.flat(definition.hull_color)
	hull.position.y = size.y * 0.28
	_visual.add_child(hull)
	var bow := MeshInstance3D.new()
	var bow_mesh := PrismMesh.new()
	bow_mesh.size = Vector3(size.x, size.y * 0.55, size.z * 0.22)
	bow.mesh = bow_mesh
	bow.material_override = Ship.flat(definition.hull_color)
	bow.rotation.x = deg_to_rad(-90.0)
	bow.position = Vector3(0.0, size.y * 0.28, -size.z * 0.5)
	_visual.add_child(bow)
	var bridge := MeshInstance3D.new()
	var bridge_mesh := BoxMesh.new()
	bridge_mesh.size = Vector3(size.x * 0.7, size.y * 0.8, size.z * 0.16)
	bridge.mesh = bridge_mesh
	bridge.material_override = Ship.flat(Color(0.92, 0.9, 0.85))
	bridge.position = Vector3(0.0, size.y * 0.95, size.z * 0.3)
	_visual.add_child(bridge)
	var crate_colors: Array[Color] = [
		definition.accent_color,
		definition.accent_color.lightened(0.25),
		Color(0.75, 0.5, 0.3),
	]
	for i in 3:
		var crate := MeshInstance3D.new()
		var crate_mesh := BoxMesh.new()
		crate_mesh.size = Vector3(size.x * 0.55, size.y * 0.45, size.z * 0.14)
		crate.mesh = crate_mesh
		crate.material_override = Ship.flat(crate_colors[i])
		crate.position = Vector3(0.0, size.y * 0.78, -size.z * (0.28 - 0.17 * i))
		_visual.add_child(crate)
