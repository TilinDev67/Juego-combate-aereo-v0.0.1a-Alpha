## Aviones con IA: enemigos (cazas y bombarderos pesados) y el aliado; aparicion, combate, dano y caida.
class_name AiPlanes
extends Node

const ENEMY_ENGINE_DB := -14.0   # volumen del motor de un avion con IA a 1 unidad de distancia (dB)
const ENEMY_ENGINE_PITCH_MIN := 0.75 # tono del motor de un avion con IA a velocidad minima
const ENEMY_ENGINE_PITCH_MAX := 1.3  # tono del motor de un avion con IA a velocidad maxima
const ENEMY_GUN_DB := -5.0      # volumen de los disparos de los aviones con IA (dB)
const ENEMY_SPREAD := 0.012       # dispersion de los canones de la IA (rad)
const ENEMY_BULLET_SPEED := 900.0 # velocidad de la bala de la IA respecto al avion (m/s)
const ENEMY_MG_RATE_K := 0.4      # cadencia de las ametralladoras de la IA relativa a la del modelo (la IA dispara menos que el jugador)
const ENEMY_MG_DMG_K := 1.0       # dano de una bala de ametralladora de la IA relativo al del modelo
const ENEMY_MG_Z := 1.5           # cuanto por delante del centro (m) salen las balas de ametralladora, como en el avion del jugador
const ENEMY_MG_DB := -8.0         # lo que suena mas bajo la ametralladora de la IA que su canon (dB)
const ENEMY_BULLET_DMG := 6.0     # dano de una bala de caza a corta distancia
const ENEMY_R := 5.0              # radio con el que un avion con IA choca con otro
const ENEMY_TURN_BASE := 0.8     # giro maximo del enemigo al empezar (rad/s)
const ENEMY_TURN_GAIN := 0.05    # aumento del giro por derribo
const ENEMY_TURN_MAX := 1.2      # giro maximo del enemigo (rad/s), cercano al del jugador
const ENEMY_BREAK_DIST := 300.0  # distancia a la que la IA rompe para no embestir (m)
const ENEMY_JINK_TIME := 0.9     # duracion de la maniobra evasiva al ser apuntado (s)
const ENEMY_JINK_SIDE := 0.8     # fuerza lateral de la maniobra evasiva
const ENEMY_THROTTLE := 0.3      # rapidez con que el motor vuelve a su velocidad de crucero (1/s)
const ENEMY_AIM_ERR := 0.03      # error de punteria de la IA (rad, crece con la distancia)
const ENEMY_FIRE_RANGE := 600.0   # distancia a la que un enemigo empieza a disparar (m)
const ENEMY_FIRE_CONE := 0.07     # angulo (rad) respecto al objetivo con el que un enemigo ya dispara
const ENEMY_REST := Vector2(1.2, 2.5) # pausa (min, max) de un enemigo entre rafagas (s), contada desde que acaba la rafaga
const ENEMY_BURST_BREAK := 1.5    # la rafaga se corta si el objetivo sale de este multiplo del cono de disparo
const ENEMY_EXTEND_TIME := 6.0   # tras un pase cercano la IA se aleja en linea recta este tiempo (s)
const ENEMY_MAX_G := 5.5          # G maximas que aguanta la IA al virar: limita su giro (el avion del jugador pasa de 7 G) y, a mas velocidad, vira mas abierto
const ENEMY_SPAWN_DIST := 1600.0  # distancia (m) a la que aparece un enemigo respecto al jugador: el combate empieza lejos
const ENEMY_EXTEND_CLIMB := 0.25 # inclinacion vertical al alejarse (trepa para recuperar energia)
const ENEMY_MUZZLE_DIST := 3.0         # distancia (m) por delante del centro del avion a la que salen sus balas y su fogonazo
const ENEMY_TERRAIN_LOOKAHEAD := 300.0   # distancia (m) por delante a la que un avion con IA mira el relieve para esquivarlo
const ENEMY_CRASH_Y := 1.0         # altura (m) a la que un avion derribado se estrella contra el suelo
const ENEMY_SMOKE_AMOUNT := 120   # particulas de humo de un avion con IA danado
const SMOKE_HEALTH_FRAC := 0.7    # fraccion de salud por debajo de la cual echa humo
const FIRE_HEALTH_FRAC := 0.3     # fraccion de salud por debajo de la cual echa fuego
const DARK_SMOKE_FRAC := 0.25     # fraccion de salud por debajo de la cual el humo es negro

const KIND_FIGHTER := 0           # caza enemigo
const KIND_HEAVY := 1             # cazabombardero pesado enemigo (Ju 87)
const KIND_ALLY := 2              # caza aliado

