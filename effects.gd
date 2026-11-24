## Efectos visuales: humo, fuego, chispas, impactos, explosiones y fragmentos con cola.
class_name Effects
extends Node

const DEBRIS_BASE := 6             # fragmentos de una explosion con escala 0
const DEBRIS_PER_SCALE := 4.0     # fragmentos extra por unidad de escala de la explosion
const DEBRIS_SPEED := Vector2(25.0, 70.0) # velocidad inicial (min, max) de un fragmento (m/s), se multiplica por la escala
const DEBRIS_SPIN := 9.0          # giro maximo de un fragmento por eje (rad/s)
const DEBRIS_LIFE := Vector2(2.0, 4.0) # vida (min, max) de un fragmento en el aire (s)
const DEBRIS_GRAVITY := 25.0      # caida de los fragmentos (m/s^2)
const DEBRIS_DRAG := 0.35         # frenado del aire sobre los fragmentos (1/s)
const DEBRIS_TRAIL_SIZE := 1.1    # tamano base de las bocanadas de la cola de un fragmento (m)
const DEBRIS_TRAIL_AMOUNT := 24   # particulas de la cola de cada fragmento
const DEBRIS_INHERIT := 0.6        # fraccion de la velocidad del avion que heredan sus fragmentos
const EXPLOSION_MIN_Y := 3.0      # altura minima del centro de una explosion por unidad de escala, para que no quede enterrada
const SMOKE_SCALE_VAR := Vector2(0.55, 1.5)   # escala al azar (min, max) de cada bocanada: unas pequenas y otras grandes
const SMOKE_TINT_MIN := 0.72      # brillo de la bocanada mas oscura respecto a la mas clara: cada una nace con un gris algo distinto
const SMOKE_SPIN := 45.0          # giro maximo de una bocanada (grados/s, en un sentido o en otro)
const SPRITE_SCALE := 1.7         # los carteles de humo y fuego se agrandan: la bocanada no llena todo el cuadrado
const MUZZLE_FLASH_TIME := 0.05   # duracion del fogonazo de boca (s)
const MUZZLE_FLAME_SIZE := Vector2(0.9, 4.0)   # ancho y largo (m) de la lengua de un fogonazo de canon
const MUZZLE_STAR_SIZE := 1.6     # lado (m) de la estrella de destello de un fogonazo de canon
const MUZZLE_BRIGHTNESS := 2.5    # brillo del fogonazo (mayor que 1 = mas intenso; cerca de 2,5 empieza a brillar el bloom)
const MUZZLE_JITTER := 0.25       # variacion al azar del largo de cada fogonazo (fraccion), para que no se repita igual
const FIRE_SIZE := 0.45           # tamano base de un cartel de llama (m, antes de SPRITE_SCALE)
const FIRE_SCALE_START := 0.9     # escala de la llama al nacer
const FIRE_SCALE_END := 0.35      # escala de la llama al apagarse
const FIRE_BRIGHTNESS := 2.0      # multiplicador de brillo del fuego y las chispas (mayor que 1 = mas intenso)
const IMPACT_LIGHT_ENERGY := 5.0  # intensidad del fogonazo de luz de un impacto
const IMPACT_LIGHT_RANGE := 18.0  # alcance (m) del fogonazo de un impacto
const IMPACT_LIGHT_TIME := 0.12   # segundos que dura el fogonazo de un impacto
const IMPACT_LIGHT_MAX := 6       # fogonazos simultaneos maximos (con la ametralladora hay muchos impactos)
const SHOCKWAVE_RADIUS := 16.0     # radio final (m por unidad de escala) de la onda de choque de una explosion
const SHOCKWAVE_TIME := 0.55      # segundos que tarda la onda de choque en expandirse y desvanecerse
const EXPLOSION_LIGHT_TIME := 0.45 # duracion del fogonazo de luz de una explosion (s)
const CORE_BRIGHTNESS := 4.0      # brillo del nucleo al rojo blanco de una explosion: muy por encima del umbral del bloom, asi lo envuelve en resplandor
const EXPLOSION_FIRE_BRIGHTNESS := 3.0   # brillo de la bola de fuego de una explosion (el fuego normal usa FIRE_BRIGHTNESS)
const PLUME_SPEED := Vector2(6.0, 30.0)  # velocidad (min, max) de la cola de humo por unidad de escala, hacia atras de la trayectoria (m/s)
const PLUME_MIN_SPEED := 8.0      # velocidad del avion (m/s) por debajo de la cual la cola de humo sube en vez de ir hacia atras
const EMBER_SPEED := Vector2(3.0, 14.0)  # velocidad (min, max) de las brasas por unidad de escala (m/s)
const EMBER_LIFE := 2.4           # segundos que flotan las brasas antes de apagarse

