## Menu de pausa (Esc): tres pestanas, graficos, sonido y HUD, con interruptores y deslizadores de volumen. Tiene la estetica del hangar y se maqueta
## a baja resolucion, como el lobby. No sabe nada del juego: avisa de cada cambio con "option_changed" (interruptor),
## "volume_changed" (deslizador) y de que hay que seguir con "resumed"; quien lo usa aplica los ajustes y pone o quita la pausa.
class_name PauseMenu
extends Control

enum Option { AO, RAYS, GUNS, ENGINE, MUSIC, HUD_TAPES, HUD_COMPASS, HUD_LADDER, HUD_DOLL, HUD_MARKERS, HUD_INFO, HUD_STATUS }
enum Tab { GRAPHICS, SOUND, HUD }

const PLATE_W := 230.0           # ancho de la chapa central (px virtuales)
const PLATE_PAD := 10            # margen interior de la chapa
const GAP := 5                   # separacion entre controles
const TEXT := 8                  # tamano del texto (multiplo de 8: donde la fuente es nitida)
const TEXT_BIG := 16             # tamano del titulo
const DIM_ALPHA := 0.7           # opacidad del velo que oscurece el juego detras
const SLIDER_STEP := 0.05          # paso de los deslizadores de volumen
const SAVE_PATH := "user://ajustes.cfg"   # donde se guardan las opciones entre partidas
const SAVE_SECTION := "opciones"
const TAB_NAMES := ["GRAFICOS", "SONIDO", "HUD"]
## Texto de cada opcion, y en que pestana va. GUNS, ENGINE y MUSIC son deslizadores de volumen; las demas, interruptores.
const OPTION_LABELS := {
	Option.AO: "OCLUSION AMBIENTAL",
	Option.RAYS: "RAYOS DE SOL",
	Option.GUNS: "SONIDO DE DISPAROS",
	Option.ENGINE: "SONIDO DE MOTOR",
	Option.MUSIC: "MUSICA",
	Option.HUD_TAPES: "CINTAS VELOCIDAD Y ALTITUD",
	Option.HUD_COMPASS: "BRUJULA",
	Option.HUD_LADDER: "HORIZONTE",
	Option.HUD_DOLL: "SILUETA DE DANOS",
	Option.HUD_MARKERS: "MARCADORES DE AVIONES",
	Option.HUD_INFO: "DATOS DE PARTIDA",
	Option.HUD_STATUS: "SALUD Y MUNICION"}
const SLIDER_OPTIONS := [Option.GUNS, Option.ENGINE, Option.MUSIC]
const TAB_OPTIONS := {
	Tab.GRAPHICS: [Option.AO, Option.RAYS],
	Tab.SOUND: [Option.GUNS, Option.ENGINE, Option.MUSIC],
	Tab.HUD: [Option.HUD_TAPES, Option.HUD_COMPASS, Option.HUD_LADDER, Option.HUD_DOLL, Option.HUD_MARKERS, Option.HUD_INFO, Option.HUD_STATUS]}

signal option_changed(option: int, on: bool)
signal volume_changed(option: int, volume: float)
signal resumed

var _font: FontFile
var _stage: Control              # contenedor ampliado por el factor entero: dentro todo va en px virtuales
var _scanlines: Lobby.Scanlines
var _last_size := Vector2.ZERO
var _pages: Array[Control] = []  # una por pestana
var _controls := {}               # control de cada opcion (Option -> Button o HSlider)
var _on := {}                    # estado de cada interruptor (Option -> bool); todos empiezan encendidos

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # sigue vivo con el juego en pausa
	visible = false
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
	column.add_child(_label("PAUSA", MilitaryStyle.KHAKI_LIGHT, TEXT_BIG))
	column.add_child(_build_plate())
	_scanlines = Lobby.Scanlines.new()
	_scanlines.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_scanlines)
	_show_tab(Tab.GRAPHICS)
	_load()

func open() -> void:
	visible = true

func close() -> void:
	visible = false
	_save()
	resumed.emit()

