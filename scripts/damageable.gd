class_name Damageable
extends Node

## Componente punti-vita condiviso (predisposizione B0): si monta come
## figlio di qualsiasi cosa debba incassare colpi — navi IA, torri
## d'avvistamento, batterie costiere (B1/B3). La barca del giocatore NON
## lo usa: il suo scafo vive in GameState (per-barca, con upgrade).

signal damaged(amount: float, hp: float)
signal destroyed

@export var max_hp: float = 100.0

var hp: float


func _ready() -> void:
	hp = max_hp


func take_damage(amount: float) -> void:
	if hp <= 0.0:
		return
	hp = maxf(hp - amount, 0.0)
	damaged.emit(amount, hp)
	if hp <= 0.0:
		destroyed.emit()


func repair(amount: float) -> void:
	hp = minf(hp + amount, max_hp)


func is_destroyed() -> bool:
	return hp <= 0.0