class Debris:
	var node: MeshInstance3D
	var vel := Vector3.ZERO
	var spin := Vector3.ZERO            # giro (rad/s) por eje
	var life := 0.0
	var trail: CPUParticles3D           # cola de fuego y humo

var g: Game                   # juego: estado central compartido
var debris: Array[Debris] = []      # fragmentos de explosion en vuelo
var _flame_mesh: QuadMesh         # lengua del fogonazo de boca (se crea la primera vez que se usa)
var _star_mesh: QuadMesh          # estrella del fogonazo de boca
var impact_lights := 0           # fogonazos de impacto encendidos ahora

func _smoke_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# cada particula es un cartel con una de las bocanadas del atlas (elegida al azar por anim_offset)
	m.albedo_texture = FxGen.smoke()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.particles_anim_h_frames = FxGen.GRID
	m.particles_anim_v_frames = FxGen.GRID
	m.particles_anim_loop = false
	return m

## Material aditivo muy brillante con la estrella de destello, para el nucleo al rojo blanco de una explosion.
func _hot_mat() -> StandardMaterial3D:
	var m := _spark_mat()
	m.albedo_color = Color(CORE_BRIGHTNESS, CORE_BRIGHTNESS, CORE_BRIGHTNESS)
	return m

## Material aditivo sin sombreado con el atlas de llamas, para fuego y brasas.
func _fire_mat() -> StandardMaterial3D:
	var m := _smoke_mat()
	m.albedo_texture = FxGen.fire()
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(FIRE_BRIGHTNESS, FIRE_BRIGHTNESS, FIRE_BRIGHTNESS)
	return m

## Material aditivo con la estrella de destello, para chispas y fogonazos.
func _spark_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = FxGen.star()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = Color(FIRE_BRIGHTNESS, FIRE_BRIGHTNESS, FIRE_BRIGHTNESS)
	return m

## Degradado de color a partir de listas de colores y posiciones.
func _ramp(colors: Array[Color], offsets: Array[float]) -> Gradient:
	var grad := Gradient.new()
	grad.colors = PackedColorArray(colors)
	grad.offsets = PackedFloat32Array(offsets)
	return grad

func make_smoke(size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # sin esto cada cartel de humo da una sombra negra sobre el avion
	var bm := QuadMesh.new()
	bm.size = Vector2.ONE * size * SPRITE_SCALE
	bm.material = _smoke_mat()
	p.mesh = bm
	p.anim_offset_max = 1.0
	p.amount = 60
	p.lifetime = 2.6
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 3.5
	p.damping_min = 0.4
	p.damping_max = 0.9
	p.angle_max = 360.0                  # las bocanadas giran al azar: se ve mas organico
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	p.gravity = Vector3(0, 2.5, 0)
	_vary_smoke(p)
	# opaca al nacer, se vuelve mas clara y se disipa
	p.color_ramp = _ramp([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.0)], [0.0, 0.5, 1.0])
	var c := Curve.new()
	c.add_point(Vector2(0, 0.5))
	c.add_point(Vector2(1, 3.2))
	p.scale_amount_curve = c
	p.emitting = false
	return p

