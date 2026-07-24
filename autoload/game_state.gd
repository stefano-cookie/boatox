extends Node

## Stato di partita e valori di bilanciamento dell'economia (CLAUDE.md:
## prezzi e curve vivono qui o nei .tres, mai nelle scene). Le boe sono
## item: vanno in stiva e diventano denaro solo vendendole al porto
## (GDD § core loop). Da M2 gestisce anche la flotta: barche possedute,
## upgrade per barca e salvataggio su file.

signal money_changed(amount: int)
signal hull_changed(current: float, max_value: float)
signal fuel_changed(current: float, max_value: float)
signal cargo_changed
signal hull_depleted
signal boat_changed(def: BoatDefinition)
signal notice_posted(text: String)
signal danger_changed(text: String)
signal danger_cleared
## Urto contro qualcosa: forza = velocità d'impatto (m/s). L'HUD lampeggia
## la barra scafo e la ChaseCamera scuote, in proporzione alla forza.
signal boat_hit(force: float)
## Momenti di gioco per l'audio (Audio autoload): raccolta boa (blu = suono
## speciale), pesce catturato, carico venduto (il cha-ching del pagoff),
## impulso radar. Event-driven: nessuna scena conosce l'audio.
signal buoy_collected(type: int)
signal fish_caught(type: int)
signal cargo_sold(amount: int)
signal radar_pinged
## Obiettivo guidato d'avvio cambiato (feedback playtest round 2): il
## nuovo giocatore ha sempre una riga che gli dice cosa fare. step = tappa
## corrente (TUTORIAL_DONE quando finito), text = riga da mostrare.
signal tutorial_changed(step: int, text: String)
## Vero quando almeno un pannello con puntatore (porto, pesca, regata,
## pausa) è aperto: la ChaseCamera rilascia/ricattura il mouse su questo
## segnale, senza duplicare la logica in ogni pannello.
signal ui_focus_changed(open: bool)
## Reputazione cambiata (roadmap A1): il pannello porto la mostra e i
## prezzi dei servizi la leggono. Per-fazione già dall'alpha
## (predisposizione B0: diventerà la diplomazia con le città).
signal reputation_changed(faction: StringName, value: int)
## Missione della bacheca accettata/avanzata/chiusa: minimappa, HUD e
## World (spawn del pacco di recupero) si aggiornano su questo.
signal mission_changed
## Missione portata a termine con successo (roadmap R2): il tracker HUD la
## celebra (animazione + suono). Distinto da mission_changed, che scatta
## anche su accetta/abbandona/fallisci.
signal mission_completed(what: String, reward: int)
## Vernice o accessori della barca corrente cambiati (acquisto, cambio o
## anteprima dal cantiere): la Boat riveste il suo modello su questo.
signal customization_changed
## Acquisto del primo Cabinato: il traguardo dell'alpha (roadmap A2).
## La schermata di fine alpha si mostra su questo, una volta sola.
signal alpha_completed
## Cannone comprato o potenziato (roadmap B1): la barca monta/aggiorna il
## pezzo su questo, l'HUD accende il mirino.
signal cannon_changed
## Momenti del combattimento navale (roadmap B1) per audio e feedback:
## un colpo partito (di chiunque), una nave colpita, una nave affondata,
## bottino raccolto. Event-driven come il resto.
signal cannon_fired
signal ship_hit(position: Vector3)
signal ship_sunk(position: Vector3)
signal loot_collected(tier: int)
## Tanica di benzina recuperata in acqua (roadmap R2): alimenta i toast di
## raccolta in basso a destra, come boe/pesci/bottino. Il rifornimento al
## porto NON la emette: è un pickup di mare, non un acquisto.
signal fuel_collected(liters: float)
## Item generico raccolto per id (roadmap R6): merci e tesori — casse dei
## relitti, prede con merci vere, pesca speciale. I segnali granulari sopra
## restano per i canali storici (suoni dedicati); questo alimenta i toast.
signal item_collected(id: StringName)
## Il world_state è tornato ai default (azzeramento partita): l'autoload
## Town lo rilancia alle scene del paese (slot, crescita, flottiglia).
signal world_state_reset

## Tipologie di boa legate al rischio della zona (GDD pillar 2):
## gialla in acque tranquille, rossa ai margini degli scogli, blu
## rarissima dentro i campi di scogli.
enum BuoyType { YELLOW, RED, BLUE }

## Upgrade funzionali (GDD § Upgrade): ognuno si sente nella guida.
enum UpgradeType { MOTOR, HULL, STABILITY, CARGO }

## Attrezzatura da pesca, comprata da Nino al porto: è personale, non
## della barca (vale su tutte). Canna = ferrata più facile (fase 1),
## mulinello = recupero più rapido (fase 2), lenza = più tolleranza alla
## tensione e agli strappi (fase 2).
enum FishingGear { ROD, REEL, LINE }

## Specie di pesce (GDD § Pesca): ogni fascia di mare ha una specie
## comune e una pregiata che premia il tempismo perfetto.
enum FishType { SARDINE, BREAM, AMBERJACK, TUNA }

## Missione del nipote in mare (GDD § Missioni): l'NPC dietro gli scogli a
## est la offre; completarla sblocca il radar. NONE non ancora accettata,
## ACCEPTED nipote da raggiungere al largo, CARRYING nipote a bordo da
## riportare, DONE conclusa. Salvata.
enum GrandsonQuest { NONE, ACCEPTED, CARRYING, DONE }

## Potenziamenti del radar (GDD § Missioni): comprati dall'NPC del nipote
## dopo lo sblocco. Ampiezza allarga il raggio di rilevazione, durata
## allunga la finestra visibile in minimappa, condensatori accorciano il
## cooldown (roadmap R3). È una famiglia a sé, come l'attrezzatura da pesca
## (personale, non della barca).
enum RadarUpgrade { RANGE, DURATION, COOLDOWN }

## Missioni della bacheca del porto (roadmap A1). Consegna: porta N casse
## all'approdo secondario entro il tempo limite (le casse occupano stiva).
## Recupero: raggiungi il punto segnato in minimappa, raccogli il pacco
## galleggiante e riportalo al porto principale. NPC_FETCH (roadmap R7):
## raccogli-e-consegna per un datore fisico a terra — gli porti gli item
## richiesti e lui paga in denaro, reputazione e item rari.
enum MissionType { DELIVERY, RECOVERY, NPC_FETCH }

## Catalogo item (roadmap R4): un .tres per item in resources/items/, ognuno
## un ItemDefinition con nome, valore, categoria, colore e forma dell'icona.
## È la fonte di verità di cosa si raccoglie e si porta a casa: l'inventario
## unico li conta, il porto li vende, HUD e griglia li mostrano. Aggiungere un
## item nuovo = un file qui, senza toccare codice. L'ordine è di presentazione
## (griglia inventario, dettaglio stiva). Le curve di gameplay (spawn, pesca,
## tier del bottino) restano a enum sotto, agganciate all'item dalla sua id.
const ITEM_DEFS: Array[ItemDefinition] = [
	preload("res://resources/items/buoy_yellow.tres"),
	preload("res://resources/items/buoy_red.tres"),
	preload("res://resources/items/buoy_blue.tres"),
	preload("res://resources/items/fish_sardine.tres"),
	preload("res://resources/items/fish_bream.tres"),
	preload("res://resources/items/fish_amberjack.tres"),
	preload("res://resources/items/fish_tuna.tres"),
	preload("res://resources/items/loot_modest.tres"),
	preload("res://resources/items/loot_good.tres"),
	preload("res://resources/items/loot_rich.tres"),
	preload("res://resources/items/goods_legno.tres"),
	preload("res://resources/items/goods_ferro.tres"),
	preload("res://resources/items/goods_stoffa.tres"),
	preload("res://resources/items/goods_spezie.tres"),
	preload("res://resources/items/goods_agrumi.tres"),
	preload("res://resources/items/goods_datteri.tres"),
	preload("res://resources/items/treasure_anfora.tres"),
	preload("res://resources/items/treasure_perla.tres"),
	preload("res://resources/items/treasure_carta.tres"),
	preload("res://resources/items/treasure_statuetta.tres"),
	preload("res://resources/items/mission_crate.tres"),
]
## Mappe dagli enum di gameplay (spawn boe, specie di pesca, tier del bottino
## restano a enum) all'id dell'item: il mondo ragiona per tipo, la stiva per id.
const BUOY_ITEM: Dictionary[int, StringName] = {
	BuoyType.YELLOW: &"buoy_yellow",
	BuoyType.RED: &"buoy_red",
	BuoyType.BLUE: &"buoy_blue",
}
const FISH_ITEM: Dictionary[int, StringName] = {
	FishType.SARDINE: &"fish_sardine",
	FishType.BREAM: &"fish_bream",
	FishType.AMBERJACK: &"fish_amberjack",
	FishType.TUNA: &"fish_tuna",
}
const LOOT_ITEM: Dictionary[int, StringName] = {
	0: &"loot_modest",
	1: &"loot_good",
	2: &"loot_rich",
}
## Casse missione: item non vendibile che occupa stiva (roadmap A1).
const MISSION_CRATE_ITEM: StringName = &"mission_crate"

## Probabilità che il punto boa sia occupato a ogni tentativo di spawn.
const BUOY_SPAWN_CHANCE: Dictionary[int, float] = {
	BuoyType.YELLOW: 1.0,
	BuoyType.RED: 0.3,
	BuoyType.BLUE: 0.05,
}
const BUOY_RESPAWN: Dictionary[int, float] = {
	BuoyType.YELLOW: 45.0,
	BuoyType.RED: 90.0,
	BuoyType.BLUE: 120.0,
}
## Pesca per fascia di mare (GDD pillar 2): più al largo pesci migliori,
## finestra di tempismo più stretta e cursore più rapido. Chiave: indice
## fascia di Sea.zone_index (0 = calme, 1 = medie, 2 = mosse).
const FISHING_COMMON: Dictionary[int, int] = {
	0: FishType.SARDINE,
	1: FishType.BREAM,
	2: FishType.AMBERJACK,
}
const FISHING_PRIZE: Dictionary[int, int] = {
	0: FishType.BREAM,
	1: FishType.AMBERJACK,
	2: FishType.TUNA,
}
## Larghezza della finestra di cattura, in frazione della barra (più
## stretta dal feedback playtest M3: la ferrata è solo la fase 1).
const FISHING_WINDOW: Dictionary[int, float] = {
	0: 0.22,
	1: 0.16,
	2: 0.12,
}
## Secondi per una traversata completa del cursore.
const FISHING_SWEEP_TIME: Dictionary[int, float] = {
	0: 1.1,
	1: 0.9,
	2: 0.7,
}
## Quota centrale della finestra che vale il pesce pregiato.
const FISHING_PRIZE_FRACTION: float = 0.4
## Catture per zona prima che i pesci se ne vadano, e secondi di riposo.
const FISHING_STOCK: int = 3
const FISHING_REST: float = 150.0

## Fase 2 della pesca, il duello (feedback playtest M3): tieni premuto E
## per recuperare, molla per far calare la tensione; a tensione piena
## troppo a lungo il filo si spezza. Per specie: reel_time = secondi di
## recupero effettivo, rise = tensione/s mentre si recupera, surge_* =
## scatti casuali (i pregiati strappano: bisogna mollare al momento
## giusto). Tutto qui, si bilancia senza toccare la scena.
const FISH_FIGHT: Dictionary[int, Dictionary] = {
	FishType.SARDINE: {"reel_time": 3.0, "rise": 0.35,
		"surge_interval": 0.0, "surge_duration": 0.0, "surge_rise": 0.0},
	FishType.BREAM: {"reel_time": 4.5, "rise": 0.45,
		"surge_interval": 3.4, "surge_duration": 1.0, "surge_rise": 0.5},
	FishType.AMBERJACK: {"reel_time": 5.5, "rise": 0.48,
		"surge_interval": 2.8, "surge_duration": 1.3, "surge_rise": 0.6},
	FishType.TUNA: {"reel_time": 7.0, "rise": 0.55,
		"surge_interval": 2.4, "surge_duration": 1.6, "surge_rise": 0.72},
}
## Discesa della tensione a lenza mollata, in frazione/s.
const FISH_TENSION_FALL: float = 0.95
## Il pesce riprende lenza mentre molli: progresso perso in frazione/s.
const FISH_PROGRESS_DECAY: float = 0.05
## Secondi concessi a tensione piena prima che il filo si spezzi (di base;
## la lenza li aumenta).
const FISH_SNAP_GRACE: float = 0.55

