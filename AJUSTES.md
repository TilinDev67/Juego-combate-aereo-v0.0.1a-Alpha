# Guía de ajuste del vuelo

Todo son constantes al principio de cada archivo (`const`). Cambia **una cada vez** y prueba. Entre paréntesis, el valor inicial.

## Qué toco si el avión se siente…

| Síntoma | Causa probable | Qué tocar | Hacia dónde |
|---|---|---|---|
| **Muy pesado** (tarda en girar, perezoso) | Poca autoridad o mucha inercia | `flight.gd`: `CMD_INERTIA` (4,5) | subir |
| | | `PITCH_RATE` (1,15), `ROLL_RATE` (2,1), `YAW_RATE` (0,4) | subir |
| | | `PITCH_GAIN` (2,0), `ROLL_GAIN` (1,5), `YAW_GAIN` (3,0) | subir |
| | Mandos duros a mucha velocidad | `AUTH_FAST` (0,7) | subir hacia 1,0 |
| | Trayectoria que tarda en seguir al morro | `SLIP_ALIGN` (4,0) | subir |
| **Muy nervioso / tembloroso** (oscila alrededor del punto de mira) | Poca amortiguación | `PITCH_KD` (0,12), `YAW_KD` (0,15), `ROLL_KD` (0,1) | subir |
| | Ganancias P demasiado altas | `PITCH_GAIN`, `YAW_GAIN`, `ROLL_GAIN` | bajar |
| | Integral que empuja de más | `PITCH_KI`, `YAW_KI` (0,3) y `PID_I_LIMIT` (0,3) | bajar |
| | Ratón demasiado sensible | `AIM_SENS` (0,0012) | bajar |
| **Como un OVNI sin gravedad** (gira en seco, sin peso) | Trayectoria pegada al morro y poca pérdida de energía | `SLIP_ALIGN` (4,0) | bajar (más derrape) |
| | | `CLIMB_DRAG` (15,0), `G_BLEED` (2,0) | subir (trepar y virar cuestan velocidad) |
| | | `CMD_INERTIA` | bajar (más inercia) |
| | Pérdida demasiado suave | `STALL_DROP` (0,9), `STALL_AUTH_LOSS` (0,8) | subir |
| **Se desliza demasiado** (el morro apunta y el avión no vira) | Mucho derrape o pérdida por ángulo de ataque | `SLIP_ALIGN` | subir |
| | | `AOA_STALL` (0,45) | subir |
| **Entra en pérdida sin querer** | Ángulo de ataque crítico bajo | `AOA_STALL`, `AOA_STALL_RANGE` (0,2), `AOA_LIFT_LOSS` (0,85) | subir los dos primeros, bajar el tercero |
| | Velocidad de pérdida alta | `stall_speed` del avión en `plane_models.gd` | bajar |
| **El aviso de pérdida sale tarde o pronto** | | `chase_cam.gd`: `AOA_BUFFET_MARGIN` (0,1); `hud.gd`: `STALL_WARN` (0,2) | subir = avisa antes |
| **Pierde velocidad al virar** | Demasiado castigo | `G_BLEED` | bajar |
| **Frena o acelera demasiado al trepar y picar** | | `CLIMB_DRAG` (15,0) | ajustar |
| **No llega a su velocidad máxima / tarda en acelerar** | | `THRUST` (20,0) | subir |
| **El Instructor no nivela las alas** | | `LEVEL_GAIN` (0,4) | subir |
| **Rueda demasiado hacia el punto de mira** | | `ROLL_ENGAGE` (0,5) | subir (rueda menos) |

## Cámara

Archivo `chase_cam.gd`.

| Síntoma | Qué tocar |
|---|---|
| Cámara demasiado pegada / rígida | `CAM_FOLLOW` (4,5) y `CAM_SPRING` (4,0): bajar |
| Cámara con demasiado retraso | `CAM_FOLLOW`, `CAM_SPRING`: subir |
| Poca sensación de velocidad | `CAM_FOV_MAX` (80) subir, `CAM_DIST_FAST` (8,0) subir |
| Demasiado efecto de velocidad | `CAM_FOV_MAX`, `CAM_DIST_FAST`: bajar |
| Vibración por G excesiva | `G_SHAKE_MAX` (0,3) bajar; `G_SHAKE_START` (5,0) subir |
| El avión se descentra mucho al virar | `CAM_SWING` (2,5 / 1,5) y `CAM_LOOK_AHEAD`: bajar |
| Mirada libre muy rápida o lenta | `ORBIT_SENS` (0,005) |

## Mira y HUD

