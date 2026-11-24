## Sonido: reproductores del motor y el viento, conjunto de efectos y sonidos posicionales.
class_name GameSound
extends Node

const MASTER_DB := -12.0         # volumen general (dB): el sonido queda de fondo
const SFX_POOL := 12            # reproductores para sonidos que se solapan (disparos)
const ENGINE_DB_IDLE := -22.0   # volumen del motor al ralenti (dB)
const ENGINE_DB_FULL := -8.0    # volumen del motor a todo gas (dB)
const ENGINE_PITCH_IDLE := 0.7  # tono del motor al ralenti (multiplo del base)
const ENGINE_PITCH_FULL := 1.6  # tono del motor a todo gas
const WIND_DB_MAX := -10.0      # volumen del viento a velocidad maxima (dB)
const SILENT_DB := -80.0        # volumen de silencio (dB)
const UNIT_SIZE := 80.0         # distancia (m) a la que un sonido del mundo pierde 6 dB, comun a todos (unit_size 3D)
const MAX_DISTANCE := 3000.0    # distancia (m) a partir de la cual un sonido del mundo no se oye
const MAX_IMPACTS := 8          # voces simultaneas maximas de cada categoria: con mas, el mas flojo se va
const MAX_EXPLOSIONS := 4
const MAX_ENEMY_GUNS := 6
const MAX_FALLS := 4
const CROWD_DB := 1.5           # lo que baja la ganancia de un sonido nuevo cada vez que se duplica el numero de voces de su categoria (dB)
const DUCK_DB := [0.0, -3.0, -8.0]  # cuanto se baja el motor con una explosion pequena, mediana y grande (dB)
const DUCK_HOLD := 0.25         # segundos que se mantiene bajado
const DUCK_RELEASE := 0.8       # segundos que tarda en volver
const CANNON_VARIANTS := 6      # variantes generadas de cada efecto (cuantas mas, menos se repite)
const MG_VARIANTS := 8
const METAL_VARIANTS := 6
const STRUCT_VARIANTS := 6
const BOOM_VARIANTS := 3          # variantes de cada tamano de explosion
const KILL_VARIANTS := 3
const FALL_VARIANTS := 2
const IMPACT_DB := Vector2(-14.0, -3.0)     # volumen (dB) de un impacto de severidad minima y maxima
const IMPACT_PITCH := Vector2(1.12, 0.88)   # tono de un impacto de severidad minima y maxima: los fuertes suenan mas graves
const IMPACT_FILTER_RANGE := 600.0          # distancia (m) a la que un impacto suena mas apagado
const IMPACT_CUTOFF_NEAR := 20500.0         # corte del filtro de distancia de un impacto cercano (Hz): 20500 = sin filtro
const IMPACT_CUTOFF_FAR := 2500.0           # corte del filtro de uno lejano (Hz)
const IMPACT_LAYER_SEVERITY := 0.6          # severidad a partir de la cual un impacto en chapa suma tambien el crujido de estructura
const IMPACT_LAYER_DELAY := 0.012           # retraso (s) de esa segunda capa
const IMPACT_LAYER_DB := -4.0               # lo que baja esa segunda capa (dB)
const EXPLOSION_SMALL_MAX := 1.2            # escala de explosion (la del efecto visual) hasta la que cuenta como pequena
const EXPLOSION_MEDIUM_MAX := 2.5           # hasta la que cuenta como mediana; por encima, grande
const EXPLOSION_DB := [-1.0, 2.0, 4.0]      # volumen (dB) de una explosion pequena, mediana y grande
const EXPLOSION_UNIT_SIZE := [60.0, 100.0, 180.0]  # alcance con el que se oye cada tamano (unit_size 3D): las grandes se oyen de mas lejos
const EXPLOSION_FILTER_RANGE := 1500.0      # distancia (m) a la que una explosion suena mas apagada
const EXPLOSION_CUTOFF_NEAR := 20500.0      # corte del filtro de distancia de una explosion cercana (Hz): 20500 = sin filtro
const EXPLOSION_CUTOFF_FAR := 1200.0        # corte de una lejana (Hz): solo queda el retumbo
const KILL_DB := 3.0                        # volumen (dB) de la confirmacion de derribo: por encima del resto para oirse en el combate
const KILL_PITCH_VARIATION := 0.02          # su tono varia muy poco: tiene que sonar siempre igual de reconocible
const KILL_GAIN_VARIATION_DB := 0.5
const FALL_DB := -8.0                       # volumen (dB) de la caida de un avion derribado
const PITCH_VARIATION := 0.05   # tono al azar de cada reproduccion (0.05 = mas o menos un 5 %)
const GAIN_VARIATION_DB := 1.0  # volumen al azar de cada reproduccion (dB)
const GUN_STAGGER := Vector2(0.004, 0.014)  # desfase (s) minimo y maximo entre un canon y el siguiente de la misma descarga
const GUN_LAYER_DB := 3.0       # lo que baja cada canon cuando hay varios disparando a la vez (dB)
const BANK_SEED := 100         # semilla base de los bancos: las variantes salen igual en cada arranque