## Attrezzatura da pesca (indice = livello, 0 = base). Costo del livello
## successivo in FISHING_GEAR_COSTS. Gli effetti si applicano in
## FishingZone leggendo i getter fishing_* qui sotto.
const FISHING_GEAR_NAME: Dictionary[int, String] = {
	FishingGear.ROD: "Canna",
	FishingGear.REEL: "Mulinello",
	FishingGear.LINE: "Lenza",
}
const FISHING_GEAR_DESC: Dictionary[int, String] = {
	FishingGear.ROD: "finestra di ferrata più larga",
	FishingGear.REEL: "recupero più rapido, tensione più lenta",
	FishingGear.LINE: "regge di più e doma gli strappi",
}
const FISHING_GEAR_COSTS: Dictionary[int, Array] = {
	FishingGear.ROD: [200, 450, 900],
	FishingGear.REEL: [250, 550, 1100],
	FishingGear.LINE: [220, 500, 1000],
}
## Canna: quota aggiunta alla larghezza della finestra di ferrata.
const FISHING_ROD_WINDOW_BONUS: Array[float] = [0.0, 0.03, 0.06, 0.09]
## Mulinello: moltiplicatori (per livello) di tempo di recupero e salita
## della tensione — più bassi = più facile.
const FISHING_REEL_TIME_MULT: Array[float] = [1.0, 0.88, 0.78, 0.68]
const FISHING_REEL_RISE_MULT: Array[float] = [1.0, 0.9, 0.82, 0.74]
## Lenza: secondi di grazia extra a tensione piena e moltiplicatore della
## forza degli strappi (più basso = strappi più gestibili).
const FISHING_LINE_GRACE_BONUS: Array[float] = [0.0, 0.2, 0.45, 0.75]
const FISHING_LINE_SURGE_MULT: Array[float] = [1.0, 0.85, 0.72, 0.6]

## Radar (GDD § Missioni): sostituisce la visibilità gratuita di boe e
## zone in minimappa con una progressione. Sbloccato dalla missione del
## nipote, si attiva a impulsi (tasto R): boe, taniche e zone dentro il
## raggio compaiono in minimappa per una finestra, poi si spegne fino al
## cooldown. I potenziamenti (comprati dall'NPC) allargano il raggio,
## allungano la finestra e accorciano il cooldown. Curve per livello, si
## bilanciano qui.
## Secondi di ricarica tra un impulso e l'altro, per livello del
## potenziamento "Condensatori" (roadmap R3): base 60 s, giù fino a 15 s.
const RADAR_COOLDOWN_STEPS: Array[float] = [60.0, 45.0, 30.0, 20.0, 15.0]
## Raggio di rilevazione come frazione di World.bounds_depth, per livello
## di ampiezza (0 = base: circa un terzo della mappa).
const RADAR_RANGE_FRACTION: Array[float] = [0.34, 0.5, 0.68, 0.9]
## Secondi di permanenza dei rilevamenti in minimappa, per livello di durata.
const RADAR_DURATION: Array[float] = [10.0, 14.0, 18.0, 24.0]
const RADAR_UPGRADE_NAME: Dictionary[int, String] = {
	RadarUpgrade.RANGE: "Antenna",
	RadarUpgrade.DURATION: "Ricevitore",
	RadarUpgrade.COOLDOWN: "Condensatori",
}
const RADAR_UPGRADE_DESC: Dictionary[int, String] = {
	RadarUpgrade.RANGE: "raggio di rilevazione più ampio",
	RadarUpgrade.DURATION: "i rilevamenti restano visibili più a lungo",
	RadarUpgrade.COOLDOWN: "il radar si ricarica più in fretta tra un impulso e l'altro",
}
const RADAR_UPGRADE_COSTS: Dictionary[int, Array] = {
	RadarUpgrade.RANGE: [400, 900, 1800],
	RadarUpgrade.DURATION: [350, 800, 1600],
	RadarUpgrade.COOLDOWN: [500, 1000, 1900, 3200],
}

## Reputazione (roadmap A1): -100..+100, per-fazione. Dalle città
## lontane di B4 è la relazione diplomatica vera e propria (Diplomacy la
## legge a soglie). Sconta o rincara i servizi di porto di
## ±REP_PRICE_EFFECT a fondo scala.
const FACTION_BOVA: StringName = &"bova"
## Città lontane del mare grande (roadmap B4): Catania a sud-ovest (più
## vicina) e Il Cairo a sud-est (molto più lontana). Entrambe ostili dal
## primo giorno (deciso il 23/07/2026 con Stefano): il finale beta le apre
## con la diplomazia, non partono amiche. "franco" è la fazione neutra
## degli scali di rifornimento in mezzo al mare (né amici né nemici).
const FACTION_CATANIA: StringName = &"catania"
const FACTION_CAIRO: StringName = &"cairo"
const FACTION_FRANCO: StringName = &"franco"
const REP_MIN: int = -100
const REP_MAX: int = 100
const REP_PRICE_EFFECT: float = 0.15
## Relazioni di partenza con le fazioni che non cominciano neutrali:
## Catania e Il Cairo sono ostili dal primo giorno (roadmap B4). Applicate
## al reset e ai salvataggi che non conoscono la fazione.
const FACTION_START_REP: Dictionary[StringName, int] = {
	FACTION_CATANIA: -40,
	FACTION_CAIRO: -40,
}

## Missioni della bacheca (roadmap A1): ricompensa scalata su distanza e
## fascia di mare del punto (più a largo = più soldi, GDD pillar 2).
## Consegna: paga per cassa + per metro di rotta; il tempo limite assume
## una velocità media prudente più un margine per attracco e manovre.
const MISSION_REWARD_PER_CRATE: int = 45
const MISSION_DELIVERY_REWARD_PER_METER: float = 0.15
const MISSION_DELIVERY_SPEED: float = 6.0
const MISSION_DELIVERY_TIME_BUFFER: float = 40.0
const MISSION_RECOVERY_BASE: int = 40
const MISSION_RECOVERY_REWARD_PER_METER: float = 0.35
## Moltiplicatore per fascia di mare del punto di recupero (indice di
## Sea.zone_index).
const MISSION_ZONE_MULT: Array[float] = [1.0, 1.2, 1.5]
const MISSION_REP_REWARD: int = 5
const MISSION_REP_FAIL: int = -5
const MISSION_REP_ABANDON: int = -3

## Incarichi dei datori NPC a terra (roadmap R5/R7): scritti a mano, per
## npc_id. Ogni voce: id univoco (spuntato in world_state.npc_done una volta
## consegnata), titolo, richiesta in items (id item → quantità), ricompensa in
## denaro/reputazione e un eventuale item in regalo. Le ricompense superano
## sempre il valore di vendita degli item richiesti: portare la roba al datore
## deve battere il banco del porto. Valori proposti — da validare in playtest.
const NPC_MISSIONS: Dictionary[StringName, Array] = {
	&"mastro_cola": [
		{
			"id": "cola_assi", "title": "Assi per il molo",
			"desc": "Il molo scricchiola e il legname buono sta in mare: relitti e prede ne sono pieni.",
			"needs": {"goods_legno": 3}, "reward": 180, "rep": 4, "reward_item": "",
		},
		{
			"id": "cola_chiodi", "title": "Ferro per i chiodi",
			"desc": "Chiodi e staffe per le barche nuove: mi serve ferro, e un'asse per i modelli.",
			"needs": {"goods_ferro": 2, "goods_legno": 1}, "reward": 300, "rep": 5, "reward_item": "",
		},
		{
			"id": "cola_progetto", "title": "Il banco del maestro d'ascia",
			"desc": "Con ferro e stoffa buona rimetto in piedi il banco da lavoro. In cambio ti cedo una carta nautica di famiglia.",
			"needs": {"goods_ferro": 3, "goods_stoffa": 2}, "reward": 120, "rep": 6,
			"reward_item": "treasure_carta",
		},
	],
	&"donna_rosa": [
		{
			"id": "rosa_stoffe", "title": "Stoffe per la festa",
			"desc": "Per la festa del paese servono stoffe: i mercantili ne portano sempre qualche balla.",
			"needs": {"goods_stoffa": 3}, "reward": 240, "rep": 4, "reward_item": "",
		},
		{
			"id": "rosa_spezie", "title": "Spezie dal largo",
			"desc": "La bottega è senza spezie da settimane. Chi va per mare le trova, chi sta al banco le paga.",
			"needs": {"goods_spezie": 2}, "reward": 320, "rep": 5, "reward_item": "",
		},
		{
			"id": "rosa_agrumi", "title": "Agrumi di Catania",
			"desc": "Gli agrumi di Catania qui non arrivano più. Portameli e ti do un'anfora che tengo in cantina.",
			"needs": {"goods_agrumi": 2}, "reward": 160, "rep": 5,
			"reward_item": "treasure_anfora",
		},
	],
	&"don_liborio": [
		{
			"id": "liborio_anfora", "title": "L'anfora per la canonica",
			"desc": "Un'anfora antica starebbe benissimo in canonica. Il mare le custodisce: tu me la porti, io pago.",
			"needs": {"treasure_anfora": 1}, "reward": 420, "rep": 6, "reward_item": "",
		},
		{
			"id": "liborio_perla", "title": "La perla della Madonna",
			"desc": "Per la statua della Madonna del mare voglio una perla vera, di quelle delle acque difficili.",
			"needs": {"treasure_perla": 1}, "reward": 520, "rep": 8, "reward_item": "",
		},
		{
			"id": "liborio_statua", "title": "La statuetta dorata",
			"desc": "Dicono che un relitto custodisca una statuetta dorata. Riportala alla luce e non ti farò mancare nulla.",
			"needs": {"treasure_statuetta": 1}, "reward": 850, "rep": 10, "reward_item": "",
		},
	],
}

## Gli eventi casuali non affondano mai la barca da soli: lo scafo non
## scende sotto questa soglia per effetto di una scelta.
const EVENT_MIN_HULL: float = 5.0

## Cannone di bordo (roadmap B1): famiglia di upgrade come motore e scafo,
## ma personale come l'attrezzatura da pesca (vale su ogni barca: non si
## ricompra cambiando scafo). Livello 0 = nessun cannone; ogni livello è
## una WeaponDefinition .tres con danno/gittata/cadenza e prezzo.
const CANNON_DEFS: Array[WeaponDefinition] = [
	preload("res://resources/weapons/cannone_1.tres"),
	preload("res://resources/weapons/cannone_2.tres"),
	preload("res://resources/weapons/cannone_3.tres"),
]

## Bottino galleggiante mollato dalle navi affondate (roadmap B1): tier
## per fascia di mare del punto dell'affondamento — prede migliori dove il
## mare è più duro (GDD pillar 2). Ogni tier è un item (LOOT_ITEM): va in
## stiva come le boe e si vende al porto.

## Ricompensa per acque difficili (roadmap R3, GDD pillar 2): oltre alle
## fasce di mare (boe/pesca/bottino/gare già scalano per fascia), un
## fattore continuo che cresce con la distanza dalla costa e con
## l'agitazione locale del mare (celle di vento comprese). 1.0 sotto costa
## e col mare gestibile, fino a DIFFICULTY_REWARD_MAX al largo e in
## tempesta. Lo leggono chi assegna ricompense a posizione nota (bottino,
## regate al largo): i punti più lontani e più mossi rendono di più.
const DIFFICULTY_REWARD_MAX: float = 2.0
## Distanza dalla costa oltre le acque medie a cui il contributo distanza
## satura.
const DIFFICULTY_REWARD_FULL_DISTANCE: float = 1400.0
## Peso relativo dei due contributi (distanza, agitazione): la loro somma
## pesata scala il bonus oltre 1.0.
const DIFFICULTY_REWARD_DISTANCE_WEIGHT: float = 0.6
const DIFFICULTY_REWARD_AGITATION_WEIGHT: float = 0.4
## Agitazione (Sea.agitation) di riferimento: sotto CALM è mare gestibile
## (nessun contributo), sopra ROUGH conta come mare grosso (contributo pieno).
const DIFFICULTY_AGITATION_CALM: float = 1.5
const DIFFICULTY_AGITATION_ROUGH: float = 3.2

## Item e fonti in mare (roadmap R6): merci comuni e tesori rari, con le
## loro fonti — relitti semisommersi, prede con merci vere, pesca speciale.
## Le merci saranno anche ingredienti di costruzione (B3), i tesori la
## moneta delle missioni NPC (R7): il doppio ruolo deciso in R5.

## Merce tipica per fazione (roadmap R6): le navi di Catania e Il Cairo
## portano le merci della loro città — si capisce da dove viene la preda.
const FACTION_GOODS: Dictionary[StringName, StringName] = {
	FACTION_CATANIA: &"goods_agrumi",
	FACTION_CAIRO: &"goods_datteri",
}
## Probabilità che una cassa mollata da una preda sia merce vera (dal
## goods_pool della ShipDefinition) invece del bottino generico a tier.
const SHIP_GOODS_CHANCE: float = 0.5
## Sulle navi con una fazione "di città": quota delle casse-merce che è la
## merce tipica della città invece che dal pool della nave.
const SHIP_FACTION_GOOD_WEIGHT: float = 0.6

## Relitti semisommersi (roadmap R6): quante casse galleggiano attorno a un
## relitto scoperto, e la probabilità che una sia un tesoro — scalata dal
## fattore difficoltà del punto (relitti più lontani e in acque più dure
## nascondono di più). Il resto sono merci dal pool dei relitti.
const WRECK_CRATES_MIN: int = 4
const WRECK_CRATES_MAX: int = 6
const WRECK_TREASURE_CHANCE_MIN: float = 0.1
const WRECK_TREASURE_CHANCE_MAX: float = 0.4
const WRECK_GOODS: Array[StringName] = [
	&"goods_legno", &"goods_ferro", &"goods_stoffa", &"goods_spezie",
]
## Pesi dei tesori (id -> peso): l'anfora è il tesoro "comune", la
## statuetta il colpo raro. Usati da relitti e pesca speciale.
const TREASURE_WEIGHTS: Dictionary[StringName, int] = {
	&"treasure_anfora": 5,
	&"treasure_perla": 3,
	&"treasure_carta": 2,
	&"treasure_statuetta": 1,
}

