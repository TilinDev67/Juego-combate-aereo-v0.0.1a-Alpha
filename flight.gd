## Vuelo del jugador: fisica, control con raton y teclas, estado de dano y humo del avion.
class_name Flight
extends Node

const MS_TO_KMH := 3.6
const MIN_SPEED := 25.0         # m/s (90 km/h): suelo absoluto de velocidad, muy por debajo de la perdida
const MAX_SPEED := 115.0        # m/s (414 km/h): velocidad maxima de referencia (IL-2 y aviones con IA); el jugador usa la de su avion
const STALL_RANGE := 15.0       # m/s por debajo de la perdida hasta la perdida total
const STALL_AUTH_LOSS := 0.8    # fraccion de mando que se pierde en perdida total
const STALL_DROP := 0.9         # rad/s a la que el morro cae en perdida total por velocidad
const AOA_WEATHERVANE := 2.0    # rad/s con los que el aire devuelve el morro a la trayectoria en perdida total por angulo de ataque: sin esto el avion se quedaba deslizando mirando hacia otro lado
const THRUST := 20.0            # m/s^2 de empuje con el acelerador al maximo
const THROTTLE_RATE := 0.4      # cambio del acelerador por segundo al pulsar las teclas de gas
const START_THROTTLE := 0.6     # acelerador inicial (equilibra a unos 89 m/s en vuelo recto)
const GRAVITY_G := 9.81          # m/s^2
const G_SMOOTH := 6.0           # rapidez con que sigue la medida de fuerza G (1/s)
const TRAIL_G_MIN := 4.0        # G a partir de las que salen estelas en las puntas de las alas
const DAMAGE_START := 0.6         # fraccion de salud por debajo de la cual el dano empieza a afectar al vuelo
const ENGINE_LOSS_MAX := 0.6      # fraccion de empuje que se pierde con el motor destrozado (salud 0)
const WING_PULL_MAX := 0.25       # alabeo no ordenado (0..1 de la orden de alabeo) con el ala destrozada
const SMOKE_AMOUNT_MIN := 40      # particulas de humo del motor con el primer dano
const SMOKE_AMOUNT_MAX := 150      # particulas de humo del motor con el dano maximo
const FIRE_DAMAGE := 0.5          # dano (0..1) a partir del cual el motor echa fuego
const WING_SMOKE_DAMAGE := 0.35   # dano (0..1) a partir del cual el ala danada echa humo
const PROP_TORQUE:= 0.1          # alabeo a la izquierda (0..1 de la orden de alabeo) por el par de la helice a todo gas y baja velocidad
const G_BLEED := 2.0           # m/s^2 de velocidad que se pierde por cada G de mas al virar
const START_SPEED_RATIO := 0.74  # velocidad inicial relativa a la maxima de su avion (crucero)
const CORNER_RATIO := 0.78       # velocidad a la que los mandos rinden al 100 %, relativa a la maxima
const PLAYER_R := 4.5
const AIM_SENS := 0.0012        # radianes que gira el punto de mira por pixel de raton
const AIM_MAX := 0.7            # angulo maximo (rad) entre el morro y el punto de mira
const AIM_DRAW_DIST := 1000.0   # distancia a la que el HUD proyecta el cursor del punto de mira (m)
const PITCH_RATE := 1.15
const ROLL_RATE := 2.1
const YAW_RATE := 0.4
const CLIMB_DRAG := 15.0        # m/s^2 de velocidad que se pierde al trepar en vertical (y se gana al picar)
const CORNER_SPEED := 90.0      # igual, para los aviones con IA (m/s)
const AUTH_MIN := 0.55          # autoridad minima de los mandos a baja velocidad
const AUTH_MAX := 1.25          # autoridad maxima a alta velocidad (los aviones con IA; el jugador usa AUTH_FAST)
const AUTH_FAST := 0.7          # autoridad del jugador a velocidad maxima: el aire endurece los mandos desde la velocidad de maniobra
const SLIP_ALIGN := 4.0         # rapidez con que la trayectoria alcanza al morro (1/s): mas bajo = mas derrape al virar
const SLIP_LIFT_MIN := 0.25     # sustentacion minima relativa (a poca velocidad el avion casi no vira la trayectoria)
const SLIP_LIFT_MAX := 1.5      # sustentacion maxima relativa (a mucha velocidad)
const AOA_STALL := 0.45         # angulo de ataque (rad) a partir del cual el ala pierde sustentacion
const AOA_STALL_RANGE := 0.2    # rad por encima del critico hasta la perdida total por angulo de ataque
const AOA_LIFT_LOSS := 0.85     # fraccion de sustentacion que se pierde con la perdida por angulo de ataque total
const KEY_ACCEL := 3.0          # rapidez con que las teclas llegan al giro maximo (1/s): rampa de aceleracion
const KEY_DECEL := 5.0          # rapidez con que el giro de las teclas se apaga al soltarlas (1/s)
const LEVEL_GAIN := 0.4         # fuerza con que el avion nivela las alas cerca del punto de mira (0 = no nivela)
const CMD_INERTIA := 4.5        # rapidez con que el giro sigue a la orden (mas bajo = mas suave)
const PITCH_GAIN := 2.0         # P del cabeceo: orden por unidad de desviacion del cursor
const ROLL_GAIN := 1.5          # P del alabeo: orden por radian de angulo a girar para poner el punto de mira "arriba"
const YAW_GAIN := 3.0           # P de la guinada: orden por unidad de desviacion lateral del punto de mira
const PITCH_KI := 0.3           # I del cabeceo: corrige el morro que cae en perdida o se queda corto
const YAW_KI := 0.3             # I de la guinada
const ROLL_KI := 0.0            # I del alabeo: apagada, solo actua cuando rueda hacia el punto de mira y se desbocaria
const PITCH_KD := 0.12          # D del cabeceo: frena el giro antes de pasarse del punto de mira (mas alto = mas amortiguado)
const YAW_KD := 0.15            # D de la guinada
const ROLL_KD := 0.1            # D del alabeo
const PID_I_LIMIT := 0.3        # tope de la parte integral de cada eje (de una orden maxima de 1)
const PID_I_LEAK := 1.0         # rapidez con que se olvida la integral (1/s): evita arrastrar un error viejo a un objetivo nuevo
const ROLL_ENGAGE := 0.5       # error (rad) a partir del cual se rueda hacia el punto de mira; por debajo, solo guinada y alas niveladas
const SURFACE_MAX := 0.5          # deflexion maxima (rad) de alerones y timones con la orden al maximo
const PLAYER_CRASH_Y := 3.0      # altura (m) a la que el jugador se estrella contra el suelo

