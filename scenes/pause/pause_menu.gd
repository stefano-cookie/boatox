extends CanvasLayer

## Menu di pausa (Esc): impostazioni complete (pannello condiviso col
## title, roadmap A2), riprendi, esci. Il nodo ha process_mode ALWAYS
## così riceve input anche a albero fermo; il porto e il title consumano
## Esc quando i loro pannelli sono aperti, quindi qui arriva solo quando
## serve davvero.

@onready var _root: Control = $Root
@onready var _settings: SettingsPanel = $Root/Panel/Margin/VBox/SettingsPanel
@onready var _resume_button: Button = $Root/Panel/Margin/VBox/ResumeButton
@onready var _quit_button: Button = $Root/Panel/Margin/VBox/QuitButton


func _ready() -> void:
	_root.hide()
	_resume_button.pressed.connect(_resume)
	_quit_button.pressed.connect(_on_quit_pressed)
	_settings.save_reset_requested.connect(_on_save_reset_requested)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if get_tree().paused:
		_resume()
	else:
		_open()


func _open() -> void:
	get_tree().paused = true
	GameState.push_ui_focus()
	_root.show()
	_resume_button.grab_focus()


func _resume() -> void:
	get_tree().paused = false
	GameState.pop_ui_focus()
	_root.hide()


## Azzeramento confermato dal pannello impostazioni: si riparte da zero
## (GameState.reset cancella anche il salvataggio) ricaricando la scena.
func _on_save_reset_requested() -> void:
	_resume()
	GameState.reset()
	Radar.reset()
	get_tree().reload_current_scene()


func _on_quit_pressed() -> void:
	GameState.save_game()
	get_tree().quit()
