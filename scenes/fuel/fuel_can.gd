class_name FuelCan
extends Area3D

## Tanica di benzina alla deriva (roadmap M3): al passaggio riempie il
## serbatoio di GameState.FUEL_CAN_LITERS litri. Ogni punto ritenta lo
## spawn a ogni ciclo con probabilità bassa (5%): vederne una è un colpo
## di fortuna, non una fonte affidabile. Feedback playtest round 2: al
## massimo UNA tanica attiva sull'intera mappa alla volta — la guardia
## sul gruppo &fuel_cans impedisce l'accumulo (prima se ne sommavano ~22).

## Assegnata da chi la spawna: serve per galleggiare sulle onde.
var sea: Sea

var _active: bool = false
var _bob_time: float = 0.0

@onready var _visual: Node3D = $Visual


func _ready() -> void:
	add_to_group(&"fuel_cans")
	body_entered.connect(_on_body_entered)
	_set_present(false)
	_try_spawn()


func _process(delta: float) -> void:
	if sea == null or not visible:
		return
	_bob_time += delta
	_visual.position.y = sea.get_height(global_position)
	# Ondeggia piano su sé stessa: si distingue dalle boe anche da lontano.
	_visual.rotation.y += 0.4 * delta
	_visual.rotation.z = sin(_bob_time * 1.3) * 0.12


func is_active() -> bool:
	return _active


## Vero se una qualsiasi tanica è già presente in acqua: il punto attende
## che quella venga raccolta prima di riprovare (max 1 attiva sulla mappa).
func _any_active() -> bool:
	for node in get_tree().get_nodes_in_group(&"fuel_cans"):
		var can := node as FuelCan
		if can != null and can.is_active():
			return true
	return false


func _try_spawn() -> void:
	while is_inside_tree():
		if not _any_active() and randf() <= GameState.FUEL_CAN_SPAWN_CHANCE:
			_set_present(true)
			return
		await get_tree().create_timer(GameState.FUEL_CAN_RESPAWN).timeout


func _set_present(present: bool) -> void:
	_active = present
	visible = present
	set_deferred("monitoring", present)


func _on_body_entered(body: Node3D) -> void:
	if not _active or not body is Boat:
		return
	GameState.add_fuel(GameState.FUEL_CAN_LITERS)
	# Il feedback passa dai toast di raccolta dell'HUD (roadmap R2), non più
	# dalla scritta centrale, riservata agli avvisi di gioco.
	GameState.fuel_collected.emit(GameState.FUEL_CAN_LITERS)
	_set_present(false)
	await get_tree().create_timer(GameState.FUEL_CAN_RESPAWN).timeout
	if is_inside_tree():
		_try_spawn()
