class_name Crosshair
extends Control

## Mirino del cannone (roadmap B1 → ridisegnato in R1, definitivo in R2):
## due segni con ruoli chiari. Il PUNTATORE (rombo) è dove punta il mouse e
## segue sempre — sul cielo, su una città oltre gittata, su un albero di
## nave: non si blocca mai. Il MARKER (crocino + anello) è il punto di
## caduta reale della palla, simulato con la fisica vera: è il segno
## veritiero. Quando coincidono (bersaglio in gittata) resta solo il marker.
## Fuori gittata il marker è rosso col chevron e un filo tratteggiato lo
## lega al puntatore: "punti lì, la palla cade qui". Il pip azzurro è
## l'anticipo su una nave in moto: porta il marker sul pip e il colpo e la
## nave arrivano insieme. Visibile solo in guida (mouse catturato) e col
## cannone a bordo; legge il cannone dal gruppo boat_cannon.

const RING_RADIUS: float = 12.0
## Colori del marker: pronto, in ricarica, fuori gittata. Ogni forma è
## disegnata anche in scuro dietro, per staccare su cielo chiaro e mare.
const READY_COLOR := Color(1.0, 1.0, 1.0, 0.9)
const WAIT_COLOR := Color(1.0, 1.0, 1.0, 0.4)
const RANGE_COLOR := Color(1.0, 0.45, 0.35, 0.9)
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.45)
## Puntatore di direzione: discreto, non deve competere col marker.
const POINTER_COLOR := Color(1.0, 1.0, 1.0, 0.5)
## Semidiagonale del rombo del puntatore (px).
const POINTER_SIZE: float = 5.0
## Sotto questa distanza a schermo (px) il puntatore sparisce dentro il
## marker: un segno solo, pulito.
const POINTER_HIDE_DIST: float = 14.0
## Pip d'anticipo: azzurro, si stacca da tutto il resto.
const LEAD_COLOR := Color(0.6, 0.9, 1.0, 0.95)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	var cannon := get_tree().get_first_node_in_group(&"boat_cannon") as BoatCannon
	visible = cannon != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
		and not get_tree().paused and not GameState.on_foot
	if visible:
		queue_redraw()


func _draw() -> void:
	var cannon := get_tree().get_first_node_in_group(&"boat_cannon") as BoatCannon
	var camera := get_viewport().get_camera_3d()
	if cannon == null or camera == null:
		return
	var impact := cannon.predicted_impact()
	if impact.is_empty():
		return
	var point: Vector3 = impact["point"]
	var pointed: Vector3 = impact["pointed"]
	var wait := cannon.cooldown_fraction()
	var ready: bool = impact["ready"]
	var in_range: bool = impact["in_range"]
	var col := READY_COLOR if ready else WAIT_COLOR
	if not in_range:
		col = RANGE_COLOR

	# Marker di caduta: sempre veritiero (parabola simulata dal cannone).
	var has_marker := not camera.is_position_behind(point)
	var marker_at := Vector2.ZERO
	if has_marker:
		marker_at = camera.unproject_position(point)
		_draw_marker(marker_at, col, in_range, wait)

	# Puntatore: dove punta il mouse, SEMPRE — anche nel cielo vuoto o su
	# una città oltre gittata. Sparisce quando coincide col marker.
	if not camera.is_position_behind(pointed):
		var pointer_at := camera.unproject_position(pointed)
		if not has_marker or pointer_at.distance_to(marker_at) > POINTER_HIDE_DIST:
			_draw_pointer(pointer_at)
			# Fuori gittata il filo lega i due segni: "punti lì, cade qui".
			if has_marker and not in_range:
				_draw_link(pointer_at, marker_at)

	# Pip d'anticipo su nave in movimento.
	var lead: Variant = impact["lead"]
	if lead is Vector3 and not camera.is_position_behind(lead):
		_draw_lead(camera.unproject_position(lead))


## Marker di caduta: crocino a quattro tacche + anello. In gittata l'anello
## si riempie col cooldown (pieno = pronto). Fuori gittata è rosso, spezzato,
## con un chevron in giù ("cade corto qui"). Tutto sdoppiato in scuro dietro.
func _draw_marker(at: Vector2, col: Color, in_range: bool, wait: float) -> void:
	# Crocino a tacche (un buco al centro per non coprire il bersaglio).
	var gap := 3.5
	var tick := 6.0
	for d: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		var a := at + d * gap
		var b := at + d * (gap + tick)
		draw_line(a + Vector2.ONE, b + Vector2.ONE, SHADOW_COLOR, 2.6)
		draw_line(a, b, col, 1.6)

	if in_range:
		# Anello di cadenza: cresce in senso orario mentre il pezzo ricarica.
		draw_arc(at, RING_RADIUS, 0.0, TAU, 48, SHADOW_COLOR, 2.8, true)
		if wait <= 0.0:
			draw_arc(at, RING_RADIUS, 0.0, TAU, 48, col, 1.8, true)
		else:
			draw_arc(at, RING_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.12), 1.8, true)
			draw_arc(at, RING_RADIUS, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - wait), 48,
				col, 1.8, true)
	else:
		# Fuori gittata: anello spezzato + chevron in giù (cade corto).
		for i: int in range(8):
			var a0 := TAU * float(i) / 8.0
			draw_arc(at, RING_RADIUS, a0, a0 + TAU / 16.0, 6, col, 1.8, true)
		var tip := at + Vector2(0.0, RING_RADIUS + 5.0)
		draw_line(at + Vector2(-4.0, RING_RADIUS - 1.0), tip, col, 1.8)
		draw_line(at + Vector2(4.0, RING_RADIUS - 1.0), tip, col, 1.8)


## Rombo sottile del puntatore: la mano del giocatore, non una promessa
## balistica. Ombra dietro per staccare sul cielo.
func _draw_pointer(at: Vector2) -> void:
	var pts: Array[Vector2] = [
		at + Vector2.UP * POINTER_SIZE, at + Vector2.RIGHT * POINTER_SIZE,
		at + Vector2.DOWN * POINTER_SIZE, at + Vector2.LEFT * POINTER_SIZE,
	]
	for i: int in range(4):
		var a := pts[i]
		var b := pts[(i + 1) % 4]
		draw_line(a + Vector2.ONE, b + Vector2.ONE, SHADOW_COLOR, 2.4)
		draw_line(a, b, POINTER_COLOR, 1.4)


## Filo tratteggiato puntatore → marker quando il bersaglio è oltre gittata:
## lega "dove punti" a "dove cade" senza rubare l'occhio.
func _draw_link(from: Vector2, to: Vector2) -> void:
	draw_dashed_line(from, to, Color(RANGE_COLOR, 0.35), 1.0, 6.0)


## Pip d'anticipo: cerchietto azzurro col punto — il marker va portato qui.
func _draw_lead(at: Vector2) -> void:
	draw_arc(at, 4.0, 0.0, TAU, 24, SHADOW_COLOR, 2.4, true)
	draw_arc(at, 4.0, 0.0, TAU, 24, LEAD_COLOR, 1.4, true)
	draw_circle(at, 1.2, LEAD_COLOR)
