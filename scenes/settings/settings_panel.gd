class_name SettingsPanel
extends VBoxContainer

## Pannello impostazioni completo (roadmap A2), riusato da menu pausa e
## title: volumi master/musica/effetti, sensibilità mouse, schermo intero
## e azzeramento del salvataggio con conferma. Applica e salva tutto via
## l'Audio autoload (unico proprietario di user://settings.cfg); chi lo
## ospita decide solo cosa fare all'azzeramento (segnale).

## Emesso alla seconda pressione di "Azzera salvataggio": la conferma è
## già avvenuta, chi ospita esegue il reset vero e proprio.
signal save_reset_requested

## Secondi entro cui ripremere per confermare l'azzeramento.
const RESET_CONFIRM_TIME := 3.0

var _reset_armed: bool = false
var _reset_timer: float = 0.0

@onready var _master_slider: HSlider = $MasterRow/MasterSlider
@onready var _music_slider: HSlider = $MusicRow/MusicSlider
@onready var _sfx_slider: HSlider = $SfxRow/SfxSlider
@onready var _sensitivity_slider: HSlider = $SensitivityRow/SensitivitySlider
@onready var _fullscreen_button: Button = $FullscreenButton
@onready var _reset_button: Button = $ResetButton


func _ready() -> void:
	_master_slider.value = Audio.master_volume
	_music_slider.value = Audio.music_volume
	_sfx_slider.value = Audio.sfx_volume
	_sensitivity_slider.min_value = Audio.SENSITIVITY_MIN
	_sensitivity_slider.max_value = Audio.SENSITIVITY_MAX
	_sensitivity_slider.value = Audio.mouse_sensitivity_scale
	_master_slider.value_changed.connect(func(v: float) -> void: Audio.set_master_volume(v))
	_music_slider.value_changed.connect(func(v: float) -> void: Audio.set_music_volume(v))
	_sfx_slider.value_changed.connect(func(v: float) -> void: Audio.set_sfx_volume(v))
	_sensitivity_slider.value_changed.connect(
		func(v: float) -> void: Audio.set_mouse_sensitivity_scale(v))
	_fullscreen_button.pressed.connect(_on_fullscreen_pressed)
	_reset_button.pressed.connect(_on_reset_pressed)
	visibility_changed.connect(_disarm_reset)
	_refresh_fullscreen_label()
	_disarm_reset()


func _process(delta: float) -> void:
	# La conferma d'azzeramento scade da sola: niente bottone armato
	# dimenticato che cancella tutto a un click distratto.
	if not _reset_armed:
		return
	_reset_timer -= delta
	if _reset_timer <= 0.0:
		_disarm_reset()


func _on_fullscreen_pressed() -> void:
	Audio.set_fullscreen(not Audio.fullscreen)
	_refresh_fullscreen_label()


func _refresh_fullscreen_label() -> void:
	_fullscreen_button.text = "Finestra" if Audio.fullscreen else "Schermo intero"


## Prima pressione: arma la conferma. Seconda entro RESET_CONFIRM_TIME:
## emette il segnale — l'azzeramento lo esegue chi ospita il pannello.
func _on_reset_pressed() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_timer = RESET_CONFIRM_TIME
		_reset_button.text = "Sicuro? Premi per confermare"
		return
	_disarm_reset()
	save_reset_requested.emit()


func _disarm_reset() -> void:
	_reset_armed = false
	_reset_timer = 0.0
	_reset_button.text = "Azzera salvataggio"
