## Hangar 3D del menu de inicio: una losa de hormigon agrietado con marcas de pista gastadas bajo una luz calida de
## atardecer, polvo en el aire y el avion elegido flotando sobre ella. El avion entra con un efecto mecanico: una
## persiana de lineas lo revela por tramos, el motor arranca con una bocanada de humo y la camara da un "clack".
## Solo existe mientras el menu esta abierto.
class_name HangarScene
extends Node3D

const PLANE_POS := Vector3(0.0, 200.0, 0.0)   # donde reposa el avion en el hangar
const PLATFORM_SIZE := Vector3(36.0, 0.8, 28.0) # losa de la plataforma (m)
const PLATFORM_DROP := 1.6                    # distancia del vientre del avion al techo de la plataforma (m)
const CURB_SIZE := Vector2(0.5, 0.25)         # ancho y alto del bordillo que rodea la losa (m)
const CONCRETE_SIZE := 64                     # lado de la textura de hormigon (px)
const CONCRETE_SEED := 7                      # semilla del hormigon: siempre el mismo
const CONCRETE_BASE := Color(0.43, 0.42, 0.37) # gris piedra con un punto de olivo
const CONCRETE_NOISE := 0.045                 # variacion de brillo de cada pixel
const CONCRETE_STAINS := 6                    # manchas de aceite y humedad
const CONCRETE_CRACKS := 5                    # grietas
const CONCRETE_CRACK_LEN := 28                # largo de cada grieta (px de textura)
const CONCRETE_TILING := 0.12                 # repeticiones de la textura por metro
const PAINT_DASH := Vector2(2.0, 4.0)         # largo minimo y maximo de un trazo de la franja amarilla (m)
const PAINT_GAP := Vector2(0.2, 1.4)          # hueco minimo y maximo entre trazos: pintura saltada
const PAINT_WIDTH := 0.3                      # ancho de las franjas (m)
const PAINT_INSET := 1.2                      # distancia de la franja amarilla al borde de la losa (m)
const PAINT_SEED := 11                        # semilla de la pintura gastada
const CENTER_DASHES := 5                      # trazos de la linea central blanca
const CENTER_DASH := Vector2(0.3, 2.2)        # ancho y largo de un trazo de la linea central (m)
const CENTER_GAP := 4.4                       # separacion entre centros de trazos (m)
const CENTER_WEAR := 0.2                      # probabilidad de que un trazo de la linea central este gastado del todo
const NUMBER_TEXT := "27"                     # numeracion de pista
const NUMBER_Z := -9.5                        # distancia del numero al centro, hacia delante (m)
const NUMBER_SIZE := 96                       # tamano de la fuente del numero
const NUMBER_PIXEL := 0.03                    # metros por pixel de la fuente del numero
const KEY_POS := Vector3(-14.0, 10.0, -18.0)  # foco principal, calido y bajo, desde delante a la izquierda
const KEY_COLOR := Color(1.0, 0.78, 0.5)
const KEY_ENERGY := 9.0
const FILL_POS := Vector3(16.0, 5.0, 20.0)    # luz de relleno timida, desde detras a la derecha
const FILL_COLOR := Color(0.9, 0.6, 0.35)
const FILL_ENERGY := 4.0
const SPOT_RANGE := 80.0
const SPOT_ANGLE := 32.0                      # apertura de los focos (grados)
const DUST_AMOUNT := 90                       # particulas de polvo
const DUST_EXTENTS := Vector3(22.0, 8.0, 22.0) # semiejes de la caja donde flota el polvo (m)
const DUST_LIFETIME := 8.0
const DUST_SPEED := Vector2(0.1, 0.5)         # velocidad minima y maxima del polvo (m/s)
const DUST_SIZE := 0.06                       # tamano de cada particula (m)
const DUST_ALPHA := 0.35
const PUFF_LOCAL := Vector3(0.0, 0.3, -1.6)   # de donde sale la bocanada de humo, en ejes del avion (m)
const PUFF_AMOUNT := 28                       # cubos de humo
const PUFF_LIFETIME := 1.1
const PUFF_SPEED := Vector2(1.5, 4.0)         # velocidad minima y maxima del humo (m/s)
const PUFF_SIZE := 0.35                       # lado de un cubo de humo (m)
const PUFF_RISE := 0.6                        # empuje hacia arriba del humo (m/s^2)
const PUFF_COLOR_START := Color(0.62, 0.6, 0.55, 0.7)
const PUFF_COLOR_END := Color(0.4, 0.38, 0.35, 0.0)
const PROP_SPIN := 24.0                       # giro de la helice en reposo (rad/s)
const LAUNCH_SPIN := 90.0                     # giro de la helice durante la salida (rad/s): el motor se revoluciona
const SPIN_FOLLOW := 8.0                      # rapidez con que la helice alcanza su giro (1/s)
const BOB_AMP := 0.12                         # amplitud del vaiven vertical del avion (m)
const BOB_RATE := 0.25                        # vaivenes por segundo
const TILT_AMP := 0.025                       # balanceo del avion (rad)
const TILT_RATE := 0.15                       # balanceos por segundo
const TEST_PHASE := 1.4                       # segundos de cada prueba de mando: alerones, profundidad, direccion y reposo
const SCAN_TIME := 0.3                        # segundos que tarda la persiana en revelar el avion
const SCAN_BOTTOM := -1.5                     # altura (respecto al avion) donde empieza la persiana (m): bajo el vientre
const SCAN_TOP := 4.5                         # altura donde acaba: sobre la cola y la cabina
const SCAN_BAND := 1.2                        # altura (m) bajo el borde revelado donde solo se ven lineas
const SCAN_STEP := 0.25                       # la persiana sube a saltos de esta altura (m): movimiento mecanico, sin deslizar
const SCAN_SLATS := 6.0                       # lineas de la persiana por metro
const SCAN_DUTY := 0.5                        # fraccion de cada linea de la persiana que se ve