## Pesca speciale (roadmap R6): nelle zone di pesca del mare aperto (tier
## 2) una cattura può tirare su un tesoro invece del pesce. Probabilità da
## zero (acque medie tranquille) fino al massimo, scalata sul fattore
## difficoltà del punto (riusa difficulty_multiplier di R3). Dal mare
## escono solo anfore e perle: carte e statuette stanno nei relitti.
const FISHING_TREASURE_CHANCE_MAX: float = 0.25
const FISHING_TREASURE_WEIGHTS: Dictionary[StringName, int] = {
	&"treasure_anfora": 3,
	&"treasure_perla": 2,
}

## Regata (GDD § Corse): premi per piazzamento e avversari IA. Le IA non
## hanno velocità assolute ma frazioni della velocità effettiva del
## giocatore al via (feedback playtest M3): la gara resta combattuta con
## ogni barca e upgrade — vincere richiede traiettorie, non solo motore.
## speed_ratio moltiplica effective_max_speed(), stability_delta si somma
## a effective_stability() (clampata 0..1).
const RACE_PRIZES: Array[int] = [300, 120, 50]
## Moltiplicatore dei premi per tier di barca (indice in BOAT_DEFS): la
## regata resta redditizia senza diventare farming facile.
const RACE_PRIZE_TIER_MULT: Array[float] = [1.0, 1.6, 2.4]
## Set IA della gara sotto costa (spot facile). Feedback playtest round 2:
## Turi era troppo forte (1.03× e molto stabile), la gara base non si
## vinceva con la barchetta. Ora tutte le IA sono ≤ della velocità del
## giocatore: si vince con traiettorie pulite, non solo col motore.
const RACE_AI: Array[Dictionary] = [
	{"name": "Ciccio", "visual": "res://scenes/boat/visuals/dinghy_visual.tscn",
		"speed_ratio": 0.88, "stability_delta": -0.1, "turn": 60.0},
	{"name": "Rosa", "visual": "res://scenes/boat/visuals/dinghy_visual.tscn",
		"speed_ratio": 0.95, "stability_delta": 0.0, "turn": 55.0},
	{"name": "Turi", "visual": "res://scenes/boat/visuals/fishing_visual.tscn",
		"speed_ratio": 0.99, "stability_delta": 0.06, "turn": 52.0},
]
## Set IA della gara al largo (spot difficile, feedback playtest round 2):
## rivali più veloci e stabili del giocatore — la vince solo chi sfrutta
## le loro frenate in curva e il mare. Ricompensa maggiore (vedi lo spot
## RaceCourse.prize_multiplier al largo).
const RACE_AI_HARD: Array[Dictionary] = [
	{"name": "Saro", "visual": "res://scenes/boat/visuals/fishing_visual.tscn",
		"speed_ratio": 1.0, "stability_delta": 0.1, "turn": 54.0},
	{"name": "Nunzio", "visual": "res://scenes/boat/visuals/fishing_visual.tscn",
		"speed_ratio": 1.06, "stability_delta": 0.18, "turn": 50.0},
	{"name": "Peppe", "visual": "res://scenes/boat/visuals/cruiser_visual.tscn",
		"speed_ratio": 1.12, "stability_delta": 0.25, "turn": 46.0},
]


## Set IA di uno spot: difficile al largo, facile sotto costa.
func race_ai_set(hard: bool) -> Array[Dictionary]:
	return RACE_AI_HARD if hard else RACE_AI

const UPGRADE_NAME: Dictionary[int, String] = {
	UpgradeType.MOTOR: "Motore",
	UpgradeType.HULL: "Scafo",
	UpgradeType.STABILITY: "Stabilità",
	UpgradeType.CARGO: "Stiva",
}
## Cosa fa in gioco ogni upgrade (feedback playtest round 2: "non sono
## spiegati"). Mostrato nel cantiere accanto al delta del prossimo livello.
const UPGRADE_DESC: Dictionary[int, String] = {
	UpgradeType.MOTOR: "Velocità di punta più alta",
	UpgradeType.HULL: "Reggi più urti prima di cedere",
	UpgradeType.STABILITY: "Tieni la barra col mare mosso",
	UpgradeType.CARGO: "Porti più carico prima di vendere",
}

## Obiettivo guidato d'avvio (feedback playtest round 2): tappe leggere,
## una riga contestuale che si aggiorna. Avanzano da sole al verificarsi
## dell'evento; TUTORIAL_DONE nasconde la riga. Salvato: chi ha già un
## salvataggio "vecchio" parte da DONE (non lo si annoia).
const TUTORIAL_COLLECT: int = 0
const TUTORIAL_SELL: int = 1
const TUTORIAL_EXPLORE: int = 2
const TUTORIAL_DONE: int = 3
const TUTORIAL_HINTS: Dictionary[int, String] = {
	TUTORIAL_COLLECT: "Obiettivo: raccogli 3 boe passandoci sopra con la barca",
	TUTORIAL_SELL: "Obiettivo: torna al porto (rombo arancio in minimappa, tasto M) e vendi il carico",
	TUTORIAL_EXPLORE: "Obiettivo: prova qualcosa di nuovo — la pesca (anelli azzurri) o una regata",
}
## Quante boe raccogliere per superare la prima tappa.
const TUTORIAL_BUOY_GOAL: int = 3

## Ordine di progressione: è anche l'ordine di listino del cantiere.
const BOAT_DEFS: Array[BoatDefinition] = [
	preload("res://resources/boats/dinghy.tres"),
	preload("res://resources/boats/fishing_boat.tres"),
	preload("res://resources/boats/cruiser.tres"),
]

## Customizzazione estetica (roadmap A2): solo visiva, prezzi alti — è il
## pozzo dell'economia (GDD pillar 3). Le vernici tingono i materiali del
## modello (scafo + rifinitura), gli accessori sono nodi opzionali montati
## sul visual (vedi scripts/boat_customization.gd). Tutto per barca,
## salvato. &"original" è la livrea di fabbrica: gratis, sempre posseduta.
const PAINT_ORIGINAL: StringName = &"original"
const PAINTS: Array[Dictionary] = [
	{"id": PAINT_ORIGINAL, "name": "Livrea di fabbrica", "price": 0,
		"hull": Color.WHITE, "accent": Color.WHITE},
	{"id": &"perla", "name": "Bianco perla", "price": 400,
		"hull": Color(0.93, 0.93, 0.9), "accent": Color(0.2, 0.32, 0.45)},
	{"id": &"corallo", "name": "Rosso corallo", "price": 450,
		"hull": Color(0.83, 0.33, 0.26), "accent": Color(0.5, 0.16, 0.12)},
	{"id": &"notte", "name": "Blu notte", "price": 450,
		"hull": Color(0.13, 0.2, 0.36), "accent": Color(0.75, 0.78, 0.82)},
	{"id": &"menta", "name": "Verde menta", "price": 500,
		"hull": Color(0.55, 0.8, 0.68), "accent": Color(0.16, 0.38, 0.3)},
	{"id": &"sole", "name": "Giallo sole", "price": 500,
		"hull": Color(0.92, 0.78, 0.28), "accent": Color(0.45, 0.35, 0.1)},
	{"id": &"carbone", "name": "Nero carbone", "price": 600,
		"hull": Color(0.16, 0.17, 0.19), "accent": Color(0.85, 0.6, 0.2)},
]
const ACCESSORIES: Array[Dictionary] = [
	{"id": &"flag", "name": "Bandiera di poppa", "price": 300,
		"desc": "sventola sulla poppa nel colore della rifinitura"},
	{"id": &"fenders", "name": "Parabordi", "price": 350,
		"desc": "una fila di parabordi bianchi lungo le murate"},
	{"id": &"lights", "name": "Luci di cortesia", "price": 550,
		"desc": "un filo di lucine calde da prua a poppa"},
]

## Riparare tutto lo scafo da zero costa hull_max * questo valore.
const REPAIR_COST_PER_POINT: float = 0.5
const FUEL_PRICE_PER_LITER: float = 1.0
## Litri restituiti da una tanica trovata in mare.
const FUEL_CAN_LITERS: float = 15.0
## Probabilità che un punto tanica sia occupato a ogni ciclo (roadmap: 5%).
const FUEL_CAN_SPAWN_CHANCE: float = 0.05
const FUEL_CAN_RESPAWN: float = 60.0
const TOW_FEE: int = 30
## Scafo restituito dal traino: quanto basta per ripartire, non di più.
const TOW_HULL_RESTORE: float = 20.0
## Recupero dopo l'affondamento al largo (feedback playtest M3): più caro
## del traino, e il carico è perso — il vero rischio del mare aperto.
const SALVAGE_FEE: int = 100

const SAVE_VERSION: int = 1
## Cartella dei mondi (menu principale stile "i mondi"): ogni partita è
## un file JSON qui dentro, col suo nome e la data dell'ultima sessione.
## Var come save_path: i test headless la reindirizzano su una propria.
var worlds_dir: String = "user://worlds"
## Var e non const: i test headless la reindirizzano su un file proprio
## per non toccare (e cancellare!) il salvataggio vero del giocatore.
var save_path: String = "user://save.json"
## Nome del mondo corrente, mostrato nel menu e salvato nel file.
var world_name: String = "Bova Marina"
## Alzato dal title prima di ricaricare la scena (nuovo mondo o cambio
## mondo): al giro dopo il title salta il menu e salpa subito.
var autostart_once: bool = false

var money: int = 0
var hull: float = 100.0
var fuel: float = 40.0
## Inventario unico della stiva (roadmap R4): id item -> quantità. Un solo
## contenitore per boe, pesci, bottino, casse missione e (da R5) merci e
## materiali — la stiva è una sola (GDD § Pesca). Sostituisce i quattro
## dizionari dedicati dell'alpha; i salvataggi vecchi vi confluiscono in
## caricamento (_migrate_legacy_cargo). Salvato.
var inventory: Dictionary[StringName, int] = {}

## Livello del cannone di bordo (0 = nessuno, indice+1 in CANNON_DEFS).
## Personale come l'attrezzatura da pesca. Salvato.
var cannon_level: int = 0

## Vittorie in regata: la prima sblocca le barche con requires_race_win.
var race_wins: int = 0

## Tappa dell'obiettivo guidato d'avvio (vedi TUTORIAL_*). Salvato.
var tutorial_step: int = TUTORIAL_COLLECT

var owned_boats: Array[StringName] = [&"dinghy"]
var current_boat_id: StringName = &"dinghy"
## Livelli upgrade per barca: id barca -> { UpgradeType -> livello }.
var upgrades: Dictionary[StringName, Dictionary] = {}
## Livelli dell'attrezzatura da pesca (FishingGear -> livello): globale,
## comprata da Nino al porto.
var fishing_gear: Dictionary[int, int] = {}

## Reputazione per fazione (vedi FACTION_*). Salvata. Letta a soglie
## dall'autoload Diplomacy (predisposizione B0). Parte dalle relazioni
## iniziali anche a freddo, senza salvataggio (Catania e Il Cairo ostili).
var reputation: Dictionary[StringName, int] = FACTION_START_REP.duplicate()
## Stato del mondo gestionale (predisposizione B0, roadmap beta):
## prosperità di Bova e difese costruite; le relazioni vivono già in
## `reputation`. Salvato accanto a denaro e upgrade. Le chiavi si
## consolidano in B2/B3 quando i sistemi nascono.
var world_state: Dictionary = _default_world_state()
## Missione attiva dalla bacheca (vuoto = nessuna): tipo, target,
## ricompensa… (vedi generate_mission_offers). Una alla volta, salvata.
var active_mission: Dictionary = {}
## Secondi rimasti alla consegna (solo missioni DELIVERY). Salvato.
var mission_time_left: float = 0.0

## Lookup id -> ItemDefinition, costruito da ITEM_DEFS all'avvio.
var _item_by_id: Dictionary[StringName, ItemDefinition] = {}

## Missione del nipote in mare (vedi GrandsonQuest). Salvata.
var grandson_quest: int = GrandsonQuest.NONE
## Radar sbloccato (dalla missione del nipote): senza, la minimappa non
## rivela boe e zone. Salvato.
var radar_unlocked: bool = false
## Livelli dei potenziamenti del radar (RadarUpgrade -> livello). Salvati.
var radar_upgrades: Dictionary[int, int] = {}

## Vernici possedute per barca (id barca -> Array di id vernice); la
## livrea di fabbrica è implicita. Salvate.
var paints_owned: Dictionary[StringName, Array] = {}
## Vernice applicata per barca (chiave assente = livrea di fabbrica). Salvata.
var paint_applied: Dictionary[StringName, StringName] = {}
## Accessori per barca (comprato = montato). Salvati.
var accessories_owned: Dictionary[StringName, Array] = {}
## Anteprima vernice del cantiere (non salvata): &"" = nessuna anteprima.
var paint_preview: StringName = &""

