class_name SupplyIsland
extends Node3D

## Isola di rifornimento della traversata (roadmap B4): uno scoglio abitato
## neutrale in mezzo al mare grande, con un piccolo scalo (scena Port
## sorella in world.tscn, servizi ridotti: vendi e fai il pieno, niente
## cantiere). Le città lontane sono ostili e ti chiudono il porto in
## faccia: queste isole sono l'unico approdo amico del viaggio — svuoti la
## stiva e riparti col pieno senza tornare a Bova.
##
## Generata in _ready con seed fisso (stessa isola a ogni avvio), primitive
## low-poly come la Coast. Entra in "calm_harbors" (la Sea spegne il mare
## grosso entro harbor_radius: attraccare al largo non è una lotteria) e in
## "supply_islands" (la minimappa la disegna come macchia di terra).

@export var display_name: String = "Scalo franco"
@export var build_seed: int = 3
## Raggio della rada calma letto dalla Sea (gruppo "calm_harbors").
@export var harbor_radius: float = 130.0
## Raggio dell'isolotto: sagoma in minimappa e keep-out per boe/pickup.
@export var island_radius: float = 30.0
@export var visibility_range: float = 1200.0

var _rng := RandomNumberGenerator.new()

var _mat_sand := _flat_material(Color(0.86, 0.78, 0.58))
var _mat_grass := _flat_material(Color(0.52, 0.57, 0.36))
var _mat_rock := _flat_material(Color(0.55, 0.51, 0.45))
var _mat_wall := _flat_material(Color(0.9, 0.86, 0.78))
var _mat_roof := _flat_material(Color(0.5, 0.36, 0.24))
var _mat_wood := _flat_material(Color(0.45, 0.32, 0.2))


func _ready() -> void:
	add_to_group(&"calm_harbors")
	add_to_group(&"supply_islands")
	_rng.seed = build_seed
	_build_island()
	_build_hut()
	_build_props()


## Basamento di sabbia che affiora e cappello d'erba sopra. Solo il
## basamento ha collisione: è l'unica cosa che la barca può toccare.
func _build_island() -> void:
	var body := StaticBody3D.new()
	add_child(body)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = island_radius
	cylinder.height = 8.0
	shape.shape = cylinder
	body.add_child(shape)
	_add_cone(island_radius * 1.25, island_radius * 0.95, 6.0, Vector3(0.0, -2.0, 0.0), _mat_sand)
	_add_cone(island_radius * 0.85, island_radius * 0.6, 1.8, Vector3(0.0, 1.0, 0.0), _mat_grass)
	# Qualche scoglio basso sul bordo, leggibilità dell'approdo.
	for i in 5:
		var angle := TAU * (float(i) + _rng.randf_range(-0.2, 0.2)) / 5.0
		var dist := island_radius * _rng.randf_range(1.05, 1.35)
		var rock := _add_box(Vector3(_rng.randf_range(2.0, 4.0), _rng.randf_range(1.0, 2.0),
			_rng.randf_range(2.0, 4.0)), Vector3(cos(angle) * dist, -0.4, sin(angle) * dist), _mat_rock)
		rock.rotation.y = _rng.randf_range(0.0, TAU)


## La casetta dello scalo: un magazzino basso col tetto spiovente.
func _build_hut() -> void:
	var hut := _add_box(Vector3(6.0, 3.4, 5.0), Vector3(-4.0, 2.6, -2.0), _mat_wall)
	hut.rotation.y = deg_to_rad(_rng.randf_range(-12.0, 12.0))
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(6.6, 1.4, 5.6)
	roof.mesh = prism
	roof.material_override = _mat_roof
	roof.position = Vector3(0.0, 2.4, 0.0)
	roof.visibility_range_end = visibility_range
	hut.add_child(roof)


## Casse e pali del pontile: si vede che qui si commercia.
func _build_props() -> void:
	for i in 4:
		var pos := Vector3(_rng.randf_range(2.0, 9.0), 2.6, _rng.randf_range(-4.0, 4.0))
		var crate := _add_box(Vector3.ONE * _rng.randf_range(1.2, 1.8), pos, _mat_wood)
		crate.rotation.y = _rng.randf_range(0.0, TAU)
	for i in 3:
		_add_box(Vector3(0.5, 3.0, 0.5), Vector3(6.0 + i * 2.4, 1.4, island_radius * 0.6), _mat_wood)


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
	cone.radial_segments = 9
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
