## Recetas de sintesis de los efectos: cada una devuelve una variante nueva cada vez que se llama, con sus
## parametros movidos al azar dentro de VARIATION. Las constantes son el sonido base: se ajustan de oido.
class_name SfxRecipes
extends RefCounted

const RATE_SHORT := 44100        # muestreo de disparos e impactos (Hz): hace falta para un chasquido nitido
const RATE_LONG := 16000         # muestreo de explosiones y caidas (Hz): casi todo es grave y duran segundos, asi ocupan menos
const VARIATION := 0.08          # variacion de cada parametro entre variantes (0.08 = mas o menos un 8 %)

# Ametralladora, por capas: clic de ataque + timbre metalico + chasquido de ruido en banda + golpe corto grave.
# Es muy breve y de poca energia para poder repetirse a mucha cadencia sin volverse un muro de ruido.
const MG_TIME := 0.07            # duracion (s)
const MG_CLICK_CUTOFF := 3000.0  # pasa-altos del clic de ataque (Hz)
const MG_CLICK_DECAY := 900.0    # rapidez con que se apaga el clic (1/s): dura un milisegundo
const MG_CLICK_AMP := 0.9
const MG_RING_HZ := 2800.0       # tono del timbre metalico
const MG_RING_RATIO := 1.52      # relacion del segundo parcial con el primero: no es armonica, suena a metal
const MG_RING_DECAY := 350.0
const MG_RING_AMP := 0.3
const MG_CRACK_LOW := 1500.0     # el chasquido de ruido se limita a esta banda (Hz): pasa-altos y pasa-bajos
const MG_CRACK_HIGH := 7000.0
const MG_CRACK_DECAY := 140.0
const MG_CRACK_AMP := 0.6
const MG_BODY_HZ := 170.0        # tono del golpe grave
const MG_BODY_DROP := 0.4        # cuanto mas agudo empieza ese golpe (fraccion): cae hasta su tono base
const MG_BODY_DROP_RATE := 70.0  # rapidez de esa caida de tono (1/s)
const MG_BODY_DECAY := 130.0
const MG_BODY_AMP := 0.45
const MG_PEAK := 0.5             # pico de la muestra (0..1)

# Canon, por capas: crujido de ataque + golpe grave con caida de tono + golpe medio de ruido + cola de ruido
# cuyo filtro se va cerrando. Una saturacion suave al final le da pegada. Pesa y dura mas que la ametralladora.
const CANNON_TIME := 0.28
const CANNON_CRACK_CUTOFF := 2000.0 # pasa-altos del crujido de ataque (Hz)
const CANNON_CRACK_DECAY := 400.0
const CANNON_CRACK_AMP := 0.8
const CANNON_BODY_HZ := 70.0     # tono base del golpe grave
const CANNON_BODY_DROP := 1.0    # cuanto mas agudo empieza (fraccion): arranca al doble y cae hasta el tono base
const CANNON_BODY_DROP_RATE := 45.0
const CANNON_BODY_DECAY := 22.0
const CANNON_BODY_AMP := 0.9
const CANNON_OVERTONE_AMP := 0.3 # armonico al doble del tono: da presencia en los altavoces pequenos
const CANNON_OVERTONE_DECAY := 30.0
const CANNON_THUD_CUTOFF := 900.0 # pasa-bajos del golpe medio (Hz)
const CANNON_THUD_DECAY := 30.0
const CANNON_THUD_AMP := 0.6
const CANNON_TAIL_HIGH := 3500.0 # corte inicial del pasa-bajos de la cola (Hz)
const CANNON_TAIL_LOW := 400.0   # corte al que tiende
const CANNON_TAIL_SWEEP := 14.0  # rapidez con que el filtro de la cola se cierra (1/s)
const CANNON_TAIL_DECAY := 12.0
const CANNON_TAIL_AMP := 0.35
const CANNON_DRIVE := 1.6        # saturacion suave final: 1 = casi nada, mas = mas comprimido y caliente
const CANNON_PEAK := 0.9

