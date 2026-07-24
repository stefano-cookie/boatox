class_name World
extends Node3D

## La baia di gioco: la costa a nord (scena Coast), isole e porto
## piazzati a mano, scogli e punti boa sparsi proceduralmente con seed
## fisso (stessa mappa a ogni avvio, densità regolabile dall'Inspector).
## Le boe seguono le fasce di mare della Sea (GDD pillar 2): gialle
## nelle acque calme sotto costa, rosse nelle medie, blu nelle mosse al
## largo — dove stanno anche isole e campi di scogli. Gestisce anche il
## confine mappa (countdown e recupero), l'allarme tempesta e il traino
## a scafo zero.

const BUOY_SCENE: PackedScene = preload("res://scenes/buoy/buoy.tscn")
const ROCK_SCENE: PackedScene = preload("res://scenes/world/rock.tscn")
const FUEL_CAN_SCENE: PackedScene = preload("res://scenes/fuel/fuel_can.tscn")
const FISHING_ZONE_SCENE: PackedScene = preload("res://scenes/fishing/fishing_zone.tscn")
const MISSION_PICKUP_SCENE: PackedScene = preload("res://scenes/missions/mission_pickup.tscn")
const RACE_COURSE_SCENE: PackedScene = preload("res://scenes/race/race_course.tscn")
const WRECK_SCENE: PackedScene = preload("res://scenes/world/wreck.tscn")

@export var boat: Boat
@export var sea: Sea

@export_group("Confini")
## Distanza massima dalla costa prima del countdown di recupero: dal
## mare grande di B4 abbraccia anche le due città lontane.
@export var bounds_depth: float = 4000.0
## Mezza larghezza del mare giocabile.
@export var bounds_half_width: float = 2600.0
## Secondi per rientrare in zona prima del recupero al porto.
@export var escape_countdown: float = 10.0
## Profondità della baia di Bova, il cuore dettagliato: boe, taniche,
## zone di pesca e navi "di casa" restano qui dentro (era il vecchio
## confine mappa dell'alpha). Oltre inizia la traversata di B4.
@export var bay_depth: float = 700.0

@export_group("Affondamento")
## A scafo zero oltre le acque medie la barca affonda (feedback playtest
## M3): carico perso e recupero a pagamento. Sotto costa resta il traino.
@export var sink_time: float = 2.0

@export_group("Sparpagliamento")
@export var scatter_seed: int = 7
## Feedback playtest round 2: le gialle intasavano la mappa (28 → 14).
@export var yellow_buoy_count: int = 14
@export var red_point_count: int = 18
## Boe rosse al largo (roadmap R3): una banda di riempitivo tra le blu del
## mare aperto, così spingersi fuori non è mai un vuoto di raccolta.
@export var open_red_point_count: int = 14
@export var blue_point_count: int = 24
## Punti tanica di benzina, sparsi su tutta la baia (spawn al 5%).
@export var fuel_point_count: int = 22
## Zone di pesca per fascia di mare (GDD beta: 2-3 zone in tutto).
@export var fishing_zones_per_band: int = 1

@export_group("Mare aperto ricco (roadmap R3)")
## Zone di pesca extra al largo profondo, piazzate a caso a ogni partita
## (RNG randomizzato, non il seed fisso): l'attività al largo non è sempre
## nello stesso punto. Tier 2 (specie pregiate).
@export var open_activity_zones: int = 2
## Spot di gara procedurali seminati in punti casuali del largo (roadmap
## R3): tracciato generato attorno al punto, IA aggressive, premi ricchi.
@export var open_race_count: int = 1
## Premio base degli spot di gara al largo, poi scalato dal fattore
## difficoltà del punto (distanza + agitazione).
@export var open_race_prize_base: float = 1.6
## Relitti semisommersi (roadmap R6): nel mare aperto della baia e sparsi
## sulla traversata di B4. Posizioni casuali a ogni partita, rivelati dal
## radar; avvicinandosi mollano casse di merci e tesori.
@export var wreck_count: int = 2
@export var route_wreck_count: int = 3

@export_group("Navi (roadmap B1)")
## Mercantili e predoni della baia di Bova (ShipDirector di casa).
@export var merchant_count: int = 2
@export var raider_count: int = 2
## Navi della traversata (B4): la rotta non è più deserta — mercantili da
## predare e predoni di pattuglia riempiono il mare aperto tra Bova e le
## città (feedback: "il mare è molto vuoto"). Il bottino si rivende agli
## scali di rifornimento senza tornare a casa.
@export var crossing_merchant_count: int = 3
@export var crossing_raider_count: int = 2
## Navi nelle acque di ciascuna città (entrambe ostili ora): niente
## mercantili amici, solo predoni al loro soldo che pattugliano la rada.
@export var city_merchant_count: int = 2
@export var city_raider_count: int = 2
## Mezzo lato del recinto navale intorno a ogni città.
@export var city_waters_radius: float = 500.0

