class_name Crosshair
extends Control

## Mirino del cannone (roadmap B1): punto + anello al centro dello schermo,
## visibile solo in guida (mouse catturato) e col cannone a bordo. L'anello
## si riempie col cooldown: pieno = pronto a sparare. Creato dall'HUD in
## codice; legge il cannone dal gruppo boat_cannon, nessun accoppiamento.

const RING_RADIUS: float = 13.0
const READY_COLOR := Color(1.0, 1.0, 1.0, 0.9)
const WAIT_COLOR := Color(1.0, 1.0, 1.0, 0.35)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	var cannon := get_tree().get_first_node_in_group(&"boat_cannon") as BoatCannon
	visible = cannon != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
		and not get_tree().paused
	if visible:
		queue_redraw()


func _draw() -> void:
	var cannon := get_tree().get_first_node_in_group(&"boat_cannon") as BoatCannon
	if cannon == null:
		return
	var center := size * 0.5
	var wait := cannon.cooldown_fraction()
	var ready := wait <= 0.0
	draw_circle(center, 2.2, READY_COLOR if ready else WAIT_COLOR)
	# Anello di cadenza: cresce in senso orario mentre il pezzo ricarica.
	draw_arc(center, RING_RADIUS, 0.0, TAU, 40, Color(1, 1, 1, 0.15), 2.0, true)
	if ready:
		draw_arc(center, RING_RADIUS, 0.0, TAU, 40, READY_COLOR, 2.0, true)
	else:
		draw_arc(center, RING_RADIUS, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - wait), 40,
			WAIT_COLOR, 2.0, true)