# Impacto en chapa (blindaje): clic de ataque + varios parciales inarmonicos que suenan a placa de metal (los agudos
# se apagan antes) + un "clank" de ruido en banda. Claro y tintineante, para confirmar el acierto.
const METAL_TIME := 0.25
const METAL_CLICK_CUTOFF := 4000.0 # pasa-altos del clic de ataque (Hz)
const METAL_CLICK_DECAY := 1200.0
const METAL_CLICK_AMP := 0.7
const METAL_HZ := 1300.0         # tono del primer parcial de la placa
const METAL_PITCH_VARIATION := 0.12 # esta receta varia mas de tono que las demas: cada acierto cae en una chapa distinta
const METAL_RATIOS := [1.0, 2.76, 5.4]   # relacion de cada parcial con el primero: no son armonicos, suena a metal
const METAL_AMPS := [1.0, 0.55, 0.3]     # volumen de cada parcial
const METAL_DECAYS := [45.0, 90.0, 160.0] # rapidez con que se apaga cada parcial (1/s): los agudos antes
const METAL_PING_AMP := 0.5      # volumen del conjunto de parciales
const METAL_CLANK_LOW := 800.0   # banda del "clank" de ruido (Hz)
const METAL_CLANK_HIGH := 3000.0
const METAL_CLANK_DECAY := 120.0
const METAL_CLANK_AMP := 0.4
const METAL_LOWPASS := 9000.0    # pasa-bajos final (Hz): le quita lo mas agudo para que no sea chillon
const METAL_PEAK := 0.7

# Impacto en estructura (fuselaje, voxeles): golpe sordo con caida de tono + crujido de ruido a trozos (grano) +
# unas pocas esquirlas, que son clics sueltos de piezas que saltan. Mas grave, seco y sucio que el de chapa.
const STRUCT_TIME := 0.22
const STRUCT_THUD_HZ := 110.0    # tono base del golpe sordo
const STRUCT_THUD_DROP := 1.0    # cuanto mas agudo empieza (fraccion): arranca al doble
const STRUCT_THUD_DROP_RATE := 40.0
const STRUCT_THUD_DECAY := 55.0
const STRUCT_THUD_AMP := 0.8
const STRUCT_CRUNCH_LOW := 300.0 # banda del crujido (Hz)
const STRUCT_CRUNCH_HIGH := 2500.0
const STRUCT_CRUNCH_DECAY := 35.0
const STRUCT_CRUNCH_AMP := 0.7
const STRUCT_GRAIN_SAMPLES := 40 # cada cuantas muestras cambia el nivel del crujido: lo trocea en granos
const STRUCT_GRAIN_MIN := 0.15   # nivel minimo de un grano (fraccion del maximo)
const STRUCT_SPLINTERS := Vector2i(2, 4)    # cuantas esquirlas (minimo y maximo)
const STRUCT_SPLINTER_WINDOW := 0.07        # tiempo (s) en el que caen
const STRUCT_SPLINTER_LEN := 0.002          # duracion de cada esquirla (s)
const STRUCT_SPLINTER_CUTOFF := 2500.0      # pasa-altos de las esquirlas (Hz)
const STRUCT_SPLINTER_AMP := 0.4
const STRUCT_LOWPASS := 6000.0   # pasa-bajos final (Hz)
const STRUCT_PEAK := 0.75

# Confirmacion de derribo, por capas: golpe final contundente + chasquido + silbido que cae de tono + dos pulsos
# tacticos retro que suben (una quinta). Es lo unico agudo y tonal del combate, para oirse sobre el caos.
const KILL_TIME := 0.36
const KILL_THUMP_HZ := 150.0     # tono base del golpe final
const KILL_THUMP_DROP := 1.0     # cuanto mas agudo empieza (fraccion)
const KILL_THUMP_DROP_RATE := 35.0
const KILL_THUMP_DECAY := 30.0
const KILL_THUMP_AMP := 0.9
const KILL_CRACK_CUTOFF := 2500.0 # pasa-altos del chasquido (Hz)
const KILL_CRACK_DECAY := 350.0
const KILL_CRACK_AMP := 0.6
const KILL_WHISTLE_START := 2600.0 # el silbido empieza en este tono (Hz)...
const KILL_WHISTLE_END := 650.0    # ...y cae hasta este
const KILL_WHISTLE_SWEEP := 11.0   # rapidez de esa caida (1/s)
const KILL_WHISTLE_DECAY := 9.0
const KILL_WHISTLE_AMP := 0.35
const KILL_PULSE_HZ := [880.0, 1320.0]  # tonos de los dos pulsos: una quinta ascendente
const KILL_PULSE_START := [0.07, 0.135] # cuando empieza cada pulso (s)
const KILL_PULSE_LEN := [0.05, 0.12]    # cuanto dura cada uno (s): el segundo se alarga como un "ping"
const KILL_PULSE_ATTACK := 0.004  # entrada de cada pulso (s)
const KILL_PULSE_RELEASE := 0.02  # salida de cada pulso (s)
const KILL_PULSE_AMP := 0.45
const KILL_PULSE_VARIATION := 0.015 # el tono de los pulsos varia poco entre variantes: tiene que sonar siempre a lo mismo
const KILL_DRIVE := 1.2          # saturacion suave final
const KILL_PEAK := 0.85

