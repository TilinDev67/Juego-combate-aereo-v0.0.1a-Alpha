## Controlador PID de un eje del Instructor Virtual: convierte el error de apuntado en una orden de mando.
## P empuja hacia el objetivo, D frena el giro antes de pasarse y I corrige el error que se queda (p. ej. el morro
## que cae en perdida). La integral tiene fuga y no se acumula con la orden saturada, para que no se desboque.
class_name Pid
extends RefCounted

var kp: float                 # ganancia proporcional: orden por unidad de error
var ki: float                 # ganancia integral: 0 la desactiva
var kd: float                 # ganancia derivativa: amortigua el giro
var i_limit: float            # tope de la parte integral (en unidades de orden, 0..1)
var i_leak: float             # rapidez con que se olvida la integral acumulada (1/s)
var _integral := 0.0
var _last_error := 0.0
var _has_last := false        # false hasta la primera muestra: sin ella la derivada daria un pico

func _init(p: float, i: float, d: float, limit: float, leak: float) -> void:
	kp = p
	ki = i
	kd = d
	i_limit = limit
	i_leak = leak

## Orden sin limitar para un error y un paso de tiempo; el llamante la recorta a -1..1.
func update(error: float, delta: float) -> float:
	var deriv := 0.0
	if _has_last and delta > 0.0:
		deriv = (error - _last_error) / delta
	_last_error = error
	_has_last = true
	var out := kp * error + kd * deriv + _integral
	# solo integra si la orden no esta ya saturada empujando en el mismo sentido que el error
	var saturated := absf(out) >= 1.0 and signf(out) == signf(error)
	_integral *= exp(-i_leak * delta)
	if not saturated:
		_integral = clampf(_integral + ki * error * delta, -i_limit, i_limit)
	return out

## Olvida lo acumulado (al empezar de nuevo o al cambiar de avion).
func reset() -> void:
	_integral = 0.0
	_last_error = 0.0
	_has_last = false
