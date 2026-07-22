class_name BuildSlot
extends Node3D

## Slot di costruzione predefinito (roadmap B2): disegnato a mano su
## costa e isole in world.tscn — si sceglie *cosa* costruirci, non dove,
## così la baia resta bella e leggibile. Vuoto mostra un cartello da
## lotto; costruito monta la visuale procedurale dell'edificio al livello
## corrente (stesso stile low-poly della Coast). Si risincronizza su
## Town.town_changed.

@export var slot_id: StringName
@export var display_name: String = "Lotto"
## Edifici ammessi in questo slot (vuoto = tutti). Il faro sta sul
## promontorio, il molo sull'acqua: è la geografia a decidere.
@export var allowed: Array[StringName] = []

var _built_id: StringName = &""
var _built_level: int = -1
var _props: Node3D = null

var _mat_wood := _flat_material(Color(0.55, 0.4, 0.26))
var _mat_pole := _flat_material(Color(0.42, 0.3, 0.2))
var _mat_wall := _flat_material(Color(0.93, 0.91, 0.86))
var _mat_roof := _flat_material(Color(0.72, 0.36, 0.24))
var _mat_crate := _flat_material(Color(0.78, 0.62, 0.4))
var _mat_metal := _flat_material(Color(0.5, 0.54, 0.58))
var _mat_red := _flat_material(Color(0.78, 0.26, 0.2))


func _ready() -> void:
	add_to_group(&"build_slots")
	Town.town_changed.connect(_sync)
	_sync()


## Vero se l'edificio può sorgere qui (il pannello del porto lo chiede
## prima di proporre il bottone).
func can_host(building_id: StringName) -> bool:
	return allowed.is_empty() or allowed.has(building_id)


## Ricostruisce le mesh solo se l'edificio o il livello sono cambiati:
## town_changed arriva anche per vendite e punti, non serve rifare nulla.
func _sync() -> void:
	var info := Town.slot_building(slot_id)
	var id: StringName = info.get("id", &"")
	var level: int = info.get("level", 0)
	if id == _built_id and level == _built_level:
		return
	_built_id = id
	_built_level = level
	if _props != null:
		_props.queue_free()
	_props = Node3D.new()
	add_child(_props)
	match id:
		&"molo_grande":
			_build_molo(level)
		&"conserva":
			_build_conserva(level)
		&"magazzino":
			_build_magazzino(level)
		&"faro":
			_build_faro(level)
		_:
			_build_empty_marker()


## Cartello da lotto: due paletti e l'insegna col nome — si vede dal
## mare che lì si può costruire.
func _build_empty_marker() -> void:
	_add_box(Vector3(0.18, 1.4, 0.18), Vector3(-0.7, 0.7, 0.0), _mat_pole)
	_add_box(Vector3(0.18, 1.4, 0.18), Vector3(0.7, 0.7, 0.0), _mat_pole)
	_add_box(Vector3(2.0, 0.9, 0.12), Vector3(0.0, 1.5, 0.0), _mat_wood)
	var label := Label3D.new()
	label.text = "%s\n(lotto edificabile)" % display_name
	label.font_size = 36
	label.outline_size = 6
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0.0, 2.6, 0.0)
	_props.add_child(label)


## Molo grande: passerella di legno che si allunga verso il mare (+z),
## coi pali; dal livello 2 la gru di banchina, al 3 l'ala di attracco.
func _build_molo(level: int) -> void:
	var length := 8.0 + 4.0 * level
	_add_box(Vector3(3.2, 0.25, length), Vector3(0.0, 0.55, length * 0.5), _mat_wood)
	var poles := int(length / 3.0)
	for i in poles:
		var z := 1.0 + float(i) * (length - 2.0) / maxf(float(poles - 1), 1.0)
		_add_box(Vector3(0.26, 1.8, 0.26), Vector3(-1.4, 0.0, z), _mat_pole)
		_add_box(Vector3(0.26, 1.8, 0.26), Vector3(1.4, 0.0, z), _mat_pole)
	if level >= 2:
		# Gru di banchina: montante, braccio e cima col gancio.
		_add_box(Vector3(0.35, 3.4, 0.35), Vector3(-1.1, 2.2, length * 0.55), _mat_pole)
		_add_box(Vector3(0.28, 0.28, 2.6), Vector3(-1.1, 3.8, length * 0.55 + 1.1), _mat_wood)
		_add_box(Vector3(0.06, 1.2, 0.06), Vector3(-1.1, 3.1, length * 0.55 + 2.3), _mat_metal)
	if level >= 3:
		_add_box(Vector3(6.0, 0.25, 2.8), Vector3(0.0, 0.55, length - 1.4), _mat_wood)
		for x: float in [-2.6, 2.6]:
			_add_box(Vector3(0.26, 1.8, 0.26), Vector3(x, 0.0, length - 0.6), _mat_pole)
	# Casse sul molo: si vede che qui si lavora.
	for i in level:
		_add_box(Vector3(0.7, 0.7, 0.7), Vector3(0.9 - float(i) * 0.8, 1.05, 2.0 + float(i)), _mat_crate)


