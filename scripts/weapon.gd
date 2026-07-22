class_name Weapon
extends Node3D

## Arma generica (predisposizione B0): la forma condivisa che useranno
## cannoni di bordo, torri e batterie costiere (B1/B3). Legge raggio,
## danno e cadenza dalla WeaponDefinition e gestisce solo il cooldown;
## per ora il colpo è istantaneo — il proiettile ad arco e la mira libera
## arrivano in B1.

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
