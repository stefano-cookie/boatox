class_name BoatCustomization
extends RefCounted

## Veste il modello della barca con la customizzazione corrente (roadmap
## A2): ritinge i materiali di scafo e rifinitura e monta gli accessori
## come nodi extra. Lavora sempre su un visual appena istanziato (la Boat
## lo rimonta a ogni customization_changed), così la livrea di fabbrica è
## semplicemente "non toccare niente" e l'anteprima non lascia tracce.
## I materiali dei .tscn sono condivisi tra le istanze (anche le IA di
## regata usano gli stessi modelli): mai modificarli sul posto — si
## duplicano, si tingono e si riassegnano solo su questa istanza.

## Nodo che porta la tinta principale in ogni modello.
const HULL_NODE := "Hull"
## Nodi che portano la tinta di rifinitura, uno per modello (il primo che
## esiste vince): Stripe (cabinato), GunwaleLeft (barchetta),
## RubRailLeft (pescareccio).
const ACCENT_NODES: Array[String] = ["Stripe", "GunwaleLeft", "RubRailLeft"]

## Proporzioni degli accessori rispetto alla collision_size della barca:
## bastano per tutti e tre i modelli senza marker per-scena.
const DECK_HEIGHT_RATIO := 0.7
const FENDER_HEIGHT_RATIO := 0.45
const FENDERS_PER_SIDE := 3
const LIGHTS_PER_SIDE := 4


## Punto d'ingresso: vernice effettiva (anteprima inclusa) e accessori
## della barca corrente, letti da GameState.
static func apply(visual: Node3D, def: BoatDefinition) -> void:
	var paint := GameState.effective_paint()
	if paint["id"] != GameState.PAINT_ORIGINAL:
		_repaint(visual, paint)
	var accent: Color = paint["accent"] if paint["id"] != GameState.PAINT_ORIGINAL \
		else Color(0.78, 0.2, 0.16)
	for accessory_id: StringName in GameState.boat_accessories():
		match accessory_id:
			&"flag":
				_mount_flag(visual, def, accent)
			&"fenders":
				_mount_fenders(visual, def)
			&"lights":
				_mount_lights(visual, def)


## Tinge tutti i mesh che condividono il materiale del nodo Hull (prua,
## cabina, tetto… nei modelli usano lo stesso materiale) e, se esiste,
## quello del nodo di rifinitura.
static func _repaint(visual: Node3D, paint: Dictionary) -> void:
	_retint_shared_material(visual, HULL_NODE, paint["hull"])
	for node_name in ACCENT_NODES:
		if visual.get_node_or_null(node_name) != null:
			_retint_shared_material(visual, node_name, paint["accent"])
			return


static func _retint_shared_material(visual: Node3D, node_name: String, tint: Color) -> void:
	var reference := visual.get_node_or_null(node_name) as MeshInstance3D
	if reference == null or reference.material_override == null:
		return
	var original := reference.material_override
	var painted := original.duplicate() as StandardMaterial3D
	if painted == null:
		return
	painted.albedo_color = tint
	for child in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if mesh.material_override == original:
			mesh.material_override = painted


## Bandiera di poppa: asta sottile e bandierina nella tinta di rifinitura.
static func _mount_flag(visual: Node3D, def: BoatDefinition, accent: Color) -> void:
	var deck_y := def.collision_size.y * DECK_HEIGHT_RATIO
	var stern_z := def.collision_size.z * 0.5 - 0.25
	var pole_height := 1.1
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.025
	pole_mesh.bottom_radius = 0.035
	pole_mesh.height = pole_height
	pole_mesh.radial_segments = 6
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.85, 0.87, 0.9)
	pole_mat.metallic = 0.5
	pole_mat.roughness = 0.4
	var pole := MeshInstance3D.new()
	pole.name = "AccessoryFlagPole"
	pole.mesh = pole_mesh
	pole.material_override = pole_mat
	pole.position = Vector3(0.0, deck_y + pole_height * 0.5, stern_z)
	visual.add_child(pole)
	var flag_mesh := BoxMesh.new()
	flag_mesh.size = Vector3(0.02, 0.32, 0.5)
	var flag_mat := StandardMaterial3D.new()
	flag_mat.albedo_color = accent
	flag_mat.roughness = 0.9
	var flag := MeshInstance3D.new()
	flag.name = "AccessoryFlag"
	flag.mesh = flag_mesh
	flag.material_override = flag_mat
	flag.position = Vector3(0.0, deck_y + pole_height - 0.2, stern_z + 0.28)
	visual.add_child(flag)


## Parabordi: cilindri bianchi appesi lungo le murate.
static func _mount_fenders(visual: Node3D, def: BoatDefinition) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.09
	mesh.bottom_radius = 0.09
	mesh.height = 0.34
	mesh.radial_segments = 8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.94, 0.94, 0.9)
	mat.roughness = 0.8
	var side_x := def.collision_size.x * 0.5 + 0.07
	var hang_y := def.collision_size.y * FENDER_HEIGHT_RATIO
	for side in [-1.0, 1.0]:
		for i in FENDERS_PER_SIDE:
			var t := (float(i) / float(FENDERS_PER_SIDE - 1)) - 0.5
			var fender := MeshInstance3D.new()
			fender.name = "AccessoryFender%s%d" % ["L" if side < 0.0 else "R", i]
			fender.mesh = mesh
			fender.material_override = mat
			fender.position = Vector3(side * side_x, hang_y,
				t * def.collision_size.z * 0.55)
			visual.add_child(fender)


## Luci di cortesia: filo di lucine calde lungo le due murate, da prua a
## poppa. Emissive: si vedono bene anche di giorno.
static func _mount_lights(visual: Node3D, def: BoatDefinition) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	mesh.radial_segments = 8
	mesh.rings = 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.82, 0.45)
	mat.emission_energy_multiplier = 1.6
	var side_x := def.collision_size.x * 0.5 * 0.95
	var rail_y := def.collision_size.y * 0.85
	for side in [-1.0, 1.0]:
		for i in LIGHTS_PER_SIDE:
			var t := (float(i) / float(LIGHTS_PER_SIDE - 1)) - 0.5
			var light := MeshInstance3D.new()
			light.name = "AccessoryLight%s%d" % ["L" if side < 0.0 else "R", i]
			light.mesh = mesh
			light.material_override = mat
			light.position = Vector3(side * side_x, rail_y,
				t * def.collision_size.z * 0.8)
			visual.add_child(light)
