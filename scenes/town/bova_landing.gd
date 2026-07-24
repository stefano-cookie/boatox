class_name BovaLanding
extends Node3D

## La Bova che si gira a piedi (roadmap R7): passerella di legno che
## unisce la battigia alle assi del molo, recinti invisibili ai bordi
## della zona camminabile (i promontori e il retro del paese) e l'edificio
## dell'arsenale. NPC datori e item raccoglibili sono figli di scena, così
## le posizioni si spostano dall'Inspector. Tutto su layer 2: la barca non
## vede niente di tutto questo.

## Mezza larghezza della zona camminabile (dentro i promontori).
@export var walk_half_width: float = 310.0
## Fine della zona camminabile verso l'entroterra (z mondo).
@export var back_z: float = -200.0
## Posizione dell'arsenale (mondo). Accanto alla radice del molo.
@export var arsenal_position: Vector3 = Vector3(52.0, 0.2, -162.0)

const WOOD_COLOR := Color(0.55, 0.4, 0.26)


func _ready() -> void:
	_build_walkway()
	_build_bounds()
	var arsenal := Arsenal.new()
	arsenal.position = arsenal_position
	add_child(arsenal)


## La passerella: un'unica rampa di assi appena inclinata, dalla sabbia
## (z ≈ -159) al filo delle assi del molo (0.675 a z = -138).
func _build_walkway() -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3.0, 0.25, 21.5)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = WOOD_COLOR
	mat.roughness = 0.9
	mesh.material_override = mat
	mesh.position = Vector3(40.0, 0.41, -148.5)
	mesh.rotation.x = -0.0131
	add_child(mesh)
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var shape_box := BoxShape3D.new()
	shape_box.size = box.size
	shape.shape = shape_box
	body.add_child(shape)
	body.position = mesh.position
	body.rotation = mesh.rotation
	add_child(body)


## Recinti invisibili (layer 2): ai piedi dei promontori e dietro il
## paese. Verso il mare nessun muro: si finisce in acqua bassa e si
## torna a riva bagnati (la rete anti-caduta del Walker copre il resto).
func _build_bounds() -> void:
	var walls: Array = [
		[Vector3(1.0, 6.0, 80.0), Vector3(-walk_half_width, 2.0, -170.0)],
		[Vector3(1.0, 6.0, 80.0), Vector3(walk_half_width + 20.0, 2.0, -170.0)],
		[Vector3(walk_half_width * 2.0 + 40.0, 6.0, 1.0), Vector3(10.0, 2.0, back_z)],
	]
	for wall: Array in walls:
		var body := StaticBody3D.new()
		body.collision_layer = 2
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = wall[0]
		shape.shape = box
		body.add_child(shape)
		body.position = wall[1]
		add_child(body)
