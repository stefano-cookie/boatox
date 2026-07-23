extends CanvasLayer

## HUD: denaro, barre scafo e benzina, stiva dettagliata per tipo di boa,
## barca corrente, tachimetro in nodi, zona di mare, stato del meteo,
## messaggi transitori e alert persistente (countdown fuori zona). Legge
## tutto da GameState via segnali e dalla barca per la velocità: nessuna
## logica di gioco qui.

const MS_TO_KNOTS: float = 1.94384
const ZONE_NAMES: Array[String] = ["Acque calme", "Acque medie", "Mare aperto"]
## Stato locale del mare nel punto della barca (feedback playtest M3):
## soglie di agitazione (zona × vento × meteo) e nomi/colori affiancati.
## Le soglie alte ricalcano quelle di caos e danni della barca.
const SEA_STATE_STEPS: Array[float] = [1.1, 1.9, 2.8, 3.4]
const SEA_STATE_NAMES: Array[String] = [
	"calmo", "increspato", "agitato", "grosso", "tempesta",
]
const SEA_STATE_COLORS: Array[Color] = [
	Color(0.75, 0.95, 0.85),
	Color(0.85, 0.95, 0.6),
	Color(1.0, 0.85, 0.4),
	Color(1.0, 0.6, 0.35),
	Color(1.0, 0.4, 0.3),
]
const FUEL_OK_COLOR := Color(0.85, 0.9, 0.95)
const FUEL_LOW_COLOR := Color(1.0, 0.35, 0.3)
## Sotto questa frazione di serbatoio la scritta benzina diventa rossa.
const FUEL_LOW_RATIO: float = 0.2

@export var boat: Boat
@export var sea: Sea
@export var weather: Weather
@export var world: World
## Moltiplica i font_size di tutti i pannelli all'avvio (feedback playtest
## round 2: "l'interfaccia è troppo piccola"). 1.0 = dimensioni base della
## scena; si tara da Inspector senza toccare i singoli nodi.
@export var ui_scale: float = 1.0

## Flash rosso della barra scafo a ogni urto.
const HULL_FLASH_COLOR := Color(1.0, 0.3, 0.25)
const HULL_FLASH_TIME: float = 0.4

## Stato del radar (visibile solo dopo lo sblocco dalla missione del nipote).
const RADAR_READY_COLOR := Color(0.55, 0.9, 1.0)
const RADAR_ACTIVE_COLOR := Color(0.5, 1.0, 0.6)
const RADAR_COOLDOWN_COLOR := Color(0.7, 0.75, 0.82)

@onready var _money_label: Label = $TopLeft/Margin/VBox/MoneyLabel
@onready var _boat_label: Label = $TopLeft/Margin/VBox/BoatLabel
@onready var _hull_bar: ProgressBar = $TopLeft/Margin/VBox/HullRow/HullBar
@onready var _fuel_bar: ProgressBar = $TopLeft/Margin/VBox/FuelRow/FuelBar
@onready var _fuel_title: Label = $TopLeft/Margin/VBox/FuelRow/FuelTitle
@onready var _fuel_label: Label = $TopLeft/Margin/VBox/FuelRow/FuelLabel
@onready var _inv_chip: PanelContainer = $InvChip
@onready var _inv_label: Label = $InvChip/InvLabel
@onready var _notice_label: Label = $NoticeLabel
@onready var _notice_timer: Timer = $NoticeTimer
@onready var _danger_label: Label = $DangerLabel
@onready var _sea_box: PanelContainer = $SeaBox
@onready var _speed_label: Label = $SeaBox/Margin/VBox/SpeedLabel
@onready var _speed_bar: ProgressBar = $SeaBox/Margin/VBox/SpeedBar
@onready var _zone_label: Label = $SeaBox/Margin/VBox/ZoneLabel
@onready var _weather_label: Label = $SeaBox/Margin/VBox/WeatherLabel
@onready var _radar_label: Label = $SeaBox/Margin/VBox/RadarLabel
@onready var _goal_box: PanelContainer = $GoalBox
@onready var _goal_label: Label = $GoalBox/GoalMargin/GoalLabel
@onready var _minimap: Minimap = $Minimap
@onready var _toast_stack: VBoxContainer = $ToastStack
@onready var _mission_tracker: PanelContainer = $MissionTracker
@onready var _mission_rows: VBoxContainer = $MissionTracker/Margin/VBox/Rows
@onready var _celebration: Label = $CelebrationLabel