var g: Game                   # juego: estado central compartido
var engine_snd: AudioStreamPlayer
var wind_snd: AudioStreamPlayer
var sfx_pool: Array[AudioStreamPlayer] = []
var sfx_i := 0                    # siguiente reproductor del conjunto
var snd_engine: AudioStreamWAV
var bank_cannon: SfxBank
var bank_mg: SfxBank
var bank_metal: SfxBank
var bank_struct: SfxBank
var banks_boom: Array[SfxBank] = []   # una por tamano de explosion (SfxRecipes.Size)
var bank_kill: SfxBank
var bank_fall: SfxBank
var kill_snd: AudioStreamPlayer       # reproductor propio de la confirmacion de derribo: ningun otro efecto se la puede quitar
var guns_volume := 1.0                # volumen de los disparos de 0 a 1 (opcion del menu de pausa)
var mixer := AudioMixer.new()         # buses, compresor, limitador y ducking
var limit_impact := VoiceLimit.new(MAX_IMPACTS, CROWD_DB)
var limit_explosion := VoiceLimit.new(MAX_EXPLOSIONS, CROWD_DB)
var limit_gun := VoiceLimit.new(MAX_ENEMY_GUNS, CROWD_DB)       # canones enemigos
var limit_fall := VoiceLimit.new(MAX_FALLS, CROWD_DB)

## Crea los sonidos por codigo (bancos de variantes de los efectos) y los reproductores (motor y viento en bucle,
## y un conjunto para efectos).
func build_audio() -> void:
	AudioServer.set_bus_volume_db(0, MASTER_DB)
	add_child(mixer)
	mixer.setup()
	bank_cannon = SfxBank.new(CANNON_VARIANTS, SfxRecipes.cannon, PITCH_VARIATION, GAIN_VARIATION_DB, BANK_SEED)
	bank_mg = SfxBank.new(MG_VARIANTS, SfxRecipes.machine_gun, PITCH_VARIATION, GAIN_VARIATION_DB, BANK_SEED + 1)
	bank_metal = SfxBank.new(METAL_VARIANTS, SfxRecipes.metal_hit, PITCH_VARIATION, GAIN_VARIATION_DB, BANK_SEED + 2)
	bank_struct = SfxBank.new(STRUCT_VARIANTS, SfxRecipes.structure_hit, PITCH_VARIATION, GAIN_VARIATION_DB, BANK_SEED + 4)
	for size in 3:
		banks_boom.append(SfxBank.new(BOOM_VARIANTS, SfxRecipes.explosion.bind(size), PITCH_VARIATION, GAIN_VARIATION_DB, BANK_SEED + 7 + size))
	bank_kill = SfxBank.new(KILL_VARIANTS, SfxRecipes.kill_confirm, KILL_PITCH_VARIATION, KILL_GAIN_VARIATION_DB, BANK_SEED + 5)
	bank_fall = SfxBank.new(FALL_VARIANTS, SfxRecipes.fall, PITCH_VARIATION, GAIN_VARIATION_DB, BANK_SEED + 6)
	kill_snd = AudioStreamPlayer.new()
	kill_snd.bus = AudioMixer.BUS_SFX
	add_child(kill_snd)
	engine_snd = AudioStreamPlayer.new()
	engine_snd.bus = AudioMixer.BUS_ENGINE
	snd_engine = Synth.engine()
	engine_snd.stream = snd_engine
	engine_snd.volume_db = SILENT_DB   # arranca en silencio: update_audio no corre hasta el primer paso de fisica
	add_child(engine_snd)
	engine_snd.play()
	wind_snd = AudioStreamPlayer.new()
	wind_snd.bus = AudioMixer.BUS_ENGINE
	wind_snd.stream = Synth.wind()
	wind_snd.volume_db = SILENT_DB
	add_child(wind_snd)
	wind_snd.play()
	for i in SFX_POOL:
		var p := AudioStreamPlayer.new()
		p.bus = AudioMixer.BUS_SFX
		add_child(p)
		sfx_pool.append(p)

