class_name ShipDefinition
extends Resource

## Parametri di una nave IA (roadmap B1): velocità, tenuta, punti scafo,
## bottino e — per chi spara — l'arma. Vivono in .tres
## (resources/ships/*.tres) come ogni valore di bilanciamento (CLAUDE.md):
## mercantili e predoni si tarano dall'Inspector senza toccare codice.

@export var display_name: String = "Nave"
@export var faction: StringName = &"mercanti"

@export_group("Navigazione")
@export var max_speed: float = 7.0
@export var turn_speed_deg: float = 35.0
@export_range(0.0, 1.0) var stability: float = 0.5

@export_group("Scafo")
@export var hp: float = 60.0
@export var collision_size: Vector3 = Vector3(2.4, 1.6, 8.0)

@export_group("Bottino")
## Casse mollate all'affondamento (il valore lo decide la fascia di mare).
@export var loot_min: int = 2
@export var loot_max: int = 3
## Merci che la nave porta in stiva (roadmap R6): id di ItemDefinition. Una
## parte delle casse mollate è merce vera da questo pool (le navi delle
## città di B4 aggiungono la merce tipica di casa via GameState.FACTION_GOODS).
## Vuoto = solo bottino generico.
@export var goods_pool: Array[StringName] = []

@export_group("Predone")
## Arma di bordo (null = disarmata, come i mercantili).
@export var weapon: WeaponDefinition
## Raggio entro cui punta il giocatore (0 = pacifica).
@export var aggro_radius: float = 0.0
## Danno dello speronamento a contatto (0 = non sperona).
@export var ram_damage: float = 0.0

@export_group("Mercantile")
## Moltiplicatore di velocità e durata della fuga quando viene attaccato.
@export var flee_speed_mult: float = 1.35
@export var flee_time: float = 14.0

@export_group("Colori")
@export var hull_color: Color = Color(0.8, 0.78, 0.72)
@export var accent_color: Color = Color(0.25, 0.35, 0.5)
