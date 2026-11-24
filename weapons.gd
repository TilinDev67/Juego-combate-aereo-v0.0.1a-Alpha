## Armas: disparo, recarga, balas, impactos sobre las cajas de los aviones y punteria asistida.
class_name Weapons
extends Node

const RELOAD_TIME := 2.0
const BULLET_SPEED := 1100.0
const BULLET_DRAG := 0.1          # perdida de velocidad de la bala por el aire (1/s)
const CANNON_BULLET_SIZE := Vector3(0.22, 0.22, 20.0) # tamano de la trazadora de canon (m): fina y larga
const MG_BULLET_SIZE := Vector3(0.14, 0.14, 10.0)    # tamano de la trazadora de ametralladora (m)
const MG_HALO_SIZE := Vector3(0.5, 0.5, 14.0)        # tamano del halo de la trazadora de ametralladora (m)
const HALO_SIZE := Vector3(0.8, 0.8, 30.0)           # tamano del halo que rodea a la trazadora de canon (m)
const BULLET_GLOW := 40.0         # brillo del nucleo de las trazadoras: alto para que el bloom las envuelva aunque sean finas
const HALO_GLOW := 8.0            # brillo del halo aditivo
const BULLET_BLOOM_BRIGHTNESS := 3.5   # brillo del cartel de resplandor de una bala: muy por encima del umbral del bloom (2,5), asi el bloom lo envuelve
const BULLET_BLOOM_MIN_SIZE := 1.8     # tamano minimo (m) del cartel de resplandor de una bala cercana
const BULLET_BLOOM_ANGLE := 0.0035     # tamano angular minimo (rad) de ese cartel: de lejos la bala sigue viendose como un punto brillante
const BULLET_SPREAD := 0.004      # dispersion de los canones del jugador (rad)
const GUN_CONVERGE := 400.0       # distancia a la que se cruzan los disparos de las dos alas (m)
const MG_FLASH_SCALE := 0.45      # tamano del fogonazo de una ametralladora respecto al de un canon
const MG_SPREAD := 0.012          # dispersion de las ametralladoras (rad)
const DMG_FALLOFF_START := 600.0  # distancia recorrida (m) a partir de la que baja el dano
const DMG_FALLOFF_END := 1800.0   # distancia (m) a la que el dano llega al minimo
const DMG_FALLOFF_MIN := 0.5      # fraccion minima de dano a larga distancia
const GRAVITY := 32.0           # caida de las balas (m/s^2)
const IMPACT_FULL_DMG := 12.0     # dano de un impacto a partir del cual suena con la severidad maxima
const LEAD_RANGE := 1200.0       # distancia maxima (m) a la que se marca un objetivo con indicador de adelanto
const LEAD_CONE := 0.3            # angulo maximo (rad) entre el morro y el punto de adelanto para marcar un objetivo
const LOCK_CONE := 0.05           # angulo (rad) por debajo del cual el objetivo esta fijado (el morro ya apunta a su adelanto)
const LEAD_EPSILON := 0.001       # por debajo de esto la ecuacion de intercepcion se trata como lineal

class Bullet:
	var node: MeshInstance3D
	var vel: Vector3
	var life := 1.8
	var friendly := true             # true = del jugador o del aliado (dana a los enemigos); false = enemiga
	var by_player := false           # disparada por el jugador: cuenta para puntos y marcador de impacto
	var remote := false              # copia de un disparo ajeno (otro jugador o aliado de la IA): solo se ve, no dana
	var travel := 0.0               # distancia recorrida (m)
	var dmg := 0.0                  # dano a corta distancia
	var glow: MeshInstance3D         # cartel de resplandor que crece con la distancia a la camara

var g: Game                   # juego: estado central compartido
var bullets: Array[Bullet] = []
var ammo := 0                   # descargas que quedan en el cargador
var reloading := false
var reload_t := 0.0
var fire_cd := 0.0
var mg_cd := 0.0                 # tiempo hasta el siguiente disparo de ametralladora
var mg_side := 1.0               # ala de la proxima ametralladora
var target_locked := false       # el morro apunta ya al adelanto del objetivo marcado
var lead_target: AiPlanes.AiPlane   # enemigo marcado: el mas cercano al morro dentro del cono; null si no hay
var lead_pos := Vector3.ZERO     # punto del mundo al que apuntar para acertar al objetivo marcado
var bullet_mesh: BoxMesh
var bullet_mat_p: StandardMaterial3D
var bullet_mat_e: StandardMaterial3D
var mg_mesh: BoxMesh              # bala de ametralladora: fina y corta
var halo_mesh: BoxMesh
var mg_halo_mesh: BoxMesh         # halo de la trazadora de ametralladora
var halo_mat_p: StandardMaterial3D
var halo_mat_e: StandardMaterial3D
var bloom_mesh: QuadMesh           # cartel de resplandor de las balas, de 1 m de lado (se escala por bala)
var bloom_mat_p: StandardMaterial3D
var bloom_mat_e: StandardMaterial3D