## Statistiche di partita per la schermata di fine alpha (roadmap A2):
## secondi giocati (la pausa non conta: _process è PAUSABLE), denaro
## totale guadagnato e pesci catturati. Salvate.
var play_seconds: float = 0.0
var total_earned: int = 0
var fish_caught_total: int = 0
## Vero se la schermata di fine alpha è già stata mostrata (si mostra una
## volta sola, poi si continua a giocare liberamente). Salvato.
var alpha_end_shown: bool = false

## Vero mentre il giocatore è sbarcato a piedi (roadmap R7). Transiente,
## non salvato: al caricamento si riparte sempre in barca. Porto, mirino e
## radar lo leggono per spegnersi mentre si cammina.
var on_foot: bool = false


func _ready() -> void:
	_build_item_index()
	# Cheat di playtest: lanciando con `--maxed` (dopo il `--` di Godot)
	# la sessione parte con tutto al massimo, su un salvataggio separato —
	# i mondi veri non si toccano. Deferred: Town e la scena devono esserci.
	if OS.get_cmdline_user_args().has("--maxed"):
		save_path = "user://save_maxed.json"
		load_game()
		debug_max_all.call_deferred()
		return
	# In headless (test, CI) niente menu dei mondi: si carica il percorso
	# di default come sempre (i test impostano save_path da soli).
	if DisplayServer.get_name() == "headless":
		load_game()
		return
	# Avvio normale: si carica il mondo giocato più di recente come
	# fondale del title; è poi il menu (Continua / Nuova partita / I
	# mondi) a decidere cosa si gioca davvero.
	migrate_legacy_save()
	# Tre mondi di prova sempre presenti nel menu "i mondi" (richiesta di
	# Stefano, 23/07/2026): Da zero, A metà, Maxato — comodi per testare gli
	# stati del gioco. Creati solo se assenti: non toccano i mondi veri e i
	# progressi fatti su di essi restano.
	seed_demo_worlds()
	var recent := most_recent_world_path()
	save_path = recent if recent != "" else worlds_dir + "/da-zero.json"
	load_game()


## Timer della consegna: scorre anche attraccati (la tensione è il senso
## della missione) ma si ferma in pausa insieme al resto del gioco — come
## il tempo di gioco, che conta solo la partita vera (title e pausa fermano
## l'albero, quindi non contano).
func _process(delta: float) -> void:
	play_seconds += delta
	if mission_type() != MissionType.DELIVERY:
		return
	mission_time_left -= delta
	if mission_time_left <= 0.0:
		fail_mission("Tempo scaduto! Le casse tornano al mittente")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


# --- Flotta e statistiche effettive -----------------------------------------

func boat_def(id: StringName) -> BoatDefinition:
	for def in BOAT_DEFS:
		if def.id == id:
			return def
	push_error("Barca sconosciuta: %s" % id)
	return BOAT_DEFS[0]


func current_def() -> BoatDefinition:
	return boat_def(current_boat_id)


func owns_boat(id: StringName) -> bool:
	return owned_boats.has(id)


func upgrade_level(type: int, boat_id: StringName = current_boat_id) -> int:
	var boat_upgrades: Dictionary = upgrades.get(boat_id, {})
	return boat_upgrades.get(type, 0)


func upgrade_max_level(type: int, boat_id: StringName = current_boat_id) -> int:
	return _upgrade_costs(boat_def(boat_id), type).size()


## Costo del prossimo livello; -1 se l'upgrade è già al massimo.
func upgrade_cost(type: int, boat_id: StringName = current_boat_id) -> int:
	var costs := _upgrade_costs(boat_def(boat_id), type)
	var level := upgrade_level(type, boat_id)
	if level >= costs.size():
		return -1
	return costs[level]


## Anteprima dell'effetto del prossimo livello ("42 → 46"), per il
## cantiere: il giocatore vede cosa guadagna. "" se l'upgrade è al massimo.
func upgrade_delta_preview(type: int) -> String:
	var level := upgrade_level(type)
	if level >= upgrade_max_level(type):
		return ""
	var def := current_def()
	match type:
		UpgradeType.MOTOR:
			var cur := effective_max_speed()
			return "vel %d → %d" % [roundi(cur), roundi(cur + def.motor_speed_step)]
		UpgradeType.HULL:
			var cur := hull_max()
			return "scafo %d → %d" % [roundi(cur), roundi(cur + def.hull_step)]
		UpgradeType.STABILITY:
			var cur := roundi(effective_stability() * 100.0)
			var nxt := roundi(clampf(def.stability + (level + 1) * def.stability_step, 0.0, 1.0) * 100.0)
			return "stab %d%% → %d%%" % [cur, nxt]
		_:
			var cur := cargo_capacity()
			return "stiva %d → %d" % [cur, cur + def.cargo_step]


func effective_max_speed() -> float:
	var def := current_def()
	return def.max_speed + upgrade_level(UpgradeType.MOTOR) * def.motor_speed_step


func effective_acceleration() -> float:
	var def := current_def()
	return def.acceleration + upgrade_level(UpgradeType.MOTOR) * def.motor_accel_step


func hull_max() -> float:
	var def := current_def()
	return def.hull_max + upgrade_level(UpgradeType.HULL) * def.hull_step


func effective_stability() -> float:
	var def := current_def()
	return clampf(def.stability + upgrade_level(UpgradeType.STABILITY) * def.stability_step, 0.0, 1.0)


func cargo_capacity() -> int:
	var def := current_def()
	return def.cargo_capacity + upgrade_level(UpgradeType.CARGO) * def.cargo_step


func fuel_capacity() -> float:
	return current_def().fuel_capacity


## Vero se la barca è acquistabile: alcune chiedono una vittoria in
## regata (GDD § Corse: vincere sblocca contenuti).
func boat_unlocked(id: StringName) -> bool:
	return not boat_def(id).requires_race_win or race_wins > 0


func buy_boat(id: StringName) -> bool:
	var def := boat_def(id)
	if owns_boat(id) or money < def.price or not boat_unlocked(id):
		return false
	money -= def.price
	owned_boats.append(id)
	money_changed.emit(money)
	post_notice("%s acquistato!" % def.display_name)
	select_boat(id)
	# Il Cabinato è il traguardo dell'alpha (roadmap A2): la prima volta
	# parte la schermata di fine alpha, poi si continua liberamente.
	if id == &"cruiser" and not alpha_end_shown:
		alpha_end_shown = true
		save_game()
		alpha_completed.emit()
	return true


## Cambio barca: scafo e benzina mantengono la percentuale (niente
## riparazioni o pieni gratis facendo avanti e indietro tra le barche).
func select_boat(id: StringName) -> void:
	if not owns_boat(id) or id == current_boat_id:
		return
	var hull_ratio := hull / hull_max()
	var fuel_ratio := fuel / fuel_capacity()
	current_boat_id = id
	hull = hull_ratio * hull_max()
	fuel = fuel_ratio * fuel_capacity()
	boat_changed.emit(current_def())
	hull_changed.emit(hull, hull_max())
	fuel_changed.emit(fuel, fuel_capacity())
	cargo_changed.emit()
	save_game()


func buy_upgrade(type: int) -> bool:
	var cost := upgrade_cost(type)
	if cost < 0 or money < cost:
		return false
	money -= cost
	var boat_upgrades: Dictionary = upgrades.get(current_boat_id, {})
	boat_upgrades[type] = boat_upgrades.get(type, 0) + 1
	upgrades[current_boat_id] = boat_upgrades
	if type == UpgradeType.HULL:
		# I punti scafo aggiunti arrivano integri: il danno resta assoluto.
		hull += current_def().hull_step
	money_changed.emit(money)
	boat_changed.emit(current_def())
	hull_changed.emit(hull, hull_max())
	cargo_changed.emit()
	post_notice("%s livello %d installato" % [UPGRADE_NAME[type], upgrade_level(type)])
	save_game()
	return true


func _upgrade_costs(def: BoatDefinition, type: int) -> Array[int]:
	match type:
		UpgradeType.MOTOR:
			return def.motor_costs
		UpgradeType.HULL:
			return def.hull_costs
		UpgradeType.STABILITY:
			return def.stability_costs
		_:
			return def.cargo_costs


# --- Attrezzatura da pesca (bottega di Nino) ---------------------------------

func fishing_gear_level(gear: int) -> int:
	return fishing_gear.get(gear, 0)


func fishing_gear_max_level(gear: int) -> int:
	return FISHING_GEAR_COSTS[gear].size()


## Costo del prossimo livello; -1 se già al massimo.
func fishing_gear_cost(gear: int) -> int:
	var costs: Array = FISHING_GEAR_COSTS[gear]
	var level := fishing_gear_level(gear)
	if level >= costs.size():
		return -1
	return costs[level]


func buy_fishing_gear(gear: int) -> bool:
	var cost := fishing_gear_cost(gear)
	if cost < 0 or money < cost:
		return false
	money -= cost
	fishing_gear[gear] = fishing_gear_level(gear) + 1
	money_changed.emit(money)
	post_notice("%s livello %d" % [FISHING_GEAR_NAME[gear], fishing_gear_level(gear)])
	save_game()
	return true


## Effetti dell'attrezzatura, letti da FishingZone. Un valore per livello
## posseduto (indice clampato alla curva, così un save con livelli fuori
## scala non esplode).
func fishing_window_bonus() -> float:
	return _gear_curve(FISHING_ROD_WINDOW_BONUS, FishingGear.ROD)


func fishing_reel_time_mult() -> float:
	return _gear_curve(FISHING_REEL_TIME_MULT, FishingGear.REEL)


func fishing_reel_rise_mult() -> float:
	return _gear_curve(FISHING_REEL_RISE_MULT, FishingGear.REEL)


func fishing_snap_grace() -> float:
	return FISH_SNAP_GRACE + _gear_curve(FISHING_LINE_GRACE_BONUS, FishingGear.LINE)


func fishing_surge_mult() -> float:
	return _gear_curve(FISHING_LINE_SURGE_MULT, FishingGear.LINE)


func _gear_curve(curve: Array[float], gear: int) -> float:
	return curve[clampi(fishing_gear_level(gear), 0, curve.size() - 1)]


# --- Radar (missione del nipote) ---------------------------------------------

func radar_upgrade_level(upgrade: int) -> int:
	return radar_upgrades.get(upgrade, 0)


func radar_upgrade_max_level(upgrade: int) -> int:
	return RADAR_UPGRADE_COSTS[upgrade].size()


## Costo del prossimo livello; -1 se già al massimo.
func radar_upgrade_cost(upgrade: int) -> int:
	var costs: Array = RADAR_UPGRADE_COSTS[upgrade]
	var level := radar_upgrade_level(upgrade)
	if level >= costs.size():
		return -1
	return costs[level]


func buy_radar_upgrade(upgrade: int) -> bool:
	var cost := radar_upgrade_cost(upgrade)
	if cost < 0 or money < cost:
		return false
	money -= cost
	radar_upgrades[upgrade] = radar_upgrade_level(upgrade) + 1
	money_changed.emit(money)
	post_notice("%s livello %d" % [RADAR_UPGRADE_NAME[upgrade], radar_upgrade_level(upgrade)])
	save_game()
	return true


## Raggio di rilevazione (frazione di bounds_depth) e durata della finestra,
## dal livello dei rispettivi potenziamenti (indice clampato alla curva).
func radar_range_fraction() -> float:
	return RADAR_RANGE_FRACTION[clampi(radar_upgrade_level(RadarUpgrade.RANGE), 0,
		RADAR_RANGE_FRACTION.size() - 1)]


func radar_duration() -> float:
	return RADAR_DURATION[clampi(radar_upgrade_level(RadarUpgrade.DURATION), 0,
		RADAR_DURATION.size() - 1)]


## Secondi di cooldown correnti dell'impulso, dal livello di "Condensatori".
func radar_cooldown() -> float:
	return RADAR_COOLDOWN_STEPS[clampi(radar_upgrade_level(RadarUpgrade.COOLDOWN), 0,
		RADAR_COOLDOWN_STEPS.size() - 1)]


# --- Cannone di bordo (roadmap B1) --------------------------------------------

func cannon_owned() -> bool:
	return cannon_level > 0


## Definizione del cannone corrente; null se non ancora comprato.
func cannon_def() -> WeaponDefinition:
	if cannon_level <= 0:
		return null
	return CANNON_DEFS[clampi(cannon_level - 1, 0, CANNON_DEFS.size() - 1)]


## Costo del prossimo livello; -1 se già al massimo.
func cannon_cost() -> int:
	if cannon_level >= CANNON_DEFS.size():
		return -1
	return CANNON_DEFS[cannon_level].price


func buy_cannon() -> bool:
	var cost := cannon_cost()
	if cost < 0 or money < cost:
		return false
	money -= cost
	cannon_level += 1
	money_changed.emit(money)
	if cannon_level == 1:
		post_notice("Cannone a bordo! Mira col mouse, spara col tasto sinistro")
	else:
		post_notice("%s installato" % cannon_def().display_name)
	cannon_changed.emit()
	save_game()
	return true


## Chi spara (barca o predone) lo annuncia da qui: l'audio fa il boato.
func report_cannon_fired() -> void:
	cannon_fired.emit()


func report_ship_hit(position: Vector3) -> void:
	ship_hit.emit(position)


func report_ship_sunk(position: Vector3) -> void:
	ship_sunk.emit(position)


