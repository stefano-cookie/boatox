class_name Buoy
extends Area3D

## Boa raccoglibile al passaggio (GDD § Boe): comuni in acque sicure,
## dorate tra gli scogli. Dopo la raccolta sparisce e rispawna a tempo;
## valori e tempi in GameState.

@export var golden: bool = false

## Assegnata da chi la spawna: serve per galleggiare sulle onde.
var sea: Sea

var _active: bool = true

@onready var _visual: Node3D = $Visual
@onready var _body_mesh: MeshInstance3D = $Visual/Body


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if golden:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.78, 0.15)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.7, 0.1)
		mat.emission_energy_multiplier = 0.6
		_body_mesh.material_override = mat
		_visual.scale = Vector3.ONE * 1.15


func _process(_delta: float) -> void:
	if sea != null and visible:
		_visual.position.y = sea.get_height(global_position)


func _on_body_entered(body: Node3D) -> void:
	if not _active or not body is Boat:
		return
	_active = false
	GameState.collect_buoy(golden)
	visible = false
	set_deferred("monitoring", false)
	var respawn := GameState.BUOY_GOLDEN_RESPAWN if golden else GameState.BUOY_COMMON_RESPAWN
	await get_tree().create_timer(respawn).timeout
	if not is_inside_tree():
		return
	visible = true
	set_deferred("monitoring", true)
	_active = true