const FIGHTER_HEALTH := 100.0
const FIGHTER_MODELS := [PlaneModels.BF109, PlaneModels.ZERO, PlaneModels.FW190] # aviones que pilotan los cazas enemigos
const FIGHTER_BURST := 8          # balas por rafaga del caza
const HEAVY_HEALTH := 260.0
const HEAVY_TURN_K := 0.55        # giro del pesado relativo al del caza
const HEAVY_SPEED_K := 0.8        # velocidad de crucero del pesado relativa a la del caza
const HEAVY_BURST := 14           # balas por rafaga del pesado
const HEAVY_BULLET_DMG := 8.0     # dano de una bala del pesado a corta distancia
const HEAVY_EXPLOSION_K := 1.4    # factor de tamano de su explosion
const ALLY_HEALTH := 140.0
const ALLY_CRUISE := 108.0        # velocidad de crucero del aliado (m/s)
const ALLY_TURN := 1.5            # giro maximo del aliado (rad/s)
const ALLY_BREAK_DIST := 70.0     # distancia a la que el aliado rompe para no embestir (m): se acerca mucho mas que un enemigo
const ALLY_AIM_ERR := 0.015       # error de punteria del aliado (rad): mejor que el del enemigo
const ALLY_FIRE_RANGE := 900.0    # distancia a la que el aliado empieza a disparar (m)
const ALLY_FIRE_CONE := 0.12      # angulo (rad) respecto al objetivo con el que el aliado ya dispara
const ALLY_REST := Vector2(0.5, 1.2) # pausa (min, max) del aliado entre rafagas (s)
const ALLY_BURST := 14            # balas por rafaga del aliado
const ALLY_RESPAWN_TIME := 25.0   # segundos hasta que aparece un aliado nuevo tras perder el anterior
const ALLY_SPAWN_OFFSET := Vector3(70.0, 10.0, 60.0) # donde aparece el aliado respecto al jugador (derecha, arriba, detras)
const ALLY_TARGET_BIAS := 1.3     # los enemigos prefieren al jugador: la distancia a un aliado cuenta esta vez mas
const ESCORT_OFFSET := Vector3(60.0, 5.0, 70.0) # sitio de escolta respecto al jugador (derecha, arriba, detras)
const ESCORT_GAIN := 0.3          # cuanto acelera o frena el aliado para mantener su sitio de escolta
const ESCORT_SPEED_RANGE := Vector2(-15.0, 40.0) # diferencia de velocidad respecto al jugador al escoltar (m/s)
const ESCORT_MIN_SPEED := 60.0    # velocidad minima de crucero del aliado en escolta (m/s)
const ROUND_FIGHTERS_BASE := 2        # cazas de la ronda 1; cada ronda suma uno mas
const ROUND_FIGHTERS_MAX := 6         # tope de cazas de una ronda
const ROUND_PER_EXTRA_PLAYER := 1     # cazas extra por cada jugador mas de uno
const ROUND_HEAVY_EVERY := 3          # cada cuantas rondas llega ademas un pesado (la 3, la 6...)
const ROUND_SPAWN_GAP := Vector2(2.5, 4.0)   # segundos (min, max) entre que entra un avion de la ronda y el siguiente
const ROUND_SPREAD := 220.0           # dispersion lateral (m) del grupo, que entra por el mismo lado
const ROUND_BREAK_TIME := 8.0         # pausa (s) tras limpiar una ronda
const ROUND_FIRST_DELAY := 4.0        # espera (s) antes de la ronda 1
const AI_SYNC_RATE := 15.0        # envios por segundo del estado de la IA a los clientes (la lleva el anfitrion)
const AI_INTERP_DELAY := 0.15     # segundos en el pasado a los que un cliente dibuja un avion de la IA (dos intervalos de envio)
const MAX_REPORTED_DMG := 999.0   # dano maximo que el anfitrion acepta en un aviso de impacto de un cliente

class AiPlane:
	var root: Node3D
	var model: Node3D
	var prop: Node3D
	var smoke: CPUParticles3D
	var kind := 0
	var friendly := false            # true = aliado del jugador
	var health := 100.0
	var health_max := 100.0
	var box_half := Vector3.ONE      # caja de impactos (semiejes) y su centro, en ejes del avion
	var box_center := Vector3.ZERO
	var bullet_dmg := 6.0
	var burst_len := 8
	var break_dist := ENEMY_BREAK_DIST   # distancia a la que rompe para no embestir
	var aim_err := ENEMY_AIM_ERR         # error de punteria (rad)
	var fire_range := ENEMY_FIRE_RANGE   # distancia a la que empieza a disparar
	var fire_cone := ENEMY_FIRE_CONE     # angulo con el objetivo con el que ya dispara
	var rest_time := ENEMY_REST          # pausa (min, max) entre rafagas
	var speed := 85.0
	var cruise := 85.0               # velocidad a la que tiende el motor
	var turn_rate := 1.5
	var evading := false
	var state_t := 0.0
	var evade_dir := Vector3.FORWARD
	var roll_dir := 1.0
	var jink_cd := 0.0
	var extend_t := 0.0              # >0: alejandose tras un pase
	var noise_cur := Vector3.ZERO    # error de punteria actual (m)
	var noise_tgt := Vector3.ZERO
	var noise_t := 0.0
	var burst := 0
	var fire_cd := 0.0
	var mg_guns := 0                 # ametralladoras del modelo: 0 = sin, 1 = en el eje, 2 = alternan entre las alas
	var mg_x := 0.0                  # separacion lateral de las ametralladoras respecto al eje (m)
	var mg_dmg := 0.0                # dano de una bala de ametralladora
	var mg_interval := 0.0           # segundos entre balas de ametralladora
	var mg_cd := 0.0                 # tiempo hasta la siguiente bala de ametralladora
	var mg_side := 1.0               # ala de la proxima ametralladora
	var rest := 1.0
	var dead := false
	var dead_t := 0.0
	var fall := 0.0
	var engine_snd: AudioStreamPlayer3D   # motor del avion
	var fire: CPUParticles3D              # llamas del motor con poca salud
	var net_id := 0                       # identificador en red, igual en todos los equipos
	var spec_id := 0                      # modelo (PlaneModels id): los clientes dibujan el mismo
	var interp: NetInterp                 # estados recibidos del anfitrion para dibujarlo suave (solo clientes)

