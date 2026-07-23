class_name ItemDefinition
extends Resource

## Definizione di un item della stiva (roadmap R4): la fondazione della
## direzione item del gioco. Ogni cosa che si raccoglie e si porta a casa —
## boe, pesci, bottino, casse missione e (da R5) merci e materiali — è un
## ItemDefinition .tres in resources/items/. Aggiungere un item nuovo diventa
## un file solo: l'inventario unico di GameState lo conta, lo vende, i toast
## dell'HUD e la griglia dell'inventario lo mostrano, senza toccare codice.
##
## I valori economici e di presentazione vivono qui (CLAUDE.md: bilanciamento
## nei .tres). Le curve di gameplay (spawn, respawn, pesca, tier del bottino)
## restano in GameState, agganciate all'item dalla sua `id`.

## Categoria dell'item: raggruppa la griglia dell'inventario e distingue chi
## si vende da chi no. GOODS è predisposta per le merci di R5 (commercio con
## le città), MISSION sono le casse che occupano stiva ma non si vendono.
enum Category { BUOY, FISH, LOOT, GOODS, MISSION }

## Forma dell'icona procedurale (item_icon.gd): in assenza di asset CC0 ogni
## item si distingue per forma e colore. Da sostituire con una texture il
## giorno che arrivano vere icone.
enum Shape { BUOY, FISH, CRATE }

## Identità stabile dell'item: chiave dell'inventario e dei salvataggi. Non
## si cambia dopo il rilascio (i salvataggi la contengono).
@export var id: StringName = &""
## Nome al singolare e al plurale, per toast, dettaglio stiva e griglia.
@export var display_name: String = ""
@export var display_name_plural: String = ""
## Valore unitario di vendita al porto (0 = senza prezzo, es. casse missione).
@export var base_value: int = 0
@export var category: Category = Category.GOODS
## Colore identificativo (icona, pastiglia del toast, punto in minimappa).
@export var color: Color = Color.WHITE
@export var shape: Shape = Shape.CRATE
## Se falso, l'item occupa stiva ma non entra nel valore del carico né si
## svuota vendendo (casse missione).
@export var sellable: bool = true


## Nome adatto a una quantità: singolare per 1, plurale per il resto.
func name_for_count(count: int) -> String:
	return display_name if count == 1 else display_name_plural
