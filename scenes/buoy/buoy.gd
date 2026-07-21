class_name Buoy
extends Area3D

## Punto boa (GDD § Boe): la boa è un item che si raccoglie al passaggio,
## finisce in stiva e si vende al porto. Tre tipologie legate al rischio
## della zona: gialla in acque tranquille, rossa ai margini degli scogli,
## blu rarissima tra gli scogli. A ogni ciclo di respawn il punto ritenta
## lo spawn con la probabilità della sua tipologia (valori in GameState).

@export_enum("Gialla", "Rossa", "Blu") var type: int = 0

## Assegnata da chi la spawna: serve per galleggiare sulle onde.
var sea: Sea

var _active: bool = false

@onready var _visual: Node3D = $Visual
@onready var _body_mesh: MeshInstance3D = $Visual/Body

# Chiavi allineate a GameState.BuoyType (autoload non usabile in const).
const _COLORS: Dictionary[int, Color] = {
	0: Color(1.0, 0.8, 0.1),
	1: Color(0.85, 0.2, 0.15),
	2: Color(0.2, 0.4, 1.0),
}


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _COLORS[type]
	mat.roughness = 0.7
	if type == GameState.BuoyType.BLUE:
		mat.emission_enabled = true
		mat.emission = _COLORS[type]
		mat.emission_energy_multiplier = 0.7
		_visual.scale = Vector3.ONE * 1.15
	_body_mesh.material_override = mat
	_set_present(false)
	_try_spawn()


func _process(_delta: float) -> void:
	if sea != null and visible:
		_visual.position.y = sea.get_height(global_position)


## Ritenta finché il tiro di probabilità non riesce; le gialle (100%)
## appaiono subito, una blu può restare assente per diversi cicli.
func _try_spawn() -> void:
	while is_inside_tree():
		if randf() <= GameState.BUOY_SPAWN_CHANCE[type]:
			_set_present(true)
			return
		await get_tree().create_timer(GameState.BUOY_RESPAWN[type]).timeout


func _set_present(present: bool) -> void:
	_active = present
	visible = present
	set_deferred("monitoring", present)


func _on_body_entered(body: Node3D) -> void:
	if not _active or not body is Boat:
		return
	# A stiva piena la boa resta in acqua: il limite è il senso
	# dell'upgrade stiva.
	if not GameState.collect_buoy(type):
		return
	_set_present(false)
	await get_tree().create_timer(GameState.BUOY_RESPAWN[type]).timeout
	if is_inside_tree():
		_try_spawn()
