extends Node3D
class_name Game
## Combate aereo 3D con modelos de voxeles.
## Raton = mover el punto de mira, un aro fijo en el mundo; el avion gira hacia el y se estabiliza ahi.
## W/S/A/D/Q/E = ajuste manual opcional, Shift/Ctrl = acelerar/frenar.
## Clic der. (mantener) = zoom de la camara. C o clic central (mantener) = mirada libre alrededor del avion.
## Espacio o clic izq = disparar, R = recargar, Esc = pausa (graficos y sonido),
## Enter = volver al hangar tras ser derribado, M = volver al hangar para cambiar de avion.
## La batalla es continua: al volver del hangar los enemigos, los aliados y los derribos siguen donde estaban.
## Las teclas son acciones del InputMap definidas en Controls (controls.gd).
##
## Este script solo coordina: guarda el estado central del jugador y llama a cada modulo en orden.
## Los modulos (World, GameSound, VoxModels, Effects, Weapons, AiPlanes, Flight, ChaseCam, Hud)
## viven cada uno en su archivo y acceden a este estado con "g".

const ZONE_CAPACITY := 0.6        # fraccion de la salud maxima que aguanta una zona antes de verse destruida
const RESPAWN_ALT := 250.0        # altura (m) a la que reaparece el jugador en una batalla en curso
const RESPAWN_RADIUS := 1500.0    # distancia (m) al punto donde dejo la batalla en la que se buscan sitios de reaparicion
## Opcion del menu de pausa -> parte del HUD que enciende o apaga.
const HUD_PARTS := {
	PauseMenu.Option.HUD_TAPES: Hud.Part.TAPES,
	PauseMenu.Option.HUD_COMPASS: Hud.Part.COMPASS,
	PauseMenu.Option.HUD_LADDER: Hud.Part.LADDER,
	PauseMenu.Option.HUD_DOLL: Hud.Part.DOLL,
	PauseMenu.Option.HUD_MARKERS: Hud.Part.MARKERS,
	PauseMenu.Option.HUD_INFO: Hud.Part.INFO,
	PauseMenu.Option.HUD_STATUS: Hud.Part.STATUS}
const RESPAWN_CANDIDATES := 8     # sitios probados alrededor de ese punto: se elige el mas lejano a los enemigos

# estado central compartido
var plane: Node3D
var plane_prop: Node3D
var cam: Camera3D
var hud: Hud
var menu: StartMenu
var rng := RandomNumberGenerator.new()
var speed := 70.0
var throttle := Flight.START_THROTTLE     # acelerador 0..1
var g_force := 1.0               # fuerza G suavizada
var health := 100.0
var max_health := 100.0          # salud del avion elegido
var agility := 1.0               # agilidad del avion elegido (multiplica la autoridad de los mandos)
var player_spec: PlaneModels.Spec
var models: Array[PlaneModels.Spec] = []
var menu_open := true            # true = menu de inicio: el juego esta parado y se ve el hangar
var score := 0
var credits := 0                 # creditos para la tienda del hangar (Shop.KILL_CREDITS por derribo)
var shop_tiers := PackedInt32Array([0, 0, 0])   # nivel comprado de cada mejora de la tienda; se pierde al ser derribado
var upgrades_lost := false       # true = las mejoras se perdieron al ser derribado (lo muestra la pantalla de derribo)
var over := false
var battle_live := false         # true = hay una batalla en curso: el menu no la reinicia y el jugador reaparece en ella
var leaving := false             # true = la persiana se cierra camino del hangar
var death_pos := Vector3.ZERO
var flash := 0.0
var hit_t := 0.0
var hit_kill := false
var aim_dir := Vector3.FORWARD   # punto de mira: direccion en el mundo hacia la que el avion quiere volar
var vel_dir := Vector3.FORWARD   # direccion real de la trayectoria: el morro la arrastra con retraso (derrape)
var zones: PlaneZones            # zonas de dano del avion elegido
var zone_damage := PackedFloat32Array()  # dano acumulado de cada zona (0 = intacta, 1 = destruida); solo informa en el HUD

# modulos
var vox: VoxModels
var world: World
var sound: GameSound
var fx: Effects
var weapons: Weapons
var ai: AiPlanes
var flight: Flight
var chase: ChaseCam
var hangar: HangarScene           # escenario del menu de inicio
var music: MusicPlayer            # musica de fondo de cada pais
var net: Net                      # red: anfitrion o cliente, lista de pilotos
var lobby: Lobby                  # pantalla previa al hangar: solo, anfitrion o unirse
var pause_menu: PauseMenu         # menu de pausa (Esc): graficos y sonido
var pilots: RemotePilots          # aviones de los demas jugadores