# --- Customizzazione estetica (roadmap A2) -----------------------------------

func paint_def(id: StringName) -> Dictionary:
	for paint in PAINTS:
		if paint["id"] == id:
			return paint
	return PAINTS[0]


func accessory_def(id: StringName) -> Dictionary:
	for accessory in ACCESSORIES:
		if accessory["id"] == id:
			return accessory
	return ACCESSORIES[0]


func owns_paint(id: StringName, boat_id: StringName = current_boat_id) -> bool:
	if id == PAINT_ORIGINAL:
		return true
	return paints_owned.get(boat_id, []).has(id)


func applied_paint(boat_id: StringName = current_boat_id) -> StringName:
	return paint_applied.get(boat_id, PAINT_ORIGINAL)


## La vernice da mostrare adesso sulla barca corrente: l'anteprima del
## cantiere vince su quella applicata.
func effective_paint() -> Dictionary:
	if paint_preview != &"":
		return paint_def(paint_preview)
	return paint_def(applied_paint())


func boat_accessories(boat_id: StringName = current_boat_id) -> Array:
	return accessories_owned.get(boat_id, [])


func owns_accessory(id: StringName, boat_id: StringName = current_boat_id) -> bool:
	return boat_accessories(boat_id).has(id)


## Acquisto e applicazione in un gesto: la vernice resta posseduta per
## questa barca, ricambiarla in seguito è gratis.
func buy_paint(id: StringName) -> bool:
	var paint := paint_def(id)
	if owns_paint(id) or money < int(paint["price"]):
		return false
	money -= int(paint["price"])
	var owned: Array = paints_owned.get(current_boat_id, [])
	owned.append(id)
	paints_owned[current_boat_id] = owned
	money_changed.emit(money)
	post_notice("%s: nuova mano di vernice" % String(paint["name"]))
	apply_paint(id)
	return true


func apply_paint(id: StringName) -> void:
	if not owns_paint(id):
		return
	if id == PAINT_ORIGINAL:
		paint_applied.erase(current_boat_id)
	else:
		paint_applied[current_boat_id] = id
	paint_preview = &""
	customization_changed.emit()
	save_game()


func buy_accessory(id: StringName) -> bool:
	var accessory := accessory_def(id)
	if owns_accessory(id) or money < int(accessory["price"]):
		return false
	money -= int(accessory["price"])
	var owned: Array = accessories_owned.get(current_boat_id, [])
	owned.append(id)
	accessories_owned[current_boat_id] = owned
	money_changed.emit(money)
	post_notice("%s: a bordo!" % String(accessory["name"]))
	customization_changed.emit()
	save_game()
	return true


## Anteprima live dal cantiere (roadmap A2): la barca attraccata si
## ridipinge subito, senza pagare; si azzera chiudendo il pannello.
func set_paint_preview(id: StringName) -> void:
	if paint_preview == id:
		return
	paint_preview = id
	customization_changed.emit()


func clear_paint_preview() -> void:
	if paint_preview == &"":
		return
	paint_preview = &""
	customization_changed.emit()


# --- Missione del nipote in mare ---------------------------------------------

## Avanza la missione e la salva (le transizioni le decide l'NPC/il nipote).
func set_grandson_quest(state: int) -> void:
	if grandson_quest == state:
		return
	grandson_quest = state
	if state == GrandsonQuest.DONE:
		radar_unlocked = true
	save_game()


# --- Reputazione (roadmap A1) ------------------------------------------------

func reputation_value(faction: StringName = FACTION_BOVA) -> int:
	return reputation.get(faction, 0)


func add_reputation(delta: int, faction: StringName = FACTION_BOVA) -> void:
	if delta == 0:
		return
	var value := clampi(reputation_value(faction) + delta, REP_MIN, REP_MAX)
	reputation[faction] = value
	reputation_changed.emit(faction, value)


## Moltiplicatore dei prezzi dei servizi di porto (riparazione e
## rifornimento): reputazione alta sconta, bassa rincara, ±15% a fondo scala.
func price_multiplier(faction: StringName = FACTION_BOVA) -> float:
	return 1.0 - REP_PRICE_EFFECT * float(reputation_value(faction)) / float(REP_MAX)


# --- Missioni della bacheca (roadmap A1) -------------------------------------

func mission_active() -> bool:
	return not active_mission.is_empty()


## Casse missione in stiva: occupano capacità ma non si vendono (item
## MISSION_CRATE_ITEM nell'inventario unico).
func mission_crate_count() -> int:
	return item_count(MISSION_CRATE_ITEM)


## Tipo della missione attiva, -1 se nessuna.
func mission_type() -> int:
	return int(active_mission.get("type", -1))


## Vero se il pacco della missione di recupero è ancora in acqua.
func mission_pickup_pending() -> bool:
	return mission_type() == MissionType.RECOVERY \
		and not bool(active_mission.get("recovered", false))


## Dove punta il marker in minimappa: il punto del pacco (o l'approdo di
## consegna) finché c'è da andare, il porto del rientro a pacco raccolto.
func mission_marker_position() -> Vector3:
	if mission_type() == MissionType.RECOVERY and bool(active_mission.get("recovered", false)):
		return active_mission.get("return", Vector3.ZERO)
	return active_mission.get("target", Vector3.ZERO)


## Riga di stato per l'HUD (pannello obiettivo, dopo il tutorial).
func mission_status_text() -> String:
	match mission_type():
		MissionType.DELIVERY:
			var left := maxf(mission_time_left, 0.0)
			return "Consegna: %d casse a %s · %d:%02d" % [
				mission_crate_count(), active_mission.get("target_name", "?"),
				int(left) / 60, int(left) % 60,
			]
		MissionType.RECOVERY:
			if bool(active_mission.get("recovered", false)):
				return "Recupero: riporta il pacco al porto"
			return "Recupero: raggiungi il punto segnato in minimappa"
		MissionType.NPC_FETCH:
			return "Incarico di %s: %s" % [
				str(active_mission.get("npc_name", "?")), npc_needs_text(),
			]
	return ""


## Dati strutturati delle missioni attive per il tracker HUD (roadmap R2):
## una lista (oggi 0 o 1 voce) già pronta per le missioni NPC di R5. Ogni
## voce: titolo, tappa corrente, progresso "n/N" leggibile e countdown in
## secondi (< 0 = nessun limite di tempo).
func active_missions() -> Array[Dictionary]:
	if not mission_active():
		return []
	match mission_type():
		MissionType.DELIVERY:
			return [{
				"title": str(active_mission.get("title", "Consegna")),
				"stage": "Consegna a %s" % active_mission.get("target_name", "?"),
				"progress": "%d casse a bordo" % mission_crate_count(),
				"countdown": maxf(mission_time_left, 0.0),
			}]
		MissionType.RECOVERY:
			var recovered := bool(active_mission.get("recovered", false))
			return [{
				"title": str(active_mission.get("title", "Recupero")),
				"stage": "Riporta il pacco al porto" if recovered \
					else "Raggiungi il punto in mappa",
				"progress": "2/2 · pacco a bordo" if recovered \
					else "1/2 · pacco in acqua",
				"countdown": -1.0,
			}]
		MissionType.NPC_FETCH:
			var p := npc_needs_progress()
			return [{
				"title": str(active_mission.get("title", "Incarico")),
				"stage": "Porta tutto a %s" % str(active_mission.get("npc_name", "?")),
				"progress": "%d/%d · %s" % [p.x, p.y, npc_needs_text()],
				"countdown": -1.0,
			}]
	return []


## Genera le offerte della bacheca: una consegna verso l'approdo e due
## recuperi (acque medie e mare aperto). Ricompense scalate su distanza e
## fascia (GDD pillar 2). Le offerte non si salvano: si rigenerano a ogni
## apertura della bacheca.
func generate_mission_offers(world: World) -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	var delivery := _delivery_offer(world, randi_range(1, 3))
	if not delivery.is_empty():
		offers.append(delivery)
	var sea := world.sea
	var near := _recovery_offer(world, sea.calm_width + 10.0, sea.medium_width - 10.0)
	if not near.is_empty():
		offers.append(near)
	var far := _recovery_offer(world, sea.medium_width + 40.0, world.bay_depth - 80.0)
	if not far.is_empty():
		offers.append(far)
	return offers


func _delivery_offer(world: World, crates: int) -> Dictionary:
	var landing := world.delivery_landing()
	if landing == null:
		return {}
	var target := landing.global_position
	var dist := world.port_position().distance_to(target)
	var time_limit := dist / MISSION_DELIVERY_SPEED + MISSION_DELIVERY_TIME_BUFFER
	return {
		"type": MissionType.DELIVERY,
		"title": "Consegna: %d casse" % crates,
		"desc": "Porta %d casse a %s entro %d:%02d. Occupano %d posti di stiva." % [
			crates, landing.map_label, int(time_limit) / 60, int(time_limit) % 60, crates,
		],
		"crates": crates,
		"time_limit": time_limit,
		"target": target,
		"target_name": landing.map_label,
		"reward": roundi(crates * MISSION_REWARD_PER_CRATE + dist * MISSION_DELIVERY_REWARD_PER_METER),
		"rep": MISSION_REP_REWARD,
	}


func _recovery_offer(world: World, d_min: float, d_max: float) -> Dictionary:
	var point := world.sample_mission_point(d_min, d_max)
	if not point.is_finite():
		return {}
	var dist := world.port_position().distance_to(point)
	var zone := world.sea.zone_index(point)
	var zone_name: String = ["nelle acque medie", "nelle acque medie", "in mare aperto"][zone]
	return {
		"type": MissionType.RECOVERY,
		"title": "Recupero %s" % zone_name,
		"desc": "Un carico è andato perso %s: raggiungi il punto segnato in minimappa, raccogli il pacco e riportalo al porto." % zone_name,
		"target": point,
		"return": world.port_position(),
		"reward": roundi((MISSION_RECOVERY_BASE + dist * MISSION_RECOVERY_REWARD_PER_METER)
			* MISSION_ZONE_MULT[zone]),
		"rep": MISSION_REP_REWARD,
	}


## Falso se c'è già una missione o se la stiva non ha posto per le casse
## (roadmap A1: si sceglie se rinunciare al pescato).
func accept_mission(offer: Dictionary) -> bool:
	if mission_active():
		return false
	if int(offer.get("type", -1)) == MissionType.DELIVERY:
		var crates := int(offer.get("crates", 0))
		if cargo_count() + crates > cargo_capacity():
			post_notice("Stiva insufficiente: servono %d posti liberi per le casse" % crates)
			return false
		_set_item(MISSION_CRATE_ITEM, crates)
		mission_time_left = float(offer.get("time_limit", 0.0))
	active_mission = offer.duplicate()
	active_mission["recovered"] = false
	cargo_changed.emit()
	mission_changed.emit()
	post_notice("Missione accettata: %s" % str(offer.get("title", "")))
	save_game()
	return true


## Pacco di recupero raccolto in acqua (chiamato dal MissionPickup): il
## marker torna sul porto del rientro.
func mission_pickup_collected() -> void:
	if not mission_pickup_pending():
		return
	active_mission["recovered"] = true
	mission_changed.emit()
	post_notice("Pacco a bordo! Riportalo al porto (marker in minimappa)")
	save_game()


## Chiusura automatica all'attracco: le casse all'approdo di consegna, il
## pacco recuperato al porto principale. Vero se una missione si è chiusa.
func try_complete_mission_at_port(is_delivery_target: bool) -> bool:
	if not mission_active():
		return false
	match mission_type():
		MissionType.DELIVERY:
			if not is_delivery_target:
				return false
			_finish_mission("Casse consegnate")
			return true
		MissionType.RECOVERY:
			if is_delivery_target or not bool(active_mission.get("recovered", false)):
				return false
			_finish_mission("Pacco riconsegnato")
			return true
	return false


func _finish_mission(what: String) -> void:
	var reward := int(active_mission.get("reward", 0))
	var rep := int(active_mission.get("rep", 0))
	money += reward
	total_earned += reward
	add_reputation(rep)
	_set_item(MISSION_CRATE_ITEM, 0)
	active_mission.clear()
	mission_time_left = 0.0
	money_changed.emit(money)
	cargo_changed.emit()
	cargo_sold.emit(reward)
	mission_changed.emit()
	mission_completed.emit(what, reward)
	post_notice("%s: +%d $ · reputazione +%d" % [what, reward, rep])
	save_game()


## Fallimento (tempo scaduto, affondamento): casse perse e reputazione giù.
func fail_mission(reason: String) -> void:
	if not mission_active():
		return
	_set_item(MISSION_CRATE_ITEM, 0)
	active_mission.clear()
	mission_time_left = 0.0
	add_reputation(MISSION_REP_FAIL)
	cargo_changed.emit()
	mission_changed.emit()
	post_notice("%s · reputazione %d" % [reason, MISSION_REP_FAIL])
	save_game()


## Abbandono volontario dalla bacheca: penalità più leggera del fallimento.
func abandon_mission() -> void:
	if not mission_active():
		return
	_set_item(MISSION_CRATE_ITEM, 0)
	active_mission.clear()
	mission_time_left = 0.0
	add_reputation(MISSION_REP_ABANDON)
	cargo_changed.emit()
	mission_changed.emit()
	post_notice("Missione abbandonata · reputazione %d" % MISSION_REP_ABANDON)
	save_game()


