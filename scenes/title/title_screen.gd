extends CanvasLayer

## Menu principale (roadmap A2): appare all'avvio sopra la baia viva —
## niente scena separata, è la scena di gioco in pausa con la camera già
## sulla barca attraccata. Salpa toglie la pausa e si gioca; le
## impostazioni sono lo stesso pannello del menu pausa. ALWAYS perché
## deve ricevere input ad albero fermo; è l'ultimo figlio di Main, così
## consuma Esc prima del menu pausa.

@onready var _root: Control = $Root
@onready var _play_button: Button = $Root/Panel/Margin/VBox/PlayButton
@onready var _settings_button: Button = $Root/Panel/Margin/VBox/SettingsButton
@onready var _quit_button: Button = $Root/Panel/Margin/VBox/QuitButton
@onready var _settings: SettingsPanel = $Root/Panel/Margin/VBox/SettingsPanel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# In headless (test, CI) non c'è nessuno a premere Salpa: il title si
	# salta e il gioco parte subito, come prima di A2.
	if DisplayServer.get_name() == "headless":
		_root.hide()
		return
	_play_button.pressed.connect(_on_play_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_settings.save_reset_requested.connect(_on_save_reset_requested)
	_settings.hide()
	_play_button.text = "Riprendi il mare" if FileAccess.file_exists(GameState.save_path) \
		else "Salpa!"
	get_tree().paused = true
	GameState.push_ui_focus()
	_root.show()
	_play_button.grab_focus()


## Esc nel title non deve aprire la pausa: al massimo richiude le
## impostazioni.
func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _settings.visible:
		_on_settings_pressed()


func _on_play_pressed() -> void:
	get_tree().paused = false
	GameState.pop_ui_focus()
	_root.hide()


func _on_settings_pressed() -> void:
	_settings.visible = not _settings.visible
	_settings_button.text = "Chiudi impostazioni" if _settings.visible else "Impostazioni"


## Azzeramento confermato dal pannello: si riparte davvero da zero, con
## la scena ricaricata (il title riappare da solo sulla baia nuova).
func _on_save_reset_requested() -> void:
	GameState.reset()
	Radar.reset()
	get_tree().reload_current_scene()


func _on_quit_pressed() -> void:
	get_tree().quit()