# Caida de un avion derribado, por etapas: chasquidos de metal al principio, un silbido que cae de tono y un
# chisporroteo electrico que va a mas segun avanza.
const FALL_TIME := 2.5
const FALL_WHINE_START := 1100.0 # el silbido empieza en este tono (Hz)...
const FALL_WHINE_END := 110.0    # ...y cae hasta este
const FALL_WHINE_SWEEP := 1.3    # rapidez de esa caida (1/s)
const FALL_WHINE_DECAY := 1.0    # rapidez con que se apaga el silbido (1/s)
const FALL_WHINE_AMP := 0.4
const FALL_SNAPS := 3            # chasquidos de metal del principio
const FALL_SNAP_WINDOW := 0.45   # tiempo (s) en el que caen
const FALL_SNAP_LEN := 0.006     # duracion de cada uno (s)
const FALL_SNAP_CUTOFF := 1500.0
const FALL_SNAP_AMP := 0.8
const FALL_POP_START := 25.0     # chisporroteos por segundo al principio...
const FALL_POP_END := 160.0      # ...y al final
const FALL_POP_DECAY := 1800.0   # rapidez con que se apaga cada chisporroteo (1/s)
const FALL_POP_CUTOFF := 1200.0
const FALL_POP_AMP := 1.6
const FALL_POP_RAMP := 0.6       # volumen del chisporroteo al principio (fraccion): sube hasta el maximo al final
const FALL_PEAK := 0.6

# Explosion, por capas y en tres tamanos: transitorio seco en t = 0 + cuerpo sub-grave con caida rapida de tono +
# golpe medio de ruido + cola de ruido cuyo pasa-bajos se va cerrando (sin siseo agudo prolongado). Cada lista
# tiene un valor por tamano: pequena (el estallido al derribar un caza), mediana (el del avion pesado) y grande
# (un avion al estrellarse o el del jugador). Mas grande = mas grave, mas larga y con mas cuerpo.
enum Size { SMALL, MEDIUM, LARGE }
const BOOM_TIME := [0.6, 1.0, 1.9]            # duracion (s)
const BOOM_TRANSIENT_CUTOFF := 600.0          # pasa-altos del transitorio (Hz)
const BOOM_TRANSIENT_DECAY := [700.0, 600.0, 500.0]   # el transitorio dura unos milisegundos
const BOOM_TRANSIENT_AMP := [0.9, 1.0, 1.0]
const BOOM_BODY_HZ := [60.0, 48.0, 38.0]      # tono final del cuerpo sub-grave
const BOOM_BODY_DROP := [2.0, 2.5, 3.0]       # cuanto mas agudo empieza (fraccion): arranca a 3, 3,5 o 4 veces el tono final
const BOOM_BODY_DROP_RATE := [28.0, 20.0, 14.0]   # rapidez de esa caida de tono (1/s)
const BOOM_BODY_DECAY := [7.0, 4.0, 2.2]
const BOOM_BODY_AMP := [0.7, 0.9, 1.0]
const BOOM_BLAST_CUTOFF := [900.0, 700.0, 500.0]  # pasa-bajos del golpe medio de ruido (Hz)
const BOOM_BLAST_DECAY := [14.0, 8.0, 4.5]
const BOOM_BLAST_AMP := [0.7, 0.8, 0.9]
const BOOM_TAIL_HIGH := [2200.0, 2000.0, 1800.0]  # corte inicial del pasa-bajos de la cola (Hz)...
const BOOM_TAIL_LOW := 90.0                   # ...que se cierra hasta este
const BOOM_TAIL_SWEEP := [6.0, 3.6, 1.8]      # rapidez con que se cierra (1/s): llega al minimo antes de que acabe la muestra, sin siseo al final
const BOOM_TAIL_DECAY := [5.5, 3.0, 1.8]
const BOOM_TAIL_AMP := [0.6, 0.8, 1.0]
const BOOM_NOISE_GAIN := 3.0                  # compensa lo que el pasa-bajos le quita al volumen del ruido
const BOOM_DRIVE := 1.4                       # saturacion suave final: pega las capas y da peso
const BOOM_PEAK := 0.95

