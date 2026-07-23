class_name RaceCourse
extends Node3D

## Regata a checkpoint (GDD § Corse): percorso fisso di cancelli che
## attraversa le tre fasce di mare — motore e stabilità contano davvero —
## contro le IA di GameState.RACE_AI. Fermi nella zona di partenza, E
## avvia il conto alla rovescia. Il cancello da prendere è verde (e
## segnato in minimappa), i presi spariscono. Premi per piazzamento in
## GameState.RACE_PRIZES; la prima vittoria sblocca il Cabinato.

enum State { IDLE, COUNTDOWN, RACING, RESULT }

## Sopra questa velocità non si parte: prima ci si ferma.
@export var start_max_speed: float = 1.5
## Raggio entro cui un cancello conta come preso dal giocatore.
@export var gate_radius: float = 16.0
@export var countdown_seconds: float = 3.0
## Spot difficile al largo (feedback playtest round 2): usa il set IA
## aggressivo GameState.RACE_AI_HARD invece di quello sotto costa.
@export var ai_hard: bool = false
## Moltiplicatore dei premi dello spot: al largo si rischia di più e si
## guadagna di più (GDD pillar 2). 1.0 = gara base sotto costa.
@export var prize_multiplier: float = 1.0

@export_group("Percorso procedurale (roadmap R3)")
## Se vero, i checkpoint della scena vengono ignorati e il percorso è
## generato attorno all'origine con proc_seed: spot di gara che il World
## semina in punti casuali del largo, diversi a ogni partita.
@export var procedural: bool = false
## Numero di cancelli del percorso generato (senza contare il traguardo).
@export var proc_gate_count: int = 6
## Raggio dell'anello di cancelli del percorso generato.
@export var proc_radius: float = 150.0
## Seme del percorso generato: lo imposta chi spawna la gara, così spot
## diversi hanno tracciati diversi ma stabili per la sessione.
var proc_seed: int = 0

## Assegnata dal World: serve a IA e classifica (rallentamento a zone).
var sea: Sea

## Griglia di partenza delle IA, dietro la linea (verso -X, il percorso
## parte verso +X).
const START_OFFSETS: Array[Vector3] = [
	Vector3(-8.0, 0.0, -7.0), Vector3(-11.0, 0.0, 1.0), Vector3(-8.0, 0.0, 9.0),
]
const BEAM_NEXT_COLOR := Color(0.35, 1.0, 0.55, 0.5)
const BEAM_FAR_COLOR := Color(1.0, 1.0, 1.0, 0.12)

var _state := State.IDLE
## Barca in zona di partenza; _race_boat è quella a cui la gara ha
## spento la guida (pattern del Port).
var _boat: Boat = null
var _race_boat: Boat = null
var _waypoints: Array[Vector3] = []
var _gates: Array[Node3D] = []
var _beam_materials: Array[StandardMaterial3D] = []
var _racers: Array[AIRacer] = []
## Ordine d'arrivo (nomi); il giocatore entra come "Tu".
var _finish_order: Array[String] = []
var _player_next: int = 0
var _count_left: float = 0.0
var _via_left: float = 0.0

@onready var _start_zone: Area3D = $StartZone
@onready var _checkpoints: Node3D = $Checkpoints
@onready var _hint: Label = $RaceUI/Hint
@onready var _status: Label = $RaceUI/Status
@onready var _big_label: Label = $RaceUI/BigLabel
@onready var _panel: PanelContainer = $RaceUI/Panel
@onready var _standings: Label = $RaceUI/Panel/Margin/VBox/Standings
@onready var _close_button: Button = $RaceUI/Panel/Margin/VBox/CloseButton


func _ready() -> void:
	add_to_group(&"race_course")
	_start_zone.body_entered.connect(_on_zone_body_entered)
	_start_zone.body_exited.connect(_on_zone_body_exited)
	_close_button.pressed.connect(_close_result)
	GameState.hull_depleted.connect(_on_hull_depleted)
	if procedural:
		_generate_checkpoints()
	_build_gates()
	_panel.hide()
	_hint.hide()
	_status.hide()
	_big_label.hide()


func _process(delta: float) -> void:
	_update_hint()
	match _state:
		State.COUNTDOWN:
			_count_left -= delta
			if _count_left <= 0.0:
				_go()
			else:
				_big_label.text = str(ceili(_count_left))
		State.RACING:
			if _via_left > 0.0:
				_via_left -= delta
				if _via_left <= 0.0:
					_big_label.hide()
			_check_player_gate()
			# _check_player_gate può concludere la gara (ultimo cancello →
			# _finish_player cambia stato): aggiorna la classifica solo se
			# siamo ancora in gara, altrimenti _player_rank legge fuori limiti.
			if _state == State.RACING:
				_update_status()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if _state == State.RESULT:
			get_viewport().set_input_as_handled()
			_close_result()
		elif _state == State.IDLE and _can_start():
			get_viewport().set_input_as_handled()
			_start_race()
	elif event.is_action_pressed("ui_cancel") and _state != State.IDLE:
		# Consumato: altrimenti lo stesso Esc aprirebbe anche la pausa.
		get_viewport().set_input_as_handled()
		if _state == State.RESULT:
			_close_result()
		else:
			_retire("Regata abbandonata")