| Síntoma | Qué tocar |
|---|---|
| El rombo de adelanto aparece muy lejos o muy tarde | `weapons.gd`: `LEAD_RANGE` (1200), `LEAD_CONE` (0,3) |
| El blanco se «fija» (rojo) con demasiada o poca precisión | `weapons.gd`: `LOCK_CONE` (0,05) |
| La línea elástica se ve demasiado o se apaga tarde | `aircraft_reticle.gd`: `TETHER_FADE` (12 / 48 px), `TETHER_STEP` (3) |
| El arco de munición estorba | `aircraft_reticle.gd`: `AMMO_ARC_R` (12), `TRACK_ALPHA` (0,3) |
| Las cintas estorban o están muy lejos del centro | `flight_tapes.gd`: `OFFSET_X` (150), `HALF_H` (50) |
| Los datos están demasiado apagados o brillantes | `hud_fade.gd`: `IDLE_ALPHA` (0,4), `FALL_TIME` (1,5) |
| Los datos se iluminan por cualquier cosa | `flight_tapes.gd`: `SPEED_ACTIVE_RATE`, `ALT_ACTIVE_RATE`; `compass_tape.gd`: `HEADING_ACTIVE_RATE`; `pitch_ladder.gd`: `ACTIVE_RATE` |
| El radar altímetro avisa tarde o pronto | `flight_tapes.gd`: `RADAR_MAX` (150), `RADAR_DANGER` (40) |
| La velocidad pasa a ámbar o rojo mal | `flight_tapes.gd`: `SPEED_CAUTION_MARGIN`, `OVERSPEED_CAUTION`, `OVERSPEED_ALERT` |
| La escalera de cabeceo se mueve demasiado o poco | `pitch_ladder.gd`: `PX_PER_RAD` (90), `MAX_OFFSET` (70) |
| Las flechas fuera de pantalla quedan muy cerca o muy lejos del centro | `offscreen_indicator.gd`: `ORBIT_FRAC` (0,36) |
| Las flechas son demasiado pequeñas o grandes | `offscreen_indicator.gd`: `ARROW_NEAR` (8), `ARROW_FAR` (3), `FAR_RANGE` (2000) |
| El HUD se mueve demasiado o muy poco al virar | `hud_inertia.gd`: `TURN_SHIFT` (4 px), `G_SHIFT` (2 px) |
| El HUD tarda en seguir o es muy brusco | `hud_inertia.gd`: `FOLLOW` (6) |
| La vibración del HUD con G o impactos es mucha | `hud_inertia.gd`: `JITTER` (1 px), `JITTER_G_START` (5) |
| Las barras saltan o tardan en moverse | `hud.gd`: `BAR_SMOOTH` (8) |
| El parpadeo al recibir impactos dura mucho o poco | `hud.gd`: `HIT_BLINK_TIME` (0,25), `BLINK_FRAMES` (2) |
| Las zonas de la silueta se destruyen muy pronto o muy tarde | `main.gd`: `ZONE_CAPACITY` (0,6 de la salud máxima) |
| Los colores de la silueta cambian a destiempo | `damage_doll.gd`: `GREEN_BELOW` (0,34), `AMBER_BELOW` (0,67) |
| Una zona no coincide con la parte del avión (p. ej. el morro es muy corto) | `vox_models.gd`: `FUSE_HALF` (3), `WING_SLICE_MIN` (11) |
| El cursor del ratón queda desplazado respecto al punto de mira | `flight.gd`: `AIM_DRAW_DIST` (1000 m) |

## Hangar (menú)

| Síntoma | Qué tocar |
|---|---|
| El avión se ve muy pequeño o grande en pantalla | `hangar_camera.gd`: `RADIUS` (26), `FOV` (40) |
| El avión queda muy alto o bajo en pantalla | `hangar_camera.gd`: `LOOK_DROP` (3,5) |
| El barrido al cambiar de avión es lento o rebota mucho | `hangar_camera.gd`: `STIFFNESS` (160) más alto = más rápido; `DAMPING` (18) más bajo = más rebote |
| El barrido es poco vistoso | `hangar_camera.gd`: `SWEEP_KICK` (5), `ZOOM_KICK` (4) |
| La cámara se mece o sigue al ratón demasiado | `hangar_camera.gd`: `SWAY_ANGLE` (0,1), `MOUSE_ANGLE` (0,15) |
| El hangar está muy oscuro o claro | `world.gd`: `HANGAR_SUN_ENERGY` (0,9), `HANGAR_AMBIENT_ENERGY` (0,55) |
| Las sombras son muy cortas o largas | `world.gd`: `HANGAR_SUN_ROTATION` (-16°: más cerca de 0 = más rasante) |
| Los focos iluminan poco o mucho | `hangar_scene.gd`: `KEY_ENERGY` (9), `FILL_ENERGY` (4) |
| Hay demasiado o muy poco polvo | `hangar_scene.gd`: `DUST_AMOUNT` (90), `DUST_ALPHA` (0,35) |
| El hormigón se ve muy liso o muy sucio | `hangar_scene.gd`: `CONCRETE_NOISE` (0,045), `CONCRETE_STAINS` (6), `CONCRETE_CRACKS` (5), `CONCRETE_TILING` (0,12) |
| La pintura de pista está muy entera o muy gastada | `hangar_scene.gd`: `PAINT_GAP` (0,2 a 1,4 m), `CENTER_WEAR` (0,2) |
| La hélice o la prueba de mandos van rápido o lentos | `hangar_scene.gd`: `PROP_SPIN` (24), `TEST_PHASE` (1,4) |

Selector y materialización (`start_menu.gd`, `hangar_scene.gd`):

