class_name WeaponDefinition
extends Resource

## Parametri di un'arma (predisposizione B0): raggio, danno e cadenza
## vivono in .tres come ogni valore di bilanciamento (CLAUDE.md). In B1
## diventa una famiglia di upgrade come motore e scafo.

@export var display_name: String = "Cannone"
@export var damage: float = 10.0
## Gittata in metri.
@export var fire_range: float = 40.0
## Secondi tra un colpo e il successivo.
@export var fire_interval: float = 2.0
## Velocità del proiettile ad arco (B1); per ora il colpo è istantaneo.
@export var projectile_speed: float = 30.0