var _hull_flash: Tween
## Tempo accumulato per gli effetti pulsanti (allarme mare, ecc.).
var _elapsed: float = 0.0
## Etichette countdown vive nel tracker: {label, mission_index} aggiornate
## ogni frame senza ricostruire le righe.
var _countdown_labels: Array[Label] = []
## Numero massimo di toast di raccolta impilati insieme (i più vecchi
## sfumano da soli; oltre questo tetto i più vecchi vengono rimossi subito).
const MAX_TOASTS: int = 6
const TOAST_LIFETIME: float = 3.2
## Colore/valore per i toast di raccolta, costruiti dai segnali granulari.
const MONEY_COLOR := Color(0.55, 0.95, 0.6)
const FUEL_TOAST_COLOR := Color(1.0, 0.5, 0.35)


func _ready() -> void:
	GameState.money_changed.connect(_on_money_changed)
	GameState.hull_changed.connect(_on_hull_changed)
	GameState.fuel_changed.connect(_on_fuel_changed)
	GameState.cargo_changed.connect(_on_cargo_changed)
	GameState.boat_changed.connect(_on_boat_changed)
	GameState.notice_posted.connect(_on_notice_posted)
	GameState.danger_changed.connect(_on_danger_changed)
	GameState.danger_cleared.connect(_danger_label.hide)
	GameState.tutorial_changed.connect(_on_tutorial_changed)
	GameState.boat_hit.connect(_on_boat_hit)
	# Toast di raccolta (roadmap R2): i segnali granulari, prima tutti sulla
	# scritta centrale, ora impilano notifiche in basso a destra.
	GameState.buoy_collected.connect(_on_buoy_toast)
	GameState.fish_caught.connect(_on_fish_toast)
	GameState.loot_collected.connect(_on_loot_toast)
	GameState.fuel_collected.connect(_on_fuel_toast)
	GameState.cargo_sold.connect(_on_money_toast)
	# Tracker missione (roadmap R2): pannello a lista sempre visibile.
	GameState.mission_changed.connect(_rebuild_mission_tracker)
	GameState.mission_completed.connect(_on_mission_completed)
	_minimap.setup(boat, sea, world)
	_notice_timer.timeout.connect(_notice_label.hide)
	_notice_label.hide()
	_danger_label.hide()
	# Mirino del cannone (roadmap B1): creato in codice, si accende da solo
	# quando il cannone è a bordo e il mouse è catturato.
	add_child(Crosshair.new())
	_on_money_changed(GameState.money)
	_on_hull_changed(GameState.hull, GameState.hull_max())
	_on_fuel_changed(GameState.fuel, GameState.fuel_capacity())
	_on_cargo_changed()
	_on_boat_changed(GameState.current_def())
	_apply_ui_scale()
	_on_tutorial_changed(GameState.tutorial_step, GameState.tutorial_hint())
	_update_radar()
	_celebration.hide()
	_celebration.modulate.a = 0.0
	_rebuild_mission_tracker()


## Impulso radar (tasto R): rivela boe e zone in minimappa. Attivo solo
## dopo lo sblocco e a cooldown scaduto (guardie in Radar.can_ping);
## nessun altro pannello lo usa, quindi non c'è conflitto con Esc/E.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("radar_ping") and boat != null and Radar.can_ping():
		get_viewport().set_input_as_handled()
		Radar.ping(boat.global_position)


func _process(delta: float) -> void:
	if boat == null:
		return
	_elapsed += delta
	var speed := absf(boat.current_speed())
	_speed_label.text = "%d nodi" % roundi(speed * MS_TO_KNOTS)
	_speed_bar.value = speed
	if sea != null:
		_update_sea_state()
	_update_radar()
	_update_mission_countdown()
	_position_bottom_left()


