class_name Weapon
extends Node3D

## Arma generica: la forma condivisa di cannoni di bordo, predoni e (in
## B3) torri e batterie costiere. Legge raggio, danno e cadenza dalla
## WeaponDefinition e gestisce solo il cooldown. Due modi d'uso: fire_at
## per il colpo istantaneo (batterie future), consume_cooldown per chi
## spara proiettili ad arco veri (CannonBall, roadmap B1).

signal fired(target: Node3D)

@export var definition: WeaponDefinition

var _cooldown: float = 0.0


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)


func can_fire() -> bool:
	return definition != null and _cooldown <= 0.0


func in_range(point: Vector3) -> bool:
	return definition != null \
		and global_position.distance_to(point) <= definition.fire_range


## Consuma il cooldown se l'arma è pronta: chi spara proiettili veri lo
## chiama al posto di fire_at e si occupa lui del colpo.
func consume_cooldown() -> bool:
	if not can_fire():
		return false
	_cooldown = definition.fire_interval
	return true


## Frazione 0..1 del cooldown ancora da scontare (per l'HUD del mirino).
func cooldown_fraction() -> float:
	if definition == null or definition.fire_interval <= 0.0:
		return 0.0
	return _cooldown / definition.fire_interval


## Spara al bersaglio se cadenza e gittata lo permettono. Il bersaglio
## deve esporre take_damage (un Vessel o un Damageable): l'arma non sa
## chi ha davanti.
func fire_at(target: Node3D) -> bool:
	if not can_fire() or not in_range(target.global_position):
		return false
	_cooldown = definition.fire_interval
	if target.has_method("take_damage"):
		target.take_damage(definition.damage)
	fired.emit(target)
	return true
