class_name Minimap
extends Control

## Minimappa schematica del mare (dal B4 non più solo la baia): fasce,
## costa, porti, città lontane con le loro rade, isole, scogli, boe e
## taniche, freccia della barca. Compatta in basso a sinistra è una
## vista locale che segue la barca (mezzo chilometro abbondante); il
## tasto M (azione "toggle_map") apre la carta nautica dell'intero mondo
## con nomi, distanze e legenda. Tutto disegnato in _draw leggendo Sea e
## World: niente seconda viewport, costo minimo.

## Terra mostrata sopra la linea di costa, in metri di mondo.
const LAND_DEPTH: float = 45.0
## Bordo interno tra cornice e mappa.
const PAD: float = 6.0

const LAND_COLOR := Color(0.72, 0.64, 0.46)
const HILLS_COLOR := Color(0.42, 0.5, 0.36)
const CALM_COLOR := Color(0.2, 0.58, 0.7)
const MEDIUM_COLOR := Color(0.13, 0.42, 0.6)
const ROUGH_COLOR := Color(0.08, 0.26, 0.46)
const BOUNDS_COLOR := Color(1.0, 0.35, 0.3, 0.45)
const ROCK_COLOR := Color(0.32, 0.34, 0.38)
const ISLAND_COLOR := Color(0.45, 0.62, 0.4)
const PORT_COLOR := Color(1.0, 0.62, 0.2)
const FUEL_COLOR := Color(0.9, 0.15, 0.1)
const WIND_COLOR := Color(0.03, 0.07, 0.16)
const FISHING_COLOR := Color(0.55, 0.9, 1.0)
const RACE_COLOR := Color(0.35, 1.0, 0.55)
const BOAT_COLOR := Color(1, 1, 1)
const TEXT_COLOR := Color(0.85, 0.9, 0.95)
## Missione del nipote e impulso radar (GDD § Missioni): boe e zone non si
## vedono più di default, solo dentro l'impulso; il rosa segna l'NPC e il
## bersaglio della missione.
const QUEST_COLOR := Color(1.0, 0.45, 0.85)
const RADAR_RING_COLOR := Color(0.55, 0.9, 1.0)
## Marker della missione della bacheca (roadmap A1): ambra, stessa logica
## del cancello regata (anello + punto sul bersaglio corrente).
const MISSION_COLOR := Color(1.0, 0.8, 0.3)

## Altezza della mappa compatta in pixel; l'espansa segue la finestra.
@export var small_height: float = 190.0
@export_range(0.1, 1.0) var expanded_height_ratio: float = 0.72
## Lato della vista locale compatta, in metri di mondo: quanto mare si
## vede intorno alla barca durante la navigazione.
@export var compact_span: float = 720.0

var _boat: Boat
var _sea: Sea
var _world: World
var _expanded: bool = false
var _panel_style: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# La vista locale scorre col mondo: ciò che esce dalla finestra va
	# tagliato, non spalmato sull'HUD.
	clip_contents = true
	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = Color(0.06, 0.1, 0.16, 0.85)
	_panel_style.border_color = Color(0.45, 0.65, 0.85, 0.35)
	_panel_style.set_border_width_all(1)
	_panel_style.set_corner_radius_all(10)
	get_viewport().size_changed.connect(_apply_layout)


## Riferimenti passati dall'HUD (la minimappa vive dentro hud.tscn e non
## può esportare NodePath verso la scena main).
func setup(boat: Boat, sea: Sea, world: World) -> void:
	_boat = boat
	_sea = sea
	_world = world
	_apply_layout()


func _process(_delta: float) -> void:
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_map"):
		get_viewport().set_input_as_handled()
		_expanded = not _expanded
		_apply_layout()


func is_expanded() -> bool:
	return _expanded


# --- Layout ------------------------------------------------------------------