## Meteo onesto (roadmap R2): l'indicatore principale è lo stato LOCALE del
## mare nel punto della barca (zona × vento × meteo), non più lo stato
## globale di Weather. Entrando in acque che fanno danno lampeggia un
## allarme: prima potevi prendere danni da tempesta con l'HUD che diceva
## "calmo".
func _update_sea_state() -> void:
	var pos := boat.global_position
	var agit := sea.agitation(pos)
	var zone := sea.zone_index(pos)
	var state := _sea_state_index(agit)
	_weather_label.text = ZONE_NAMES[zone]
	_weather_label.modulate = Color(0.72, 0.82, 0.92)
	var threshold: float = boat.storm_damage_threshold if boat != null else 3.4
	if threshold > 0.0 and agit >= threshold:
		# In acque da danno: allarme rosso pulsante, così sai perché lo scafo
		# sta calando.
		var pulse := 0.5 + 0.5 * sin(_elapsed * 8.0)
		_zone_label.text = "⚠ %s" % SEA_STATE_NAMES[state].to_upper()
		_zone_label.modulate = SEA_STATE_COLORS[4].lerp(Color(1, 1, 1), pulse * 0.5)
	else:
		_zone_label.text = SEA_STATE_NAMES[state].capitalize()
		_zone_label.modulate = SEA_STATE_COLORS[state]


## Colloca in basso a sinistra il pannello mare/nodi (in fondo) e la chip
## stiva subito sopra: liberato l'angolo dalla minimappa (ora in alto a
## destra), non dipendono più da lei.
func _position_bottom_left() -> void:
	var vp := get_viewport().get_visible_rect().size
	_sea_box.position = Vector2(16.0, vp.y - _sea_box.size.y - 16.0)
	_inv_chip.position = Vector2(16.0, _sea_box.position.y - _inv_chip.size.y - 10.0)


## Riga di stato del radar in basso a destra: nascosta finché è bloccato,
## poi pronto / attivo (finestra) / in cooldown.
func _update_radar() -> void:
	if not GameState.radar_unlocked:
		_radar_label.hide()
		return
	_radar_label.show()
	if Radar.is_active():
		_radar_label.text = "Radar attivo · %d s" % ceili(Radar.window_left())
		_radar_label.modulate = RADAR_ACTIVE_COLOR
	elif Radar.cooldown_left() > 0.0:
		_radar_label.text = "Radar: %d s" % ceili(Radar.cooldown_left())
		_radar_label.modulate = RADAR_COOLDOWN_COLOR
	else:
		_radar_label.text = "Radar: pronto (R)"
		_radar_label.modulate = RADAR_READY_COLOR


## Indice dello stato locale del mare a partire dall'agitazione.
func _sea_state_index(agitation: float) -> int:
	for i in SEA_STATE_STEPS.size():
		if agitation < SEA_STATE_STEPS[i]:
			return i
	return SEA_STATE_STEPS.size()


func _on_money_changed(amount: int) -> void:
	_money_label.text = "%d $" % amount


func _on_hull_changed(current: float, max_value: float) -> void:
	_hull_bar.max_value = max_value
	_hull_bar.value = current


func _on_fuel_changed(current: float, max_value: float) -> void:
	_fuel_bar.max_value = max_value
	_fuel_bar.value = current
	_fuel_label.text = "%d L" % ceili(current)
	var low := current <= max_value * FUEL_LOW_RATIO
	_fuel_title.modulate = FUEL_LOW_COLOR if low else Color.WHITE
	_fuel_label.modulate = FUEL_LOW_COLOR if low else FUEL_OK_COLOR


## Chip stiva in basso a sinistra: stiva usata/capacità. Il mouse è
## catturato dalla camera, quindi non è cliccabile: la scritta (I) ricorda
## il tasto che apre il pannello inventario completo.
func _on_cargo_changed() -> void:
	var count := GameState.cargo_count()
	var capacity := GameState.cargo_capacity()
	_inv_label.text = "Stiva %d/%d  (I)" % [count, capacity]
	_inv_label.modulate = Color(1, 0.85, 0.55) if count >= capacity else Color.WHITE