## Da variedad a un emisor de humo: tamano, giro y gris distintos en cada bocanada (el dibujo de cada una ya lo elige al azar
## por el atlas). Con el atlas de 9 bocanadas, dos nubes seguidas ya no se repiten.
func _vary_smoke(p: CPUParticles3D) -> void:
	p.scale_amount_min = SMOKE_SCALE_VAR.x
	p.scale_amount_max = SMOKE_SCALE_VAR.y
	p.angular_velocity_min = -SMOKE_SPIN
	p.angular_velocity_max = SMOKE_SPIN
	var tint := Gradient.new()
	tint.colors = PackedColorArray([Color(SMOKE_TINT_MIN, SMOKE_TINT_MIN * 0.97, SMOKE_TINT_MIN * 0.94, 1.0), Color.WHITE])
	tint.offsets = PackedFloat32Array([0.0, 1.0])
	p.color_initial_ramp = tint

## Llamas del motor: particulas cortas amarillo-naranja que se apagan hacia el rojo.
func make_fire() -> CPUParticles3D:
	var p := make_smoke(FIRE_SIZE)
	p.color_initial_ramp = null   # las llamas no se oscurecen como el humo
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	(p.mesh as QuadMesh).material = _fire_mat()
	p.amount = 40
	p.lifetime = 0.6
	p.spread = 35.0
	p.gravity = Vector3(0, 3.0, 0)
	p.color_ramp = _ramp([Color(1, 0.95, 0.4, 1), Color(1, 0.4, 0.05, 0.9), Color(0.5, 0.05, 0.0, 0.0)], [0.0, 0.4, 1.0])
	var shrink := Curve.new()   # la llama se encoge al apagarse; la curva del humo (que crece hasta x3) taparia la pantalla
	shrink.add_point(Vector2(0, FIRE_SCALE_START))
	shrink.add_point(Vector2(1, FIRE_SCALE_END))
	p.scale_amount_curve = shrink
	return p

## Fogonazo de boca: una lengua de fuego hacia delante (dos carteles cruzados, para verla desde cualquier lado) y una
## estrella de destello que mira a la camara. Cuelga de "parent" en "local_pos" y apunta a su -Z; "scale" lo agranda o
## lo encoge (1 = canon). Dura MUZZLE_FLASH_TIME y se borra solo.
func muzzle_flash(parent: Node3D, local_pos: Vector3, scale: float) -> void:
	_ensure_muzzle_assets()
	var flash := Node3D.new()
	flash.position = local_pos
	var len_k := scale * (1.0 + g.rng.randf_range(-MUZZLE_JITTER, MUZZLE_JITTER))
	var roll := g.rng.randf_range(0.0, PI)
	for i in 2:
		var tongue := MeshInstance3D.new()
		tongue.mesh = _flame_mesh
		tongue.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# el cartel mide a lo largo de Y: girado -90 grados sobre X su largo apunta a -Z; el segundo cartel va cruzado
		tongue.basis = Basis(Vector3.FORWARD, roll + i * PI * 0.5) * Basis(Vector3.RIGHT, -PI * 0.5)
		tongue.scale = Vector3(scale, len_k, 1.0)
		flash.add_child(tongue)
	var star := MeshInstance3D.new()
	star.mesh = _star_mesh
	star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	star.scale = Vector3.ONE * scale
	flash.add_child(star)
	parent.add_child(flash)
	get_tree().create_timer(MUZZLE_FLASH_TIME).timeout.connect(flash.queue_free)