| Síntoma | Qué tocar |
|---|---|
| Los corchetes se cierran lento o lejos | `start_menu.gd`: `LOCK_TIME` (0,18), `LOCK_GROW` (10), `PLANE_LOCK_GROW` (24) |
| Las marcas de grado de los corchetes estorban | `military_style.gd`: `TICK_SPACING` (6), `TICK_LEN` (2) |
| El parpadeo al fijar es muy largo o corto | `start_menu.gd`: `LOCK_BLINK_TIME` (0,12), `LOCK_BLINK_FRAMES` (2) |
| El pulso, el retroceso o la luz piloto de la fila se ven poco | `start_menu.gd`: `PULSE_TIME` (0,25), `NUDGE_PX` (2), `PILOT_RATE` (1) |
| La línea guía molesta | `start_menu.gd`: `GUIDE_ALPHA` (0,5), `GUIDE_STEP` (3) |
| La entrada del avión (persiana) es lenta o a saltos muy grandes | `hangar_scene.gd`: `SCAN_TIME` (0,3), `SCAN_STEP` (0,25), `SCAN_SLATS` (6) |
| La bocanada de humo se ve poco | `hangar_scene.gd`: `PUFF_AMOUNT` (28), `PUFF_SIZE` (0,35), `PUFF_COLOR_START` |
| El «clack» de la cámara no se nota | `hangar_camera.gd`: `CLACK_FOV` (3) |
| El barrido empieza o acaba fuera del avión | `hangar_scene.gd`: `SCAN_BOTTOM` (-1,5), `SCAN_TOP` (4,5) |

Telemetría del menú (`start_menu.gd`):

| Síntoma | Qué tocar |
|---|---|
| El barrido de las barras es lento | `SWEEP_RATE` (40 segmentos/s) |
| Las cifras tardan en llegar a su valor | `BAR_FOLLOW` (14): más alto = más rápido |
| Las barras se llenan muy seguidas o muy separadas al abrir | `OPEN_STAGGER` (0,06) |
| El indicador `+`/`-` dura mucho o poco | `DELTA_TIME` (1,2), `DELTA_FADE` (0,4) |
| El indicador tapa el valor | `DELTA_X` (74) |
| El destello del valor se nota poco | `FLASH_TIME` (0,3) |

Botón y salida (`start_menu.gd`, `hangar_scene.gd`, `hangar_camera.gd`, `hud_style.gd`):

| Síntoma | Qué tocar |
|---|---|
| La salida es larga o corta | `start_menu.gd`: `LAUNCH_TIME` (0,4), `LAUNCH_SHUTTER_DELAY` (0,1) |
| La persiana se ve muy brusca o muy lenta | `hud_style.gd`: `SHUTTER_STAGGER` (0,35), `SHUTTER_SLATS` (12); `hud.gd`: `SHUTTER_OPEN_TIME` (0,3) |
| La cámara se lanza poco o demasiado | `hangar_camera.gd`: `LAUNCH_DIVE` (12) |
| La hélice no se revoluciona lo bastante | `hangar_scene.gd`: `LAUNCH_SPIN` (90), `SPIN_FOLLOW` (8) |
| Los corchetes del botón tardan o se ven poco | `start_menu.gd`: `HOVER_TIME` (0,15), `BUTTON_GROW` (8), `HOVER_OFFSET` (1) |
| El hundimiento del botón se nota poco | `start_menu.gd`: `PRESS_RECOIL` (2), `PRESS_TIME` (0,1) |

## Superficies de mando

- `SURFACE_MAX` (0,5 rad) en `flight.gd`: cuánto se mueven alerones y timones.
- Si una superficie coge la pieza equivocada, o se mueve al revés, mira las constantes `AILERON_*`, `ELEVATOR_*` y `RUDDER_*` de `vox_models.gd`, o el signo en `_animate_surfaces` de `flight.gd`.

## Controles

Las teclas por defecto están en `controls.gd` (`DEFAULTS`). Las acciones se pueden reasignar con el `InputMap`.

## Sonido (efectos procedimentales)

Los efectos se generan al arrancar en bancos de variantes (`sfx_recipes.gd`, `sfx_bank.gd`, `synth_kit.gd`). Cada reproducción elige una variante al azar, distinta de la anterior, con un tono y un volumen algo distintos.