func glow_mat(c: Color, energy: float = 3.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m

# halo aditivo alrededor del nucleo de la bala (da cuerpo al bloom)
func halo_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, 0.35)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = HALO_GLOW
	return m

## Cartel de resplandor de una bala: redondo, aditivo y siempre de cara a la camara. Su brillo supera el umbral del bloom,
## asi la bala brilla aunque la trazadora sea fina o este lejos.
func bloom_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true   # sin esto el cartel ignora su escala, y la escala es lo que lo agranda con la distancia
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = FxGen.glow()
	m.albedo_color = Color(c.r * BULLET_BLOOM_BRIGHTNESS, c.g * BULLET_BLOOM_BRIGHTNESS, c.b * BULLET_BLOOM_BRIGHTNESS)
	return m

## Marca el enemigo mas cercano al morro (por su punto de adelanto) y lo da por fijado si el morro ya apunta a el.
func check_lock() -> void:
	target_locked = false
	lead_target = null
	var fwd := -g.plane.transform.basis.z
	var best := LEAD_CONE
	for e in g.ai.enemies:
		if e.dead:
			continue
		var point := lead_point(e)
		var to := point - g.plane.position
		if to.length() > LEAD_RANGE:
			continue
		var ang := fwd.angle_to(to)
		if ang < best:
			best = ang
			lead_target = e
			lead_pos = point
	target_locked = lead_target != null and best < LOCK_CONE

## Punto del mundo al que apuntar para acertar a un avion: la bala sale a BULLET_SPEED respecto al avion
## del jugador, asi que se resuelve |pos_rel + vel_rel * t| = BULLET_SPEED * t y se suma la caida de la bala.
## Ignora el rozamiento de la bala (BULLET_DRAG): el error es pequeno a estas distancias.
func lead_point(e: AiPlanes.AiPlane) -> Vector3:
	var rel_pos := e.root.position - g.plane.position
	var rel_vel := -e.root.basis.z * e.speed - g.velocity()
	var a := rel_vel.dot(rel_vel) - BULLET_SPEED * BULLET_SPEED
	var b := 2.0 * rel_pos.dot(rel_vel)
	var c := rel_pos.dot(rel_pos)
	var t := rel_pos.length() / BULLET_SPEED   # sin solucion: tiro directo
	if absf(a) > LEAD_EPSILON:
		var disc := b * b - 4.0 * a * c
		if disc >= 0.0:
			var root := sqrt(disc)
			var best := INF
			for candidate: float in [(-b - root) / (2.0 * a), (-b + root) / (2.0 * a)]:
				if candidate > 0.0 and candidate < best:
					best = candidate
			if best < INF:
				t = best
	elif b < 0.0:
		t = -c / b
	return g.plane.position + rel_pos + rel_vel * t + Vector3.UP * 0.5 * GRAVITY * t * t

## Severidad (0..1) del sonido de un impacto segun el dano que hace: una ametralladora roza, un canon pesado golpea.
func impact_severity(dmg: float) -> float:
	return clampf(dmg / IMPACT_FULL_DMG, 0.0, 1.0)

## Fraccion (0..1) de la distancia de tiro en la que el dano es pleno: 1 hasta DMG_FALLOFF_START y 0 en DMG_FALLOFF_END.
func effective_fraction(dist: float) -> float:
	return clampf((_dmg_falloff(dist) - DMG_FALLOFF_MIN) / (1.0 - DMG_FALLOFF_MIN), 0.0, 1.0)

func start_reload() -> void:
	if reloading or ammo >= g.player_spec.mag_size:
		return
	reloading = true
	reload_t = RELOAD_TIME

