## Mundo: cielo, suelo, nubes y desenfoque de movimiento de pantalla completa.
class_name World
extends Node

const CLOUD_RANGE := 3500.0
const FOG_DENSITY := 0.0002        # densidad de la niebla (era 0.0005, muy densa); 0 = sin niebla
const CLOUD_COUNT := 260          # nubes en el alcance (eran 70): mas nubes = mas cortes de luz y rayos de sol visibles
const CLOUD_CLUSTERS := 22        # racimos de nubes: entre ellos queda cielo abierto (los huecos)
const CLOUD_CLUSTER_RADIUS := 500.0  # radio de cada racimo (m): mayor = racimos mas grandes y menos huecos
const CLOUD_ALTITUDE := Vector2(600.0, 1200.0)  # altura minima y maxima de las nubes (m); el avion arranca a 200
## Relieve: un mapa de alturas que se repite sin costuras, con colinas de ruido. La malla del suelo sigue al jugador y
## el shader (ground.gdshader) levanta sus vertices leyendo ese mismo mapa; los choques lo leen con ground_height().
const GLOW_LEVEL_1 := 0.4          # peso del nivel de bloom mas estrecho (0 = sin el; los demas niveles pesan 1)
const HILL_MAX := 160.0            # altura maxima de las colinas (m): por debajo de la altura de salida (200 m)
const TERRAIN_TILE := 16384.0      # lado (m) del mapa de alturas; pasado ese borde el relieve se repite
const TERRAIN_RES := 256           # texeles por lado del mapa (64 m cada uno): sobra para colinas, y se calcula rapido al arrancar
const TERRAIN_SPACING := 32.0      # separacion (m) entre vertices de la malla del suelo
const TERRAIN_SIZE := 14080.0      # lado (m) de la malla del suelo: 440 separaciones, y el borde queda fuera de la vista
const HILL_FREQ := 0.02            # frecuencia del ruido en texeles (1/texel): colinas grandes de unos 3 km
const HILL_OCTAVES := 4            # capas de detalle del ruido: la mas fina mide unos 400 m
const HILL_SEED := 7
const HILL_FLOOR := 0.3            # valor del ruido (0..1) por debajo del cual el suelo es llano: deja valles y llanuras
const HILL_CURVE := 1.2            # exponente del relieve: mayor = laderas mas suaves abajo y cimas mas marcadas
const MOTION_BLUR := 2.0           # intensidad del desenfoque de movimiento (0 = apagado; 1 = el desplazamiento de un paso de fisica)
const PLANE_BLUR_MARGIN := 8.0     # distancia extra tras la del avion hasta la que no se desenfoca (m): su largo y envergadura
const MOTION_BLUR_PRIORITY := -128 # prioridad de dibujo: el desenfoque va el primero, porque la copia de pantalla no incluye lo transparente (aro, humo, nubes) y lo taparia

## Luz de la partida y luz del hangar (menu): cielo, niebla, sol y luz ambiente.
const SKY_TOP := Color(0.25, 0.5, 0.85)
const SKY_HORIZON := Color(0.7, 0.82, 0.95)
const FOG_COLOR := Color(0.7, 0.82, 0.95)
const SUN_COLOR := Color(1.0, 1.0, 1.0)
const SUN_ENERGY := 1.0
const AMBIENT_ENERGY := 1.0
const SUN_ROTATION := Vector3(-22.0, 220.0, 0.0)     # sol en la partida (grados): 22 de altura y 40 a la izquierda del rumbo inicial (-Z), asi entra en pantalla y hay rayos
const HANGAR_SKY_TOP := Color(0.2, 0.25, 0.34)        # cielo del hangar: atardecer, azul apagado arriba y calido en el horizonte
const HANGAR_SKY_HORIZON := Color(0.86, 0.56, 0.34)
const HANGAR_FOG_COLOR := Color(0.5, 0.38, 0.3)
const HANGAR_SUN_COLOR := Color(1.0, 0.72, 0.45)      # luz calida y baja, de campo
const HANGAR_SUN_ENERGY := 0.9
const HANGAR_AMBIENT_ENERGY := 0.55
const HANGAR_SUN_ROTATION := Vector3(-16.0, 35.0, 0.0) # sol casi rasante: sombras largas

