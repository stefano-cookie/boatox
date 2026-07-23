class_name City
extends Node3D

## Città lontana del mare grande (roadmap B4): non più un isolotto ma un
## tratto di costa modellata nello stile della Coast di Bova — spiaggia che
## scende sotto il pelo dell'acqua, paese addossato al porto, colline e
## montagne che sfumano nella foschia, due promontori che chiudono la rada.
## Tutto generato in _ready con seed fisso (stessa costa a ogni avvio),
## primitive low-poly e materiali piatti: la personalità viene dai colori.
## La scena Port dell'attracco è un'istanza sorella in world.tscn.
##
## Orientamento: il giocatore arriva da nord (Bova, z piccolo) e la costa
## gli sta di fronte. In locale l'acqua è verso -Z (fronte), la terra verso
## +Z (dietro): la città si piazza senza rotazioni, il porto sorella guarda
## -Z come già fa a Bova.
##
## Gruppi: "cities" (minimappa: sagoma, rada, nome dal porto) e
## "calm_harbors" (la Sea spegne il mare grosso entro harbor_radius, così
## attraccare lontano da casa non è mai una lotteria).

@export var display_name: String = "Città"
@export var build_seed: int = 41
## Raggio della rada calma letto dalla Sea (gruppo "calm_harbors").
@export var harbor_radius: float = 190.0
## Raggio della macchia di terra in minimappa e keep-out per boe/pickup
## (World._is_clear): tiene libero il fronte mare della città.
@export var island_radius: float = 120.0
## Larghezza del tratto di costa lungo X.
@export var coast_width: float = 820.0
@export var house_count: int = 20
@export var tree_count: int = 16
@export var hill_count: int = 20
@export var mountain_count: int = 16
## Colori della personalità: mura e tetti del paese.
@export var wall_color: Color = Color(0.94, 0.91, 0.84)
@export var roof_color: Color = Color(0.24, 0.45, 0.62)
## Sabbia, verde dell'entroterra e montagne sul fondo: cambiano il clima
## del posto (Catania mediterranea verde, Il Cairo sabbioso e desertico).
@export var sand_color: Color = Color(0.88, 0.8, 0.6)
@export var veg_color: Color = Color(0.5, 0.56, 0.34)
@export var mountain_color: Color = Color(0.42, 0.47, 0.53)
## Torre di guardia scura sul punto alto: le città ostili la ostentano.
@export var has_watchtower: bool = true
## Oltre questa distanza i pezzi non si disegnano più: la nebbia
## (fog_depth_end 650) li copre molto prima, è solo risparmio.
@export var visibility_range: float = 1500.0

var _rng := RandomNumberGenerator.new()

var _mat_sand: StandardMaterial3D
var _mat_grass: StandardMaterial3D
var _mat_hill: StandardMaterial3D
var _mat_mountain: StandardMaterial3D
var _mat_rock := _flat_material(Color(0.56, 0.52, 0.46))
var _mat_wall: StandardMaterial3D
var _mat_roof: StandardMaterial3D
var _mat_tree := _flat_material(Color(0.28, 0.43, 0.27))


func _ready() -> void:
	add_to_group(&"cities")
	add_to_group(&"calm_harbors")
	_rng.seed = build_seed
	_mat_sand = _flat_material(sand_color)
	_mat_grass = _flat_material(veg_color)
	_mat_hill = _flat_material(veg_color.darkened(0.12))
	_mat_mountain = _flat_material(mountain_color)
	_mat_wall = _flat_material(wall_color)
	_mat_roof = _flat_material(roof_color)
	_build_beach()
	_build_plain()
	_build_hills()
	_build_mountains()
	_build_headland(-1.0)
	_build_headland(1.0)
	_build_village()
	_build_trees()
	if has_watchtower:
		_build_watchtower()


## Striscia di sabbia inclinata: il bordo verso il mare (-Z) finisce sotto
## l'acqua, così la battigia sparisce nel turchese. La collisione è un muro
## verticale al filo di costa: la barca si ferma sulla sabbia, non ci sale.
func _build_beach() -> void:
	var beach := _add_box(Vector3(coast_width, 4.0, 52.0),
		Vector3(0.0, -1.6, 22.0), _mat_sand)
	beach.rotation.x = deg_to_rad(-3.5)
	# La striscia è lunga: il culling per distanza dall'origine la
	# spegnerebbe ai lati mentre è a due passi.
	beach.visibility_range_end = 0.0
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(coast_width, 8.0, 30.0)
	shape.shape = box
	body.position = Vector3(0.0, -1.0, 30.0)
	add_child(body)
	body.add_child(shape)


## Pianura dietro la spiaggia: copre il piano del mare fin oltre le montagne
## e la portata della nebbia (niente buchi grigi tra le colline).
func _build_plain() -> void:
	var plain := _add_box(Vector3(coast_width, 4.0, 420.0),
		Vector3(0.0, -0.5, 250.0), _mat_grass)
	plain.visibility_range_end = 0.0


func _build_hills() -> void:
	for i in hill_count:
		var height := _rng.randf_range(7.0, 15.0)
		var bottom := _rng.randf_range(14.0, 26.0)
		var pos := Vector3(_rng.randf_range(-coast_width * 0.5, coast_width * 0.5),
			height * 0.25, _rng.randf_range(95.0, 135.0))
		_add_cone(bottom, _rng.randf_range(2.0, 6.0), height, pos, _mat_hill)