## Disparo de ametralladora.
static func machine_gun(rng: RandomNumberGenerator, _variant: int) -> AudioStreamWAV:
	var s := SynthKit.buffer(MG_TIME, RATE_SHORT)
	var click_cutoff := SynthKit.vary(rng, MG_CLICK_CUTOFF, VARIATION)
	var ring_hz := SynthKit.vary(rng, MG_RING_HZ, VARIATION)
	var ring_phase := rng.randf_range(0.0, TAU)
	var body_hz := SynthKit.vary(rng, MG_BODY_HZ, VARIATION)
	var click_hp := SynthKit.OnePole.new()
	var crack_hp := SynthKit.OnePole.new()
	var crack_lp := SynthKit.OnePole.new()
	var body_phase := 0.0
	for i in s.size():
		var t := float(i) / RATE_SHORT
		var click := click_hp.highpass(SynthKit.white(rng), click_cutoff, RATE_SHORT) * SynthKit.decay(t, MG_CLICK_DECAY) * MG_CLICK_AMP
		var ring := (sin(TAU * ring_hz * t + ring_phase) + 0.6 * sin(TAU * ring_hz * MG_RING_RATIO * t)) * SynthKit.decay(t, MG_RING_DECAY) * MG_RING_AMP
		var crack := crack_lp.lowpass(crack_hp.highpass(SynthKit.white(rng), MG_CRACK_LOW, RATE_SHORT), MG_CRACK_HIGH, RATE_SHORT) \
				* SynthKit.decay(t, MG_CRACK_DECAY) * MG_CRACK_AMP
		body_phase += TAU * body_hz * (1.0 + MG_BODY_DROP * SynthKit.decay(t, MG_BODY_DROP_RATE)) / RATE_SHORT
		var body := sin(body_phase) * SynthKit.decay(t, MG_BODY_DECAY) * MG_BODY_AMP
		s[i] = click + ring + crack + body
	return SynthKit.to_wav(SynthKit.finish(s, MG_PEAK, RATE_SHORT), RATE_SHORT)

## Disparo de canon.
static func cannon(rng: RandomNumberGenerator, _variant: int) -> AudioStreamWAV:
	var s := SynthKit.buffer(CANNON_TIME, RATE_SHORT)
	var body_hz := SynthKit.vary(rng, CANNON_BODY_HZ, VARIATION)
	var tail_high := SynthKit.vary(rng, CANNON_TAIL_HIGH, VARIATION)
	var crack_hp := SynthKit.OnePole.new()
	var thud_lp := SynthKit.OnePole.new()
	var tail_lp := SynthKit.OnePole.new()
	var body_phase := 0.0
	for i in s.size():
		var t := float(i) / RATE_SHORT
		var crack := crack_hp.highpass(SynthKit.white(rng), CANNON_CRACK_CUTOFF, RATE_SHORT) * SynthKit.decay(t, CANNON_CRACK_DECAY) * CANNON_CRACK_AMP
		body_phase += TAU * body_hz * (1.0 + CANNON_BODY_DROP * SynthKit.decay(t, CANNON_BODY_DROP_RATE)) / RATE_SHORT
		var body := (sin(body_phase) * CANNON_BODY_AMP * SynthKit.decay(t, CANNON_BODY_DECAY)
				+ sin(2.0 * body_phase) * CANNON_OVERTONE_AMP * SynthKit.decay(t, CANNON_OVERTONE_DECAY))
		var thud := thud_lp.lowpass(SynthKit.white(rng), CANNON_THUD_CUTOFF, RATE_SHORT) * SynthKit.decay(t, CANNON_THUD_DECAY) * CANNON_THUD_AMP
		var tail_cutoff := maxf(CANNON_TAIL_LOW, tail_high * SynthKit.decay(t, CANNON_TAIL_SWEEP))
		var tail := tail_lp.lowpass(SynthKit.white(rng), tail_cutoff, RATE_SHORT) * SynthKit.decay(t, CANNON_TAIL_DECAY) * CANNON_TAIL_AMP
		s[i] = SynthKit.saturate(crack + body + thud + tail, CANNON_DRIVE)
	return SynthKit.to_wav(SynthKit.finish(s, CANNON_PEAK, RATE_SHORT), RATE_SHORT)