## Imagen: mapeo tonal ACES y gradacion de color (se aplican a toda la escena, transparentes incluidos).
const TONEMAPPER := Environment.TONE_MAPPER_ACES   # mapeo tonal: TONE_MAPPER_LINEAR (como antes de la mejora), _FILMIC, _ACES o _AGX
const TONEMAP_EXPOSURE := 0.6    # exposicion antes del mapeo tonal: el ACES de Godot ya multiplica x1.8 por dentro, asi que <1 compensa
const GRADE_CONTRAST := 1.15     # contraste tras el mapeo tonal
const GRADE_SATURATION := 1.25   # ACES apaga los colores (se ve palido): se compensa aqui
const GRADE_BRIGHTNESS := 1.0
const VIBRANCE := 0.6           # vibrancia: satura mas los colores apagados que los vivos (0 = apagada); va en motion_blur.gdshader
const BALANCE_NEUTRO := Color(1.0, 1.0, 1.0)    # balance de blancos: ganancia por canal (maximo 1.0, la textura no admite mas)
const BALANCE_FRIO := Color(0.9, 0.97, 1.0)     # gran altitud: aire limpio y frio
const BALANCE_CALIDO := Color(1.0, 0.93, 0.8)   # hangar: atardecer
const ALT_FRIA_INI := 300.0      # altitud (m) donde empieza a enfriarse la imagen
const ALT_FRIA_FIN := 2500.0     # altitud (m) donde llega al balance frio completo
const BALANCE_PASO := 0.05       # cuantizacion del balance: la textura solo se rehace si cambia al menos esto

## Rayos de sol (god rays): se calculan en motion_blur.gdshader desde la direccion del sol.
const RAY_INTENSITY := 1.2         # brillo global de los rayos (0 = apagados)
const RAY_DENSITY := 1.0         # largo del rayo: fraccion del camino pixel-sol que se recorre (1 = hasta el sol)
const RAY_DECAY := 0.985        # caida por muestra: menor = rayos mas cortos y concentrados junto al sol
const RAY_WEIGHT := 0.6          # peso de cada muestra
const RAY_SPREAD := 40.0        # concentracion del resplandor alrededor del sol (mayor = mas estrecho)
const RAY_STREAKS := 0.6         # radios fijos alrededor del sol (0 = solo los que hacen las nubes; 1 = muy marcados): asegura muchos rayos aunque haya pocas nubes
const FLARE_INTENSITY := 0.6      # destello de lente del sol: nucleo, anillo y reflejos (0 = apagado)
const RAY_ABSORB := 0.6         # cuanto apaga el rayo cada muestra tapada por nube o terreno (0-1): mas = franjas mas marcadas

var g: Game                   # juego: estado central compartido
var blur_mat: ShaderMaterial          # desenfoque de movimiento de pantalla completa
var ground: MeshInstance3D
var _heights := PackedFloat32Array()   # alturas (m) del mapa, TERRAIN_RES x TERRAIN_RES, fila a fila
var clouds: Array[MeshInstance3D] = []
var sky_mat: ProceduralSkyMaterial
var env: Environment
var sun: DirectionalLight3D
var grade_gradient: Gradient   # curva por canal de la gradacion: de negro a la ganancia del balance de blancos
var grade_k := -1.0            # mezcla frio/neutro aplicada ahora (-1 = aun sin aplicar)
var hangar_on := false

func build_environment() -> void:
	sky_mat = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.fog_enabled = true
	env.fog_density = FOG_DENSITY
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 2.5   # solo brilla lo muy intenso (balas), no el cielo ni el mundo
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	for lvl in [2, 3, 4, 5]:
		env.set_glow_level(lvl, 1.0)
	env.set_glow_level(1, GLOW_LEVEL_1)   # el nivel 1 es el mas estrecho: hace brillar objetos finos como las balas
	env.tonemap_mode = TONEMAPPER
	env.tonemap_exposure = TONEMAP_EXPOSURE
	env.adjustment_enabled = true
	env.adjustment_brightness = GRADE_BRIGHTNESS
	env.adjustment_contrast = GRADE_CONTRAST
	env.adjustment_saturation = GRADE_SATURATION
	grade_gradient = Gradient.new()
	var grade_tex := GradientTexture1D.new()
	grade_tex.gradient = grade_gradient
	env.adjustment_color_correction = grade_tex
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 500.0
	add_child(sun)
	set_hangar_look(false)

## Cambia entre la luz de la partida y la del hangar (cielo de atardecer, sol calido y rasante, ambiente tenue).
func set_hangar_look(on: bool) -> void:
	hangar_on = on
	grade_k = -1.0
	if on:
		_set_balance(BALANCE_CALIDO)
	sky_mat.sky_top_color = HANGAR_SKY_TOP if on else SKY_TOP
	sky_mat.sky_horizon_color = HANGAR_SKY_HORIZON if on else SKY_HORIZON
	env.fog_light_color = HANGAR_FOG_COLOR if on else FOG_COLOR
	env.ambient_light_energy = HANGAR_AMBIENT_ENERGY if on else AMBIENT_ENERGY
	sun.light_color = HANGAR_SUN_COLOR if on else SUN_COLOR
	sun.light_energy = HANGAR_SUN_ENERGY if on else SUN_ENERGY
	sun.rotation_degrees = HANGAR_SUN_ROTATION if on else SUN_ROTATION

