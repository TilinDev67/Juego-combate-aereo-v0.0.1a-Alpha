## Limite de voces de una categoria de sonidos (impactos, explosiones...): evita que decenas de reproductores
## suenen a la vez. Cuando esta lleno, un sonido nuevo solo entra si es mas fuerte que el mas flojo que suena ahora
## (al que le quita el sitio); si es aun mas flojo, no suena. Ademas baja la ganancia de cada sonido nuevo segun
## cuantos suenan ya, para que la suma no crezca sin limite.
class_name VoiceLimit
extends RefCounted

## Una voz que suena: su reproductor y lo fuerte que se oye (dB, ya con la distancia).
class Voice:
	var player: Node
	var loudness: float

var max_voices: int                # cuantas voces caben a la vez
var crowd_db_per_doubling: float   # lo que baja la ganancia por cada vez que se duplica el numero de voces (dB)
var _voices: Array[Voice] = []

func _init(max_count: int, crowd_db: float) -> void:
	max_voices = max_count
	crowd_db_per_doubling = crowd_db

## Cuantas voces suenan ahora.
func active() -> int:
	_prune()
	return _voices.size()

## Ajuste de ganancia (dB, cero o negativo) para un sonido nuevo: 0 con una voz o ninguna, y baja
## "crowd_db_per_doubling" cada vez que se duplica el numero de voces (2 voces = 1 paso, 4 = 2 pasos...).
func crowd_db() -> float:
	var n := active()
	return 0.0 if n < 2 else -crowd_db_per_doubling * log(float(n)) / log(2.0)

## Pregunta si cabe un sonido de esa fuerza (dB). Si esta lleno, le quita el sitio a la voz mas floja siempre que la
## nueva sea mas fuerte (en un empate se va la mas antigua, que es la primera de la lista); si no, devuelve false.
func admit(loudness: float) -> bool:
	_prune()
	if _voices.size() < max_voices:
		return true
	var weakest := 0
	for i in _voices.size():
		if _voices[i].loudness < _voices[weakest].loudness:
			weakest = i
	if _voices[weakest].loudness >= loudness:
		return false
	var victim := _voices[weakest]
	victim.player.stop()
	victim.player.queue_free()
	_voices.remove_at(weakest)
	return true

## Anota una voz que acaba de empezar a sonar.
func add(player: Node, loudness: float) -> void:
	var v := Voice.new()
	v.player = player
	v.loudness = loudness
	_voices.append(v)

## Olvida las voces que ya han terminado (su reproductor se libera al acabar).
func _prune() -> void:
	var alive: Array[Voice] = []
	for v in _voices:
		if is_instance_valid(v.player) and v.player.playing:
			alive.append(v)
	_voices = alive
