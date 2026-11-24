## Zonas de dano de un avion: morro y motor, fuselaje, ala izquierda, ala derecha y cola.
## Dice a que zona pertenece un punto del avion y guarda su silueta cenital (en pixeles del HUD) con la zona de cada pixel.
class_name PlaneZones
extends RefCounted

enum Zone { NOSE, FUSELAGE, WING_L, WING_R, TAIL }
const COUNT := 5                  # numero de zonas
const SILHOUETTE_SIZE := 32       # lado de la caja de la silueta (px)

var pixels: Array[PackedVector2Array] = []   # por zona, los pixeles de la silueta (x, y) respecto a su esquina
var silhouette_size := Vector2i.ZERO         # tamano real de la silueta (px)
var _box := SILHOUETTE_SIZE                  # lado de la caja de la silueta (px)
var _known := false                          # false si no se reconocio la forma del casco: todo cuenta como fuselaje
var _wing_front := 0                         # primer corte (Z, voxeles) con ala
var _tail_start := 0                         # primer corte (Z, voxeles) de la cola

## "hull" son los voxeles del casco en ejes del juego y "layout" sus medidas (ver VoxModels._layout).
## "box" es el lado de la caja de la silueta: SILHOUETTE_SIZE para el HUD, menos para las mini-siluetas del menu.
func _init(hull: Dictionary, layout: Dictionary, box: int = SILHOUETTE_SIZE) -> void:
	_box = box
	_known = not layout.is_empty()
	if _known:
		_wing_front = layout["wing_front"]
		_tail_start = layout["tail_start"]
	_build_silhouette(hull)

## Zona de un voxel del casco (x a lo ancho, z hacia atras desde el pivote).
func zone_of(x: int, z: int) -> Zone:
	if not _known:
		return Zone.FUSELAGE
	if z >= _tail_start:
		return Zone.TAIL
	if absi(x) > VoxModels.FUSE_HALF:
		return Zone.WING_R if x > 0 else Zone.WING_L
	if z < _wing_front:
		return Zone.NOSE
	return Zone.FUSELAGE

## Zona de un punto en metros, en ejes locales del avion.
func zone_of_local(p: Vector3) -> Zone:
	return zone_of(roundi(p.x / VoxModels.VS), roundi(p.z / VoxModels.VS))

## Proyecta el casco desde arriba (morro hacia arriba) a una caja de _box px y le da a cada pixel
## la zona con mas voxeles. No hay un dibujo aparte: cada avion tiene la silueta de su modelo.
func _build_silhouette(hull: Dictionary) -> void:
	pixels.clear()
	for i in COUNT:
		pixels.append(PackedVector2Array())
	var half := 0
	var z_min := 0
	var z_max := 0
	var first := true
	for key in hull:
		var p: Vector3i = key
		half = maxi(half, absi(p.x))
		z_min = p.z if first else mini(z_min, p.z)
		z_max = p.z if first else maxi(z_max, p.z)
		first = false
	if first:
		return
	var scale := float(_box) / maxf(2.0 * half + 1.0, float(z_max - z_min + 1))
	var votes := {}   # pixel -> votos de cada zona
	for key in hull:
		var p: Vector3i = key
		var cell := Vector2i(floori((p.x + half) * scale), floori((p.z - z_min) * scale))
		if not votes.has(cell):
			votes[cell] = [0, 0, 0, 0, 0]
		votes[cell][zone_of(p.x, p.z)] += 1
	var low := Vector2i(_box, _box)
	var high := Vector2i.ZERO
	for cell: Vector2i in votes:
		low = Vector2i(mini(low.x, cell.x), mini(low.y, cell.y))
		high = Vector2i(maxi(high.x, cell.x), maxi(high.y, cell.y))
	silhouette_size = high - low + Vector2i.ONE
	for cell: Vector2i in votes:
		var counts: Array = votes[cell]
		var best := 0
		for i in COUNT:
			if counts[i] > counts[best]:
				best = i
		pixels[best].append(Vector2(cell - low))
