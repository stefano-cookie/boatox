extends CanvasLayer

## Schermata di fine alpha (roadmap A2): appare una volta sola, quando si
## compra il primo Cabinato — il traguardo dell'alpha. Statistiche di
## partita, ringraziamento, e si continua a giocare liberamente. ALWAYS
## perché mette in pausa l'albero mentre è aperta (come il menu pausa).

@onready var _root: Control = $Root
@onready var _stats: RichTextLabel = $Root/Panel/Margin/VBox/Stats
@onready var _continue_button: Button = $Root/Panel/Margin/VBox/ContinueButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.hide()
	GameState.alpha_completed.connect(_open)
	_continue_button.pressed.connect(_close)


## Esc mentre è aperta vale come "Continua": senza questo, lo prenderebbe
## il menu pausa (ALWAYS anche lui) togliendo la pausa sotto la schermata.
func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	_close()


func _open() -> void:
	_stats.text = "\n".join([
		"Tempo di gioco: [b]%s[/b]" % _format_time(GameState.play_seconds),
		"Denaro guadagnato in totale: [color=#8ee3a8]%d $[/color]" % GameState.total_earned,
		"Pesci catturati: [b]%d[/b]" % GameState.fish_caught_total,
		"Regate vinte: [b]%d[/b]" % GameState.race_wins,
	])
	get_tree().paused = true
	GameState.push_ui_focus()
	_root.show()
	_continue_button.grab_focus()


func _close() -> void:
	get_tree().paused = false
	GameState.pop_ui_focus()
	_root.hide()


func _format_time(seconds: float) -> String:
	var total := int(seconds)
	if total >= 3600:
		return "%d h %02d min" % [total / 3600, (total % 3600) / 60]
	return "%d min %02d s" % [total / 60, total % 60]
