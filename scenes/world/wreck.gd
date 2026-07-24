class_name Wreck
extends StaticBody3D

## Relitto semisommerso del mare aperto (roadmap R6): una carcassa di nave
## incagliata, sparsa a caso al largo a ogni partita e rivelata dal radar
## come le boe. Avvicinandosi, il relitto molla in acqua le sue casse —
## merci comuni e, con fortuna, un tesoro (probabilità scalata dal fattore
## difficoltà del punto: i relitti più lontani e in acque più dure
## nascondono di più). Riusa le casse galleggianti del bottino (LootCrate).
## Una volta saccheggiato resta lì come paesaggio.

const LOOT_SCENE: PackedScene = preload("res://scenes/ships/loot_crate.tscn")

## Distanza dalla barca a cui il relitto molla le casse: abbastanza vicino
## da dover arrivare "sul punto", abbastanza largo da non doverci sbattere.
@export var loot_radius: float = 45.0
## Raggio dell'anello di casse attorno allo scafo.
@export var crate_ring_min: float = 8.0
@export var crate_ring_max: float = 16.0

## Impostati dal World allo spawn.
var sea: Sea
var boat: Boat

var _looted: bool = false
## Accumulatore per non fare il check distanza ogni frame.
var _check_left: float = 0.0

@onready var _visual: Node3D = $Visual


func _ready() -> void:
	add_to_group(&"wrecks")
	_build_visual()


func _process(delta: float) -> void:
	if _looted or boat == null:
		return
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = 0.5
	if global_position.distance_to(boat.global_position) <= loot_radius:
		_spill_crates()


## Vero finché le casse non sono state mollate: la minimappa lo marca
## come punto d'interesse, dopo resta solo la carcassa.
func has_loot() -> bool:
	return not _looted


## Le casse del carico affiorano in un anello attorno allo scafo: merci
## dal pool dei relitti più l'eventuale tesoro (vedi costanti R6).
func _spill_crates() -> void:
	_looted = true
	var count := randi_range(GameState.WRECK_CRATES_MIN, GameState.WRECK_CRATES_MAX)
	var t := (GameState.difficulty_multiplier(global_position, sea) - 1.0) \
		/ (GameState.DIFFICULTY_REWARD_MAX - 1.0)
	var treasure_chance := lerpf(GameState.WRECK_TREASURE_CHANCE_MIN,
		GameState.WRECK_TREASURE_CHANCE_MAX, clampf(t, 0.0, 1.0))
	for i in count:
		var crate := LOOT_SCENE.instantiate() as LootCrate
		if randf() < treasure_chance:
			crate.item_id = GameState.pick_weighted_item(GameState.TREASURE_WEIGHTS)
		else:
			crate.item_id = GameState.WRECK_GOODS[randi() % GameState.WRECK_GOODS.size()]
		crate.sea = sea
		get_parent().add_child(crate)
		var angle := TAU * float(i) / float(count) + randf_range(-0.3, 0.3)
		crate.global_position = global_position + Vector3(cos(angle), 0.0, sin(angle)) \
			* randf_range(crate_ring_min, crate_ring_max)
	GameState.post_notice("Un relitto! Il carico affiora tra le onde")


## La carcassa: scafo spezzato in due tronconi inclinati, un moncone
## d'albero storto. Legno scurito dal mare, mezzo sotto il pelo dell'acqua.
func _build_visual() -> void:
	var wood := Ship.flat(Color(0.3, 0.26, 0.22))
	var dark := Ship.flat(Color(0.22, 0.19, 0.17))
	# Troncone di prua: emerge inclinato.
	var bow := MeshInstance3D.new()
	var bow_mesh := BoxMesh.new()
	bow_mesh.size = Vector3(2.6, 1.8, 5.5)
	bow.mesh = bow_mesh
	bow.material_override = wood
	bow.position = Vector3(0.0, -0.4, -3.2)
	bow.rotation.x = deg_to_rad(-18.0)
	bow.rotation.z = deg_to_rad(8.0)
	_visual.add_child(bow)
	# Troncone di poppa, più affondato e sbandato dall'altra parte.
	var stern := MeshInstance3D.new()
	var stern_mesh := BoxMesh.new()
	stern_mesh.size = Vector3(2.6, 1.6, 4.5)
	stern.mesh = stern_mesh
	stern.material_override = dark
	stern.position = Vector3(0.6, -0.85, 2.8)
	stern.rotation.x = deg_to_rad(12.0)
	stern.rotation.z = deg_to_rad(-14.0)
	_visual.add_child(stern)
	# Moncone d'albero storto sulla prua: la sagoma che si vede da lontano.
	var mast := MeshInstance3D.new()
	var mast_mesh := BoxMesh.new()
	mast_mesh.size = Vector3(0.3, 3.4, 0.3)
	mast.mesh = mast_mesh
	mast.material_override = dark
	mast.position = Vector3(-0.3, 1.2, -3.4)
	mast.rotation.z = deg_to_rad(22.0)
	mast.rotation.x = deg_to_rad(-10.0)
	_visual.add_child(mast)