# --- Stato per la minimappa --------------------------------------------------

func is_racing() -> bool:
	return _state == State.COUNTDOWN or _state == State.RACING


func next_gate_position() -> Vector3:
	return _waypoints[mini(_player_next, _waypoints.size() - 1)]


## Punto di partenza della regata: marker permanente in minimappa (feedback
## playtest round 2: il giocatore deve sapere che la regata esiste e dov'è).
func start_position() -> Vector3:
	return global_position


# --- Partenza ----------------------------------------------------------------

func _can_start() -> bool:
	return _boat != null and absf(_boat.current_speed()) <= start_max_speed


func _on_zone_body_entered(body: Node3D) -> void:
	if body is Boat:
		_boat = body


func _on_zone_body_exited(body: Node3D) -> void:
	if body == _boat:
		_boat = null


func _on_hull_depleted() -> void:
	if _state == State.COUNTDOWN or _state == State.RACING:
		_retire("Regata annullata: scafo a pezzi")


func _start_race() -> void:
	_state = State.COUNTDOWN
	_race_boat = _boat
	_race_boat.input_enabled = false
	_race_boat.reset_motion()
	_player_next = 0
	_finish_order.clear()
	_count_left = countdown_seconds
	_spawn_racers()
	for gate in _gates:
		gate.show()
	_refresh_gates()
	_big_label.text = str(ceili(countdown_seconds))
	_big_label.show()
	_status.show()
	_update_status()


## Le IA si tarano sul giocatore al via (feedback playtest M3): frazioni
## della sua velocità effettiva e scarti sulla sua stabilità, upgrade
## compresi. La gara resta combattuta con ogni barca: il rivale veloce
## si batte con le traiettorie, non comprando motore.
func _spawn_racers() -> void:
	var player_speed := GameState.effective_max_speed()
	var player_stability := GameState.effective_stability()
	var ai_set := GameState.race_ai_set(ai_hard)
	for i in ai_set.size():
		var def: Dictionary = ai_set[i]
		var racer := AIRacer.new()
		racer.racer_name = def["name"]
		racer.visual_scene = load(def["visual"])
		racer.max_speed = player_speed * def["speed_ratio"]
		racer.stability = clampf(player_stability + def["stability_delta"], 0.0, 1.0)
		racer.turn_speed_deg = def["turn"]
		racer.sea = sea
		add_child(racer)
		racer.global_position = global_position + START_OFFSETS[i % START_OFFSETS.size()]
		racer.begin_course(_waypoints)
		racer.finished_course.connect(_on_racer_finished)
		_racers.append(racer)


func _go() -> void:
	_state = State.RACING
	_race_boat.input_enabled = true
	for racer in _racers:
		racer.go()
	_big_label.text = "VIA!"
	_via_left = 1.0


# --- Gara --------------------------------------------------------------------

func _check_player_gate() -> void:
	var target := _waypoints[_player_next]
	var flat := _race_boat.global_position - target
	flat.y = 0.0
	if flat.length() > gate_radius:
		return
	_player_next += 1
	if _player_next >= _waypoints.size():
		_finish_player()
	else:
		_refresh_gates()


func _on_racer_finished(racer: AIRacer) -> void:
	_finish_order.append(racer.racer_name)


func _finish_player() -> void:
	var rank := _finish_order.size() + 1
	_finish_order.append("Tu")
	GameState.record_race_result(rank, _racers.size() + 1, prize_multiplier)
	_state = State.RESULT
	_race_boat.input_enabled = false
	_race_boat.reset_motion()
	_status.hide()
	_big_label.hide()
	_show_standings(rank)


func _show_standings(rank: int) -> void:
	var lines: Array[String] = []
	for i in _finish_order.size():
		lines.append("%d°  %s" % [i + 1, _finish_order[i]])
	# Chi è ancora in mare, in ordine di avanzamento.
	var unfinished := _racers.filter(func(r: AIRacer) -> bool: return not r.has_finished())
	unfinished.sort_custom(func(a: AIRacer, b: AIRacer) -> bool: return a.progress() > b.progress())
	var place := _finish_order.size()
	for racer: AIRacer in unfinished:
		place += 1
		lines.append("%d°  %s (in mare)" % [place, racer.racer_name])
	lines.append("")
	lines.append("Premio: %d $" % GameState.race_prize(rank, prize_multiplier))
	_standings.text = "\n".join(lines)
	GameState.push_ui_focus()
	_panel.show()
	_close_button.grab_focus()


