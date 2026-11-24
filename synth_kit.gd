## Kit de sintesis procedimental: ruido, filtros de un polo, variacion aleatoria y el cierre de cada muestra
## (normalizacion y fundidos de pocos milisegundos para que no haya clics). Lo usan las recetas de sonido.
class_name SynthKit
extends RefCounted

const FADE_IN_MS := 0.3          # fundido de entrada (ms): casi instantaneo para no perder el golpe, pero sin clic
const FADE_OUT_MS := 2.0         # fundido de salida (ms): el final de la muestra siempre llega a cero

## Filtro de un polo: pasa-bajos o pasa-altos segun el metodo. Cada instancia guarda su propio estado,
## asi que hace falta una por filtro y por muestra generada. Encadenando uno de cada se obtiene un pasa-banda.
class OnePole:
	var y := 0.0

	## Deja pasar lo grave: el cutoff (Hz) puede cambiar en cada muestra para hacer barridos.
	func lowpass(x: float, cutoff: float, rate: float) -> float:
		y += (x - y) * (1.0 - exp(-TAU * cutoff / rate))
		return y

	## Deja pasar lo agudo: lo que queda al quitarle a la entrada su parte grave.
	func highpass(x: float, cutoff: float, rate: float) -> float:
		y += (x - y) * (1.0 - exp(-TAU * cutoff / rate))
		return x - y

## Lista de muestras a cero de "seconds" segundos.
static func buffer(seconds: float, rate: int) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(int(rate * seconds))
	return s

## Ruido blanco (-1..1).
static func white(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(-1.0, 1.0)

## Valor "base" cambiado al azar hasta una fraccion "amount" (0.05 = mas o menos un 5 %).
static func vary(rng: RandomNumberGenerator, base: float, amount: float) -> float:
	return base * (1.0 + rng.randf_range(-amount, amount))

## Saturacion suave (tanh): redondea los picos y da cuerpo y pegada sin recortar de golpe. Con "drive" bajo casi no
## cambia la senal; con mas, se comprime y se calienta. Mantiene el pico en 1.
static func saturate(x: float, drive: float) -> float:
	return tanh(x * drive) / tanh(drive)

## Envolvente de decaimiento exponencial: 1 en t = 0 y cae a 1/e cada 1/decay segundos.
static func decay(t: float, rate_per_s: float) -> float:
	return exp(-t * rate_per_s)

## Cierra una muestra: aplica los fundidos de entrada y salida y despues la lleva a un pico de "peak", asi el pico
## final es exactamente el pedido aunque el golpe mas fuerte caiga en el fundido de entrada.
static func finish(samples: PackedFloat32Array, peak: float, rate: int) -> PackedFloat32Array:
	var fade_in := maxi(int(rate * FADE_IN_MS / 1000.0), 1)
	var fade_out := maxi(int(rate * FADE_OUT_MS / 1000.0), 1)
	var n := samples.size()
	var top := 0.0
	for i in n:
		var v := samples[i]
		if i < fade_in:
			v *= float(i) / fade_in
		if i >= n - fade_out:
			v *= float(n - 1 - i) / fade_out
		samples[i] = v
		top = maxf(top, absf(v))
	if top > 0.0:
		var gain := peak / top
		for i in n:
			samples[i] = samples[i] * gain
	return samples

## Convierte muestras (-1..1) en un AudioStreamWAV mono de 16 bits, opcionalmente en bucle.
static func to_wav(samples: PackedFloat32Array, rate: int, loop: bool = false) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	var d := PackedByteArray()
	d.resize(samples.size() * 2)
	for i in samples.size():
		d.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	w.data = d
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w