## Finestra di mondo mostrata, in coordinate mondo (x, z). Compatta:
## quadrato centrato sulla barca. Espansa: tutto il mare giocabile più la
## striscia di terra a nord — la carta nautica del viaggio (roadmap B4).
func _view_rect() -> Rect2:
	if not _expanded and _boat != null:
		var pos := _boat.global_position
		return Rect2(pos.x - compact_span * 0.5, pos.z - compact_span * 0.5,
			compact_span, compact_span)
	var half_width := _world.bounds_half_width if _world != null else 330.0
	var depth := _world.bounds_depth if _world != null else 340.0
	var shore := _sea.shore_z if _sea != null else -140.0
	return Rect2(-half_width, shore - LAND_DEPTH, half_width * 2.0, depth + LAND_DEPTH)


func _apply_layout() -> void:
	var vp := get_viewport_rect().size
	var view := _view_rect()
	var aspect := view.size.x / view.size.y
	var h := vp.y * expanded_height_ratio if _expanded else small_height
	var w := h * aspect
	if w > vp.x * 0.9:
		w = vp.x * 0.9
		h = w / aspect
	size = Vector2(w, h) + Vector2(PAD, PAD) * 2.0
	if _expanded:
		position = (vp - size) * 0.5
	else:
		position = Vector2(16.0, vp.y - size.y - 16.0)


func _to_map(rect: Rect2, world_pos: Vector3) -> Vector2:
	var view := _view_rect()
	var u := (world_pos.x - view.position.x) / view.size.x
	var v := (world_pos.z - view.position.y) / view.size.y
	return rect.position + Vector2(u, v) * rect.size


## Metri di mondo -> pixel di mappa (la scala è uniforme sui due assi).
func _px(rect: Rect2, meters: float) -> float:
	return meters * rect.size.x / _view_rect().size.x


## Vero se il punto (con margine in metri) cade nella finestra corrente:
## per saltare il disegno di ciò che sta a chilometri dalla vista.
func _in_view(world_pos: Vector3, margin: float = 0.0) -> bool:
	return _view_rect().grow(margin).has_point(Vector2(world_pos.x, world_pos.z))


## Blocca un punto mappa dentro la cornice: i marker di missione e i
## porti fuori vista restano appiccicati al bordo, nella loro direzione.
func _clamp_to_rect(rect: Rect2, p: Vector2, margin: float = 6.0) -> Vector2:
	return p.clamp(rect.position + Vector2(margin, margin), rect.end - Vector2(margin, margin))


# --- Disegno -----------------------------------------------------------------

func _draw() -> void:
	if _boat == null or _sea == null or _world == null:
		return
	draw_style_box(_panel_style, Rect2(Vector2.ZERO, size))
	var rect := Rect2(Vector2(PAD, PAD), size - Vector2(PAD, PAD) * 2.0)
	_draw_bands(rect)
	_draw_harbors(rect)
	_draw_wind_cells(rect)
	_draw_bounds(rect)
	_draw_rocks(rect)
	_draw_islands(rect)
	_draw_port(rect)
	_draw_fishing_zones(rect)
	_draw_race_start(rect)
	_draw_race_gate(rect)
	_draw_quest(rect)
	_draw_mission(rect)
	_draw_radar(rect)
	_draw_pickups(rect)
	_draw_boat(rect)
	if _expanded:
		_draw_legend(rect)
		_draw_hint(rect)
	else:
		_draw_badge(rect)


## Striscia orizzontale [y0, y1] tagliata sulla cornice: le fasce si
## disegnano solo per la parte che cade nella finestra corrente.
func _fill_hband(rect: Rect2, y0: float, y1: float, color: Color) -> void:
	var top := maxf(y0, rect.position.y)
	var bottom := minf(y1, rect.end.y)
	if bottom > top:
		draw_rect(Rect2(rect.position.x, top, rect.size.x, bottom - top), color)