## Objetivo elegido por un avion con IA: donde esta, como se mueve y hacia donde mira.
class Aim:
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var fwd := Vector3.FORWARD
	var found := false               # true = hay un enemigo al que atacar; false = el aliado escolta al jugador
	var idle := false                # true = no hay a quien atacar ni escoltar: sigue recto
	var basis := Basis.IDENTITY      # orientacion del objetivo (para el sitio de escolta)

var g: Game                   # juego: estado central compartido
var enemies: Array[AiPlane] = []
var allies: Array[AiPlane] = []
var ally_cd := 0.0
var starting := true            # true = falta crear al aliado y arrancar la primera cuenta atras
var round_n := 0                # ronda en curso (o la ultima, en la pausa); 0 = aun no ha empezado ninguna
var between := true             # true = pausa entre rondas
var round_cd := 0.0             # segundos que faltan para que empiece la siguiente ronda
var remaining := 0              # enemigos de la ronda sin derribar, vivos y por entrar (los clientes lo reciben)
var queue: Array[int] = []      # tipos de avion que faltan por entrar en esta ronda
var _spawn_cd := 0.0            # segundos hasta que entre el siguiente de la cola
var _group_angle := 0.0         # direccion (rad) por la que entra el grupo de esta ronda
var by_id := {}                 # net_id -> AiPlane
var present := true             # false = en el hangar: los aviones no se ven ni suenan
var _next_id := 1
var _sync_cd := 0.0

## Ficha del avion con ese id de PlaneModels.
func _spec_of(id: int) -> PlaneModels.Spec:
	for sp in g.models:
		if sp.id == id:
			return sp
	return g.models[0]

## Crea un avion con IA del tipo dado, con su modelo, estadisticas, humo, fuego y motor. No lo coloca.
func _make_ai(kind: int, spec_id: int = -1, net_id: int = 0) -> AiPlane:
	var e := AiPlane.new()
	e.kind = kind
	e.friendly = kind == KIND_ALLY
	var base_turn := minf(ENEMY_TURN_BASE + g.score * ENEMY_TURN_GAIN, ENEMY_TURN_MAX)
	var base_cruise := minf(80.0 + g.score * 3.0, 112.0)
	var spec: PlaneModels.Spec
	match kind:
		KIND_HEAVY:
			spec = _spec_of(PlaneModels.STUKA)
			e.root = PlaneModels.build(spec, g.vox, true)
			e.health = HEAVY_HEALTH
			e.bullet_dmg = HEAVY_BULLET_DMG
			e.burst_len = HEAVY_BURST
			e.cruise = base_cruise * HEAVY_SPEED_K
			e.turn_rate = base_turn * HEAVY_TURN_K
		KIND_ALLY:
			spec = _spec_of(PlaneModels.IL2)
			e.root = PlaneModels.build(spec, g.vox)
			e.health = ALLY_HEALTH
			e.bullet_dmg = ENEMY_BULLET_DMG
			e.burst_len = ALLY_BURST
			e.cruise = ALLY_CRUISE
			e.turn_rate = ALLY_TURN
			e.break_dist = ALLY_BREAK_DIST
			e.aim_err = ALLY_AIM_ERR
			e.fire_range = ALLY_FIRE_RANGE
			e.fire_cone = ALLY_FIRE_CONE
			e.rest_time = ALLY_REST
		_:
			var model_id: int = spec_id if spec_id >= 0 else FIGHTER_MODELS[g.rng.randi() % FIGHTER_MODELS.size()]
			spec = _spec_of(model_id)
			e.root = PlaneModels.build(spec, g.vox, true)
			e.health = FIGHTER_HEALTH
			e.bullet_dmg = ENEMY_BULLET_DMG
			e.burst_len = FIGHTER_BURST
			e.cruise = base_cruise
			e.turn_rate = base_turn
	e.spec_id = spec.id
	e.box_half = spec.box_half
	e.box_center = spec.box_center
	if spec.mg_guns > 0:
		e.mg_guns = spec.mg_guns
		e.mg_x = spec.mg_x
		e.mg_dmg = spec.mg_dmg * ENEMY_MG_DMG_K
		e.mg_interval = 1.0 / (spec.mg_rate * ENEMY_MG_RATE_K)
	e.health_max = e.health
	e.speed = e.cruise
	e.model = e.root.get_node("Model")
	e.prop = e.root.get_node("Model/Prop")
	e.smoke = g.fx.make_smoke(1.2)
	e.smoke.amount = ENEMY_SMOKE_AMOUNT
	e.root.add_child(e.smoke)
	e.smoke.position = Vector3(0, 0.3, 3.5)
	e.fire = g.fx.make_fire()
	e.root.add_child(e.fire)
	e.fire.position = Vector3(0, 0.4, -1.5)
	e.engine_snd = g.sound.make_3d_player(g.sound.snd_engine, ENEMY_ENGINE_DB, AudioMixer.BUS_ENGINE)
	e.root.add_child(e.engine_snd)
	e.engine_snd.play()
	add_child(e.root)
	e.jink_cd = 3.0
	e.root.visible = present
	e.engine_snd.stream_paused = not present
	if net_id > 0:
		e.net_id = net_id
	else:
		e.net_id = _next_id
		_next_id += 1
	by_id[e.net_id] = e
	return e