## Material aditivo sin sombreado y de dos caras para un cartel suelto (no una particula).
func _additive_mat(tex: Texture2D, tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = tex
	m.albedo_color = tint
	return m

## Mallas y materiales aditivos del fogonazo de boca; se crean la primera vez y se comparten.
func _ensure_muzzle_assets() -> void:
	if _flame_mesh != null:
		return
	var flame_mat := _additive_mat(FxGen.muzzle_flame(), Color(MUZZLE_BRIGHTNESS, MUZZLE_BRIGHTNESS, MUZZLE_BRIGHTNESS))
	_flame_mesh = QuadMesh.new()
	_flame_mesh.size = MUZZLE_FLAME_SIZE
	_flame_mesh.center_offset = Vector3(0.0, MUZZLE_FLAME_SIZE.y * 0.5, 0.0)   # la base de la lengua queda en la boca del arma
	_flame_mesh.material = flame_mat
	var star_mat := _additive_mat(FxGen.star(), Color(MUZZLE_BRIGHTNESS, MUZZLE_BRIGHTNESS * 0.85, MUZZLE_BRIGHTNESS * 0.5))
	star_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED   # la estrella mira siempre a la camara
	_star_mesh = QuadMesh.new()
	_star_mesh.size = Vector2.ONE * MUZZLE_STAR_SIZE
	_star_mesh.material = star_mat

## Estela blanca fina que queda fija en el mundo detras de la punta del ala.
func make_trail() -> CPUParticles3D:
	var p := make_smoke(0.45)
	p.color_initial_ramp = null   # la estela de condensacion es blanca y uniforme
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	p.angular_velocity_min = 0.0
	p.angular_velocity_max = 0.0
	p.amount = 150
	p.lifetime = 1.0
	p.spread = 0.0
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.0
	p.gravity = Vector3.ZERO
	p.color_ramp = _ramp([Color(1, 1, 1, 0.6), Color(1, 1, 1, 0.0)], [0.0, 1.0])
	var c := Curve.new()
	c.add_point(Vector2(0, 1.0))
	c.add_point(Vector2(1, 0.4))
	p.scale_amount_curve = c
	return p

## Rafaga unica de particulas que se libera sola. "vel" = velocidad inicial (min, max) y "grow" = escala (inicio, fin).
func _burst(pos: Vector3, mat: StandardMaterial3D, size: float, amount: int, life: float, vel: Vector2,
		spread: float, gravity: Vector3, ramp: Gradient, grow: Vector2, dir: Vector3 = Vector3.UP) -> void:
	var p := CPUParticles3D.new()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bm := QuadMesh.new()
	bm.size = Vector2.ONE * size * SPRITE_SCALE
	bm.material = mat
	p.mesh = bm
	p.anim_offset_max = 1.0
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = true   # la rafaga no se mueve: en coordenadas locales no depende de la transformacion al nacer
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = vel.x
	p.initial_velocity_max = vel.y
	p.gravity = gravity
	p.damping_min = 0.5
	p.damping_max = 1.5
	p.angle_max = 360.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.color_ramp = ramp
	if mat.albedo_texture == FxGen.smoke():
		_vary_smoke(p)
	var c := Curve.new()
	c.add_point(Vector2(0, grow.x))
	c.add_point(Vector2(1, grow.y))
	p.scale_amount_curve = c
	p.position = pos
	add_child(p)
	p.emitting = true
	get_tree().create_timer(life + 1.0).timeout.connect(p.queue_free)

## Impacto de bala sobre un fuselaje: destello, chispas y esquirlas que salen de vuelta hacia el
## tirador (dir = direccion de la bala) y una bocanada de humo oscuro. "severity" (0..1) y "metal" eligen el sonido
## (ver GameSound.play_impact).
func impact(pos: Vector3, dir: Vector3, severity: float, metal: bool) -> void:
	g.sound.play_impact(pos, severity, metal)
	var back := -dir.normalized()
	# fogonazo de luz que ilumina el fuselaje un instante
	if impact_lights < IMPACT_LIGHT_MAX:
		impact_lights += 1
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.75, 0.4)
		light.light_energy = IMPACT_LIGHT_ENERGY
		light.omni_range = IMPACT_LIGHT_RANGE
		light.shadow_enabled = false
		light.position = pos
		add_child(light)
		var ltw := create_tween()
		ltw.tween_property(light, "light_energy", 0.0, IMPACT_LIGHT_TIME)
		ltw.tween_callback(func() -> void:
			impact_lights -= 1
			light.queue_free())
	var spark_ramp := _ramp([Color(1, 0.95, 0.6, 1), Color(1, 0.5, 0.1, 0.8), Color(1, 0.3, 0.0, 0.0)], [0.0, 0.4, 1.0])
	# destello: nucleo blanco muy brillante y resplandor naranja mas grande y algo mas duradero
	_burst(pos, _spark_mat(), 1.2, 4, 0.1, Vector2(0.0, 1.0), 180.0, Vector3.ZERO,
		_ramp([Color(1, 1, 1, 1), Color(1, 0.95, 0.7, 0.8), Color(1, 0.8, 0.4, 0.0)], [0.0, 0.5, 1.0]), Vector2(1.2, 0.4))
	_burst(pos, _fire_mat(), 1.8, 3, 0.22, Vector2(0.0, 1.0), 180.0, Vector3.ZERO,
		_ramp([Color(1, 0.7, 0.25, 0.7), Color(1, 0.4, 0.05, 0.35), Color(1, 0.25, 0.0, 0.0)], [0.0, 0.5, 1.0]), Vector2(0.8, 1.4))
	_burst(pos, _spark_mat(), 0.25, 24, 0.5, Vector2(25.0, 80.0), 55.0, Vector3(0, -18, 0), spark_ramp, Vector2(1.0, 0.2), back)
	_burst(pos, _smoke_mat(), 0.25, 6, 1.0, Vector2(8.0, 25.0), 70.0, Vector3(0, -20, 0),
		_ramp([Color(0.2, 0.18, 0.15, 1), Color(0.1, 0.1, 0.1, 0.0)], [0.0, 1.0]), Vector2(1.0, 0.6), back)
	_burst(pos, _smoke_mat(), 0.8, 6, 1.6, Vector2(1.0, 5.0), 180.0, Vector3(0, 2, 0),
		_ramp([Color(0.15, 0.15, 0.15, 0.7), Color(0.3, 0.3, 0.3, 0.0)], [0.0, 1.0]), Vector2(0.5, 2.5))