## Mare aperto come fondo, poi le fasce sotto costa e la terra in alto —
## quello che ne entra nella finestra corrente.
func _draw_bands(rect: Rect2) -> void:
	draw_rect(rect, ROUGH_COLOR)
	var land_y := _to_map(rect, Vector3(0, 0, _sea.shore_z - LAND_DEPTH)).y
	var shore_y := _to_map(rect, Vector3(0, 0, _sea.shore_z)).y
	var calm_y := _to_map(rect, Vector3(0, 0, _sea.shore_z + _sea.calm_width)).y
	var medium_y := _to_map(rect, Vector3(0, 0, _sea.shore_z + _sea.medium_width)).y
	_fill_hband(rect, calm_y, medium_y, MEDIUM_COLOR)
	_fill_hband(rect, shore_y, calm_y, CALM_COLOR)
	_fill_hband(rect, rect.position.y, shore_y, LAND_COLOR)
	_fill_hband(rect, land_y, land_y + (shore_y - land_y) * 0.4, HILLS_COLOR)
	var separator := Color(1, 1, 1, 0.12)
	if calm_y > rect.position.y and calm_y < rect.end.y:
		draw_line(Vector2(rect.position.x, calm_y), Vector2(rect.end.x, calm_y), separator, 1.0)
	if medium_y > rect.position.y and medium_y < rect.end.y:
		draw_line(Vector2(rect.position.x, medium_y), Vector2(rect.end.x, medium_y), separator, 1.0)


## Le città lontane (roadmap B4): la macchia d'acqua calma della rada e
## la sagoma dell'isola. Il nome lo mette il porto (stessa posizione).
func _draw_harbors(rect: Rect2) -> void:
	for node in get_tree().get_nodes_in_group(&"cities"):
		var city := node as City
		if city == null or not _in_view(city.global_position, city.harbor_radius + 50.0):
			continue
		var center := _to_map(rect, city.global_position)
		var harbor_px := _px(rect, city.harbor_radius)
		draw_circle(center, harbor_px, Color(CALM_COLOR, 0.55))
		draw_arc(center, harbor_px, 0.0, TAU, 32, Color(CALM_COLOR, 0.9), 1.5)
		draw_circle(center, maxf(_px(rect, city.island_radius), 3.0), ISLAND_COLOR)


## Celle di vento attive come macchie scure sul mare (feedback playtest
## M3): dentro una macchia il mare è più grosso del previsto.
func _draw_wind_cells(rect: Rect2) -> void:
	var field := get_tree().get_first_node_in_group(&"wind_field") as WindField
	if field == null:
		return
	for cell in field.cells_packed():
		if cell.w < 0.15 or not _in_view(Vector3(cell.x, 0.0, cell.y), cell.z):
			continue
		var center := _to_map(rect, Vector3(cell.x, 0.0, cell.y))
		var radius := _px(rect, cell.z)
		draw_circle(center, radius, Color(WIND_COLOR, 0.45 * cell.w))
		draw_arc(center, radius, 0.0, TAU, 28, Color(WIND_COLOR, 0.7 * cell.w), 1.5)


## Bordo rosso sui lati di mare aperto: oltre scatta il countdown.
func _draw_bounds(rect: Rect2) -> void:
	var shore_y := _to_map(rect, Vector3(0, 0, _sea.shore_z)).y
	var left_x := _to_map(rect, Vector3(-_world.bounds_half_width, 0, 0)).x
	var right_x := _to_map(rect, Vector3(_world.bounds_half_width, 0, 0)).x
	var bottom_y := _to_map(rect, Vector3(0, 0, _sea.shore_z + _world.bounds_depth)).y
	var width := 2.0
	draw_line(Vector2(left_x, maxf(shore_y, rect.position.y)), Vector2(left_x, bottom_y), BOUNDS_COLOR, width)
	draw_line(Vector2(right_x, maxf(shore_y, rect.position.y)), Vector2(right_x, bottom_y), BOUNDS_COLOR, width)
	draw_line(Vector2(left_x, bottom_y), Vector2(right_x, bottom_y), BOUNDS_COLOR, width)


