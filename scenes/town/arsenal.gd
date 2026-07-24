class_name Arsenal
extends Node3D

## L'arsenale di Bova (roadmap R7): l'edificio fisico sul molo in cui si
## entra a piedi. Dentro, il tavolo con la mappa della baia — gli slot
## difensivi veri arrivano con B3 (la mappa si co-progetta con Stefano
## prima, decisione R5). Porta d'ingresso e d'uscita sono teletrasporti:
## la stanza interna vive sotto il terreno, così niente interni da
## incastrare nel paesaggio. Tutto costruito in codice, stile Coast.

## Quota della stanza interna rispetto all'edificio (sottoterra).
const INTERIOR_Y: float = -40.0

var _walker_at_door: Walker = null
var _walker_inside: Walker = null
var _hint: Label


func _ready() -> void:
	_build_exterior()
	_build_interior()
	var ui := CanvasLayer.new()
	add_child(ui)
	_hint = Label.new()
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_left = -400.0
	_hint.offset_right = 400.0
	_hint.offset_top = -104.0
	_hint.offset_bottom = -64.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 28)
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", 6)
	ui.add_child(_hint)
	_hint.hide()


func _process(_delta: float) -> void:
	if GameState.ui_focus_open():
		_hint.hide()
	elif _walker_at_door != null:
		_hint.text = "Premi E per entrare nell'arsenale"
		_hint.show()
	elif _walker_inside != null:
		_hint.text = "Premi E per uscire"
		_hint.show()
	else:
		_hint.hide()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or GameState.ui_focus_open():
		return
	if _walker_at_door != null:
		get_viewport().set_input_as_handled()
		# Dentro, di fronte al tavolo della mappa (porta alle spalle).
		_walker_at_door.teleport(to_global(Vector3(0.0, INTERIOR_Y + 0.2, 2.4)), global_rotation.y)
	elif _walker_inside != null:
		get_viewport().set_input_as_handled()
		# Fuori dalla porta, verso il mare.
		_walker_inside.teleport(to_global(Vector3(0.0, 0.6, 4.6)), global_rotation.y + PI)


## L'edificio: pietra chiara, tetto in terracotta, portone di legno verso
## il mare e insegna. Collider pieno (layer 2): dentro si va per porta.
func _build_exterior() -> void:
	var stone := _flat(Color(0.78, 0.76, 0.7))
	_add_box(Vector3(8.0, 4.2, 6.0), Vector3(0.0, 2.1, 0.0), stone)
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(8.6, 1.6, 6.6)
	roof.mesh = prism
	roof.material_override = _flat(Color(0.72, 0.36, 0.24))
	roof.position = Vector3(0.0, 5.0, 0.0)
	add_child(roof)
	# Portone inset sul lato mare (+z) e insegna sopra.
	_add_box(Vector3(1.5, 2.4, 0.12), Vector3(0.0, 1.2, 3.02), _flat(Color(0.4, 0.29, 0.18)))
	var sign := Label3D.new()
	sign.text = "ARSENALE"
	sign.font_size = 72
	sign.outline_size = 10
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = Vector3(0.0, 5.6, 0.0)
	add_child(sign)
	_add_walk_collider(Vector3(8.0, 5.0, 6.0), Vector3(0.0, 2.5, 0.0))
	_add_door_zone(Vector3(0.0, 1.0, 3.6), true)


## La stanza della mappa, sottoterra: pavimento di legno, muri di pietra,
## il tavolo con la carta della baia e una luce calda.
func _build_interior() -> void:
	var stone := _flat(Color(0.55, 0.53, 0.48))
	var wood := _flat(Color(0.5, 0.38, 0.24))
	var y := INTERIOR_Y
	_add_box(Vector3(9.0, 0.3, 7.0), Vector3(0.0, y - 0.15, 0.0), wood)
	_add_walk_collider(Vector3(9.0, 0.3, 7.0), Vector3(0.0, y - 0.15, 0.0))
	# Muri e soffitto (collider solo sui muri: il soffitto è scenografia).
	for wall: Array in [
		[Vector3(9.0, 3.2, 0.3), Vector3(0.0, y + 1.6, -3.5)],
		[Vector3(9.0, 3.2, 0.3), Vector3(0.0, y + 1.6, 3.5)],
		[Vector3(0.3, 3.2, 7.0), Vector3(-4.5, y + 1.6, 0.0)],
		[Vector3(0.3, 3.2, 7.0), Vector3(4.5, y + 1.6, 0.0)],
	]:
		_add_box(wall[0], wall[1], stone)
		_add_walk_collider(wall[0], wall[1])
	_add_box(Vector3(9.0, 0.3, 7.0), Vector3(0.0, y + 3.3, 0.0), stone)
	# Il tavolo con la mappa della baia (segnaposto: gli slot arrivano in B3).
	_add_box(Vector3(2.6, 0.9, 1.6), Vector3(0.0, y + 0.45, -1.6), wood)
	_add_walk_collider(Vector3(2.6, 0.9, 1.6), Vector3(0.0, y + 0.45, -1.6))
	_add_box(Vector3(2.3, 0.04, 1.3), Vector3(0.0, y + 0.93, -1.6), _flat(Color(0.35, 0.55, 0.7)))
	_add_box(Vector3(0.5, 0.05, 0.3), Vector3(-0.4, y + 0.96, -1.5), _flat(Color(0.84, 0.78, 0.6)))
	var note := Label3D.new()
	note.text = "La mappa delle difese della baia\n— in allestimento —"
	note.font_size = 40
	note.outline_size = 8
	note.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	note.position = Vector3(0.0, y + 1.9, -1.6)
	add_child(note)
	# La porta interna, sul muro verso il mare (+z), e la sua zona d'uscita.
	_add_box(Vector3(1.5, 2.4, 0.1), Vector3(0.0, y + 1.2, 3.42), _flat(Color(0.4, 0.29, 0.18)))
	_add_door_zone(Vector3(0.0, y + 1.0, 2.6), false)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.6)
	light.light_energy = 2.4
	light.omni_range = 9.0
	light.position = Vector3(0.0, y + 2.8, 0.0)
	add_child(light)


## Zona-porta (Area3D su mask 2): entra il Walker e compare il prompt.
func _add_door_zone(pos: Vector3, outside: bool) -> void:
	var zone := Area3D.new()
	zone.collision_layer = 0
	zone.collision_mask = 2
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.5
	shape.shape = sphere
	zone.add_child(shape)
	zone.position = pos
	add_child(zone)
	zone.body_entered.connect(_on_door_entered.bind(outside))
	zone.body_exited.connect(_on_door_exited.bind(outside))


func _on_door_entered(body: Node3D, outside: bool) -> void:
	if not body is Walker:
		return
	if outside:
		_walker_at_door = body
	else:
		_walker_inside = body


func _on_door_exited(body: Node3D, outside: bool) -> void:
	if outside and body == _walker_at_door:
		_walker_at_door = null
	elif not outside and body == _walker_inside:
		_walker_inside = null


func _add_box(size: Vector3, pos: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	instance.mesh = box
	instance.material_override = material
	instance.position = pos
	add_child(instance)
	return instance


## Collider camminabile/bloccante su layer 2 (i piedi, non le barche).
func _add_walk_collider(size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = pos
	add_child(body)


static func _flat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	return mat