## Explosion de avion destruido: destello de luz, onda de choque, nucleo al rojo blanco, bola de fuego, columna y cola de
## humo negro, nube de hollin persistente, escombros, chispas y brasas.
func explode(pos: Vector3, sc: float, vel: Vector3 = Vector3.ZERO) -> void:
	pos.y = maxf(pos.y, g.world.ground_height(pos.x, pos.z) + EXPLOSION_MIN_Y * sc)
	g.chase.add_trauma(clampf(1.0 - g.cam.position.distance_to(pos) / ChaseCam.EXPLOSION_SHAKE_RANGE, 0.0, 1.0) * minf(sc, 1.5))
	g.sound.play_explosion(pos, sc)
	var spark_ramp := _ramp([Color(1, 0.95, 0.6, 1), Color(1, 0.5, 0.1, 0.8), Color(1, 0.3, 0.0, 0.0)], [0.0, 0.4, 1.0])
	# onda de choque: anillo aditivo que mira a la camara, se expande y se desvanece
	var wave_mat := StandardMaterial3D.new()
	wave_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wave_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wave_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	wave_mat.albedo_texture = FxGen.ring()
	wave_mat.albedo_color = Color(1.0, 0.75, 0.45, 0.6)
	wave_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	wave_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var wave := MeshInstance3D.new()
	var wave_quad := QuadMesh.new()
	wave_quad.size = Vector2.ONE * 2.0
	wave.mesh = wave_quad
	wave.material_override = wave_mat
	wave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wave.position = pos
	add_child(wave)
	wave.scale = Vector3.ONE * sc
	var wtw := create_tween().set_parallel(true)
	wtw.tween_property(wave, "scale", Vector3.ONE * SHOCKWAVE_RADIUS * sc, SHOCKWAVE_TIME)
	wtw.tween_property(wave_mat, "albedo_color:a", 0.0, SHOCKWAVE_TIME)
	wtw.chain().tween_callback(wave.queue_free)
	# destello de luz que ilumina el entorno y se apaga
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.2)
	light.light_energy = 6.0 * sc
	light.omni_range = 80.0 * sc
	light.position = pos
	add_child(light)
	var tw := create_tween()
	tw.tween_property(light, "light_energy", 0.0, EXPLOSION_LIGHT_TIME)
	tw.tween_callback(light.queue_free)
	# nucleo al rojo blanco: un destello brevisimo y muy brillante en el centro
	_burst(pos, _hot_mat(), 5.0 * sc, 3, 0.2, Vector2(0.0, 1.0), 180.0, Vector3.ZERO,
		_ramp([Color(1, 1, 1, 1), Color(1, 0.85, 0.5, 0.8), Color(1, 0.5, 0.15, 0.0)], [0.0, 0.35, 1.0]), Vector2(0.8, 1.7))
	# bola de fuego que se expande: blanco-amarillo, naranja, rojo oscuro y hollin, con mucho contraste
	var fire := _fire_mat()
	fire.albedo_color = Color(EXPLOSION_FIRE_BRIGHTNESS, EXPLOSION_FIRE_BRIGHTNESS, EXPLOSION_FIRE_BRIGHTNESS)
	_burst(pos, fire, 3.0 * sc, int(40.0 + 16.0 * sc), 0.9, Vector2(5.0, 24.0) * sc, 180.0, Vector3(0, 3, 0),
		_ramp([Color(1, 0.97, 0.75, 1), Color(1, 0.5, 0.05, 1.0), Color(0.5, 0.08, 0.02, 0.8), Color(0.05, 0.04, 0.04, 0.0)],
			[0.0, 0.22, 0.6, 1.0]), Vector2(0.5, 2.0))
	# columna de humo denso, casi negro, que sube y se ensancha
	_burst(pos, _smoke_mat(), 4.0 * sc, int(36.0 + 18.0 * sc), 5.0, Vector2(3.0, 10.0) * sc, 40.0, Vector3(0, 3, 0),
		_ramp([Color(0.04, 0.04, 0.04, 0.95), Color(0.12, 0.12, 0.12, 0.8), Color(0.35, 0.35, 0.35, 0.0)], [0.0, 0.4, 1.0]), Vector2(0.4, 3.2))
	# cola de humo: se estira hacia atras de la trayectoria del avion (o hacia arriba si apenas se movia)
	var plume_dir := Vector3.UP
	if vel.length() > PLUME_MIN_SPEED:
		plume_dir = -vel.normalized()
	_burst(pos, _smoke_mat(), 3.5 * sc, int(20.0 + 10.0 * sc), 6.5, PLUME_SPEED * sc, 12.0, Vector3(0, 1.0, 0),
		_ramp([Color(0.05, 0.05, 0.05, 0.9), Color(0.13, 0.12, 0.12, 0.75), Color(0.3, 0.3, 0.3, 0.0)], [0.0, 0.35, 1.0]), Vector2(0.6, 2.4), plume_dir)
	# humo persistente: nube de hollin que se queda un buen rato en el aire y se disipa despacio
	_burst(pos, _smoke_mat(), 6.0 * sc, int(14.0 + 7.0 * sc), 11.0, Vector2(1.0, 4.0) * sc, 70.0, Vector3(0, 1.5, 0),
		_ramp([Color(0.08, 0.08, 0.08, 0.0), Color(0.1, 0.1, 0.1, 0.65), Color(0.28, 0.28, 0.28, 0.0)], [0.0, 0.12, 1.0]), Vector2(0.5, 2.8))
	# fragmentos de chapa que salen despedidos dejando una cola de fuego y humo
	_spawn_debris(pos, sc, vel)
	# chispas rapidas
	_burst(pos, _spark_mat(), 0.5, int(24.0 + 12.0 * sc), 0.8, Vector2(20.0, 70.0) * sc, 180.0, Vector3(0, -10, 0), spark_ramp, Vector2(1.0, 0.2))
	# brasas incandescentes: lentas, flotan y se apagan del naranja al rojo oscuro
	_burst(pos, _spark_mat(), 0.22, int(30.0 + 15.0 * sc), EMBER_LIFE, EMBER_SPEED * sc, 180.0, Vector3(0, -3, 0),
		_ramp([Color(1, 0.8, 0.35, 1), Color(1, 0.35, 0.05, 0.9), Color(0.35, 0.05, 0.02, 0.0)], [0.0, 0.5, 1.0]), Vector2(1.0, 0.5))

