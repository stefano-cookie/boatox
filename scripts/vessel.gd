class_name Vessel
extends CharacterBody3D

## Base comune di tutte le imbarcazioni (predisposizione B0, roadmap
## beta): la barca del giocatore (Boat) e le navi IA (AIRacer oggi,
## mercantili e predoni in B1) condividono fazione, riferimento al mare,
## velocità/stabilità e la lettura del mare agitato — le stesse soglie
## per tutti: gli upgrade si confrontano ad armi pari.
## Nessuna guida qui: ogni figlio muove come preferisce (fisica per il
## giocatore, cinematica per le IA).

## Fazione proprietaria (per ora sempre player o neutrale): la leggeranno
## armi e IA via Diplomacy per decidere chi è ostile a chi.
@export var faction: StringName = &"player"
@export var sea: Sea

@export_group("Mare agitato")
## Agitazione (zona × meteo) oltre cui il mare inizia a destabilizzare.
@export var chaos_threshold: float = 1.6
## Quanta agitazione oltre la soglia serve per il caos pieno.
@export var chaos_full_range: float = 2.5
## Quota di velocità massima persa a caos pieno: il mare grosso frena.
@export_range(0.0, 1.0) var rough_slow_max: float = 0.55

## Impostate dai figli (BoatDefinition per il giocatore, parametri di
## spawn per le IA).
var max_speed: float = 12.0
var stability: float = 0.2

var _speed: float = 0.0


func current_speed() -> float:
	return _speed


## Caos 0..1 nel punto della nave: agitazione oltre soglia, mitigata
## dalla stabilità. I figli lo traducono in sbandata, spinta e freno.
func chaos01() -> float:
	if sea == null:
		return 0.0
	return clampf((sea.agitation(global_position) - chaos_threshold) / chaos_full_range, 0.0, 1.0) \
		* (1.0 - stability)


## Punto d'ingresso uniforme dei colpi (Weapon chiama questo senza sapere
## chi ha davanti). La barca del giocatore lo gira a GameState (scafo
## per-barca con upgrade); le navi IA di B1 lo terranno in un Damageable.
func take_damage(_amount: float) -> void:
	pass
