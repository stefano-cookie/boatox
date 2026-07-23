extends Node

## Audio centrale del gioco (roadmap M4 "Audio: mare, motore, UI, un tema
## musicale", anticipato). Un solo posto: crea i bus, genera gli stream
## procedurali (AudioSynth) e li suona. Gli SFX sono event-driven — si
## agganciano ai segnali di GameState, così nessuna scena deve conoscere
## l'audio. Il mare e il motore sono loop continui pilotati dalla barca
## (update_sea/update_engine). I bus Master/Music/Ambient/Sfx esistono già
## ora perché le impostazioni volumi di M4 ci si aggancino senza rifattorizzare.

const BUS_MUSIC := &"Music"
const BUS_AMBIENT := &"Ambient"
const BUS_SFX := &"Sfx"

## Suono del motore: dB e pitch da idle (fermo) a pieno regime; il volume
## OFF lo spegne nei menu senza fermare il loop. Lo smoothing evita scatti.
const ENGINE_OFF_DB := -60.0
const ENGINE_IDLE_DB := -28.0
const ENGINE_FULL_DB := -10.0
const ENGINE_PITCH_IDLE := 0.75
## Pitch di punta contenuto: un motore tondo, non un ronzio acuto in accelerazione.
const ENGINE_PITCH_FULL := 1.4
const ENGINE_SMOOTH := 6.0
## Se la barca smette di aggiornare il motore (menu, cambio scena) per più di
## questo, il motore torna a zero: niente rombo che resta appeso.
const ENGINE_STALE := 0.2

## Mare d'ambiente: l'agitazione locale (zona × vento × meteo) viene mappata
## in 0..1 tra queste soglie. Due strati d'onde in crossfade su quel valore —
## così il mare non cambia solo di volume ma di timbro: lo strato "calmo"
## (sciacquio dolce, sempre presente) e lo strato "burrasca" (frangenti
## brillanti, onde più rapide) che entra col mare grosso. Smoothing lento.
const SEA_SMOOTH := 1.5
const SEA_AGITATION_MIN := 0.4
const SEA_AGITATION_MAX := 3.2
const SEA_CALM_MIN_DB := -24.0
const SEA_CALM_MAX_DB := -7.0
const SEA_STORM_MIN_DB := -60.0
const SEA_STORM_MAX_DB := -3.0

## Playlist musicale (roadmap "un tema musicale"): più brani generati, suonati
## a rotazione con una pausa in mezzo (come Minecraft), estetica Frutiger Aero
## — maggiore, arioso, campanellini puliti. Generati in un thread per non far
## scattare l'avvio; saltati in headless (test).
const MUSIC_DB := -11.0
const ENABLE_MUSIC := true
const MUSIC_GAP_MIN := 14.0
const MUSIC_GAP_MAX := 34.0

const SFX_PLAYERS := 6

## Impostazioni complete (roadmap A2): volumi 0..1 applicati ai bus
## ("Master" = bus Master, "Musica" = bus Music, "Effetti" = Ambient + Sfx),
## più schermo intero e sensibilità mouse (moltiplicatore letto dalla
## ChaseCamera). Tutto su un solo ConfigFile: questo autoload è l'unico a
## scrivere user://settings.cfg, così nessuna sezione sovrascrive le altre.
const SETTINGS_PATH := "user://settings.cfg"
## Escursione del moltiplicatore di sensibilità mouse (slider impostazioni).
const SENSITIVITY_MIN := 0.3
const SENSITIVITY_MAX := 2.0
var master_volume: float = 1.0
var music_volume: float = 0.7
var sfx_volume: float = 0.9
var mouse_sensitivity_scale: float = 1.0
var fullscreen: bool = false

var _engine: AudioStreamPlayer
var _sea_calm: AudioStreamPlayer
var _sea_storm: AudioStreamPlayer
var _music: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_next: int = 0
var _sfx: Dictionary[StringName, AudioStream] = {}

var _engine_vol_target: float = 0.0
var _engine_pitch_target: float = ENGINE_PITCH_IDLE
var _engine_idle: float = ENGINE_STALE + 1.0
var _sea_target: float = 0.0

## Playlist musicale: brani generati (in _gen_thread), ordine mescolato e
## indice corrente; _music_gap è la pausa di silenzio tra un brano e l'altro.
var _music_tracks: Array[AudioStreamWAV] = []
var _music_order: Array[int] = []
var _music_index: int = 0
var _music_gap: Timer
var _gen_thread: Thread


