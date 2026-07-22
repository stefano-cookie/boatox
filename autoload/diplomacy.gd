extends Node

## Diplomazia embrionale (predisposizione B0): mappa fazione → relazione
## col giocatore. La relazione È la reputazione per-fazione di GameState
## (primo caso: il porto di Bova, A1) — qui vive solo la lettura a soglie
## che in B4 deciderà accordi, guerre e chi spara a chi. Le rivalità tra
## città sono raccontate, non simulate: la relazione esiste solo verso il
## giocatore.

enum Stance { WAR, HOSTILE, NEUTRAL, ALLIED }

const FACTION_PLAYER: StringName = &"player"

## Soglie leggibili sulla scala -100..+100 (da tarare in B4).
const WAR_BELOW: int = -75
const HOSTILE_BELOW: int = -25
const ALLIED_FROM: int = 60


## Relazione -100..+100 della fazione verso il giocatore.
func relation(faction: StringName) -> int:
	return GameState.reputation_value(faction)


func change_relation(faction: StringName, delta: int) -> void:
	GameState.add_reputation(delta, faction)


func stance(faction: StringName) -> Stance:
	if faction == FACTION_PLAYER:
		return Stance.ALLIED
	var value := relation(faction)
	if value < WAR_BELOW:
		return Stance.WAR
	if value < HOSTILE_BELOW:
		return Stance.HOSTILE
	if value >= ALLIED_FROM:
		return Stance.ALLIED
	return Stance.NEUTRAL


## Vero se la fazione attacca a vista le cose del giocatore (B1/B3).
func is_hostile(faction: StringName) -> bool:
	var s := stance(faction)
	return s == Stance.WAR or s == Stance.HOSTILE