## Reproduce un efecto en el siguiente reproductor del conjunto (rotativo).
func play_sfx(stream: AudioStream, db: float, pitch: float = 1.0) -> void:
	var p := sfx_pool[sfx_i]
	sfx_i = (sfx_i + 1) % sfx_pool.size()
	p.stream = stream
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()

## Reproduce una variante al azar de un banco, con su tono y volumen al azar (sonido no posicional).
## Con "delay" (s) empieza un poco mas tarde.
func play_bank(bank: SfxBank, db: float, delay: float = 0.0) -> void:
	if guns_volume <= 0.0:
		return
	var stream := bank.pick()
	var gain := db + bank.gain_db() + linear_to_db(guns_volume)
	var pitch := bank.pitch_scale()
	if delay <= 0.0:
		play_sfx(stream, gain, pitch)
	else:
		get_tree().create_timer(delay).timeout.connect(func() -> void: play_sfx(stream, gain, pitch))

## Descarga de varios canones a la vez: cada uno suena con su propia variante y un desfase de pocos milisegundos
## respecto al anterior, como suenan de verdad dos armas que no son perfectamente simultaneas. Con mas de uno,
## cada capa baja GUN_LAYER_DB para que la suma no suene mas fuerte que un solo canon.
func play_volley(bank: SfxBank, guns: int, db: float) -> void:
	var layer_db := 0.0 if guns <= 1 else -GUN_LAYER_DB
	for k in guns:
		play_bank(bank, db + layer_db, k * randf_range(GUN_STAGGER.x, GUN_STAGGER.y))

## Igual, pero posicional en el mundo; con "limit" cuenta para el limite de voces de su categoria.
func play_bank_3d(bank: SfxBank, pos: Vector3, db: float, limit: VoiceLimit = null) -> void:
	if guns_volume <= 0.0:
		return
	play_3d(bank.pick(), pos, db + bank.gain_db() + linear_to_db(guns_volume), bank.pitch_scale(), 0.0, 0.0, limit)

## Reproductor 3D con el alcance y el efecto Doppler comunes a todos los sonidos del mundo. Va al bus de efectos,
## salvo los de motor, que van al suyo para poder bajarlos con el ducking.
func make_3d_player(stream: AudioStream, db: float, bus: StringName = AudioMixer.BUS_SFX) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = db
	p.bus = bus
	p.unit_size = UNIT_SIZE
	p.max_distance = MAX_DISTANCE
	p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	return p

## Lo fuerte (dB) que se oye un sonido del mundo desde la camara: su volumen menos lo que pierde con la distancia.
func loudness_at(db: float, pos: Vector3, unit_size: float) -> float:
	var unit := unit_size if unit_size > 0.0 else UNIT_SIZE
	return db - 20.0 * log(maxf(g.cam.position.distance_to(pos) / unit, 1.0)) / log(10.0)

## Reproduce un efecto posicional en el mundo y lo libera al terminar. Con "limit", la categoria tiene un tope de
## voces: si esta llena, el sonido solo entra si es mas fuerte que el mas flojo (que se corta), y su volumen baja
## segun cuantos suenan ya.
func play_3d(stream: AudioStream, pos: Vector3, db: float, pitch: float = 1.0, cutoff_hz: float = 0.0,
		unit_size: float = 0.0, limit: VoiceLimit = null) -> void:
	var gain := db
	var loud := 0.0
	if limit != null:
		gain += limit.crowd_db()
		loud = loudness_at(gain, pos, unit_size)
		if not limit.admit(loud):
			return
	var p := make_3d_player(stream, gain)
	add_child(p)
	p.pitch_scale = pitch
	if unit_size > 0.0:
		p.unit_size = unit_size
	if cutoff_hz > 0.0:
		p.attenuation_filter_cutoff_hz = cutoff_hz
	p.position = pos
	p.play()
	p.finished.connect(p.queue_free)
	if limit != null:
		limit.add(p, loud)

## Confirmacion de derribo: un sonido tonal y reconocible, no posicional, que se oye por encima del combate.
## Si cae otro derribo mientras suena el anterior, lo reinicia.
func play_kill() -> void:
	kill_snd.stream = bank_kill.pick()
	kill_snd.pitch_scale = bank_kill.pitch_scale()
	kill_snd.volume_db = KILL_DB + bank_kill.gain_db()
	kill_snd.play()

