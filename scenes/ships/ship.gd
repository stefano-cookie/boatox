class_name Ship
extends Vessel

## Base delle navi IA del mare aperto (roadmap B1): mercantili e predoni
## condividono guida cinematica (come AIRacer, ma solide: hanno una
## collision shape), punti scafo in un Damageable, barra salute leggibile,
## affondamento con bottino galleggiante. I parametri vivono nella
## ShipDefinition (.tres); il comportamento nei figli (MerchantShip,
## RaiderShip).

signal sunk(ship: Ship)

const LOOT_SCENE: PackedScene = preload("res://scenes/ships/loot_crate.tscn")

const ACCELERATION: float = 3.0
## Tetto di velocità in virata stretta, come le IA della regata.
const TURN_SLOW: float = 0.6
## Secondi della sequenza di affondamento.
const SINK_TIME: float = 2.2

@export var definition: ShipDefinition

## Recinto di navigazione (x/z), impostato dallo ShipDirector: rotte e
## fughe non escono mai dai confini della baia.
var roam_min := Vector3(-350.0, 0.0, 100.0)
var roam_max := Vector3(350.0, 0.0, 600.0)

var _damageable: Damageable
var _sinking: bool = false
var _lean: float = 0.0

@onready var _visual: Node3D = $Visual
@onready var _collision: CollisionShape3D = $CollisionShape3D

var _bar_root: Node3D
var _bar_fill: MeshInstance3D
var _bar_width: float = 2.2


func _ready() -> void:
	add_to_group(&"ships")
	faction = definition.faction
	max_speed = definition.max_speed
	stability = definition.stability
	var shape := BoxShape3D.new()
	shape.size = definition.collision_size
	_collision.shape = shape
	_collision.position.y = definition.collision_size.y * 0.35
	_damageable = Damageable.new()
	_damageable.max_hp = definition.hp
	add_child(_damageable)
	_damageable.damaged.connect(_on_damaged)
	_damageable.destroyed.connect(_start_sinking)
	_build_visual()
	_build_health_bar()


func _process(_delta: float) -> void:
	# Galleggiamento e assetto: l'acqua decide la quota, la virata il rollio.
	if sea != null and not _sinking:
		_visual.position.y = sea.get_height(global_position)
	_visual.rotation.z = _lean
	# La barra salute guarda sempre la camera (billboard).
	if _bar_root.visible:
		var camera := get_viewport().get_camera_3d()
		if camera != null:
			_bar_root.look_at(camera.global_position)


## Punto d'ingresso uniforme dei colpi (Weapon/CannonBall non sanno chi
## hanno davanti): tutto passa dal Damageable.
func take_damage(amount: float) -> void:
	if _sinking:
		return
	_damageable.take_damage(amount)


func is_sinking() -> bool:
	return _sinking


func hp_ratio() -> float:
	if _damageable == null or _damageable.max_hp <= 0.0:
		return 1.0
	return _damageable.hp / _damageable.max_hp


## Avvisa la nave che qualcuno le ha sparato da `from`: i figli reagiscono
## (il mercantile fugge, il predone si volta). Chiamato da chi colpisce.
func notify_attacked(_from: Vector3) -> void:
	pass


## Vira verso il punto e avanza; torna la distanza planare residua.
## speed_scale scala il tetto (fuga > 1, lavoro < 1); il mare grosso frena
## con le stesse soglie del giocatore (Vessel).
func steer_towards(target: Vector3, delta: float, speed_scale: float = 1.0) -> float:
	var to := target - global_position
	to.y = 0.0
	var target_angle := atan2(-to.x, -to.z)
	var diff := angle_difference(rotation.y, target_angle)
	var max_step := deg_to_rad(definition.turn_speed_deg) * delta
	rotation.y += clampf(diff, -max_step, max_step)
	var cap := max_speed * speed_scale * (1.0 - rough_slow_max * chaos01())
	if absf(diff) > 0.7:
		cap *= TURN_SLOW
	_speed = move_toward(_speed, cap, ACCELERATION * delta)
	global_position += -global_transform.basis.z * _speed * delta
	global_position.y = 0.0
	_lean = lerpf(_lean, clampf(-diff * 0.5, -0.2, 0.2), 1.0 - exp(-5.0 * delta))
	return to.length()