func _draw_rocks(rect: Rect2) -> void:
	var radius := maxf(_px(rect, 2.5), 1.5)
	for pos in _world.map_rocks():
		if _in_view(pos, 10.0):
			draw_circle(_to_map(rect, pos), radius, ROCK_COLOR)


func _draw_islands(rect: Rect2) -> void:
	for island: Node3D in _world.map_islands():
		if not _in_view(island.global_position, 30.0):
			continue
		var radius := maxf(_px(rect, 13.0 * island.scale.x), 3.0)
		draw_circle(_to_map(rect, island.global_position), radius, ISLAND_COLOR)


## Tutti i porti del gruppo, con l'etichetta breve del Port parametrico e
## la distanza sulla carta espansa. Nella vista locale i porti fuori
## finestra restano al bordo, nella loro direzione: la bussola del viaggio.
func _draw_port(rect: Rect2) -> void:
	var s := 8.0 if _expanded else 5.0
	for node in get_tree().get_nodes_in_group(&"ports"):
		var port := node as Port
		if port == null:
			continue
		var p := _to_map(rect, port.global_position)
		if not _expanded and not _in_view(port.global_position):
			p = _clamp_to_rect(rect, p)
			_draw_diamond(p, s * 0.8, Color(PORT_COLOR, 0.8))
			continue
		_draw_diamond(p, s, PORT_COLOR)
		if _expanded:
			var km := port.global_position.distance_to(_boat.global_position) / 1000.0
			var label := port.map_label
			if km >= 0.25:
				label += " · %.1f km" % km
			draw_string(ThemeDB.fallback_font, p + Vector2(12.0, 5.0), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 15, TEXT_COLOR)


## Zone di pesca attive, come anelli — ma solo quelle rivelate da un
## impulso radar attivo (GDD § Missioni): senza radar la minimappa non le
## mostra. Quelle a riposo non si disegnano comunque.
func _draw_fishing_zones(rect: Rect2) -> void:
	var radius := maxf(_px(rect, 15.0), 4.0)
	for node in get_tree().get_nodes_in_group(&"fishing_zones"):
		var zone := node as FishingZone
		if zone == null or zone.is_resting() or not _radar_reveals(zone.global_position):
			continue
		if _in_view(zone.global_position, 20.0):
			draw_arc(_to_map(rect, zone.global_position), radius, 0.0, TAU, 20, FISHING_COLOR, 2.0)


## Vero se un impulso radar è attivo e il punto cade nel suo raggio: solo
## allora la minimappa lo rivela (boe, taniche, zone). Il raggio è una
## frazione della profondità della baia, allargata dai potenziamenti.
func _radar_reveals(world_pos: Vector3) -> bool:
	if not Radar.is_active():
		return false
	var radius := Radar.range_fraction() * _world.bay_depth
	return Radar.origin().distance_to(world_pos) <= radius


## Cerchio dell'impulso radar in corso: mostra dove e fin dove ha rilevato.
func _draw_radar(rect: Rect2) -> void:
	if not Radar.is_active():
		return
	var center := _to_map(rect, Radar.origin())
	var radius := _px(rect, Radar.range_fraction() * _world.bay_depth)
	draw_arc(center, radius, 0.0, TAU, 48, Color(RADAR_RING_COLOR, 0.4), 1.5)