func _ready() -> void:
	Controls.register()
	rng.randomize()
	vox = VoxModels.new()
	world = World.new()
	sound = GameSound.new()
	fx = Effects.new()
	weapons = Weapons.new()
	ai = AiPlanes.new()
	ai.name = "AiPlanes"   # el mismo nombre en todos los equipos: los RPC se enrutan por la ruta del nodo
	flight = Flight.new()
	chase = ChaseCam.new()
	for m in [world, sound, fx, weapons, ai, flight, chase]:
		m.g = self
		add_child(m)
	music = MusicPlayer.new()
	add_child(music)
	weapons.setup()
	world.build_environment()
	world.build_ground()
	world.build_clouds()
	sound.build_audio()
	models = PlaneModels.all()
	_build_player(0)
	cam = Camera3D.new()
	cam.far = 9000.0
	cam.fov = ChaseCam.CAM_FOV_MIN
	cam.doppler_tracking = Camera3D.DOPPLER_TRACKING_PHYSICS_STEP
	add_child(cam)
	world.build_motion_blur()
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	hud.g = self
	var hud_view := HudView.new()
	hud_view.hud = hud
	layer.add_child(hud_view)
	menu = StartMenu.new()
	menu.models = models
	for m in models:
		menu.silhouettes.append(vox.zones(m.model, StartMenu.ICON_SIZE))
	menu.chosen.connect(_on_model_chosen)
	menu.confirmed.connect(_start_game)
	menu.shop_buy.connect(_on_shop_buy)
	layer.add_child(menu)
	hangar = HangarScene.new()
	add_child(hangar)
	hangar.build(self)
	menu.launching.connect(hangar.on_launch)
	net = Net.new()
	net.name = "Net"   # el mismo nombre en todos los equipos: los RPC se enrutan por la ruta del nodo
	add_child(net)
	net.link_lost.connect(_on_link_lost)
	pilots = RemotePilots.new()
	pilots.name = "RemotePilots"
	pilots.g = self
	pilots.net = net
	add_child(pilots)
	menu.visible = false   # primero el lobby; el hangar se abre al terminar (_on_lobby_done)
	lobby = Lobby.new()
	lobby.net = net
	layer.add_child(lobby)
	lobby.done.connect(_on_lobby_done)
	pause_menu = PauseMenu.new()
	pause_menu.option_changed.connect(_on_option_changed)
	pause_menu.volume_changed.connect(_on_volume_changed)
	pause_menu.resumed.connect(_on_resumed)
	layer.add_child(pause_menu)

## Aplica un interruptor del menu de pausa.
func _on_option_changed(option: int, on: bool) -> void:
	if HUD_PARTS.has(option):
		hud.set_part(HUD_PARTS[option], on)
		return
	match option:
		PauseMenu.Option.AO:
			vox.set_ao(on)
		PauseMenu.Option.RAYS:
			world.set_rays(on)

## Aplica un deslizador de volumen del menu de pausa (0 a 1).
func _on_volume_changed(option: int, volume: float) -> void:
	match option:
		PauseMenu.Option.GUNS:
			sound.guns_volume = volume
		PauseMenu.Option.ENGINE:
			sound.mixer.set_engine_volume(volume)
		PauseMenu.Option.MUSIC:
			sound.mixer.set_music_volume(volume)

## Abre la pausa. En red la batalla no se puede parar (la IA es del anfitrion): solo se muestra el menu.
func _open_pause() -> void:
	get_tree().paused = not net.is_online()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	pause_menu.open()

func _on_resumed() -> void:
	get_tree().paused = false
	if not over:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_lobby_done() -> void:
	_open_menu()   # el lobby sigue unos instantes con la cortina y se borra solo (ver Lobby._process)

## Se pierde al anfitrion: la batalla era suya, asi que se vuelve al lobby con un aviso.
func _on_link_lost() -> void:
	Lobby.notice = "Se perdio la conexion con el anfitrion."
	get_tree().reload_current_scene()

## Crea el avion del jugador con el modelo elegido y aplica sus caracteristicas.
func _build_player(i: int) -> void:
	player_spec = models[i]
	if plane != null:
		plane.queue_free()
	plane = PlaneModels.build(player_spec, vox, false, true)
	add_child(plane)
	plane_prop = plane.get_node("Model/Prop")
	flight.setup()
	zones = vox.zones(player_spec.model)
	zone_damage.resize(PlaneZones.COUNT)
	max_health = player_spec.health
	agility = player_spec.agility
	music.prepare(player_spec.country)

