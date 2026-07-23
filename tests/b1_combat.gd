extends Node

## Smoke test di B1 (il cannone): acquisto e livelli del cannone,
## bottino in stiva (capienza, valore, vendita), round-trip di salvataggio,
## balistica del proiettile (atterra dove si mira) e ciclo di danno di una
## nave (Damageable → affondamento → casse di bottino in acqua).
## Stampa un verdetto per ogni controllo.
## Uso: Godot --path . --headless res://tests/b1_combat.tscn

const MERCHANT_SCENE: PackedScene = preload("res://scenes/ships/merchant_ship.tscn")


func _ready() -> void:
	# File di salvataggio separato: i test non toccano quello vero.
	GameState.save_path = "user://save_test.json"
	GameState.reset()
	_run()


func _run() -> void:
	GameState.money = 10000

	# --- Cannone: acquisto, livelli, tetto ---
	var ok := GameState.buy_cannon()
	print("CANNONE: comprato=%s (atteso true), livello=%d (atteso 1), denaro=%d (atteso 9100), danno=%d (atteso 12)" % [
		ok, GameState.cannon_level, GameState.money, roundi(GameState.cannon_def().damage)])
	GameState.buy_cannon()
	GameState.buy_cannon()
	var over := GameState.buy_cannon()
	print("CANNONE MAX: livello=%d (atteso 3), oltre=%s (atteso false), costo=%d (atteso -1), denaro=%d (atteso 4100)" % [
		GameState.cannon_level, over, GameState.cannon_cost(), GameState.money])

	# --- Bottino: in stiva, valore per fascia, tetto di capienza ---
	ok = GameState.collect_loot(2)
	print("BOTTINO: raccolto=%s (atteso true), stiva=%d (atteso 1), valore=%d (atteso 150)" % [
		ok, GameState.cargo_count(), GameState.cargo_value()])
	while GameState.collect_loot(0):
		pass
	print("STIVA PIENA: stiva=%d/%d (attesa piena), rifiuto=%s (atteso false)" % [
		GameState.cargo_count(), GameState.cargo_capacity(), GameState.collect_loot(1)])

	# --- Vendita: il bottino diventa denaro e la stiva si svuota ---
	var value := GameState.cargo_value()
	var money_before := GameState.money
	var earned := GameState.sell_cargo()
	print("VENDITA: incasso=%d (atteso %d), stiva=%d (attesa 0), denaro=%d (atteso %d)" % [
		earned, value, GameState.cargo_count(), GameState.money, money_before + value])

	# --- Round-trip di salvataggio: cannone e bottino sopravvivono ---
	GameState.collect_loot(1)
	GameState.collect_loot(1)
	GameState.save_game()
	GameState.cannon_level = 0
	GameState.inventory.clear()
	GameState.load_game()
	print("SALVATAGGIO: cannone=%d (atteso 3), bottino fascia 1=%d (atteso 2)" % [
		GameState.cannon_level, GameState.item_count(GameState.LOOT_ITEM[1])])

	# --- Balistica: la palla ricade sul punto mirato (integrazione a 60 Hz) ---
	var from := Vector3(0.0, 1.2, 0.0)
	var to := Vector3(30.0, 0.0, 40.0)
	var speed := 30.0
	var velocity := CannonBall.launch_velocity(from, to, speed)
	var pos := from
	var dt := 1.0 / 60.0
	for i in 600:
		velocity.y -= CannonBall.GRAVITY * dt
		pos += velocity * dt
		if velocity.y < 0.0 and pos.y <= to.y:
			break
	print("BALISTICA: atterra a %.1f m dal bersaglio (atteso < 2)" % pos.distance_to(to))

	# --- Nave: danno leggibile, affondamento, bottino in acqua ---
	var ship := MERCHANT_SCENE.instantiate() as MerchantShip
	add_child(ship)
	ship.global_position = Vector3(0.0, 0.0, 300.0)
	ship.take_damage(20.0)
	print("NAVE COLPITA: scafo=%.2f (atteso 0.67), affonda=%s (atteso false)" % [
		ship.hp_ratio(), ship.is_sinking()])
	ship.take_damage(1000.0)
	print("NAVE A FONDO: affonda=%s (atteso true)" % ship.is_sinking())
	await get_tree().create_timer(Ship.SINK_TIME + 0.6).timeout
	var crates := get_tree().get_nodes_in_group(&"loot_crates").size()
	print("BOTTINO IN ACQUA: casse=%d (attese 2-3), nave rimossa=%s (atteso true)" % [
		crates, not is_instance_valid(ship)])

	GameState.reset()
	print("RESET: cannone=%d (atteso 0), bottino=%d (atteso 0)" % [
		GameState.cannon_level, GameState.inventory.size()])
	get_tree().quit()