| Síntoma | Qué tocar |
|---|---|
| Las ráfagas suenan repetidas | `game_sound.gd`: `MG_VARIANTS` (8), `CANNON_VARIANTS` (6): más variantes |
| Suena «robótico» o demasiado distinto de un disparo a otro | `game_sound.gd`: `PITCH_VARIATION` (0,05), `GAIN_VARIATION_DB` (1,0); `sfx_recipes.gd`: `VARIATION` (0,08) |
| El cañón no tiene peso | `sfx_recipes.gd`: `CANNON_BODY_AMP` (0,9), `CANNON_BODY_HZ` (70), `CANNON_BODY_DECAY` (22): menos decaimiento = golpe más largo |
| El cañón suena chillón o sin ataque | `CANNON_CRACK_AMP` (0,8) y `CANNON_CRACK_CUTOFF` (2000 Hz) controlan el crujido de ataque; `CANNON_TAIL_HIGH` (3500) el brillo de la cola |
| El cañón tiene mucha o poca cola | `CANNON_TAIL_AMP` (0,35), `CANNON_TAIL_DECAY` (12); `CANNON_TIME` (0,28) |
| El cañón suena sucio o aplastado | `CANNON_DRIVE` (1,6): más bajo = más limpio |
| El cañón no se distingue de la ametralladora | subir `CANNON_BODY_AMP` y `CANNON_THUD_AMP` (0,6), o bajar `MG_BODY_AMP` (0,45) |
| La ametralladora es muy punzante o muy débil | `sfx_recipes.gd`: `MG_CRACK_AMP` (0,6), `MG_CLICK_AMP` (0,9), `MG_PEAK` (0,5) |
| La ametralladora suena a plástico o a lata | `MG_RING_AMP` (0,3) y `MG_RING_HZ` (2800): el timbre metálico; bájalo o muévelo |
| La ametralladora no tiene cuerpo | `MG_BODY_AMP` (0,45), `MG_BODY_HZ` (170) |
| El derribo no se oye entre el combate | `game_sound.gd`: `KILL_DB` (3 dB); `sfx_recipes.gd`: `KILL_PULSE_AMP` (0,45), `KILL_THUMP_AMP` (0,9) |
| El derribo suena a juego de móvil o a timbre | `KILL_PULSE_HZ` (880 y 1320 Hz), `KILL_PULSE_AMP`; menos armónicos = más suave |
| El derribo es largo o corto | `KILL_PULSE_LEN` (0,05 y 0,12 s), `KILL_WHISTLE_DECAY` (9), `KILL_TIME` (0,36) |
| El silbido del derribo es chillón | `KILL_WHISTLE_START` (2600 Hz), `KILL_WHISTLE_AMP` (0,35) |
| La caída del avión suena muy fuerte o flojo | `game_sound.gd`: `FALL_DB` (-8 dB) |
| La caída tiene poco chisporroteo | `sfx_recipes.gd`: `FALL_POP_AMP` (1,6), `FALL_POP_END` (160 por segundo), `FALL_POP_RAMP` (0,6) |
| El silbido de la caída es muy largo o agudo | `FALL_WHINE_DECAY` (1), `FALL_WHINE_START` (1100 Hz), `FALL_WHINE_SWEEP` (1,3) |
| Los cañones suenan «a la vez» o muy desparejos | `game_sound.gd`: `GUN_STAGGER` (4 a 14 ms) |
| Dos cañones suenan más fuertes que uno | `game_sound.gd`: `GUN_LAYER_DB` (3) |
| El impacto en chapa suena a campana o a plástico | `sfx_recipes.gd`: `METAL_HZ` (1300), `METAL_AMPS` (los parciales agudos), `METAL_DECAYS` (cuánto dura el tintineo) |
| El impacto en chapa es chillón | `METAL_LOWPASS` (9000 Hz), `METAL_CLICK_AMP` (0,7): más bajo = menos agudo |
| El impacto en chapa no «confirma» el acierto | subir `METAL_PING_AMP` (0,5) o su volumen mínimo en `game_sound.gd`: `IMPACT_DB` (-14 a -3 dB) |
| El impacto en estructura es flojo o poco crujiente | `STRUCT_THUD_AMP` (0,8), `STRUCT_CRUNCH_AMP` (0,7), `STRUCT_GRAIN_MIN` (0,15: más bajo = más a trozos) |
| Faltan esquirlas | `STRUCT_SPLINTERS` (2 a 4), `STRUCT_SPLINTER_AMP` (0,4) |
| Los impactos flojos y fuertes suenan igual | `game_sound.gd`: `IMPACT_DB`, `IMPACT_PITCH` (1,12 a 0,88); `weapons.gd`: `IMPACT_FULL_DMG` (12) |
| Un impacto fuerte en chapa no suma el crujido | `game_sound.gd`: `IMPACT_LAYER_SEVERITY` (0,6), `IMPACT_LAYER_DB` (-4) |
| Los impactos lejanos suenan igual que los cercanos | `game_sound.gd`: `IMPACT_FILTER_RANGE` (600 m), `IMPACT_CUTOFF_FAR` (2500 Hz) |
| Las explosiones no tienen peso | `sfx_recipes.gd`: `BOOM_BODY_AMP` y `BOOM_BODY_HZ` (una cifra por tamaño: pequeña, mediana, grande); `BOOM_BODY_DROP` (cuánto cae el tono) |
| La explosión no «pega» al principio | `BOOM_TRANSIENT_AMP` y `BOOM_TRANSIENT_DECAY`; `BOOM_DRIVE` (1,4) |
| La explosión es muy corta o muy larga | `BOOM_TIME` (0,6 / 1,0 / 1,9 s), `BOOM_TAIL_DECAY`, `BOOM_BODY_DECAY` |
| La cola suena a siseo | `BOOM_TAIL_HIGH` (más bajo = más apagado), `BOOM_TAIL_SWEEP` (más alto = se cierra antes), `BOOM_TAIL_AMP` |
| Una explosión pequeña suena como una grande (o al revés) | `game_sound.gd`: `EXPLOSION_SMALL_MAX` (1,2), `EXPLOSION_MEDIUM_MAX` (2,5): el tamaño sale de la escala del efecto visual |
| Las explosiones tapan todo o se oyen poco | `game_sound.gd`: `EXPLOSION_DB` (-1 / 2 / 4 dB) |
| Las explosiones lejanas se oyen igual que las cercanas | `EXPLOSION_FILTER_RANGE` (1500 m), `EXPLOSION_CUTOFF_FAR` (1200 Hz), `EXPLOSION_UNIT_SIZE` (alcance de cada tamaño) |
| Un efecto suena más fuerte o flojo que los demás | volumen de la llamada (`weapons.gd`, `effects.gd`, `ai_planes.gd`) o `*_PEAK` en `sfx_recipes.gd` |
| El juego tarda al arrancar | `game_sound.gd`: reducir los `*_VARIANTS` |