# --- Incarichi dei datori NPC a terra (roadmap R7) ----------------------------

## Id degli incarichi NPC già consegnati (in world_state: si salvano col
## mondo e si azzerano con la nuova partita).
func npc_missions_done() -> Array:
	return world_state.get("npc_done", [])


## Offerte ancora aperte di un datore: il catalogo scritto a mano meno gli
## incarichi già consegnati. L'incarico attivo resta fuori dalla lista (lo
## mostra il dialogo come "in corso", non come offerta).
func npc_offers(npc_id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var active_id := str(active_mission.get("id", ""))
	for offer: Dictionary in NPC_MISSIONS.get(npc_id, []):
		var id := str(offer.get("id", ""))
		if not npc_missions_done().has(id) and id != active_id:
			out.append(offer)
	return out


## Accetta un incarico NPC: diventa la missione attiva (una alla volta,
## come la bacheca — decisione direttore 23/07/2026).
func accept_npc_mission(npc_id: StringName, npc_name: String, offer: Dictionary) -> bool:
	if mission_active():
		return false
	active_mission = offer.duplicate(true)
	active_mission["type"] = MissionType.NPC_FETCH
	active_mission["npc_id"] = String(npc_id)
	active_mission["npc_name"] = npc_name
	mission_changed.emit()
	post_notice("Incarico accettato: %s" % str(offer.get("title", "")))
	save_game()
	return true


## La richiesta dell'incarico attivo (id item → quantità). Le quantità
## passano dal round-trip JSON: sempre int() a leggerle.
func npc_needs() -> Dictionary:
	return active_mission.get("needs", {})


## Progresso della raccolta: x = pezzi in stiva (contati fino al richiesto),
## y = pezzi totali richiesti.
func npc_needs_progress() -> Vector2i:
	var have := 0
	var total := 0
	var needs := npc_needs()
	for id: String in needs:
		var need := int(needs[id])
		total += need
		have += mini(item_count(StringName(id)), need)
	return Vector2i(have, total)


func npc_needs_met() -> bool:
	var p := npc_needs_progress()
	return p.y > 0 and p.x >= p.y


## La richiesta leggibile, coi conti aggiornati: "2/3 legno · 0/2 ferro".
func npc_needs_text() -> String:
	var parts: PackedStringArray = []
	var needs := npc_needs()
	for id: String in needs:
		var def := item_def(StringName(id))
		var item_name := def.display_name if def != null else id
		parts.append("%d/%d %s" % [
			mini(item_count(StringName(id)), int(needs[id])), int(needs[id]), item_name,
		])
	return " · ".join(parts)


## Consegna al datore: consuma gli item richiesti, paga denaro e reputazione,
## regala l'eventuale item promesso e spunta l'incarico per sempre. Falso se
## l'incarico attivo non è suo o manca ancora roba.
func deliver_npc_mission(npc_id: StringName) -> bool:
	if mission_type() != MissionType.NPC_FETCH \
			or str(active_mission.get("npc_id", "")) != String(npc_id) \
			or not npc_needs_met():
		return false
	var needs := npc_needs()
	for id: String in needs:
		_set_item(StringName(id), item_count(StringName(id)) - int(needs[id]))
	var reward := int(active_mission.get("reward", 0))
	var rep := int(active_mission.get("rep", 0))
	var gift := str(active_mission.get("reward_item", ""))
	var title := str(active_mission.get("title", ""))
	money += reward
	total_earned += reward
	add_reputation(rep)
	# Il regalo entra anche a stiva piena: un dono non si rifiuta.
	if gift != "":
		_add_item(StringName(gift))
	var done: Array = npc_missions_done()
	done.append(str(active_mission.get("id", "")))
	world_state["npc_done"] = done
	active_mission.clear()
	money_changed.emit(money)
	cargo_changed.emit()
	cargo_sold.emit(reward)
	mission_changed.emit()
	mission_completed.emit(title, reward)
	if gift != "":
		item_collected.emit(StringName(gift))
	post_notice("%s: +%d $ · reputazione +%d" % [title, reward, rep])
	save_game()
	return true


# --- Eventi casuali (roadmap A1) ---------------------------------------------

## Applica le conseguenze di una scelta d'evento: denaro, carburante,
## scafo, reputazione. Un dialogo non affonda mai la barca (EVENT_MIN_HULL)
## e non manda mai il denaro sotto zero: l'accessibilità della scelta la
## verifica il pannello prima di proporla.
func apply_event_choice(money_delta: int, fuel_delta: float, hull_delta: float, rep_delta: int) -> void:
	if money_delta != 0:
		money = maxi(money + money_delta, 0)
		if money_delta > 0:
			total_earned += money_delta
		money_changed.emit(money)
	if fuel_delta > 0.0:
		add_fuel(fuel_delta)
	elif fuel_delta < 0.0:
		fuel = maxf(fuel + fuel_delta, 0.0)
		fuel_changed.emit(fuel, fuel_capacity())
	if hull_delta > 0.0:
		hull = minf(hull + hull_delta, hull_max())
		hull_changed.emit(hull, hull_max())
	elif hull_delta < 0.0:
		hull = maxf(hull + hull_delta, minf(hull, EVENT_MIN_HULL))
		hull_changed.emit(hull, hull_max())
	add_reputation(rep_delta)
	save_game()


# --- Catalogo item (roadmap R4) ----------------------------------------------

func _build_item_index() -> void:
	for def in ITEM_DEFS:
		_item_by_id[def.id] = def


## Definizione di un item dal suo id; null se sconosciuto (salvataggio con un
## item rimosso dal catalogo: il conteggio resta ma non lo si vende/mostra).
func item_def(id: StringName) -> ItemDefinition:
	return _item_by_id.get(id, null)


## Definizione dell'item corrispondente a un tipo di gameplay (comodo per chi
## ragiona ancora per enum: boe in World, pesci nella pesca, bottino dai relitti).
func buoy_item(type: int) -> ItemDefinition:
	return item_def(BUOY_ITEM[type])


func fish_item(type: int) -> ItemDefinition:
	return item_def(FISH_ITEM[type])


func loot_item(tier: int) -> ItemDefinition:
	return item_def(LOOT_ITEM[clampi(tier, 0, 2)])


func item_count(id: StringName) -> int:
	return inventory.get(id, 0)


## Aggiunge quantità a un item (nessun controllo di capacità: lo fa il
## chiamante di raccolta, che sa dare il feedback giusto).
func _add_item(id: StringName, amount: int = 1) -> void:
	inventory[id] = inventory.get(id, 0) + amount


## Fissa la quantità di un item; 0 o meno lo toglie dalla stiva.
func _set_item(id: StringName, amount: int) -> void:
	if amount <= 0:
		inventory.erase(id)
	else:
		inventory[id] = amount


## Toglie dalla stiva tutti gli item vendibili (vendita al porto,
## affondamento): le casse missione e le merci non vendibili restano.
func _clear_sellable() -> void:
	for def in ITEM_DEFS:
		if def.sellable:
			inventory.erase(def.id)


# --- Stiva e denaro ----------------------------------------------------------

## Falso se la stiva è piena: la boa resta in acqua (il limite di stiva
## è il senso dell'upgrade omonimo).
func collect_buoy(type: int) -> bool:
	if cargo_count() >= cargo_capacity():
		post_notice("Stiva piena! Vendi al porto")
		return false
	_add_item(BUOY_ITEM[type])
	if type == BuoyType.BLUE:
		post_notice("Boa blu! Rarissima: +%d $ di carico" % buoy_item(type).base_value)
	cargo_changed.emit()
	buoy_collected.emit(type)
	if tutorial_step == TUTORIAL_COLLECT and cargo_count() >= TUTORIAL_BUOY_GOAL:
		_advance_tutorial(TUTORIAL_COLLECT)
	return true


## Falso a stiva piena, come per le boe: il pesce resta in acqua.
func collect_fish(type: int) -> bool:
	if cargo_count() >= cargo_capacity():
		post_notice("Stiva piena! Vendi al porto")
		return false
	_add_item(FISH_ITEM[type])
	fish_caught_total += 1
	cargo_changed.emit()
	fish_caught.emit(type)
	_advance_tutorial(TUTORIAL_EXPLORE)
	return true


## Falso a stiva piena, come per le boe: il bottino resta a galla.
func collect_loot(tier: int) -> bool:
	if cargo_count() >= cargo_capacity():
		post_notice("Stiva piena! Vendi al porto")
		return false
	tier = clampi(tier, 0, 2)
	_add_item(LOOT_ITEM[tier])
	cargo_changed.emit()
	loot_collected.emit(tier)
	return true


## Raccolta generica per id (roadmap R6): merci e tesori da relitti, prede
## e pesca speciale. Falso a stiva piena o id sconosciuto, come le boe.
func collect_item(id: StringName) -> bool:
	if item_def(id) == null:
		push_error("Item sconosciuto: %s" % id)
		return false
	if cargo_count() >= cargo_capacity():
		post_notice("Stiva piena! Vendi al porto")
		return false
	_add_item(id)
	cargo_changed.emit()
	item_collected.emit(id)
	return true


## Estrazione a peso da un dizionario id -> peso (tesori di relitti e
## pesca). Usa il RNG globale: la varietà qui è il punto, non la ripetibilità.
func pick_weighted_item(weights: Dictionary[StringName, int]) -> StringName:
	var total := 0
	for id in weights:
		total += weights[id]
	var roll := randi_range(1, maxi(total, 1))
	for id in weights:
		roll -= weights[id]
		if roll <= 0:
			return id
	return weights.keys()[0]


## Probabilità che una cattura in zona tier 2 tiri su un tesoro (roadmap
## R6): zero al margine delle acque medie, sale col fattore difficoltà del
## punto fino a FISHING_TREASURE_CHANCE_MAX al largo e in tempesta.
func fishing_treasure_chance(world_pos: Vector3, sea: Sea) -> float:
	var t := (difficulty_multiplier(world_pos, sea) - 1.0) / (DIFFICULTY_REWARD_MAX - 1.0)
	return FISHING_TREASURE_CHANCE_MAX * clampf(t, 0.0, 1.0)


## L'id della merce che una preda molla in una cassa (roadmap R6): le navi
## delle città portano (spesso) la merce tipica di casa, per il resto si
## pesca dal pool della nave. &"" se la nave non ha merci da mollare.
func ship_goods_item(faction: StringName, pool: Array[StringName]) -> StringName:
	var typical: StringName = FACTION_GOODS.get(faction, &"")
	if typical != &"" and (pool.is_empty() or randf() < SHIP_FACTION_GOOD_WEIGHT):
		return typical
	if pool.is_empty():
		return &""
	return pool[randi() % pool.size()]


## Fattore ricompensa per acque difficili in un punto (roadmap R3): 1.0
## sotto costa e col mare calmo, cresce con la distanza dalla costa e con
## l'agitazione locale, fino a DIFFICULTY_REWARD_MAX. Chi assegna premi a
## posizione nota (bottino delle prede, regate al largo) ci scala sopra.
func difficulty_multiplier(world_pos: Vector3, sea: Sea) -> float:
	if sea == null:
		return 1.0
	var span := maxf(DIFFICULTY_REWARD_FULL_DISTANCE - sea.medium_width, 1.0)
	var dist01 := clampf((sea.shore_distance(world_pos) - sea.medium_width) / span, 0.0, 1.0)
	var agit_span := maxf(DIFFICULTY_AGITATION_ROUGH - DIFFICULTY_AGITATION_CALM, 0.01)
	var agit01 := clampf((sea.agitation(world_pos) - DIFFICULTY_AGITATION_CALM) / agit_span, 0.0, 1.0)
	var bonus := DIFFICULTY_REWARD_DISTANCE_WEIGHT * dist01 \
		+ DIFFICULTY_REWARD_AGITATION_WEIGHT * agit01
	return 1.0 + bonus * (DIFFICULTY_REWARD_MAX - 1.0)


## Include le casse missione e ogni item non vendibile: occupano stiva.
func cargo_count() -> int:
	var total := 0
	for id in inventory:
		total += inventory[id]
	return total


## Vale solo l'inventario vendibile: casse missione e merci non vendibili
## occupano stiva ma non contano al porto.
func cargo_value() -> int:
	var total := 0
	for id: StringName in inventory:
		var def := item_def(id)
		if def != null and def.sellable:
			total += inventory[id] * def.base_value
	return total


## Dettaglio stiva in BBCode ("2× boe gialle · 1× tonno"), condiviso da HUD
## e pannello del porto: cosa hai raccolto si capisce a colpo d'occhio. Segue
## l'ordine del catalogo; le casse missione portano il suffisso "(missione)".
func cargo_detail_bbcode() -> String:
	var parts: Array[String] = []
	for def in ITEM_DEFS:
		var count := item_count(def.id)
		if count <= 0:
			continue
		var label := def.name_for_count(count)
		if def.category == ItemDefinition.Category.MISSION:
			label += " (missione)"
		parts.append("[color=#%s]%d× %s[/color]" % [def.color.to_html(false), count, label])
	return " · ".join(parts)


func sell_cargo() -> int:
	var earned := cargo_value()
	if earned <= 0:
		return 0
	money += earned
	total_earned += earned
	_clear_sellable()
	money_changed.emit(money)
	cargo_changed.emit()
	cargo_sold.emit(earned)
	post_notice("Carico venduto: +%d $" % earned)
	_advance_tutorial(TUTORIAL_SELL)
	return earned


## La reputazione sconta o rincara riparazione e rifornimento (roadmap A1).
func repair_cost() -> int:
	return ceili((hull_max() - hull) * REPAIR_COST_PER_POINT * price_multiplier())


func repair_hull() -> void:
	var missing := hull_max() - hull
	if missing <= 0.0 or money <= 0:
		return
	var full_cost := repair_cost()
	if money >= full_cost:
		money -= full_cost
		hull = hull_max()
	else:
		hull += float(money) / (REPAIR_COST_PER_POINT * price_multiplier())
		money = 0
	money_changed.emit(money)
	hull_changed.emit(hull, hull_max())


# --- Regata ------------------------------------------------------------------

## Tier della barca: il suo indice nell'ordine di progressione BOAT_DEFS.
func boat_tier(id: StringName = current_boat_id) -> int:
	for i in BOAT_DEFS.size():
		if BOAT_DEFS[i].id == id:
			return i
	return 0


## Premio per piazzamento, scalato col tier della barca corrente
## (feedback playtest M3) e col moltiplicatore dello spot (feedback round
## 2: la gara al largo paga di più).
func race_prize(rank: int, prize_mult: float = 1.0) -> int:
	if rank - 1 >= RACE_PRIZES.size():
		return 0
	return roundi(RACE_PRIZES[rank - 1] * RACE_PRIZE_TIER_MULT[boat_tier()] * prize_mult)


## Piazzamento a fine gara: accredita il premio e conta le vittorie
## (la prima sblocca il Cabinato in cantiere). prize_mult è il bonus dello
## spot (1.0 sotto costa, più alto al largo).
func record_race_result(rank: int, total: int, prize_mult: float = 1.0) -> void:
	var prize := race_prize(rank, prize_mult)
	if prize > 0:
		money += prize
		total_earned += prize
		money_changed.emit(money)
	if rank == 1:
		race_wins += 1
		if race_wins == 1:
			post_notice("Prima vittoria! Il Cabinato è sbloccato in cantiere")
		else:
			post_notice("Regata vinta: +%d $" % prize)
	else:
		post_notice("Regata: %d° su %d (+%d $)" % [rank, total, prize])
	_advance_tutorial(TUTORIAL_EXPLORE)
	save_game()


# --- Carburante --------------------------------------------------------------

func consume_fuel(amount: float) -> void:
	if fuel <= 0.0 or amount <= 0.0:
		return
	fuel = maxf(fuel - amount, 0.0)
	fuel_changed.emit(fuel, fuel_capacity())
	if fuel <= 0.0:
		post_notice("Serbatoio vuoto! Vai in riserva d'emergenza: torna al porto")


## Tanica trovata in mare (o rifornimento parziale): non oltre il pieno.
func add_fuel(amount: float) -> void:
	if amount <= 0.0:
		return
	fuel = minf(fuel + amount, fuel_capacity())
	fuel_changed.emit(fuel, fuel_capacity())


## Anche il pieno segue la reputazione (vedi repair_cost).
func refuel_cost() -> int:
	return ceili((fuel_capacity() - fuel) * FUEL_PRICE_PER_LITER * price_multiplier())


## Pieno al porto; se i soldi non bastano si riempie quel che si può.
func refuel() -> void:
	var missing := fuel_capacity() - fuel
	if missing <= 0.0 or money <= 0:
		return
	var full_cost := refuel_cost()
	if money >= full_cost:
		money -= full_cost
		fuel = fuel_capacity()
	else:
		fuel += float(money) / (FUEL_PRICE_PER_LITER * price_multiplier())
		money = 0
	money_changed.emit(money)
	fuel_changed.emit(fuel, fuel_capacity())


func apply_damage(amount: float) -> void:
	if hull <= 0.0 or amount <= 0.0:
		return
	hull = maxf(hull - amount, 0.0)
	hull_changed.emit(hull, hull_max())
	if hull <= 0.0:
		hull_depleted.emit()


func pay_tow() -> void:
	money = maxi(money - TOW_FEE, 0)
	hull = TOW_HULL_RESTORE
	money_changed.emit(money)
	hull_changed.emit(hull, hull_max())
	post_notice("Scafo a pezzi: rimorchiato al porto (-%d $)" % TOW_FEE)


## Affondamento al largo (feedback playtest M3): il carico va perso e il
## recupero costa più del traino. Chiamato dal World a barca già in porto.
func salvage_after_sinking() -> void:
	var lost := cargo_value()
	_clear_sellable()
	money = maxi(money - SALVAGE_FEE, 0)
	hull = TOW_HULL_RESTORE
	money_changed.emit(money)
	hull_changed.emit(hull, hull_max())
	cargo_changed.emit()
	if lost > 0:
		post_notice("Affondato! Carico perso (%d $) · recupero -%d $" % [lost, SALVAGE_FEE])
	else:
		post_notice("Affondato! Recupero al porto -%d $" % SALVAGE_FEE)
	# Il mare si prende anche casse e pacco della missione attiva. Gli
	# incarichi NPC invece restano: la richiesta del datore non affonda,
	# si riparte a raccogliere (roadmap R7).
	if mission_active() and mission_type() != MissionType.NPC_FETCH:
		fail_mission("Missione persa in mare")
	save_game()


# --- Salvataggio -------------------------------------------------------------

## Forma di partenza del world_state: Bova povera, nessuna difesa,
## nessun edificio e magazzino vuoto (le regole vivono nell'autoload Town).
func _default_world_state() -> Dictionary:
	return {
		"bova_prosperity": 0,
		"prosperity_points": 0,
		"buildings": {},
		"warehouse": {},
		"defenses": [],
		"npc_done": [],
	}


func save_game() -> void:
	var inventory_out: Dictionary = {}
	for id in inventory:
		inventory_out[String(id)] = inventory[id]
	var upgrades_out: Dictionary = {}
	for boat_id in upgrades:
		var levels: Dictionary = {}
		for type in upgrades[boat_id]:
			levels[str(type)] = upgrades[boat_id][type]
		upgrades_out[String(boat_id)] = levels
	var owned_out: Array[String] = []
	for id in owned_boats:
		owned_out.append(String(id))
	var gear_out: Dictionary = {}
	for gear in fishing_gear:
		gear_out[str(gear)] = fishing_gear[gear]
	var radar_out: Dictionary = {}
	for upgrade in radar_upgrades:
		radar_out[str(upgrade)] = radar_upgrades[upgrade]
	var rep_out: Dictionary = {}
	for faction in reputation:
		rep_out[String(faction)] = reputation[faction]
	var paints_out: Dictionary = {}
	for boat_id in paints_owned:
		var ids: Array[String] = []
		for paint_id: StringName in paints_owned[boat_id]:
			ids.append(String(paint_id))
		paints_out[String(boat_id)] = ids
	var applied_out: Dictionary = {}
	for boat_id in paint_applied:
		applied_out[String(boat_id)] = String(paint_applied[boat_id])
	var accessories_out: Dictionary = {}
	for boat_id in accessories_owned:
		var ids: Array[String] = []
		for accessory_id: StringName in accessories_owned[boat_id]:
			ids.append(String(accessory_id))
		accessories_out[String(boat_id)] = ids
	# I Vector3 della missione (target/return) diventano array [x, y, z]:
	# JSON non li rappresenta.
	var mission_out: Dictionary = {}
	for key: String in active_mission:
		var value: Variant = active_mission[key]
		mission_out[key] = _vec3_to_array(value) if value is Vector3 else value
	var data := {
		"version": SAVE_VERSION,
		"world_name": world_name,
		"last_played": int(Time.get_unix_time_from_system()),
		"money": money,
		"hull": hull,
		"fuel": fuel,
		"inventory": inventory_out,
		"cannon_level": cannon_level,
		"race_wins": race_wins,
		"tutorial_step": tutorial_step,
		"owned_boats": owned_out,
		"current_boat": String(current_boat_id),
		"upgrades": upgrades_out,
		"fishing_gear": gear_out,
		"grandson_quest": grandson_quest,
		"radar_unlocked": radar_unlocked,
		"radar_upgrades": radar_out,
		"reputation": rep_out,
		"world_state": world_state,
		"mission": mission_out,
		"mission_time_left": mission_time_left,
		"paints_owned": paints_out,
		"paint_applied": applied_out,
		"accessories": accessories_out,
		"play_seconds": play_seconds,
		"total_earned": total_earned,
		"fish_caught_total": fish_caught_total,
		"alpha_end_shown": alpha_end_shown,
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("Salvataggio fallito: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data, "\t"))


## Carica il salvataggio se esiste e non emette segnali: si chiama solo
## all'avvio dell'autoload, prima che le scene si registrino.
func load_game() -> void:
	if not FileAccess.file_exists(save_path):
		hull = hull_max()
		fuel = fuel_capacity()
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	var data: Variant = JSON.parse_string(file.get_as_text())
	if data == null or not data is Dictionary:
		push_error("Salvataggio corrotto, si riparte da zero")
		hull = hull_max()
		fuel = fuel_capacity()
		return
	world_name = str(data.get("world_name", "Bova Marina"))
	money = int(data.get("money", 0))
	race_wins = int(data.get("race_wins", 0))
	# Salvataggi pre-tutorial: chi giocava già conosce le basi, parte da DONE.
	tutorial_step = int(data.get("tutorial_step", TUTORIAL_DONE))
	current_boat_id = StringName(data.get("current_boat", "dinghy"))
	owned_boats.clear()
	for id: String in data.get("owned_boats", ["dinghy"]):
		owned_boats.append(StringName(id))
	if not owns_boat(&"dinghy"):
		owned_boats.append(&"dinghy")
	if not owns_boat(current_boat_id):
		current_boat_id = &"dinghy"
	upgrades.clear()
	var upgrades_in: Dictionary = data.get("upgrades", {})
	for boat_id: String in upgrades_in:
		var levels: Dictionary = {}
		for type: String in upgrades_in[boat_id]:
			levels[int(type)] = int(upgrades_in[boat_id][type])
		upgrades[StringName(boat_id)] = levels
	# Inventario unico (roadmap R4): i salvataggi da R4 in poi hanno la chiave
	# "inventory"; quelli precedenti avevano cargo/fish/loot/mission_crates
	# separati e vi confluiscono (migrazione retrocompatibile).
	inventory.clear()
	if data.has("inventory"):
		var inv_in: Dictionary = data.get("inventory", {})
		for id: String in inv_in:
			_set_item(StringName(id), int(inv_in[id]))
	else:
		_migrate_legacy_cargo(data)
	# Salvataggi pre-B1: niente cannone.
	cannon_level = clampi(int(data.get("cannon_level", 0)), 0, CANNON_DEFS.size())
	fishing_gear.clear()
	var gear_in: Dictionary = data.get("fishing_gear", {})
	for gear: String in gear_in:
		fishing_gear[int(gear)] = int(gear_in[gear])
	# Salvataggi pre-radar: missione non ancora incontrata, radar bloccato.
	grandson_quest = int(data.get("grandson_quest", GrandsonQuest.NONE))
	radar_unlocked = bool(data.get("radar_unlocked", false))
	radar_upgrades.clear()
	var radar_in: Dictionary = data.get("radar_upgrades", {})
	for upgrade: String in radar_in:
		radar_upgrades[int(upgrade)] = int(radar_in[upgrade])
	# Salvataggi pre-A1: reputazione neutra, nessuna missione in corso.
	reputation.clear()
	var rep_in: Dictionary = data.get("reputation", {})
	for faction: String in rep_in:
		reputation[StringName(faction)] = clampi(int(rep_in[faction]), REP_MIN, REP_MAX)
	# Salvataggi pre-B4: le fazioni nuove partono dalla loro relazione
	# iniziale (merge non tocca le chiavi già presenti).
	reputation.merge(FACTION_START_REP)
	# Salvataggi pre-B0: mondo allo stato iniziale. Le chiavi salvate si
	# sovrappongono ai default, così aggiungerne di nuove non li invalida.
	world_state = _default_world_state()
	var ws_in: Dictionary = data.get("world_state", {})
	for key: String in ws_in:
		world_state[key] = ws_in[key]
	world_state["bova_prosperity"] = int(world_state.get("bova_prosperity", 0))
	world_state["prosperity_points"] = int(world_state.get("prosperity_points", 0))
	active_mission.clear()
	var mission_in: Dictionary = data.get("mission", {})
	for key: String in mission_in:
		var value: Variant = mission_in[key]
		active_mission[key] = _array_to_vec3(value) if _is_vec3_array(value) else value
	mission_time_left = float(data.get("mission_time_left", 0.0))
	# Salvataggi pre-A2: nessuna vernice, statistiche da zero.
	paints_owned.clear()
	var paints_in: Dictionary = data.get("paints_owned", {})
	for boat_id: String in paints_in:
		var ids: Array[StringName] = []
		for paint_id: String in paints_in[boat_id]:
			ids.append(StringName(paint_id))
		paints_owned[StringName(boat_id)] = ids
	paint_applied.clear()
	var applied_in: Dictionary = data.get("paint_applied", {})
	for boat_id: String in applied_in:
		paint_applied[StringName(boat_id)] = StringName(applied_in[boat_id])
	accessories_owned.clear()
	var accessories_in: Dictionary = data.get("accessories", {})
	for boat_id: String in accessories_in:
		var ids: Array[StringName] = []
		for accessory_id: String in accessories_in[boat_id]:
			ids.append(StringName(accessory_id))
		accessories_owned[StringName(boat_id)] = ids
	play_seconds = float(data.get("play_seconds", 0.0))
	total_earned = int(data.get("total_earned", 0))
	fish_caught_total = int(data.get("fish_caught_total", 0))
	alpha_end_shown = bool(data.get("alpha_end_shown", false))
	hull = clampf(float(data.get("hull", hull_max())), 0.0, hull_max())
	# Salvataggi pre-benzina: si riparte col pieno.
	fuel = clampf(float(data.get("fuel", fuel_capacity())), 0.0, fuel_capacity())


## Migrazione dei salvataggi pre-R4 (roadmap R4): i quattro contenitori
## separati dell'alpha (boe per BuoyType, pesci per FishType, bottino per tier,
## casse missione) confluiscono nell'inventario unico via le mappe enum→id,
## senza che i mondi esistenti perdano niente.
func _migrate_legacy_cargo(data: Dictionary) -> void:
	var cargo_in: Dictionary = data.get("cargo", {})
	for type: String in cargo_in:
		_add_item(BUOY_ITEM[int(type)], int(cargo_in[type]))
	var fish_in: Dictionary = data.get("fish", {})
	for type: String in fish_in:
		_add_item(FISH_ITEM[int(type)], int(fish_in[type]))
	var loot_in: Dictionary = data.get("loot", {})
	for tier: String in loot_in:
		_add_item(LOOT_ITEM[int(tier)], int(loot_in[tier]))
	_set_item(MISSION_CRATE_ITEM, int(data.get("mission_crates", 0)))


func _vec3_to_array(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


## Riconosce un Vector3 serializzato ([x, y, z] numerico) nel round-trip
## JSON della missione: solo target/return lo sono, ma la forma basta.
func _is_vec3_array(value: Variant) -> bool:
	if not value is Array:
		return false
	var arr: Array = value
	if arr.size() != 3:
		return false
	for item: Variant in arr:
		if not (item is float or item is int):
			return false
	return true


func _array_to_vec3(arr: Array) -> Vector3:
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))


func delete_save() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)


## Riporta la partita allo stato iniziale e cancella il salvataggio
## (usato dal "Ricomincia" della pausa: gli autoload sopravvivono al
## reload della scena).
func reset() -> void:
	money = 0
	race_wins = 0
	tutorial_step = TUTORIAL_COLLECT
	inventory.clear()
	cannon_level = 0
	owned_boats.clear()
	owned_boats.append(&"dinghy")
	current_boat_id = &"dinghy"
	upgrades.clear()
	fishing_gear.clear()
	grandson_quest = GrandsonQuest.NONE
	radar_unlocked = false
	radar_upgrades.clear()
	reputation.clear()
	reputation.merge(FACTION_START_REP)
	world_state = _default_world_state()
	active_mission.clear()
	mission_time_left = 0.0
	paints_owned.clear()
	paint_applied.clear()
	accessories_owned.clear()
	paint_preview = &""
	play_seconds = 0.0
	total_earned = 0
	fish_caught_total = 0
	alpha_end_shown = false
	hull = hull_max()
	fuel = fuel_capacity()
	on_foot = false
	_ui_focus_count = 0
	delete_save()
	money_changed.emit(money)
	hull_changed.emit(hull, hull_max())
	fuel_changed.emit(fuel, fuel_capacity())
	cargo_changed.emit()
	boat_changed.emit(current_def())
	customization_changed.emit()
	cannon_changed.emit()
	tutorial_changed.emit(tutorial_step, tutorial_hint())
	reputation_changed.emit(FACTION_BOVA, 0)
	mission_changed.emit()
	world_state_reset.emit()
	clear_danger()


func post_notice(text: String) -> void:
	notice_posted.emit(text)


# --- Obiettivo guidato d'avvio -----------------------------------------------

## Riga da mostrare per la tappa corrente ("" quando finito).
func tutorial_hint() -> String:
	return TUTORIAL_HINTS.get(tutorial_step, "")


## Avanza alla tappa successiva solo se siamo davvero su `from` (le
## chiamate arrivano da eventi di gioco): evita salti e doppie emissioni.
func _advance_tutorial(from: int) -> void:
	if tutorial_step != from:
		return
	tutorial_step = from + 1
	tutorial_changed.emit(tutorial_step, tutorial_hint())
	save_game()


# --- Feedback d'urto ---------------------------------------------------------

## Chiamato dalla barca a ogni impatto: propaga la forza a HUD e camera.
func report_boat_hit(force: float) -> void:
	boat_hit.emit(force)


# --- Focus UI (mouse) --------------------------------------------------------

## Conteggio dei pannelli aperti: le chiamate vanno sempre in coppia
## (aperto/chiuso) da ogni pannello.
var _ui_focus_count: int = 0


func push_ui_focus() -> void:
	_ui_focus_count += 1
	if _ui_focus_count == 1:
		ui_focus_changed.emit(true)


func pop_ui_focus() -> void:
	if _ui_focus_count <= 0:
		return
	_ui_focus_count -= 1
	if _ui_focus_count == 0:
		ui_focus_changed.emit(false)


func ui_focus_open() -> bool:
	return _ui_focus_count > 0


## Avviso persistente a schermo (es. countdown fuori zona), aggiornato
## dal chiamante finché la condizione dura.
func set_danger(text: String) -> void:
	danger_changed.emit(text)


func clear_danger() -> void:
	danger_cleared.emit()


# --- Cheat di playtest -------------------------------------------------------

## Tutto al massimo in un colpo (lancio con --maxed): flotta completa,
## upgrade, cannone, attrezzatura, radar, vernici e accessori, reputazione
## di casa a fondo scala, Bova al massimo splendore. Passa dalle funzioni
## d'acquisto vere, così ogni invariante e segnale regge. Le città lontane
## restano ostili: la loro storia è parte del gioco, non un numero da maxare.
func debug_max_all() -> void:
	money = 999999
	race_wins = maxi(race_wins, 1)
	tutorial_step = TUTORIAL_DONE
	grandson_quest = GrandsonQuest.DONE
	radar_unlocked = true
	for def in BOAT_DEFS:
		if not owns_boat(def.id):
			buy_boat(def.id)
	for def in BOAT_DEFS:
		select_boat(def.id)
		for type: int in UPGRADE_NAME:
			while buy_upgrade(type):
				pass
		for paint in PAINTS:
			buy_paint(paint["id"])
		for accessory in ACCESSORIES:
			buy_accessory(accessory["id"])
	select_boat(&"cruiser")
	while buy_cannon():
		pass
	for gear: int in FISHING_GEAR_NAME:
		while buy_fishing_gear(gear):
			pass
	for upgrade: int in RADAR_UPGRADE_NAME:
		while buy_radar_upgrade(upgrade):
			pass
	add_reputation(REP_MAX, FACTION_BOVA)
	Town.debug_max()
	money = 999999
	hull = hull_max()
	fuel = fuel_capacity()
	money_changed.emit(money)
	hull_changed.emit(hull, hull_max())
	fuel_changed.emit(fuel, fuel_capacity())
	tutorial_changed.emit(tutorial_step, tutorial_hint())
	post_notice("MAXED: flotta, upgrade e Bova al massimo")
	save_game()


# --- I mondi (menu principale, stile Minecraft) ------------------------------

## Elenca i mondi salvati in worlds_dir, dal più recente: per ogni file
## il minimo che serve alle righe del menu (nome, ultima sessione, un
## riassunto della partita). I file illeggibili si saltano senza drammi.
func list_worlds() -> Array[Dictionary]:
	var worlds: Array[Dictionary] = []
	var dir := DirAccess.open(worlds_dir)
	if dir == null:
		return worlds
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var path := worlds_dir + "/" + file_name
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data == null or not data is Dictionary:
			continue
		worlds.append({
			"path": path,
			"name": str(data.get("world_name", "Bova Marina")),
			"last_played": int(data.get("last_played", 0)),
			"money": int(data.get("money", 0)),
			"play_seconds": float(data.get("play_seconds", 0.0)),
			"boat": StringName(data.get("current_boat", "dinghy")),
		})
	worlds.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["last_played"]) > int(b["last_played"]))
	return worlds