## Enemigo nuevo en un circulo de 900 m alrededor del jugador, mirando hacia el.
func _spawn_enemy(kind: int) -> void:
	var e := _make_ai(kind)
	var anchor := _anchor()
	var dir := Vector3(cos(_group_angle), 0, sin(_group_angle))
	var pos := anchor.origin + dir * ENEMY_SPAWN_DIST + dir.cross(Vector3.UP) * g.rng.randf_range(-ROUND_SPREAD, ROUND_SPREAD)
	pos.y = clampf(anchor.origin.y + g.rng.randf_range(-60, 80), 120.0, 400.0)
	e.root.position = pos
	e.root.look_at(anchor.origin, Vector3.UP)
	enemies.append(e)

## Aliado nuevo junto al jugador, con su mismo rumbo y velocidad.
func _spawn_ally() -> void:
	var e := _make_ai(KIND_ALLY)
	var anchor := _anchor()
	var b := anchor.basis
	e.root.transform = Transform3D(b, anchor.origin + b * ALLY_SPAWN_OFFSET)
	e.speed = g.speed
	allies.append(e)

## Dano a un avion con IA (solo la autoridad: el anfitrion o quien juega solo; los clientes usan request_hit).
## by_player = el disparo es de un jugador (solo esos derribos suman puntos); scorer = id del jugador que lo dispara.
func hit_plane(e: AiPlane, dmg: float, by_player: bool, scorer: int = Net.HOST_ID) -> void:
	if e.dead:
		return
	e.health -= dmg
	if e.health > 0.0:
		return
	e.dead = true
	e.dead_t = 0.0
	e.fall = 0.0
	if e.friendly:
		ally_cd = ALLY_RESPAWN_TIME
	elif by_player:
		g.score += 1
		if scorer == Net.HOST_ID:
			g.add_credits(Shop.KILL_CREDITS)
	if by_player and not e.friendly and scorer == Net.HOST_ID:
		g.sound.play_kill()
	if g.net.is_online():
		_killed.rpc(e.net_id, scorer if by_player else 0)
	g.sound.play_fall(e.root)
	g.fx.explode(e.root.position, _explosion_scale(e, 1.0), -e.root.basis.z * e.speed)

func _explosion_scale(e: AiPlane, base: float) -> float:
	return base * (HEAVY_EXPLOSION_K if e.kind == KIND_HEAVY else 1.0)

func _kill_plane(e: AiPlane) -> void:
	g.fx.explode(e.root.position, _explosion_scale(e, 3.2), -e.root.basis.z * e.speed * 0.7 + Vector3.DOWN * e.fall)
	e.root.queue_free()
	by_id.erase(e.net_id)
	if e.friendly:
		allies.erase(e)
	else:
		enemies.erase(e)

func update_enemies(dt: float) -> void:
	if not g.net.is_authority():
		_update_puppets(dt)
		return
	if starting:
		starting = false
		_spawn_ally()
		round_cd = ROUND_FIRST_DELAY
	_update_round(dt)
	if allies.is_empty():
		ally_cd -= dt
		if ally_cd <= 0.0:
			_spawn_ally()
	_collide_allies_with_enemies()
	for e in enemies.duplicate():
		_update_plane(e, dt)
	for a in allies.duplicate():
		_update_plane(a, dt)
	_broadcast(dt)

## Un aliado y un enemigo que se tocan se destruyen entre si (sin puntos).
func _collide_allies_with_enemies() -> void:
	for a in allies:
		for e in enemies:
			if not a.dead and not e.dead and a.root.position.distance_to(e.root.position) < ENEMY_R * 2.0:
				hit_plane(a, 999.0, false)
				hit_plane(e, 999.0, false)

func _level(e: AiPlane) -> void:
	var f := -e.root.basis.z
	if absf(f.y) > 0.97:
		return
	var r := f.cross(Vector3.UP).normalized()
	var u := r.cross(f)
	e.root.basis = Basis(r, u, -f)

