extends Node

## Smoke test della chiusura alpha (roadmap A2): customizzazione estetica
## (acquisto vernice/accessorio, anteprima, ritinta del modello),
## statistiche di partita, segnale di fine alpha all'acquisto del Cabinato
## e round-trip di salvataggio dei nuovi campi. Stampa un verdetto per
## ogni controllo.
## Uso: Godot --path . --headless res://tests/a2_closure.tscn

var _alpha_fired: bool = false


func _ready() -> void:
	# File di salvataggio separato: i test non toccano quello vero.
	GameState.save_path = "user://save_test.json"
	GameState.reset()
	GameState.alpha_completed.connect(func() -> void: _alpha_fired = true)
	_run()


func _run() -> void:
	GameState.money = 5000

	# --- Vernice: acquisto + applicazione in un gesto ---
	var ok := GameState.buy_paint(&"corallo")
	print("VERNICE: comprata=%s (atteso true), applicata=%s (attesa corallo), denaro=%d (atteso 4550)" % [
		ok, GameState.applied_paint(), GameState.money])

	# --- Anteprima: vince sulla vernice applicata, e si azzera ---
	GameState.set_paint_preview(&"notte")
	var preview_id: StringName = GameState.effective_paint()["id"]
	GameState.clear_paint_preview()
	var after_id: StringName = GameState.effective_paint()["id"]
	print("ANTEPRIMA: durante=%s (attesa notte), dopo=%s (attesa corallo)" % [preview_id, after_id])

	# --- Accessorio ---
	ok = GameState.buy_accessory(&"lights")
	print("ACCESSORIO: comprato=%s (atteso true), a bordo=%s (atteso true), denaro=%d (atteso 4000)" % [
		ok, GameState.owns_accessory(&"lights"), GameState.money])

	# --- Il modello si ritinge e monta gli accessori ---
	var def := GameState.current_def()
	var visual := def.visual_scene.instantiate() as Node3D
	add_child(visual)
	BoatCustomization.apply(visual, def)
	var hull := visual.get_node("Hull") as MeshInstance3D
	var hull_color := (hull.material_override as StandardMaterial3D).albedo_color
	var expected: Color = GameState.paint_def(&"corallo")["hull"]
	print("MODELLO: tinta scafo=%s (attesa %s), luci montate=%s (atteso true)" % [
		hull_color, expected, visual.get_node_or_null("AccessoryLightL0") != null])

	# --- Statistiche ---
	GameState.collect_fish(GameState.FishType.TUNA)
	GameState.sell_cargo()
	print("STATISTICHE: pesci=%d (atteso 1), guadagno totale=%d (atteso 250)" % [
		GameState.fish_caught_total, GameState.total_earned])

	# --- Fine alpha: primo acquisto del Cabinato ---
	GameState.race_wins = 1
	GameState.money = 2000
	ok = GameState.buy_boat(&"cruiser")
	print("FINE ALPHA: acquisto=%s (atteso true), segnale=%s (atteso true), mostrata=%s (atteso true)" % [
		ok, _alpha_fired, GameState.alpha_end_shown])

	# --- Round-trip di salvataggio dei campi A2 ---
	GameState.save_game()
	GameState.paint_applied.clear()
	GameState.accessories_owned.clear()
	GameState.fish_caught_total = 0
	GameState.total_earned = 0
	GameState.alpha_end_shown = false
	GameState.load_game()
	print("SALVATAGGIO: vernice dinghy=%s (attesa corallo), luci dinghy=%s (atteso true), pesci=%d (atteso 1), guadagno=%d (atteso 250), fine alpha vista=%s (atteso true)" % [
		GameState.applied_paint(&"dinghy"), GameState.owns_accessory(&"lights", &"dinghy"),
		GameState.fish_caught_total, GameState.total_earned, GameState.alpha_end_shown])

	GameState.reset()
	get_tree().quit()