func shoot(delta: float) -> void:
	fire_cd -= delta
	mg_cd -= delta
	if reloading:
		reload_t -= delta
		if reload_t <= 0.0:
			reloading = false
			ammo = g.player_spec.mag_size
		return
	if ammo <= 0:
		start_reload()
		return
	var want := Input.is_action_pressed(Controls.FIRE)
	if not want:
		return
	var spec := g.player_spec
	if spec.cannon_guns > 0 and fire_cd <= 0.0:
		# los canones (1 en el eje o 1 por ala) disparan a la vez
		fire_cd = 1.0 / (spec.cannon_rate * g.shop_mult(Shop.RATE))
		ammo -= 1
		for k in spec.cannon_guns:
			var x := 0.0 if spec.cannon_guns == 1 else spec.cannon_x * (1.0 if k == 1 else -1.0)
			_fire_gun(Vector3(x, -0.3, -1.5), BULLET_SPEED, BULLET_SPREAD, spec.cannon_dmg * g.shop_mult(Shop.DAMAGE), true)
		g.sound.play_volley(g.sound.bank_cannon, spec.cannon_guns, 0.0)
		g.chase.add_trauma(ChaseCam.SHOOT_TRAUMA)
	if spec.mg_guns > 0 and mg_cd <= 0.0:
		# las ametralladoras alternan entre las alas (o van en el eje); sin canones, gastan el cargador
		mg_cd = 1.0 / (spec.mg_rate * g.shop_mult(Shop.RATE))
		mg_side = -mg_side
		if spec.cannon_guns == 0:
			ammo -= 1
		var mx := 0.0 if spec.mg_guns == 1 else spec.mg_x * mg_side
		_fire_gun(Vector3(mx, -0.2, -1.5), BULLET_SPEED * 0.9, MG_SPREAD, spec.mg_dmg * g.shop_mult(Shop.DAMAGE), false)
		if mg_side > 0.0:
			g.sound.play_bank(g.sound.bank_mg, -7.0)  # una de cada dos, para no saturar

## Dispara un arma del jugador desde un punto local del avion: apunta al punto de convergencia
## y la bala hereda la velocidad del avion. Todas llevan fogonazo (el de los canones, mas grande); los canones (heavy) llevan ademas trazadora grande.
func _fire_gun(muzzle: Vector3, muzzle_speed: float, spread: float, dmg: float, heavy: bool) -> void:
	var b := g.plane.transform.basis
	var fwd := -b.z
	var origin := g.plane.position + b * muzzle
	var shot := scatter((g.plane.position + fwd * GUN_CONVERGE - origin).normalized(), spread)
	g.fx.muzzle_flash(g.plane, muzzle, 1.0 if heavy else MG_FLASH_SCALE)
	var vel := shot * muzzle_speed + g.velocity()
	spawn_bullet(origin, vel, true, dmg, heavy, true)
	g.pilots.send_shot(origin, vel, heavy)

func spawn_bullet(pos: Vector3, vel: Vector3, friendly: bool, dmg: float, heavy: bool, by_player: bool = false, remote: bool = false) -> void:
	var bl := Bullet.new()
	bl.friendly = friendly
	bl.by_player = by_player
	bl.remote = remote
	bl.vel = vel
	bl.dmg = dmg
	var mi := MeshInstance3D.new()
	mi.mesh = bullet_mesh if heavy else mg_mesh
	mi.material_override = bullet_mat_p if friendly else bullet_mat_e
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var halo := MeshInstance3D.new()
	halo.mesh = halo_mesh if heavy else mg_halo_mesh
	halo.material_override = halo_mat_p if friendly else halo_mat_e
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_child(halo)
	var bloom := MeshInstance3D.new()
	bloom.mesh = bloom_mesh
	bloom.material_override = bloom_mat_p if friendly else bloom_mat_e
	bloom.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_child(bloom)
	bl.glow = bloom
	add_child(mi)
	mi.transform = Transform3D(_bullet_basis(vel), pos)
	bl.node = mi
	bullets.append(bl)

## Desvia un vector de direccion un angulo aleatorio de hasta "ang" radianes.
func scatter(dir: Vector3, ang: float) -> Vector3:
	var s := Vector3(g.rng.randf_range(-1, 1), g.rng.randf_range(-1, 1), g.rng.randf_range(-1, 1)) * ang
	return (dir + s).normalized()

## Fraccion del dano que conserva una bala segun la distancia recorrida.
func _dmg_falloff(travel: float) -> float:
	return lerpf(1.0, DMG_FALLOFF_MIN, clampf((travel - DMG_FALLOFF_START) / (DMG_FALLOFF_END - DMG_FALLOFF_START), 0.0, 1.0))

func _bullet_basis(vel: Vector3) -> Basis:
	var dir := vel.normalized()
	var upv := Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT
	return Basis.looking_at(dir, upv)