## Abre el menu de inicio: quita lo que haya en el aire y muestra el avion elegido en el hangar.
func _open_menu() -> void:
	menu_open = true
	over = false
	ai.set_present(false)
	if not battle_live and not net.is_online():
		ai.reset()
		fx.reset()
	weapons.reset()
	hud.visible = false
	menu.visible = true
	flight.stop_effects()
	music.stop()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_preview()
	hangar.set_active(true)

## Deja el avion elegido en su sitio del hangar.
func _show_preview() -> void:
	plane.visible = true
	plane.transform = Transform3D(Basis.IDENTITY, HangarScene.PLANE_POS)

## Sitio donde reaparece el jugador en una batalla en curso: el mas lejano a los enemigos entre varios alrededor de
## donde dejo la batalla, mirando al enemigo mas cercano.
func _respawn_transform() -> Transform3D:
	var best_p := Vector3(death_pos.x, RESPAWN_ALT, death_pos.z)
	var best_d := -1.0
	for i in RESPAWN_CANDIDATES:
		var a: float = TAU * float(i) / float(RESPAWN_CANDIDATES)
		var p := Vector3(death_pos.x + cos(a) * RESPAWN_RADIUS, RESPAWN_ALT, death_pos.z + sin(a) * RESPAWN_RADIUS)
		var near := _nearest_enemy(p)
		var d: float = INF if near == null else near.root.position.distance_to(p)
		if d > best_d:
			best_d = d
			best_p = p
	var facing := Vector3.FORWARD
	var target := _nearest_enemy(best_p)
	if target != null:
		var flat := target.root.position - best_p
		flat.y = 0.0
		if flat.length() > 1.0:
			facing = flat.normalized()
	return Transform3D(Basis.looking_at(facing, Vector3.UP), best_p)

func _nearest_enemy(from: Vector3) -> AiPlanes.AiPlane:
	var best: AiPlanes.AiPlane = null
	var best_d := INF
	for e in ai.enemies:
		if e.dead:
			continue
		var d := e.root.position.distance_to(from)
		if d < best_d:
			best_d = d
			best = e
	return best

## Deja la batalla para ir al hangar: la persiana se cierra y, al cubrir la pantalla, se abre el menu (ver _physics_process).
func _leave_battle() -> void:
	if leaving:
		return
	leaving = true
	if not over:
		death_pos = plane.position
	hud.close_shutter()

## Multiplicador de una mejora de la tienda (1.0 sin comprar).
func shop_mult(kind: int) -> float:
	return Shop.multiplier(kind, shop_tiers[kind])

func add_credits(n: int) -> void:
	credits += n
	if menu != null:
		menu.set_shop(credits, shop_tiers)

## Compra el siguiente nivel de una mejora si alcanzan los creditos.
func _on_shop_buy(kind: int) -> void:
	var cost := Shop.price(kind, shop_tiers[kind])
	var ok := cost > 0 and credits >= cost
	if ok:
		credits -= cost
		shop_tiers[kind] += 1
	menu.set_shop(credits, shop_tiers)
	menu.shop_result(kind, ok)

func _on_model_chosen(i: int) -> void:
	_build_player(i)
	_show_preview()
	hangar.on_model_changed()

func _start_game() -> void:
	menu_open = false
	menu.visible = false
	hangar.set_active(false)
	hud.visible = true
	hud.open_shutter()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	ai.set_present(true)
	if battle_live or (net.is_online() and (not net.is_authority() or pilots.any_alive())):
		_spawn_player(_respawn_transform())   # entra en una batalla que ya existe (la del anfitrion o la de otro jugador)
	else:
		_reset()
	battle_live = true

## Batalla nueva: quita a todos los aviones con IA, pone los derribos a cero y coloca al jugador en el punto de salida.
func _reset() -> void:
	ai.reset()
	fx.reset()
	score = 0
	_spawn_player(Transform3D(Basis.IDENTITY, Vector3(0, 200, 0)))

## Pone al jugador en el aire con su avion entero y el cargador lleno, sin tocar la batalla.
func _spawn_player(at: Transform3D) -> void:
	weapons.reset()
	max_health = player_spec.health * shop_mult(Shop.HEALTH)
	health = max_health
	upgrades_lost = false
	zone_damage.fill(0.0)
	flash = 0.0
	speed = player_spec.max_speed * Flight.START_SPEED_RATIO
	over = false
	plane.visible = true
	plane.transform = at
	flight.reset()
	aim_dir = -plane.transform.basis.z
	vel_dir = aim_dir
	throttle = Flight.START_THROTTLE
	g_force = 1.0
	hit_t = 0.0
	chase.reset()
	music.play(player_spec.country)