@export_group("Traversata (roadmap B4)")
## Taniche e boe blu sparse sulla rotta tra Bova e le città: il pieno di
## fortuna e il bottino che ripagano il viaggio.
@export var route_fuel_count: int = 20
@export var route_buoy_count: int = 16
## Le boe vengono campionate con |x| entro questo limite, per non
## finire dentro i promontori.
@export var scatter_half_width: float = 255.0
## Al largo i promontori sono lontani: si campiona più largo, per non
## diluire la densità della baia profonda.
@export var scatter_half_width_open: float = 400.0
@export var rocks_per_field: int = 9
@export var rock_field_radius: float = 13.0

var _rng := RandomNumberGenerator.new()
## RNG separato per i punti delle missioni: offerte diverse a ogni
## partita, senza consumare la sequenza del seed fisso dello scatter.
var _mission_rng := RandomNumberGenerator.new()
var _rock_positions: Array[Vector3] = []
var _buoy_positions: Array[Vector3] = []
var _fishing_positions: Array[Vector3] = []
## -1 quando la barca è dentro i confini.
var _outside_elapsed: float = -1.0
var _storm_alarmed: bool = false
var _sinking: bool = false

@onready var _islands: Node3D = $Islands
@onready var _rock_fields: Node3D = $RockFields
@onready var _port: Port = $Port
@onready var _cities: Node3D = $Cities


func _ready() -> void:
	add_to_group(&"world")
	_rng.seed = scatter_seed
	_mission_rng.randomize()
	# Ogni spot di gara (sotto costa + al largo) ha bisogno della Sea per
	# IA e classifica: i figli sono già in gruppo (add_to_group in _ready).
	for node in get_tree().get_nodes_in_group(&"race_course"):
		(node as RaceCourse).sea = sea
	# L'NPC del nipote galleggia sulle onde come le zone di pesca.
	for node in get_tree().get_nodes_in_group(&"rescue_npc"):
		(node as RescueNpc).sea = sea
	GameState.hull_depleted.connect(_on_hull_depleted)
	GameState.mission_changed.connect(_sync_mission_pickup)
	for field: Node3D in _rock_fields.get_children():
		_spawn_rock_field(field.global_position)
	# Le zone di pesca prima delle boe: prendono posto pulito e le boe
	# non finiscono dentro gli anelli.
	_spawn_fishing_zones()
	_spawn_open_activity_zones()
	# I relitti prima delle boe, così anche loro prendono posto pulito.
	_spawn_wrecks()
	_spawn_zone_buoys()
	_spawn_route_pickups()
	_spawn_ship_directors()
	_spawn_open_races()
	# Missione di recupero già in corso nel salvataggio: il pacco torna in acqua.
	_sync_mission_pickup()


## Le navi del mare (roadmap B1, allargato in B4): un direttore per zona
## — la baia di casa, la traversata di mezzo e le acque delle due città,
## ognuna con le navi della sua fazione.
func _spawn_ship_directors() -> void:
	_add_director(
		Vector3(-scatter_half_width_open, 0.0, sea.shore_z),
		Vector3(scatter_half_width_open, 0.0, sea.shore_z + bay_depth - 60.0),
		merchant_count, raider_count, &"")
	_add_director(
		Vector3(-bounds_half_width + 400.0, 0.0, sea.shore_z + bay_depth + 200.0),
		Vector3(bounds_half_width - 400.0, 0.0, sea.shore_z + bounds_depth - 700.0),
		crossing_merchant_count, crossing_raider_count, &"")
	for node in _cities.get_children():
		var city := node as City
		if city == null:
			continue
		var center := city.global_position
		var is_hostile := Diplomacy.is_hostile(_city_faction(city))
		_add_director(
			center - Vector3(city_waters_radius, 0.0, city_waters_radius),
			center + Vector3(city_waters_radius, 0.0, city_waters_radius),
			0 if is_hostile else city_merchant_count,
			city_raider_count if is_hostile else 0,
			_city_faction(city))


