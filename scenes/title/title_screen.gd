extends CanvasLayer

## Menu principale (roadmap A2, esteso coi "mondi"): appare all'avvio
## sopra la baia viva — niente scena separata, è la scena di gioco in
## pausa con la camera già sulla barca attraccata. Come i mondi di
## Minecraft: Continua riprende il mondo più recente, Nuova partita ne
## crea uno col suo nome, I mondi elenca i salvataggi (gioca/elimina).
## Ogni mondo è un file in GameState.WORLDS_DIR; cambiare mondo ricarica
## la scena con GameState.autostart_once alzato, così al giro dopo il
## title salta il menu e si salpa dritti. ALWAYS perché deve ricevere
## input ad albero fermo; è l'ultimo figlio di Main, così consuma Esc
## prima del menu pausa.

## Secondi entro cui ripremere Elimina per confermare (come l'azzeramento
## nelle impostazioni).
const DELETE_CONFIRM_SECONDS: float = 3.0

@onready var _root: Control = $Root
@onready var _menu_box: VBoxContainer = $Root/Panel/Margin/VBox/MenuBox
@onready var _continue_button: Button = $Root/Panel/Margin/VBox/MenuBox/ContinueButton
@onready var _new_button: Button = $Root/Panel/Margin/VBox/MenuBox/NewButton
@onready var _worlds_button: Button = $Root/Panel/Margin/VBox/MenuBox/WorldsButton
@onready var _settings_button: Button = $Root/Panel/Margin/VBox/MenuBox/SettingsButton
@onready var _quit_button: Button = $Root/Panel/Margin/VBox/MenuBox/QuitButton
@onready var _settings: SettingsPanel = $Root/Panel/Margin/VBox/MenuBox/SettingsPanel
@onready var _new_box: VBoxContainer = $Root/Panel/Margin/VBox/NewBox
@onready var _name_edit: LineEdit = $Root/Panel/Margin/VBox/NewBox/NameEdit
@onready var _create_button: Button = $Root/Panel/Margin/VBox/NewBox/CreateButton
@onready var _new_back: Button = $Root/Panel/Margin/VBox/NewBox/NewBackButton
@onready var _worlds_box: VBoxContainer = $Root/Panel/Margin/VBox/WorldsBox
@onready var _worlds_list: VBoxContainer = $Root/Panel/Margin/VBox/WorldsBox/Scroll/WorldsList
@onready var _worlds_back: Button = $Root/Panel/Margin/VBox/WorldsBox/WorldsBackButton

## Bottone Elimina in attesa di conferma (uno alla volta) e il suo timer.
var _delete_pending: Button = null
var _delete_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# In headless (test, CI) non c'è nessuno a scegliere: il title si
	# salta e il gioco parte subito, come prima di A2.
	if DisplayServer.get_name() == "headless":
		_root.hide()
		return
	# Rientro da un cambio/creazione mondo, o playtest --maxed: si salpa
	# dritti, il menu l'abbiamo già visto.
	if GameState.autostart_once or OS.get_cmdline_user_args().has("--maxed"):
		GameState.autostart_once = false
		get_tree().paused = false
		_root.hide()
		return
	_continue_button.pressed.connect(_on_continue_pressed)
	_new_button.pressed.connect(_open_new_box)
	_worlds_button.pressed.connect(_open_worlds_box)
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_settings.save_reset_requested.connect(_on_save_reset_requested)
	_create_button.pressed.connect(_on_create_pressed)
	_name_edit.text_submitted.connect(func(_text: String) -> void: _on_create_pressed())
	_new_back.pressed.connect(_show_menu)
	_worlds_back.pressed.connect(_show_menu)
	_settings.hide()
	get_tree().paused = true
	GameState.push_ui_focus()
	_root.show()
	_show_menu()


func _process(delta: float) -> void:
	# La conferma di Elimina scade da sola, come nelle impostazioni.
	if _delete_pending == null:
		return
	_delete_timer -= delta
	if _delete_timer <= 0.0:
		if is_instance_valid(_delete_pending):
			_delete_pending.text = "Elimina"
		_delete_pending = null


## Esc nel title torna indietro di un livello: chiude impostazioni o
## sotto-pannelli, mai la pausa di gioco.
func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _settings.visible:
		_on_settings_pressed()
	elif _new_box.visible or _worlds_box.visible:
		_show_menu()


# --- Navigazione tra i pannelli ----------------------------------------------