func _ready() -> void:
	# Continua a lisciare i volumi anche a gioco in pausa (menu/inventario):
	# così il motore sfuma a zero invece di restare fisso.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_load_settings()
	_build_streams()
	_build_players()
	_connect_signals()


func _process(delta: float) -> void:
	_engine_idle += delta
	var vol01 := _engine_vol_target
	if _engine_idle > ENGINE_STALE or get_tree().paused:
		vol01 = 0.0
	var engine_db := ENGINE_OFF_DB if vol01 <= 0.001 else lerpf(ENGINE_IDLE_DB, ENGINE_FULL_DB, vol01)
	_engine.volume_db = _approach(_engine.volume_db, engine_db, ENGINE_SMOOTH, delta)
	_engine.pitch_scale = _approach(_engine.pitch_scale, _engine_pitch_target, ENGINE_SMOOTH, delta)
	# Strato calmo sempre presente (sale dolce con la radice); strato burrasca
	# che entra solo oltre il 35% di agitazione → il mare cambia timbro, non
	# solo volume.
	var calm_db := lerpf(SEA_CALM_MIN_DB, SEA_CALM_MAX_DB, sqrt(_sea_target))
	var storm01 := clampf((_sea_target - 0.35) / 0.65, 0.0, 1.0)
	var storm_db := SEA_STORM_MIN_DB if storm01 <= 0.001 else lerpf(SEA_STORM_MIN_DB, SEA_STORM_MAX_DB, storm01)
	_sea_calm.volume_db = _approach(_sea_calm.volume_db, calm_db, SEA_SMOOTH, delta)
	_sea_storm.volume_db = _approach(_sea_storm.volume_db, storm_db, SEA_SMOOTH, delta)


func _exit_tree() -> void:
	# Il thread di generazione musica va chiuso ordinatamente all'uscita.
	if _gen_thread != null and _gen_thread.is_started():
		_gen_thread.wait_to_finish()


# --- API continua (pilotata dalla barca) -------------------------------------

## Regime del motore: speed01 e throttle in 0..1. Volume e pitch salgono col
## più alto dei due (accelerare da fermo si sente subito, non solo a velocità).
func update_engine(speed01: float, throttle: float) -> void:
	var drive := clampf(maxf(speed01, absf(throttle)), 0.0, 1.0)
	_engine_vol_target = clampf(0.25 + 0.75 * drive, 0.0, 1.0)
	_engine_pitch_target = lerpf(ENGINE_PITCH_IDLE, ENGINE_PITCH_FULL, drive)
	_engine_idle = 0.0


## Agitazione del mare nel punto della barca (Sea.agitation): alza il volume
## del loop d'ambiente. Il mare grosso si sente prima ancora di vederlo.
func update_sea(agitation: float) -> void:
	_sea_target = clampf(inverse_lerp(SEA_AGITATION_MIN, SEA_AGITATION_MAX, agitation), 0.0, 1.0)


# --- Impostazioni (pannello impostazioni) ------------------------------------

## Volume generale 0..1: scala il bus Master (tutto il gioco) e salva.
func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_master_volume()
	_save_settings()


## Volume musica 0..1 (0 = muto): scala il bus Music e salva.
func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_music_volume()
	_save_settings()


## Volume effetti 0..1 (mare, motore, SFX): scala i bus Ambient e Sfx e salva.
func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_sfx_volume()
	_save_settings()


## Sensibilità del mouse in camera: moltiplicatore 0.3..2 sul valore di
## design della ChaseCamera (che resta @export, da tarare giocando).
func set_mouse_sensitivity_scale(value: float) -> void:
	mouse_sensitivity_scale = clampf(value, SENSITIVITY_MIN, SENSITIVITY_MAX)
	_save_settings()


## Schermo intero: applicato subito e ricordato al prossimo avvio.
func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_apply_fullscreen()
	_save_settings()


func _apply_master_volume() -> void:
	AudioServer.set_bus_volume_db(0, _volume_db(master_volume))


func _apply_fullscreen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen
		else DisplayServer.WINDOW_MODE_WINDOWED)


func _apply_music_volume() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_MUSIC), _volume_db(music_volume))


func _apply_sfx_volume() -> void:
	var db := _volume_db(sfx_volume)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_AMBIENT), db)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_SFX), db)


