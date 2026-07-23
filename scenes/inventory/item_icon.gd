class_name ItemIcon
extends Control

## Icona procedurale per gli item della stiva (roadmap R4 § Inventario): in
## assenza di asset CC0 (non scaricabili da script, come i modelli Kenney),
## ogni item si distingue per forma e colore. Boa = galleggiante tondo con
## antenna, pesce = sagoma con coda e occhio, cassa = baule (bottino e casse
## missione). La forma e il colore arrivano dall'ItemDefinition (shape/color)
## così restano allineati a HUD, porto e minimappa. Se un giorno arrivano vere
## icone, basta sostituire il disegno con una texture. I valori dell'enum
## coincidono con ItemDefinition.Shape (BUOY, FISH, CRATE).
enum Kind { BUOY, FISH, CRATE }

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
	match _kind:
		Kind.FISH:
			_draw_fish(center, radius)
		Kind.CRATE:
			_draw_crate(center, radius)
		_:
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


## Cassa/baule (bottino e casse missione): corpo squadrato con coperchio,
## bordi scuri e una borchia centrale.
func _draw_crate(center: Vector2, radius: float) -> void:
	var half := radius * 0.82
	var body := Rect2(center - Vector2(half, half * 0.72), Vector2(half * 2.0, half * 1.5))
	draw_rect(body, _color)
	# Coperchio più scuro in cima.
	var lid := Rect2(body.position, Vector2(body.size.x, body.size.y * 0.32))
	draw_rect(lid, _color.darkened(0.3))
	# Cornice scura e assi verticali.
	draw_rect(body, _color.darkened(0.5), false, maxf(2.0, radius * 0.08))
	var mid := center.x
	draw_line(Vector2(mid, body.position.y), Vector2(mid, body.position.y + body.size.y),
		_color.darkened(0.5), maxf(1.5, radius * 0.06))
	# Borchia della serratura.
	draw_circle(Vector2(mid, center.y + half * 0.05), radius * 0.13, _color.darkened(0.5))