func _show_menu() -> void:
	_new_box.hide()
	_worlds_box.hide()
	_menu_box.show()
	var recent := GameState.most_recent_world_path()
	var has_worlds := recent != ""
	_continue_button.visible = has_worlds
	_worlds_button.visible = has_worlds
	if has_worlds:
		_continue_button.text = "Continua — %s" % GameState.world_name
		_continue_button.grab_focus()
	else:
		_new_button.grab_focus()


func _open_new_box() -> void:
	_menu_box.hide()
	_new_box.show()
	_name_edit.text = "Mondo %d" % (GameState.list_worlds().size() + 1)
	_name_edit.grab_focus()
	_name_edit.select_all()


func _open_worlds_box() -> void:
	_menu_box.hide()
	_worlds_box.show()
	_build_world_rows()
	_worlds_back.grab_focus()


# --- Azioni ------------------------------------------------------------------

## Il mondo più recente è già caricato (fondale del title): si ricarica
## la scena per ripartire puliti dal molo, saltando il menu al rientro.
func _on_continue_pressed() -> void:
	GameState.pop_ui_focus()
	_start_into_current_world()


func _on_create_pressed() -> void:
	GameState.create_world(_name_edit.text)
	_start_into_current_world()


func _on_world_play(path: String) -> void:
	if path == GameState.save_path:
		GameState.pop_ui_focus()
	else:
		GameState.switch_world(path)
	_start_into_current_world()


func _on_world_delete(path: String, button: Button) -> void:
	if _delete_pending != button:
		if _delete_pending != null and is_instance_valid(_delete_pending):
			_delete_pending.text = "Elimina"
		_delete_pending = button
		_delete_timer = DELETE_CONFIRM_SECONDS
		button.text = "Sicuro?"
		return
	_delete_pending = null
	GameState.delete_world(path)
	_build_world_rows()
	_worlds_back.grab_focus()


func _start_into_current_world() -> void:
	GameState.autostart_once = true
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_settings_pressed() -> void:
	_settings.visible = not _settings.visible
	_settings_button.text = "Chiudi impostazioni" if _settings.visible else "Impostazioni"


## Azzeramento confermato dal pannello: il mondo corrente riparte da
## zero (stesso nome, stesso file) e la scena si ricarica sul title.
func _on_save_reset_requested() -> void:
	var world_label := GameState.world_name
	GameState.reset()
	GameState.world_name = world_label
	GameState.save_game()
	Radar.reset()
	get_tree().reload_current_scene()


func _on_quit_pressed() -> void:
	get_tree().quit()


# --- Righe dei mondi ---------------------------------------------------------

func _build_world_rows() -> void:
	_delete_pending = null
	for child in _worlds_list.get_children():
		child.queue_free()
	var worlds := GameState.list_worlds()
	if worlds.is_empty():
		var empty := Label.new()
		empty.text = "Nessun mondo: creane uno nuovo!"
		empty.add_theme_font_size_override("font_size", 20)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_worlds_list.add_child(empty)
		return
	for world in worlds:
		_worlds_list.add_child(_world_row(world))


func _world_row(world: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var path := str(world["path"])
	var label := Label.new()
	var name_line := str(world["name"])
	if path == GameState.save_path:
		name_line += "  ●"
	var def := GameState.boat_def(world["boat"])
	label.text = "%s\n%s · %d $ · %s · %s" % [
		name_line,
		def.display_name if def != null else "Barchetta",
		int(world["money"]),
		_format_play_time(float(world["play_seconds"])),
		_format_last_played(int(world["last_played"])),
	]
	label.add_theme_font_size_override("font_size", 18)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var play := Button.new()
	play.text = "Salpa"
	play.add_theme_font_size_override("font_size", 20)
	play.custom_minimum_size = Vector2(96, 0)
	play.pressed.connect(_on_world_play.bind(path))
	row.add_child(play)
	var remove := Button.new()
	remove.text = "Elimina"
	remove.add_theme_font_size_override("font_size", 20)
	remove.custom_minimum_size = Vector2(110, 0)
	remove.pressed.connect(func() -> void: _on_world_delete(path, remove))
	row.add_child(remove)
	return row


func _format_play_time(seconds: float) -> String:
	var minutes := int(seconds / 60.0)
	if minutes < 60:
		return "%d min" % minutes
	return "%dh %02dm" % [minutes / 60, minutes % 60]


func _format_last_played(unix: int) -> String:
	if unix <= 0:
		return "mai giocato"
	var date := Time.get_datetime_dict_from_unix_time(unix)
	return "%02d/%02d/%d" % [date["day"], date["month"], date["year"]]