## Caida de un avion derribado: chasquidos, un silbido que cae de tono y chisporroteo. Va pegado al avion, asi que
## lo sigue mientras cae, y se corta solo cuando el avion desaparece.
func play_fall(plane_root: Node3D) -> void:
	var gain := FALL_DB + bank_fall.gain_db() + limit_fall.crowd_db()
	var loud := loudness_at(gain, plane_root.position, 0.0)
	if not limit_fall.admit(loud):
		return
	var p := make_3d_player(bank_fall.pick(), gain)
	p.pitch_scale = bank_fall.pitch_scale()
	plane_root.add_child(p)
	p.play()
	limit_fall.add(p, loud)

## Explosion en un punto del mundo. "scale" es la del efecto visual: segun ella suena pequena, mediana o grande (mas
## grave, larga y fuerte). Las grandes se oyen de mas lejos, y las lejanas suenan mas apagadas: solo llega el retumbo.
func play_explosion(pos: Vector3, scale: float) -> void:
	var size := 0 if scale < EXPLOSION_SMALL_MAX else (1 if scale < EXPLOSION_MEDIUM_MAX else 2)
	var bank := banks_boom[size]
	var far := clampf(g.cam.position.distance_to(pos) / EXPLOSION_FILTER_RANGE, 0.0, 1.0)
	var cutoff := lerpf(EXPLOSION_CUTOFF_NEAR, EXPLOSION_CUTOFF_FAR, far)
	mixer.duck(DUCK_DB[size] * (1.0 - far), DUCK_HOLD, DUCK_RELEASE)   # el motor se agacha menos cuanto mas lejos estalla
	play_3d(bank.pick(), pos, EXPLOSION_DB[size] + bank.gain_db(), bank.pitch_scale(), cutoff, EXPLOSION_UNIT_SIZE[size], limit_explosion)

## Impacto de bala en un punto del mundo. "severity" (0..1) es lo fuerte que es el golpe: sube el volumen y baja el
## tono. Un impacto lejano suena mas apagado y flojo. "metal" elige el sonido de chapa (tintineo claro, para
## confirmar el acierto) o el de estructura (golpe sordo y crujiente); un golpe de chapa muy fuerte suma tambien
## el crujido de estructura un instante despues.
func play_impact(pos: Vector3, severity: float, metal: bool) -> void:
	var sev := clampf(severity, 0.0, 1.0)
	var db := lerpf(IMPACT_DB.x, IMPACT_DB.y, sev)
	var pitch := lerpf(IMPACT_PITCH.x, IMPACT_PITCH.y, sev)
	var far := clampf(g.cam.position.distance_to(pos) / IMPACT_FILTER_RANGE, 0.0, 1.0)
	var cutoff := lerpf(IMPACT_CUTOFF_NEAR, IMPACT_CUTOFF_FAR, far)
	var bank := bank_metal if metal else bank_struct
	play_3d(bank.pick(), pos, db + bank.gain_db(), pitch * bank.pitch_scale(), cutoff, 0.0, limit_impact)
	if metal and sev >= IMPACT_LAYER_SEVERITY:
		var layer := bank_struct.pick()
		var layer_db := db + IMPACT_LAYER_DB + bank_struct.gain_db()
		var layer_pitch := pitch * bank_struct.pitch_scale()
		get_tree().create_timer(IMPACT_LAYER_DELAY).timeout.connect(func() -> void: play_3d(layer, pos, layer_db, layer_pitch, cutoff, 0.0, limit_impact))

## Motor y viento segun gas y velocidad.
func update_audio() -> void:
	if g.over or g.menu_open:
		engine_snd.volume_db = SILENT_DB
		wind_snd.volume_db = SILENT_DB
		return
	var speed_t := inverse_lerp(Flight.MIN_SPEED, g.player_spec.max_speed, g.speed)
	var rev := clampf(g.throttle * 0.7 + speed_t * 0.3, 0.0, 1.0)
	engine_snd.pitch_scale = lerpf(ENGINE_PITCH_IDLE, ENGINE_PITCH_FULL, rev)
	engine_snd.volume_db = lerpf(ENGINE_DB_IDLE, ENGINE_DB_FULL, g.throttle)
	wind_snd.pitch_scale = lerpf(0.8, 1.4, speed_t)
	wind_snd.volume_db = linear_to_db(maxf(speed_t * speed_t, 0.0001)) + WIND_DB_MAX
