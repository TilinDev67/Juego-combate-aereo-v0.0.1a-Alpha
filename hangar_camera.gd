## Cámara de inspección del hangar: orbita alrededor del avion con muelles, de modo que al cambiar de avion
## hace un barrido rapido al otro lado con un pequeno acercamiento. En reposo se mece despacio y sigue un poco al raton.
class_name HangarCamera
extends RefCounted

const RADIUS := 26.0               # distancia de la camara al avion (m)
const HEIGHT := 5.0                # altura de la camara sobre el avion (m)
const LOOK_DROP := 3.5             # cuanto mas abajo que el avion mira la camara (m): sube el avion en pantalla
const FOV := 40.0                  # campo de vision (grados)
const REST_ANGLE := 0.7            # angulo de reposo respecto al morro (rad); alterna de lado en cada cambio de avion
const SWAY_ANGLE := 0.1            # amplitud del balanceo en reposo (rad)
const SWAY_RATE := 0.12            # balanceos por segundo
const STIFFNESS := 160.0           # rigidez del muelle del angulo (1/s^2): mas alto = barrido mas rapido
const DAMPING := 18.0              # amortiguacion de los muelles (1/s): mas bajo = mas rebote
const SWEEP_KICK := 5.0            # impulso angular (rad/s) al cambiar de avion, en el sentido del barrido
const ZOOM_KICK := 4.0             # acercamiento (m) al cambiar de avion; el muelle lo devuelve
const LAUNCH_DIVE := 12.0          # acercamiento (m) hacia el avion durante la secuencia de salida
const CLACK_FOV := 3.0             # cierre del campo de vision (grados) en el "clack" de enfoque; el muelle lo devuelve
const MOUSE_ANGLE := 0.15          # giro (rad) con el raton en el borde horizontal de la pantalla
const MOUSE_HEIGHT := 2.0          # altura (m) con el raton en el borde vertical de la pantalla
const MOUSE_FOLLOW := 4.0          # rapidez con que la camara sigue al raton (1/s)
const MAX_STEP := 1.0 / 30.0       # paso maximo de tiempo (s): con tirones el muelle se descontrolaria

var _angle := REST_ANGLE
var _angle_vel := 0.0
var _side := 1.0                   # lado del reposo actual: +1 derecha del avion, -1 izquierda
var _zoom := 0.0                   # acercamiento actual (m, negativo = mas cerca)
var _zoom_goal := 0.0              # acercamiento al que tiende el muelle: 0 en reposo, -LAUNCH_DIVE al salir
var _zoom_vel := 0.0
var _fov := 0.0                    # variacion del campo de vision (grados): negativa tras un "clack"
var _fov_vel := 0.0
var _mouse := Vector2.ZERO         # posicion del raton suavizada, -1..1 en cada eje
var _clock := 0.0

## Cambio de avion: pasa al lado contrario con un impulso y un pequeno acercamiento.
func kick() -> void:
	_side = -_side
	_angle_vel += _side * SWEEP_KICK
	_zoom = -ZOOM_KICK

## "Clack" de enfoque: el campo de vision se cierra de golpe y el muelle lo devuelve.
func clack() -> void:
	_fov = -CLACK_FOV

## Salida: la camara se lanza hacia el avion.
func dive() -> void:
	_zoom_goal = -LAUNCH_DIVE

## Coloca la camara en su sitio de reposo sin animacion.
func snap() -> void:
	_angle = REST_ANGLE * _side
	_angle_vel = 0.0
	_zoom = 0.0
	_zoom_goal = 0.0
	_zoom_vel = 0.0
	_fov = 0.0
	_fov_vel = 0.0

## Mueve la camara alrededor de "focus". "mouse" es la posicion del raton normalizada (-1..1 en cada eje).
func update(cam: Camera3D, focus: Vector3, mouse: Vector2, delta: float) -> void:
	delta = minf(delta, MAX_STEP)
	_clock += delta
	_mouse = _mouse.lerp(mouse, 1.0 - exp(-MOUSE_FOLLOW * delta))
	var target := REST_ANGLE * _side + sin(_clock * SWAY_RATE * TAU) * SWAY_ANGLE + _mouse.x * MOUSE_ANGLE
	_angle_vel += ((target - _angle) * STIFFNESS - _angle_vel * DAMPING) * delta
	_angle += _angle_vel * delta
	_zoom_vel += ((_zoom_goal - _zoom) * STIFFNESS - _zoom_vel * DAMPING) * delta
	_zoom += _zoom_vel * delta
	_fov_vel += ((0.0 - _fov) * STIFFNESS - _fov_vel * DAMPING) * delta
	_fov += _fov_vel * delta
	var radius := RADIUS + _zoom
	var height := HEIGHT - _mouse.y * MOUSE_HEIGHT
	cam.position = focus + Vector3(sin(_angle) * radius, height, -cos(_angle) * radius)
	cam.look_at(focus - Vector3(0.0, LOOK_DROP, 0.0), Vector3.UP)
	cam.fov = FOV + _fov
