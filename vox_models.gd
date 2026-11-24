## Modelos de voxeles: mallas con oclusion ambiental barata y aviones cargados desde archivos .vox.
class_name VoxModels
extends RefCounted

const VS := 0.25                # tamano del voxel de los aviones (m)
const MODELS_PATH := "res://modelos/aviones.json"  # fichas de los aviones (las genera herramientas/aviones.py)
const VOX_SPECULAR := 0.0          # brillo especular de los modelos de voxeles (0 = mate): sin brillo, solo color
const AO_STRENGTH := 0.13         # oscurecimiento por cada nivel de oclusion de un vertice (0..3 niveles)
## Esquinas de una cara en el orden de sus 4 vertices, en los ejes (u, v) de la cara.
const FACE_CORNERS := [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1)]
const FACES := [
	[Vector3i(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
	[Vector3i(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
	[Vector3i(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)],
	[Vector3i(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	[Vector3i(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
	[Vector3i(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0)],
]

## Reconocimiento de las superficies de mando por la forma del casco (medidas en voxeles de 0.25 m).
const FUSE_HALF := 3            # semianchura del fuselaje: lo que sobresale mas son alas y estabilizador
const WING_SLICE_MIN := 11      # un corte mas ancho que esto es de ala (el estabilizador no llega)
const AILERON_START := 0.55     # el aleron empieza a esta fraccion de la semienvergadura
const AILERON_CHORD := 0.3      # fraccion trasera de la cuerda del ala que ocupa el aleron
const ELEVATOR_CHORD := 0.5     # fraccion trasera del estabilizador que es timon de profundidad
const ELEVATOR_ROOT := 2        # el timon de profundidad no toca el centro: ahi queda el fuselaje
const FIN_HALF := 1             # semianchura de la deriva (la aleta vertical)
const RUDDER_MIN_Y := 3         # altura minima (sobre el eje) de la deriva: por debajo es fuselaje
const RUDDER_CHORD := 0.5       # fraccion trasera de la deriva que es timon de direccion

static var _cards: Dictionary = {}   # fichas de los aviones, leidas una vez
var vox_mat: ShaderMaterial

func _init() -> void:
	vox_mat = ShaderMaterial.new()
	vox_mat.shader = load("res://vox.gdshader")
	vox_mat.set_shader_parameter("specular_amount", VOX_SPECULAR)

## Enciende o apaga la oclusion ambiental de todos los modelos de voxeles (comparten el material).
func set_ao(on: bool) -> void:
	vox_mat.set_shader_parameter("ao_on", on)

## Oclusion ambiental de un vertice de una cara: 0 (muy tapado) a 3 (libre).
## "base" es la celda justo delante de la cara; "su" y "sv" apuntan a la esquina sobre cada eje de la cara.
func _vertex_ao(d: Dictionary, base: Vector3i, su: Vector3i, sv: Vector3i) -> int:
	var side1 := d.has(base + su)
	var side2 := d.has(base + sv)
	if side1 and side2:
		return 0
	return 3 - int(side1) - int(side2) - int(d.has(base + su + sv))

func voxel_mesh(d: Dictionary, vs: float, jitter: float = 0.08) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := vs * 0.5
	for k in d.keys():
		var pos: Vector3i = k
		var col: Color = d[k]
		var hs := absi((pos.x * 73856093) ^ (pos.y * 19349663) ^ (pos.z * 83492791)) % 100
		var j := 1.0 + (float(hs) / 100.0 - 0.5) * 2.0 * jitter
		var c := Color(col.r * j, col.g * j, col.b * j, 1.0)
		for f in FACES:
			var ni: Vector3i = f[0]
			if d.has(pos + ni):
				continue
			var n := Vector3(ni)
			var u: Vector3 = f[1]
			var v: Vector3 = f[2]
			# oclusion ambiental barata: cada vertice se oscurece segun los vecinos que lo rodean
			var ao: Array[int] = []
			var shade: Array[Color] = []
			var shade_k: Array[float] = []   # lo que oscurece la oclusion a cada vertice (1 = nada): vox.gdshader lo usa para quitarla
			for corner_v in FACE_CORNERS:
				var corner: Vector2i = corner_v
				var a := _vertex_ao(d, pos + ni, Vector3i(u) * corner.x, Vector3i(v) * corner.y)
				ao.append(a)
				var m := 1.0 - float(3 - a) * AO_STRENGTH
				shade.append(Color(c.r * m, c.g * m, c.b * m, 1.0))
				shade_k.append(m)
			var c0 := Vector3(pos) * vs
			var p: Array[Vector3] = [
				c0 + (n - u - v) * h, c0 + (n + u - v) * h,
				c0 + (n + u + v) * h, c0 + (n - u + v) * h]
			# la diagonal une el par de esquinas mas claras, asi el degradado no sale en zigzag
			var tris := [0, 2, 1, 0, 3, 2] if ao[0] + ao[2] >= ao[1] + ao[3] else [0, 3, 1, 3, 2, 1]
			for idx in tris:
				st.set_color(shade[idx])
				st.set_uv(Vector2(shade_k[idx], 0.0))
				st.set_normal(n)
				st.add_vertex(p[idx])
	return st.commit()

## Corte de la malla (eje Z del avion, hacia atras) -> semianchura maxima en voxeles.
func _slice_widths(hull: Dictionary) -> Dictionary:
	var width := {}
	for key in hull:
		var p: Vector3i = key
		width[p.z] = maxi(int(width.get(p.z, 0)), absi(p.x))
	return width

## Medidas (en voxeles) de la forma comun de los aviones, o {} si no se reconoce: "span" (semienvergadura),
## "wing_min_z" (primer corte con ala ancha), "wing_front" (borde de ataque del ala), "wing_end" (ultimo corte del ala),
## "tail_start" (primer corte de la cola) y "z_last" (ultimo corte del casco). El ala acaba donde los cortes
## vuelven a ser solo fuselaje; la cola empieza donde vuelven a ensancharse.
func _layout(hull: Dictionary) -> Dictionary:
	var width := _slice_widths(hull)
	var span := 0
	var wing_zs: Array[int] = []
	for key in width:
		var w: int = width[key]
		span = maxi(span, w)
		if w > WING_SLICE_MIN:
			wing_zs.append(key)
	if wing_zs.is_empty():
		return {}
	var wing_end: int = wing_zs.max()
	while int(width.get(wing_end + 1, 0)) > FUSE_HALF:
		wing_end += 1
	var z_last: int = width.keys().max()
	var tail_start := wing_end + 1
	while tail_start <= z_last and int(width.get(tail_start, 0)) <= FUSE_HALF:
		tail_start += 1
	var wing_front := wing_end
	for key in hull:
		var p: Vector3i = key
		if p.z <= wing_end and absi(p.x) > FUSE_HALF:
			wing_front = mini(wing_front, p.z)
	return {"span": span, "wing_min_z": wing_zs.min(), "wing_front": wing_front,
			"wing_end": wing_end, "tail_start": tail_start, "z_last": z_last}

## Separa del casco las superficies de mando buscandolas por la forma comun de los aviones:
## fuselaje estrecho, ala, un tramo solo de fuselaje y la cola. Quita sus voxeles de "hull" y devuelve
## {nombre: {"voxels": {...}, "pivot": Vector3 (voxeles, en el eje de giro)}}; vacio si no reconoce la forma.
## Los nombres son AileronL, AileronR (giran sobre X), Elevator (sobre X) y Rudder (sobre Y).
func _split_surfaces(hull: Dictionary) -> Dictionary:
	var layout := _layout(hull)
	if layout.is_empty():
		return {}
	var span: int = layout["span"]
	var wing_end: int = layout["wing_end"]
	var tail_start: int = layout["tail_start"]
	var z_last: int = layout["z_last"]
	# bordes de las tres superficies: la parte trasera de la cuerda de cada una
	var aileron_x0 := ceili(span * AILERON_START)
	var wing_lo := wing_end
	var wing_hi: int = layout["wing_min_z"]
	var stab_hi := tail_start
	var fin_hi := tail_start
	for key in hull:
		var p: Vector3i = key
		if p.z <= wing_end and absi(p.x) >= aileron_x0:
			wing_lo = mini(wing_lo, p.z)
			wing_hi = maxi(wing_hi, p.z)
		elif p.z >= tail_start and absi(p.x) > FUSE_HALF:
			stab_hi = maxi(stab_hi, p.z)
		elif p.z >= tail_start and absi(p.x) <= FIN_HALF and p.y >= RUDDER_MIN_Y:
			fin_hi = maxi(fin_hi, p.z)
	var aileron_hinge := roundi(wing_hi - AILERON_CHORD * (wing_hi - wing_lo))
	var elevator_hinge := roundi(stab_hi - ELEVATOR_CHORD * (stab_hi - tail_start))
	var rudder_hinge := roundi(fin_hi - RUDDER_CHORD * (fin_hi - tail_start))
	var has_tail := tail_start <= z_last
	var cells := {&"AileronL": [], &"AileronR": [], &"Elevator": [], &"Rudder": []}
	for key in hull:
		var p: Vector3i = key
		if p.z <= wing_end and absi(p.x) >= aileron_x0 and p.z >= aileron_hinge:
			cells[&"AileronL" if p.x < 0 else &"AileronR"].append(p)
		elif has_tail and p.z >= elevator_hinge and absi(p.x) > ELEVATOR_ROOT:
			cells[&"Elevator"].append(p)
		elif has_tail and p.z >= rudder_hinge and absi(p.x) <= FIN_HALF and p.y >= RUDDER_MIN_Y:
			cells[&"Rudder"].append(p)
	var hinges := {&"AileronL": aileron_hinge, &"AileronR": aileron_hinge, &"Elevator": elevator_hinge, &"Rudder": rudder_hinge}
	var parts := {}
	for part_name: StringName in cells:
		var list: Array = cells[part_name]
		if list.is_empty():
			continue
		var voxels := {}
		var sum := Vector3.ZERO
		for p: Vector3i in list:
			voxels[p] = hull[p]
			hull.erase(p)
			sum += Vector3(p)
		var mean := sum / list.size()
		# los alerones giran sobre un eje que pasa por su centro; los timones, sobre el plano central
		var pivot_x := roundf(mean.x) if part_name == &"AileronL" or part_name == &"AileronR" else 0.0
		parts[part_name] = {"voxels": voxels, "pivot": Vector3(pivot_x, roundf(mean.y), hinges[part_name])}
	return parts

## Monta el nodo del avion: Model/(casco + Prop + superficies de mando). La helice gira sobre su Z.
## Cada superficie es un nodo en su bisagra con la malla desplazada de vuelta, asi gira sobre ella.
func _assemble_plane(hull_d: Dictionary, prop_d: Dictionary, prop_pos: Vector3, vs: float, controls: bool) -> Node3D:
	var root := Node3D.new()
	var model := Node3D.new()
	model.name = "Model"
	root.add_child(model)
	var parts := _split_surfaces(hull_d) if controls else {}
	var hull := MeshInstance3D.new()
	hull.mesh = voxel_mesh(hull_d, vs)
	hull.material_override = vox_mat
	model.add_child(hull)
	for part_name: StringName in parts:
		var pivot: Vector3 = parts[part_name]["pivot"]
		var hinge := Node3D.new()
		hinge.name = part_name
		hinge.position = pivot * vs
		var mesh := MeshInstance3D.new()
		mesh.mesh = voxel_mesh(parts[part_name]["voxels"], vs)
		mesh.material_override = vox_mat
		mesh.position = -pivot * vs
		hinge.add_child(mesh)
		model.add_child(hinge)
	var prop := Node3D.new()
	prop.name = "Prop"
	prop.position = prop_pos
	var pm := MeshInstance3D.new()
	pm.mesh = voxel_mesh(prop_d, vs, 0.0)
	pm.material_override = vox_mat
	prop.add_child(pm)
	model.add_child(prop)
	return root

## Ficha de un avion (pivote, eje de la helice, punta del ala y caja de impactos); {} si no existe.
static func info(model: String) -> Dictionary:
	if _cards.is_empty():
		_cards = JSON.parse_string(FileAccess.get_file_as_string(MODELS_PATH))
	assert(_cards.has(model), "Avion sin ficha: " + model)
	return _cards[model]

## Construye un avion desde su .vox (modelo 0 = casco, modelo 1 = helice): pasa de ejes MagicaVoxel
## (morro en +x, z arriba) a los del juego (morro en -Z, Y arriba) con un giro, sin espejar.
## Con "controls" las superficies de mando salen como nodos propios que se pueden animar.
func make_model(model: String, controls: bool = false) -> Node3D:
	var card := info(model)
	var models := _read_vox(card["file"])
	var hub := Vector2i(int(card["prop_hub"][0]), int(card["prop_hub"][1]))
	var hull_d := _hull_voxels(models[0], card)
	var prop_d := {}
	for k in models[1].keys():
		var v: Vector3i = k
		prop_d[Vector3i(hub.x - v.y, v.z - hub.y, 0)] = models[1][k]
	return _assemble_plane(hull_d, prop_d, Vector3(0, 0, float(card["prop_z"]) * VS), VS, controls)

## Voxeles del casco en ejes del juego: X a lo ancho, Y arriba y Z hacia atras desde el pivote.
func _hull_voxels(vox_hull: Dictionary, card: Dictionary) -> Dictionary:
	var pivot_x: int = card["pivot_x"]
	var span_y: int = card["span_y"]
	var axis_z: int = card["axis_z"]
	var hull_d := {}
	for k in vox_hull.keys():
		var v: Vector3i = k
		hull_d[Vector3i(span_y - v.y, v.z - axis_z, pivot_x - v.x)] = vox_hull[k]
	return hull_d

## Zonas de dano de un avion (silueta cenital y zona de cada punto), para el HUD y las armas.
func zones(model: String, box: int = PlaneZones.SILHOUETTE_SIZE) -> PlaneZones:
	var card := info(model)
	var hull_d := _hull_voxels(_read_vox(card["file"])[0], card)
	return PlaneZones.new(hull_d, _layout(hull_d), box)

## Lee un .vox de MagicaVoxel y devuelve un diccionario {Vector3i: Color} por modelo.
func _read_vox(path: String) -> Array[Dictionary]:
	var f := FileAccess.open(path, FileAccess.READ)
	assert(f != null, "No se pudo abrir " + path)
	f.seek(8)  # "VOX " + version
	var raw: Array[Array] = []
	var pal: Array[Color] = []
	while f.get_position() < f.get_length():
		var id := f.get_buffer(4).get_string_from_ascii()
		var n := f.get_32()
		var m := f.get_32()
		if id == "MAIN":
			continue  # solo contenedor: sus hijos van a continuacion
		var end := f.get_position() + n + m
		if id == "XYZI":
			var vox: Array[Vector4i] = []
			for i in f.get_32():
				vox.append(Vector4i(f.get_8(), f.get_8(), f.get_8(), f.get_8()))
			raw.append(vox)
		elif id == "RGBA":
			for i in 256:
				pal.append(Color8(f.get_8(), f.get_8(), f.get_8(), f.get_8()))
		f.seek(end)
	var models: Array[Dictionary] = []
	for vox in raw:
		var d := {}
		for q in vox:
			var e: Vector4i = q
			d[Vector3i(e.x, e.y, e.z)] = pal[e.w - 1]  # indice 1 = pal[0]
		models.append(d)
	return models
