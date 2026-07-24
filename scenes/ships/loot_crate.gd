class_name LootCrate
extends Area3D

## Bottino galleggiante mollato da una nave affondata (roadmap B1): si
## raccoglie passandoci sopra con la barca, come boe e taniche (stesso
## pattern). Il valore dipende dalla fascia di mare dell'affondamento
## (tier, vedi GameState.LOOT_ITEM): prede migliori dove il mare è più
## duro. Da R6 la cassa può portare un item qualsiasi per id (merci e
## tesori di relitti e prede): il coperchio prende il colore dell'item,
## così si capisce da lontano cosa galleggia. A stiva piena resta a galla;
## dopo un po' il mare se lo riprende.

## Secondi di vita in acqua prima di sparire (con dissolvenza).
const LIFETIME: float = 180.0
const FADE_TIME: float = 6.0

## Impostati da chi lo spawna (Ship._drop_loot, Wreck). Se item_id è
## valorizzato la cassa porta quell'item, altrimenti il bottino del tier.
var tier: int = 0
var item_id: StringName = &""
var sea: Sea

var _age: float = 0.0
var _bob_time: float = 0.0

@onready var _visual: Node3D = $Visual


func _ready() -> void:
	add_to_group(&"loot_crates")
	body_entered.connect(_on_body_entered)
	var def := GameState.item_def(item_id) if item_id != &"" else null
	var lid := $Visual/Lid as MeshInstance3D
	# I materiali della scena sono sottorisorse condivise tra le istanze:
	# si duplicano prima di tingerli, o una cassa colora tutte le altre.
	var mat := (lid.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
	lid.material_override = mat
	if def != null:
		mat.albedo_color = def.color
	# Tesori e tier ricco luccicano: si capisce da lontano che la
	# deviazione vale.
	if tier >= 2 or (def != null and def.category == ItemDefinition.Category.TREASURE):
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = 0.6


func _process(delta: float) -> void:
	_bob_time += delta
	_age += delta
	if sea != null:
		_visual.position.y = sea.get_height(global_position) + 0.05
	_visual.rotation.y += 0.4 * delta
	_visual.rotation.z = sin(_bob_time * 1.3) * 0.12
	if _age >= LIFETIME:
		var left := LIFETIME + FADE_TIME - _age
		if left <= 0.0:
			queue_free()
		else:
			_visual.scale = Vector3.ONE * maxf(left / FADE_TIME, 0.01)


func _on_body_entered(body: Node3D) -> void:
	if not body is Boat:
		return
	var collected := GameState.collect_item(item_id) if item_id != &"" \
		else GameState.collect_loot(tier)
	if collected:
		queue_free()