## En el menu el hangar se anima a la frecuencia de dibujo, para que la camara vaya suave.
func _process(delta: float) -> void:
	if menu_open:
		hangar.update(delta)

func _physics_process(delta: float) -> void:
	flash = maxf(flash - delta * 2.0, 0.0)
	hit_t = maxf(hit_t - delta, 0.0)
	world.update()
	sound.update_audio()
	fx.update_debris(delta)
	if leaving and hud.shutter_closed():
		leaving = false
		_open_menu()
	if menu_open:
		if net.is_online() and net.is_authority() and pilots.any_alive():
			ai.update_enemies(delta)   # el anfitrion en el hangar: la batalla sigue para los demas jugadores
			weapons.update_bullets(delta)
		return   # el hangar mueve su camara y su desenfoque en _process
	if over:
		world.blur_mat.set_shader_parameter("strength", 0.0)
		if net.is_online():
			ai.update_enemies(delta)   # en red la batalla sigue aunque tu avion este derribado
		weapons.update_bullets(delta)
		cam.look_at(death_pos, Vector3.UP)
		return
	flight.fly(delta)
	weapons.shoot(delta)
	ai.update_enemies(delta)
	weapons.update_bullets(delta)
	_check_player_collisions()
	flight.update_smoke()
	chase.update_camera(delta)
	weapons.check_lock()

## Velocidad del avion del jugador en el mundo (m/s): sigue la trayectoria, no el morro.
func velocity() -> Vector3:
	return vel_dir * speed

## Dano al jugador: baja la salud y se anota en la zona alcanzada (solo para la silueta del HUD).
func damage_player(n: float, zone: PlaneZones.Zone = PlaneZones.Zone.FUSELAGE) -> void:
	chase.add_trauma(ChaseCam.HIT_TRAUMA)
	zone_damage[zone] = minf(zone_damage[zone] + n / (max_health * ZONE_CAPACITY), 1.0)
	health -= n
	flash = 1.0
	if health <= 0.0:
		_player_die()

func _player_die() -> void:
	if over:
		return
	health = 0.0
	over = true
	upgrades_lost = shop_tiers[Shop.DAMAGE] + shop_tiers[Shop.RATE] + shop_tiers[Shop.HEALTH] > 0
	shop_tiers.fill(0)
	menu.set_shop(credits, shop_tiers)
	death_pos = plane.position
	plane.visible = false
	flight.stop_effects()
	music.stop()
	fx.explode(death_pos, RemotePilots.PLAYER_EXPLOSION_SCALE, velocity())
	pilots.announce_death(death_pos, velocity())

func _check_player_collisions() -> void:
	var p := plane.position
	if world.altitude(p) < Flight.PLAYER_CRASH_Y:
		_player_die()
		return
	for e in ai.enemies:
		if not e.dead and e.root.position.distance_to(p) < Flight.PLAYER_R + AiPlanes.ENEMY_R:
			ai.request_hit(e, 999.0, false)
			damage_player(45.0, zones.zone_of_local(plane.to_local(e.root.position)))

func _input(event: InputEvent) -> void:
	if menu_open:
		return
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and not over \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if chase.orbiting:
			chase.orbit_yaw -= event.relative.x * ChaseCam.ORBIT_SENS
			chase.orbit_pitch = clampf(chase.orbit_pitch - event.relative.y * ChaseCam.ORBIT_SENS, -ChaseCam.ORBIT_PITCH_MAX, ChaseCam.ORBIT_PITCH_MAX)
		else:
			# el punto de mira gira en el marco del avion: derecha del raton = derecha en pantalla
			var pb := plane.transform.basis
			var sens := Flight.AIM_SENS * lerpf(1.0, ChaseCam.ZOOM_FOV_FACTOR, chase.zoom_k)   # con zoom el apuntado es mas fino
			aim_dir = aim_dir.rotated(pb.y, -event.relative.x * sens)
			aim_dir = aim_dir.rotated(pb.x, -event.relative.y * sens).normalized()

func _unhandled_key_input(event: InputEvent) -> void:
	if menu_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: Key = event.keycode
		if k == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_open_pause()
		elif k == KEY_ENTER or k == KEY_KP_ENTER:
			if over:
				_leave_battle()
		elif event.is_action_pressed(Controls.MENU):
			_leave_battle()
		elif event.is_action_pressed(Controls.RELOAD) and not over:
			weapons.start_reload()
