## Tienda del hangar: tres mejoras individuales (dano, cadencia y salud) de tres niveles cada una, que se compran con
## creditos (+KILL_CREDITS por cada derribo). Las mejoras se pierden al ser derribado y se pueden volver a comprar.
## Aqui solo estan los datos y las cuentas; el estado vive en Game y el dibujo en StartMenu.
class_name Shop

const KILL_CREDITS := 5          # creditos que da cada derribo
const DAMAGE := 0                # indices de las mejoras
const RATE := 1
const HEALTH := 2
const COUNT := 3                 # mejoras distintas
const TIERS := 3                 # niveles de cada una
const NAMES := ["DANO", "CADENCIA", "SALUD"]
## Aumento total de cada nivel (no se suma al del anterior: el nivel 2 pasa a dar +25 %, no +40 %).
const BONUS := [[0.15, 0.25, 0.35], [0.15, 0.25, 0.35], [0.20, 0.35, 0.50]]
## Precio de cada nivel (el del siguiente nivel, al comprar).
const PRICES := [[15, 25, 35], [10, 20, 30], [20, 40, 50]]

## Aumento (0.15 = +15 %) de la mejora "kind" en el nivel "tier"; 0 sin comprar.
static func bonus(kind: int, tier: int) -> float:
	if tier <= 0:
		return 0.0
	var levels: Array = BONUS[kind]
	return levels[mini(tier, TIERS) - 1]

## Multiplicador que se aplica a la estadistica (1.0 sin mejora).
static func multiplier(kind: int, tier: int) -> float:
	return 1.0 + bonus(kind, tier)

## Precio del siguiente nivel de la mejora "kind" teniendo el nivel "tier"; -1 si ya esta al maximo.
static func price(kind: int, tier: int) -> int:
	if tier >= TIERS:
		return -1
	var levels: Array = PRICES[kind]
	return levels[tier]
