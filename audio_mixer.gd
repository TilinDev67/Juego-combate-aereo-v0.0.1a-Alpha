## Mezcla del juego: crea los buses de audio (efectos y motor), pone un compresor a los efectos y un limitador
## al final de todo, y permite bajar el motor un momento ("ducking") cuando suena algo muy fuerte.
## Asi, aunque haya muchas explosiones, disparos e impactos a la vez, la suma no recorta ni se vuelve un muro de ruido.
class_name AudioMixer
extends Node

const BUS_SFX := &"SFX"                  # disparos, impactos, derribos y explosiones
const BUS_ENGINE := &"Engine"            # motor del jugador, de los enemigos y viento
const BUS_MUSIC := &"Music"              # musica de fondo; igual que el motor, se baja con el ducking
const COMP_THRESHOLD_DB := -3.0          # nivel (dB) a partir del cual el compresor de los efectos empieza a actuar: alto, para que un
                                         # solo disparo no se toque y solo comprima cuando se acumulan muchos sonidos
const COMP_RATIO := 3.0                  # cuanto comprime por encima de ese nivel (3 = por cada 3 dB de mas sale 1)
const COMP_ATTACK_US := 500.0            # lo rapido que reacciona (microsegundos): deja pasar el primer medio milisegundo del golpe
const COMP_RELEASE_MS := 200.0           # lo que tarda en soltar (ms)
const LIMITER_CEILING_DB := -1.0         # techo del limitador final (dB): nada pasa de aqui
const SILENT_DB := -80.0                 # volumen que se oye como silencio (dB)
const LIMITER_THRESHOLD_DB := -3.0       # nivel (dB) a partir del cual el limitador empieza a redondear los picos

var _duck_tween: Tween
var _engine_amp: AudioEffectAmplify   # volumen del usuario para el motor: va en un efecto porque el ducking ya usa el volumen del bus
var _music_amp: AudioEffectAmplify    # igual, para la musica

## Crea los buses y los efectos. Es seguro llamarla mas de una vez: solo actua la primera.
func setup() -> void:
	if AudioServer.get_bus_index(BUS_SFX) != -1:
		return
	_add_bus(BUS_SFX)
	var comp := AudioEffectCompressor.new()
	comp.threshold = COMP_THRESHOLD_DB
	comp.ratio = COMP_RATIO
	comp.attack_us = COMP_ATTACK_US
	comp.release_ms = COMP_RELEASE_MS
	AudioServer.add_bus_effect(AudioServer.get_bus_index(BUS_SFX), comp)
	_add_bus(BUS_ENGINE)
	_engine_amp = AudioEffectAmplify.new()
	AudioServer.add_bus_effect(AudioServer.get_bus_index(BUS_ENGINE), _engine_amp)
	_add_bus(BUS_MUSIC)
	_music_amp = AudioEffectAmplify.new()
	AudioServer.add_bus_effect(AudioServer.get_bus_index(BUS_MUSIC), _music_amp)
	var limiter := AudioEffectLimiter.new()
	limiter.ceiling_db = LIMITER_CEILING_DB
	limiter.threshold_db = LIMITER_THRESHOLD_DB
	AudioServer.add_bus_effect(0, limiter)

## Volumen del motor y el viento de 0 (silencio) a 1 (normal), sin tocar el ducking.
func set_engine_volume(volume: float) -> void:
	_engine_amp.volume_db = _volume_to_db(volume)

## Volumen de la musica de 0 (silencio) a 1 (normal), sin tocar el ducking.
func set_music_volume(volume: float) -> void:
	_music_amp.volume_db = _volume_to_db(volume)

func _volume_to_db(volume: float) -> float:
	return linear_to_db(volume) if volume > 0.0 else SILENT_DB

func _add_bus(bus_name: StringName) -> void:
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, bus_name)
	AudioServer.set_bus_send(i, &"Master")

## Baja el motor, el viento y la musica "amount_db" (negativo) de golpe, los mantiene "hold" segundos y los devuelve a su
## volumen en "release" segundos. Si ya estan mas bajos que eso, no los sube.
func duck(amount_db: float, hold: float, release: float) -> void:
	if amount_db >= 0.0:
		return
	var engine_bus := AudioServer.get_bus_index(BUS_ENGINE)
	var music_bus := AudioServer.get_bus_index(BUS_MUSIC)
	var level := minf(amount_db, AudioServer.get_bus_volume_db(engine_bus))
	if _duck_tween != null:
		_duck_tween.kill()
	_set_ducked(engine_bus, music_bus, level)
	_duck_tween = create_tween()
	_duck_tween.tween_interval(hold)
	_duck_tween.tween_method(func(v: float) -> void: _set_ducked(engine_bus, music_bus, v), level, 0.0, release)

func _set_ducked(engine_bus: int, music_bus: int, db: float) -> void:
	AudioServer.set_bus_volume_db(engine_bus, db)
	AudioServer.set_bus_volume_db(music_bus, db)
