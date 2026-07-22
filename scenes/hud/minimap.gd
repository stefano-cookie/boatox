class_name Minimap
extends Control

## Minimappa schematica della baia: fasce di mare, costa, porto, isole,
## scogli, boe e taniche presenti in acqua, freccia della barca. Compatta
## in basso a sinistra, il tasto M (azione "toggle_map") la espande al
## centro con la legenda. Tutto disegnato in _draw leggendo Sea e World:
## niente seconda viewport, costo minimo.

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
const FISHING_COLOR := Color(0.55, 0.9, 1.0)
const BOAT_COLOR := Color(1, 1, 1)
const TEXT_COLOR := Color(0.85, 0.9, 0.95)

## Altezza della mappa compatta in pixel; l'espansa segue la finestra.
@export var small_height: float = 150.0
@export_range(0.1, 1.0) var expanded_height_ratio: float = 0.72

var _boat: Boat
var _sea: Sea
var _world: World
var _expanded: bool = false
var _panel_style: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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

## Larghezza e profondità del mondo mappato (baia + striscia di terra).
func _world_size() -> Vector2:
	var half_width := _world.bounds_half_width if _world != null else 330.0
	var depth := _world.bounds_depth if _world != null else 340.0
	return Vector2(half_width * 2.0, depth + LAND_DEPTH)


func _apply_layout() -> void:
	var vp := get_viewport_rect().size
	var world_size := _world_size()
	var aspect := world_size.x / world_size.y
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
	var ws := _world_size()
	var u := (world_pos.x + ws.x * 0.5) / ws.x
	var v := (world_pos.z - (_sea.shore_z - LAND_DEPTH)) / ws.y
	return rect.position + Vector2(u, v) * rect.size


## Metri di mondo -> pixel di mappa (la scala è uniforme sui due assi).
func _px(rect: Rect2, meters: float) -> float:
	return meters * rect.size.x / _world_size().x


# --- Disegno -----------------------------------------------------------------

func _draw() -> void:
	if _boat == null or _sea == null or _world == null:
		return
	draw_style_box(_panel_style, Rect2(Vector2.ZERO, size))
	var rect := Rect2(Vector2(PAD, PAD), size - Vector2(PAD, PAD) * 2.0)
	_draw_bands(rect)
	_draw_bounds(rect)
	_draw_rocks(rect)
	_draw_islands(rect)
	_draw_port(rect)
	_draw_fishing_zones(rect)
	_draw_pickups(rect)
	_draw_boat(rect)
	if _expanded:
		_draw_legend(rect)
		_draw_hint(rect)
	else:
		_draw_badge(rect)


## Terra in alto, poi le tre fasce di mare parallele alla costa.
func _draw_bands(rect: Rect2) -> void:
	var shore_y := _to_map(rect, Vector3(0, 0, _sea.shore_z)).y
	var calm_y := _to_map(rect, Vector3(0, 0, _sea.shore_z + _sea.calm_width)).y
	var medium_y := _to_map(rect, Vector3(0, 0, _sea.shore_z + _sea.medium_width)).y
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, shore_y - rect.position.y)), LAND_COLOR)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, (shore_y - rect.position.y) * 0.4)), HILLS_COLOR)
	draw_rect(Rect2(Vector2(rect.position.x, shore_y), Vector2(rect.size.x, calm_y - shore_y)), CALM_COLOR)
	draw_rect(Rect2(Vector2(rect.position.x, calm_y), Vector2(rect.size.x, medium_y - calm_y)), MEDIUM_COLOR)
	draw_rect(Rect2(Vector2(rect.position.x, medium_y), Vector2(rect.size.x, rect.end.y - medium_y)), ROUGH_COLOR)
	var separator := Color(1, 1, 1, 0.12)
	draw_line(Vector2(rect.position.x, calm_y), Vector2(rect.end.x, calm_y), separator, 1.0)
	draw_line(Vector2(rect.position.x, medium_y), Vector2(rect.end.x, medium_y), separator, 1.0)


## Bordo rosso sui lati di mare aperto: oltre scatta il countdown.
func _draw_bounds(rect: Rect2) -> void:
	var shore_y := _to_map(rect, Vector3(0, 0, _sea.shore_z)).y
	var width := 2.0
	draw_line(Vector2(rect.position.x + 1, shore_y), Vector2(rect.position.x + 1, rect.end.y), BOUNDS_COLOR, width)
	draw_line(Vector2(rect.end.x - 1, shore_y), Vector2(rect.end.x - 1, rect.end.y), BOUNDS_COLOR, width)
	draw_line(Vector2(rect.position.x + 1, rect.end.y - 1), Vector2(rect.end.x - 1, rect.end.y - 1), BOUNDS_COLOR, width)


func _draw_rocks(rect: Rect2) -> void:
	var radius := maxf(_px(rect, 2.5), 1.5)
	for pos in _world.map_rocks():
		draw_circle(_to_map(rect, pos), radius, ROCK_COLOR)


func _draw_islands(rect: Rect2) -> void:
	for island: Node3D in _world.map_islands():
		var radius := maxf(_px(rect, 13.0 * island.scale.x), 3.0)
		draw_circle(_to_map(rect, island.global_position), radius, ISLAND_COLOR)


func _draw_port(rect: Rect2) -> void:
	var p := _to_map(rect, _world.port_position())
	var s := 8.0 if _expanded else 5.0
	_draw_diamond(p, s, PORT_COLOR)
	if _expanded:
		draw_string(ThemeDB.fallback_font, p + Vector2(12.0, 5.0), "Porto",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, TEXT_COLOR)


## Zone di pesca attive, come anelli (quelle a riposo non si disegnano:
## gli uccelli se ne sono andati anche dalla mappa).
func _draw_fishing_zones(rect: Rect2) -> void:
	var radius := maxf(_px(rect, 9.0), 4.0)
	for node in get_tree().get_nodes_in_group(&"fishing_zones"):
		var zone := node as FishingZone
		if zone == null or zone.is_resting():
			continue
		draw_arc(_to_map(rect, zone.global_position), radius, 0.0, TAU, 20, FISHING_COLOR, 2.0)


## Boe e taniche effettivamente presenti in acqua (i punti non spawnati
## sono invisibili e non si disegnano): cerchi le boe, quadrati le taniche.
func _draw_pickups(rect: Rect2) -> void:
	var buoy_radius := 4.0 if _expanded else 2.5
	for node in get_tree().get_nodes_in_group(&"buoys"):
		var buoy := node as Buoy
		if buoy == null or not buoy.visible:
			continue
		var color := Color("#" + GameState.BUOY_HEX[buoy.type])
		draw_circle(_to_map(rect, buoy.global_position), buoy_radius, color)
	var can_size := 8.0 if _expanded else 5.0
	for node in get_tree().get_nodes_in_group(&"fuel_cans"):
		var can := node as FuelCan
		if can == null or not can.visible:
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
	var text := "M per chiudere"
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
	_draw_diamond(Vector2(x, y - 5.0), 6.0, PORT_COLOR)
	x += 11.0
	_legend_label(font, x, y, "porto")


## Disegna un'etichetta di legenda e restituisce la x della voce dopo.
func _legend_label(font: Font, x: float, y: float, text: String) -> float:
	draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, TEXT_COLOR)
	return x + font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 18.0