func _volume_db(value: float) -> float:
	return -60.0 if value <= 0.001 else linear_to_db(value)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		master_volume = clampf(cfg.get_value("audio", "master", master_volume), 0.0, 1.0)
		music_volume = clampf(cfg.get_value("audio", "music", music_volume), 0.0, 1.0)
		sfx_volume = clampf(cfg.get_value("audio", "sfx", sfx_volume), 0.0, 1.0)
		mouse_sensitivity_scale = clampf(cfg.get_value("controls", "mouse_sensitivity",
			mouse_sensitivity_scale), SENSITIVITY_MIN, SENSITIVITY_MAX)
		fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))
	_apply_master_volume()
	_apply_music_volume()
	_apply_sfx_volume()
	_apply_fullscreen()


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity_scale)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.save(SETTINGS_PATH)


# --- SFX event-driven (segnali di GameState) ---------------------------------

func _connect_signals() -> void:
	GameState.boat_hit.connect(_on_boat_hit)
	GameState.hull_depleted.connect(func() -> void: _play(&"alarm"))
	GameState.cargo_sold.connect(func(_amount: int) -> void: _play(&"coin"))
	GameState.buoy_collected.connect(_on_buoy_collected)
	GameState.fish_caught.connect(func(_type: int) -> void: _play(&"fish"))
	GameState.radar_pinged.connect(func() -> void: _play(&"radar"))
	# Combattimento navale (roadmap B1): boato dello sparo (di chiunque),
	# legnata sulla nave colpita, gorgoglio dell'affondamento, bottino a bordo.
	GameState.cannon_fired.connect(func() -> void: _play(&"cannon", randf_range(0.92, 1.1)))
	GameState.ship_hit.connect(func(_pos: Vector3) -> void: _play(&"impact", 1.25, -6.0))
	GameState.ship_sunk.connect(func(_pos: Vector3) -> void: _play(&"sink"))
	GameState.loot_collected.connect(func(_tier: int) -> void: _play(&"pop", 0.8))
	GameState.fuel_collected.connect(func(_liters: float) -> void: _play(&"pop", 1.15))
	# Missione compiuta (roadmap R2): fanfara del tracker HUD, distinta dal
	# cha-ching della vendita che parte in contemporanea.
	GameState.mission_completed.connect(func(_what: String, _reward: int) -> void: _play(&"chime", 1.18))
	# Tick discreto su ogni avviso: conferma che qualcosa è successo, basso
	# volume per non stancare (le vendite hanno già il loro cha-ching sopra).
	GameState.notice_posted.connect(func(_text: String) -> void: _play(&"tick", 1.0, -14.0))


## Urto: più forte l'impatto, più grave e forte il tonfo (scala con boat_hit).
func _on_boat_hit(force: float) -> void:
	var strength := clampf(force / 14.0, 0.15, 1.0)
	_play(&"impact", lerpf(1.15, 0.7, strength), lerpf(-10.0, 3.0, strength))


func _on_buoy_collected(type: int) -> void:
	if type == GameState.BuoyType.BLUE:
		_play(&"chime")
	else:
		_play(&"pop", randf_range(0.94, 1.08))


## Suona un SFX dal pool round-robin (i suoni brevi si sovrappongono senza
## tagliarsi). pitch e vol_db opzionali per variarlo senza nuovi stream.
func _play(name: StringName, pitch: float = 1.0, vol_db: float = 0.0) -> void:
	if not _sfx.has(name):
		return
	var player := _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_pool.size()
	player.stream = _sfx[name]
	player.pitch_scale = pitch
	player.volume_db = vol_db
	player.play()


# --- Setup -------------------------------------------------------------------

func _setup_buses() -> void:
	for bus_name: StringName in [BUS_MUSIC, BUS_AMBIENT, BUS_SFX]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, &"Master")


func _build_players() -> void:
	_engine = _make_player(BUS_SFX, ENGINE_OFF_DB)
	_engine.stream = _make_engine_loop()
	_engine.pitch_scale = ENGINE_PITCH_IDLE
	_engine.play()
	_sea_calm = _make_player(BUS_AMBIENT, SEA_CALM_MIN_DB)
	_sea_calm.stream = _make_sea_loop(false)
	_sea_calm.play()
	_sea_storm = _make_player(BUS_AMBIENT, SEA_STORM_MIN_DB)
	_sea_storm.stream = _make_sea_loop(true)
	_sea_storm.play()
	_music = _make_player(BUS_MUSIC, MUSIC_DB)
	if ENABLE_MUSIC:
		_start_music()
	for i in SFX_PLAYERS:
		_sfx_pool.append(_make_player(BUS_SFX, 0.0))