var g: Game
var camera := HangarCamera.new()
var _dust: CPUParticles3D
var _puff: CPUParticles3D                     # bocanada de humo al arrancar el motor
var _fresh := true                            # true en el primer fotograma tras abrir el hangar: la camara acaba de saltar y no debe desenfocar
var _clock := 0.0                             # tiempo del vaiven del avion
var _test_clock := 0.0                        # tiempo de la prueba de mandos: se reinicia al cambiar de avion
var _spin := PROP_SPIN                        # giro actual de la helice (rad/s)
var _spin_goal := PROP_SPIN                   # giro al que tiende
var _scan_mat: ShaderMaterial                 # material con el que el avion se descubre
var _scan_t := SCAN_TIME                      # tiempo de la persiana; SCAN_TIME o mas = sin persiana en curso
var _scan_meshes: Array[MeshInstance3D] = []  # mallas del avion que llevan el material de persiana

## Crea la plataforma, las luces y el polvo. El nodo debe estar ya en el arbol.
func build(game: Game) -> void:
	g = game
	position = PLANE_POS
	_scan_mat = ShaderMaterial.new()
	_scan_mat.shader = load("res://hangar_scan.gdshader")
	_scan_mat.set_shader_parameter("specular_amount", VoxModels.VOX_SPECULAR)
	_scan_mat.set_shader_parameter("band", SCAN_BAND)
	_scan_mat.set_shader_parameter("slat_density", SCAN_SLATS)
	_scan_mat.set_shader_parameter("slat_duty", SCAN_DUTY)
	_build_platform()
	_build_lights()
	_build_dust()
	_build_puff()
	visible = false

## Muestra u oculta el hangar y cambia la luz del mundo. Al abrirlo, el avion se descubre con la persiana.
func set_active(on: bool) -> void:
	visible = on
	_dust.emitting = on
	g.world.set_hangar_look(on)
	if on:
		camera.snap()
		_fresh = true
		_apply_blur(g.cam.global_transform, 1.0 / Engine.physics_ticks_per_second)   # sin movimiento hasta el primer fotograma
		_clock = 0.0
		_test_clock = 0.0
		_start_scan()
	else:
		_finish_scan()

## Se ha elegido otro avion: la camara barre al otro lado, la prueba de mandos vuelve a empezar y el avion entra de nuevo.
func on_model_changed() -> void:
	camera.kick()
	_test_clock = 0.0
	_start_scan()

## Se pulsa empezar: la camara se lanza hacia el avion y la helice se revoluciona.
func on_launch() -> void:
	camera.dive()
	_spin_goal = LAUNCH_SPIN