## La fazione di una città è quella del suo porto (l'istanza Port più
## vicina): un posto solo per la verità, niente doppioni da disallineare.
func _city_faction(city: City) -> StringName:
	var best: Port = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group(&"ports"):
		var port := node as Port
		if port == null:
			continue
		var d := port.global_position.distance_to(city.global_position)
		if d < best_d:
			best_d = d
			best = port
	return best.faction if best != null else &""


func _add_director(area_min: Vector3, area_max: Vector3,
		merchants: int, raiders: int, faction: StringName) -> void:
	var director := ShipDirector.new()
	director.sea = sea
	director.boat = boat
	director.area_min = area_min
	director.area_max = area_max
	director.merchant_count = merchants
	director.raider_count = raiders
	director.faction_override = faction
	add_child(director)


func _physics_process(delta: float) -> void:
	if boat == null or _sinking:
		return
	var pos := boat.global_position
	var outside := sea.shore_distance(pos) > bounds_depth or absf(pos.x) > bounds_half_width
	if outside:
		if _outside_elapsed < 0.0:
			_outside_elapsed = 0.0
		_outside_elapsed += delta
		var left := escape_countdown - _outside_elapsed
		boat.sink_amount = clampf(_outside_elapsed / escape_countdown, 0.0, 1.0)
		if left <= 0.0:
			_rescue_boat()
		else:
			GameState.set_danger("ACQUE PERICOLOSE! Torna indietro… %d" % ceili(left))
		return
	if _outside_elapsed >= 0.0:
		_outside_elapsed = -1.0
		boat.sink_amount = 0.0
		GameState.clear_danger()
	# Allarme tempesta: il mare sta danneggiando lo scafo (la logica del
	# danno vive nella barca, qui solo il messaggio — la priorità resta
	# al countdown fuori zona).
	if boat.storm_alarm():
		_storm_alarmed = true
		GameState.set_danger("TEMPESTA! Lo scafo sta cedendo: punta verso la costa!")
	elif _storm_alarmed:
		_storm_alarmed = false
		GameState.clear_danger()


# --- Dati per la minimappa ---------------------------------------------------

func port_position() -> Vector3:
	return _port.global_position


func map_islands() -> Array[Node]:
	var nodes := _islands.get_children()
	# Gli isolotti satellite delle città (le City sono Node3D, le isole
	# StaticBody3D: si distinguono da sole).
	for child in _cities.get_children():
		if child is StaticBody3D:
			nodes.append(child)
	# Gli scali di rifornimento della traversata: macchie di terra in
	# minimappa come gli isolotti.
	for node in get_tree().get_nodes_in_group(&"supply_islands"):
		nodes.append(node)
	return nodes


func map_rocks() -> Array[Vector3]:
	return _rock_positions


## Le zone di pesca della baia: la flottiglia di Bova (roadmap B2) ci
## manda le sue barche a lavorare.
func fishing_positions() -> Array[Vector3]:
	return _fishing_positions


# --- Missioni della bacheca (roadmap A1) -------------------------------------

## L'approdo che riceve le casse delle consegne (flag sul Port parametrico).
func delivery_landing() -> Port:
	for node in get_tree().get_nodes_in_group(&"ports"):
		var port := node as Port
		if port != null and port.is_delivery_target:
			return port
	return null


## Punto libero nella fascia tra d_min e d_max metri dalla costa, per i
## recuperi della bacheca. Vector3.INF se non trova posto. Vicino a costa
## campiona stretto (promontori), al largo si allarga, come le boe.
func sample_mission_point(d_min: float, d_max: float) -> Vector3:
	var half_width := scatter_half_width if d_max <= sea.medium_width else scatter_half_width_open
	for attempt in 40:
		var pos := Vector3(_mission_rng.randf_range(-half_width, half_width), 0.0,
			sea.shore_z + _mission_rng.randf_range(d_min, d_max))
		if _is_clear(pos):
			return pos
	return Vector3.INF


## Tiene il pacco galleggiante allineato allo stato della missione: in
## acqua sul punto finché c'è un recupero da fare, via in ogni altro caso
## (raccolto, consegnato, fallito, abbandonato).
func _sync_mission_pickup() -> void:
	var pickup := get_tree().get_first_node_in_group(&"mission_pickups") as MissionPickup
	if GameState.mission_pickup_pending():
		if pickup == null:
			var node := MISSION_PICKUP_SCENE.instantiate() as MissionPickup
			node.sea = sea
			add_child(node)
			node.global_position = GameState.mission_marker_position()
	elif pickup != null:
		pickup.queue_free()


