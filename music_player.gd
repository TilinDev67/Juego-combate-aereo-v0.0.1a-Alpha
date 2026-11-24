## Musica del juego: genera la marcha de cada pais con ChipSynth en un hilo aparte (para no congelar el juego)
## y la reproduce en bucle por su propio bus. Las ya generadas se guardan, asi que cambiar de avion y volver es instantaneo.
class_name MusicPlayer
extends Node

const MUSIC_DB := -14.0          # volumen de la musica (dB): de fondo, por debajo de los efectos
const SILENT_DB := -60.0         # volumen de silencio (dB)
const FADE_IN := 1.5             # segundos que tarda en subir al empezar
const FADE_OUT := 0.6            # segundos que tarda en bajar al parar

var _player := AudioStreamPlayer.new()
var _cache: Dictionary = {}      # pais -> AudioStreamWAV ya generado
var _thread: Thread              # hilo que esta generando una partitura (null si ninguno)
var _rendering := ""             # pais que se esta generando
var _queued := ""                # siguiente pais a generar, si llega otro pedido mientras se genera
var _wanted := ""                # pais que debe sonar ahora ("" = silencio)
var _fade: Tween

func _ready() -> void:
	_player.bus = AudioMixer.BUS_MUSIC
	add_child(_player)

func _exit_tree() -> void:
	if _thread != null:
		_thread.wait_to_finish()

## Empieza a generar la musica de un pais en segundo plano si aun no esta lista (se llama al elegir avion en el menu,
## para que ya este cuando se empiece la partida).
func prepare(country: String) -> void:
	if _cache.has(country) or _rendering == country:
		return
	if _thread != null:
		_queued = country
		return
	_rendering = country
	_thread = Thread.new()
	_thread.start(ChipSynth.render.bind(MusicScores.score(country)))

## Pone a sonar la musica de un pais: al momento si ya esta generada, o en cuanto termine de generarse.
func play(country: String) -> void:
	_wanted = country
	if _cache.has(country):
		_start(country)
	else:
		prepare(country)

## Baja la musica y la para.
func stop() -> void:
	_wanted = ""
	if not _player.playing:
		return
	_fade_to(SILENT_DB, FADE_OUT)
	_fade.tween_callback(_player.stop)

func _process(_delta: float) -> void:
	if _thread == null or _thread.is_alive():
		return
	_cache[_rendering] = _thread.wait_to_finish()
	_thread = null
	var done := _rendering
	_rendering = ""
	if _wanted == done:
		_start(done)
	if _queued != "":
		var next := _queued
		_queued = ""
		prepare(next)

func _start(country: String) -> void:
	if _player.playing and _player.stream == _cache[country]:
		return
	_player.stream = _cache[country]
	_player.volume_db = SILENT_DB
	_player.play()
	_fade_to(MUSIC_DB, FADE_IN)

func _fade_to(db: float, seconds: float) -> void:
	if _fade != null:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_player, "volume_db", db, seconds)
