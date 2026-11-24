## Controles del juego: acciones del InputMap con sus teclas por defecto.
## El resto del codigo pregunta por acciones, nunca por teclas, asi se pueden reasignar en un solo sitio.
class_name Controls

const PITCH_UP := &"pitch_up"            # morro arriba
const PITCH_DOWN := &"pitch_down"        # morro abajo
const ROLL_LEFT := &"roll_left"
const ROLL_RIGHT := &"roll_right"
const YAW_LEFT := &"yaw_left"
const YAW_RIGHT := &"yaw_right"
const THROTTLE_UP := &"throttle_up"
const THROTTLE_DOWN := &"throttle_down"
const FIRE := &"fire"
const RELOAD := &"reload"
const ZOOM := &"zoom"
const FREE_LOOK := &"free_look"          # mirar alrededor sin cambiar el rumbo
const MENU := &"menu"                    # volver al menu de seleccion de avion

## Teclas por defecto de cada accion: fisicas (no cambian con la distribucion del teclado) o botones del raton.
const DEFAULTS := {
	PITCH_UP: [KEY_S],
	PITCH_DOWN: [KEY_W],
	ROLL_LEFT: [KEY_A],
	ROLL_RIGHT: [KEY_D],
	YAW_LEFT: [KEY_Q],
	YAW_RIGHT: [KEY_E],
	THROTTLE_UP: [KEY_SHIFT],
	THROTTLE_DOWN: [KEY_CTRL],
	FIRE: [KEY_SPACE, MOUSE_BUTTON_LEFT],
	RELOAD: [KEY_R],
	ZOOM: [MOUSE_BUTTON_RIGHT],
	FREE_LOOK: [KEY_C, MOUSE_BUTTON_MIDDLE],
	MENU: [KEY_M],
}

## Registra las acciones que aun no existan. Se llama una vez al arrancar.
static func register() -> void:
	for action: StringName in DEFAULTS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for code: int in DEFAULTS[action]:
			InputMap.action_add_event(action, _event_for(code))

## Evento de entrada de un codigo por defecto: los botones del raton son los de 1 a 9.
static func _event_for(code: int) -> InputEvent:
	if code >= MOUSE_BUTTON_LEFT and code <= MOUSE_BUTTON_XBUTTON2:
		var mb := InputEventMouseButton.new()
		mb.button_index = code as MouseButton
		return mb
	var k := InputEventKey.new()
	k.physical_keycode = code as Key
	return k

## Eje -1..1 entre dos acciones: positivo si solo esta pulsada la segunda.
static func axis(neg: StringName, pos: StringName) -> float:
	return Input.get_action_strength(pos) - Input.get_action_strength(neg)