## Scafo a zero: sotto costa arriva il traino, oltre le acque medie la
## barca affonda davvero — carico perso e recupero a pagamento (feedback
## playtest M3: è il rischio del mare aperto, GDD pillar 2).
func _on_hull_depleted() -> void:
	if _sinking:
		return
	if sea.shore_distance(boat.global_position) > sea.medium_width:
		_sink_boat.call_deferred()
	else:
		_tow_boat.call_deferred()


func _tow_boat() -> void:
	GameState.pay_tow()
	boat.reset_motion()
	boat.global_position = _port.tow_spawn_position()


## Piccola sequenza di affondamento (riusa il sink_amount del fuori
## zona), poi il recupero: niente teletrasporto secco a scafo zero.
func _sink_boat() -> void:
	_sinking = true
	boat.input_enabled = false
	boat.reset_motion()
	GameState.set_danger("LA BARCA AFFONDA!")
	var tween := create_tween()
	tween.tween_property(boat, "sink_amount", 1.0, sink_time)
	tween.tween_interval(0.6)
	tween.tween_callback(_finish_sinking)


func _finish_sinking() -> void:
	_sinking = false
	boat.sink_amount = 0.0
	boat.reset_motion()
	boat.global_position = _port.tow_spawn_position()
	boat.input_enabled = true
	GameState.clear_danger()
	GameState.salvage_after_sinking()


## Recupero gratuito quando il countdown fuori zona scade: riporta al
## porto senza toccare scafo e denaro (niente punizione doppia).
func _rescue_boat() -> void:
	_outside_elapsed = -1.0
	boat.sink_amount = 0.0
	boat.reset_motion()
	boat.global_position = _port.tow_spawn_position()
	GameState.clear_danger()
	GameState.post_notice("Recuperato al largo e riportato al porto")


func _spawn_rock_field(center: Vector3) -> void:
	for i in rocks_per_field:
		var pos := _sample_disc(center, rock_field_radius, _rock_positions, 3.0)
		if not pos.is_finite():
			continue
		var rock := ROCK_SCENE.instantiate() as Node3D
		add_child(rock)
		rock.global_position = Vector3(pos.x, _rng.randf_range(-0.5, 0.1), pos.z)
		rock.rotation.y = _rng.randf_range(0.0, TAU)
		rock.scale = Vector3.ONE * _rng.randf_range(0.7, 1.9)
		_rock_positions.append(pos)


## Ogni tipologia vive nella sua fascia di mare (GDD § Boe): gialle
## nelle acque calme sotto costa, rosse nelle medie, blu al largo.
func _spawn_zone_buoys() -> void:
	for i in yellow_buoy_count:
		var pos := _sample_band(18.0, sea.calm_width - 15.0, _buoy_positions, 10.0)
		if pos.is_finite() and _is_clear(pos):
			_spawn_buoy(pos, GameState.BuoyType.YELLOW)
	for i in red_point_count:
		var pos := _sample_band(sea.calm_width + 5.0, sea.medium_width - 10.0, _buoy_positions, 10.0)
		if pos.is_finite() and _is_clear(pos):
			_spawn_buoy(pos, GameState.BuoyType.RED)
	for i in blue_point_count:
		var pos := _sample_band(sea.medium_width + 15.0, bay_depth - 60.0,
			_buoy_positions, 12.0, scatter_half_width_open)
		if pos.is_finite() and _is_clear(pos):
			_spawn_buoy(pos, GameState.BuoyType.BLUE)
	# Boe rosse al largo (roadmap R3): riempitivo tra le blu del mare aperto.
	for i in open_red_point_count:
		var pos := _sample_band(sea.medium_width + 15.0, bay_depth - 60.0,
			_buoy_positions, 12.0, scatter_half_width_open)
		if pos.is_finite() and _is_clear(pos):
			_spawn_buoy(pos, GameState.BuoyType.RED)
	# Le taniche vagano su tutta la baia: la fortuna può capitare ovunque.
	for i in fuel_point_count:
		var wide := i % 2 == 1
		var pos := _sample_band(20.0, bay_depth - 60.0, _buoy_positions, 10.0,
			scatter_half_width_open if wide else -1.0)
		if pos.is_finite() and _is_clear(pos):
			_spawn_fuel_can(pos)


