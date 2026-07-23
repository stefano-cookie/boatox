class_name Sea
extends MeshInstance3D

## Piano d'acqua infinito: segue il bersaglio a scatti di una cella di
## griglia (le onde sono calcolate in spazio mondo, quindi lo spostamento
## è invisibile). Replica su CPU la matematica dello shader per dare a
## chi galleggia l'altezza dell'acqua in un punto (get_height).
##
## Lo stato del mare dipende dalla distanza dalla costa (GDD § Navigazione):
## la terra sta a z < shore_z, il mare aperto verso +Z. Vicino alla
## spiaggia c'è solo risacca, poi acque calme, medie e mosse a fasce
## parallele alla costa. Il meteo dinamico moltiplica tutto.

@export var follow_target: Node3D
## Limite sud dell'inseguimento vicino alla costa: il piano non scorre
## oltre, così il suo bordo nord resta sempre infilato sotto la spiaggia
## (niente buchi d'acqua guardando la costa dal largo). Feedback playtest
## round 2: il mare sembrava finire come un muro al largo. Col piano
## 1400×1400 (mezzo lato 700), a follow_z_max=500 il bordo nord resta a
## z≈-200 (sotto la costa a shore_z=-140).
@export var follow_z_max: float = 500.0
## Oltre questa z il piano segue libero (roadmap B4, mare grande): la
## costa è ormai fuori dalla nebbia (fog_depth_end 650 < 700 di mezzo
## piano), quindi il bordo nord non si vede mai scoperto.
@export var follow_free_z: float = 700.0

@export_group("Costa e zone di mare")
## Linea di costa: la terra occupa z < shore_z.
@export var shore_z: float = -140.0
## Larghezza della fascia di acque calme, misurata dalla costa.
@export var calm_width: float = 110.0
## Fino a questa distanza dalla costa acque medie; oltre, mare aperto.
@export var medium_width: float = 220.0
## Larghezza della transizione tra una fascia e l'altra.
@export var zone_blend: float = 40.0
@export var calm_multiplier: float = 0.6
@export var medium_multiplier: float = 1.5

@export_group("Mare aperto")
## Oltre le acque medie non c'è una fascia uniforme ma una curva continua
## (feedback playtest M3): agitazione di base media all'inizio del largo,
## che cresce con la distanza fino a open_far_multiplier. Sopra ci
## lavorano meteo e celle di vento: la tempesta perenne non esiste più.
@export var open_base_multiplier: float = 1.7
@export var open_far_multiplier: float = 2.6
## Distanza dalla costa a cui la curva raggiunge open_far_multiplier.
@export var open_far_distance: float = 700.0
## Celle di vento che ingrossano il mare localmente (nodo WindField).
@export var wind_field: WindField

@export_group("Battigia")
## Entro questa distanza dalla costa le onde si spengono (risacca).
@export var shore_lap_distance: float = 30.0
## Frazione d'ampiezza residua sulla battigia.
@export_range(0.0, 1.0) var shore_min_multiplier: float = 0.25

@export_group("Onda 1")
@export var wave_1_direction_deg: float = -90.0
@export var wave_1_amplitude: float = 0.22
@export var wave_1_length: float = 14.0
@export var wave_1_speed: float = 3.0

@export_group("Onda 2")
@export var wave_2_direction_deg: float = -55.0
@export var wave_2_amplitude: float = 0.12
@export var wave_2_length: float = 8.0
@export var wave_2_speed: float = 2.4

@export_group("Onda 3")
@export var wave_3_direction_deg: float = -130.0
@export var wave_3_amplitude: float = 0.06
@export var wave_3_length: float = 4.5
@export var wave_3_speed: float = 1.8

## Moltiplicatore del meteo dinamico (GDD § Navigazione), pilotato dal
## nodo Weather: 1 = calmo, sale col mare mosso sopra le zone statiche.
var weather_multiplier: float = 1.0

## Tetto dell'array harbor_calms nello shader del mare (2 città lontane +
## le isole di rifornimento neutrali della traversata, roadmap B4).
const MAX_HARBORS: int = 8

## Rade calme delle città lontane (roadmap B4): i nodi nel gruppo
## "calm_harbors" (le City) spengono il mare grosso in un cerchio intorno
## a sé, così l'attracco lontano da casa resta gestibile. xy = centro,
## z = raggio, w = attiva. Raccolte una volta a scena montata.
var _harbors := PackedVector4Array()

var _time: float = 0.0
var _grid_step: float = 2.5

@onready var _material: ShaderMaterial = material_override as ShaderMaterial


func _ready() -> void:
	var plane := mesh as PlaneMesh
	if plane != null:
		_grid_step = plane.size.x / float(plane.subdivide_width + 1)
	# Le città sono sorelle nella scena main: si raccolgono a fine setup.
	refresh_harbors.call_deferred()


## Rilegge il gruppo "calm_harbors" (nodi con harbor_radius). Da
## richiamare se una rada nasce o sparisce a runtime.
func refresh_harbors() -> void:
	_harbors.clear()
	if not is_inside_tree():
		return
	for node in get_tree().get_nodes_in_group(&"calm_harbors"):
		var harbor := node as Node3D
		if harbor == null or _harbors.size() >= MAX_HARBORS:
			continue
		var radius: float = harbor.get(&"harbor_radius")
		_harbors.append(Vector4(harbor.global_position.x, harbor.global_position.z, radius, 1.0))


