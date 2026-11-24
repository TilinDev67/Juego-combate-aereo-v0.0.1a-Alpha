## Sintetizador chiptune: convierte una partitura y un "estilo" en una musica de 8 bits en bucle, generada por codigo.
## El estilo de cada pais decide el arreglo entero: timbre y articulacion de la melodia (ataque corto o ligado), una
## segunda voz en terceras o en octava, el patron del bajo (pedal, alterno, caminante, bordon), los acordes
## (en contratiempo, en corcheas o como colchon), la percusion (patrones de bombo, caja, timbal, plato y bloque, con
## redobles de relleno) y el swing. Todo pasa por dos filtros pasa-bajos para que sea calido y no chillon.
## Solo usa datos locales, asi que es seguro llamarlo desde otro hilo.
class_name ChipSynth
extends RefCounted

const RATE := 11025                  # muestreo (Hz): bajo a proposito, da el sonido de 8 bits y recorta los agudos
const BEATS_PER_BAR := 4             # compas de 4 tiempos
const SLOTS_PER_BAR := 8             # los patrones de percusion tienen una casilla por corchea
const NOTE_ATTACK := 0.004           # entrada de cada nota (s): evita el clic
const NOTE_RELEASE := 0.03           # salida de cada nota (s)
const ARP_RATE := 20.0               # notas por segundo del arpegio de los acordes cortos
const PAD_ARP_RATE := 8.0            # notas por segundo del arpegio del colchon de acordes
const STAB_LENGTH := 0.4             # duracion de un acorde en el tiempo flojo (tiempos)
const OFFBEAT_LENGTH := 0.25         # duracion de un acorde en contratiempo (tiempos)
const PAD_LENGTH := 3.9              # duracion del colchon de acordes (tiempos)
const BASS_SHIFT := -12              # el bajo suena una octava bajo la raiz de la tabla (semitonos)
const CHORD_SHIFT := 12              # los acordes suenan una octava sobre la raiz de la tabla (semitonos)
const CHORD_ROOT_OCTAVE := 3         # octava de la raiz de cada acorde en la tabla
const FIFTH := 7                     # semitonos de una quinta
const SIXTH := 9
const MINOR_SEVENTH := 10
const STAB_DUTY := 0.125             # ciclo del pulso fino de los acordes
const PAD_AMP := 0.06
const OFFBEAT_AMP := 0.10
const STAB_AMP := 0.12
const BASS_HOLD := 3.8               # duracion de la nota larga del bajo de pedal (tiempos)
const BASS_STEP := 0.95              # duracion de una nota del bajo caminante (tiempos)
const BASS_STACCATO := 0.45          # duracion de una nota del bajo alterno (tiempos)
const DRONE_FIFTH_AMP := 0.5         # volumen de la quinta del bordon respecto a la raiz
const ACCENT := 1.0                  # fuerza de un golpe de percusion marcado ("X")
const SOFT := 0.6                    # fuerza de un golpe suave ("x")
const KICK_AMP := 0.5
const KICK_HZ := 55.0                # tono final del bombo (Hz): arranca al doble y cae
const KICK_DECAY := 28.0
const SNARE_AMP := 0.22
const SNARE_CUTOFF := 2500.0         # pasa-bajos del ruido de la caja (Hz): suave, sin siseo
const SNARE_DECAY := 35.0
const TOM_AMP := 0.45
const HAT_AMP := 0.10
const HAT_DECAY := 90.0
const CLICK_AMP := 0.25
const CLICK_HZ := 900.0              # tono del bloque de madera
const CLICK_DECAY := 90.0
const ROLL_SLOTS := 2                # casillas (corcheas) que ocupa un redoble de relleno: el ultimo tiempo del compas
const ROLL_HITS_PER_SLOT := 2        # golpes de caja en cada una
const ROLL_STEP := 0.25              # separacion entre golpes del redoble (tiempos)
const ROLL_EVERY := 4                # un redoble cada tantos compases
const LOWPASS_HZ := 2600.0           # corte de los dos filtros pasa-bajos finales (Hz)
const PEAK := 0.7                    # pico de la mezcla (0..1)
const SEMITONES := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
const MINOR_TRIAD := [0, 3, 7]
const MAJOR_TRIAD := [0, 4, 7]
const HARMONY_CHOICES := [-3, -4]    # terceras por debajo que se prueban para la segunda voz

