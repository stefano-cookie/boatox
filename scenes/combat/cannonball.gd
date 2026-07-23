class_name CannonBall
extends Area3D

## Proiettile ad arco del combattimento navale (roadmap B1): balistica
## semplice (velocità iniziale + gravità arcade), esplode sul primo corpo
## che incontra o quando ricade in acqua. Sparato dal cannone di bordo e
## dai predoni: chi lo lancia passa fazione e danno, la palla non sa chi
## ha davanti (take_damage uniforme, come Weapon).

## Gravità arcade: più forte del reale, l'arco resta leggibile e teso.
const GRAVITY: float = 18.0
## Vita massima: nessuna palla vaga per la baia all'infinito.
const MAX_LIFETIME: float = 8.0

## Impostati da chi spara, prima di add_child.
var shooter: Node3D
var shooter_faction: StringName = &"player"
var damage: float = 10.0
var velocity: Vector3 = Vector3.ZERO
var sea: Sea

var _life: float = 0.0
var _dead: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	velocity.y -= GRAVITY * delta
	global_position += velocity * delta
	# La prua della palla segue la traiettoria (si vede l'arco); il caso
	# quasi verticale va saltato (look_at non ammette l'up parallelo).
	if velocity.length_squared() > 0.01 \
			and absf(velocity.normalized().dot(Vector3.UP)) < 0.98:
		look_at(global_position + velocity)
	_life += delta
	if _life > MAX_LIFETIME:
		queue_free()
		return
	# Ricaduta in acqua: splash e via. Quota dell'onda vera se c'è la Sea.
	var water_y := sea.get_height(global_position) if sea != null else 0.0
	if velocity.y < 0.0 and global_position.y <= water_y:
		_splash()
		_die()


## Velocità di lancio a modulo fisso (`speed`): si risolve l'ANGOLO d'alzo
## per centrare `to`, come un vero pezzo d'artiglieria. Vicino il tiro è
## quasi teso, lontano l'arco cresce da sé con la distanza — la palla passa
## sempre per il punto mirato (il mirino è il riferimento). Si sceglie la
## soluzione bassa (arco teso, non il lob a campana). Oltre la gittata
## balistica (`speed²/g`) si spara a 45°, gittata massima, verso il bersaglio.
static func launch_velocity(from: Vector3, to: Vector3, speed: float) -> Vector3:
	var v := maxf(speed, 1.0)
	var delta := to - from
	var flat := Vector3(delta.x, 0.0, delta.z)
	var d := flat.length()
	if d < 0.01:
		# Bersaglio a piombo: si spara in verticale nel verso giusto.
		return Vector3.UP * (v if delta.y >= 0.0 else -v)
	var dir := flat / d
	var v2 := v * v
	# tan θ = (v² ± √(v⁴ − g(g·d² + 2·h·v²))) / (g·d): il segno − è il tiro teso.
	var disc := v2 * v2 - GRAVITY * (GRAVITY * d * d + 2.0 * delta.y * v2)
	if disc < 0.0:
		# Fuori portata: 45° verso il bersaglio (la gittata massima possibile).
		return (dir + Vector3.UP) * (v / sqrt(2.0))
	var theta := atan((v2 - sqrt(disc)) / (GRAVITY * d))
	return dir * (v * cos(theta)) + Vector3.UP * (v * sin(theta))


## Vero se un tiro a velocità fissa `speed` può passare per `to` partendo
## da `from`: il discriminante dell'equazione d'alzo non è negativo. Usato
## dal cannone per capire se il punto mirato è in portata balistica (i punti
## alti e vicini possono non esserlo anche dentro la gittata piana).
static func can_reach(from: Vector3, to: Vector3, speed: float) -> bool:
	var v := maxf(speed, 1.0)
	var delta := to - from
	var d2 := delta.x * delta.x + delta.z * delta.z
	var v2 := v * v
	return v2 * v2 - GRAVITY * (GRAVITY * d2 + 2.0 * delta.y * v2) >= 0.0


func _on_body_entered(body: Node3D) -> void:
	if _dead or body == shooter:
		return
	# Niente fuoco amico tra navi della stessa fazione.
	var vessel := body as Vessel
	if vessel != null and vessel.faction == shooter_faction:
		return
	if body.has_method("take_damage"):
		body.take_damage(damage)
		# La nave colpita sa da dove è arrivato il colpo: il mercantile
		# fugge, il predone si volta (Ship.notify_attacked).
		if body.has_method("notify_attacked") and shooter != null:
			body.notify_attacked(shooter.global_position)
		if body is Boat:
			# Colpo incassato dal giocatore: flash scafo + shake camera,
			# come un urto (il feedback esiste già, si riusa).
			GameState.report_boat_hit(6.0)
		else:
			GameState.report_ship_hit(global_position)
	_burst()
	_die()


## Spegne la palla ma lascia vivere le particelle appena emesse.
func _die() -> void:
	_dead = true
	set_deferred("monitoring", false)
	($Ball as MeshInstance3D).visible = false
	var timer := get_tree().create_timer(1.0)
	timer.timeout.connect(queue_free)


## Splash bianco sull'acqua (colpo a vuoto: si vede dove è caduto).
func _splash() -> void:
	var p := $Burst as CPUParticles3D
	p.color = Color(0.85, 0.93, 1.0, 0.9)
	p.restart()
	p.emitting = true


## Sbuffo scuro sull'impatto a segno.
func _burst() -> void:
	var p := $Burst as CPUParticles3D
	p.color = Color(0.95, 0.75, 0.35, 0.95)
	p.restart()
	p.emitting = true