var g: Game                   # juego: estado central compartido
var psmoke: CPUParticles3D
var pfire: CPUParticles3D         # fuego del motor con poca salud
var pwing: CPUParticles3D         # humo oscuro del ala danada
var trails: Array[CPUParticles3D] = []  # estelas de las puntas de las alas
var wing_side := 1.0                # lado del ala danada: +1 tira hacia la derecha, -1 hacia la izquierda
var key_rate := Vector3.ZERO       # giro manual suavizado (cabeceo, alabeo, guinada), -1..1
var rate_p := 0.0
var rate_r := 0.0
var rate_y := 0.0
var sway_t := 0.0
var aoa := 0.0                      # angulo de ataque (rad): entre el morro y la trayectoria, del fotograma anterior
var stall_level := 0.0              # perdida actual (0..1), por velocidad o por angulo de ataque: la usan el aviso y la camara
var pitch_pid := Pid.new(PITCH_GAIN, PITCH_KI, PITCH_KD, PID_I_LIMIT, PID_I_LEAK)   # Instructor: un PID por eje
var roll_pid := Pid.new(ROLL_GAIN, ROLL_KI, ROLL_KD, PID_I_LIMIT, PID_I_LEAK)
var yaw_pid := Pid.new(YAW_GAIN, YAW_KI, YAW_KD, PID_I_LIMIT, PID_I_LEAK)
var aileron_l: Node3D             # superficies de mando del modelo (null si no se reconocieron)
var aileron_r: Node3D
var elevator: Node3D
var rudder: Node3D

