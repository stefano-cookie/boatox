extends Node3D

## La flottiglia di pesca di Bova (roadmap B2): tante barche quante ne
## concede il Molo grande (Town.fleet_boat_count), che fanno la spola tra
## la rada (posizione di questo nodo, accanto allo slot del molo) e le
## zone di pesca conosciute del World. Figlio del World in world.tscn;
## si risincronizza su Town.town_changed.

const HULL_COLORS: Array[Color] = [
	Color(0.85, 0.85, 0.8), Color(0.4, 0.55, 0.7),
	Color(0.75, 0.45, 0.3), Color(0.45, 0.6, 0.4),
]

var _boats: Array[FleetBoat] = []


func _ready() -> void:
	Town.town_changed.connect(_sync)
	# Le zone di pesca nascono nel _ready del World (dopo il nostro):
	# la prima sincronizzazione aspetta che esistano.
	_sync.call_deferred()


func _sync() -> void:
	var target := Town.fleet_boat_count()
	if target == _boats.size():
		return
	var world := get_parent() as World
	if world == null:
		return
	while _boats.size() > target:
		_boats.pop_back().queue_free()
	while _boats.size() < target:
		var boat := FleetBoat.new()
		boat.sea = world.sea
		boat.hull_color = HULL_COLORS[_boats.size() % HULL_COLORS.size()]
		# Ormeggio sfalsato davanti al molo, una zona di pesca a testa.
		boat.home = global_position + Vector3(float(_boats.size()) * 4.0 - 4.0, 0.0, 6.0)
		boat.spot = _pick_spot(world, _boats.size())
		add_child(boat)
		_boats.append(boat)


## Zona di pesca assegnata alla barca: si distribuiscono su quelle del
## World (le "zone conosciute"); se ancora non esistono, un punto di
## ripiego nelle acque calme davanti al porto.
func _pick_spot(world: World, index: int) -> Vector3:
	var spots := world.fishing_positions()
	if spots.is_empty():
		return global_position + Vector3(20.0 + float(index) * 15.0, 0.0, 40.0)
	var spot := spots[index % spots.size()]
	# Le barche lavorano al margine della zona, non sopra gli anelli del
	# minigioco del giocatore.
	return spot + Vector3(18.0, 0.0, 0.0)