func _make_player(bus: StringName, vol_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	player.volume_db = vol_db
	add_child(player)
	return player


func _approach(current: float, target: float, speed: float, delta: float) -> float:
	return lerpf(current, target, 1.0 - exp(-speed * delta))


# --- Stream procedurali ------------------------------------------------------

func _build_streams() -> void:
	# Urto: tonfo grave (rumore basso) + due sinusoidi profonde a coda rapida.
	var b := AudioSynth.buffer(0.3)
	AudioSynth.add_noise(b, 0.0, 0.25, 0.9, 14.0, 0.12, 21)
	AudioSynth.add_sine(b, 0.0, 90.0, 0.22, 0.7, 12.0)
	AudioSynth.add_sine(b, 0.0, 55.0, 0.26, 0.5, 9.0)
	_sfx[&"impact"] = AudioSynth.to_wav(b)

	# Vendita: arpeggio brillante ascendente (cha-ching del pagoff, GDD loop).
	b = AudioSynth.buffer(0.55)
	var coin_notes: Array[float] = [880.0, 1108.7, 1318.5, 1760.0]
	for i in coin_notes.size():
		AudioSynth.add_sine(b, i * 0.06, coin_notes[i], 0.22, 0.42, 9.0)
	_sfx[&"coin"] = AudioSynth.to_wav(b)

	# Boa raccolta: "pop" corto con glide verso l'alto.
	b = AudioSynth.buffer(0.18)
	AudioSynth.add_sine(b, 0.0, 500.0, 0.12, 0.6, 10.0, 0.004, 900.0)
	_sfx[&"pop"] = AudioSynth.to_wav(b)

	# Boa blu (rarissima): due note che salgono, più preziose del pop.
	b = AudioSynth.buffer(0.6)
	AudioSynth.add_sine(b, 0.0, 1318.5, 0.4, 0.45, 5.0)
	AudioSynth.add_sine(b, 0.12, 1760.0, 0.45, 0.45, 5.0)
	_sfx[&"chime"] = AudioSynth.to_wav(b)

	# Radar: sweep discendente tipo sonar, con eco tenue.
	b = AudioSynth.buffer(0.7)
	AudioSynth.add_sine(b, 0.0, 1400.0, 0.5, 0.5, 4.0, 0.004, 500.0)
	AudioSynth.add_sine(b, 0.18, 1400.0, 0.45, 0.22, 5.0, 0.004, 500.0)
	_sfx[&"radar"] = AudioSynth.to_wav(b)

	# Allarme scafo a zero: due beep gravi alternati.
	b = AudioSynth.buffer(0.6)
	AudioSynth.add_sine(b, 0.0, 440.0, 0.16, 0.5, 2.5)
	AudioSynth.add_sine(b, 0.22, 330.0, 0.16, 0.5, 2.5)
	_sfx[&"alarm"] = AudioSynth.to_wav(b)

	# Pesce catturato: pizzico + ding luminoso.
	b = AudioSynth.buffer(0.5)
	AudioSynth.add_noise(b, 0.0, 0.1, 0.2, 8.0, 0.3, 7)
	AudioSynth.add_sine(b, 0.0, 180.0, 0.12, 0.4, 10.0)
	AudioSynth.add_sine(b, 0.1, 1046.5, 0.35, 0.5, 6.0)
	_sfx[&"fish"] = AudioSynth.to_wav(b)

	# Tick UI: clic brevissimo per gli avvisi.
	b = AudioSynth.buffer(0.05)
	AudioSynth.add_sine(b, 0.0, 1200.0, 0.03, 0.3, 20.0, 0.001)
	_sfx[&"tick"] = AudioSynth.to_wav(b)

	# Cannone (roadmap B1): botta di rumore secca + fondamentale grave che
	# scende — un boato tondo, non un petardo.
	b = AudioSynth.buffer(0.45)
	AudioSynth.add_noise(b, 0.0, 0.3, 0.8, 10.0, 0.2, 33)
	AudioSynth.add_sine(b, 0.0, 70.0, 0.35, 0.8, 7.0, 0.004, 40.0)
	_sfx[&"cannon"] = AudioSynth.to_wav(b)

	# Affondamento: rimbombo profondo con gorgoglio (rumore lento) sopra.
	b = AudioSynth.buffer(1.1)
	AudioSynth.add_sine(b, 0.0, 48.0, 0.9, 0.6, 3.0, 0.01, 30.0)
	AudioSynth.add_noise(b, 0.15, 0.8, 0.3, 4.0, 0.5, 47)
	_sfx[&"sink"] = AudioSynth.to_wav(b)


## Motore: fondamentale a 60 Hz con due sole armoniche, tutte con un numero
## intero di cicli in 0.4 s (0.4 s a 60 Hz = 24 cicli esatti, 8820 campioni).
## Nessun rumore e nessun crossfade: il buffer è già periodico e il loop
## combacia campione per campione — così non c'è il "tic" a ogni ripetizione
## che, con il pitch che sale in accelerazione, diventava un ticchettio.
func _make_engine_loop() -> AudioStreamWAV:
	var b := AudioSynth.buffer(0.4)
	AudioSynth.add_sine(b, 0.0, 60.0, 0.4, 0.72, 0.0, 0.0)
	AudioSynth.add_sine(b, 0.0, 120.0, 0.4, 0.13, 0.0, 0.0)
	AudioSynth.add_sine(b, 0.0, 180.0, 0.4, 0.04, 0.0, 0.0)
	return AudioSynth.to_wav(b, true)


## Mare (loop di 8 s). Due varianti: calmo = rombo profondo + sciacquio dolce,
## onde lente; burrasca = corpo più pieno + frangenti brillanti, onde rapide e
## marcate. Gli swell (apply_swell) sono le onde che vanno e vengono; il
## crossfade lungo tiene il loop senza stacco udibile.
func _make_sea_loop(storm: bool) -> AudioStreamWAV:
	var b := AudioSynth.buffer(8.0)
	if storm:
		AudioSynth.add_noise(b, 0.0, 8.0, 0.42, 0.0, 0.12, 303)
		AudioSynth.add_noise(b, 0.0, 8.0, 0.32, 0.0, 0.6, 404)
		AudioSynth.apply_swell(b, 0.5, 0.7)
		AudioSynth.apply_swell(b, 0.9, 0.45, 1.7)
	else:
		AudioSynth.add_noise(b, 0.0, 8.0, 0.5, 0.0, 0.04, 101)
		AudioSynth.add_noise(b, 0.0, 8.0, 0.14, 0.0, 0.18, 202)
		AudioSynth.apply_swell(b, 0.16, 0.55)
		AudioSynth.apply_swell(b, 0.33, 0.3, 2.1)
	AudioSynth.crossfade_loop(b, 0.3)
	return AudioSynth.to_wav(b, true)


# --- Playlist musicale (Frutiger Aero) ---------------------------------------

## Prepara il timer di pausa tra i brani e avvia la generazione. I brani si
## costruiscono in un thread (secondi di calcolo) per non far scattare l'avvio;
## quando sono pronti (_on_music_ready) parte il primo. In headless (test)
## niente musica: sarebbe muta e rallenterebbe soltanto.
func _start_music() -> void:
	_music_gap = Timer.new()
	_music_gap.one_shot = true
	add_child(_music_gap)
	_music_gap.timeout.connect(_play_next_track)
	_music.finished.connect(_on_track_finished)
	if DisplayServer.get_name() == "headless":
		return
	_gen_thread = Thread.new()
	_gen_thread.start(_generate_tracks)


## Brani in maggiore, accordi con settima (colore luminoso, "aero"): I–vi–IV–V
## in quattro tonalità diverse. Ogni accordo è un array di note MIDI. Girano
## nel thread → solo matematica, nessun accesso alla scena.
func _generate_tracks() -> void:
	var tracks: Array[AudioStreamWAV] = []
	tracks.append(_make_track([[60, 64, 67, 71], [57, 60, 64, 67], [53, 57, 60, 64], [55, 59, 62, 67]], 72, 11, 0.62))
	tracks.append(_make_track([[62, 66, 69, 73], [59, 62, 66, 69], [55, 59, 62, 66], [57, 61, 64, 69]], 74, 22, 0.68))
	tracks.append(_make_track([[53, 57, 60, 64], [50, 53, 57, 60], [46, 50, 53, 57], [48, 52, 55, 60]], 65, 33, 0.72))
	tracks.append(_make_track([[57, 61, 64, 68], [54, 57, 61, 64], [50, 54, 57, 61], [52, 56, 59, 64]], 69, 44, 0.6))
	call_deferred("_on_music_ready", tracks)


func _on_music_ready(tracks: Array) -> void:
	if _gen_thread != null:
		_gen_thread.wait_to_finish()
		_gen_thread = null
	_music_tracks.assign(tracks)
	_reshuffle_music()
	_play_next_track()


func _play_next_track() -> void:
	if _music_tracks.is_empty():
		return
	if _music_index >= _music_order.size():
		_reshuffle_music()
	_music.stream = _music_tracks[_music_order[_music_index]]
	_music_index += 1
	_music.play()


## Fine brano → pausa di silenzio (come Minecraft), poi il prossimo.
func _on_track_finished() -> void:
	_music_gap.start(randf_range(MUSIC_GAP_MIN, MUSIC_GAP_MAX))


func _reshuffle_music() -> void:
	_music_order.clear()
	for i in _music_tracks.size():
		_music_order.append(i)
	for i in range(_music_order.size() - 1, 0, -1):
		var j := randi() % (i + 1)
		var tmp := _music_order[i]
		_music_order[i] = _music_order[j]
		_music_order[j] = tmp
	_music_index = 0


## Un brano (~20 s, non in loop: la playlist li concatena). Estetica Frutiger
## Aero: pad ariosa tenuta con lieve detune (larghezza), basso morbido, arpeggio
## di campanellini puliti e una melodia a campana pentatonica, sparsa e con
## pause — deterministica dal seed, così ogni brano è diverso ma sempre consono.
func _make_track(chords: Array, key_root: int, seed_val: int, beat: float) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var bar := beat * 4.0
	var passes := 2
	var penta: Array[int] = [0, 2, 4, 7, 9]
	var b := AudioSynth.buffer(bar * chords.size() * passes + 0.6)
	for p in passes:
		for ci in chords.size():
			var chord: Array = chords[ci]
			var t0 := (p * chords.size() + ci) * bar
			for m: int in chord:
				var f := _midi(m)
				AudioSynth.add_sine(b, t0, f, bar + 0.3, 0.035, 0.0, 0.08)
				AudioSynth.add_sine(b, t0, f * 1.004, bar + 0.3, 0.022, 0.0, 0.08)
			var bass := _midi(chord[0] - 12)
			AudioSynth.add_sine(b, t0, bass, beat * 1.8, 0.16, 2.2)
			AudioSynth.add_sine(b, t0 + beat * 2.0, bass, beat * 1.8, 0.14, 2.2)
			for n in 8:
				var am: int = chord[n % chord.size()] + (12 if n >= 4 else 0)
				_add_bell(b, t0 + n * (beat * 0.5), _midi(am), beat * 0.5, 0.05)
			var t := t0
			while t < t0 + bar - 0.01:
				var durs: Array[float] = [0.5, 1.0, 1.0, 1.5]
				var dur := beat * durs[rng.randi() % durs.size()]
				if rng.randf() < 0.28:
					t += dur
					continue
				var deg: int = penta[rng.randi() % penta.size()]
				var octave: int = 12 * (1 + (rng.randi() % 2))
				_add_bell(b, t, _midi(key_root + deg + octave), minf(dur, t0 + bar - t), 0.12)
				t += dur
	_fade_edges(b, 0.4)
	return AudioSynth.to_wav(b)


## Campana Frutiger Aero: fondamentale morbida + ottava tenue, attacco dolce.
func _add_bell(b: PackedFloat32Array, at: float, freq: float, dur: float, amp: float) -> void:
	AudioSynth.add_sine(b, at, freq, dur, amp, 3.0, 0.015)
	AudioSynth.add_sine(b, at, freq * 2.0, dur, amp * 0.3, 4.0, 0.015)


## Dissolvenza in entrata/uscita, così inizio e fine brano non scattano.
func _fade_edges(b: PackedFloat32Array, secs: float) -> void:
	var n := int(secs * AudioSynth.RATE)
	for i in n:
		var w := float(i) / float(n)
		b[i] *= w
		b[b.size() - 1 - i] *= w


func _midi(note: int) -> float:
	return 440.0 * pow(2.0, (note - 69) / 12.0)