## Convierte una partitura (ver MusicScores) en un AudioStreamWAV en bucle.
static func render(score: Dictionary) -> AudioStreamWAV:
	var style: Dictionary = score["style"]
	var beat_samples := RATE * 60.0 / float(score["bpm"])
	var melody := _parse_melody(score["melody"])
	var chords := _parse_chords(score["chords"])
	var buf := PackedFloat32Array()
	buf.resize(int(chords.size() * BEATS_PER_BAR * beat_samples))
	var swing: float = style.get("swing", 0.5)
	_lead(buf, melody, style, beat_samples, swing)
	_bass(buf, chords, style["bass"], beat_samples)
	_chords(buf, chords, style["chords"], beat_samples, swing)
	_drums(buf, chords.size(), style["drums"], beat_samples, swing)
	_lowpass(buf)
	_lowpass(buf)
	var top := 0.0
	for v in buf:
		top = maxf(top, absf(v))
	var gain := PEAK / top if top > 0.0 else 0.0
	for i in buf.size():
		buf[i] = buf[i] * gain
	return SynthKit.to_wav(buf, RATE, true)

## Tiempo (en tiempos) con swing: con 0.5 es recto; con mas, la segunda corchea de cada tiempo se retrasa.
static func _swing(beats: float, swing: float) -> float:
	var whole := floorf(beats)
	var frac := beats - whole
	var shifted := frac * 2.0 * swing if frac < 0.5 else swing + (frac - 0.5) * 2.0 * (1.0 - swing)
	return whole + shifted

## Melodia: la voz principal, y si el estilo lo pide una segunda voz en terceras por debajo y un doblado una octava abajo.
static func _lead(buf: PackedFloat32Array, melody: Array, style: Dictionary, beat_samples: float, swing: float) -> void:
	var lead: Dictionary = style["lead"]
	var duty: float = lead.get("duty", 0.5)
	var amp: float = lead.get("amp", 0.3)
	var gap: float = lead.get("gap", 0.05)
	var sustain: float = lead.get("sustain", 0.7)
	var decay: float = lead.get("decay", 3.0)
	var double_amp: float = lead.get("double", 0.0)
	var harmony: Dictionary = style.get("harmony", {})
	var harmony_amp: float = harmony.get("amp", 0.0)
	var cursor := 0.0
	for note in melody:
		var midi: int = note[0]
		var length: float = note[1]
		if midi >= 0:
			var start := _swing(cursor, swing)
			var stop := _swing(cursor + length * (1.0 - gap), swing)
			var first := int(start * beat_samples)
			var count := int((stop - start) * beat_samples)
			_voice(buf, first, count, _freq(midi), duty, amp, false, sustain, decay)
			if double_amp > 0.0:
				_voice(buf, first, count, _freq(midi - 12), 0.0, double_amp, true, sustain, decay)
			if harmony_amp > 0.0:
				var second := _harmonize(midi, harmony["scale"])
				_voice(buf, first, count, _freq(second), float(harmony.get("duty", 0.5)), harmony_amp, false, sustain, decay)
		cursor += length

## Tercera por debajo que cae en la escala (pruebas menor y mayor); si ninguna, la menor.
static func _harmonize(midi: int, scale: Array) -> int:
	for choice in HARMONY_CHOICES:
		if (midi + choice) % 12 in scale:
			return midi + choice
	return midi + HARMONY_CHOICES[0]