## Interseccion del segmento a-b con una caja orientada (xf = transformacion del avion, center y half en
## sus ejes locales). Devuelve el tramo 0..1 donde el segmento entra en la caja, o -1 si no la toca.
func _seg_box(a: Vector3, b: Vector3, xf: Transform3D, center: Vector3, half: Vector3) -> float:
	var inv := xf.affine_inverse()
	var la := inv * a - center
	var d := inv * b - center - la
	var t0 := 0.0
	var t1 := 1.0
	for i in 3:
		if absf(d[i]) < 0.00001:
			if absf(la[i]) > half[i]:
				return -1.0
		else:
			var ta := (-half[i] - la[i]) / d[i]
			var tb := (half[i] - la[i]) / d[i]
			t0 = maxf(t0, minf(ta, tb))
			t1 = minf(t1, maxf(ta, tb))
			if t0 > t1:
				return -1.0
	return t0

func update_bullets(dt: float) -> void:
	for i in range(bullets.size() - 1, -1, -1):
		var b := bullets[i]
		var prev := b.node.position
		b.vel *= exp(-BULLET_DRAG * dt)
		b.vel.y -= GRAVITY * dt
		var cur := prev + b.vel * dt
		b.travel += b.vel.length() * dt
		b.life -= dt
		var kill := b.life <= 0.0 or cur.y < g.world.ground_height(cur.x, cur.z)
		if not kill:
			# las balas del jugador y del aliado solo dan a los enemigos; las enemigas, al jugador y al aliado
			var targets: Array[AiPlanes.AiPlane] = g.ai.enemies if b.friendly else g.ai.allies
			for e in targets:
				if e.dead or b.remote or (not b.friendly and not g.net.is_authority()):
					continue   # las copias de disparos ajenos solo se ven; los aliados solo los dana el anfitrion
				var t := _seg_box(prev, cur, e.root.transform, e.box_center, e.box_half)
				if t >= 0.0:
					var dealt := b.dmg * _dmg_falloff(b.travel)
					g.ai.request_hit(e, dealt, b.by_player)
					if b.by_player:
						g.hit_t = 0.3
						g.hit_kill = e.dead
					g.fx.impact(prev.lerp(cur, t), b.vel, impact_severity(dealt), true)
					kill = true
					break
			if not kill and not b.friendly and not g.over:
				var tp := _seg_box(prev, cur, g.plane.transform, g.player_spec.box_center, g.player_spec.box_half)
				if tp >= 0.0:
					var hit_at := prev.lerp(cur, tp)
					var dealt := b.dmg * _dmg_falloff(b.travel)
					var zone := g.zones.zone_of_local(g.plane.to_local(hit_at))
					g.damage_player(dealt, zone)
					# el morro (motor y blindaje) suena a chapa; el resto del avion, a estructura que cruje
					g.fx.impact(hit_at, b.vel, impact_severity(dealt), zone == PlaneZones.Zone.NOSE)
					kill = true
		if kill:
			b.node.queue_free()
			bullets.remove_at(i)
		else:
			b.node.position = cur
			b.node.basis = _bullet_basis(b.vel)
			b.glow.scale = Vector3.ONE * maxf(BULLET_BLOOM_MIN_SIZE, cur.distance_to(g.cam.position) * BULLET_BLOOM_ANGLE)

## Crea las mallas y materiales de las balas (se comparten entre todos los disparos).
func setup() -> void:
	bullet_mesh = BoxMesh.new()
	bullet_mesh.size = CANNON_BULLET_SIZE
	bullet_mat_p = glow_mat(Color(1.0, 0.95, 0.6), BULLET_GLOW)
	bullet_mat_e = glow_mat(Color(1.0, 0.55, 0.45), BULLET_GLOW)
	mg_mesh = BoxMesh.new()
	mg_mesh.size = MG_BULLET_SIZE
	halo_mesh = BoxMesh.new()
	halo_mesh.size = HALO_SIZE
	mg_halo_mesh = BoxMesh.new()
	mg_halo_mesh.size = MG_HALO_SIZE
	halo_mat_p = halo_mat(Color(1.0, 0.6, 0.05))
	halo_mat_e = halo_mat(Color(1.0, 0.1, 0.05))
	bloom_mesh = QuadMesh.new()
	bloom_mesh.size = Vector2.ONE
	bloom_mat_p = bloom_mat(Color(1.0, 0.8, 0.4))
	bloom_mat_e = bloom_mat(Color(1.0, 0.35, 0.25))

## Quita las balas en vuelo y recarga el cargador.
func reset() -> void:
	for b in bullets:
		b.node.queue_free()
	bullets.clear()
	ammo = g.player_spec.mag_size
	reloading = false
	fire_cd = 0.0
	mg_cd = 0.0
	lead_target = null
	target_locked = false
