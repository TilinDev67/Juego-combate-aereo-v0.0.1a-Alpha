## Camara de persecucion: seguimiento flexible, zoom, orbita, sacudidas y colision con el terreno.
class_name ChaseCam
extends Node

const ZOOM_FOV_FACTOR := 0.3      # campo de vision con el zoom al maximo, relativo al normal (0.5 era x2; 0.3 es x3,3). Tambien afina el apuntado con el raton
const ZOOM_TIME := 0.3            # segundos que tarda el zoom en entrar o salir
const CAM_AIM_BLEND := 0.4       # cuanto mira la camara hacia el punto de mira (0 = al morro, 1 = al punto de mira)
const CAM_FOLLOW := 4.5         # rapidez con que la camara alcanza su direccion objetivo (mas bajo = mas retraso)
const CAM_BASE := Vector3(0, 3.5, 13.0) # posicion de la camara respecto al avion (parado)
const CAM_DIST_FAST := 8.0       # distancia extra detras del avion a velocidad maxima (m)
const CAM_FOV_MIN := 70.0        # campo de vision a velocidad minima (grados)
const CAM_FOV_MAX := 80.0        # campo de vision a velocidad maxima: da sensacion de velocidad
const CAM_FOV_RATE := 2.0        # rapidez con que el campo de vision sigue a la velocidad (1/s)
const CAM_SWING := Vector3(2.5, 1.5, 0.0) # desplazamiento (m) de la camara por unidad de giro: se queda atras al virar y cabecear
const CAM_SPRING := 4.0          # rigidez del muelle de la camara (mas bajo = mas flexible)
const CAM_ROLL := 0.06           # fraccion del alabeo del avion que copia la camara
const CAM_LOOK_AHEAD := Vector2(0.1, 0.06) # giro de la camara hacia donde se vira (rad por unidad de giro): guinada, cabeceo
const CAM_LOOK_SPRING := 3.0      # rapidez con que la camara adelanta la mirada (mas bajo = mas retraso)
const CAM_MIN_Y := 3.0            # altura minima de la camara sobre el suelo (m)
const CAM_LIFT_UP := 14.0         # rapidez con que la camara sube para no atravesar suelo o copas (1/s)
const CAM_LIFT_DOWN := 4.0        # rapidez con que vuelve a bajar al despejarse (1/s)
const TRAUMA_DECAY := 1.2         # rapidez con que se calma una sacudida de camara (1/s)
const CAM_TRAUMA_POS := 0.6       # desplazamiento maximo de la camara con la sacudida al maximo (m)
const CAM_TRAUMA_ROT := 0.05      # giro maximo (rad) de la camara con la sacudida al maximo
const SHOOT_TRAUMA := 0.05        # sacudida por cada descarga de los canones
const HIT_TRAUMA := 0.35          # sacudida por cada impacto recibido
const EXPLOSION_SHAKE_RANGE := 800.0 # distancia (m) a la que una explosion deja de sacudir la camara
const STALL_BUFFET_MARGIN := 8.0  # m/s sobre la perdida a los que empieza a vibrar el avion
const AOA_BUFFET_MARGIN := 0.1    # rad por debajo del angulo de ataque critico a los que empieza a vibrar (aviso de perdida)
const STALL_BUFFET_MAX := 0.4    # sacudida continua maxima en perdida total
const G_SHAKE_START := 5.0        # G a partir de las que vibra la camara
const G_SHAKE_RANGE := 5.0        # G adicionales hasta la vibracion maxima
const G_SHAKE_MAX := 0.3          # vibracion maxima por G
const CAM_SHAKE := 0.02          # vibracion (m) de la camara a velocidad maxima
const ORBIT_SENS := 0.005       # radianes de orbita por pixel de raton
const ORBIT_RETURN := 5.0       # rapidez con que la camara orbital vuelve detras del avion
const ORBIT_PITCH_MAX := 1.3    # limite de la orbita arriba/abajo (rad)

