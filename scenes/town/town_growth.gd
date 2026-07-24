extends Node3D

## La crescita visiva di Bova (roadmap B2): a ogni livello di prosperità
## il paese si trasforma — più case coi vetri accesi, barche ormeggiate
## che dondolano, gente e file di luci sul lungomare, il campanile che si
## veste d'oro. Tutto procedurale con seed fisso, nello stesso stile
## della Coast: si distingue a colpo d'occhio una Bova povera da una
## ricca (criterio di uscita B2). Figlio del World, si ricostruisce su
## Town.prosperity_changed.

@export var growth_seed: int = 21
## Linea di costa: deve coincidere con shore_z di Sea e Coast.
@export var shore_z: float = -140.0

var _rng := RandomNumberGenerator.new()
var _level_built: int = -1
## Barche ormeggiate che dondolano sull'acqua (aggiornate in _process).
var _moored: Array[Node3D] = []
var _sea: Sea = null

var _mat_wall := _flat_material(Color(0.93, 0.91, 0.86))
var _mat_roof := _flat_material(Color(0.72, 0.36, 0.24))
var _mat_wood := _flat_material(Color(0.55, 0.4, 0.26))
var _mat_skin := _flat_material(Color(0.83, 0.62, 0.46))
var _mat_pants := _flat_material(Color(0.24, 0.28, 0.36))
var _mat_gold: StandardMaterial3D = _glow_material(Color(0.95, 0.78, 0.3), 0.6)
var _mat_window: StandardMaterial3D = _glow_material(Color(1.0, 0.85, 0.5), 1.4)
var _mat_bulb: StandardMaterial3D = _glow_material(Color(1.0, 0.9, 0.6), 2.0)


func _ready() -> void:
	Town.prosperity_changed.connect(func(_level: int) -> void: _rebuild())
	# town_changed copre anche l'azzeramento partita (il livello torna 0).
	Town.town_changed.connect(_rebuild)
	_rebuild()


## Il dondolio delle barche ormeggiate: seguono l'acqua come le boe.
func _process(_delta: float) -> void:
	if _moored.is_empty():
		return
	if _sea == null:
		var world := get_parent() as World
		if world == null or world.sea == null:
			return
		_sea = world.sea
	for boat in _moored:
		boat.position.y = _sea.get_height(boat.global_position)


## Ricostruisce solo al cambio di livello: town_changed arriva anche per
## vendite e tick, non serve rifare le mesh.
func _rebuild() -> void:
	var level := Town.prosperity_level()
	if level == _level_built:
		return
	_level_built = level
	for child in get_children():
		child.queue_free()
	_moored.clear()
	_rng.seed = growth_seed
	if level >= 1:
		_add_houses(6)
	if level >= 2:
		_add_moored_boats(3)
	if level >= 3:
		_add_villagers(5)
		_add_string_lights()
	if level >= 4:
		_add_houses(5)
		_add_moored_boats(2)
		_gild_bell_tower()


## Case nuove ai margini del paese, coi vetri accesi di caldo: la
## ricchezza si vede dalle finestre.
func _add_houses(count: int) -> void:
	for i in count:
		var w := _rng.randf_range(3.0, 5.0)
		var h := _rng.randf_range(2.6, 4.2)
		var d := _rng.randf_range(3.0, 5.0)
		var pos := Vector3(_rng.randf_range(-85.0, 175.0),
			1.2 + h * 0.5, shore_z + _rng.randf_range(-68.0, -28.0))
		var house := _add_box(Vector3(w, h, d), pos, _mat_wall)
		house.rotation.y = deg_to_rad(_rng.randf_range(-12.0, 12.0))
		var roof := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(w + 0.5, 1.3, d + 0.5)
		roof.mesh = prism
		roof.material_override = _mat_roof
		roof.position = Vector3(0.0, h * 0.5 + 0.65, 0.0)
		house.add_child(roof)
		# A piedi non si passa attraverso le case nuove (roadmap R7):
		# collider layer 2, invisibile alle barche.
		var body := StaticBody3D.new()
		body.collision_layer = 2
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(w, h, d)
		shape.shape = box
		body.add_child(shape)
		house.add_child(body)
		# Due finestre accese sulla facciata verso il mare (+z).
		for x: float in [-w * 0.25, w * 0.25]:
			var window := MeshInstance3D.new()
			var quad := BoxMesh.new()
			quad.size = Vector3(0.55, 0.7, 0.06)
			window.mesh = quad
			window.material_override = _mat_window
			window.position = Vector3(x, 0.2, d * 0.5 + 0.02)
			house.add_child(window)