## NPC del nipote (landmark fisso, come il porto) e, a missione in corso,
## il marker del bersaglio: il nipote al largo o l'NPC dove riportarlo.
func _draw_quest(rect: Rect2) -> void:
	var npc := get_tree().get_first_node_in_group(&"rescue_npc") as RescueNpc
	if npc == null:
		return
	if _in_view(npc.global_position, 10.0):
		var np := _to_map(rect, npc.global_position)
		_draw_diamond(np, 6.0 if _expanded else 4.0, QUEST_COLOR)
		if _expanded:
			draw_string(ThemeDB.fallback_font, np + Vector2(12.0, 5.0), "Zu' Vito",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 15, TEXT_COLOR)
	if not npc.show_quest_marker():
		return
	var target := _clamp_to_rect(rect, _to_map(rect, npc.quest_marker_position()))
	var radius := 8.0 if _expanded else 5.5
	draw_arc(target, radius, 0.0, TAU, 20, QUEST_COLOR, 2.5)
	draw_circle(target, 2.5, QUEST_COLOR)


## Marker della missione della bacheca (roadmap A1): il punto del pacco o
## l'approdo di consegna finché c'è da andare, il porto del rientro a
## pacco raccolto. Fuori finestra resta al bordo, nella sua direzione.
func _draw_mission(rect: Rect2) -> void:
	if not GameState.mission_active():
		return
	var p := _clamp_to_rect(rect, _to_map(rect, GameState.mission_marker_position()))
	var radius := 8.0 if _expanded else 5.5
	draw_arc(p, radius, 0.0, TAU, 20, MISSION_COLOR, 2.5)
	draw_circle(p, 2.5, MISSION_COLOR)


## Marker permanente della partenza regata (feedback playtest round 2: il
## giocatore deve sapere che c'è e dov'è, non solo durante la gara). Rombo
## verde con anello, distinto dal rombo arancio del porto.
func _draw_race_start(rect: Rect2) -> void:
	var s := 7.0 if _expanded else 4.5
	for node in get_tree().get_nodes_in_group(&"race_course"):
		var course := node as RaceCourse
		if course == null or not _in_view(course.start_position(), 20.0):
			continue
		var p := _to_map(rect, course.start_position())
		draw_arc(p, s + 2.0, 0.0, TAU, 18, RACE_COLOR, 1.5)
		_draw_diamond(p, s, RACE_COLOR)
		if _expanded:
			# Lo spot difficile al largo si etichetta come tale.
			var label := "Regata largo" if course.ai_hard else "Regata"
			draw_string(ThemeDB.fallback_font, p + Vector2(12.0, 5.0), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 15, TEXT_COLOR)


## Solo durante la regata: il prossimo cancello da prendere, dello
## stesso verde della colonna di luce in 3D.
func _draw_race_gate(rect: Rect2) -> void:
	var radius := 7.0 if _expanded else 5.0
	for node in get_tree().get_nodes_in_group(&"race_course"):
		var course := node as RaceCourse
		if course == null or not course.is_racing():
			continue
		var p := _clamp_to_rect(rect, _to_map(rect, course.next_gate_position()))
		draw_arc(p, radius, 0.0, TAU, 16, RACE_COLOR, 2.5)
		draw_circle(p, 2.0, RACE_COLOR)


## Boe e taniche presenti in acqua, ma solo quelle rivelate da un impulso
## radar attivo (GDD § Missioni): senza radar la minimappa non le mostra.
## Cerchi le boe, quadrati le taniche.
func _draw_pickups(rect: Rect2) -> void:
	var buoy_radius := 4.0 if _expanded else 2.5
	for node in get_tree().get_nodes_in_group(&"buoys"):
		var buoy := node as Buoy
		if buoy == null or not buoy.visible or not _radar_reveals(buoy.global_position):
			continue
		if not _in_view(buoy.global_position, 10.0):
			continue
		var color := Color("#" + GameState.BUOY_HEX[buoy.type])
		draw_circle(_to_map(rect, buoy.global_position), buoy_radius, color)
	var can_size := 8.0 if _expanded else 5.0
	for node in get_tree().get_nodes_in_group(&"fuel_cans"):
		var can := node as FuelCan
		if can == null or not can.visible or not _radar_reveals(can.global_position):
			continue
		if not _in_view(can.global_position, 10.0):
			continue
		var p := _to_map(rect, can.global_position)
		draw_rect(Rect2(p - Vector2(can_size, can_size) * 0.5, Vector2(can_size, can_size)), FUEL_COLOR)