## Fragmentos de chapa: cada uno vuela con su caida y su giro y deja una cola que pasa de fuego a humo.
func _spawn_debris(pos: Vector3, sc: float, base_vel: Vector3) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = FxGen.scrap()
	mat.roughness = 0.8
	var piece := clampf(sc, 1.0, 3.0)
	var trail_ramp := _ramp([Color(1, 0.7, 0.2, 0.9), Color(0.25, 0.22, 0.2, 0.7), Color(0.3, 0.3, 0.3, 0.0)], [0.0, 0.25, 1.0])
	var trail_curve := Curve.new()
	trail_curve.add_point(Vector2(0, 0.6))
	trail_curve.add_point(Vector2(1, 2.2))
	for i in int(DEBRIS_BASE + DEBRIS_PER_SCALE * sc):
		var d := Debris.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(g.rng.randf_range(0.4, 1.4), g.rng.randf_range(0.08, 0.35), g.rng.randf_range(0.4, 1.1)) * piece
		bm.material = mat
		d.node = MeshInstance3D.new()
		d.node.mesh = bm
		d.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var dir := Vector3(g.rng.randf_range(-1.0, 1.0), g.rng.randf_range(-0.3, 1.0), g.rng.randf_range(-1.0, 1.0)).normalized()
		d.vel = dir * g.rng.randf_range(DEBRIS_SPEED.x, DEBRIS_SPEED.y) * minf(sc, 2.0) + base_vel * DEBRIS_INHERIT
		d.spin = Vector3(g.rng.randf_range(-1.0, 1.0), g.rng.randf_range(-1.0, 1.0), g.rng.randf_range(-1.0, 1.0)) * DEBRIS_SPIN
		d.life = g.rng.randf_range(DEBRIS_LIFE.x, DEBRIS_LIFE.y)
		d.trail = make_smoke(DEBRIS_TRAIL_SIZE * piece)
		d.trail.amount = DEBRIS_TRAIL_AMOUNT
		d.trail.lifetime = 1.8
		d.trail.initial_velocity_min = 0.0
		d.trail.initial_velocity_max = 1.0
		d.trail.color_ramp = trail_ramp
		d.trail.scale_amount_curve = trail_curve
		d.trail.emitting = true
		d.node.add_child(d.trail)
		d.node.position = pos
		add_child(d.node)
		debris.append(d)

func update_debris(dt: float) -> void:
	for i in range(debris.size() - 1, -1, -1):
		var d := debris[i]
		d.vel.y -= DEBRIS_GRAVITY * dt
		d.vel *= exp(-DEBRIS_DRAG * dt)
		d.node.position += d.vel * dt
		d.node.rotation += d.spin * dt
		d.life -= dt
		if d.life <= 0.0 or g.world.altitude(d.node.position) < 0.0:
			# el fragmento desaparece pero su cola termina de disiparse
			d.trail.emitting = false
			d.node.mesh = null
			get_tree().create_timer(d.trail.lifetime + 0.5).timeout.connect(d.node.queue_free)
			debris.remove_at(i)

## Quita los fragmentos en vuelo.
func reset() -> void:
	for d in debris:
		d.node.queue_free()
	debris.clear()