## La traversata di B4: taniche di soccorso e boe blu sparse tra la baia
## e le città lontane. Poca roba su tanto mare — trovarle è fortuna, non
## raccolta sistematica (il grosso del viaggio resta vento e incontri).
func _spawn_route_pickups() -> void:
	for i in route_fuel_count:
		var pos := _sample_band(bay_depth + 100.0, bounds_depth - 300.0,
			_buoy_positions, 60.0, bounds_half_width - 500.0)
		if pos.is_finite() and _is_clear(pos):
			_spawn_fuel_can(pos)
	for i in route_buoy_count:
		var pos := _sample_band(bay_depth + 100.0, bounds_depth - 300.0,
			_buoy_positions, 60.0, bounds_half_width - 500.0)
		if pos.is_finite() and _is_clear(pos):
			_spawn_buoy(pos, GameState.BuoyType.BLUE)


## Una zona di pesca per fascia di mare (GDD § Pesca): specie e
## difficoltà crescono col rischio, come le boe. Il mare aperto è
## profondo il doppio delle altre fasce: ha due bande di zone.
func _spawn_fishing_zones() -> void:
	# x = distanza min dalla costa, y = distanza max, z = fascia (tier).
	var bands: Array[Vector3] = [
		Vector3(25.0, sea.calm_width - 20.0, 0.0),
		Vector3(sea.calm_width + 15.0, sea.medium_width - 15.0, 1.0),
		Vector3(sea.medium_width + 20.0, sea.medium_width + 220.0, 2.0),
		Vector3(sea.medium_width + 280.0, bay_depth - 70.0, 2.0),
	]
	for band in bands:
		var tier := int(band.z)
		for i in fishing_zones_per_band:
			var pos := _sample_band(band.x, band.y, _fishing_positions, 60.0,
				scatter_half_width_open if tier >= 2 else -1.0)
			if pos.is_finite() and _is_clear(pos):
				_spawn_fishing_zone(pos, tier)


func _spawn_fishing_zone(pos: Vector3, tier: int) -> void:
	var zone := FISHING_ZONE_SCENE.instantiate() as FishingZone
	zone.zone_tier = tier
	zone.sea = sea
	add_child(zone)
	zone.global_position = Vector3(pos.x, 0.0, pos.z)
	_fishing_positions.append(pos)


## Zone di pesca extra al largo profondo (roadmap R3), piazzate col RNG
## randomizzato delle missioni: posizioni nuove a ogni partita, così il
## mare aperto non ha sempre le stesse zone. Sempre tier 2 (specie pregiate).
func _spawn_open_activity_zones() -> void:
	for i in open_activity_zones:
		var pos := _sample_open_point(sea.medium_width + 120.0, bay_depth - 70.0)
		if pos.is_finite():
			_spawn_fishing_zone(pos, 2)


## Spot di gara procedurali al largo (roadmap R3): tracciato generato
## attorno a un punto casuale del mare aperto, IA aggressive e premi
## scalati dal fattore difficoltà del punto. Randomizzati a ogni partita.
func _spawn_open_races() -> void:
	for i in open_race_count:
		var center := _sample_open_point(sea.medium_width + 250.0, bay_depth + 500.0)
		if not center.is_finite():
			continue
		var course := RACE_COURSE_SCENE.instantiate() as RaceCourse
		course.procedural = true
		course.proc_seed = _mission_rng.randi()
		course.ai_hard = true
		course.prize_multiplier = open_race_prize_base \
			* GameState.difficulty_multiplier(center, sea)
		# La posizione va impostata prima di add_child: _ready costruisce i
		# cancelli dalle coordinate mondo dei marker (serve il transform).
		course.position = center
		add_child(course)
		course.sea = sea


## Punto libero nel mare aperto profondo, campionato col RNG randomizzato
## (posizioni nuove a ogni partita). Vector3.INF se non trova posto.
## half_width < 0 usa scatter_half_width_open (la fascia della baia).
func _sample_open_point(d_min: float, d_max: float, half_width: float = -1.0) -> Vector3:
	if half_width < 0.0:
		half_width = scatter_half_width_open
	for attempt in 30:
		var pos := Vector3(
			_mission_rng.randf_range(-half_width, half_width),
			0.0, sea.shore_z + _mission_rng.randf_range(d_min, d_max))
		if _is_clear(pos):
			return pos
	return Vector3.INF


## Relitti semisommersi (roadmap R6): qualche carcassa nel mare aperto
## della baia e altre sparse sulla traversata verso le città. RNG
## randomizzato: la caccia al relitto è nuova a ogni partita.
func _spawn_wrecks() -> void:
	for i in wreck_count:
		_spawn_wreck(_sample_open_point(sea.medium_width + 150.0, bay_depth - 80.0))
	for i in route_wreck_count:
		_spawn_wreck(_sample_open_point(bay_depth + 150.0, bounds_depth - 400.0,
			bounds_half_width - 500.0))