## Control estilo War Thunder: el raton mueve un punto de mira (aim_dir, fijo en el mundo) y el
## "piloto automatico" hace girar el avion hacia el, con inercia suave.
func fly(delta: float) -> void:
	g.throttle = clampf(g.throttle + Controls.axis(Controls.THROTTLE_DOWN, Controls.THROTTLE_UP) * THROTTLE_RATE * delta, 0.0, 1.0)
	var b := g.plane.transform.basis
	var fwd_old := -b.z
	# velocidad: empuje - resistencia - gravedad al trepar - perdida por virar fuerte
	# dano: por debajo de DAMAGE_START el motor pierde empuje y un ala tira del avion hacia un lado
	var damage := damage_level()
	var max_speed: float = g.player_spec.max_speed
	var corner := max_speed * CORNER_RATIO
	var accel := g.throttle * THRUST * (1.0 - damage * ENGINE_LOSS_MAX) - THRUST / (max_speed * max_speed) * g.speed * g.speed - g.vel_dir.y * CLIMB_DRAG - maxf(g.g_force - 1.0, 0.0) * G_BLEED
	g.speed = clampf(g.speed + accel * delta, MIN_SPEED, max_speed)
	# perdida de sustentacion: sin velocidad, o con demasiado angulo de ataque, los mandos casi no responden y el morro cae
	var speed_stall := clampf((g.player_spec.stall_speed - g.speed) / STALL_RANGE, 0.0, 1.0)
	var aoa_stall := _aoa_stall(aoa)
	var stall := maxf(speed_stall, aoa_stall)
	stall_level = stall
	# mandos: ganan fuerza hasta la velocidad de maniobra y se endurecen por encima de ella
	var auth := clampf(g.speed / corner, AUTH_MIN, 1.0) * lerpf(1.0, AUTH_FAST, smoothstep(corner, max_speed, g.speed)) \
			* (1.0 - stall * STALL_AUTH_LOSS) * g.agility
	# el punto de mira esta fijo en el mundo: el avion gira hacia el y se
	# deja de corregir al alcanzarlo (el raton ya no "empuja" de continuo)
	var fwd := -b.z
	if g.aim_dir.angle_to(fwd) > AIM_MAX:
		g.aim_dir = fwd.slerp(g.aim_dir, AIM_MAX / g.aim_dir.angle_to(fwd))
	var local := b.inverse() * g.aim_dir
	var ang := Vector3(0, 0, -1).angle_to(local)
	# cabeceo: tira hacia el punto de mira cuando esta "arriba" del avion
	var pitch_cmd := pitch_pid.update(local.y, delta)
	# guinada positiva = a la izquierda, asi que se opone a la desviacion lateral
	var yaw_cmd := yaw_pid.update(-local.x, delta)
	# alabeo: rueda hasta poner el punto de mira en el plano de cabeceo; cerca del morro nivela las alas
	var engage := pow(clampf(ang / ROLL_ENGAGE, 0.0, 1.0), 2.0)  # cuadratico: errores pequenos casi no ruedan
	var roll_to_target := clampf(roll_pid.update(atan2(local.x, absf(local.y)), delta), -1.0, 1.0)
	# teclas con rampa: aceleran suavemente al pulsar y frenan al soltar
	var key_cmd := Vector3(
			Controls.axis(Controls.PITCH_DOWN, Controls.PITCH_UP),
			Controls.axis(Controls.ROLL_LEFT, Controls.ROLL_RIGHT),
			Controls.axis(Controls.YAW_RIGHT, Controls.YAW_LEFT))
	for i in 3:
		var ramp := KEY_ACCEL if key_cmd[i] != 0.0 else KEY_DECEL
		key_rate[i] = move_toward(key_rate[i], key_cmd[i], ramp * delta)
	# al rodar con A/D no se nivelan las alas
	var roll_level := clampf(b.x.y * LEVEL_GAIN, -1.0, 1.0) * (1.0 - absf(key_rate.y))
	var roll_cmd := lerpf(roll_level, roll_to_target, engage) + wing_side * damage * WING_PULL_MAX
	# par de la helice: la helice gira a la derecha y el avion tiende a alabear a la izquierda; pesa mas con gas alto y poca velocidad
	roll_cmd -= g.throttle * clampf(1.0 - g.speed / corner, 0.0, 1.0) * PROP_TORQUE
	pitch_cmd = clampf(pitch_cmd, -1.0, 1.0)
	roll_cmd = clampf(roll_cmd, -1.0, 1.0)
	yaw_cmd = clampf(yaw_cmd, -1.0, 1.0)
	# inercia: las velocidades angulares siguen suavemente a la orden
	var k := 1.0 - exp(-delta * CMD_INERTIA)
	rate_p = lerpf(rate_p, pitch_cmd, k)
	rate_r = lerpf(rate_r, roll_cmd, k)
	rate_y = lerpf(rate_y, yaw_cmd, k)
	b = b.rotated(b.x, rate_p * PITCH_RATE * auth * delta)
	b = b.rotated(b.z, -rate_r * ROLL_RATE * auth * delta)
	b = b.rotated(b.y, rate_y * YAW_RATE * auth * delta)
	# teclas: giro manual directo, sumado al del piloto automatico. El punto de mira
	# gira con el avion, asi el automatico no pelea contra las teclas y el raton sigue activo
	var key_turn := Vector3(PITCH_RATE, -ROLL_RATE, YAW_RATE) * key_rate * auth * delta
	for i in 3:
		var axis := b.x if i == 0 else (b.z if i == 1 else b.y)
		b = b.rotated(axis, key_turn[i])
		g.aim_dir = g.aim_dir.rotated(axis, key_turn[i])
	# sin velocidad el morro cae
	var drop_axis := fwd_old.cross(Vector3.DOWN)
	if speed_stall > 0.0 and drop_axis.length() > 0.001:
		b = b.rotated(drop_axis.normalized(), STALL_DROP * speed_stall * delta)
	# veleta: con demasiado angulo de ataque el aire empuja el morro hacia la trayectoria (arriba, abajo o de lado),
	# asi el avion siempre recupera el control en vez de quedarse deslizando mirando hacia otro lado
	var wind_axis := fwd_old.cross(g.vel_dir)
	if aoa_stall > 0.0 and wind_axis.length() > 0.001:
		b = b.rotated(wind_axis.normalized(), minf(aoa, AOA_WEATHERVANE * aoa_stall * delta))
	g.plane.transform.basis = b.orthonormalized()
	# derrape: la trayectoria alcanza al morro con retraso. La sustentacion crece con el cuadrado de la velocidad
	# y se pierde pasado el angulo de ataque critico, y entonces el avion se desliza sin virar
	var nose := -g.plane.transform.basis.z
	var vel_old := g.vel_dir
	aoa = vel_old.angle_to(nose)
	var lift := clampf(pow(g.speed / corner, 2.0), SLIP_LIFT_MIN, SLIP_LIFT_MAX) * (1.0 - _aoa_stall(aoa) * AOA_LIFT_LOSS)
	g.vel_dir = vel_old.slerp(nose, 1.0 - exp(-delta * SLIP_ALIGN * lift)).normalized()
	# fuerza G: aceleracion centripeta del giro de la trayectoria
	var turn_rate := vel_old.angle_to(g.vel_dir) / delta
	g.g_force = lerpf(g.g_force, 1.0 + g.speed * turn_rate / GRAVITY_G, 1.0 - exp(-delta * G_SMOOTH))
	g.plane.position += g.velocity() * delta
	g.plane_prop.rotation.z += (30.0 + g.speed * 0.2) * delta
	# balanceo visual (sway): se inclina con el giro y flota con turbulencia suave
	sway_t += delta
	var m: Node3D = g.plane.get_node("Model")
	m.rotation = Vector3(
		rate_p * 0.03 + sin(sway_t * 1.1) * 0.004,
		-rate_y * 0.04 + sin(sway_t * 0.7 + 2.0) * 0.004,
		-rate_r * 0.07 + sin(sway_t * 0.8 + 1.0) * 0.01)
	m.position = Vector3(sin(sway_t * 0.9) * 0.03, sin(sway_t * 1.3) * 0.02, 0)
	_animate_surfaces()