## Impacto de bala en chapa metalica.
static func metal_hit(rng: RandomNumberGenerator, _variant: int) -> AudioStreamWAV:
	var s := SynthKit.buffer(METAL_TIME, RATE_SHORT)
	var hz := SynthKit.vary(rng, METAL_HZ, METAL_PITCH_VARIATION)
	var phases: Array[float] = []
	for m in METAL_RATIOS.size():
		phases.append(rng.randf_range(0.0, TAU))
	var click_hp := SynthKit.OnePole.new()
	var clank_hp := SynthKit.OnePole.new()
	var clank_lp := SynthKit.OnePole.new()
	var final_lp := SynthKit.OnePole.new()
	for i in s.size():
		var t := float(i) / RATE_SHORT
		var click := click_hp.highpass(SynthKit.white(rng), METAL_CLICK_CUTOFF, RATE_SHORT) * SynthKit.decay(t, METAL_CLICK_DECAY) * METAL_CLICK_AMP
		var ping := 0.0
		for m in METAL_RATIOS.size():
			ping += sin(TAU * hz * METAL_RATIOS[m] * t + phases[m]) * METAL_AMPS[m] * SynthKit.decay(t, METAL_DECAYS[m])
		var clank := clank_lp.lowpass(clank_hp.highpass(SynthKit.white(rng), METAL_CLANK_LOW, RATE_SHORT), METAL_CLANK_HIGH, RATE_SHORT) \
				* SynthKit.decay(t, METAL_CLANK_DECAY) * METAL_CLANK_AMP
		s[i] = final_lp.lowpass(click + ping * METAL_PING_AMP + clank, METAL_LOWPASS, RATE_SHORT)
	return SynthKit.to_wav(SynthKit.finish(s, METAL_PEAK, RATE_SHORT), RATE_SHORT)

## Impacto de bala en fuselaje o estructura de voxeles.
static func structure_hit(rng: RandomNumberGenerator, _variant: int) -> AudioStreamWAV:
	var s := SynthKit.buffer(STRUCT_TIME, RATE_SHORT)
	var thud_hz := SynthKit.vary(rng, STRUCT_THUD_HZ, VARIATION)
	# esquirlas: instantes en los que salta una pieza
	var splinter_starts: Array[int] = []
	for k in rng.randi_range(STRUCT_SPLINTERS.x, STRUCT_SPLINTERS.y):
		splinter_starts.append(int(rng.randf_range(0.0, STRUCT_SPLINTER_WINDOW) * RATE_SHORT))
	var splinter_len := int(STRUCT_SPLINTER_LEN * RATE_SHORT)
	var crunch_hp := SynthKit.OnePole.new()
	var crunch_lp := SynthKit.OnePole.new()
	var splinter_hp := SynthKit.OnePole.new()
	var final_lp := SynthKit.OnePole.new()
	var thud_phase := 0.0
	var grain := 1.0
	for i in s.size():
		var t := float(i) / RATE_SHORT
		thud_phase += TAU * thud_hz * (1.0 + STRUCT_THUD_DROP * SynthKit.decay(t, STRUCT_THUD_DROP_RATE)) / RATE_SHORT
		var thud := sin(thud_phase) * SynthKit.decay(t, STRUCT_THUD_DECAY) * STRUCT_THUD_AMP
		if i % STRUCT_GRAIN_SAMPLES == 0:
			grain = rng.randf_range(STRUCT_GRAIN_MIN, 1.0)
		var crunch := crunch_lp.lowpass(crunch_hp.highpass(SynthKit.white(rng), STRUCT_CRUNCH_LOW, RATE_SHORT), STRUCT_CRUNCH_HIGH, RATE_SHORT) \
				* grain * SynthKit.decay(t, STRUCT_CRUNCH_DECAY) * STRUCT_CRUNCH_AMP
		var splinters := 0.0
		for start in splinter_starts:
			if i >= start and i < start + splinter_len:
				splinters += splinter_hp.highpass(SynthKit.white(rng), STRUCT_SPLINTER_CUTOFF, RATE_SHORT) \
						* (1.0 - float(i - start) / splinter_len) * STRUCT_SPLINTER_AMP
		s[i] = final_lp.lowpass(thud + crunch + splinters, STRUCT_LOWPASS, RATE_SHORT)
	return SynthKit.to_wav(SynthKit.finish(s, STRUCT_PEAK, RATE_SHORT), RATE_SHORT)