## Empieza la entrada: el motor esta parado y el avion pasa al material de persiana, que lo descubre de abajo arriba.
func _start_scan() -> void:
	_finish_scan()
	_scan_meshes.clear()
	_collect_meshes(g.plane)
	for mi in _scan_meshes:
		mi.material_override = _scan_mat
	_spin = 0.0
	_spin_goal = 0.0
	_scan_t = 0.0
	_apply_scan()

## Termina la entrada (o la cancela): las mallas vuelven a su material normal.
func _finish_scan() -> void:
	for mi in _scan_meshes:
		if is_instance_valid(mi):
			mi.material_override = g.vox.vox_mat
	_scan_meshes.clear()
	_scan_t = SCAN_TIME

## Con el avion ya entero, el motor arranca: la helice coge vueltas, sale una bocanada de humo y la camara da un "clack".
func _engine_start() -> void:
	_spin_goal = PROP_SPIN
	_puff.restart()
	camera.clack()

func _collect_meshes(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			_scan_meshes.append(child)
		_collect_meshes(child)

## Altura de revelado segun el tiempo: sube rapido al principio y se asienta, pero a saltos de SCAN_STEP.
func _apply_scan() -> void:
	var p := clampf(_scan_t / SCAN_TIME, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - p, 3.0)
	var height := snappedf(lerpf(SCAN_BOTTOM, SCAN_TOP, eased), SCAN_STEP)
	_scan_mat.set_shader_parameter("reveal_y", PLANE_POS.y + height)

func update(delta: float) -> void:
	_clock += delta
	_test_clock += delta
	if _scan_t < SCAN_TIME:
		_scan_t += delta
		if _scan_t >= SCAN_TIME:
			_finish_scan()
			_engine_start()
		else:
			_apply_scan()
	g.plane.position = PLANE_POS + Vector3(0.0, sin(_clock * BOB_RATE * TAU) * BOB_AMP, 0.0)
	g.plane.rotation = Vector3(0.0, 0.0, sin(_clock * TILT_RATE * TAU) * TILT_AMP)
	_spin = lerpf(_spin, _spin_goal, 1.0 - exp(-SPIN_FOLLOW * delta))
	g.plane_prop.rotation.z += _spin * delta
	_puff.global_position = g.plane.to_global(PUFF_LOCAL)
	_test_surfaces()
	var vp := g.get_viewport()
	var mouse := ((vp.get_mouse_position() / vp.get_visible_rect().size - Vector2(0.5, 0.5)) * 2.0).clamp(-Vector2.ONE, Vector2.ONE)
	var before := g.cam.global_transform
	camera.update(g.cam, PLANE_POS, mouse, delta)
	_apply_blur(before if not _fresh else g.cam.global_transform, delta)
	_fresh = false
	g.menu.focus = g.cam.unproject_position(PLANE_POS)

## Desenfoque de movimiento con el mismo shader que en vuelo: lo que se mueve en pantalla al orbitar la camara se
## desenfoca, y el avion no. El shader mide el desplazamiento de un paso de fisica, asi que aqui se escala por el
## tiempo del fotograma para que el desenfoque no dependa de los fotogramas por segundo.
func _apply_blur(previous: Transform3D, delta: float) -> void:
	var step := 1.0 / Engine.physics_ticks_per_second
	g.world.blur_mat.set_shader_parameter("prev_view", Projection(previous.affine_inverse()))
	g.world.blur_mat.set_shader_parameter("strength", World.MOTION_BLUR * step / maxf(delta, step * 0.1))
	g.world.blur_mat.set_shader_parameter("clear_dist", g.cam.position.distance_to(g.plane.position) + World.PLANE_BLUR_MARGIN)

## Prueba los mandos del avion uno a uno: alerones, timon de profundidad, timon de direccion y reposo.
func _test_surfaces() -> void:
	var cycle := TEST_PHASE * 4.0
	var phase := int(fposmod(_test_clock, cycle) / TEST_PHASE)
	var swing := sin(fposmod(_test_clock, TEST_PHASE) / TEST_PHASE * TAU) * Flight.SURFACE_MAX
	var roll := swing if phase == 0 else 0.0
	var pitch := swing if phase == 1 else 0.0
	var yaw := swing if phase == 2 else 0.0
	var f := g.flight
	if f.aileron_l != null:
		f.aileron_l.rotation.x = roll
	if f.aileron_r != null:
		f.aileron_r.rotation.x = -roll
	if f.elevator != null:
		f.elevator.rotation.x = -pitch
	if f.rudder != null:
		f.rudder.rotation.y = yaw

## Material mate de pintura o piedra, sin brillo ni luz propia.
func _matte(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 1.0
	return m

func _add_box(size: Vector3, at: Vector3, mat: Material, shadow: bool = false) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = at
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

## Textura de hormigon de pixel gordo: grano, manchas de aceite y grietas. Siempre sale igual (semilla fija).
func _concrete_texture() -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = CONCRETE_SEED
	var img := Image.create(CONCRETE_SIZE, CONCRETE_SIZE, false, Image.FORMAT_RGB8)
	for y in CONCRETE_SIZE:
		for x in CONCRETE_SIZE:
			var n := rng.randf_range(-CONCRETE_NOISE, CONCRETE_NOISE)
			img.set_pixel(x, y, Color(CONCRETE_BASE.r + n, CONCRETE_BASE.g + n, CONCRETE_BASE.b + n * 0.8))
	for i in CONCRETE_STAINS:
		var c := Vector2(rng.randf_range(0.0, CONCRETE_SIZE), rng.randf_range(0.0, CONCRETE_SIZE))
		var radius := rng.randf_range(3.0, 7.0)
		for y in CONCRETE_SIZE:
			for x in CONCRETE_SIZE:
				if Vector2(x, y).distance_to(c) < radius:
					img.set_pixel(x, y, img.get_pixel(x, y).darkened(0.12))
	for i in CONCRETE_CRACKS:
		var p := Vector2(rng.randf_range(0.0, CONCRETE_SIZE), rng.randf_range(0.0, CONCRETE_SIZE))
		var dir := rng.randf_range(0.0, TAU)
		for step in CONCRETE_CRACK_LEN:
			img.set_pixel(posmod(int(p.x), CONCRETE_SIZE), posmod(int(p.y), CONCRETE_SIZE), CONCRETE_BASE.darkened(0.5))
			p += Vector2(cos(dir), sin(dir))
			dir += rng.randf_range(-0.6, 0.6)
	return ImageTexture.create_from_image(img)

func _build_platform() -> void:
	var top_y := -PLATFORM_DROP
	var concrete := StandardMaterial3D.new()
	concrete.albedo_texture = _concrete_texture()
	concrete.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	concrete.uv1_triplanar = true
	concrete.uv1_scale = Vector3.ONE * CONCRETE_TILING
	concrete.roughness = 1.0
	_add_box(PLATFORM_SIZE, Vector3(0.0, top_y - PLATFORM_SIZE.y * 0.5, 0.0), concrete, true)
	# bordillo de hormigon mas oscuro alrededor de la losa
	var curb := _matte(CONCRETE_BASE.darkened(0.3))
	var hx := PLATFORM_SIZE.x * 0.5 - CURB_SIZE.x * 0.5
	var hz := PLATFORM_SIZE.z * 0.5 - CURB_SIZE.x * 0.5
	for sign_z: float in [-1.0, 1.0]:
		_add_box(Vector3(PLATFORM_SIZE.x, CURB_SIZE.y, CURB_SIZE.x), Vector3(0.0, top_y + CURB_SIZE.y * 0.5, sign_z * hz), curb)
	for sign_x: float in [-1.0, 1.0]:
		_add_box(Vector3(CURB_SIZE.x, CURB_SIZE.y, PLATFORM_SIZE.z), Vector3(sign_x * hx, top_y + CURB_SIZE.y * 0.5, 0.0), curb)
	_build_paint(top_y)

## Pintura de pista gastada: franjas amarillas por tramos, con huecos donde se ha saltado, linea central blanca y numeracion.
func _build_paint(top_y: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = PAINT_SEED
	var yellow := _matte(MilitaryStyle.PAINT_YELLOW)
	var white := _matte(MilitaryStyle.PAINT_WHITE)
	var y := top_y + 0.02
	var edge_x := PLATFORM_SIZE.x * 0.5 - PAINT_INSET
	var edge_z := PLATFORM_SIZE.z * 0.5 - PAINT_INSET
	for sign_z: float in [-1.0, 1.0]:
		var x := -edge_x
		while x < edge_x:
			var dash := minf(rng.randf_range(PAINT_DASH.x, PAINT_DASH.y), edge_x - x)
			_add_box(Vector3(dash, 0.02, PAINT_WIDTH), Vector3(x + dash * 0.5, y, sign_z * edge_z), yellow)
			x += dash + rng.randf_range(PAINT_GAP.x, PAINT_GAP.y)
	for sign_x: float in [-1.0, 1.0]:
		var z := -edge_z
		while z < edge_z:
			var dash := minf(rng.randf_range(PAINT_DASH.x, PAINT_DASH.y), edge_z - z)
			_add_box(Vector3(PAINT_WIDTH, 0.02, dash), Vector3(sign_x * edge_x, y, z + dash * 0.5), yellow)
			z += dash + rng.randf_range(PAINT_GAP.x, PAINT_GAP.y)
	for i in CENTER_DASHES:
		if rng.randf() < CENTER_WEAR:
			continue   # un trazo gastado del todo
		_add_box(Vector3(CENTER_DASH.x, 0.02, CENTER_DASH.y), Vector3(0.0, y, (i - (CENTER_DASHES - 1) * 0.5) * CENTER_GAP), white)
	var number := Label3D.new()
	number.text = NUMBER_TEXT
	number.font = HudStyle.load_font()
	number.font_size = NUMBER_SIZE
	number.pixel_size = NUMBER_PIXEL
	number.modulate = Color(MilitaryStyle.PAINT_WHITE, 0.8)
	number.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	number.double_sided = true
	number.rotation_degrees = Vector3(-90.0, 180.0, 0.0)   # tumbado en el suelo y legible desde delante del avion
	number.position = Vector3(0.0, y + 0.01, NUMBER_Z)
	add_child(number)

func _spot(at: Vector3, col: Color, energy: float) -> void:
	var light := SpotLight3D.new()
	light.light_color = col
	light.light_energy = energy
	light.spot_range = SPOT_RANGE
	light.spot_angle = SPOT_ANGLE
	add_child(light)
	light.look_at_from_position(to_global(at), global_position, Vector3.UP)

func _build_lights() -> void:
	_spot(KEY_POS, KEY_COLOR, KEY_ENERGY)
	_spot(FILL_POS, FILL_COLOR, FILL_ENERGY)

func _build_dust() -> void:
	_dust = CPUParticles3D.new()
	_dust.amount = DUST_AMOUNT
	_dust.lifetime = DUST_LIFETIME
	_dust.preprocess = DUST_LIFETIME
	_dust.local_coords = false
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = DUST_EXTENTS
	_dust.direction = Vector3.UP
	_dust.spread = 180.0
	_dust.initial_velocity_min = DUST_SPEED.x
	_dust.initial_velocity_max = DUST_SPEED.y
	_dust.gravity = Vector3.ZERO
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * DUST_SIZE
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(MilitaryStyle.KHAKI, DUST_ALPHA)
	cube.material = m
	_dust.mesh = cube
	_dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_dust)

## Bocanada de humo de cubos para el arranque del motor: se dispara una vez y se desvanece subiendo.
func _build_puff() -> void:
	_puff = CPUParticles3D.new()
	_puff.amount = PUFF_AMOUNT
	_puff.lifetime = PUFF_LIFETIME
	_puff.one_shot = true
	_puff.explosiveness = 0.85
	_puff.emitting = false
	_puff.local_coords = false
	_puff.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_puff.emission_sphere_radius = 0.25
	_puff.direction = Vector3(0.0, 0.5, 1.0)
	_puff.spread = 35.0
	_puff.initial_velocity_min = PUFF_SPEED.x
	_puff.initial_velocity_max = PUFF_SPEED.y
	_puff.gravity = Vector3(0.0, PUFF_RISE, 0.0)
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([PUFF_COLOR_START, PUFF_COLOR_END])
	ramp.offsets = PackedFloat32Array([0.0, 1.0])
	_puff.color_ramp = ramp
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * PUFF_SIZE
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	cube.material = m
	_puff.mesh = cube
	_puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_puff)
