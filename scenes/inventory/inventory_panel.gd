extends CanvasLayer

## Pannello inventario della stiva (roadmap P2 § Inventario), aperto col
## tasto I. Oggi la stiva è solo una riga di testo nell'HUD; qui diventa una
## griglia leggibile: per ogni tipo di boa e di pesce un'icona, la quantità
## e il valore unitario, più stiva usata/capacità e valore totale del carico.
##
## Pattern UI del progetto: mette in pausa l'albero come il menu di pausa
## (process_mode ALWAYS per ricevere input a gioco fermo), libera/ricattura
## il mouse con push_ui_focus/pop_ui_focus (la ChaseCamera reagisce da sola).
## Non si apre se un altro pannello ha il focus (porto, pesca, regata, pausa):
## la guardia ui_focus_open() le rende mutuamente esclusive. Si chiude con I o
## Esc; Esc viene consumato così non fa scattare anche la pausa.

const ICON_SIZE: float = 64.0
## Righe con quantità 0 restano visibili (catalogo) ma smorzate.
const EMPTY_MODULATE := Color(1.0, 1.0, 1.0, 0.32)

## Durata dell'animazione di apertura/chiusura (feedback playtest: far
## capire che si sta aprendo la stiva). Breve: è feedback, non un'attesa.
const ANIM_TIME: float = 0.16
const CLOSED_SCALE := Vector2(0.9, 0.9)

@onready var _root: Control = $Overlay
@onready var _panel: PanelContainer = $Overlay/Center/Panel
@onready var _subtitle: RichTextLabel = $Overlay/Center/Panel/Margin/VBox/Subtitle
@onready var _buoy_grid: GridContainer = $Overlay/Center/Panel/Margin/VBox/BuoySection/BuoyGrid
@onready var _fish_grid: GridContainer = $Overlay/Center/Panel/Margin/VBox/FishSection/FishGrid

var _open: bool = false
## Tween corrente di apertura/chiusura: si annulla prima di ripartire, così
## premere I ripetutamente non lascia il pannello a metà.
var _anim: Tween
## Celle costruite una volta e aggiornate a ogni apertura. type -> nodi.
var _buoy_cells: Dictionary[int, Dictionary] = {}
var _fish_cells: Dictionary[int, Dictionary] = {}


func _ready() -> void:
	_build_cells()
	_root.hide()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		_toggle()
	elif event.is_action_pressed("ui_cancel") and _open:
		# Consumato: altrimenti lo stesso Esc aprirebbe anche la pausa.
		get_viewport().set_input_as_handled()
		_close()


## Apre se chiuso (e nessun altro pannello ha il focus), chiude se aperto.
func _toggle() -> void:
	if _open:
		_close()
	elif not GameState.ui_focus_open():
		_open_panel()


## Apertura animata: il gioco si ferma e il pannello entra crescendo e in
## dissolvenza. Il CanvasLayer è in process_mode ALWAYS, quindi il tween
## avanza anche a gioco fermo. Si aspetta un frame perché il layout assesti
## la dimensione del pannello prima di centrarne il pivot per lo scale.
func _open_panel() -> void:
	_open = true
	_refresh()
	GameState.push_ui_focus()
	get_tree().paused = true
	_root.modulate.a = 0.0
	_root.show()
	await get_tree().process_frame
	if not _open:
		return
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = CLOSED_SCALE
	if _anim != null and _anim.is_valid():
		_anim.kill()
	_anim = create_tween().set_parallel().set_ease(Tween.EASE_OUT)
	_anim.tween_property(_root, "modulate:a", 1.0, ANIM_TIME)
	_anim.tween_property(_panel, "scale", Vector2.ONE, ANIM_TIME).set_trans(Tween.TRANS_BACK)


## Chiusura animata: il pannello rimpicciolisce e sfuma, poi si nasconde e
## il gioco riparte. Il gioco resta fermo per la breve durata dell'uscita.
func _close() -> void:
	_open = false
	if _anim != null and _anim.is_valid():
		_anim.kill()
	_anim = create_tween().set_parallel().set_ease(Tween.EASE_IN)
	_anim.tween_property(_root, "modulate:a", 0.0, ANIM_TIME)
	_anim.tween_property(_panel, "scale", CLOSED_SCALE, ANIM_TIME).set_trans(Tween.TRANS_BACK)
	_anim.chain().tween_callback(_finish_close)


## Fine dell'uscita: nasconde davvero e restituisce controllo e mouse. Non
## eseguito se un'apertura ha annullato il tween nel frattempo.
func _finish_close() -> void:
	_root.hide()
	get_tree().paused = false
	GameState.pop_ui_focus()


# --- Costruzione e aggiornamento della griglia -------------------------------

func _build_cells() -> void:
	for type: int in GameState.BuoyType.values():
		var color := Color.html(GameState.BUOY_HEX[type])
		var cell := _make_cell(ItemIcon.Kind.BUOY, color,
			GameState.BUOY_NAME[type].capitalize(), GameState.BUOY_VALUE[type])
		_buoy_grid.add_child(cell.root)
		_buoy_cells[type] = cell
	for type: int in GameState.FishType.values():
		var color := Color.html(GameState.FISH_HEX[type])
		var cell := _make_cell(ItemIcon.Kind.FISH, color,
			GameState.FISH_NAME[type].capitalize(), GameState.FISH_VALUE[type])
		_fish_grid.add_child(cell.root)
		_fish_cells[type] = cell


## Una cella: icona, nome, "×N" e valore unitario. Ritorna i nodi che vanno
## aggiornati (root per lo smorzamento, qty per la quantità).
func _make_cell(kind: int, color: Color, item_name: String, unit_value: int) -> Dictionary:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.custom_minimum_size = Vector2(110.0, 0.0)
	box.add_theme_constant_override("separation", 2)

	var icon := ItemIcon.new()
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.setup(kind, color)
	box.add_child(icon)

	var name_label := Label.new()
	name_label.text = item_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	box.add_child(name_label)

	var qty_label := Label.new()
	qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty_label.add_theme_font_size_override("font_size", 26)
	box.add_child(qty_label)

	var value_label := Label.new()
	value_label.text = "%d $" % unit_value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 18)
	value_label.modulate = Color(0.7, 0.78, 0.85)
	box.add_child(value_label)

	return {"root": box, "qty": qty_label}


func _refresh() -> void:
	# Le casse missione occupano stiva ma non hanno cella in griglia:
	# si dichiarano nel sottotitolo, così il conteggio torna.
	var crates_text := ""
	if GameState.mission_crates > 0:
		crates_text = " · [color=#%s]%d casse missione[/color]" % [
			GameState.CRATE_HEX, GameState.mission_crates,
		]
	_subtitle.text = "[center]Stiva %d/%d · vale [color=#8ee3a8]%d $[/color]%s[/center]" % [
		GameState.cargo_count(), GameState.cargo_capacity(), GameState.cargo_value(),
		crates_text,
	]
	for type: int in _buoy_cells:
		_update_cell(_buoy_cells[type], GameState.cargo.get(type, 0))
	for type: int in _fish_cells:
		_update_cell(_fish_cells[type], GameState.fish_cargo.get(type, 0))


func _update_cell(cell: Dictionary, count: int) -> void:
	var root: Control = cell["root"]
	var qty: Label = cell["qty"]
	qty.text = "×%d" % count
	root.modulate = Color.WHITE if count > 0 else EMPTY_MODULATE
