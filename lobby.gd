## Pantalla previa al hangar: jugar solo, ser anfitrion o unirse a una partida por IP. Tiene la estetica retro-militar
## del hangar: paleta de verde olivo, chapa remachada, fuente pixel y scanlines. Se maqueta a baja resolucion (unos
## 640x360) y se amplia por un factor entero, como el menu del hangar, para que la fuente salga nitida.
class_name Lobby
extends Control

const PLATE_W := 230.0           # ancho de la chapa central (px virtuales)
const PLATE_PAD := 10            # margen interior de la chapa
const GAP := 5                   # separacion entre controles
const TEXT := 8                  # tamano del texto (multiplo de 8: donde la fuente es nitida)
const TEXT_BIG := 16             # tamano del titulo
const NAME_MAX := 16             # largo maximo del nombre de piloto
const DEFAULT_ADDRESS := "127.0.0.1"     # IP que se propone: la de este mismo equipo, para probar con dos ventanas

signal done                      # hay que pasar al hangar

static var notice := ""          # aviso para la proxima vez que se abre (por ejemplo, se perdio la conexion)

## Chapa de panel del hangar que envuelve a los controles; se dimensiona sola segun su contenido.
class Plate extends MarginContainer:
	func _draw() -> void:
		MilitaryStyle.panel(self, Rect2(Vector2.ZERO, size))

## Capa final con las scanlines y el grano del hangar; deja pasar el raton.
class Scanlines extends Control:
	var factor := 1.0
	var closed := 0.0            # cierre de la cortina de transicion (0 = abierta, 1 = cerrada)
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(factor, factor))
		MilitaryStyle.overlay(self, (size / factor).floor())
		HudStyle.shutter(self, (size / factor).floor(), closed, MilitaryStyle.AMBER)