Mezcla (`game_sound.gd`, `audio_mixer.gd`; ver `SONIDO.md`):

| Síntoma | Qué tocar |
|---|---|
| El sonido satura o suena a muro de ruido en el combate | `audio_mixer.gd`: `COMP_THRESHOLD_DB` (-3: más bajo = comprime antes), `COMP_RATIO` (3); `game_sound.gd`: `MASTER_DB` (-12) |
| Los disparos y explosiones suenan «aplastados» o sin pegada | `audio_mixer.gd`: subir `COMP_THRESHOLD_DB` o `COMP_ATTACK_US` (500) |
| Se cortan impactos o explosiones que quieres oír | `game_sound.gd`: `MAX_IMPACTS` (8), `MAX_EXPLOSIONS` (4), `MAX_ENEMY_GUNS` (6), `MAX_FALLS` (4) |
| Con muchos impactos a la vez suena flojo | `game_sound.gd`: `CROWD_DB` (1,5): más bajo = baja menos la ganancia |
| El motor no se agacha con las explosiones o lo hace demasiado | `game_sound.gd`: `DUCK_DB` (0 / -3 / -8), `DUCK_HOLD` (0,25), `DUCK_RELEASE` (0,8) |
| Un pico sigue recortando | `audio_mixer.gd`: `LIMITER_CEILING_DB` (-1), `LIMITER_THRESHOLD_DB` (-3) |

## Música (ver `MUSICA.md`)

| Síntoma | Qué tocar |
|---|---|
| La música se oye muy fuerte o muy floja | `music_player.gd`: `MUSIC_DB` (-14 dB) |
| Suena aguda o chillona | `chip_synth.gd`: `LOWPASS_HZ` (2600: más bajo = más sorda); o bajar las notas una octava en `music_scores.gd` |
| Suena apagada o sorda | subir `LOWPASS_HZ` o el `amp` del solista en el estilo del país |
| Dos países aún suenan parecidos | cambiar en su `style` el `bpm`, el `pattern` del bajo y de los acordes, el `duty` o el `gap` del solista, o los patrones de percusión (`music_scores.gd`) |
| Un país suena muy cargado o muy vacío | `style.lead.double`, `style.harmony.amp`, `style.chords.pattern` (`none` lo quita) |
| El bajo no se oye o retumba | `style.bass.amp`; `chip_synth.gd`: `BASS_SHIFT` (-12) |
| La percusión molesta o falta | `chip_synth.gd`: `KICK_AMP` (0,5), `SNARE_AMP` (0,22), `TOM_AMP` (0,45), `HAT_AMP` (0,1); o el patrón en `style.drums` |
| Los redobles de caja sobran | `style.drums.fills` a `false`; `chip_synth.gd`: `ROLL_EVERY` (4) |
| Las notas suenan muy pegadas o muy picadas | `style.lead.gap` (silencio al final de cada nota) |
| El swing es muy fuerte o falta | `style.swing` (0,5 = recto; EE. UU. usa 0,64) |
| Quiero otro tempo | `bpm` de cada marcha |
| La música tarda en empezar tras darle a empezar | se genera al elegir avión; con muy poco tiempo en el menú puede no estar lista (`music_player.gd`, `prepare`) |
| Con las explosiones la música baja demasiado | `game_sound.gd`: `DUCK_DB` (afecta también al motor) |

## Imagen (mapeo tonal y gradacion) — `world.gd`
Sin probar en el motor: ACES cambia el brillo de todo (cielo, suelo, luces), asi que afinalo de ojo.
- Demasiado brillo -> baja `TONEMAP_EXPOSURE` (0.4-0.5) y `RAY_INTENSITY`.
- Todo se ve oscuro o apagado -> sube `TONEMAP_EXPOSURE` (0.6 por defecto; prueba 0.8-1.2) o `AMBIENT_ENERGY`/`SUN_ENERGY`.
- Colores lavados -> sube `GRADE_SATURATION`; chillones -> bajala. Poco relieve -> sube `GRADE_CONTRAST`.
- Altitud fria: `BALANCE_FRIO`, `ALT_FRIA_INI`, `ALT_FRIA_FIN`. Hangar calido: `BALANCE_CALIDO`. Ganancias maximo 1.0.