## Elige a quien ataca un avion con IA. Un enemigo va a por el mas cercano entre los jugadores y los
## aliados (prefiere a los jugadores); un aliado, al enemigo mas cercano o, si no hay, escolta al jugador mas cercano.
## Si no hay a quien atacar ni escoltar (nadie en vuelo), idle = true.
func _pick_target(e: AiPlane) -> Aim:
	var best := INF
	if e.friendly:
		var ta := Aim.new()
		for o in enemies:
			if o.dead:
				continue
			var d := e.root.position.distance_to(o.root.position)
			if d < best:
				best = d
				ta.pos = o.root.position
				ta.vel = -o.root.basis.z * o.speed
				ta.fwd = -o.root.basis.z
		ta.found = best < INF
		if not ta.found:
			ta = _nearest_player(e.root.position)
			ta.idle = not ta.found
			ta.found = false
			ta.pos += ta.basis * ESCORT_OFFSET
		return ta
	var t := _nearest_player(e.root.position)
	if t.found:
		best = e.root.position.distance_to(t.pos)
	for o in allies:
		if o.dead:
			continue
		var d := e.root.position.distance_to(o.root.position) * ALLY_TARGET_BIAS
		if d < best:
			best = d
			t.pos = o.root.position
			t.vel = -o.root.basis.z * o.speed
			t.fwd = -o.root.basis.z
			t.found = true
	t.idle = not t.found
	return t

## Jugador en vuelo mas cercano a un punto, entre el propio y los demas; found = false si no hay ninguno.
func _nearest_player(from: Vector3) -> Aim:
	var t := Aim.new()
	var best := INF
	if not g.over and not g.menu_open:
		best = from.distance_to(g.plane.position)
		t.pos = g.plane.position
		t.vel = g.velocity()
		t.basis = g.plane.transform.basis
		t.found = true
	for id in g.pilots.pilots:
		var p: RemotePilots.Pilot = g.pilots.pilots[id]
		if not p.alive or p.root == null:
			continue
		var d := from.distance_to(p.target_pos)
		if d < best:
			best = d
			t.pos = p.target_pos
			t.basis = Basis(p.target_rot)
			t.vel = -t.basis.z * p.speed
			t.found = true
	t.fwd = -t.basis.z
	return t

## Sitio de referencia para que aparezcan aviones: el de un jugador en vuelo; si no hay ninguno, el avion propio.
func _anchor() -> Transform3D:
	var t := _nearest_player(g.plane.position)
	return Transform3D(t.basis, t.pos) if t.found else g.plane.transform

## Efectos de un avion con IA: helice, motor, humo y fuego segun la salud. Los usan tanto el anfitrion como los clientes.
func _update_effects(e: AiPlane, dt: float) -> void:
	e.prop.rotation.z += 35.0 * dt
	if e.dead:
		e.engine_snd.pitch_scale = maxf(e.engine_snd.pitch_scale - dt * 0.3, 0.3)  # motor que se apaga al caer
	else:
		var spd_t := inverse_lerp(Flight.MIN_SPEED, Flight.MAX_SPEED, e.speed)
		e.engine_snd.pitch_scale = lerpf(ENEMY_ENGINE_PITCH_MIN, ENEMY_ENGINE_PITCH_MAX, spd_t)
	var hf := e.health / e.health_max
	e.smoke.emitting = hf < SMOKE_HEALTH_FRAC or e.dead
	e.fire.emitting = e.dead or hf < FIRE_HEALTH_FRAC
	e.smoke.color = Color(0.1, 0.1, 0.1) if (e.dead or hf < DARK_SMOKE_FRAC) else Color(0.6, 0.6, 0.6)