func _spawn_wreck(pos: Vector3) -> void:
	if not pos.is_finite():
		return
	var wreck := WRECK_SCENE.instantiate() as Wreck
	wreck.sea = sea
	wreck.boat = boat
	add_child(wreck)
	wreck.global_position = Vector3(pos.x, 0.0, pos.z)
	wreck.rotation.y = _mission_rng.randf_range(0.0, TAU)
	# Le boe e le taniche girano alla larga dalla carcassa.
	_buoy_positions.append(pos)


func _spawn_buoy(pos: Vector3, type: int) -> void:
	var buoy := BUOY_SCENE.instantiate() as Buoy
	buoy.type = type
	buoy.sea = sea
	add_child(buoy)
	buoy.global_position = Vector3(pos.x, 0.0, pos.z)
	_buoy_positions.append(pos)


func _spawn_fuel_can(pos: Vector3) -> void:
	var can := FUEL_CAN_SCENE.instantiate() as FuelCan
	can.sea = sea
	add_child(can)
	can.global_position = Vector3(pos.x, 0.0, pos.z)
	_buoy_positions.append(pos)


## Campiona un punto nella fascia di mare tra d_min e d_max metri dalla
## costa, lontano almeno min_dist dai punti già occupati. Vector3.INF se
## non trova posto. half_width < 0 usa scatter_half_width (i default dei
## parametri non possono leggere altre proprietà).
func _sample_band(d_min: float, d_max: float, taken: Array[Vector3],
		min_dist: float, half_width: float = -1.0) -> Vector3:
	if half_width < 0.0:
		half_width = scatter_half_width
	for attempt in 30:
		var pos := Vector3(_rng.randf_range(-half_width, half_width), 0.0,
			sea.shore_z + _rng.randf_range(d_min, d_max))
		if _far_from(pos, taken, min_dist):
			return pos
	return Vector3.INF


## Campiona un punto in un disco intorno a center (per i campi di scogli).
func _sample_disc(center: Vector3, radius: float, taken: Array[Vector3], min_dist: float) -> Vector3:
	for attempt in 30:
		var angle := _rng.randf_range(0.0, TAU)
		var pos := center + Vector3(cos(angle), 0.0, sin(angle)) * _rng.randf_range(0.0, radius)
		if _far_from(pos, taken, min_dist):
			return pos
	return Vector3.INF


func _far_from(pos: Vector3, points: Array[Vector3], min_dist: float) -> bool:
	for point in points:
		if pos.distance_to(point) < min_dist:
			return false
	return true


## Vero se il punto non finisce dentro isole, porti, città, scogli o
## zone di pesca.
func _is_clear(pos: Vector3) -> bool:
	for island: Node3D in _islands.get_children():
		if pos.distance_to(island.global_position) < 14.0 * island.scale.x:
			return false
	# Le città lontane tengono libera la loro rada interna.
	for node in get_tree().get_nodes_in_group(&"cities"):
		var city := node as City
		if city != null and pos.distance_to(city.global_position) < city.island_radius * 2.2:
			return false
	# Gli scali di rifornimento: niente boe o taniche addosso all'isolotto.
	for node in get_tree().get_nodes_in_group(&"supply_islands"):
		var isl := node as SupplyIsland
		if isl != null and pos.distance_to(isl.global_position) < isl.island_radius + 22.0:
			return false
	# Tutti i porti (principale + approdo secondario), non solo _port.
	for node in get_tree().get_nodes_in_group(&"ports"):
		if pos.distance_to((node as Port).global_position) < 26.0:
			return false
	# I relitti tengono libero l'anello dove affiorano le loro casse.
	for node in get_tree().get_nodes_in_group(&"wrecks"):
		if pos.distance_to((node as Wreck).global_position) < 30.0:
			return false
	# Niente boe addosso all'NPC del nipote né sul punto di recupero al largo.
	for node in get_tree().get_nodes_in_group(&"rescue_npc"):
		var npc := node as RescueNpc
		if pos.distance_to(npc.global_position) < 14.0 or pos.distance_to(npc.rescue_point) < 12.0:
			return false
	# Le zone di pesca ora sono più larghe (raggio ~15): niente boe dentro.
	if not _far_from(pos, _fishing_positions, 22.0):
		return false
	return _far_from(pos, _rock_positions, 3.0)