## Rayos de sol (god rays) — `world.gd` (RAY_*) y `motion_blur.gdshader`
Sin probar en el motor. El resplandor se calcula por direccion (no por pixel), asi que los rayos salen aunque el sol quede fuera de pantalla; las nubes con dithering y el terreno los van apagando.
- No se ven -> sube `RAY_INTENSITY` (0.8 ahora; 1-2) o `RAY_ABSORB` (0.5 = franjas mas duras); demasiado velo -> bajala. Muy brillantes junto al sol -> baja `RAY_WEIGHT`.
- Rayos cortos -> sube `RAY_DECAY` (hasta 0.98) y `RAY_DENSITY` (hasta 1.0); demasiado largos -> bajalos.
- Resplandor muy grande o pequeno -> `RAY_SPREAD` (40; mayor = mas estrecho). Si aparece cerca del sol al reves o en otro sitio, revisa el signo de `sun_dir`.
- Coste: 32 lecturas de profundidad por pixel; si baja el rendimiento, baja `RAY_SAMPLES` en el shader (16 basta).

## Vibrancia y rendimiento de la imagen
Sin probar en el motor. `VIBRANCE` (world.gd, 0 = apagada, 0.3 por defecto) satura mas lo apagado que lo vivo; se aplica antes del mapeo tonal.
- Si el cielo o el suelo se ven artificiales, baja `VIBRANCE` o `GRADE_SATURATION`: se suman.
- Coste por pixel de la pasada: 16 lecturas de desenfoque (1 si casi no hay movimiento) + 24 de los rayos. Si bajan los fps: `RAY_SAMPLES` a 12 y `SAMPLES` a 8 en el shader.
- Las nubes y el humo (transparentes) se dibujan despues de esta pasada: no reciben vibrancia ni rayos, pero si el mapeo tonal ACES.

## Nubes y rayos de sol
Sin probar en el motor. Las nubes tienen dithering (30% de pixeles, `COVERAGE` en cloud.gdshader) y escriben profundidad: cada muestra de rayo que cae en un pixel de nube apaga el rayo (`RAY_ABSORB`). Mas `COVERAGE` = rayos mas marcados, pero mas tramado visible en el cielo.
- Mas o menos nubes -> `CLOUD_COUNT` en world.gd (260; si bajan los fps, 150).
- El sol (`SUN_ROTATION` en world.gd) esta a 22 grados de altura y 40 a la izquierda del rumbo inicial: al empezar sale arriba a la izquierda. Antes estaba a 50 grados y detras del avion, y no se veia nunca. Mas bajo (10-15) = rayos mas largos y sombras mas largas; mas alto = menos rayos. Los rayos solo se ven con el sol (o su lado del cielo) en pantalla y nubes por delante.
- Niebla: `FOG_DENSITY` en world.gd (0.0002 ahora; 0.0005 era la anterior). Menos niebla = mas lejania visible pero rayos menos velados; mas niebla = mas bruma y rayos mas suaves. El hangar usa la misma.

## Imagen palida
Sin probar. Si el cielo y el suelo se ven lavados: prueba `TONEMAPPER = Environment.TONE_MAPPER_LINEAR` en world.gd (es la imagen de antes del mapeo tonal; con ese modo `TONEMAP_EXPOSURE` debe volver a 1.0). Si asi se ve bien, el culpable es ACES. Otros sospechosos: `AMBIENT_ENERGY` (el ambiente azulado del cielo palidece el suelo), `FOG_DENSITY` y `FOG_COLOR`. Ahora `GRADE_SATURATION` 1.25, `VIBRANCE` 0.6 y `GRADE_CONTRAST` 1.15 compensan ACES.
- Nubes en racimos con huecos (world.gd): `CLOUD_ALTITUDE` (600-1200 m), `CLOUD_CLUSTERS` (16) y `CLOUD_CLUSTER_RADIUS` (500 m). Mas huecos = menos racimos o radio menor; mas nubes juntas = lo contrario. Sin probar. Los rayos de sol entran por los huecos; para volar bajo las nubes, sube el avion por debajo de 600 m.

## Rayos largos y destello de lente del sol
Sin probar. `world.gd`: `RAY_STREAKS` (0.6) mete radios fijos alrededor del sol aunque no haya nubes (0 = solo los de las nubes, 1 = muy marcados); `RAY_DENSITY` 1.0, `RAY_DECAY` 0.985 y `RAY_INTENSITY` 1.2 los alargan y los marcan; el largo maximo en pantalla es `RAY_MAX_LEN` (1.0) en el shader. Mas o menos radios: `RAY_STREAKS_A` y `RAY_STREAKS_B` en el shader.
- Destello: `FLARE_INTENSITY` (0.6, 0 lo apaga). Aparece solo con el sol en pantalla y sin nube delante; se desvanece al salir por el borde. Posiciones, tamanos y colores de los reflejos: `GHOST_POS`, `GHOST_RADIUS`, `GHOST_TINT` en el shader.
- Si el cielo se quema junto al sol: baja `FLARE_INTENSITY` y `RAY_INTENSITY`.