func _update_plane(e: AiPlane, dt: float) -> void:
	var pos := e.root.position
	var fwd := -e.root.basis.z
	_update_effects(e, dt)
	if e.dead:
		e.dead_t += dt
		e.fall += 70.0 * dt
		e.root.basis = e.root.basis.rotated(e.root.basis.x, -0.6 * dt)
		e.model.rotation.z += 5.0 * dt
		e.root.position += fwd * e.speed * 0.7 * dt + Vector3.DOWN * e.fall * dt
		if g.world.altitude(e.root.position) < ENEMY_CRASH_Y or e.dead_t > 5.0:
			_kill_plane(e)
		return

	var t := _pick_target(e)
	var idle := t.idle
	var escorting := e.friendly and not t.found and not idle
	var to_p := t.pos - pos
	var dist := to_p.length()
	var bspeed := ENEMY_BULLET_SPEED + e.speed
	var t_lead := clampf(dist / bspeed, 0.0, 2.5)
	if escorting:
		# mantiene su sitio junto al jugador: acelera si se queda atras y frena si se adelanta
		e.cruise = clampf(g.speed + clampf(dist * ESCORT_GAIN, ESCORT_SPEED_RANGE.x, ESCORT_SPEED_RANGE.y), ESCORT_MIN_SPEED, Flight.MAX_SPEED)
	# energia: trepar frena, picar acelera; el motor tira hacia la velocidad de crucero
	e.speed = clampf(e.speed + ((e.cruise - e.speed) * ENEMY_THROTTLE - fwd.y * Flight.CLIMB_DRAG) * dt, Flight.MIN_SPEED, Flight.MAX_SPEED)
	var auth := clampf(e.speed / Flight.CORNER_SPEED, Flight.AUTH_MIN, Flight.AUTH_MAX)
	# punteria imperfecta: el punto de mira deriva alrededor del objetivo
	e.noise_t -= dt
	if e.noise_t <= 0.0:
		e.noise_t = g.rng.randf_range(0.6, 1.4)
		e.noise_tgt = Vector3(g.rng.randf_range(-1, 1), g.rng.randf_range(-1, 1), g.rng.randf_range(-1, 1)) * dist * e.aim_err
	e.noise_cur = e.noise_cur.lerp(e.noise_tgt, 1.0 - exp(-2.0 * dt))
	var aim := t.pos + t.vel * t_lead * 0.85 + Vector3.UP * 0.5 * Weapons.GRAVITY * t_lead * t_lead + e.noise_cur
	var lead_dir := (aim - pos).normalized()
	var dir := lead_dir

	e.state_t -= dt
	e.jink_cd -= dt
	e.extend_t -= dt
	if e.evading:
		dir = e.evade_dir
		e.model.rotation.z += 6.0 * e.roll_dir * dt
		if e.state_t <= 0.0:
			e.evading = false
	elif idle:
		dir = fwd
	elif escorting:
		dir = to_p.normalized()
	else:
		var side := fwd.cross(Vector3.UP).normalized()
		if e.extend_t > 0.0:
			# tras el pase: se aleja en linea recta y trepa para recuperar energia
			dir = Vector3(fwd.x, ENEMY_EXTEND_CLIMB, fwd.z).normalized()
		elif dist < e.break_dist and fwd.dot(to_p.normalized()) > 0.3:
			# demasiado cerca: pasa de largo y se extiende en vez de embestir
			e.extend_t = ENEMY_EXTEND_TIME
		elif e.jink_cd <= 0.0 and dist < 450.0 and t.fwd.dot(-to_p.normalized()) > 0.985:
			# el objetivo le apunta: maniobra evasiva
			e.evading = true
			e.state_t = ENEMY_JINK_TIME
			var sgn2 := 1.0 if g.rng.randf() < 0.5 else -1.0
			e.roll_dir = sgn2
			e.evade_dir = (fwd + side * sgn2 * ENEMY_JINK_SIDE + Vector3.UP * g.rng.randf_range(-0.4, 0.5)).normalized()
			e.jink_cd = g.rng.randf_range(6.0, 9.0)

	# evitar suelo y techo: la altura se mide sobre el punto mas alto entre donde esta y un poco mas adelante, para subir antes de una colina
	var ahead := pos + fwd * ENEMY_TERRAIN_LOOKAHEAD
	var clearance := pos.y - maxf(g.world.ground_height(pos.x, pos.z), g.world.ground_height(ahead.x, ahead.z))
	if clearance < 90.0:
		dir.y = maxf(dir.y, 0.6)
		dir = dir.normalized()
	if clearance < 45.0:
		dir = Vector3(fwd.x, 1.2, fwd.z).normalized()
	if pos.y > 520.0:
		dir.y = minf(dir.y, -0.3)
		dir = dir.normalized()

	# giro limitado
	var ang := fwd.angle_to(dir)
	var axis := fwd.cross(dir)
	var bank := 0.0
	if axis.length() > 0.0001 and ang > 0.001:
		# el giro lo limita tambien la fuerza G que aguanta el avion: a mas velocidad, curva mas abierta
		var max_rate := minf(e.turn_rate * auth, ENEMY_MAX_G * Flight.GRAVITY_G / maxf(e.speed, Flight.MIN_SPEED))
		var step := minf(ang, max_rate * dt)
		# virar a muchas G le cuesta velocidad, igual que al jugador (Flight.G_BLEED)
		e.speed -= maxf(step / dt * e.speed / Flight.GRAVITY_G - 1.0, 0.0) * Flight.G_BLEED * dt
		e.root.basis = Basis(axis.normalized(), step) * e.root.basis
		bank = clampf(axis.normalized().y * minf(ang * 2.5, 1.0), -1.0, 1.0) * 1.1
	_level(e)
	if not e.evading:
		e.model.rotation.z = lerp_angle(e.model.rotation.z, bank, 5.0 * dt)
	e.root.position += -e.root.basis.z * e.speed * dt

	# disparo en rafagas
	e.fire_cd -= dt
	e.rest -= dt
	var nf := -e.root.basis.z
	if e.burst > 0:
		# la rafaga se corta si el objetivo se le va del cono o del alcance, o si evade o escolta
		if e.evading or escorting or idle or dist > e.fire_range or nf.angle_to(lead_dir) > e.fire_cone * ENEMY_BURST_BREAK:
			e.burst = 0
			e.rest = g.rng.randf_range(e.rest_time.x, e.rest_time.y)
		else:
			if e.mg_guns > 0:
				_fire_mg(e, nf, bspeed, dt)   # las ametralladoras disparan mientras dura la rafaga del canon
			if e.fire_cd <= 0.0:
				e.fire_cd = 0.09
				e.burst -= 1
				var muzzle := e.root.position + nf * ENEMY_MUZZLE_DIST
				g.fx.muzzle_flash(e.root, Vector3(0.0, 0.0, -ENEMY_MUZZLE_DIST), 1.0)
				var shot := g.weapons.scatter(nf, ENEMY_SPREAD) * bspeed
				g.weapons.spawn_bullet(muzzle, shot, e.friendly, e.bullet_dmg, true)
				if g.net.is_online():
					_fired.rpc(e.net_id, muzzle, shot, e.friendly, e.bullet_dmg, true)
				if not g.menu_open:
					g.sound.play_bank_3d(g.sound.bank_cannon, muzzle, ENEMY_GUN_DB, g.sound.limit_gun)
				if e.burst == 0:
					e.rest = g.rng.randf_range(e.rest_time.x, e.rest_time.y)   # la pausa cuenta desde que acaba la rafaga
	elif e.rest <= 0.0 and not escorting and not idle and not e.evading and dist < e.fire_range and nf.angle_to(lead_dir) < e.fire_cone:
		e.burst = e.burst_len

	# colision con el suelo
	if g.world.altitude(e.root.position) < 2.0:
		hit_plane(e, 999.0, false)

