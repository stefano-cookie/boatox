class_name BoatDefinition
extends Resource

## Scheda di una barca (GDD § Upgrade): guida, statistiche e tutta la
## curva dei prezzi vivono qui, nei .tres in resources/boats/ — si
## bilancia dall'Inspector senza toccare scene o codice. Il numero di
## livelli di un upgrade è la lunghezza del suo array di costi.

@export var id: StringName
@export var display_name: String = ""
## Prezzo d'acquisto; 0 = barca di partenza.
@export var price: int = 0
@export var visual_scene: PackedScene
@export var collision_size: Vector3 = Vector3(1.8, 1.0, 5.4)

@export_group("Guida")
@export var max_speed: float = 14.0
@export var max_reverse_speed: float = 4.0
@export var acceleration: float = 5.0
@export var reverse_acceleration: float = 3.0
@export var brake_force: float = 8.0
@export var water_drag: float = 2.0
@export var turn_speed_deg: float = 60.0
@export var turn_full_speed_ratio: float = 0.35
@export var grip: float = 2.5

@export_group("Statistiche")
@export var hull_max: float = 100.0
@export var cargo_capacity: int = 8
## 0 = sughero in balia delle onde, 1 = piattaforma. Vedi Boat._apply_chaos.
@export_range(0.0, 1.0) var stability: float = 0.2

@export_group("Upgrade: costi per livello")
@export var motor_costs: Array[int] = []
@export var hull_costs: Array[int] = []
@export var stability_costs: Array[int] = []
@export var cargo_costs: Array[int] = []

@export_group("Upgrade: bonus per livello")
@export var motor_speed_step: float = 1.5
@export var motor_accel_step: float = 0.6
@export var hull_step: float = 25.0
@export var stability_step: float = 0.15
@export var cargo_step: int = 4