func most_recent_world_path() -> String:
	var worlds := list_worlds()
	return str(worlds[0]["path"]) if not worlds.is_empty() else ""


## Nuovo mondo: partita da zero su un file suo. Il chiamante (title)
## ricarica poi la scena per ripartire sulla baia nuova.
func create_world(name: String) -> void:
	DirAccess.make_dir_recursive_absolute(worlds_dir)
	save_path = _unique_world_path(name)
	reset()
	world_name = name.strip_edges()
	if world_name == "":
		world_name = "Mondo senza nome"
	save_game()


## Cambia mondo: carica il file e riallinea gli autoload. Il chiamante
## ricarica poi la scena, che rilegge tutto lo stato da zero.
func switch_world(path: String) -> void:
	save_path = path
	load_game()
	hull = clampf(hull, 0.0, hull_max())
	_ui_focus_count = 0
	Radar.reset()


## Elimina il file di un mondo. Se era quello corrente, si passa al più
## recente rimasto (o a uno stato vergine, senza file finché non si salva).
func delete_world(path: String) -> void:
	DirAccess.remove_absolute(path)
	if path != save_path:
		return
	var recent := most_recent_world_path()
	if recent != "":
		switch_world(recent)
	else:
		save_path = worlds_dir + "/bova-marina.json"
		reset()