## Explosion de un tamano (SfxRecipes.Size).
static func explosion(rng: RandomNumberGenerator, _variant: int, size: int) -> AudioStreamWAV:
	var s := SynthKit.buffer(BOOM_TIME[size], RATE_LONG)
	var body_hz := SynthKit.vary(rng, BOOM_BODY_HZ[size], VARIATION)
	var tail_high := SynthKit.vary(rng, BOOM_TAIL_HIGH[size], VARIATION)
	var transient_hp := SynthKit.OnePole.new()
	var blast_lp := SynthKit.OnePole.new()
	var tail_lp := SynthKit.OnePole.new()
	var body_phase := 0.0
	for i in s.size():
		var t := float(i) / RATE_LONG
		var transient: float = transient_hp.highpass(SynthKit.white(rng), BOOM_TRANSIENT_CUTOFF, RATE_LONG) * SynthKit.decay(t, BOOM_TRANSIENT_DECAY[size]) * BOOM_TRANSIENT_AMP[size]
		body_phase += TAU * body_hz * (1.0 + BOOM_BODY_DROP[size] * SynthKit.decay(t, BOOM_BODY_DROP_RATE[size])) / RATE_LONG
		var body: float = sin(body_phase) * SynthKit.decay(t, BOOM_BODY_DECAY[size]) * BOOM_BODY_AMP[size]
		var blast: float = blast_lp.lowpass(SynthKit.white(rng), BOOM_BLAST_CUTOFF[size], RATE_LONG) * SynthKit.decay(t, BOOM_BLAST_DECAY[size]) * BOOM_BLAST_AMP[size] * BOOM_NOISE_GAIN
		var tail_cutoff := maxf(BOOM_TAIL_LOW, tail_high * SynthKit.decay(t, BOOM_TAIL_SWEEP[size]))
		var tail: float = tail_lp.lowpass(SynthKit.white(rng), tail_cutoff, RATE_LONG) * SynthKit.decay(t, BOOM_TAIL_DECAY[size]) * BOOM_TAIL_AMP[size] * BOOM_NOISE_GAIN
		s[i] = SynthKit.saturate(transient + body + blast + tail, BOOM_DRIVE)
	return SynthKit.to_wav(SynthKit.finish(s, BOOM_PEAK, RATE_LONG), RATE_LONG)