var g: Game                   # juego: estado central compartido
var cam_fov := CAM_FOV_MIN         # campo de vision segun la velocidad, sin zoom
var zoom_t := 0.0                  # avance lineal del zoom (0 = fuera, 1 = dentro)
var zoom_k := 0.0                  # zoom suavizado (curva de entrada y salida)
var cam_q := Quaternion.IDENTITY   # orientacion suavizada de la camara
var cam_look := Vector2.ZERO           # giro actual de la camara hacia el viraje (guinada, cabeceo)
var cam_lift := 0.0                  # altura extra de la camara para no atravesar el suelo (m)
var trauma := 0.0                  # sacudida de camara por eventos (0..1), se calma sola
var cam_swing := Vector3.ZERO       # desplazamiento flexible de la camara respecto a su posicion base
var orbit_yaw := 0.0             # orbita de la camara respecto al avion (rad)
var orbit_pitch := 0.0
var orbiting := false            # mirada libre mantenida: el raton orbita la camara en vez de apuntar

## La camara mira entre el morro y el punto de mira (como el raton en War Thunder), con el alabeo
## del avion: se ve girar el avion hacia el centro mientras se pilota, sin descentrarlo mucho.
func target_cam_q() -> Quaternion:
	var look := (-g.plane.transform.basis.z).slerp(g.aim_dir, CAM_AIM_BLEND)
	return Quaternion(Basis.looking_at(look, g.plane.transform.basis.y))

## Suma sacudida a la camara (se limita a 1).
func add_trauma(amount: float) -> void:
	trauma = minf(trauma + amount, 1.0)

