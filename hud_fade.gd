## Atenuacion de un dato periferico del HUD: se queda tenue mientras es estable y se ilumina del todo
## cuando cambia bruscamente o esta en zona de peligro, para no cargar de informacion el centro de la pantalla.
class_name HudFade
extends RefCounted

const IDLE_ALPHA := 0.4          # opacidad de un dato estable
const RISE_TIME := 0.15          # segundos que tarda en iluminarse del todo cuando algo cambia o hay peligro
const FALL_TIME := 1.5           # segundos que tarda en volver a atenuarse al quedar estable

var alpha := IDLE_ALPHA
var _last := 0.0
var _has_last := false           # false hasta la primera muestra: sin ella la primera tasa seria un pico

## Opacidad (IDLE_ALPHA..1) tras una muestra: "rate_limit" es la tasa de cambio (unidades por segundo)
## por encima de la cual el dato se ilumina, y "alert" lo fuerza al maximo.
func update(value: float, delta: float, rate_limit: float, alert: bool) -> float:
	var rate := 0.0
	if _has_last and delta > 0.0:
		rate = absf(value - _last) / delta
	_last = value
	_has_last = true
	if alert or rate > rate_limit:
		alpha = minf(alpha + delta / RISE_TIME * (1.0 - IDLE_ALPHA), 1.0)
	else:
		alpha = maxf(alpha - delta / FALL_TIME * (1.0 - IDLE_ALPHA), IDLE_ALPHA)
	return alpha