## Rafagas de la IA
Sin probar. Antes la IA disparaba la rafaga entera aunque el objetivo se fuera, y la pausa se contaba desde que EMPEZABA (en el pesado y el aliado la rafaga duraba mas que la pausa: fuego casi continuo). Ahora la pausa (`ENEMY_REST`, `ALLY_REST`) cuenta desde que acaba, y la rafaga se corta si el objetivo sale del cono (`ENEMY_BURST_BREAK` x `fire_cone`), del alcance, o si el avion evade.
- Siguen acertando demasiado -> sube `ENEMY_SPREAD` (0.012; prueba 0.02) o `ENEMY_AIM_ERR`.
- Disparan poco -> baja `ENEMY_REST` o sube `ENEMY_BURST_BREAK`.

## Batalla continua y vuelta al hangar
Sin probar. Al ser derribado: Enter (o M en vuelo) cierra la persiana (`SHUTTER_TIME` en hud.gd, 0,3 s) y abre el hangar para elegir avion. La batalla NO se reinicia: los enemigos, el aliado y los derribos quedan congelados y ocultos mientras estas en el hangar, y al lanzarte siguen donde estaban. Solo se reinicia al arrancar el juego.
- Reaparicion (main.gd): `RESPAWN_ALT` (250 m), `RESPAWN_RADIUS` (900 m) y `RESPAWN_CANDIDATES` (8): prueba 8 sitios alrededor de donde dejaste la batalla, elige el mas lejano a los enemigos y mira al mas cercano.
- Se borran las balas en vuelo y se llena el cargador al reaparecer; se mantienen los derribos y la dificultad que sube con ellos.

## Cortina de chapa olivo
Sin probar. Las transiciones (derribado -> hangar, hangar -> partida, lanzar desde el menu y ahora lobby -> hangar) usan una cortina de lamas de chapa olivo con bisel y remaches (`MilitaryStyle.slat`), con el borde ambar al avanzar. Duracion: `Hud.SHUTTER_TIME` (0,3 s). Lamas: `HudStyle.SHUTTER_SLATS` y desfase: `HudStyle.SHUTTER_STAGGER`. Remaches: `MilitaryStyle.SLAT_RIVET_STEP` y `SLAT_RIVET_MIN_H`.

## Distancia del combate y ventaja de la IA
Sin probar. Antes la IA viraba hasta 1,5 rad/s al instante (el avion del jugador tiene mandos con inercia, derrape y perdida) y no perdia velocidad al hacerlo, y aparecia a 900 m y rompia a 200 m. Ahora (`ai_planes.gd`):
- `ENEMY_MAX_G` (5,5): tope de G al virar. Giro maximo = G x 9,81 / velocidad: a 85 m/s son ~0,63 rad/s, mas abierto cuanto mas rapido. Virar a muchas G le cuesta velocidad como al jugador. Para volverlos mas agiles sube `ENEMY_MAX_G` (7 = como el jugador) o `ENEMY_TURN_MAX`.
- `ENEMY_SPAWN_DIST` (1600 m, antes 900), `ENEMY_BREAK_DIST` (300 m, antes 200) y `ENEMY_EXTEND_TIME` (6 s, antes 4): el combate empieza mas lejos y los pases son mas amplios. `RESPAWN_RADIUS` (main.gd) pasa a 1500 m.
- Si ahora los enemigos tardan demasiado en llegar: baja `ENEMY_SPAWN_DIST` (1200). Si siguen demasiado encima: sube `ENEMY_BREAK_DIST` y `ENEMY_EXTEND_TIME`.

## Derrape sin control (perdida por angulo de ataque)
Sin probar. Antes, con demasiado angulo de ataque el ala perdia sustentacion y la trayectoria dejaba de seguir al morro, pero el morro solo se corregia si estaba POR ENCIMA de la trayectoria: con el morro de lado o por debajo el avion se quedaba deslizando mirando hacia otro lado, con los mandos al 20 %. Ahora (`flight.gd`) hay una veleta: con perdida por angulo de ataque el aire devuelve el morro hacia la trayectoria, en cualquier direccion, a `AOA_WEATHERVANE` (2,0 rad/s a perdida total). `STALL_DROP` queda solo para la perdida por falta de velocidad.
- Sigue derrapando demasiado tiempo -> sube `AOA_WEATHERVANE` (3) o `AOA_STALL` (0,55: entra en perdida mas tarde).
- Ahora recupera demasiado de golpe o no se puede forzar el morro -> baja `AOA_WEATHERVANE` (1,2).

## Rondas
Sin probar. La batalla es por rondas (`ai_planes.gd`): cada ronda es un grupo de cazas que entra por el mismo lado y UNO TRAS OTRO (`ROUND_SPAWN_GAP`, 2,5 a 4 s entre avion y avion), con una dispersion lateral de `ROUND_SPREAD` (220 m). Al derribarlos a todos hay una pausa de `ROUND_BREAK_TIME` (8 s) con un cartel y empieza la siguiente. Sustituye al sistema anterior de reaparicion continua (`START_FIGHTERS`, `MAX_ENEMIES`, `SPAWN_INTERVAL` y `HEAVY_RESPAWN_TIME` ya no existen).
- Cazas por ronda: `ROUND_FIGHTERS_BASE` (2) + 1 por ronda, hasta `ROUND_FIGHTERS_MAX` (6), y `ROUND_PER_EXTRA_PLAYER` (1) mas por cada jugador de mas en red.
- Un pesado cada `ROUND_HEAVY_EVERY` (3) rondas, tras los dos primeros cazas. El aliado se repone como antes (`ALLY_RESPAWN_TIME`).
- Mas lento o mas rapido el goteo -> `ROUND_SPAWN_GAP`. Mas o menos tiempo entre rondas -> `ROUND_BREAK_TIME`; antes de la primera: `ROUND_FIRST_DELAY`.
- HUD: bajo DERRIBOS sale "RONDA n QUEDAN m"; al empezar una ronda, un cartel (`BANNER_TIME`, en hud.gd), y en la pausa "RONDA n COMPLETADA" con la cuenta atras.

