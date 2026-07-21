extends CanvasLayer

## Menu di pausa (Esc): riprendi, ricomincia, schermo intero, esci.
## Le impostazioni complete arrivano con M4; qui c'è l'essenziale per il
## playtest. Il nodo ha process_mode ALWAYS così riceve input anche a
## albero fermo; il porto consuma Esc quando il suo menu è aperto, quindi
## qui arriva solo quando serve davvero.

@onready var _root: Control = $Root
@onready var _resume_button: Button = $Root/Panel/Margin/VBox/ResumeButton
@onready var _restart_button: Button = $Root/Panel/Margin/VBox/RestartButton
@onready var _fullscreen_button: Button = $Root/Panel/Margin/VBox/FullscreenButton
@onready var _quit_button: Button = $Root/Panel/Margin/VBox/QuitButton


func _ready() -> void:
	_root.hide()
	_resume_button.pressed.connect(_resume)
	_restart_button.pressed.connect(_on_restart_pressed)
	_fullscreen_button.pressed.connect(_on_fullscreen_pressed)
	_quit_button.pressed.connect(get_tree().quit)


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
	_refresh_fullscreen_label()
	_root.show()
	_resume_button.grab_focus()


func _resume() -> void:
	get_tree().paused = false
	_root.hide()


func _on_restart_pressed() -> void:
	_resume()
	GameState.reset()
	get_tree().reload_current_scene()


func _on_fullscreen_pressed() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_refresh_fullscreen_label()


func _refresh_fullscreen_label() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		_fullscreen_button.text = "Finestra"
	else:
		_fullscreen_button.text = "Schermo intero"