## I monti sul fondo: coni alti e desaturati mangiati dalla nebbia, la
## quinta scenica della città.
func _build_mountains() -> void:
	for i in mountain_count:
		var height := _rng.randf_range(40.0, 74.0)
		var bottom := _rng.randf_range(30.0, 52.0)
		var pos := Vector3(
			lerpf(-coast_width * 0.5, coast_width * 0.5,
				(float(i) + _rng.randf_range(0.2, 0.8)) / float(mountain_count)),
			height * 0.32, _rng.randf_range(165.0, 225.0))
		_add_cone(bottom, _rng.randf_range(1.5, 5.0), height, pos, _mat_mountain)


## Promontorio roccioso che chiude un lato della rada: blocchi sfalsati che
## digradano verso la punta in acqua (-Z), non un muro netto. Ha collisione,
## così la rada è una sacca vera. side: -1 = ovest, +1 = est.
func _build_headland(side: float) -> void:
	var body := StaticBody3D.new()
	body.position = Vector3(side * coast_width * 0.42, 0.0, 6.0)
	body.rotation.y = deg_to_rad(10.0 * side)
	add_child(body)
	# [posizione, dimensioni, inclinazione]: dal blocco alto lato terra alla
	# punta bassa che affiora dall'acqua verso -Z.
	var blocks: Array = [
		[Vector3(0.0, 3.0, 34.0), Vector3(56.0, 18.0, 62.0), 3.0],
		[Vector3(4.0 * side, 1.5, -6.0), Vector3(44.0, 12.0, 54.0), -4.0],
		[Vector3(-3.0 * side, 0.6, -42.0), Vector3(30.0, 8.0, 40.0), 5.0],
		[Vector3(2.0 * side, -0.6, -66.0), Vector3(18.0, 5.0, 24.0), -6.0],
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
		rock.visibility_range_end = visibility_range
		body.add_child(rock)
	# Macchia verde sui blocchi alti lato terra.
	var top := MeshInstance3D.new()
	var top_mesh := BoxMesh.new()
	top_mesh.size = Vector3(46.0, 2.5, 52.0)
	top.mesh = top_mesh
	top.material_override = _mat_hill
	top.position = Vector3(0.0, 11.0, 36.0)
	top.rotation.z = deg_to_rad(3.0)
	top.visibility_range_end = visibility_range
	body.add_child(top)
	for shape_def: Array in [[Vector3(0.0, 2.0, 16.0), Vector3(54.0, 16.0, 104.0)],
			[Vector3(0.0, 0.0, -58.0), Vector3(24.0, 8.0, 40.0)]]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = shape_def[1]
		shape.shape = box
		shape.position = shape_def[0]
		body.add_child(shape)


## Il paese addossato al porto: casette coi tetti spioventi raccolte sul
## lungomare, verso il centro della costa.
func _build_village() -> void:
	for i in house_count:
		var w := _rng.randf_range(3.0, 5.0)
		var h := _rng.randf_range(2.6, 4.2)
		var d := _rng.randf_range(3.0, 5.0)
		var pos := Vector3(_rng.randf_range(-coast_width * 0.28, coast_width * 0.28),
			1.4 + h * 0.5, _rng.randf_range(24.0, 74.0))
		var house := _add_box(Vector3(w, h, d), pos, _mat_wall)
		house.rotation.y = deg_to_rad(_rng.randf_range(-14.0, 14.0))
		var roof := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(w + 0.5, 1.3, d + 0.5)
		roof.mesh = prism
		roof.material_override = _mat_roof
		roof.position = Vector3(0.0, h * 0.5 + 0.65, 0.0)
		house.add_child(roof)


## Verde della costa: pini bassi e cipressi slanciati tra paese e colline.
func _build_trees() -> void:
	for i in tree_count:
		var pos := Vector3(_rng.randf_range(-coast_width * 0.42, coast_width * 0.42),
			1.4, _rng.randf_range(40.0, 110.0))
		if _rng.randf() < 0.35:
			_add_cone(0.6, 0.05, _rng.randf_range(4.0, 6.0), pos + Vector3(0, 2.2, 0), _mat_tree)
		else:
			_add_cone(1.6, 0.2, _rng.randf_range(2.2, 3.2), pos + Vector3(0, 1.2, 0), _mat_tree)


## Torre di guardia scura su un fianco del paese: la faccia ostile che vede
## chi arriva dal mare.
func _build_watchtower() -> void:
	var base := Vector3(coast_width * 0.2, 8.0, 30.0)
	var tower := _add_box(Vector3(3.6, 15.0, 3.6), base, _flat_material(wall_color.darkened(0.4)))
	var top := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(4.6, 2.6, 4.6)
	top.mesh = prism
	top.material_override = _mat_roof
	top.position = Vector3(0.0, 8.8, 0.0)
	top.visibility_range_end = visibility_range
	tower.add_child(top)


func _add_box(size: Vector3, pos: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	instance.mesh = box
	instance.material_override = material
	instance.position = pos
	instance.visibility_range_end = visibility_range
	add_child(instance)
	return instance


func _add_cone(bottom_radius: float, top_radius: float, height: float,
		pos: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.bottom_radius = bottom_radius
	cone.top_radius = top_radius
	cone.height = height
	cone.radial_segments = 8
	cone.rings = 1
	instance.mesh = cone
	instance.material_override = material
	instance.position = pos
	instance.rotation.y = _rng.randf_range(0.0, TAU)
	instance.visibility_range_end = visibility_range
	add_child(instance)
	return instance


static func _flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	return mat