## Balance de blancos: ganancia por canal (la curva de cada canal va de 0 a la ganancia).
func _set_balance(gain: Color) -> void:
	grade_gradient.set_color(0, Color.BLACK)
	grade_gradient.set_color(1, gain)

## En la partida la imagen se enfria con la altitud; en el hangar se queda calida.
func _update_balance() -> void:
	if hangar_on:
		return
	var k: float = snappedf(smoothstep(ALT_FRIA_INI, ALT_FRIA_FIN, g.plane.position.y), BALANCE_PASO)
	if k == grade_k:
		return
	grade_k = k
	_set_balance(BALANCE_NEUTRO.lerp(BALANCE_FRIO, k))

func build_ground() -> void:
	_build_heights()
	ground = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(TERRAIN_SIZE, TERRAIN_SIZE)
	var segments := roundi(TERRAIN_SIZE / TERRAIN_SPACING)
	pm.subdivide_width = segments - 1
	pm.subdivide_depth = segments - 1
	ground.mesh = pm
	ground.extra_cull_margin = HILL_MAX   # la malla es plana: sin esto se descartaria al mirar las colinas desde un lado
	var img := Image.create_from_data(TERRAIN_RES, TERRAIN_RES, false, Image.FORMAT_RF, _heights.to_byte_array())
	img.convert(Image.FORMAT_RH)   # media precision: filtra bien en cualquier tarjeta y sobra (6 cm a 100 m)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://ground.gdshader")
	mat.set_shader_parameter("heightmap", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("tile", TERRAIN_TILE)
	mat.set_shader_parameter("spacing", TERRAIN_SPACING)
	ground.material_override = mat
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)

## Rellena el mapa de alturas con ruido fractal. Para que el mapa se repita sin costuras se mezclan cuatro copias
## desplazadas, cada una con mas peso cerca de su esquina.
func _build_heights() -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = HILL_OCTAVES
	noise.frequency = HILL_FREQ
	noise.seed = HILL_SEED
	var n := float(TERRAIN_RES)
	_heights.resize(TERRAIN_RES * TERRAIN_RES)
	for j in TERRAIN_RES:
		for i in TERRAIN_RES:
			var x := float(i)
			var y := float(j)
			var mixed: float = (noise.get_noise_2d(x, y) * (n - x) * (n - y) + noise.get_noise_2d(x - n, y) * x * (n - y) 					+ noise.get_noise_2d(x - n, y - n) * x * y + noise.get_noise_2d(x, y - n) * (n - x) * y) / (n * n)
			var t := clampf((mixed * 0.5 + 0.5 - HILL_FLOOR) / (1.0 - HILL_FLOOR), 0.0, 1.0)
			_heights[j * TERRAIN_RES + i] = HILL_MAX * pow(t, HILL_CURVE)

## Altura del suelo (m) en un punto del mundo: la misma interpolacion que hace la tarjeta grafica con el mapa.
func ground_height(x: float, z: float) -> float:
	var tx := x / TERRAIN_TILE * TERRAIN_RES - 0.5   # el centro del texel i esta en (i + 0.5) texeles
	var ty := z / TERRAIN_TILE * TERRAIN_RES - 0.5
	var ix := floori(tx)
	var iy := floori(ty)
	var fx := tx - float(ix)
	var fy := ty - float(iy)
	var x0 := posmod(ix, TERRAIN_RES)
	var x1 := posmod(ix + 1, TERRAIN_RES)
	var row0 := posmod(iy, TERRAIN_RES) * TERRAIN_RES
	var row1 := posmod(iy + 1, TERRAIN_RES) * TERRAIN_RES
	return lerpf(lerpf(_heights[row0 + x0], _heights[row0 + x1], fx), lerpf(_heights[row1 + x0], _heights[row1 + x1], fx), fy)

## Altura de un punto sobre el suelo que tiene debajo (m).
func altitude(p: Vector3) -> float:
	return p.y - ground_height(p.x, p.z)