## Bajo, segun el patron del estilo: "pedal" (una nota larga), "alt" (raiz y quinta alternas y cortas),
## "walk" (cuatro notas ligadas por compas), "walk6" (igual, terminando en sexta o septima) y "drone" (bordon de quinta).
static func _bass(buf: PackedFloat32Array, chords: Array, bass: Dictionary, beat_samples: float) -> void:
	var pattern: String = bass["pattern"]
	var amp: float = bass.get("amp", 0.34)
	for bar in chords.size():
		var base: int = chords[bar][0] + BASS_SHIFT
		var third: int = chords[bar][1][1]
		var seventh: bool = chords[bar][2]
		var at := int(bar * BEATS_PER_BAR * beat_samples)
		match pattern:
			"pedal":
				_voice(buf, at, int(BASS_HOLD * beat_samples), _freq(base), 0.0, amp, true, 1.0, 0.0)
			"drone":
				_voice(buf, at, int(PAD_LENGTH * beat_samples), _freq(base), 0.0, amp, true, 1.0, 0.0)
				_voice(buf, at, int(PAD_LENGTH * beat_samples), _freq(base + FIFTH), 0.5, amp * DRONE_FIFTH_AMP, false, 1.0, 0.0)
			"alt":
				for b in BEATS_PER_BAR:
					_voice(buf, at + int(b * beat_samples), int(BASS_STACCATO * beat_samples), _freq(base + (0 if b % 2 == 0 else FIFTH)), 0.0, amp, true, 1.0, 0.0)
			_:
				var last: int = MINOR_SEVENTH if (seventh and pattern == "walk6") else (SIXTH if pattern == "walk6" else third)
				var steps := [0, third, FIFTH, last]
				for b in BEATS_PER_BAR:
					_voice(buf, at + int(b * beat_samples), int(BASS_STEP * beat_samples), _freq(base + steps[b]), 0.0, amp, true, 1.0, 0.0)

## Acordes en pulso fino: "afterbeat" (en los tiempos 2 y 4), "offbeat" (en los contratiempos, con swing),
## "pad" (un colchon que dura el compas) o "none".
static func _chords(buf: PackedFloat32Array, chords: Array, spec: Dictionary, beat_samples: float, swing: float) -> void:
	var pattern: String = spec["pattern"]
	if pattern == "none":
		return
	for bar in chords.size():
		var root: int = chords[bar][0] + CHORD_SHIFT
		var tones: Array = []
		for step in chords[bar][1]:
			tones.append(root + step)
		if chords[bar][2]:
			tones.append(root + MINOR_SEVENTH)
		var first_beat := bar * BEATS_PER_BAR
		match pattern:
			"afterbeat":
				for b in [1, 3]:
					_stab(buf, int((first_beat + b) * beat_samples), int(STAB_LENGTH * beat_samples), tones, ARP_RATE, STAB_AMP, false)
			"offbeat":
				for b in BEATS_PER_BAR:
					var t := _swing(first_beat + b + 0.5, swing)
					_stab(buf, int(t * beat_samples), int(OFFBEAT_LENGTH * beat_samples), tones, ARP_RATE, OFFBEAT_AMP, false)
			"pad":
				_stab(buf, int(first_beat * beat_samples), int(PAD_LENGTH * beat_samples), tones, PAD_ARP_RATE, PAD_AMP, true)