## Barchette ormeggiate in rada davanti al paese: dondolano sull'acqua.
func _add_moored_boats(count: int) -> void:
	for i in count:
		var boat := Node3D.new()
		add_child(boat)
		boat.position = Vector3(_rng.randf_range(-60.0, 20.0), 0.0,
			shore_z + _rng.randf_range(6.0, 14.0))
		boat.rotation.y = _rng.randf_range(0.0, TAU)
		var hull := MeshInstance3D.new()
		var hull_mesh := BoxMesh.new()
		hull_mesh.size = Vector3(1.2, 0.5, 3.0)
		hull.mesh = hull_mesh
		hull.material_override = _flat_material(
			[Color(0.85, 0.85, 0.8), Color(0.4, 0.55, 0.7), Color(0.75, 0.45, 0.3)][i % 3])
		hull.position.y = 0.25
		boat.add_child(hull)
		var bench := MeshInstance3D.new()
		var bench_mesh := BoxMesh.new()
		bench_mesh.size = Vector3(1.0, 0.12, 0.4)
		bench.mesh = bench_mesh
		bench.material_override = _mat_wood
		bench.position = Vector3(0.0, 0.55, -0.4)
		boat.add_child(bench)
		_moored.append(boat)


## Gente sul lungomare (roadmap B2): figure semplici come Nino, ferme a
## godersi il molo — camicie di colori diversi.
func _add_villagers(count: int) -> void:
	var shirts: Array[Color] = [
		Color(0.78, 0.32, 0.24), Color(0.3, 0.5, 0.68), Color(0.45, 0.6, 0.35),
		Color(0.8, 0.65, 0.3), Color(0.6, 0.4, 0.6),
	]
	for i in count:
		var villager := Node3D.new()
		add_child(villager)
		# La quota segue la spiaggia inclinata della Coast (~0.8 lato terra).
		villager.position = Vector3(_rng.randf_range(-45.0, 145.0), 0.85,
			shore_z + _rng.randf_range(-26.0, -18.0))
		villager.rotation.y = _rng.randf_range(0.0, TAU)
		var legs := MeshInstance3D.new()
		var legs_mesh := BoxMesh.new()
		legs_mesh.size = Vector3(0.36, 0.5, 0.26)
		legs.mesh = legs_mesh
		legs.material_override = _mat_pants
		legs.position.y = 0.25
		villager.add_child(legs)
		var torso := MeshInstance3D.new()
		var torso_mesh := CapsuleMesh.new()
		torso_mesh.radius = 0.22
		torso_mesh.height = 0.9
		torso.mesh = torso_mesh
		torso.material_override = _flat_material(shirts[i % shirts.size()])
		torso.position.y = 0.83
		villager.add_child(torso)
		var head := MeshInstance3D.new()
		var head_mesh := SphereMesh.new()
		head_mesh.radius = 0.16
		head_mesh.height = 0.32
		head.mesh = head_mesh
		head.material_override = _mat_skin
		head.position.y = 1.22
		villager.add_child(head)


## Filo di luci calde lungo il lungomare, tra paletti di legno.
func _add_string_lights() -> void:
	var z := shore_z - 24.0
	for x in range(-40, 150, 24):
		_add_box(Vector3(0.16, 3.0, 0.16), Vector3(float(x), 2.1, z), _mat_wood)
	for x in range(-40, 146, 4):
		var bulb := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.13
		sphere.height = 0.26
		bulb.mesh = sphere
		bulb.material_override = _mat_bulb
		# Le lampadine pendono leggermente tra un paletto e l'altro.
		var sag := 0.35 * sin(float(posmod(x, 24)) / 24.0 * PI)
		bulb.position = Vector3(float(x), 3.45 - sag, z)
		add_child(bulb)


## Il campanile si veste d'oro: fascia e globo sulla cuspide (il
## campanile della Coast sta a (58, ~5, shore_z - 38)).
func _gild_bell_tower() -> void:
	var base := Vector3(58.0, 0.0, shore_z - 38.0)
	_add_box(Vector3(2.5, 0.5, 2.5), base + Vector3(0.0, 9.3, 0.0), _mat_gold)
	var globe := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.45
	sphere.height = 0.9
	globe.mesh = sphere
	globe.material_override = _mat_gold
	globe.position = base + Vector3(0.0, 11.3, 0.0)
	add_child(globe)


func _add_box(size: Vector3, pos: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	instance.mesh = box
	instance.material_override = material
	instance.position = pos
	add_child(instance)
	return instance


static func _flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	return mat


static func _glow_material(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	mat.roughness = 0.8
	return mat