func _process(delta: float) -> void:
	_time += delta
	_update_uniforms()
	if follow_target != null:
		global_position.x = snappedf(follow_target.global_position.x, _grid_step)
		var target_z := snappedf(follow_target.global_position.z, _grid_step)
		if follow_target.global_position.z <= follow_free_z:
			target_z = minf(target_z, follow_z_max)
		global_position.z = target_z


func get_height(world_pos: Vector3) -> float:
	var p := Vector2(world_pos.x, world_pos.z)
	return (_sine(p, wave_1_direction_deg, wave_1_amplitude, wave_1_length, wave_1_speed) \
		+ _sine(p, wave_2_direction_deg, wave_2_amplitude, wave_2_length, wave_2_speed) \
		+ _sine(p, wave_3_direction_deg, wave_3_amplitude, wave_3_length, wave_3_speed)) \
		* state_multiplier(world_pos)


## Distanza dalla linea di costa, positiva verso il largo.
func shore_distance(world_pos: Vector3) -> float:
	return world_pos.z - shore_z


## Replica di sea_state nello shader: le due copie vanno tenute allineate.
func state_multiplier(world_pos: Vector3) -> float:
	var d := shore_distance(world_pos)
	var open_amp := lerpf(open_base_multiplier, open_far_multiplier,
		clampf((d - medium_width) / maxf(open_far_distance - medium_width, 1.0), 0.0, 1.0))
	var m: float = lerpf(calm_multiplier, medium_multiplier,
		smoothstep(calm_width - zone_blend * 0.5, calm_width + zone_blend * 0.5, d))
	m = lerpf(m, open_amp,
		smoothstep(medium_width - zone_blend * 0.5, medium_width + zone_blend * 0.5, d))
	m *= lerpf(shore_min_multiplier, 1.0, smoothstep(0.0, shore_lap_distance, d))
	if wind_field != null:
		m *= wind_field.wind_multiplier(world_pos)
	# Dentro una rada il mare torna alle acque calme, meteo e vento
	# compresi: attraccare a una città lontana non è mai una lotteria.
	return lerpf(m * weather_multiplier, calm_multiplier, harbor_calm01(world_pos))


## Quanto il punto è protetto da una rada cittadina: 0 in mare libero,
## 1 nel cuore della rada. Stesso falloff del loop harbor_calms nello shader.
func harbor_calm01(world_pos: Vector3) -> float:
	var p := Vector2(world_pos.x, world_pos.z)
	var best := 0.0
	for harbor in _harbors:
		if harbor.w <= 0.0 or harbor.z <= 0.0:
			continue
		best = maxf(best, 1.0 - smoothstep(harbor.z * 0.45, harbor.z, p.distance_to(Vector2(harbor.x, harbor.y))))
	return best


## Quanto il mare scuote in un punto (zona × meteo): la barca lo usa per
## la destabilizzazione, in scala con state_multiplier.
func agitation(world_pos: Vector3) -> float:
	return state_multiplier(world_pos)


## Direzione orizzontale dell'onda principale: le spinte del mare mosso
## seguono lei. Con le onde che corrono verso la spiaggia, la tempesta
## spinge verso la costa — cioè verso la salvezza, mai al largo.
func wave_push_direction() -> Vector3:
	var dir := Vector2.from_angle(deg_to_rad(wave_1_direction_deg))
	return Vector3(dir.x, 0.0, dir.y)


## 0 = calme, 1 = medie, 2 = mare aperto (per HUD e spawn delle boe).
## Le rade delle città contano come acque calme: l'HUD lo dice e gli
## eventi casuali non scattano sul molo di un porto lontano.
func zone_index(world_pos: Vector3) -> int:
	var harbor := harbor_calm01(world_pos)
	if harbor >= 0.6:
		return 0
	if harbor >= 0.25:
		return 1
	var d := shore_distance(world_pos)
	if d < calm_width:
		return 0
	if d < medium_width:
		return 1
	return 2


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
	_material.set_shader_parameter("shore_z", shore_z)
	_material.set_shader_parameter("calm_width", calm_width)
	_material.set_shader_parameter("medium_width", medium_width)
	_material.set_shader_parameter("zone_blend", zone_blend)
	_material.set_shader_parameter("zone_amps",
		Vector4(calm_multiplier, medium_multiplier, open_base_multiplier, open_far_multiplier))
	_material.set_shader_parameter("open_far_distance", open_far_distance)
	_material.set_shader_parameter("shore_lap_distance", shore_lap_distance)
	_material.set_shader_parameter("shore_min_multiplier", shore_min_multiplier)
	_material.set_shader_parameter("weather_mult", weather_multiplier)
	_material.set_shader_parameter("harbor_calms", _harbors_padded())
	if wind_field != null:
		_material.set_shader_parameter("wind_cells", wind_field.cells_packed())
		_material.set_shader_parameter("wind_strength", wind_field.strength)


## Rade impacchettate per lo shader: sempre lunghe MAX_HARBORS (pad a zero).
func _harbors_padded() -> PackedVector4Array:
	var packed := _harbors.duplicate()
	while packed.size() < MAX_HARBORS:
		packed.append(Vector4.ZERO)
	return packed


func _wave_vec(dir_deg: float, amplitude: float, length: float) -> Vector4:
	var dir := Vector2.from_angle(deg_to_rad(dir_deg))
	return Vector4(dir.x, dir.y, amplitude, length)