## Conserva: capannone bianco con tetto in terracotta e ciminiera; al
## livello 2 l'ala nuova e più casse pronte a partire.
func _build_conserva(level: int) -> void:
	_add_box(Vector3(6.0, 3.0, 4.2), Vector3(0.0, 1.5, 0.0), _mat_wall)
	_add_prism(Vector3(6.5, 1.4, 4.7), Vector3(0.0, 3.7, 0.0), _mat_roof)
	_add_cylinder(0.35, 2.2, Vector3(2.2, 4.0, -1.2), _mat_metal)
	if level >= 2:
		_add_box(Vector3(3.4, 2.4, 3.4), Vector3(4.6, 1.2, 0.2), _mat_wall)
		_add_prism(Vector3(3.9, 1.1, 3.9), Vector3(4.6, 3.0, 0.2), _mat_roof)
	for i in 2 + level * 2:
		_add_box(Vector3(0.65, 0.65, 0.65),
			Vector3(-3.6 + float(i % 3) * 0.8, 0.35, 2.6 + float(i / 3) * 0.8), _mat_crate)


## Magazzino: capannone lungo dal tetto piatto, botti e casse impilate
## che crescono col livello.
func _build_magazzino(level: int) -> void:
	var width := 5.0 + float(level)
	_add_box(Vector3(width, 3.2, 4.6), Vector3(0.0, 1.6, 0.0), _mat_crate)
	_add_box(Vector3(width + 0.5, 0.3, 5.1), Vector3(0.0, 3.35, 0.0), _mat_pole)
	_add_box(Vector3(1.6, 2.2, 0.15), Vector3(0.0, 1.1, 2.35), _mat_wood)
	for i in level * 3:
		_add_cylinder(0.4, 0.9, Vector3(width * 0.5 + 0.8, 0.45 + float(i / 3) * 0.95,
			-1.2 + float(i % 3) * 1.0), _mat_wood)


## Faro: torre bianca a fasce rosse sul promontorio, lanterna accesa che
## si vede dal largo (e in B2 rende di più la flottiglia).
func _build_faro(_level: int) -> void:
	for i in 4:
		var mat := _mat_red if i % 2 == 1 else _mat_wall
		_add_cylinder(1.35 - float(i) * 0.13, 2.0, Vector3(0.0, 1.0 + float(i) * 2.0, 0.0), mat)
	# Ballatoio e lanterna.
	_add_cylinder(1.25, 0.25, Vector3(0.0, 8.1, 0.0), _mat_metal)
	var lamp := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.55
	sphere.height = 1.1
	lamp.mesh = sphere
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.albedo_color = Color(1.0, 0.9, 0.55)
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(1.0, 0.85, 0.4)
	lamp_mat.emission_energy_multiplier = 2.0
	lamp.material_override = lamp_mat
	lamp.position = Vector3(0.0, 8.9, 0.0)
	_props.add_child(lamp)
	_add_cylinder(0.9, 0.5, Vector3(0.0, 9.6, 0.0), _mat_red)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.5)
	light.light_energy = 2.0
	light.omni_range = 35.0
	light.position = Vector3(0.0, 8.9, 0.0)
	_props.add_child(light)


# --- Mattoncini (stile Coast) ------------------------------------------------

func _add_box(size: Vector3, pos: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	instance.mesh = box
	instance.material_override = material
	instance.position = pos
	_props.add_child(instance)
	return instance


func _add_prism(size: Vector3, pos: Vector3, material: StandardMaterial3D) -> void:
	var instance := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = size
	instance.mesh = prism
	instance.material_override = material
	instance.position = pos
	_props.add_child(instance)


func _add_cylinder(radius: float, height: float, pos: Vector3, material: StandardMaterial3D) -> void:
	var instance := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 10
	cylinder.rings = 1
	instance.mesh = cylinder
	instance.material_override = material
	instance.position = pos
	_props.add_child(instance)


static func _flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	return mat