## Tienda del hangar
Sin probar. Datos en `shop.gd`: `KILL_CREDITS` (5 por derribo), y por mejora `BONUS` y `PRICES`: dano +15/+25/+35 % por 15/25/35, cadencia +15/+25/+35 % por 10/20/30, salud +20/+35/+50 % por 20/40/50. Cada nivel sustituye al anterior (no se suman). Se compra el siguiente nivel con clic en la fila (panel bajo la telemetria del hangar). Los creditos se conservan; las mejoras se pierden al ser derribado (`Game._player_die`) y se pueden volver a comprar. Si vuelves al hangar con M sin morir las conservas.
- Aplican: dano y cadencia en `weapons.gd` (`shop_mult`), salud al aparecer (`Game._spawn_player`).
- El anfitrion valida los impactos de los clientes con margenes que cubren +35 % (`RemotePilots.HIT_DMG_MARGIN`, `HIT_RATE_MARGIN`).
- Dibujo: `start_menu.gd` (`SHOP_*`).

## Zoom
Sin probar. `ChaseCam.ZOOM_FOV_FACTOR` (chase_cam.gd) es el campo de vision con el zoom al maximo relativo al normal: 0,3 (x3,3 de aumento; antes 0,5 = x2). Mas profundo -> baja (0,2 = x5); menos -> sube. El apuntado con el raton se afina solo con el zoom (usa el mismo factor). `ZOOM_TIME` (0,3 s) es lo que tarda en entrar.

## Relieve (colinas) — `world.gd` (HILL_*, TERRAIN_*) y `ground.gdshader`
Sin probar. Mapa de alturas de 256x256 que se repite cada 16 km; la malla del suelo sigue al jugador y el shader la levanta. Los choques (jugador, IA, balas, escombros, camara) usan `World.ground_height()`.
- Mas o menos altura -> `HILL_MAX` (160 m; la salida es a 200 m, no lo subas mucho sin subir tambien la altura de salida).
- Mas o menos llanura -> `HILL_FLOOR` (0,3: mayor = mas valles planos). Cimas mas o menos marcadas -> `HILL_CURVE` (1,2).
- Colinas mas grandes o pequenas -> `HILL_FREQ` (0,02; menor = mas anchas). Otro paisaje -> `HILL_SEED`.
- Roca en las laderas -> `slope_start`, `slope_end` y `rock_color` en el shader. Tierra seca y grano -> `dry_*`, `patch_size`, `grain_size`.
- Si los fps bajan: `TERRAIN_SPACING` 32 -> 48 (y `TERRAIN_SIZE` multiplo de el, p. ej. 14064).

## Explosiones (visual) — `effects.gd` (`explode`)
Sin probar. Capas: onda de choque, nucleo al rojo blanco (`CORE_BRIGHTNESS`), bola de fuego (`EXPLOSION_FIRE_BRIGHTNESS`), columna de humo, cola de humo hacia atras de la trayectoria (`PLUME_SPEED`, `PLUME_MIN_SPEED`), nube de hollin persistente, fragmentos con cola, chispas y brasas (`EMBER_SPEED`, `EMBER_LIFE`).
- Mas o menos resplandor -> `CORE_BRIGHTNESS` (4; el bloom empieza en `glow_hdr_threshold` 2,5 de world.gd) y `EXPLOSION_FIRE_BRIGHTNESS` (3).
- Si bajan los fps con muchas explosiones: baja las cantidades `int(... * sc)` de cada capa o la vida de la nube de hollin (11 s).

## Resolucion del HUD de vuelo — `hud_view.gd` (`DETAIL`)
Sin probar. El diseno del HUD (posiciones, tamanos, 8/16 px de texto) no cambia, pero el lienzo es `DETAIL` veces mas fino: lineas, puntos, circulos y texto salen con 1 px del lienzo. A 720p las lineas miden la mitad, a 1080p dos tercios (3 px pasan a 2).
- Mas fino aun -> `DETAIL` 3 (a 1080p lineas de 1 px de pantalla; a 720p igual que 2). Como antes -> `DETAIL` 1.
- A 1080p el texto sale a 12 y 24 px (el 12 no es multiplo de 8, que es donde la fuente pixel es mas nitida): `DETAIL` 3 da 24 y 48.
- Los menus (hangar, lobby, pausa) no cambian. Persiana y vineta del HUD siguen con el pixel grueso de siempre.