## Perdida por angulo de ataque (0..1): 0 hasta AOA_STALL y 1 con AOA_STALL_RANGE de mas.
func _aoa_stall(angle: float) -> float:
	return clampf((angle - AOA_STALL) / AOA_STALL_RANGE, 0.0, 1.0)

## Mueve alerones y timones con lo que ordenan el Instructor y las teclas (el giro ya va suavizado).
## Alabeo a la derecha = aleron derecho arriba e izquierdo abajo; morro arriba = timon de profundidad arriba;
## guinada a la izquierda = timon de direccion hacia la derecha. En un nodo girado sobre X, un giro negativo sube el borde de salida.
func _animate_surfaces() -> void:
	var pitch := clampf(rate_p + key_rate.x, -1.0, 1.0)
	var roll := clampf(rate_r + key_rate.y, -1.0, 1.0)
	var yaw := clampf(rate_y + key_rate.z, -1.0, 1.0)
	if aileron_l != null:
		aileron_l.rotation.x = roll * SURFACE_MAX
	if aileron_r != null:
		aileron_r.rotation.x = -roll * SURFACE_MAX
	if elevator != null:
		elevator.rotation.x = -pitch * SURFACE_MAX
	if rudder != null:
		rudder.rotation.y = yaw * SURFACE_MAX