## Il salvataggio unico pre-mondi diventa il primo mondo della lista
## ("Bova Marina"), una volta sola: l'originale resta dov'è come scorta.
func migrate_legacy_save() -> void:
	if DirAccess.dir_exists_absolute(worlds_dir) or not FileAccess.file_exists("user://save.json"):
		return
	DirAccess.make_dir_recursive_absolute(worlds_dir)
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://save.json"))
	if data == null or not data is Dictionary:
		return
	data["world_name"] = "Bova Marina"
	var file := FileAccess.open(worlds_dir + "/bova-marina.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))


## Tre mondi di prova sempre disponibili nel menu (richiesta di Stefano,
## 23/07/2026): "Da zero", "A metà" e "Maxato". Creati solo se assenti, così
## non toccano i mondi veri e i progressi fatti su di essi restano. Ognuno
## passa dalle funzioni vere (reset, acquisti, Town), quindi lo stato è
## coerente come una partita giocata. Lascia lo stato live sul mondo maxato:
## il chiamante ricarica subito il mondo scelto (load_game rimette tutto).
func seed_demo_worlds() -> void:
	DirAccess.make_dir_recursive_absolute(worlds_dir)
	_seed_world_if_absent("da-zero.json", "Da zero", Callable())
	_seed_world_if_absent("a-meta.json", "A metà", _apply_mid_preset)
	_seed_world_if_absent("maxato.json", "Maxato", debug_max_all)


func _seed_world_if_absent(file_name: String, name: String, apply: Callable) -> void:
	var path := worlds_dir + "/" + file_name
	if FileAccess.file_exists(path):
		return
	save_path = path
	reset()
	world_name = name
	if apply.is_valid():
		apply.call()
	world_name = name
	save_game()


## Preset "a metà partita": peschereccio, qualche upgrade, cannone base,
## radar, un paio di edifici a Bova e un gruzzolo modesto. Un punto di
## partenza credibile a mezza progressione, senza doverci arrivare giocando.
func _apply_mid_preset() -> void:
	tutorial_step = TUTORIAL_DONE
	grandson_quest = GrandsonQuest.DONE
	radar_unlocked = true
	race_wins = 1
	money = 30000
	buy_boat(&"fishing_boat")
	for i in 2:
		buy_upgrade(UpgradeType.MOTOR)
	buy_upgrade(UpgradeType.HULL)
	buy_upgrade(UpgradeType.CARGO)
	buy_cannon()
	buy_fishing_gear(FishingGear.ROD)
	buy_radar_upgrade(RadarUpgrade.RANGE)
	Town.build(&"molo", &"molo_grande")
	Town.build(&"lungomare", &"conserva")
	money = 2200
	hull = hull_max()
	fuel = fuel_capacity()


## Percorso libero per un mondo nuovo, dal nome: minuscole e trattini
## (es. "La mia baia" -> la-mia-baia.json), con suffisso se già preso.
func _unique_world_path(name: String) -> String:
	var slug := ""
	for character in name.to_lower():
		if character.is_valid_identifier() or character.is_valid_int():
			slug += character
		elif not slug.ends_with("-"):
			slug += "-"
	slug = slug.strip_edges().trim_prefix("-").trim_suffix("-")
	if slug == "":
		slug = "mondo"
	var path := worlds_dir + "/" + slug + ".json"
	var attempt := 2
	while FileAccess.file_exists(path):
		path = worlds_dir + "/" + slug + "-" + str(attempt) + ".json"
		attempt += 1
	return path
