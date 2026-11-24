## Inercia del HUD central: se desplaza unos pixeles con el giro del avion y las fuerzas G, y vibra con las
## G altas y los impactos, como proyectado en el visor del piloto. El resultado es entero para mantener el pixel-perfect.
class_name HudInertia
extends RefCounted

const FOLLOW := 6.0                  # rapidez con que el HUD alcanza su desplazamiento (1/s): mas bajo = mas elastico
const TURN_SHIFT := Vector2(4.0, 4.0) # px de desplazamiento con el giro (guinada, cabeceo) al maximo: el HUD se queda atras
const G_SHIFT := 2.0                 # px que baja con las G al maximo
const G_FULL := 8.0                  # G a partir de las que el desplazamiento por G es maximo
const JITTER := 1.0                  # px de vibracion maxima
const JITTER_G_START := 5.0          # G a partir de las que empieza a vibrar
const JITTER_G_RANGE := 5.0          # G adicionales hasta la vibracion maxima
const JITTER_FREQ := Vector2(47.0, 53.0) # frecuencias (rad/s) de la vibracion en cada eje

var _offset := Vector2.ZERO          # desplazamiento suavizado
var _clock := 0.0

## Desplazamiento (px enteros) que hay que aplicar al HUD central en este fotograma.
func update(g: Game, delta: float) -> Vector2:
	_clock += delta
	# el HUD se queda atras: si el avion vira a la izquierda la vista se mueve a la derecha y el HUD la sigue
	var turn := Vector2(
			clampf(g.flight.rate_y + g.flight.key_rate.z, -1.0, 1.0),
			clampf(g.flight.rate_p + g.flight.key_rate.x, -1.0, 1.0))
	var target := turn * TURN_SHIFT
	target.y += clampf((g.g_force - 1.0) / G_FULL, 0.0, 1.0) * G_SHIFT
	_offset = _offset.lerp(target, 1.0 - exp(-FOLLOW * delta))
	var shake := maxf(clampf((g.g_force - JITTER_G_START) / JITTER_G_RANGE, 0.0, 1.0), g.chase.trauma)
	var jitter := Vector2(sin(_clock * JITTER_FREQ.x), sin(_clock * JITTER_FREQ.y + 1.0)) * JITTER * shake
	return (_offset + jitter).round()
