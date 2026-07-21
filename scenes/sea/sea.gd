class_name Sea
extends MeshInstance3D

## Piano d'acqua infinito: segue il bersaglio a scatti di una cella di
## griglia (le onde sono calcolate in spazio mondo, quindi lo spostamento
## è invisibile). Replica su CPU la matematica dello shader per dare a
## chi galleggia l'altezza dell'acqua in un punto (get_height).

@export var follow_target: Node3D

@export_group("Onda 1")
@export var wave_1_direction_deg: float = 0.0
@export var wave_1_amplitude: float = 0.22
@export var wave_1_length: float = 14.0
@export var wave_1_speed: float = 3.0

@export_group("Onda 2")
@export var wave_2_direction_deg: float = 65.0
@export var wave_2_amplitude: float = 0.12
@export var wave_2_length: float = 8.0
@export var wave_2_speed: float = 2.4

@export_group("Onda 3")
@export var wave_3_direction_deg: float = 130.0
@export var wave_3_amplitude: float = 0.06
@export var wave_3_length: float = 4.5
@export var wave_3_speed: float = 1.8

var _time: float = 0.0
var _grid_step: float = 2.5

@onready var _material: ShaderMaterial = material_override as ShaderMaterial


func _ready() -> void:
	var plane := mesh as PlaneMesh
	if plane != null:
		_grid_step = plane.size.x / float(plane.subdivide_width + 1)


func _process(delta: float) -> void:
	_time += delta
	_update_uniforms()
	if follow_target != null:
		global_position.x = snappedf(follow_target.global_position.x, _grid_step)
		global_position.z = snappedf(follow_target.global_position.z, _grid_step)


func get_height(world_pos: Vector3) -> float:
	var p := Vector2(world_pos.x, world_pos.z)
	return _sine(p, wave_1_direction_deg, wave_1_amplitude, wave_1_length, wave_1_speed) \
		+ _sine(p, wave_2_direction_deg, wave_2_amplitude, wave_2_length, wave_2_speed) \
		+ _sine(p, wave_3_direction_deg, wave_3_amplitude, wave_3_length, wave_3_speed)


func _sine(p: Vector2, dir_deg: float, amplitude: float, length: float, speed: float) -> float:
	var dir := Vector2.from_angle(deg_to_rad(dir_deg))
	var k := TAU / maxf(length, 0.01)
	return amplitude * sin(k * (dir.dot(p) - speed * _time))


func _update_uniforms() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("u_time", _time)
	_material.set_shader_parameter("wave_a", _wave_vec(wave_1_direction_deg, wave_1_amplitude, wave_1_length))
	_material.set_shader_parameter("wave_b", _wave_vec(wave_2_direction_deg, wave_2_amplitude, wave_2_length))
	_material.set_shader_parameter("wave_c", _wave_vec(wave_3_direction_deg, wave_3_amplitude, wave_3_length))
	_material.set_shader_parameter("wave_speeds", Vector3(wave_1_speed, wave_2_speed, wave_3_speed))


func _wave_vec(dir_deg: float, amplitude: float, length: float) -> Vector4:
	var dir := Vector2.from_angle(deg_to_rad(dir_deg))
	return Vector4(dir.x, dir.y, amplitude, length)
