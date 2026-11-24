## Banco de variantes de un efecto de sonido: varias muestras generadas con parametros algo distintos, que se
## reproducen al azar y con un tono y una ganancia ligeramente distintos cada vez, para que una rafaga o una
## serie de impactos no suene como la misma muestra repetida.
class_name SfxBank
extends RefCounted

var variants: Array[AudioStreamWAV] = []
var pitch_variation: float       # fraccion de tono al azar al reproducir (0.05 = mas o menos un 5 %)
var gain_variation_db: float     # variacion de volumen al azar al reproducir (dB, mas o menos)
var _last := -1                  # variante usada la ultima vez, para no repetirla seguida

## "recipe" es una funcion estatica de SfxRecipes: recibe un generador de numeros aleatorios y el numero de
## variante, y devuelve la muestra. "seed" hace que las variantes salgan siempre iguales en cada arranque.
func _init(count: int, recipe: Callable, pitch_var: float, gain_var_db: float, seed: int) -> void:
	pitch_variation = pitch_var
	gain_variation_db = gain_var_db
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in count:
		variants.append(recipe.call(rng, i))

## Una variante al azar, distinta de la anterior si hay mas de una.
func pick() -> AudioStreamWAV:
	var i := randi() % variants.size()
	if variants.size() > 1 and i == _last:
		i = (i + 1 + randi() % (variants.size() - 1)) % variants.size()
	_last = i
	return variants[i]

## Tono al azar para esta reproduccion (1 = el original).
func pitch_scale() -> float:
	return 1.0 + randf_range(-pitch_variation, pitch_variation)

## Ganancia al azar para esta reproduccion (dB).
func gain_db() -> float:
	return randf_range(-gain_variation_db, gain_variation_db)
