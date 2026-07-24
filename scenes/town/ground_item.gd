class_name GroundItem
extends Node3D

## Item raccoglibile a piedi (roadmap R7): una cassa o cesta appoggiata in
## paese — avvicinati e premi E per metterla in stiva (collect_item, con
## controllo di capienza). Il seme delle isolette da sbarco: la stessa
## scena, domani, sparsa su una spiaggia lontana. Non si salva: a ogni
## sessione il paese rimette fuori la sua roba.

@export var item_id: StringName = &"goods_legno"
## Cesta (vero) o cassa (falso): cambia solo la sagoma.
@export var basket: bool = false

var _walker: Walker = null
var _taken: bool = false

@onready var _zone: Area3D = $PickZone
@onready var _hint: Label = $PickUI/Hint


func _ready() -> void:
	_zone.body_entered.connect(_on_zone_entered)
	_zone.body_exited.connect(_on_zone_exited)
	_hint.hide()
	_build_shape()


func _process(_delta: float) -> void:
	if _walker == null or _taken or GameState.ui_focus_open():
		_hint.hide()
		return
	var def := GameState.item_def(item_id)
	_hint.text = "Premi E per raccogliere: %s" % (def.display_name if def != null else String(item_id))
	_hint.show()


func _unhandled_input(event: InputEvent) -> void:
	if _walker == null or _taken or GameState.ui_focus_open():
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if GameState.collect_item(item_id):
			_taken = true
			_hint.hide()
			queue_free()


func _on_zone_entered(body: Node3D) -> void:
	if body is Walker:
		_walker = body


func _on_zone_exited(body: Node3D) -> void:
	if body == _walker:
		_walker = null


## Cassa di legno (coperchio del colore dell'item, come le LootCrate) o
## cesta tonda: si capisce da lontano cosa c'è dentro.
func _build_shape() -> void:
	var def := GameState.item_def(item_id)
	var accent := def.color if def != null else Color(0.7, 0.6, 0.4)
	if basket:
		var body := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.34
		cyl.bottom_radius = 0.26
		cyl.height = 0.36
		body.mesh = cyl
		body.material_override = _flat(Color(0.62, 0.48, 0.28))
		body.position.y = 0.18
		add_child(body)
		var content := MeshInstance3D.new()
		var top := SphereMesh.new()
		top.radius = 0.26
		top.height = 0.3
		content.mesh = top
		content.material_override = _flat(accent)
		content.position.y = 0.4
		add_child(content)
	else:
		var box := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		box_mesh.size = Vector3(0.55, 0.42, 0.55)
		box.mesh = box_mesh
		box.material_override = _flat(Color(0.5, 0.38, 0.24))
		box.position.y = 0.21
		add_child(box)
		var lid := MeshInstance3D.new()
		var lid_mesh := BoxMesh.new()
		lid_mesh.size = Vector3(0.58, 0.08, 0.58)
		lid.mesh = lid_mesh
		lid.material_override = _flat(accent)
		lid.position.y = 0.46
		add_child(lid)


static func _flat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	return mat