func _draw_boat(rect: Rect2) -> void:
	var p := _to_map(rect, _boat.global_position)
	p = p.clamp(rect.position, rect.end)
	var forward := -_boat.global_transform.basis.z
	var dir := Vector2(forward.x, forward.z)
	dir = Vector2.UP if dir.length_squared() < 0.001 else dir.normalized()
	var s := 11.0 if _expanded else 7.0
	var points := PackedVector2Array([
		p + dir * s,
		p + dir.rotated(2.5) * s * 0.7,
		p + dir.rotated(-2.5) * s * 0.7,
	])
	draw_colored_polygon(points, BOAT_COLOR)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color(0, 0, 0, 0.6), 1.5)


func _draw_diamond(center: Vector2, s: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -s), center + Vector2(s, 0),
		center + Vector2(0, s), center + Vector2(-s, 0),
	]), color)


func _draw_badge(rect: Rect2) -> void:
	var chip := Rect2(rect.end - Vector2(24.0, 22.0), Vector2(18.0, 16.0))
	draw_rect(chip, Color(0, 0, 0, 0.45))
	draw_string(ThemeDB.fallback_font, chip.position + Vector2(5.0, 13.0), "M",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TEXT_COLOR)


func _draw_hint(rect: Rect2) -> void:
	var font := ThemeDB.fallback_font
	var radar_note := "boe e zone: impulso radar (R)" if GameState.radar_unlocked \
		else "boe e zone: sblocca il radar da Zu' Vito"
	var text := "M per chiudere  ·  %s" % radar_note
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	draw_string(font, Vector2(rect.position.x + (rect.size.x - text_width) * 0.5, rect.position.y + 20.0),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.55))


func _draw_legend(rect: Rect2) -> void:
	var font := ThemeDB.fallback_font
	var y := rect.end.y - 14.0
	var x := rect.position.x + 14.0
	for type: int in GameState.BuoyType.values():
		draw_circle(Vector2(x, y - 5.0), 5.0, Color("#" + GameState.BUOY_HEX[type]))
		x += 10.0
		x = _legend_label(font, x, y, "boa " + GameState.BUOY_NAME[type])
	draw_rect(Rect2(x - 5.0, y - 10.0, 10.0, 10.0), FUEL_COLOR)
	x += 10.0
	x = _legend_label(font, x, y, "benzina")
	draw_arc(Vector2(x, y - 5.0), 5.0, 0.0, TAU, 16, FISHING_COLOR, 2.0)
	x += 10.0
	x = _legend_label(font, x, y, "pesca")
	draw_circle(Vector2(x, y - 5.0), 5.0, Color(WIND_COLOR, 0.8))
	x += 10.0
	x = _legend_label(font, x, y, "vento")
	_draw_diamond(Vector2(x, y - 5.0), 6.0, PORT_COLOR)
	x += 11.0
	x = _legend_label(font, x, y, "porto")
	_draw_diamond(Vector2(x, y - 5.0), 6.0, RACE_COLOR)
	x += 11.0
	x = _legend_label(font, x, y, "regata")
	_draw_diamond(Vector2(x, y - 5.0), 6.0, QUEST_COLOR)
	x += 11.0
	x = _legend_label(font, x, y, "nipote")
	draw_arc(Vector2(x, y - 5.0), 5.0, 0.0, TAU, 16, MISSION_COLOR, 2.0)
	x += 10.0
	_legend_label(font, x, y, "missione")


## Disegna un'etichetta di legenda e restituisce la x della voce dopo.
func _legend_label(font: Font, x: float, y: float, text: String) -> float:
	draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, TEXT_COLOR)
	return x + font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 18.0
