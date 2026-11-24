## Buffer de estados recibidos por red de un objeto en movimiento. En vez de saltar al ultimo estado, el objeto se
## dibuja unos milisegundos en el pasado, interpolando entre los dos estados que lo rodean: el movimiento sale
## continuo aunque lleguen pocos paquetes o con retraso desigual. Si falta uno nuevo, se extrapola un poco.
class_name NetInterp
extends RefCounted

const MAX_SAMPLES := 12
const MAX_EXTRAPOLATION := 0.25  # segundos maximos que se adelanta mas alla del ultimo estado

var delay := 0.1                 # segundos en el pasado a los que se dibuja: debe cubrir mas de un intervalo entre paquetes
var _t := PackedFloat64Array()   # instante local de llegada de cada estado
var _pos: Array[Vector3] = []
var _rot: Array[Quaternion] = []
var _vel: Array[Vector3] = []    # velocidad (m/s) de cada estado, para extrapolar

func _init(delay_s: float) -> void:
	delay = delay_s

func is_empty() -> bool:
	return _t.is_empty()

func clear() -> void:
	_t.clear()
	_pos.clear()
	_rot.clear()
	_vel.clear()

## Anota un estado recibido en el instante local "now" (segundos).
func add(now: float, pos: Vector3, rot: Quaternion, vel: Vector3) -> void:
	if not _t.is_empty() and now <= _t[_t.size() - 1]:
		return
	_t.append(now)
	_pos.append(pos)
	_rot.append(rot)
	_vel.append(vel)
	if _t.size() > MAX_SAMPLES:
		_t.remove_at(0)
		_pos.remove_at(0)
		_rot.remove_at(0)
		_vel.remove_at(0)

## Posicion y orientacion del objeto en el instante local "now" (ya con el retraso aplicado). No vale si esta vacio.
func sample(now: float) -> Transform3D:
	var at := now - delay
	var n := _t.size()
	if at >= _t[n - 1]:
		var age := minf(at - _t[n - 1], MAX_EXTRAPOLATION)
		return Transform3D(Basis(_rot[n - 1]), _pos[n - 1] + _vel[n - 1] * age)
	if at <= _t[0]:
		return Transform3D(Basis(_rot[0]), _pos[0])
	var i := 1
	while _t[i] < at:
		i += 1
	var k: float = (at - _t[i - 1]) / (_t[i] - _t[i - 1])
	return Transform3D(Basis(_rot[i - 1].slerp(_rot[i], k)), _pos[i - 1].lerp(_pos[i], k))