## Confirmacion de derribo del jugador.
static func kill_confirm(rng: RandomNumberGenerator, _variant: int) -> AudioStreamWAV:
	var s := SynthKit.buffer(KILL_TIME, RATE_SHORT)
	var thump_hz := SynthKit.vary(rng, KILL_THUMP_HZ, VARIATION)
	var whistle_start := SynthKit.vary(rng, KILL_WHISTLE_START, VARIATION)
	var pulse_scale := 1.0 + rng.randf_range(-KILL_PULSE_VARIATION, KILL_PULSE_VARIATION)
	var crack_hp := SynthKit.OnePole.new()
	var thump_phase := 0.0
	var whistle_phase := 0.0
	for i in s.size():
		var t := float(i) / RATE_SHORT
		thump_phase += TAU * thump_hz * (1.0 + KILL_THUMP_DROP * SynthKit.decay(t, KILL_THUMP_DROP_RATE)) / RATE_SHORT
		var thump := sin(thump_phase) * SynthKit.decay(t, KILL_THUMP_DECAY) * KILL_THUMP_AMP
		var crack := crack_hp.highpass(SynthKit.white(rng), KILL_CRACK_CUTOFF, RATE_SHORT) * SynthKit.decay(t, KILL_CRACK_DECAY) * KILL_CRACK_AMP
		var whistle_hz := KILL_WHISTLE_END + (whistle_start - KILL_WHISTLE_END) * SynthKit.decay(t, KILL_WHISTLE_SWEEP)
		whistle_phase += TAU * whistle_hz / RATE_SHORT
		var whistle := sin(whistle_phase) * SynthKit.decay(t, KILL_WHISTLE_DECAY) * KILL_WHISTLE_AMP
		var pulses := 0.0
		for p in KILL_PULSE_HZ.size():
			var local: float = t - KILL_PULSE_START[p]
			if local >= 0.0 and local < KILL_PULSE_LEN[p]:
				# pulso retro: onda casi cuadrada (impares) con entrada y salida cortas
				var w: float = TAU * KILL_PULSE_HZ[p] * pulse_scale * local
				var tone := sin(w) + sin(3.0 * w) / 3.0 + sin(5.0 * w) / 5.0
				var gate := minf(local / KILL_PULSE_ATTACK, 1.0) * minf((KILL_PULSE_LEN[p] - local) / KILL_PULSE_RELEASE, 1.0)
				pulses += tone * gate * KILL_PULSE_AMP
		s[i] = SynthKit.saturate(thump + crack + whistle + pulses, KILL_DRIVE)
	return SynthKit.to_wav(SynthKit.finish(s, KILL_PEAK, RATE_SHORT), RATE_SHORT)

## Caida de un avion derribado.
static func fall(rng: RandomNumberGenerator, _variant: int) -> AudioStreamWAV:
	var s := SynthKit.buffer(FALL_TIME, RATE_LONG)
	var whine_start := SynthKit.vary(rng, FALL_WHINE_START, VARIATION)
	var snap_len := int(FALL_SNAP_LEN * RATE_LONG)
	var snaps: Array[int] = []
	for k in FALL_SNAPS:
		snaps.append(int(rng.randf_range(0.0, FALL_SNAP_WINDOW) * RATE_LONG))
	var snap_hp := SynthKit.OnePole.new()
	var pop_hp := SynthKit.OnePole.new()
	var pop_keep := exp(-FALL_POP_DECAY / RATE_LONG)
	var whine_phase := 0.0
	var pop_env := 0.0
	for i in s.size():
		var t := float(i) / RATE_LONG
		var progress := t / FALL_TIME
		var whine_hz := FALL_WHINE_END + (whine_start - FALL_WHINE_END) * SynthKit.decay(t, FALL_WHINE_SWEEP)
		whine_phase += TAU * whine_hz / RATE_LONG
		var whine := (sin(whine_phase) + 0.3 * sin(2.0 * whine_phase)) * FALL_WHINE_AMP * SynthKit.decay(t, FALL_WHINE_DECAY)
		var snap := 0.0
		for start in snaps:
			if i >= start and i < start + snap_len:
				snap += snap_hp.highpass(SynthKit.white(rng), FALL_SNAP_CUTOFF, RATE_LONG) * (1.0 - float(i - start) / snap_len) * FALL_SNAP_AMP
		if rng.randf() < lerpf(FALL_POP_START, FALL_POP_END, progress) / RATE_LONG:
			pop_env = rng.randf_range(0.4, 1.0)
		pop_env *= pop_keep
		var pop := pop_hp.highpass(SynthKit.white(rng), FALL_POP_CUTOFF, RATE_LONG) * pop_env * FALL_POP_AMP * lerpf(FALL_POP_RAMP, 1.0, progress)
		s[i] = whine + snap + pop
	return SynthKit.to_wav(SynthKit.finish(s, FALL_PEAK, RATE_LONG), RATE_LONG)
