class_name Synth
extends RefCounted
## Sonidos continuos generados por codigo (sin archivos de audio): el motor y el viento, en bucle.
## Los efectos puntuales (disparos, impactos, explosiones) estan en SfxRecipes.

const RATE := 22050            # frecuencia de muestreo (Hz)
const ENGINE_HZ := 80          # tono base del motor: entero para que el bucle de 1 s no tenga corte
const ENGINE_HARMONICS := 8    # armonicos del motor
const WIND_SMOOTH := 0.12      # suavizado del ruido del viento (menor = mas grave)

## Motor de helice: armonicos del tono base con un latido de cilindros, en bucle de 1 s.
static func engine() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var s := SynthKit.buffer(1.0, RATE)
	for i in s.size():
		var t: float = float(i) / RATE
		var v := 0.0
		for h in range(1, ENGINE_HARMONICS + 1):
			v += sin(TAU * ENGINE_HZ * h * t + h * 0.7) / pow(float(h), 1.2)
		var beat: float = 0.75 + 0.25 * sin(TAU * ENGINE_HZ * 0.5 * t)
		s[i] = v * beat * 0.35 + rng.randf_range(-1.0, 1.0) * 0.05
	return SynthKit.to_wav(s, RATE, true)

## Viento: ruido suavizado en bucle.
static func wind() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var s := SynthKit.buffer(1.0, RATE)
	var y := 0.0
	for i in s.size():
		y += (rng.randf_range(-1.0, 1.0) - y) * WIND_SMOOTH
		s[i] = y * 1.6
	return SynthKit.to_wav(s, RATE, true)
