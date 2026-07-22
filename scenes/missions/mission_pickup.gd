class_name MissionPickup
extends Area3D

## Il pacco/relitto galleggiante delle missioni di recupero (roadmap A1):
## il World lo mette in acqua sul punto della missione e lo toglie quando
## non serve più (raccolto, missione chiusa). Si raccoglie passandoci
## sopra con la barca, come boe e taniche; la bandierina arancione lo fa
## riconoscere da lontano.

## Assegnata dal World: serve per galleggiare sulle onde.
var sea: Sea

var _bob_time: float = 0.0

@onready var _visual: Node3D = $Visual


func _ready() -> void:
	add_to_group(&"mission_pickups")
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if sea == null:
		return
	_bob_time += delta
	_visual.position.y = sea.get_height(global_position) + 0.05
	_visual.rotation.y += 0.3 * delta
	_visual.rotation.z = sin(_bob_time * 1.1) * 0.1


## La raccolta avanza la missione in GameState; a rimuovere il nodo ci
## pensa il World sul segnale mission_changed (niente doppia gestione).
func _on_body_entered(body: Node3D) -> void:
	if body is Boat and GameState.mission_pickup_pending():
		GameState.mission_pickup_collected()
