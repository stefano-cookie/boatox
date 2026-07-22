class_name AudioSynth
extends RefCounted

## Sintetizzatore audio procedurale (CLAUDE.md: asset esterni solo CC0/CC-BY,
## ma i kit audio non sono scaricabili da script — come i modelli Kenney e le
## icone dell'inventario, si generano in codice). Costruisce piccoli
## AudioStreamWAV a 16 bit mono a partire da un buffer di campioni float in
## [-1, 1]: primitive (sine con glide/inviluppo, rumore filtrato) che l'Audio
## autoload compone nei suoni del gioco. I loop (mare, motore, musica) si
## chiudono senza click grazie a crossfade_loop. Tutto qui è @static: nessuno
## stato, si testa e si richiama senza istanziare.

const RATE: int = 22050


## Buffer di silenzio lungo dur secondi, su cui stratificare i suoni.
static func buffer(dur: float) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(maxi(int(dur * RATE), 1))
	buf.fill(0.0)
	return buf


## Aggiunge una sinusoide a partire da start_s. decay > 0 = coda esponenziale
## (suoni one-shot), 0 = sostenuta (loop). glide_to >= 0 fa scivolare la
## frequenza da freq a glide_to (sweep). L'attacco breve evita il click iniziale.
static func add_sine(buf: PackedFloat32Array, start_s: float, freq: float,
		dur: float, amp: float, decay: float = 0.0, attack: float = 0.004,
		glide_to: float = -1.0) -> void:
	var start_i := int(start_s * RATE)
	var n := int(dur * RATE)
	var attack_n := attack * RATE
	var phase := 0.0
	for i in n:
		var idx := start_i + i
		if idx < 0 or idx >= buf.size():
			continue
		var u := float(i) / float(maxi(n, 1))
		var f := freq if glide_to < 0.0 else lerpf(freq, glide_to, u)
		phase += TAU * f / float(RATE)
		var env := 1.0
		if decay > 0.0:
			env = exp(-decay * u)
		if attack_n > 1.0 and i < attack_n:
			env *= float(i) / attack_n
		buf[idx] += sin(phase) * amp * env


## Aggiunge rumore bianco passato in un passa-basso a un polo (cutoff 0..1:
## basso = rombo, alto = fruscio). Stessa logica d'inviluppo di add_sine.
static func add_noise(buf: PackedFloat32Array, start_s: float, dur: float,
		amp: float, decay: float = 0.0, cutoff: float = 0.5, seed: int = 1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var start_i := int(start_s * RATE)
	var n := int(dur * RATE)
	var a := clampf(cutoff, 0.001, 1.0)
	var lp := 0.0
	for i in n:
		var idx := start_i + i
		if idx < 0 or idx >= buf.size():
			continue
		lp += a * (rng.randf_range(-1.0, 1.0) - lp)
		var u := float(i) / float(maxi(n, 1))
		var env := 1.0
		if decay > 0.0:
			env = exp(-decay * u)
		buf[idx] += lp * amp * env


## Modula l'ampiezza del buffer con un LFO lento (le onde che vanno e vengono):
## depth 0..1 = profondità dello swell, freq in Hz, phase per sfasare più swell
## sovrapposti. Applicato ai loop del mare per dargli il respiro dei frangenti.
static func apply_swell(buf: PackedFloat32Array, freq: float, depth: float,
		phase: float = 0.0) -> void:
	for i in buf.size():
		var t := float(i) / float(RATE)
		var lfo := 0.5 * (1.0 + sin(TAU * freq * t + phase))
		buf[i] *= (1.0 - depth) + depth * lfo


## Rende il buffer ciclabile senza salto: ripiega la coda (lunga fade_s) sulla
## testa con crossfade e la scarta, così l'ultimo campione combacia col primo.
## Va chiamato prima di to_wav(buf, true).
static func crossfade_loop(buf: PackedFloat32Array, fade_s: float) -> void:
	var f := int(fade_s * RATE)
	var n := buf.size()
	if f <= 0 or f * 2 >= n:
		return
	var loop_len := n - f
	for i in f:
		var w := float(i) / float(f)
		buf[i] = buf[i] * w + buf[loop_len + i] * (1.0 - w)
	buf.resize(loop_len)


## Converte il buffer in AudioStreamWAV. tanh = soft clip morbido quando gli
## strati sommati superano 1, così niente distorsione dura.
static func to_wav(buf: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		var v := tanh(buf[i])
		bytes.encode_s16(i * 2, int(round(clampf(v, -1.0, 1.0) * 32767.0)))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = buf.size()
	return wav