func _player_rank() -> int:
	var next := mini(_player_next, _waypoints.size() - 1)
	var progress := float(_player_next) * 10000.0 \
		- _race_boat.global_position.distance_to(_waypoints[next])
	var rank := 1 + _finish_order.size()
	for racer in _racers:
		if not racer.has_finished() and racer.progress() > progress:
			rank += 1
	return rank


func _update_status() -> void:
	_status.text = "Cancello %d/%d  ·  Posizione %d°/%d" % [
		_player_next + 1, _waypoints.size(), _player_rank(), _racers.size() + 1,
	]


func _retire(message: String) -> void:
	GameState.post_notice(message)
	_cleanup()


func _close_result() -> void:
	_panel.hide()
	GameState.pop_ui_focus()
	_cleanup()


func _cleanup() -> void:
	_state = State.IDLE
	_status.hide()
	_big_label.hide()
	_panel.hide()
	for gate in _gates:
		gate.hide()
	for racer in _racers:
		racer.queue_free()
	_racers.clear()
	if _race_boat != null:
		_race_boat.input_enabled = true
		_race_boat = null


# --- Cancelli ----------------------------------------------------------------

## Percorso generato attorno all'origine (roadmap R3): scarta i checkpoint
## della scena e ne crea di nuovi su un anello, con l'ultimo (traguardo)
## sulla linea di partenza. proc_seed dà un tracciato diverso per spot ma
## stabile per la sessione. L'anello è spostato in avanti (+Z) così non
## copre la zona di partenza all'origine.
func _generate_checkpoints() -> void:
	for child in _checkpoints.get_children():
		_checkpoints.remove_child(child)
		child.free()
	var rng := RandomNumberGenerator.new()
	rng.seed = proc_seed
	var start_angle := -PI * 0.5
	for i in proc_gate_count:
		var angle := start_angle + TAU * float(i) / float(proc_gate_count)
		var r := proc_radius * rng.randf_range(0.75, 1.15)
		var marker := Marker3D.new()
		_checkpoints.add_child(marker)
		marker.position = Vector3(cos(angle) * r, 0.0, sin(angle) * r + proc_radius)
	# Traguardo sulla linea di partenza.
	var finish := Marker3D.new()
	_checkpoints.add_child(finish)
	finish.position = Vector3.ZERO


## Un pilone luminoso con colonna di luce per ogni marker in Checkpoints
## (l'ultimo è il traguardo, sulla linea di partenza). Visibili solo in
## gara: il prossimo è verde, i presi spariscono.
func _build_gates() -> void:
	var pylon_mesh := CylinderMesh.new()
	pylon_mesh.top_radius = 0.4
	pylon_mesh.bottom_radius = 0.55
	pylon_mesh.height = 4.0
	var pylon_mat := StandardMaterial3D.new()
	pylon_mat.albedo_color = Color(1.0, 0.55, 0.15)
	pylon_mat.emission_enabled = true
	pylon_mat.emission = Color(1.0, 0.55, 0.15)
	pylon_mat.emission_energy_multiplier = 0.5
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 1.4
	beam_mesh.bottom_radius = 1.4
	beam_mesh.height = 30.0
	for marker: Node3D in _checkpoints.get_children():
		var pos := marker.global_position
		pos.y = 0.0
		_waypoints.append(pos)
		var gate := Node3D.new()
		add_child(gate)
		gate.global_position = pos
		var pylon := MeshInstance3D.new()
		pylon.mesh = pylon_mesh
		pylon.material_override = pylon_mat
		pylon.position.y = 1.6
		gate.add_child(pylon)
		var beam := MeshInstance3D.new()
		beam.mesh = beam_mesh
		var beam_mat := StandardMaterial3D.new()
		beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		beam_mat.albedo_color = BEAM_FAR_COLOR
		beam.material_override = beam_mat
		beam.position.y = 15.0
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gate.add_child(beam)
		gate.hide()
		_gates.append(gate)
		_beam_materials.append(beam_mat)


func _refresh_gates() -> void:
	for i in _gates.size():
		_gates[i].visible = i >= _player_next
		_beam_materials[i].albedo_color = BEAM_NEXT_COLOR if i == _player_next \
			else BEAM_FAR_COLOR


func _update_hint() -> void:
	# Durante la gara (e il countdown) l'hint ricorda la ritirata gratuita
	# (feedback playtest round 2: la ritirata esisteva ma era invisibile).
	if _state == State.COUNTDOWN or _state == State.RACING:
		_hint.show()
		_hint.text = "Esc — abbandona la regata (gratis)"
		return
	if _boat == null or _state != State.IDLE:
		_hint.hide()
		return
	_hint.show()
	if absf(_boat.current_speed()) <= start_max_speed:
		_hint.text = "Premi E per la regata"
	else:
		_hint.text = "Rallenta per la regata"