## Dano (0..1) segun la salud: 0 hasta DAMAGE_START y crece hasta 1 con la salud a cero.
func damage_level() -> float:
	return clampf((DAMAGE_START - g.health / g.max_health) / DAMAGE_START, 0.0, 1.0)

func update_smoke() -> void:
	# el humo del motor crece y se oscurece con el dano; el fuego y el humo del ala llegan mas tarde
	var damage := damage_level()
	psmoke.emitting = damage > 0.0
	psmoke.color = Color(0.6, 0.6, 0.6).lerp(Color(0.1, 0.1, 0.1), damage)
	psmoke.amount = int(lerpf(SMOKE_AMOUNT_MIN, SMOKE_AMOUNT_MAX, damage))
	pfire.emitting = damage >= FIRE_DAMAGE
	pwing.emitting = damage >= WING_SMOKE_DAMAGE
	var tip := g.player_spec.wing_tip
	pwing.position = Vector3(tip.x * wing_side, tip.y, tip.z)
	for tr in trails:
		tr.emitting = g.g_force > TRAIL_G_MIN

## Apaga humo, fuego y estelas del avion del jugador.
func stop_effects() -> void:
	psmoke.emitting = false
	pfire.emitting = false
	pwing.emitting = false
	for tr in trails:
		tr.emitting = false

## Crea el humo, el fuego y las estelas del avion del jugador (g.plane debe existir ya).
func setup() -> void:
	aileron_l = g.plane.get_node_or_null("Model/AileronL")
	aileron_r = g.plane.get_node_or_null("Model/AileronR")
	elevator = g.plane.get_node_or_null("Model/Elevator")
	rudder = g.plane.get_node_or_null("Model/Rudder")
	trails.clear()
	psmoke = g.fx.make_smoke(1.2)
	g.plane.add_child(psmoke)
	psmoke.position = Vector3(0, 0.3, 3.5)
	pfire = g.fx.make_fire()
	g.plane.add_child(pfire)
	pfire.position = Vector3(0, 0.4, -1.5)
	pwing = g.fx.make_smoke(0.8)
	pwing.color = Color(0.1, 0.1, 0.1)
	g.plane.add_child(pwing)
	for side in [-1.0, 1.0]:
		var tr := g.fx.make_trail()
		g.plane.add_child(tr)
		tr.position = Vector3(g.player_spec.wing_tip.x * side, g.player_spec.wing_tip.y, g.player_spec.wing_tip.z)
		trails.append(tr)

## Vuelve a las condiciones iniciales: ala danada al azar y sin giro.
func reset() -> void:
	wing_side = 1.0 if randf() < 0.5 else -1.0
	stop_effects()
	key_rate = Vector3.ZERO
	aoa = 0.0
	stall_level = 0.0
	pitch_pid.reset()
	roll_pid.reset()
	yaw_pid.reset()
	rate_p = 0.0
	rate_r = 0.0
	rate_y = 0.0