func _on_boat_changed(def: BoatDefinition) -> void:
	_boat_label.text = def.display_name
	if boat != null:
		_speed_bar.max_value = GameState.effective_max_speed()
	_on_fuel_changed(GameState.fuel, GameState.fuel_capacity())


func _on_notice_posted(text: String) -> void:
	_notice_label.text = text
	_notice_label.show()
	_notice_timer.start()


func _on_danger_changed(text: String) -> void:
	_danger_label.text = text
	_danger_label.show()


## Obiettivo guidato: mostra la riga della tappa, nasconde il pannello a
## tutorial finito.
func _on_tutorial_changed(step: int, text: String) -> void:
	if step >= GameState.TUTORIAL_DONE or text.is_empty():
		_goal_box.hide()
		return
	_goal_label.text = text
	_goal_box.show()


# --- Toast di raccolta (roadmap R2) ------------------------------------------

## Ogni pickup impila un toast (pastiglia colore + testo) in basso a destra,
## invece di scorrere sull'unica scritta centrale. I segnali granulari di
## GameState arrivano qui e diventano righe.
func _on_buoy_toast(type: int) -> void:
	_push_item_toast(GameState.buoy_item(type))


func _on_fish_toast(type: int) -> void:
	_push_item_toast(GameState.fish_item(type))


func _on_loot_toast(tier: int) -> void:
	_push_item_toast(GameState.loot_item(tier))


## Toast di un item raccolto (roadmap R4): pastiglia col colore dell'item,
## nome e valore unitario, tutto dall'ItemDefinition.
func _push_item_toast(def: ItemDefinition) -> void:
	if def == null:
		return
	_push_toast(def.color, def.display_name.capitalize(), "+%d $" % def.base_value)


func _on_fuel_toast(liters: float) -> void:
	_push_toast(FUEL_TOAST_COLOR, "Tanica", "+%d L" % roundi(liters))


func _on_money_toast(amount: int) -> void:
	if amount <= 0:
		return
	_push_toast(MONEY_COLOR, "Incasso", "+%d $" % amount)


## Costruisce e anima un toast: pastiglia colore, nome, valore. Compare con
## una comparsa morbida, resta TOAST_LIFETIME, poi sfuma. Oltre MAX_TOASTS i
## più vecchi vengono rimossi subito.
func _push_toast(color: Color, item_name: String, value: String) -> void:
	while _toast_stack.get_child_count() >= MAX_TOASTS:
		var oldest := _toast_stack.get_child(0)
		_toast_stack.remove_child(oldest)
		oldest.queue_free()
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.13, 0.2, 0.9)
	style.set_border_width_all(1)
	style.border_color = Color(color, 0.7)
	style.set_corner_radius_all(9)
	style.content_margin_left = 14.0
	style.content_margin_right = 16.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dot := ColorRect.new()
	dot.color = color
	dot.custom_minimum_size = Vector2(16, 16)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dot)
	var name_label := Label.new()
	name_label.text = item_name
	name_label.add_theme_font_size_override("font_size", roundi(24 * ui_scale))
	row.add_child(name_label)
	var value_label := Label.new()
	value_label.text = value
	value_label.add_theme_font_size_override("font_size", roundi(24 * ui_scale))
	value_label.modulate = color.lerp(Color.WHITE, 0.35)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	row.add_child(value_label)
	panel.add_child(row)
	_toast_stack.add_child(panel)
	panel.modulate.a = 0.0
	panel.pivot_offset = Vector2(0, 16)
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.18)
	tween.tween_interval(TOAST_LIFETIME)
	tween.tween_property(panel, "modulate:a", 0.0, 0.5)
	tween.tween_callback(panel.queue_free)


# --- Tracker missione (roadmap R2) -------------------------------------------

## Ricostruisce la lista delle missioni attive (oggi 0 o 1). Costruita come
## lista fin da subito: le missioni NPC di R5 aggiungeranno solo righe.
func _rebuild_mission_tracker() -> void:
	_countdown_labels.clear()
	for child in _mission_rows.get_children():
		child.queue_free()
	var missions := GameState.active_missions()
	if missions.is_empty():
		_mission_tracker.hide()
		return
	_mission_tracker.show()
	for mission in missions:
		_mission_rows.add_child(_build_mission_row(mission))


