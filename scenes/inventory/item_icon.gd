class_name ItemIcon
extends Control

## Icona procedurale per gli item della stiva (roadmap R4 § Inventario): in
## assenza di asset CC0 (non scaricabili da script, come i modelli Kenney),
## ogni item si distingue per forma e colore. Boa = galleggiante tondo con
## antenna, pesce = sagoma con coda e occhio, cassa = baule (bottino e casse
## missione). Da R6 anche le merci (sacco) e i tesori (anfora, perla,
## rotolo, statuetta). La forma e il colore arrivano dall'ItemDefinition
## (shape/color) così restano allineati a HUD, porto e minimappa. Se un
## giorno arrivano vere icone, basta sostituire il disegno con una texture.
## I valori dell'enum coincidono con ItemDefinition.Shape.
enum Kind { BUOY, FISH, CRATE, SACK, AMPHORA, PEARL, SCROLL, STATUE }

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
		Kind.SACK:
			_draw_sack(center, radius)
		Kind.AMPHORA:
			_draw_amphora(center, radius)
		Kind.PEARL:
			_draw_pearl(center, radius)
		Kind.SCROLL:
			_draw_scroll(center, radius)
		Kind.STATUE:
			_draw_statue(center, radius)
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


## Sacco di merce (R6): corpo a goccia con collo legato e lembi in cima.
func _draw_sack(center: Vector2, radius: float) -> void:
	var body_center := center + Vector2(0.0, radius * 0.22)
	var rx := radius * 0.62
	var ry := radius * 0.58
	var body := PackedVector2Array()
	var steps := 22
	for i in steps:
		var a := TAU * float(i) / float(steps)
		body.append(body_center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(body, _color)
	# Collo stretto e legaccio scuro.
	var neck_y := body_center.y - ry * 0.92
	var neck := Rect2(Vector2(center.x - radius * 0.18, neck_y - radius * 0.3),
		Vector2(radius * 0.36, radius * 0.34))
	draw_rect(neck, _color)
	draw_line(Vector2(neck.position.x - 2.0, neck.end.y),
		Vector2(neck.end.x + 2.0, neck.end.y), _color.darkened(0.5), maxf(2.0, radius * 0.1))
	# Lembi sopra il legaccio.
	var top := neck_y - radius * 0.32
	draw_line(Vector2(center.x, top + radius * 0.16), Vector2(center.x - radius * 0.22, top),
		_color.darkened(0.2), maxf(2.0, radius * 0.1))
	draw_line(Vector2(center.x, top + radius * 0.16), Vector2(center.x + radius * 0.22, top),
		_color.darkened(0.2), maxf(2.0, radius * 0.1))


## Anfora antica (R6): corpo panciuto, collo con bocca larga e due anse.
func _draw_amphora(center: Vector2, radius: float) -> void:
	var body_center := center + Vector2(0.0, radius * 0.12)
	var body := PackedVector2Array()
	var steps := 22
	for i in steps:
		var a := TAU * float(i) / float(steps)
		# Goccia: pancia larga in alto che si stringe verso il piede.
		var w := radius * (0.5 - 0.18 * sin(a))
		body.append(body_center + Vector2(cos(a) * w, sin(a) * radius * 0.6))
	draw_colored_polygon(body, _color)
	# Collo e bocca.
	var neck := Rect2(Vector2(center.x - radius * 0.14, center.y - radius * 0.85),
		Vector2(radius * 0.28, radius * 0.4))
	draw_rect(neck, _color)
	draw_rect(Rect2(Vector2(center.x - radius * 0.26, center.y - radius * 0.95),
		Vector2(radius * 0.52, radius * 0.14)), _color.darkened(0.25))
	# Anse ad arco ai lati del collo.
	var handle_w := maxf(2.0, radius * 0.1)
	draw_arc(center + Vector2(-radius * 0.32, -radius * 0.5), radius * 0.22,
		PI * 0.5, PI * 1.5, 10, _color.darkened(0.2), handle_w)
	draw_arc(center + Vector2(radius * 0.32, -radius * 0.5), radius * 0.22,
		-PI * 0.5, PI * 0.5, 10, _color.darkened(0.2), handle_w)
	# Decoro a fascia sulla pancia.
	draw_line(body_center + Vector2(-radius * 0.42, 0.0), body_center + Vector2(radius * 0.42, 0.0),
		_color.darkened(0.45), maxf(2.0, radius * 0.08))


## Perla (R6): conchiglia aperta scura con la sfera lucida dentro.
func _draw_pearl(center: Vector2, radius: float) -> void:
	# Valva inferiore: mezzaluna scura.
	var shell := PackedVector2Array()
	var steps := 14
	for i in steps + 1:
		var a := PI * float(i) / float(steps)
		shell.append(center + Vector2(cos(a) * radius * 0.85, sin(a) * radius * 0.6 + radius * 0.25))
	draw_colored_polygon(shell, Color(0.35, 0.3, 0.38))
	# La perla, con riflesso in alto a sinistra.
	var pearl_center := center + Vector2(0.0, -radius * 0.05)
	draw_circle(pearl_center, radius * 0.42, _color)
	draw_circle(pearl_center + Vector2(-radius * 0.14, -radius * 0.14), radius * 0.12,
		Color(1.0, 1.0, 1.0, 0.85))


## Carta nautica (R6): rotolo con i riccioli ai lati e una rotta tratteggiata.
func _draw_scroll(center: Vector2, radius: float) -> void:
	var half_w := radius * 0.8
	var half_h := radius * 0.55
	draw_rect(Rect2(center - Vector2(half_w, half_h), Vector2(half_w * 2.0, half_h * 2.0)), _color)
	# Riccioli arrotolati ai lati, più scuri.
	draw_rect(Rect2(center + Vector2(-half_w - radius * 0.12, -half_h),
		Vector2(radius * 0.18, half_h * 2.0)), _color.darkened(0.3))
	draw_rect(Rect2(center + Vector2(half_w - radius * 0.06, -half_h),
		Vector2(radius * 0.18, half_h * 2.0)), _color.darkened(0.3))
	# Rotta tratteggiata con la X del tesoro.
	var ink := Color(0.45, 0.3, 0.2)
	var p0 := center + Vector2(-half_w * 0.6, half_h * 0.5)
	var p1 := center + Vector2(-half_w * 0.1, -half_h * 0.2)
	var p2 := center + Vector2(half_w * 0.45, half_h * 0.1)
	_dashed(p0, p1, ink)
	_dashed(p1, p2, ink)
	var s := radius * 0.14
	draw_line(p2 + Vector2(-s, -s), p2 + Vector2(s, s), Color(0.75, 0.2, 0.15), 2.0)
	draw_line(p2 + Vector2(-s, s), p2 + Vector2(s, -s), Color(0.75, 0.2, 0.15), 2.0)


## Statuetta dorata (R6): figurina stilizzata su piedistallo.
func _draw_statue(center: Vector2, radius: float) -> void:
	# Piedistallo a gradino.
	draw_rect(Rect2(center + Vector2(-radius * 0.55, radius * 0.62),
		Vector2(radius * 1.1, radius * 0.24)), _color.darkened(0.4))
	draw_rect(Rect2(center + Vector2(-radius * 0.34, radius * 0.42),
		Vector2(radius * 0.68, radius * 0.22)), _color.darkened(0.25))
	# Corpo a trapezio e testa.
	var body := PackedVector2Array([
		center + Vector2(-radius * 0.16, -radius * 0.28),
		center + Vector2(radius * 0.16, -radius * 0.28),
		center + Vector2(radius * 0.3, radius * 0.44),
		center + Vector2(-radius * 0.3, radius * 0.44),
	])
	draw_colored_polygon(body, _color)
	draw_circle(center + Vector2(0.0, -radius * 0.5), radius * 0.2, _color)
	# Braccia alzate a V (posa da idolo).
	var arm_w := maxf(2.0, radius * 0.1)
	draw_line(center + Vector2(-radius * 0.14, -radius * 0.24),
		center + Vector2(-radius * 0.42, -radius * 0.62), _color, arm_w)
	draw_line(center + Vector2(radius * 0.14, -radius * 0.24),
		center + Vector2(radius * 0.42, -radius * 0.62), _color, arm_w)
	# Riflesso sul corpo.
	draw_line(center + Vector2(-radius * 0.06, -radius * 0.2),
		center + Vector2(-radius * 0.14, radius * 0.36), Color(1.0, 1.0, 1.0, 0.4), 2.0)


## Tratteggio tra due punti (per la rotta della carta nautica).
func _dashed(from: Vector2, to: Vector2, color: Color) -> void:
	var dir := to - from
	var length := dir.length()
	if length < 1.0:
		return
	dir /= length
	var step := 5.0
	var t := 0.0
	while t < length:
		var seg_end := minf(t + step * 0.55, length)
		draw_line(from + dir * t, from + dir * seg_end, color, 2.0)
		t += step