## Tiene un punto dentro il recinto di navigazione.
func clamp_to_roam(point: Vector3) -> Vector3:
	return Vector3(clampf(point.x, roam_min.x, roam_max.x), 0.0,
		clampf(point.z, roam_min.z, roam_max.z))


func _on_damaged(_amount: float, _hp: float) -> void:
	_bar_root.visible = true
	_update_health_bar()
	# Colpo incassato: la nave accusa con uno scrollone di rollio.
	_lean += 0.12 if randf() > 0.5 else -0.12


## Affondamento: collisione via, prua giù, bottino a galla dove il mare
## decide il valore (fascia di zona, GDD pillar 2), poi la nave sparisce.
func _start_sinking() -> void:
	if _sinking:
		return
	_sinking = true
	_bar_root.visible = false
	_collision.set_deferred("disabled", true)
	set_physics_process(false)
	_drop_loot()
	GameState.report_ship_sunk(global_position)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_visual, "position:y", -definition.collision_size.y * 2.2, SINK_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_visual, "rotation:x", deg_to_rad(-14.0), SINK_TIME)
	tween.set_parallel(false)
	tween.tween_callback(_finish_sinking)


func _finish_sinking() -> void:
	sunk.emit(self)
	queue_free()


func _drop_loot() -> void:
	var tier := sea.zone_index(global_position) if sea != null else 2
	# Ricompensa per acque difficili (roadmap R3): più casse quando la preda
	# affonda lontano da costa e col mare grosso — sempre almeno il minimo.
	var base_count := randi_range(definition.loot_min, definition.loot_max)
	var count := maxi(definition.loot_min,
		roundi(base_count * GameState.difficulty_multiplier(global_position, sea)))
	for i in count:
		var crate := LOOT_SCENE.instantiate() as LootCrate
		crate.tier = tier
		crate.sea = sea
		get_parent().add_child(crate)
		var angle := randf_range(0.0, TAU)
		crate.global_position = global_position \
			+ Vector3(cos(angle), 0.0, sin(angle)) * randf_range(2.0, 6.0)


## Sagoma della nave: la costruiscono i figli, coi colori della definizione.
func _build_visual() -> void:
	pass


## Barra salute sopra la nave: fondo scuro + riempimento che scala e
## cambia colore con lo scafo. Nascosta finché la nave è integra.
func _build_health_bar() -> void:
	_bar_root = Node3D.new()
	_bar_root.position.y = definition.collision_size.y + 2.6
	_bar_root.visible = false
	add_child(_bar_root)
	var back := MeshInstance3D.new()
	var back_mesh := BoxMesh.new()
	back_mesh.size = Vector3(_bar_width + 0.12, 0.3, 0.02)
	back.mesh = back_mesh
	back.material_override = _bar_material(Color(0.08, 0.08, 0.1, 0.85))
	_bar_root.add_child(back)
	_bar_fill = MeshInstance3D.new()
	var fill_mesh := BoxMesh.new()
	fill_mesh.size = Vector3(_bar_width, 0.2, 0.03)
	_bar_fill.mesh = fill_mesh
	_bar_fill.material_override = _bar_material(Color(0.5, 0.9, 0.5))
	_bar_root.add_child(_bar_fill)


func _update_health_bar() -> void:
	var ratio := hp_ratio()
	_bar_fill.scale.x = maxf(ratio, 0.01)
	_bar_fill.position.x = -_bar_width * 0.5 * (1.0 - ratio)
	var mat := _bar_fill.material_override as StandardMaterial3D
	mat.albedo_color = Color(0.55, 0.9, 0.5).lerp(Color(0.95, 0.35, 0.3), 1.0 - ratio)


static func _bar_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	return mat


## Materiale piatto per le sagome low-poly (come la flottiglia di B2).
static func flat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	return mat
