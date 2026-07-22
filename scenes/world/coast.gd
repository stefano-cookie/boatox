extends Node3D

## La costa ionica ispirata a Bova Marina: spiaggia in pendenza che
## scende sotto il pelo dell'acqua, paesino bianco con tetti in
## terracotta e campanile sul lungomare, colline secche mediterranee,
## la sagoma dell'Aspromonte nella foschia e due promontori rocciosi
## che chiudono la baia. Tutto generato in _ready con seed fisso:
## stessa costa a ogni avvio, densità regolabili dall'Inspector.
## La terra vive a z < shore_z della Sea; solo spiaggia e promontori
## hanno collisioni (il resto non è raggiungibile in barca).

@export var build_seed: int = 12
## Mezza larghezza della costa: più larga dei confini di gioco, così
## dall'acqua non se ne vede mai la fine.
@export var half_width: float = 520.0
## Linea di costa: deve coincidere con shore_z della Sea.
@export var shore_z: float = -140.0
@export var house_count: int = 22
@export var tree_count: int = 46
@export var hill_count: int = 12
@export var mountain_count: int = 9

var _rng := RandomNumberGenerator.new()

var _mat_sand := _flat_material(Color(0.88, 0.8, 0.6))
var _mat_grass := _flat_material(Color(0.56, 0.6, 0.36))
var _mat_hill := _flat_material(Color(0.46, 0.52, 0.32))
var _mat_mountain := _flat_material(Color(0.42, 0.47, 0.53))
var _mat_rock := _flat_material(Color(0.58, 0.53, 0.46))
var _mat_wall := _flat_material(Color(0.93, 0.91, 0.86))
var _mat_roof := _flat_material(Color(0.72, 0.36, 0.24))
var _mat_tree := _flat_material(Color(0.27, 0.44, 0.26))


func _ready() -> void:
	_rng.seed = build_seed
	_build_beach()
	_build_plain()
	_build_hills()
	_build_mountains()
	_build_promontory(-1.0)
	_build_promontory(1.0)
	_build_village()
	_build_trees()


## Striscia di sabbia inclinata: il bordo verso il mare finisce sotto
## l'acqua, così la battigia è sabbia che sparisce nel turchese.
func _build_beach() -> void:
	var beach := _add_box(Vector3(half_width * 2.0, 4.0, 48.0),
		Vector3(0.0, -1.6, shore_z - 20.0), _mat_sand)
	beach.rotation.x = deg_to_rad(3.5)
	# Collisione verticale al filo di costa: la barca si ferma sulla
	# sabbia invece di salire sulla spiaggia.
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(half_width * 2.0, 8.0, 44.0)
	shape.shape = box
	body.position = Vector3(0.0, -2.0, shore_z - 22.0)
	add_child(body)
	body.add_child(shape)


## Pianura verde dietro la spiaggia: copre il piano del mare fin oltre
## le montagne e la portata della nebbia (niente buchi grigi tra le
## colline guardando la costa dal largo).
func _build_plain() -> void:
	_add_box(Vector3(half_width * 2.0, 4.0, 420.0),
		Vector3(0.0, -0.5, shore_z - 250.0), _mat_grass)


func _build_hills() -> void:
	for i in hill_count:
		var height := _rng.randf_range(7.0, 16.0)
		var bottom := _rng.randf_range(14.0, 26.0)
		var pos := Vector3(_rng.randf_range(-half_width, half_width), height * 0.25,
			shore_z + _rng.randf_range(-125.0, -85.0))
		_add_cone(bottom, _rng.randf_range(2.0, 6.0), height, pos, _mat_hill)


## L'Aspromonte: coni alti e desaturati dietro le colline, mangiati
## dalla nebbia — la quinta scenica della baia.
func _build_mountains() -> void:
	for i in mountain_count:
		var height := _rng.randf_range(42.0, 80.0)
		var bottom := _rng.randf_range(32.0, 55.0)
		var pos := Vector3(
			lerpf(-half_width, half_width, (float(i) + _rng.randf_range(0.2, 0.8)) / float(mountain_count)),
			height * 0.32, shore_z + _rng.randf_range(-215.0, -160.0))
		_add_cone(bottom, _rng.randf_range(1.5, 5.0), height, pos, _mat_mountain)