var net: Net
var _font: FontFile
var _stage: Control              # contenedor ampliado por el factor entero: dentro todo va en px virtuales
var _scanlines: Scanlines
var _last_size := Vector2.ZERO
var _k := 0.0                    # cierre actual de la cortina (0 = abierta, 1 = cerrada)
var _goal := 0.0                 # hacia donde va la cortina
var _revealing := false          # true = ya se paso al hangar y la cortina se esta abriendo para descubrirlo
var _name_edit: LineEdit
var _addr_edit: LineEdit
var _status: Label
var _roster: Label
var _port_note: Label            # estado de la apertura del puerto por UPnP
var _go: Button
var _choices: Array[Button] = [] # botones de solo, anfitrion y unirse

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_font = HudStyle.load_font()
	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.theme = MilitaryStyle.menu_theme(_font, TEXT)
	add_child(_stage)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", GAP * 2)
	center.add_child(column)
	column.add_child(_label("COMBATE AEREO", MilitaryStyle.KHAKI_LIGHT, TEXT_BIG, HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(_label("SALA DE CONEXION", MilitaryStyle.AMBER, TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(_build_plate())
	_scanlines = Scanlines.new()
	_scanlines.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_scanlines)

	if not notice.is_empty():
		_say(_status, notice, MilitaryStyle.AMBER)
		notice = ""
	net.roster_changed.connect(_show_roster)
	net.joined.connect(_finish)
	net.join_failed.connect(_on_join_failed)
	net.port_opened.connect(_on_port_opened)

## La chapa con todos los controles: piloto, partida, unirse y los mensajes.
func _build_plate() -> Plate:
	var plate := Plate.new()
	plate.custom_minimum_size = Vector2(PLATE_W, 0.0)
	for side in ["left", "right", "top", "bottom"]:
		plate.add_theme_constant_override("margin_" + side, PLATE_PAD)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", GAP)
	plate.add_child(box)

	box.add_child(_header("PILOTO"))
	_name_edit = LineEdit.new()
	_name_edit.text = "Piloto%d" % (randi() % 1000)
	_name_edit.max_length = NAME_MAX
	box.add_child(_name_edit)

	box.add_child(_header("PARTIDA"))
	_choices.append(_button(box, "JUGAR SOLO", _on_solo))
	_choices.append(_button(box, "SER ANFITRION", _on_host))

	box.add_child(_header("UNIRSE A UNA PARTIDA"))
	box.add_child(_label("IP del anfitrion, o IP:puerto si usa un tunel", Color(MilitaryStyle.KHAKI, MilitaryStyle.DIM)))
	_addr_edit = LineEdit.new()
	_addr_edit.text = DEFAULT_ADDRESS
	box.add_child(_addr_edit)
	_choices.append(_button(box, "UNIRSE", _on_join))

	_roster = _label("", MilitaryStyle.GAUGE_LIGHT)
	box.add_child(_roster)
	_go = _button(box, "CONTINUAR AL HANGAR", _finish)
	_go.visible = false
	_port_note = _label("", Color(MilitaryStyle.KHAKI, MilitaryStyle.DIM))
	_port_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_port_note)
	_status = _label("", MilitaryStyle.KHAKI)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	return plate

func _label(text: String, col: Color, size_px: int = TEXT, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", col)
	return l

func _header(text: String) -> Label:
	return _label(text, MilitaryStyle.KHAKI)

func _button(box: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(action)
	box.add_child(b)
	return b

## Pone un mensaje en una etiqueta con el color de su tipo (ambar = aviso, oxido = error, caqui = informacion).
func _say(l: Label, text: String, col: Color) -> void:
	l.text = text
	l.add_theme_color_override("font_color", col)

## Cierra la cortina de chapa; al cubrir la pantalla se emite "done" (el hangar se abre debajo) y la cortina se abre
## sola para descubrirlo. Despues el lobby se borra.
func _finish() -> void:
	if _goal == 0.0 and not _revealing:
		_goal = 1.0

func _process(delta: float) -> void:
	size = get_viewport_rect().size
	if size != _last_size:
		_last_size = size
		var f := float(HudView.scale_for(size))
		_stage.scale = Vector2(f, f)
		_stage.size = (size / f).floor()
		_scanlines.factor = f
		_scanlines.queue_redraw()
		queue_redraw()
	var before := _k
	_k = move_toward(_k, _goal, delta / Hud.SHUTTER_TIME)
	if _k != before:
		_scanlines.closed = _k
		_scanlines.queue_redraw()
	if _goal == 1.0 and _k >= 1.0:
		_goal = 0.0
		_revealing = true
		_stage.visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE   # el hangar de debajo ya recibe el raton
		queue_redraw()
		done.emit()
	elif _revealing and _k <= 0.0:
		queue_free()

func _draw() -> void:
	if not _revealing:
		draw_rect(Rect2(Vector2.ZERO, size), MilitaryStyle.OLIVE_DARK)

func _pilot_name() -> String:
	var n := _name_edit.text.strip_edges()
	return n if not n.is_empty() else "Piloto"

func _set_choices_enabled(on: bool) -> void:
	for b in _choices:
		b.disabled = not on

func _on_solo() -> void:
	_finish()

func _on_host() -> void:
	var err := net.host(_pilot_name())
	if err != OK:
		_say(_status, "No se pudo abrir el puerto %d (error %d)." % [Net.PORT, err], MilitaryStyle.RUST)
		return
	_set_choices_enabled(false)
	_go.visible = true
	_port_note.text = "Abriendo el puerto en el router (UPnP)..."
	net.open_port()
	_say(_status, "Partida abierta en el puerto %d. Los demas se unen a: %s" % [Net.PORT, ", ".join(_local_ips())], MilitaryStyle.KHAKI)

func _on_join() -> void:
	var err := net.join(_addr_edit.text.strip_edges(), _pilot_name())
	if err != OK:
		_say(_status, "No se pudo iniciar la conexion: revisa la direccion (error %d)." % err, MilitaryStyle.RUST)
		return
	_set_choices_enabled(false)
	_say(_status, "Conectando...", MilitaryStyle.KHAKI)

func _on_port_opened(ok: bool, public_ip: String) -> void:
	if ok:
		_port_note.text = "Puerto abierto por UPnP. Por internet se unen a: %s" % public_ip
	else:
		_port_note.text = "No se pudo abrir el puerto por UPnP: para jugar por internet abrelo a mano en el router (UDP %d) o usa una VPN o un tunel." % Net.PORT

func _on_join_failed() -> void:
	_set_choices_enabled(true)
	_say(_status, "Sin respuesta del anfitrion. Comprueba que ya pulso Ser anfitrion, que la direccion y el puerto son correctos, que el firewall deja pasar el juego y, si usais un tunel, que es UDP y apunta al puerto %d." % Net.PORT, MilitaryStyle.RUST)

func _show_roster() -> void:
	var names := PackedStringArray()
	for id: int in net.roster:
		names.append("- %s" % net.roster[id])
	_roster.text = "PILOTOS CONECTADOS\n" + "\n".join(names) if not names.is_empty() else ""

## Direcciones IPv4 de este equipo en la red local, para decirselas a los demas jugadores.
func _local_ips() -> PackedStringArray:
	var out := PackedStringArray()
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
			out.append(a)
	return out