## La chapa con las pestanas, sus interruptores y el boton de continuar.
func _build_plate() -> Lobby.Plate:
	var plate := Lobby.Plate.new()
	plate.custom_minimum_size = Vector2(PLATE_W, 0.0)
	for side in ["left", "right", "top", "bottom"]:
		plate.add_theme_constant_override("margin_" + side, PLATE_PAD)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", GAP)
	plate.add_child(box)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", GAP)
	box.add_child(tabs)
	var group := ButtonGroup.new()
	for t in TAB_NAMES.size():
		var b := Button.new()
		b.text = TAB_NAMES[t]
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = t == Tab.GRAPHICS
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_show_tab.bind(t))
		tabs.add_child(b)
	for t in TAB_NAMES.size():
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", GAP)
		for opt: int in TAB_OPTIONS[t]:
			if opt in SLIDER_OPTIONS:
				page.add_child(_slider(opt))
			else:
				page.add_child(_toggle(opt))
		box.add_child(page)
		_pages.append(page)
	var resume := Button.new()
	resume.text = "CONTINUAR"
	resume.pressed.connect(close)
	box.add_child(resume)
	return plate

## Interruptor de una opcion: encendido = boton hundido y "SI".
func _toggle(opt: int) -> Button:
	_on[opt] = true
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = true
	b.text = _toggle_text(opt)
	_controls[opt] = b
	b.toggled.connect(func(on: bool) -> void:
		_on[opt] = on
		b.text = _toggle_text(opt)
		option_changed.emit(opt, on))
	return b

## Deslizador de volumen de una opcion: etiqueta con el porcentaje encima y la barra debajo.
func _slider(opt: int) -> Control:
	var box := VBoxContainer.new()
	var label := _label("", MilitaryStyle.KHAKI, TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	box.add_child(label)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = SLIDER_STEP
	s.value = 1.0
	s.custom_minimum_size = Vector2(0.0, TEXT + 2.0 * MilitaryStyle.FIELD_PAD.y)
	var refresh := func(v: float) -> void:
		label.text = "%s: %d%%" % [OPTION_LABELS[opt], roundi(v * 100.0)]
	refresh.call(s.value)
	s.value_changed.connect(func(v: float) -> void:
		refresh.call(v)
		volume_changed.emit(opt, v))
	_controls[opt] = s
	box.add_child(s)
	return box

func _toggle_text(opt: int) -> String:
	return "%s: %s" % [OPTION_LABELS[opt], "SI" if _on[opt] else "NO"]

## Lee las opciones guardadas y las pone en los controles; al cambiar su valor, estos avisan y el juego las aplica.
func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for opt: int in _controls:
		var key: String = Option.keys()[opt]
		if not cfg.has_section_key(SAVE_SECTION, key):
			continue
		var c: Control = _controls[opt]
		if c is HSlider:
			c.value = float(cfg.get_value(SAVE_SECTION, key))
		else:
			(c as Button).button_pressed = bool(cfg.get_value(SAVE_SECTION, key))

func _save() -> void:
	var cfg := ConfigFile.new()
	for opt: int in _controls:
		var key: String = Option.keys()[opt]
		var c: Control = _controls[opt]
		if c is HSlider:
			cfg.set_value(SAVE_SECTION, key, (c as HSlider).value)
		else:
			cfg.set_value(SAVE_SECTION, key, (c as Button).button_pressed)
	cfg.save(SAVE_PATH)

## Al cerrar la ventana se guarda tambien, por si se cierra el juego con el menu abierto.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()

func _show_tab(tab: int) -> void:
	for i in _pages.size():
		_pages[i].visible = i == tab

func _label(text: String, col: Color, size_px: int, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", col)
	return l

func _process(_delta: float) -> void:
	size = get_viewport_rect().size
	if size != _last_size:
		_last_size = size
		var f := float(HudView.scale_for(size))
		_stage.scale = Vector2(f, f)
		_stage.size = (size / f).floor()
		_scanlines.factor = f
		_scanlines.queue_redraw()
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(MilitaryStyle.OLIVE_DARK, DIM_ALPHA))

## Esc con el menu abierto: sigue la partida.
func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()