## Muestra u oculta a todos los aviones con IA y calla sus motores: mientras el jugador esta en el hangar la batalla
## queda congelada y fuera de vista, y al volver sigue donde estaba.
func set_present(on: bool) -> void:
	present = on
	for list: Array in [enemies, allies]:
		for e: AiPlane in list:
			e.root.visible = on
			e.engine_snd.stream_paused = not on

## Quita todos los aviones con IA; en el siguiente fotograma vuelven a salir todos a la vez.
func reset() -> void:
	for e in enemies:
		e.root.queue_free()
	enemies.clear()
	for a in allies:
		a.root.queue_free()
	allies.clear()
	by_id.clear()
	round_n = 0
	between = true
	round_cd = 0.0
	remaining = 0
	queue.clear()
	starting = true

## Dano a un avion con IA desde cualquier equipo: el anfitrion (o quien juega solo) lo aplica; un cliente se lo avisa al anfitrion.
func request_hit(e: AiPlane, dmg: float, by_player: bool) -> void:
	if g.net.is_authority():
		hit_plane(e, dmg, by_player)
	else:
		_report_hit.rpc_id(Net.HOST_ID, e.net_id, dmg, by_player)

@rpc("any_peer", "call_remote", "reliable")
func _report_hit(id: int, dmg: float, by_player: bool) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	var e: AiPlane = by_id.get(id)
	if e != null and g.pilots.accept_hit(sender, e.root.position, dmg):
		hit_plane(e, clampf(dmg, 0.0, MAX_REPORTED_DMG), by_player, sender)

## El anfitrion manda a los clientes el estado de todos los aviones de la IA.
func _broadcast(dt: float) -> void:
	if not g.net.is_online():
		return
	_sync_cd -= dt
	if _sync_cd > 0.0:
		return
	_sync_cd = 1.0 / AI_SYNC_RATE
	var entries: Array = []
	for list: Array in [enemies, allies]:
		for e: AiPlane in list:
			entries.append([e.net_id, e.kind, e.spec_id, e.root.position, e.root.basis.get_rotation_quaternion(), e.speed, e.health, e.dead])
	_snapshot.rpc(entries, g.score, round_n, between, remaining, round_cd)

## Estado de la IA enviado por el anfitrion: crea los aviones que faltan, actualiza los demas y quita los que ya no estan.
@rpc("authority", "call_remote", "unreliable")
func _snapshot(entries: Array, score: int, round_number: int, in_break: bool, enemies_left: int, countdown: float) -> void:
	g.score = score
	round_n = round_number
	between = in_break
	remaining = enemies_left
	round_cd = countdown
	var now: float = Time.get_ticks_msec() / 1000.0
	var seen := {}
	for entry: Array in entries:
		var id: int = entry[0]
		seen[id] = true
		var e: AiPlane = by_id.get(id)
		if e == null:
			var kind: int = entry[1]
			var spec: int = entry[2]
			e = _make_ai(kind, spec, id)
			e.interp = NetInterp.new(AI_INTERP_DELAY)
			if e.friendly:
				allies.append(e)
			else:
				enemies.append(e)
			e.root.position = entry[3]
			e.root.basis = Basis(entry[4])
		var rot: Quaternion = entry[4]
		var spd: float = entry[5]
		e.speed = spd
		e.health = entry[6]
		e.dead = entry[7]
		e.interp.add(now, entry[3], rot, -Basis(rot).z * spd)
	for id in by_id.keys():
		if not seen.has(id):
			_kill_plane(by_id[id])