## Percusion: un patron de 8 casillas (una por corchea) para cada instrumento; "X" golpe marcado, "x" suave, "." nada.
## Con "fills", el ultimo tiempo de cada cuarto compas lleva un redoble de caja.
static func _drums(buf: PackedFloat32Array, bars: int, drums: Dictionary, beat_samples: float, swing: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var fills: bool = drums.get("fills", false)
	var tom_hz: float = drums.get("tom_hz", 90.0)
	var tom_decay: float = drums.get("tom_decay", 12.0)
	for bar in bars:
		var roll_bar := fills and bar % ROLL_EVERY == ROLL_EVERY - 1
		for slot in SLOTS_PER_BAR:
			var beats := bar * BEATS_PER_BAR + slot * 0.5
			var at := int(_swing(beats, swing) * beat_samples)
			var in_roll := roll_bar and slot >= SLOTS_PER_BAR - ROLL_SLOTS
			for kind in ["kick", "snare", "tom", "hat", "click"]:
				var pattern: String = drums.get(kind, "........")
				var level := _level(pattern[slot])
				if in_roll and kind == "snare":
					continue
				if level <= 0.0:
					continue
				match kind:
					"kick": _kick(buf, at, level)
					"snare": _snare(buf, at, rng, level)
					"tom": _tom(buf, at, level, tom_hz, tom_decay)
					"hat": _hat(buf, at, rng, level)
					"click": _click(buf, at, level)
			if in_roll:
				var total_hits := ROLL_SLOTS * ROLL_HITS_PER_SLOT
				for hit in ROLL_HITS_PER_SLOT:
					var number := (slot - (SLOTS_PER_BAR - ROLL_SLOTS)) * ROLL_HITS_PER_SLOT + hit   # 0.. en todo el redoble
					var ramp := 0.5 + 0.5 * float(number) / float(total_hits - 1)                     # cada golpe mas fuerte que el anterior
					_snare(buf, int(_swing(beats + hit * ROLL_STEP, swing) * beat_samples), rng, ramp)

static func _level(symbol: String) -> float:
	return ACCENT if symbol == "X" else (SOFT if symbol == "x" else 0.0)

## Una nota de onda cuadrada (duty > 0) o triangular con entrada y salida suaves y un decaimiento al nivel "sustain".
static func _voice(buf: PackedFloat32Array, start: int, length: int, freq: float, duty: float, amp: float,
		triangle: bool, sustain: float, decay: float) -> void:
	var step := freq / RATE
	var attack := maxf(NOTE_ATTACK * RATE, 1.0)
	var release := maxf(NOTE_RELEASE * RATE, 1.0)
	var keep := exp(-decay / RATE)
	var level := 1.0
	var phase := 0.0
	for i in length:
		var idx := start + i
		if idx >= buf.size():
			break
		phase += step
		phase -= floorf(phase)
		level *= keep
		var env := minf(float(i) / attack, 1.0) * minf(float(length - i) / release, 1.0) * (sustain + (1.0 - sustain) * level)
		var wave := 4.0 * absf(phase - 0.5) - 1.0 if triangle else (1.0 if phase < duty else -1.0)
		buf[idx] += wave * amp * env

## Acorde como arpegio rapido de pulso fino sobre las notas "tones"; "flat" lo deja sonar parejo (colchon) y si no se apaga.
static func _stab(buf: PackedFloat32Array, start: int, length: int, tones: Array, rate: float, amp: float, flat: bool) -> void:
	var step_len := maxi(int(RATE / rate), 1)
	var phase := 0.0
	var attack := maxf(NOTE_ATTACK * RATE, 1.0)
	var release := maxf(NOTE_RELEASE * RATE, 1.0)
	for i in length:
		var idx := start + i
		if idx >= buf.size():
			break
		var tone: int = tones[int(float(i) / step_len) % tones.size()]
		phase += _freq(tone) / RATE
		phase -= floorf(phase)
		var env := minf(float(i) / attack, 1.0) * (minf(float(length - i) / release, 1.0) if flat else (1.0 - float(i) / length))
		buf[idx] += (1.0 if phase < STAB_DUTY else -1.0) * amp * env

## Bombo: un seno que arranca al doble de su tono y cae.
static func _kick(buf: PackedFloat32Array, start: int, level: float) -> void:
	var phase := 0.0
	for i in int(RATE * 0.18):
		var idx := start + i
		if idx >= buf.size():
			break
		var t := float(i) / RATE
		phase += TAU * KICK_HZ * (1.0 + exp(-t * 40.0)) / RATE
		buf[idx] += sin(phase) * exp(-t * KICK_DECAY) * KICK_AMP * level

## Caja: ruido pasa-bajos que se apaga rapido.
static func _snare(buf: PackedFloat32Array, start: int, rng: RandomNumberGenerator, level: float) -> void:
	var filter := SynthKit.OnePole.new()
	for i in int(RATE * 0.14):
		var idx := start + i
		if idx >= buf.size():
			break
		var t := float(i) / RATE
		buf[idx] += filter.lowpass(rng.randf_range(-1.0, 1.0), SNARE_CUTOFF, RATE) * 2.0 * exp(-t * SNARE_DECAY) * SNARE_AMP * level

## Timbal o tambor grande: un seno afinado que cae un poco, con la duracion que pida el estilo.
static func _tom(buf: PackedFloat32Array, start: int, level: float, hz: float, decay: float) -> void:
	var phase := 0.0
	for i in int(RATE * 0.5):
		var idx := start + i
		if idx >= buf.size():
			break
		var t := float(i) / RATE
		phase += TAU * hz * (1.0 + 0.3 * exp(-t * 30.0)) / RATE
		buf[idx] += sin(phase) * exp(-t * decay) * TOM_AMP * level

## Plato de ritmo: ruido muy corto (los filtros finales lo suavizan).
static func _hat(buf: PackedFloat32Array, start: int, rng: RandomNumberGenerator, level: float) -> void:
	for i in int(RATE * 0.06):
		var idx := start + i
		if idx >= buf.size():
			break
		buf[idx] += rng.randf_range(-1.0, 1.0) * exp(-float(i) / RATE * HAT_DECAY) * HAT_AMP * level

## Bloque de madera: un tono corto que se apaga muy rapido.
static func _click(buf: PackedFloat32Array, start: int, level: float) -> void:
	for i in int(RATE * 0.06):
		var idx := start + i
		if idx >= buf.size():
			break
		var t := float(i) / RATE
		buf[idx] += sin(TAU * CLICK_HZ * t) * exp(-t * CLICK_DECAY) * CLICK_AMP * level

## Pasa-bajos de un polo sobre todo el buffer.
static func _lowpass(buf: PackedFloat32Array) -> void:
	var a := 1.0 - exp(-TAU * LOWPASS_HZ / RATE)
	var y := 0.0
	for i in buf.size():
		y += (buf[i] - y) * a
		buf[i] = y

## Frecuencia (Hz) de una nota MIDI.
static func _freq(midi: int) -> float:
	return 440.0 * pow(2.0, (midi - 69) / 12.0)

## Nota MIDI de un nombre como "C#5" o "Bb4" (C4 = 60).
static func midi_of(name: String) -> int:
	var semitone: int = SEMITONES[name.substr(0, 1)]
	var i := 1
	if name.substr(i, 1) == "#":
		semitone += 1
		i += 1
	elif name.substr(i, 1) == "b":
		semitone -= 1
		i += 1
	return semitone + 12 * (name.substr(i).to_int() + 1)

## Lista de [nota MIDI (-1 = silencio), duracion en tiempos].
static func _parse_melody(text: String) -> Array:
	var notes: Array = []
	for token in text.split(" ", false):
		if token == "|":
			continue
		var parts := token.split(":")
		var midi := -1 if parts[0] == "r" else midi_of(parts[0])
		notes.append([midi, parts[1].to_float()])
	return notes

## Lista de [raiz MIDI (octava CHORD_ROOT_OCTAVE), tonos de la triada, tiene septima] por compas.
static func _parse_chords(text: String) -> Array:
	var chords: Array = []
	for token in text.split(" ", false):
		var root_name := token.substr(0, 1)
		var rest := token.substr(1)
		if rest.begins_with("#") or rest.begins_with("b"):
			root_name += rest.substr(0, 1)
			rest = rest.substr(1)
		var root := midi_of(root_name + str(CHORD_ROOT_OCTAVE))
		chords.append([root, MINOR_TRIAD if rest.begins_with("m") else MAJOR_TRIAD, rest.ends_with("7")])
	return chords
