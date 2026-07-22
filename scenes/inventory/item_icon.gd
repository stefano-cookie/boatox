class_name ItemIcon
extends Control

## Icona procedurale per gli item della stiva (roadmap P2 § Inventario): in
## assenza di asset CC0 (non scaricabili da script, come i modelli Kenney),
## ogni tipo si distingue per forma e colore. Boa = galleggiante tondo con
## antenna, pesce = sagoma con coda e occhio. I colori arrivano da
## GameState.BUOY_HEX/FISH_HEX così restano allineati a HUD e porto. Se un
## giorno arrivano vere icone, basta sostituire il disegno con una texture.

enum Kind { BUOY, FISH }

var _kind: int = Kind.BUOY
var _color: Color = Color.WHITE


func setup(kind: int, color: Color) -> void:
	_kind = kind
	_color = color
	queue_redraw()


func _draw() -> void:
	var pad := size.x * 0.12
	var rect := Rect2(Vector2(pad, pad), size - Vector2(pad, pad) * 2.0)
	var center := rect.position + rect.size * 0.5
	var radius := minf(rect.size.x, rect.size.y) * 0.5
	if _kind == Kind.FISH:
		_draw_fish(center, radius)
	else:
		_draw_buoy(center, radius)


## Galleggiante: corpo tondo, antenna con pallino, banda più scura.
func _draw_buoy(center: Vector2, radius: float) -> void:
	var top := center + Vector2(0.0, -radius * 0.95)
	draw_line(center + Vector2(0.0, -radius * 0.35), top, _color, maxf(2.0, radius * 0.14))
	draw_circle(top, radius * 0.15, _color)
	var body := center + Vector2(0.0, radius * 0.18)
	var body_radius := radius * 0.62
	draw_circle(body, body_radius, _color)
	# Banda scura al centro del corpo (dettaglio da boa da mare).
	var band := PackedVector2Array([
		body + Vector2(-body_radius * 0.92, -body_radius * 0.16),
		body + Vector2(body_radius * 0.92, -body_radius * 0.16),
		body + Vector2(body_radius * 0.92, body_radius * 0.16),
		body + Vector2(-body_radius * 0.92, body_radius * 0.16),
	])
	draw_colored_polygon(band, _color.darkened(0.45))


## Pesce di profilo (naso a destra): corpo ellittico, coda a triangolo, occhio.
func _draw_fish(center: Vector2, radius: float) -> void:
	var body_center := center + Vector2(radius * 0.12, 0.0)
	var rx := radius * 0.72
	var ry := radius * 0.42
	var body := PackedVector2Array()
	var steps := 22
	for i in steps:
		var a := TAU * float(i) / float(steps)
		body.append(body_center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(body, _color)
	var tail := PackedVector2Array([
		body_center + Vector2(-rx * 0.75, 0.0),
		center + Vector2(-radius * 0.98, -radius * 0.45),
		center + Vector2(-radius * 0.98, radius * 0.45),
	])
	draw_colored_polygon(tail, _color)
	draw_circle(body_center + Vector2(rx * 0.5, -ry * 0.28), radius * 0.1, Color(0.1, 0.12, 0.16))