## Camara que sigue el punto de mira con retraso suave, y mirada libre.
## Al soltar, la orbita vuelve sola detras del avion.
func update_camera(delta: float) -> void:
	orbiting = Input.is_action_pressed(Controls.FREE_LOOK) and not g.over
	# zoom: avanza linealmente y se suaviza con una curva (entra y sale con calma)
	var zoom_target := 1.0 if Input.is_action_pressed(Controls.ZOOM) and not g.over else 0.0
	zoom_t = move_toward(zoom_t, zoom_target, delta / ZOOM_TIME)
	zoom_k = smoothstep(0.0, 1.0, zoom_t)
	if not orbiting:
		var back := 1.0 - exp(-delta * ORBIT_RETURN)
		orbit_yaw = lerpf(wrapf(orbit_yaw, -PI, PI), 0.0, back)
		orbit_pitch = lerpf(orbit_pitch, 0.0, back)
	var prev_cam := g.cam.global_transform
	cam_q = cam_q.slerp(target_cam_q(), 1.0 - exp(-delta * CAM_FOLLOW))
	var cb := Basis(cam_q) * Basis(Vector3.UP, orbit_yaw) * Basis(Vector3.RIGHT, orbit_pitch)
	# velocidad: mas campo de vision y mas distancia cuanto mas rapido va
	var speed_t := inverse_lerp(Flight.MIN_SPEED, g.player_spec.max_speed, g.speed)
	cam_fov = lerpf(cam_fov, lerpf(CAM_FOV_MIN, CAM_FOV_MAX, speed_t), 1.0 - exp(-delta * CAM_FOV_RATE))
	g.cam.fov = cam_fov * lerpf(1.0, ZOOM_FOV_FACTOR, zoom_k)
	# flexibilidad: un muelle desplaza la camara al girar (virar a la izquierda la manda a la derecha,
	# cabecear arriba la baja)
	var turn := Vector3(g.flight.rate_p + g.flight.key_rate.x, g.flight.rate_r + g.flight.key_rate.y, g.flight.rate_y + g.flight.key_rate.z)
	var swing_target := Vector3(turn.z * CAM_SWING.x, -turn.x * CAM_SWING.y, 0.0)
	cam_swing = cam_swing.lerp(swing_target, 1.0 - exp(-delta * CAM_SPRING))
	var offset := CAM_BASE + cam_swing + Vector3(0, 0, CAM_DIST_FAST * speed_t)
	# vibracion suave que crece con la velocidad
	var shake := Vector3(sin(g.flight.sway_t * 37.0), sin(g.flight.sway_t * 43.0 + 1.0), 0.0) * CAM_SHAKE * speed_t
	# sacudida de eventos (disparos, impactos, explosiones) mas la continua de perdida y de G altas;
	# crece con el cuadrado para que lo leve apenas se note y lo fuerte golpee
	trauma = maxf(trauma - TRAUMA_DECAY * delta, 0.0)
	var speed_buffet := clampf((g.player_spec.stall_speed + STALL_BUFFET_MARGIN - g.speed) / STALL_BUFFET_MARGIN, 0.0, 1.0) * STALL_BUFFET_MAX
	var aoa_buffet := clampf((g.flight.aoa - (Flight.AOA_STALL - AOA_BUFFET_MARGIN)) / AOA_BUFFET_MARGIN, 0.0, 1.0) * STALL_BUFFET_MAX
	var buffet := maxf(speed_buffet, aoa_buffet)
	var g_shake := clampf((g.g_force - G_SHAKE_START) / G_SHAKE_RANGE, 0.0, 1.0) * G_SHAKE_MAX
	var rumble := maxf(trauma, maxf(buffet, g_shake))
	rumble *= rumble
	shake += Vector3(sin(g.flight.sway_t * 47.0), sin(g.flight.sway_t * 53.0 + 1.0), sin(g.flight.sway_t * 41.0 + 2.0)) * CAM_TRAUMA_POS * rumble
	# mirada adelantada: la camara gira un poco hacia donde vira el avion, sin mover su posicion
	var look_target := Vector2(turn.z * CAM_LOOK_AHEAD.x, turn.x * CAM_LOOK_AHEAD.y)
	cam_look = cam_look.lerp(look_target, 1.0 - exp(-delta * CAM_LOOK_SPRING))
	var look := Basis(Vector3.UP, cam_look.x) * Basis(Vector3.RIGHT, cam_look.y)
	g.cam.position = g.plane.position + cb * (offset + shake)
	# colision de camara: no atraviesa el suelo; sube rapido y baja despacio
	var lift_need := maxf(CAM_MIN_Y - g.world.altitude(g.cam.position), 0.0)
	cam_lift = lerpf(cam_lift, lift_need, 1.0 - exp(-delta * (CAM_LIFT_UP if lift_need > cam_lift else CAM_LIFT_DOWN)))
	g.cam.position.y += cam_lift
	g.cam.basis = cb * look * Basis(Vector3.RIGHT, -0.09) * Basis(Vector3.BACK, -turn.y * CAM_ROLL + sin(g.flight.sway_t * 29.0 + 0.5) * CAM_TRAUMA_ROT * rumble)
	# el desenfoque usa lo que se movio la camara en este paso (sin movimiento si es la primera vez)
	g.world.blur_mat.set_shader_parameter("prev_view", Projection((prev_cam if delta > 0.0 else g.cam.global_transform).affine_inverse()))
	g.world.blur_mat.set_shader_parameter("strength", World.MOTION_BLUR)
	g.world.blur_mat.set_shader_parameter("clear_dist", g.cam.position.distance_to(g.plane.position) + World.PLANE_BLUR_MARGIN)

## Deja la camara detras del avion, sin sacudida, zoom ni orbita.
func reset() -> void:
	zoom_t = 0.0
	trauma = 0.0
	cam_lift = 0.0
	cam_look = Vector2.ZERO
	orbit_yaw = 0.0
	orbit_pitch = 0.0
	cam_swing = Vector3.ZERO
	cam_q = target_cam_q()
	update_camera(0.0)
