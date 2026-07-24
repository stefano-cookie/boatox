extends CanvasLayer

## Pannello inventario della stiva (roadmap R4 § Inventario), aperto col
## tasto I. La stiva è un inventario unico (GameState.inventory): il pannello
## si costruisce dal catalogo ITEM_DEFS, una sezione per categoria (boe, pesci,
## bottino, casse missione e — da R5 — merci). Per ogni item un'icona, il nome,
## la quantità e il valore unitario, più stiva usata/capacità e valore totale.
## Aggiungere un item nuovo = un .tres: appare qui senza toccare questo codice.
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
## Colonne della griglia di ogni sezione.
const GRID_COLUMNS: int = 4
## Titoli delle sezioni per categoria (ItemDefinition.Category).
const CATEGORY_TITLE: Dictionary[int, String] = {
	ItemDefinition.Category.BUOY: "Boe",
	ItemDefinition.Category.FISH: "Pesci",
	ItemDefinition.Category.LOOT: "Bottino",
	ItemDefinition.Category.GOODS: "Merci",
	ItemDefinition.Category.TREASURE: "Tesori",
	ItemDefinition.Category.MISSION: "Missione",
}

## Durata dell'animazione di apertura/chiusura (feedback playtest: far
## capire che si sta aprendo la stiva). Breve: è feedback, non un'attesa.
const ANIM_TIME: float = 0.16
const CLOSED_SCALE := Vector2(0.9, 0.9)

@onready var _root: Control = $Overlay
@onready var _panel: PanelContainer = $Overlay/Center/Panel
@onready var _subtitle: RichTextLabel = $Overlay/Center/Panel/Margin/VBox/Subtitle
@onready var _sections: VBoxContainer = $Overlay/Center/Panel/Margin/VBox/Sections

var _open: bool = false
## Tween corrente di apertura/chiusura: si annulla prima di ripartire, così
## premere I ripetutamente non lascia il pannello a metà.
var _anim: Tween
## Celle costruite una volta e aggiornate a ogni apertura. id item -> nodi.
var _cells: Dictionary[StringName, Dictionary] = {}


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

## Costruisce una sezione per categoria dal catalogo (roadmap R4): l'ordine
## degli item è quello di ITEM_DEFS, le categorie compaiono nell'ordine in cui
## il catalogo le incontra. Aggiungere un .tres di categoria nuova crea la sua
## sezione da solo.
func _build_cells() -> void:
	var current_category: int = -1
	var grid: GridContainer = null
	for def: ItemDefinition in GameState.ITEM_DEFS:
		if def.category != current_category:
			current_category = def.category
			grid = _add_section(def.category)
		var cell := _make_cell(def.shape, def.color, def.display_name.capitalize(),
			def.base_value, def.sellable)
		grid.add_child(cell.root)
		_cells[def.id] = cell


## Titolo + griglia di una sezione, aggiunti al contenitore. Ritorna la griglia
## a cui appendere le celle.
func _add_section(category: int) -> GridContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	var header := Label.new()
	header.text = CATEGORY_TITLE.get(category, "Varie")
	header.add_theme_color_override("font_color", Color(0.7, 0.82, 0.95))
	header.add_theme_font_size_override("font_size", 22)
	section.add_child(header)
	var grid := GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	section.add_child(grid)
	_sections.add_child(section)
	return grid


## Una cella: icona, nome, "×N" e valore unitario (o "missione" se non si
## vende). Ritorna i nodi da aggiornare (root per lo smorzamento, qty).
func _make_cell(shape: int, color: Color, item_name: String, unit_value: int,
		sellable: bool) -> Dictionary:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.custom_minimum_size = Vector2(110.0, 0.0)
	box.add_theme_constant_override("separation", 2)

	var icon := ItemIcon.new()
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.setup(shape, color)
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
	value_label.text = "%d $" % unit_value if sellable else "missione"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 18)
	value_label.modulate = Color(0.7, 0.78, 0.85)
	box.add_child(value_label)

	return {"root": box, "qty": qty_label}


func _refresh() -> void:
	_subtitle.text = "[center]Stiva %d/%d · vale [color=#8ee3a8]%d $[/color][/center]" % [
		GameState.cargo_count(), GameState.cargo_capacity(), GameState.cargo_value(),
	]
	for id: StringName in _cells:
		_update_cell(_cells[id], GameState.item_count(id))


func _update_cell(cell: Dictionary, count: int) -> void:
	var root: Control = cell["root"]
	var qty: Label = cell["qty"]
	qty.text = "×%d" % count
	root.modulate = Color.WHITE if count > 0 else EMPTY_MODULATE