## Desenfoque de movimiento: un cuadrado a pantalla completa pegado a la camara con el shader motion_blur.
func build_motion_blur() -> void:
	blur_mat = ShaderMaterial.new()
	blur_mat.shader = load("res://motion_blur.gdshader")
	blur_mat.render_priority = MOTION_BLUR_PRIORITY
	blur_mat.set_shader_parameter("strength", MOTION_BLUR)
	blur_mat.set_shader_parameter("vibrance", VIBRANCE)
	blur_mat.set_shader_parameter("ray_intensity", RAY_INTENSITY)
	blur_mat.set_shader_parameter("ray_density", RAY_DENSITY)
	blur_mat.set_shader_parameter("ray_decay", RAY_DECAY)
	blur_mat.set_shader_parameter("ray_weight", RAY_WEIGHT)
	blur_mat.set_shader_parameter("ray_spread", RAY_SPREAD)
	blur_mat.set_shader_parameter("ray_absorb", RAY_ABSORB)
	blur_mat.set_shader_parameter("ray_streaks", RAY_STREAKS)
	blur_mat.set_shader_parameter("flare_intensity", FLARE_INTENSITY)
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	quad.flip_faces = true
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = blur_mat
	mi.extra_cull_margin = 16384.0   # que nunca se descarte por estar "fuera" de la pantalla
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.cam.add_child(mi)

## Enciende o apaga los rayos de sol (el destello de lente no cambia).
func set_rays(on: bool) -> void:
	blur_mat.set_shader_parameter("ray_intensity", RAY_INTENSITY if on else 0.0)

func build_clouds() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://cloud.gdshader")
	var meshes: Array[ArrayMesh] = []
	for i in 6:
		meshes.append(_make_cloud_mesh(i * 977 + 13))
	# las nubes se agrupan en racimos y entre racimos queda cielo abierto: por ahi entran los rayos de sol
	var centers: Array[Vector2] = []
	for k in CLOUD_CLUSTERS:
		centers.append(Vector2(g.rng.randf_range(-CLOUD_RANGE, CLOUD_RANGE), g.rng.randf_range(-CLOUD_RANGE, CLOUD_RANGE)))
	for i in CLOUD_COUNT:
		var center: Vector2 = centers[i % CLOUD_CLUSTERS]
		var ang: float = g.rng.randf_range(0.0, TAU)
		var rad: float = CLOUD_CLUSTER_RADIUS * sqrt(g.rng.randf())
		var mi := MeshInstance3D.new()
		mi.mesh = meshes[i % meshes.size()]
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var s := g.rng.randf_range(1.0, 2.4)
		mi.scale = Vector3(s, s * g.rng.randf_range(0.8, 1.2), s)
		mi.rotation.y = g.rng.randf_range(0, TAU)
		mi.position = Vector3(center.x + cos(ang) * rad, g.rng.randf_range(CLOUD_ALTITUDE.x, CLOUD_ALTITUDE.y), center.y + sin(ang) * rad)
		add_child(mi)
		clouds.append(mi)

func _make_cloud_mesh(seed_i: int) -> ArrayMesh:
	var r := RandomNumberGenerator.new()
	r.seed = seed_i
	var d := {}
	for b in r.randi_range(4, 8):
		var c := Vector3(r.randf_range(-7, 7), r.randf_range(-1.0, 1.5), r.randf_range(-5, 5))
		var rad := Vector3(r.randf_range(3, 6), r.randf_range(1.5, 3.2), r.randf_range(2.5, 5))
		for x in range(int(c.x - rad.x) - 1, int(c.x + rad.x) + 2):
			for y in range(-1, int(c.y + rad.y) + 2):
				for z in range(int(c.z - rad.z) - 1, int(c.z + rad.z) + 2):
					var q := Vector3((x - c.x) / rad.x, (y - c.y) / rad.y, (z - c.z) / rad.z)
					if q.length_squared() <= 1.0:
						d[Vector3i(x, y, z)] = Color.WHITE
	# sombreado por altura: base grisacea, cima blanca (da volumen)
	for k in d.keys():
		var v: Vector3i = k
		var s := remap(float(v.y), -1.0, 4.0, 0.7, 1.0)
		d[k] = Color(s * 0.97, s * 0.98, minf(s * 1.03, 1.0))
	return g.vox.voxel_mesh(d, 14.0, 0.04)

## Nubes y suelo siguen al jugador: las nubes se reciclan al salir del alcance.
func update() -> void:
	_update_balance()
	blur_mat.set_shader_parameter("sun_dir", sun.global_transform.basis.z)   # el eje +Z del sol apunta hacia el sol
	blur_mat.set_shader_parameter("sun_color", Vector3(sun.light_color.r, sun.light_color.g, sun.light_color.b))
	var pp := g.plane.position
	ground.position = Vector3(snappedf(pp.x, TERRAIN_SPACING), 0.0, snappedf(pp.z, TERRAIN_SPACING))   # a saltos de una separacion: los vertices no se desplazan sobre el relieve
	for c in clouds:
		var o := c.position - pp
		o.x = wrapf(o.x, -CLOUD_RANGE, CLOUD_RANGE)
		o.z = wrapf(o.z, -CLOUD_RANGE, CLOUD_RANGE)
		c.position = Vector3(pp.x + o.x, c.position.y, pp.z + o.z)
