class_name WeaponDefinition
extends Resource

## Parametri di un'arma: raggio, danno e cadenza vivono in .tres come ogni
## valore di bilanciamento (CLAUDE.md). Da B1 è la famiglia di upgrade del
## cannone di bordo (resources/weapons/cannone_*.tres) e l'arma dei
## predoni; in B3 la useranno torri e batterie costiere.

@export var display_name: String = "Cannone"
@export var damage: float = 10.0
## Gittata in metri.
@export var fire_range: float = 40.0
## Secondi tra un colpo e il successivo.
@export var fire_interval: float = 2.0
## Velocità media del proiettile ad arco (m/s): decide il tempo di volo
## verso il punto mirato — più lento = arco più alto e anticipo maggiore.
@export var projectile_speed: float = 30.0
## Prezzo del livello nel listino del cantiere (0 = non in vendita).
@export var price: int = 0