## Una riga del tracker: titolo, tappa, progresso e (se c'è) countdown.
func _build_mission_row(mission: Dictionary) -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	var title := Label.new()
	title.text = str(mission.get("title", ""))
	title.add_theme_font_size_override("font_size", roundi(26 * ui_scale))
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.72))
	vbox.add_child(title)
	var stage := Label.new()
	stage.text = str(mission.get("stage", ""))
	stage.add_theme_font_size_override("font_size", roundi(20 * ui_scale))
	stage.modulate = Color(0.82, 0.88, 0.95)
	vbox.add_child(stage)
	var progress := Label.new()
	progress.text = str(mission.get("progress", ""))
	progress.add_theme_font_size_override("font_size", roundi(20 * ui_scale))
	progress.modulate = Color(0.6, 0.85, 1.0)
	vbox.add_child(progress)
	var countdown := float(mission.get("countdown", -1.0))
	if countdown >= 0.0:
		var timer_label := Label.new()
		timer_label.add_theme_font_size_override("font_size", roundi(22 * ui_scale))
		vbox.add_child(timer_label)
		_countdown_labels.append(timer_label)
		_update_mission_countdown()
	return vbox


## Aggiorna solo le etichette countdown (per frame), senza ricostruire le
## righe. Legge il tempo residuo dalla missione attiva.
func _update_mission_countdown() -> void:
	if _countdown_labels.is_empty():
		return
	var left := maxf(GameState.mission_time_left, 0.0)
	var text := "⏱ %d:%02d" % [int(left) / 60, int(left) % 60]
	var urgent := left <= 30.0
	for label in _countdown_labels:
		label.text = text
		label.modulate = Color(1, 0.4, 0.35) if urgent else Color(1, 0.85, 0.5)


## Missione compiuta: pop celebrativo al centro (oltre al suono). Il tracker
## si svuota poco dopo via mission_changed.
func _on_mission_completed(what: String, reward: int) -> void:
	_celebration.text = "✓ %s!  +%d $" % [what, reward]
	_celebration.show()
	_celebration.modulate.a = 1.0
	_celebration.scale = Vector2(0.6, 0.6)
	var tween := create_tween()
	tween.tween_property(_celebration, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.4)
	tween.tween_property(_celebration, "modulate:a", 0.0, 0.6)
	tween.tween_callback(_celebration.hide)


## Flash rosso della barra scafo a ogni urto (feedback playtest round 2:
## "quando sbatti non te ne accorgi"). La forza qui non serve: il flash è
## uguale, sono lo shake camera e le particelle a scalare con l'impatto.
func _on_boat_hit(_force: float) -> void:
	if _hull_flash != null and _hull_flash.is_valid():
		_hull_flash.kill()
	_hull_bar.modulate = HULL_FLASH_COLOR
	_hull_flash = create_tween()
	_hull_flash.tween_property(_hull_bar, "modulate", Color.WHITE, HULL_FLASH_TIME)


# --- Scala UI ----------------------------------------------------------------

## Moltiplica i font (e le dimensioni minime delle barre) dei pannelli per
## ui_scale. I pannelli sono Container e si ridimensionano al contenuto,
## quindi crescono senza uscire dallo schermo (restano ancorati agli angoli).
func _apply_ui_scale() -> void:
	if is_equal_approx(ui_scale, 1.0):
		return
	for root: Node in [$TopLeft, $SeaBox, $GoalBox, $MissionTracker]:
		_scale_control_tree(root)
	_scale_font(_inv_label)
	_scale_font(_notice_label)
	_scale_font(_danger_label)
	_scale_font(_celebration)


func _scale_control_tree(node: Node) -> void:
	for child in node.get_children():
		if child is ProgressBar:
			(child as ProgressBar).custom_minimum_size *= ui_scale
		elif child is Label or child is RichTextLabel:
			_scale_font(child)
		_scale_control_tree(child)


func _scale_font(control: Control) -> void:
	var key := "normal_font_size" if control is RichTextLabel else "font_size"
	var size := control.get_theme_font_size(key)
	control.add_theme_font_size_override(key, roundi(size * ui_scale))