## Un cliente dibuja los aviones de la IA interpolando los estados del anfitrion, unos 150 ms en el pasado.
func _update_puppets(dt: float) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	for list: Array in [enemies, allies]:
		for e: AiPlane in list:
			_update_effects(e, dt)
			if not e.interp.is_empty():
				e.root.transform = e.interp.sample(now)

## Un avion de la IA muere: los clientes oyen y ven la caida y el jugador que lo derribo oye la confirmacion.
@rpc("authority", "call_remote", "reliable")
func _killed(id: int, scorer: int) -> void:
	var e: AiPlane = by_id.get(id)
	if e == null:
		return
	e.dead = true
	if scorer == g.net.my_id() and not e.friendly:
		g.add_credits(Shop.KILL_CREDITS)
	if not present:
		return
	if scorer == g.net.my_id() and not e.friendly:
		g.sound.play_kill()
	g.sound.play_fall(e.root)
	g.fx.explode(e.root.position, _explosion_scale(e, 1.0), -e.root.basis.z * e.speed)

## Una bala de ametralladora de un avion con IA: sale de un ala (alternando) o del eje, con su fogonazo pequeno.
## Va aparte del canon porque tiene su propia cadencia, y el avion la dispara solo mientras dura la rafaga.
func _fire_mg(e: AiPlane, nf: Vector3, bspeed: float, dt: float) -> void:
	e.mg_cd -= dt
	if e.mg_cd > 0.0:
		return
	e.mg_cd = e.mg_interval
	e.mg_side = -e.mg_side
	var local := Vector3(0.0 if e.mg_guns == 1 else e.mg_x * e.mg_side, -0.2, -ENEMY_MG_Z)
	var muzzle := e.root.position + e.root.basis * local
	g.fx.muzzle_flash(e.root, local, Weapons.MG_FLASH_SCALE)
	var shot := g.weapons.scatter(nf, Weapons.MG_SPREAD) * bspeed
	g.weapons.spawn_bullet(muzzle, shot, e.friendly, e.mg_dmg, false)
	if g.net.is_online():
		_fired.rpc(e.net_id, muzzle, shot, e.friendly, e.mg_dmg, false)
	if not g.menu_open:
		g.sound.play_bank_3d(g.sound.bank_mg, muzzle, ENEMY_GUN_DB + ENEMY_MG_DB, g.sound.limit_gun)

## Disparo de un avion de la IA: los clientes ven la bala (la danina cada uno si le da a su avion).
@rpc("authority", "call_remote", "unreliable")
func _fired(net_id: int, pos: Vector3, vel: Vector3, friendly: bool, dmg: float, heavy: bool) -> void:
	if g.menu_open:
		return
	g.weapons.spawn_bullet(pos, vel, friendly, dmg, heavy, false, friendly)
	var shooter: AiPlane = by_id.get(net_id)
	if shooter != null and not shooter.dead:   # el fogonazo cuelga del avion para que lo siga mientras dura
		g.fx.muzzle_flash(shooter.root, shooter.root.to_local(pos), 1.0 if heavy else Weapons.MG_FLASH_SCALE)
	if heavy:
		g.sound.play_bank_3d(g.sound.bank_cannon, pos, ENEMY_GUN_DB, g.sound.limit_gun)
	else:
		g.sound.play_bank_3d(g.sound.bank_mg, pos, ENEMY_GUN_DB + ENEMY_MG_DB, g.sound.limit_gun)

## Las batallas son por rondas: cada ronda es un grupo de cazas (y a veces un pesado) que entra por el mismo lado, uno
## tras otro con unos segundos entre medias. Al derribarlos a todos hay una pausa y empieza la siguiente, con un caza mas.
func _update_round(dt: float) -> void:
	if between:
		remaining = 0
		round_cd -= dt
		if round_cd <= 0.0:
			_start_round()
		return
	_spawn_cd -= dt
	if not queue.is_empty() and _spawn_cd <= 0.0:
		_spawn_enemy(queue.pop_front())
		_spawn_cd = g.rng.randf_range(ROUND_SPAWN_GAP.x, ROUND_SPAWN_GAP.y)
	var alive := 0
	for e in enemies:
		if not e.dead:
			alive += 1
	remaining = queue.size() + alive
	if remaining == 0:
		between = true
		round_cd = ROUND_BREAK_TIME

func _start_round() -> void:
	round_n += 1
	between = false
	var players := maxi(g.net.roster.size(), 1)
	var fighters := mini(ROUND_FIGHTERS_BASE + round_n - 1 + (players - 1) * ROUND_PER_EXTRA_PLAYER, ROUND_FIGHTERS_MAX)
	queue.clear()
	for i in fighters:
		queue.append(KIND_FIGHTER)
	if round_n % ROUND_HEAVY_EVERY == 0:
		queue.insert(mini(2, fighters), KIND_HEAVY)   # el pesado entra tras los dos primeros cazas
	_group_angle = g.rng.randf_range(0.0, TAU)
	_spawn_cd = 0.0