## Promontorio roccioso che chiude un lato della baia: blocchi sfalsati
## e inclinati che digradano verso la punta, non un muro netto.
## side: -1 = ovest, +1 = est.
func _build_promontory(side: float) -> void:
	var body := StaticBody3D.new()
	body.position = Vector3(side * 312.0, 0.0, shore_z + 48.0)
	body.rotation.y = deg_to_rad(-12.0 * side)
	add_child(body)
	# [posizione, dimensioni, inclinazione]: dal blocco alto lato terra
	# alla punta bassa che affiora dall'acqua.
	var blocks: Array = [
		[Vector3(0.0, 3.0, -38.0), Vector3(60.0, 18.0, 68.0), 3.0],
		[Vector3(4.0 * side, 1.5, 6.0), Vector3(48.0, 12.0, 58.0), -4.0],
		[Vector3(-3.0 * side, 0.6, 44.0), Vector3(34.0, 8.0, 44.0), 5.0],
		[Vector3(2.0 * side, -0.6, 70.0), Vector3(20.0, 5.0, 26.0), -6.0],
	]
	for block: Array in blocks:
		var rock := MeshInstance3D.new()
		var rock_mesh := BoxMesh.new()
		rock_mesh.size = block[1]
		rock.mesh = rock_mesh
		rock.material_override = _mat_rock
		rock.position = block[0]
		rock.rotation = Vector3(deg_to_rad(_rng.randf_range(-2.0, 2.0)),
			deg_to_rad(_rng.randf_range(-8.0, 8.0)), deg_to_rad(block[2]))
		body.add_child(rock)
	# Macchia verde sui blocchi alti lato terra.
	var top := MeshInstance3D.new()
	var top_mesh := BoxMesh.new()
	top_mesh.size = Vector3(50.0, 2.5, 56.0)
	top.mesh = top_mesh
	top.material_override = _mat_hill
	top.position = Vector3(0.0, 11.0, -40.0)
	top.rotation.z = deg_to_rad(3.0)
	body.add_child(top)
	for shape_def: Array in [[Vector3(0.0, 2.0, -18.0), Vector3(58.0, 16.0, 110.0)],
			[Vector3(0.0, 0.0, 62.0), Vector3(26.0, 8.0, 44.0)]]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = shape_def[1]
		shape.shape = box
		shape.position = shape_def[0]
		body.add_child(shape)


## Il paesino sul lungomare: casette bianche coi tetti in terracotta
## raccolte intorno al porto, più il campanile.
func _build_village() -> void:
	for i in house_count:
		var w := _rng.randf_range(3.0, 5.0)
		var h := _rng.randf_range(2.6, 4.0)
		var d := _rng.randf_range(3.0, 5.0)
		var pos := Vector3(_rng.randf_range(-50.0, 150.0),
			1.2 + h * 0.5, shore_z + _rng.randf_range(-58.0, -30.0))
		var house := _add_box(Vector3(w, h, d), pos, _mat_wall)
		house.rotation.y = deg_to_rad(_rng.randf_range(-12.0, 12.0))
		var roof := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(w + 0.5, 1.3, d + 0.5)
		roof.mesh = prism
		roof.material_override = _mat_roof
		roof.position = Vector3(0.0, h * 0.5 + 0.65, 0.0)
		house.add_child(roof)
	# Campanile vicino al porto.
	var tower := _add_box(Vector3(2.2, 8.0, 2.2), Vector3(58.0, 5.0, shore_z - 38.0), _mat_wall)
	var spire := MeshInstance3D.new()
	var spire_mesh := PrismMesh.new()
	spire_mesh.size = Vector3(2.6, 1.8, 2.6)
	spire.mesh = spire_mesh
	spire.material_override = _mat_roof
	spire.position = Vector3(0.0, 4.9, 0.0)
	tower.add_child(spire)


## Verde mediterraneo: pini bassi e cipressi slanciati tra paese e colline.
func _build_trees() -> void:
	for i in tree_count:
		var pos := Vector3(_rng.randf_range(-half_width * 0.9, half_width * 0.9),
			1.4, shore_z + _rng.randf_range(-110.0, -35.0))
		if _rng.randf() < 0.35:
			_add_cone(0.6, 0.05, _rng.randf_range(4.0, 6.0), pos + Vector3(0, 2.2, 0), _mat_tree)
		else:
			_add_cone(1.6, 0.2, _rng.randf_range(2.2, 3.2), pos + Vector3(0, 1.2, 0), _mat_tree)


func _add_box(size: Vector3, pos: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	instance.mesh = box
	instance.material_override = material
	instance.position = pos
	add_child(instance)
	return instance


func _add_cone(bottom_radius: float, top_radius: float, height: float,
		pos: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.bottom_radius = bottom_radius
	cone.top_radius = top_radius
	cone.height = height
	cone.radial_segments = 7
	cone.rings = 1
	instance.mesh = cone
	instance.material_override = material
	instance.position = pos
	instance.rotation.y = _rng.randf_range(0.0, TAU)
	add_child(instance)
	return instance


static func _flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	return mat
