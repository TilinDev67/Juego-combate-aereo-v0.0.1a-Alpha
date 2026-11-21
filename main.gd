extends Node3D
## Combate aereo 3D con modelos de voxeles.
## Raton = apuntar (el avion gira hacia el cursor, estilo War Thunder).
## W/S/A/D/Q/E = ajuste manual opcional, Shift/Ctrl = acelerar/frenar.
## Espacio o clic izq = disparar, R = recargar, Esc = soltar raton,
## Enter = reiniciar tras ser derribado.

const VS := 0.5                 # tamano del voxel de los aviones (m)
const MIN_SPEED := 40.0
const MAX_SPEED := 140.0
const MAG_SIZE := 60
const FIRE_RATE := 14.0
const RELOAD_TIME := 2.0
const BULLET_SPEED := 700.0
const PLAYER_R := 4.5
const ENEMY_R := 5.0
const CLOUD_RANGE := 3500.0
const GRAVITY := 32.0           # caida de las balas (m/s^2)
const MOUSE_SENS := 1.0         # pixeles de cursor por pixel de raton
const CURSOR_RADIUS := 0.38     # radio maximo del cursor (fraccion del lado menor de la pantalla)
const CAM_MARGIN := 0.2         # margen maximo (rad) que la camara puede quedarse atras
const PITCH_RATE := 1.3
const ROLL_RATE := 2.6
const YAW_RATE := 0.5

