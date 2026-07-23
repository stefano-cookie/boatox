class_name WindField
extends Node

## Celle di vento del mare aperto (feedback playtest M3): aree circolari
## che derivano lentamente e si rafforzano/spengono nel tempo. Dentro una
## cella attiva il mare si ingrossa davvero: la Sea moltiplica la sua
## agitazione per wind_multiplier(pos), quindi guida, danni e onde dello
## shader reagiscono tutti insieme. La matematica del falloff qui e in
## sea.gdshader (wind_cells) va tenuta allineata.

## Numero di celle gestite (lo shader ne accetta al massimo MAX_CELLS).
@export_range(1, 12) var cell_count: int = 10
## Sul mare grande le celle sono più larghe: da schivare con una virata
## vera, non con un colpo di timone.
@export var radius_min: float = 120.0
@export var radius_max: float = 320.0
## Moltiplicatore extra di agitazione al centro di una cella a intensità 1.
@export var strength: float = 0.9
## Velocità di deriva del centro cella, in m/s.
@export var drift_speed: float = 1.2
## Secondi tra un cambio di intensità bersaglio e l'altro.
@export var retarget_min: float = 25.0
@export var retarget_max: float = 55.0
## Secondi perché una cella passi da spenta a piena (e viceversa).
@export var ramp_time: float = 14.0
## Probabilità che il nuovo bersaglio sia "cella spenta".
@export_range(0.0, 1.0) var off_chance: float = 0.35

@export_group("Area (coordinate mondo)")
## Le celle vivono solo al largo: coi raggi massimi il loro bordo non
## tocca mai le acque calme (costa = sicurezza, GDD pillar 2). Dal mare
## grande di B4 l'area copre tutta la traversata verso le due città —
## le rade cittadine spengono comunque le celle che ci finiscono sopra.
@export var area_half_width: float = 2300.0
@export var area_z_min: float = 200.0
@export var area_z_max: float = 3400.0

## Quota del raggio dove il falloff inizia a scendere (come nello shader).
const FALLOFF_INNER: float = 0.35
## Tetto dell'array di celle nello shader del mare.
const MAX_CELLS: int = 12

## Una voce per cella: pos (Vector2 xz), radius, intensity, target,
## timer, drift (Vector2).
var _cells: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(&"wind_field")
	for i in mini(cell_count, MAX_CELLS):
		var cell := {
			"pos": Vector2(_rng.randf_range(-area_half_width, area_half_width),
				_rng.randf_range(area_z_min, area_z_max)),
			"radius": _rng.randf_range(radius_min, radius_max),
			"intensity": 0.0,
			"target": 0.0,
			"timer": _rng.randf_range(0.0, retarget_max),
			"drift": Vector2.from_angle(_rng.randf_range(0.0, TAU)) * drift_speed,
		}
		_cells.append(cell)
	# Un paio di celle già attive all'avvio: il largo non parte mai piatto.
	for i in mini(2, _cells.size()):
		_cells[i]["target"] = _rng.randf_range(0.6, 1.0)
		_cells[i]["intensity"] = _cells[i]["target"] * 0.5


func _process(delta: float) -> void:
	for cell in _cells:
		cell["timer"] -= delta
		if cell["timer"] <= 0.0:
			_retarget(cell)
		cell["intensity"] = move_toward(cell["intensity"], cell["target"],
			delta / maxf(ramp_time, 0.1))
		var pos: Vector2 = cell["pos"] + cell["drift"] * delta
		# Rimbalzo morbido ai bordi dell'area: la cella non esce dalla baia.
		var drift: Vector2 = cell["drift"]
		if absf(pos.x) > area_half_width:
			drift.x = -drift.x
			pos.x = clampf(pos.x, -area_half_width, area_half_width)
		if pos.y < area_z_min or pos.y > area_z_max:
			drift.y = -drift.y
			pos.y = clampf(pos.y, area_z_min, area_z_max)
		cell["pos"] = pos
		cell["drift"] = drift


## Moltiplicatore di agitazione nel punto: 1 fuori dalle celle, fino a
## 1 + strength al centro di una cella piena. Replica del loop wind_cells
## nello shader del mare.
func wind_multiplier(world_pos: Vector3) -> float:
	var p := Vector2(world_pos.x, world_pos.z)
	var total := 0.0
	for cell in _cells:
		var intensity: float = cell["intensity"]
		if intensity <= 0.0:
			continue
		var radius: float = cell["radius"]
		var fall := 1.0 - smoothstep(radius * FALLOFF_INNER, radius, p.distance_to(cell["pos"]))
		total += intensity * fall
	return 1.0 + strength * total


## Celle impacchettate per lo shader e la minimappa: xy = centro,
## z = raggio, w = intensità. Sempre lunga MAX_CELLS (padding a zero).
func cells_packed() -> PackedVector4Array:
	var packed := PackedVector4Array()
	for cell in _cells:
		var pos: Vector2 = cell["pos"]
		packed.append(Vector4(pos.x, pos.y, cell["radius"], cell["intensity"]))
	while packed.size() < MAX_CELLS:
		packed.append(Vector4.ZERO)
	return packed


func _retarget(cell: Dictionary) -> void:
	cell["timer"] = _rng.randf_range(retarget_min, retarget_max)
	if _rng.randf() < off_chance:
		cell["target"] = 0.0
	else:
		cell["target"] = _rng.randf_range(0.5, 1.0)
	# Se la cella si è spenta del tutto, rinasce altrove con altro raggio.
	if cell["intensity"] <= 0.01 and cell["target"] > 0.0:
		cell["pos"] = Vector2(_rng.randf_range(-area_half_width, area_half_width),
			_rng.randf_range(area_z_min, area_z_max))
		cell["radius"] = _rng.randf_range(radius_min, radius_max)
	cell["drift"] = cell["drift"].rotated(_rng.randf_range(-0.8, 0.8))