const FACES := [
	[Vector3i(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
	[Vector3i(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
	[Vector3i(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)],
	[Vector3i(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	[Vector3i(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
	[Vector3i(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0)],
]

class Bullet:
	var node: MeshInstance3D
	var vel: Vector3
	var life := 1.8
	var from_player := true

class Enemy:
	var root: Node3D
	var model: Node3D
	var prop: Node3D
	var smoke: CPUParticles3D
	var health := 100.0
	var speed := 85.0
	var turn_rate := 1.5
	var evading := false
	var state_t := 0.0
	var evade_dir := Vector3.FORWARD
	var roll_dir := 1.0
	var jink_cd := 0.0
	var burst := 0
	var fire_cd := 0.0
	var rest := 1.0
	var dead := false
	var dead_t := 0.0
	var fall := 0.0

class Hud extends Control:
	var g
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		size = get_viewport_rect().size
		queue_redraw()

	func _t(p: Vector2, s: String, sz: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
		var f := ThemeDB.fallback_font
		draw_string_outline(f, p, s, align, w, sz, 6, Color.BLACK)
		draw_string(f, p, s, align, w, sz, col)

	func _draw() -> void:
		if g == null or g.cam == null:
			return
		var S := size
		var C := S / 2.0
		if g.flash > 0.0:
			draw_rect(Rect2(Vector2.ZERO, S), Color(1, 0, 0, g.flash * 0.3))
		if not g.over:
			_draw_play(S, C)
		else:
			draw_rect(Rect2(Vector2.ZERO, S), Color(0, 0, 0, 0.6))
			_t(Vector2(0, C.y - 40), "DERRIBADO", 80, Color(1, 0.25, 0.2), HORIZONTAL_ALIGNMENT_CENTER, S.x)
			_t(Vector2(0, C.y + 20), "Derribos: %d" % g.score, 36, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, S.x)
			_t(Vector2(0, C.y + 80), "Pulsa ENTER para reiniciar", 28, Color(1, 0.9, 0.4), HORIZONTAL_ALIGNMENT_CENTER, S.x)

	func _draw_play(S: Vector2, C: Vector2) -> void:
		var cam: Camera3D = g.cam
		# reticula
		var aim_t: float = 600.0 / (g.BULLET_SPEED + g.speed)
		var aim: Vector3 = g.plane.position + (-g.plane.transform.basis.z) * 600.0 + Vector3.DOWN * 0.5 * g.GRAVITY * aim_t * aim_t
		if not cam.is_position_behind(aim):
			var rp := cam.unproject_position(aim)
			var col := Color(0.3, 1, 0.4, 0.9)
			if g.target_locked:
				col = Color(1, 0.3, 0.2, 0.95)
			draw_arc(rp, 16, 0, TAU, 32, col, 2.0)
			draw_circle(rp, 2.0, col)
			for a in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				draw_line(rp + a * 16, rp + a * 26, col, 2.0)
			# hitmarker
			if g.hit_t > 0.0:
				var k: float = g.hit_t / 0.3
				var hc := Color(1, 0.15, 0.1, k) if g.hit_kill else Color(1, 1, 1, k)
				var r0 := 8.0 if not g.hit_kill else 10.0
				var r1 := 20.0 if not g.hit_kill else 34.0
				var w := 2.5 if not g.hit_kill else 4.0
				for dgn in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
					draw_line(rp + dgn * r0, rp + dgn * r1, hc, w)
		# cursor del raton (hacia donde quiere girar el avion)
		var cp: Vector2 = C + g.cursor_off
		draw_line(C, cp, Color(1, 1, 1, 0.25), 1.0)
		draw_arc(cp, 8, 0, TAU, 20, Color(1, 1, 1, 0.8), 1.5)
		draw_circle(cp, 1.5, Color(1, 1, 1, 0.8))
		# marcadores de enemigos
		for e in g.enemies:
			if e.dead:
				continue
			var wp: Vector3 = e.root.position
			var behind := cam.is_position_behind(wp)
			var p := cam.unproject_position(wp)
			if behind:
				p = S - p
			var dist: float = wp.distance_to(g.plane.position)
			var edge := Rect2(Vector2(40, 40), S - Vector2(80, 80))
			if not behind and edge.has_point(p):
				var r := 22.0
				var rc := Color(1, 0.25, 0.2)
				for s in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
					var c: Vector2 = p + s * r
					draw_line(c, c - Vector2(s.x * 9, 0), rc, 2.0)
					draw_line(c, c - Vector2(0, s.y * 9), rc, 2.0)
				_t(p + Vector2(-30, r + 22), "%d m" % int(dist), 16, rc, HORIZONTAL_ALIGNMENT_CENTER, 60)
			else:
				var q := Vector2(clampf(p.x, 40, S.x - 40), clampf(p.y, 40, S.y - 40))
				draw_circle(q, 9, Color(1, 0.25, 0.2, 0.9))
				_t(q + Vector2(-30, 28), "%d m" % int(dist), 14, Color(1, 0.5, 0.4), HORIZONTAL_ALIGNMENT_CENTER, 60)
		# salud
		var h: float = clampf(g.health / 100.0, 0.0, 1.0)
		_t(Vector2(24, S.y - 58), "SALUD", 18, Color.WHITE)
		draw_rect(Rect2(24, S.y - 48, 260, 20), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(26, S.y - 46, 256 * h, 16), Color(1.0 - h * 0.8, 0.3 + h * 0.6, 0.15))
		# municion
		var ax := S.x - 284
		_t(Vector2(ax, S.y - 58), "RECARGANDO" if g.reloading else "MUNICION  %d / %d" % [g.ammo, g.MAG_SIZE], 18, Color(1, 0.9, 0.4) if not g.reloading else Color(1, 0.5, 0.3))
		draw_rect(Rect2(ax, S.y - 48, 260, 20), Color(0, 0, 0, 0.6))
		var af: float = float(g.ammo) / g.MAG_SIZE
		if g.reloading:
			af = 1.0 - g.reload_t / g.RELOAD_TIME
		draw_rect(Rect2(ax + 2, S.y - 46, 256 * af, 16), Color(1, 0.8, 0.2) if not g.reloading else Color(1, 0.45, 0.2))
		# datos de vuelo
		_t(Vector2(24, 36), "Derribos: %d" % g.score, 28, Color.WHITE)
		_t(Vector2(24, 66), "Vel %d   Alt %d" % [int(g.speed), int(g.plane.position.y)], 18, Color(0.85, 0.95, 1))

var plane: Node3D
var plane_prop: Node3D
var psmoke: CPUParticles3D
var cam: Camera3D
var ground: MeshInstance3D
var hud: Hud
var pillars: Array[AABB] = []
var clouds: Array[MeshInstance3D] = []
var bullets: Array[Bullet] = []
var enemies: Array[Enemy] = []

var speed := 70.0
var score := 0
var health := 100.0
var ammo := MAG_SIZE
var reloading := false
var reload_t := 0.0
var fire_cd := 0.0
var gun_side := 1.0
var flash := 0.0
var over := false
var death_pos := Vector3.ZERO
var spawn_cd := 1.0
var target_locked := false
var cursor_off := Vector2.ZERO   # cursor en pantalla, en pixeles respecto al centro
var rate_p := 0.0
var rate_r := 0.0
var rate_y := 0.0
var sway_t := 0.0
var cam_q := Quaternion.IDENTITY
var hit_t := 0.0
var hit_kill := false

var vox_mat: StandardMaterial3D
var bullet_mesh: BoxMesh
var bullet_mat_p: StandardMaterial3D
var bullet_mat_e: StandardMaterial3D
var halo_mesh: BoxMesh
var halo_mat_p: StandardMaterial3D
var halo_mat_e: StandardMaterial3D
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	vox_mat = StandardMaterial3D.new()
	vox_mat.vertex_color_use_as_albedo = true
	vox_mat.roughness = 1.0
	bullet_mesh = BoxMesh.new()
	bullet_mesh.size = Vector3(0.35, 0.35, 10.0)
	bullet_mat_p = _glow_mat(Color(1.0, 0.95, 0.6), 10.0)
	bullet_mat_e = _glow_mat(Color(1.0, 0.55, 0.45), 10.0)
	halo_mesh = BoxMesh.new()
	halo_mesh.size = Vector3(1.1, 1.1, 16.0)
	halo_mat_p = _halo_mat(Color(1.0, 0.6, 0.05))
	halo_mat_e = _halo_mat(Color(1.0, 0.1, 0.05))
	_build_environment()
	_build_ground()
	_build_pillars()
	_build_clouds()
	plane = _make_plane(Color(0.45, 0.55, 0.3), Color(0.25, 0.4, 0.75), Color(0.9, 0.8, 0.2))
	add_child(plane)
	plane_prop = plane.get_node("Model/Prop")
	psmoke = _make_smoke(1.2)
	plane.add_child(psmoke)
	psmoke.position = Vector3(0, 0.3, 3.5)
	cam = Camera3D.new()
	cam.far = 9000.0
	cam.fov = 75.0
	add_child(cam)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	hud.g = self
	layer.add_child(hud)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_reset()

func _glow_mat(c: Color, energy: float = 3.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m

# halo aditivo alrededor del nucleo de la bala (da cuerpo al bloom)
func _halo_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, 0.35)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 4.0
	return m

# ------------------------------------------------------------------ reinicio

func _reset() -> void:
	for e in enemies:
		e.root.queue_free()
	enemies.clear()
	for b in bullets:
		b.node.queue_free()
	bullets.clear()
	score = 0
	health = 100.0
	ammo = MAG_SIZE
	reloading = false
	fire_cd = 0.0
	flash = 0.0
	speed = 70.0
	over = false
	spawn_cd = 1.5
	plane.visible = true
	plane.transform = Transform3D(Basis.IDENTITY, Vector3(0, 200, 0))
	psmoke.emitting = false
	cursor_off = Vector2.ZERO
	rate_p = 0.0
	rate_r = 0.0
	rate_y = 0.0
	hit_t = 0.0
	cam_q = _target_cam_q()
	_update_camera(0.0)

# ------------------------------------------------------------------ mundo

func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.25, 0.5, 0.85)
	sky_mat.sky_horizon_color = Color(0.7, 0.82, 0.95)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.82, 0.95)
	env.fog_density = 0.0005
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 2.5   # solo brilla lo muy intenso (balas), no el cielo ni el mundo
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	for lvl in [2, 3, 4, 5]:
		env.set_glow_level(lvl, 1.0)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 500.0
	add_child(sun)

func _build_ground() -> void:
	ground = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(14000, 14000)
	ground.mesh = pm
	var mat := ShaderMaterial.new()
	mat.shader = load("res://ground.gdshader")
	ground.material_override = mat
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)

func _build_pillars() -> void:
	var cols := [Color(0.7, 0.7, 0.75), Color(0.75, 0.65, 0.5), Color(0.55, 0.6, 0.7), Color(0.8, 0.5, 0.4)]
	for i in 250:
		var pos := Vector3(rng.randf_range(-5000, 5000), 0, rng.randf_range(-5000, 5000))
		if Vector2(pos.x, pos.z).length() < 150.0:
			continue
		var size := Vector3(rng.randf_range(20, 60), rng.randf_range(40, 260), rng.randf_range(20, 60))
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = cols[rng.randi() % cols.size()]
		mi.material_override = m
		mi.position = pos + Vector3(0, size.y / 2.0, 0)
		add_child(mi)
		pillars.append(AABB(mi.position - size / 2.0, size))

func _build_clouds() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://cloud.gdshader")
	var meshes: Array[ArrayMesh] = []
	for i in 6:
		meshes.append(_make_cloud_mesh(i * 977 + 13))
	for i in 70:
		var mi := MeshInstance3D.new()
		mi.mesh = meshes[i % meshes.size()]
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var s := rng.randf_range(1.0, 2.4)
		mi.scale = Vector3(s, s * rng.randf_range(0.8, 1.2), s)
		mi.rotation.y = rng.randf_range(0, TAU)
		mi.position = Vector3(rng.randf_range(-CLOUD_RANGE, CLOUD_RANGE), rng.randf_range(150, 750), rng.randf_range(-CLOUD_RANGE, CLOUD_RANGE))
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
	return _voxel_mesh(d, 14.0, 0.04)

# ------------------------------------------------------------------ voxeles

func _box(d: Dictionary, a: Vector3i, b: Vector3i, c: Color) -> void:
	for x in range(a.x, b.x + 1):
		for y in range(a.y, b.y + 1):
			for z in range(a.z, b.z + 1):
				d[Vector3i(x, y, z)] = c

func _voxel_mesh(d: Dictionary, vs: float, jitter: float = 0.08) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := vs * 0.5
	for k in d.keys():
		var pos: Vector3i = k
		var col: Color = d[k]
		var hs := absi((pos.x * 73856093) ^ (pos.y * 19349663) ^ (pos.z * 83492791)) % 100
		var j := 1.0 + (float(hs) / 100.0 - 0.5) * 2.0 * jitter
		var c := Color(col.r * j, col.g * j, col.b * j, 1.0)
		for f in FACES:
			if d.has(pos + (f[0] as Vector3i)):
				continue
			var n := Vector3(f[0] as Vector3i)
			var u: Vector3 = f[1]
			var v: Vector3 = f[2]
			var c0 := Vector3(pos) * vs
			var p: Array[Vector3] = [
				c0 + (n - u - v) * h, c0 + (n + u - v) * h,
				c0 + (n + u + v) * h, c0 + (n - u + v) * h]
			for idx in [0, 2, 1, 0, 3, 2]:
				st.set_color(c)
				st.set_normal(n)
				st.add_vertex(p[idx])
	return st.commit()

func _make_plane(body: Color, wing: Color, accent: Color) -> Node3D:
	var d := {}
	_box(d, Vector3i(-1, -1, -7), Vector3i(1, 1, 8), body)
	_box(d, Vector3i(-1, -1, -7), Vector3i(1, -1, 8), body.darkened(0.3))
	_box(d, Vector3i(-1, -1, -8), Vector3i(1, 1, -8), Color(0.25, 0.25, 0.28))
	d[Vector3i(0, 0, -9)] = accent
	_box(d, Vector3i(0, 0, 9), Vector3i(0, 1, 12), body)
	_box(d, Vector3i(-9, 0, -1), Vector3i(9, 0, 3), wing)
	_box(d, Vector3i(-3, -1, -1), Vector3i(3, -1, 3), wing.darkened(0.2))
	_box(d, Vector3i(-9, 0, -1), Vector3i(-8, 0, 3), accent)
	_box(d, Vector3i(8, 0, -1), Vector3i(9, 0, 3), accent)
	_box(d, Vector3i(-4, 0, 10), Vector3i(4, 0, 12), wing)
	_box(d, Vector3i(0, 1, 10), Vector3i(0, 3, 12), accent)
	_box(d, Vector3i(-1, 2, -3), Vector3i(1, 2, 0), Color(0.55, 0.8, 1.0))
	_box(d, Vector3i(0, 3, -2), Vector3i(0, 3, -1), Color(0.55, 0.8, 1.0))
	var root := Node3D.new()
	var model := Node3D.new()
	model.name = "Model"
	root.add_child(model)
	var hull := MeshInstance3D.new()
	hull.mesh = _voxel_mesh(d, VS)
	hull.material_override = vox_mat
	model.add_child(hull)
	# helice: "+" de voxeles que gira
	var pd := {}
	_box(pd, Vector3i(0, -5, 0), Vector3i(0, 5, 0), Color(0.12, 0.12, 0.12))
	_box(pd, Vector3i(-5, 0, 0), Vector3i(5, 0, 0), Color(0.12, 0.12, 0.12))
	_box(pd, Vector3i(0, 0, 0), Vector3i(0, 0, 0), accent)
	var prop := Node3D.new()
	prop.name = "Prop"
	prop.position = Vector3(0, 0, -9.0 * VS - 0.45)
	var pm := MeshInstance3D.new()
	pm.mesh = _voxel_mesh(pd, VS, 0.0)
	pm.material_override = vox_mat
	prop.add_child(pm)
	model.add_child(prop)
	return root

# ------------------------------------------------------------------ particulas

func _smoke_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

func _make_smoke(size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * size
	bm.material = _smoke_mat()
	p.mesh = bm
	p.amount = 40
	p.lifetime = 1.8
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0, 2.5, 0)
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 1.0])
	p.color_ramp = g
	var c := Curve.new()
	c.add_point(Vector2(0, 0.5))
	c.add_point(Vector2(1, 2.4))
	p.scale_amount_curve = c
	p.emitting = false
	return p

func _explode(pos: Vector3, sc: float) -> void:
	var p := CPUParticles3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * 1.5 * sc
	var m := _smoke_mat()
	bm.material = m
	p.mesh = bm
	p.amount = int(clampf(60.0 * sc, 8.0, 120.0))
	p.lifetime = 1.3
	p.one_shot = true
	p.explosiveness = 0.95
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 8.0 * sc
	p.initial_velocity_max = 35.0 * sc
	p.gravity = Vector3(0, -9, 0)
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 0.95, 0.4, 1), Color(1, 0.45, 0.05, 1), Color(0.2, 0.2, 0.2, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	p.color_ramp = g
	var c := Curve.new()
	c.add_point(Vector2(0, 1.0))
	c.add_point(Vector2(1, 0.2))
	p.scale_amount_curve = c
	add_child(p)
	p.position = pos
	p.emitting = true
	get_tree().create_timer(3.0).timeout.connect(p.queue_free)

# ------------------------------------------------------------------ bucle

func _physics_process(delta: float) -> void:
	flash = maxf(flash - delta * 2.0, 0.0)
	hit_t = maxf(hit_t - delta, 0.0)
	_update_clouds()
	ground.position = Vector3(plane.position.x, 0, plane.position.z)
	if over:
		_update_bullets(delta)
		cam.look_at(death_pos, Vector3.UP)
		return
	_fly(delta)
	_shoot(delta)
	_update_enemies(delta)
	_update_bullets(delta)
	_check_player_collisions()
	_update_smoke()
	_update_camera(delta)
	_check_lock()

func _update_clouds() -> void:
	var pp := plane.position
	for c in clouds:
		var o := c.position - pp
		o.x = wrapf(o.x, -CLOUD_RANGE, CLOUD_RANGE)
		o.z = wrapf(o.z, -CLOUD_RANGE, CLOUD_RANGE)
		c.position = Vector3(pp.x + o.x, c.position.y, pp.z + o.z)

func _axis(neg: Key, pos: Key) -> float:
	return float(Input.is_physical_key_pressed(pos)) - float(Input.is_physical_key_pressed(neg))

## Control estilo War Thunder: el raton mueve un cursor (aim_dir) y el
## "piloto automatico" hace girar el avion hacia el, con inercia suave.
func _fly(delta: float) -> void:
	var throttle := _axis(KEY_CTRL, KEY_SHIFT)
	speed = clampf(speed + throttle * 40.0 * delta, MIN_SPEED, MAX_SPEED)
	var b := plane.transform.basis
	# el cursor vive en la pantalla: su posicion respecto al centro da la
	# direccion deseada en el marco del avion (no depende del mundo)
	var vs := get_viewport().get_visible_rect().size
	var max_r := minf(vs.x, vs.y) * CURSOR_RADIUS
	if cursor_off.length() > max_r:
		cursor_off = cursor_off.normalized() * max_r
	var ray := cam.project_ray_normal(vs / 2.0 + cursor_off)
	var local := Basis(Vector3.RIGHT, -0.09) * (cam.basis.inverse() * ray)
	var ang := Vector3(0, 0, -1).angle_to(local)
	var pitch_cmd := clampf(local.y * 3.0, -1.0, 1.0)
	var roll_cmd := clampf(local.x * 4.0, -1.0, 1.0)
	var yaw_cmd := clampf(local.x * 1.0, -1.0, 1.0)
	# con el cursor cerca del morro, nivela las alas
	roll_cmd += clampf(b.x.y * 2.0, -1.0, 1.0) * clampf(1.0 - ang / 0.25, 0.0, 1.0)
	# teclas: ajuste manual opcional
	pitch_cmd += _axis(KEY_W, KEY_S)
	roll_cmd += _axis(KEY_A, KEY_D)
	yaw_cmd += _axis(KEY_E, KEY_Q)
	pitch_cmd = clampf(pitch_cmd, -1.0, 1.0)
	roll_cmd = clampf(roll_cmd, -1.0, 1.0)
	yaw_cmd = clampf(yaw_cmd, -1.0, 1.0)
	# inercia: las velocidades angulares siguen suavemente a la orden
	var k := 1.0 - exp(-delta * 5.0)
	rate_p = lerpf(rate_p, pitch_cmd, k)
	rate_r = lerpf(rate_r, roll_cmd, k)
	rate_y = lerpf(rate_y, yaw_cmd, k)
	b = b.rotated(b.x, rate_p * PITCH_RATE * delta)
	b = b.rotated(b.z, -rate_r * ROLL_RATE * delta)
	b = b.rotated(b.y, rate_y * YAW_RATE * delta)
	b = b.rotated(Vector3.UP, b.x.y * delta)
	plane.transform.basis = b.orthonormalized()
	plane.position += -plane.transform.basis.z * speed * delta
	plane_prop.rotation.z += (30.0 + speed * 0.2) * delta
	# balanceo visual (sway): se inclina con el giro y flota con turbulencia suave
	sway_t += delta
	var m: Node3D = plane.get_node("Model")
	m.rotation = Vector3(
		rate_p * 0.08 + sin(sway_t * 1.1) * 0.012,
		-rate_y * 0.10 + sin(sway_t * 0.7 + 2.0) * 0.01,
		-rate_r * 0.18 + sin(sway_t * 0.8 + 1.0) * 0.03)
	m.position = Vector3(sin(sway_t * 0.9) * 0.08, sin(sway_t * 1.3) * 0.06, 0)

func _target_cam_q() -> Quaternion:
	return Quaternion(plane.transform.basis)

## Camara rigidamente fija al cuerpo del avion (sin retraso ni suavizado,
## asi no hay vaivenes al cabecear). El balanceo visual no la afecta.
func _update_camera(_delta: float) -> void:
	var b := plane.transform.basis
	cam.position = plane.position + b * Vector3(0, 3.5, 13.0)
	cam.basis = b * Basis(Vector3.RIGHT, -0.09)

func _update_smoke() -> void:
	if health < 60.0:
		psmoke.emitting = true
		var dark := health < 30.0
		psmoke.color = Color(0.12, 0.12, 0.12) if dark else Color(0.6, 0.6, 0.6)
		psmoke.amount = 70 if dark else 40
	else:
		psmoke.emitting = false

func _check_lock() -> void:
	target_locked = false
	var fwd := -plane.transform.basis.z
	for e in enemies:
		if e.dead:
			continue
		var to := e.root.position - plane.position
		var tt := to.length() / (BULLET_SPEED + speed)
		to += Vector3.UP * 0.5 * GRAVITY * tt * tt   # compensa la caida de la bala
		if to.length() < 700.0 and fwd.angle_to(to) < 0.05:
			target_locked = true

# ------------------------------------------------------------------ disparo

func _start_reload() -> void:
	if reloading or ammo >= MAG_SIZE:
		return
	reloading = true
	reload_t = RELOAD_TIME

func _shoot(delta: float) -> void:
	fire_cd -= delta
	if reloading:
		reload_t -= delta
		if reload_t <= 0.0:
			reloading = false
			ammo = MAG_SIZE
		return
	if ammo <= 0:
		_start_reload()
		return
	var want := Input.is_physical_key_pressed(KEY_SPACE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if want and fire_cd <= 0.0:
		fire_cd = 1.0 / FIRE_RATE
		ammo -= 1
		gun_side = -gun_side
		var b := plane.transform.basis
		var fwd := -b.z
		var origin := plane.position + b * Vector3(2.8 * gun_side, -0.3, -1.5)
		_spawn_bullet(origin, fwd * (BULLET_SPEED + speed), true)

func _spawn_bullet(pos: Vector3, vel: Vector3, from_player: bool) -> void:
	var bl := Bullet.new()
	bl.from_player = from_player
	bl.vel = vel
	var mi := MeshInstance3D.new()
	mi.mesh = bullet_mesh
	mi.material_override = bullet_mat_p if from_player else bullet_mat_e
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var halo := MeshInstance3D.new()
	halo.mesh = halo_mesh
	halo.material_override = halo_mat_p if from_player else halo_mat_e
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_child(halo)
	add_child(mi)
	mi.transform = Transform3D(_bullet_basis(vel), pos)
	bl.node = mi
	bullets.append(bl)

func _bullet_basis(vel: Vector3) -> Basis:
	var dir := vel.normalized()
	var upv := Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT
	return Basis.looking_at(dir, upv)

func _seg_dist(a: Vector3, b: Vector3, p: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return (a + ab * t).distance_to(p)

func _update_bullets(dt: float) -> void:
	for i in range(bullets.size() - 1, -1, -1):
		var b := bullets[i]
		var prev := b.node.position
		b.vel.y -= GRAVITY * dt
		var cur := prev + b.vel * dt
		b.life -= dt
		var kill := b.life <= 0.0 or cur.y < 0.0
		if not kill and cur.y < 300.0:
			for a in pillars:
				if a.has_point(cur):
					kill = true
					_explode(cur, 0.2)
					break
		if not kill:
			if b.from_player:
				for e in enemies:
					if not e.dead and _seg_dist(prev, cur, e.root.position) < ENEMY_R:
						_hit_enemy(e, 10.0)
						hit_t = 0.3
						hit_kill = e.dead
						_explode(cur, 0.25)
						kill = true
						break
			elif not over and _seg_dist(prev, cur, plane.position) < PLAYER_R:
				_damage_player(6.0)
				_explode(cur, 0.25)
				kill = true
		if kill:
			b.node.queue_free()
			bullets.remove_at(i)
		else:
			b.node.position = cur
			b.node.basis = _bullet_basis(b.vel)

# ------------------------------------------------------------------ jugador

func _damage_player(n: float) -> void:
	health -= n
	flash = 1.0
	if health <= 0.0:
		_player_die()

func _player_die() -> void:
	if over:
		return
	health = 0.0
	over = true
	death_pos = plane.position
	plane.visible = false
	psmoke.emitting = false
	_explode(death_pos, 2.0)

func _check_player_collisions() -> void:
	var p := plane.position
	if p.y < 3.0:
		_player_die()
		return
	if p.y < 300.0:
		for a in pillars:
			if a.grow(2.0).has_point(p):
				_player_die()
				return
	for e in enemies:
		if not e.dead and e.root.position.distance_to(p) < PLAYER_R + ENEMY_R:
			_hit_enemy(e, 999.0)
			_damage_player(45.0)

# ------------------------------------------------------------------ enemigos

func _spawn_enemy() -> void:
	var e := Enemy.new()
	e.root = _make_plane(Color(0.6, 0.2, 0.18), Color(0.3, 0.3, 0.33), Color(0.95, 0.85, 0.3))
	e.model = e.root.get_node("Model")
	e.prop = e.root.get_node("Model/Prop")
	e.smoke = _make_smoke(1.2)
	e.root.add_child(e.smoke)
	e.smoke.position = Vector3(0, 0.3, 3.5)
	e.speed = minf(80.0 + score * 3.0, 112.0)
	e.turn_rate = minf(1.3 + score * 0.08, 2.1)
	add_child(e.root)
	var a := rng.randf_range(0, TAU)
	var pos := plane.position + Vector3(cos(a), 0, sin(a)) * 900.0
	pos.y = clampf(plane.position.y + rng.randf_range(-60, 80), 120.0, 400.0)
	e.root.position = pos
	e.root.look_at(plane.position, Vector3.UP)
	e.jink_cd = 3.0
	enemies.append(e)

func _hit_enemy(e: Enemy, dmg: float) -> void:
	if e.dead:
		return
	e.health -= dmg
	if e.health <= 0.0:
		e.dead = true
		e.dead_t = 0.0
		e.fall = 0.0
		score += 1
		spawn_cd = 2.5
		_explode(e.root.position, 0.9)

func _kill_enemy(e: Enemy) -> void:
	_explode(e.root.position, 2.2)
	e.root.queue_free()
	enemies.erase(e)

func _update_enemies(dt: float) -> void:
	spawn_cd -= dt
	var target_count := mini(1 + score / 3, 4)
	var alive := 0
	for e in enemies:
		if not e.dead:
			alive += 1
	if alive < target_count and spawn_cd <= 0.0:
		_spawn_enemy()
		spawn_cd = 3.0
	for e in enemies.duplicate():
		_update_enemy(e, dt)

func _level(e: Enemy) -> void:
	var f := -e.root.basis.z
	if absf(f.y) > 0.97:
		return
	var r := f.cross(Vector3.UP).normalized()
	var u := r.cross(f)
	e.root.basis = Basis(r, u, -f)

func _update_enemy(e: Enemy, dt: float) -> void:
	var pos := e.root.position
	var fwd := -e.root.basis.z
	e.prop.rotation.z += 35.0 * dt
	# humo segun dano
	var hurt := e.health < 50.0 or e.dead
	e.smoke.emitting = hurt
	e.smoke.color = Color(0.1, 0.1, 0.1) if (e.dead or e.health < 25.0) else Color(0.6, 0.6, 0.6)
	if e.dead:
		e.dead_t += dt
		e.fall += 70.0 * dt
		e.root.basis = e.root.basis.rotated(e.root.basis.x, -0.6 * dt)
		e.model.rotation.z += 5.0 * dt
		e.root.position += fwd * e.speed * 0.7 * dt + Vector3.DOWN * e.fall * dt
		if e.root.position.y <= 1.0 or e.dead_t > 5.0:
			_kill_enemy(e)
		return

	var to_p := plane.position - pos
	var dist := to_p.length()
	var pvel := -plane.transform.basis.z * speed
	var bspeed := 560.0 + e.speed
	var t_lead := clampf(dist / bspeed, 0.0, 2.5)
	var aim := plane.position + pvel * t_lead * 0.85 + Vector3.UP * 0.5 * GRAVITY * t_lead * t_lead
	var lead_dir := (aim - pos).normalized()
	var dir := lead_dir

	e.state_t -= dt
	e.jink_cd -= dt
	if e.evading:
		dir = e.evade_dir
		e.model.rotation.z += 6.0 * e.roll_dir * dt
		if e.state_t <= 0.0:
			e.evading = false
	else:
		var pf := -plane.transform.basis.z
		var side := fwd.cross(Vector3.UP).normalized()
		if dist < 90.0 and fwd.dot(to_p.normalized()) > 0.3:
			# demasiado cerca: rompe para evitar la colision
			e.evading = true
			e.state_t = 2.0
			var sgn := 1.0 if rng.randf() < 0.5 else -1.0
			e.roll_dir = sgn
			e.evade_dir = (fwd + side * sgn * 1.5 + Vector3.UP * rng.randf_range(-0.2, 0.8)).normalized()
		elif e.jink_cd <= 0.0 and dist < 450.0 and pf.dot(-to_p.normalized()) > 0.985:
			# el jugador le apunta: maniobra evasiva
			e.evading = true
			e.state_t = 1.3
			var sgn2 := 1.0 if rng.randf() < 0.5 else -1.0
			e.roll_dir = sgn2
			e.evade_dir = (fwd + side * sgn2 * 1.2 + Vector3.UP * rng.randf_range(-0.6, 0.8)).normalized()
			e.jink_cd = rng.randf_range(3.0, 5.0)

	# evitar suelo, techo y edificios
	if pos.y < 90.0:
		dir.y = maxf(dir.y, 0.6)
		dir = dir.normalized()
	if pos.y < 45.0:
		dir = Vector3(fwd.x, 1.2, fwd.z).normalized()
	if pos.y > 520.0:
		dir.y = minf(dir.y, -0.3)
		dir = dir.normalized()
	var ahead := pos + fwd * 140.0
	if ahead.y < 300.0:
		for a in pillars:
			if a.grow(25.0).has_point(ahead):
				dir = Vector3(fwd.x * 0.3, 1.0, fwd.z * 0.3).normalized()
				break

	# giro limitado
	var ang := fwd.angle_to(dir)
	var axis := fwd.cross(dir)
	var bank := 0.0
	if axis.length() > 0.0001 and ang > 0.001:
		var step := minf(ang, e.turn_rate * dt)
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
		if e.fire_cd <= 0.0 and not e.evading:
			e.fire_cd = 0.09
			e.burst -= 1
			var spread := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 0.012
			_spawn_bullet(e.root.position + nf * 3.0, (nf + spread).normalized() * bspeed, false)
	elif e.rest <= 0.0 and not e.evading and dist < 600.0 and nf.angle_to(lead_dir) < 0.07:
		e.burst = 8
		e.rest = rng.randf_range(1.2, 2.5)

	# colision enemigo con suelo / edificios
	var np := e.root.position
	var crashed := np.y < 2.0
	if not crashed and np.y < 300.0:
		for a in pillars:
			if a.has_point(np):
				crashed = true
				break
	if crashed:
		_hit_enemy(e, 999.0)

# ------------------------------------------------------------------ entrada

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and not over \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		cursor_off += event.relative * MOUSE_SENS

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k: Key = event.keycode
		if k == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif k == KEY_ENTER or k == KEY_KP_ENTER:
			if over:
				_reset()
		elif k == KEY_R and not over:
			_start_reload()
