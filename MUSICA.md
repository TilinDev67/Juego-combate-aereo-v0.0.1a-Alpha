# Música de 8 bits por país

Cada avión tiene la marcha de su país en bucle durante la partida: IL-2 (URSS), Bf 109, Ju 87 y Fw 190 (Alemania), Spitfire (Reino Unido), P-51 (EE. UU.) y Zero (Japón).

## Qué suena (y qué no)

**No son los himnos reales.** Varios siguen protegidos por derechos de autor (el de la Fuerza Aérea de EE. UU. y, probablemente, el *Aviamarsh* soviético), y no hay un himno aéreo oficial claro para Alemania ni para Japón. Son **marchas originales** compuestas en el estilo de la aviación de cada país. Las piezas reales de dominio público que se habían planteado (la *Royal Air Force March Past* de Walford Davies y la canción aérea de 1910) **no se incluyen** porque no se pudo obtener su melodía con fiabilidad; para añadir una, basta con escribirla en `music_scores.gd` con el mismo formato.

## Un arreglo distinto por país

Cada país tiene su propia melodía, y también **su propio arreglo**: timbre, articulación, ritmo, bajo, acordes, percusión, forma y tempo. Esto es lo que hace que no suenen igual.

| | URSS | Alemania | Reino Unido | EE. UU. | Japón |
|---|---|---|---|---|---|
| **Tempo** | 92 | 136 | 116 | 120 | 60 |
| **Tonalidad** | re menor armónico | fa mayor | sol mayor | do (blues) | escala *in* (re, mi♭, sol, la, si♭) |
| **Forma** | 16 compases | 16 | 16 | **12 (blues)** | **12, escasa** |
| **Ritmo de la melodía** | notas largas, solemne | corcheas continuas | **figuras con puntillo** | **swing y síncopa, con silencios** | **2 notas por compás a contratiempo, 32 % de silencio** |
| **Timbre del solista** | cuadrada llena, ligada | pulso fino (25 %), **muy corta** | cuadrada llena, **muy ligada** | pulso fino, picada, swing | **pulsada como un koto** (suena y se apaga) |
| **Segunda voz** | coro en terceras + octava abajo | — | terceras | — | — |
| **Bajo** | **pedal** muy grave | **alterna** raíz y quinta cada tiempo | **caminante** ligado | **caminante** acabando en sexta o séptima | **bordón** de quinta |
| **Acordes** | — | en los tiempos flojos | **colchón** sostenido (órgano) | **contratiempos** con swing | — |
| **Percusión** | bombo, timbal en cada tiempo, caja, redobles | caja que **repica sin parar**, redobles | **timbales afinados**, caja suave, redobles | plato de swing, bombo suave, caja de contratiempo | **taiko** grave suelto y bloque de madera |

## Estilo «no tan agudo»

- Melodías entre Re4 y Fa5 (294-698 Hz).
- Ondas cuadradas llenas, bajo triangular y percusión suave.
- Dos filtros pasa-bajos a 2,6 kHz y muestreo de 11 kHz: solo el 2-6 % de la energía queda por encima de 2 kHz y entre el 64 y el 86 % por debajo de 500 Hz.

## Cómo funciona

| Archivo | Qué hace |
|---|---|
| `music_scores.gd` | Las cinco partituras (melodía, acordes y estilo) |
| `chip_synth.gd` | Las convierte en un bucle de 8 bits siguiendo el estilo |
| `music_player.gd` | Las genera en un hilo aparte, las guarda y las reproduce con fundido |
| `audio_mixer.gd` | Bus `Music`, que se agacha con las explosiones junto al motor |

La música del avión elegido se genera en segundo plano **mientras estás en el menú**. Suena al empezar o reiniciar, se detiene al ser derribado y al volver al menú.

## Formato de una partitura

- `melody`: notas `D4:1.5` (nombre, octava y duración en tiempos), `r:1` para un silencio y `|` entre compases. Cada compás suma 4 tiempos.
- `chords`: un símbolo por compás (`Dm`, `A7`, `F#m`, `Bb`; el 7 añade la séptima menor).
- `style`: `swing`; `lead` (`duty`, `amp`, `gap`, `sustain`, `decay`, `double`); `harmony` (`amp`, `duty`, `scale`); `bass` (`pattern`: `pedal`, `alt`, `walk`, `walk6`, `drone`); `chords` (`pattern`: `afterbeat`, `offbeat`, `pad`, `none`); `drums` (patrones de 8 casillas para `kick`, `snare`, `tom`, `hat`, `click`; `X` marcado, `x` suave, `.` nada; `tom_hz`, `tom_decay`, `fills`).

## Cuánto se parecen (medido, no escuchado)

Con un port en Python comparé las cinco: el patrón rítmico de las melodías se parece entre sí como máximo un 0,79 (1 = idénticas), con EE. UU. y Reino Unido en 0,39 y URSS y Japón en 0,21-0,75. Es una medida del ritmo, no del gusto: lo que de verdad hay que hacer es escucharlas.

## Poner una pieza real (por ejemplo el *Aviamarsh*, «Все выше»)

No se puede escribir una melodía real de memoria sin equivocarse, así que se importa de un archivo MIDI con `herramientas/midi_a_partitura.py`:

1. Consigue un MIDI de la pieza (por ejemplo, la versión de «Все выше» que aparece en [MidiShow](https://www.midishow.com/en/midi/188014.html), de 6 instrumentos y 120 bpm, sin autor indicado, o cualquier otra que tengas) y guárdalo en el proyecto.
2. `python herramientas/midi_a_partitura.py cancion.mid` lista las pistas.
3. `python herramientas/midi_a_partitura.py cancion.mid --pista N` saca la melodía de esa pista: la deja a una sola voz, la cuantiza a semicorcheas, la mueve a las octavas del rango suave de la música (Re4 a Fa5) y calcula un acorde por compás con todas las pistas. Opciones: `--transponer N` (semitonos) y `--compases N` (por defecto 32).
4. Pega el `bpm`, la `melody` y los `chords` que escribe en la entrada del país en `music_scores.gd` y deja o cambia el `style`.

Solo admite compás de 4/4 y revisa a mano el resultado: la herramienta transcribe lo que hay en el MIDI, no sabe si el MIDI es fiel a la obra.

**Derechos.** El *Aviamarsh* es de Yuli Khayt (letra de Pavel German), publicado en 1923. No he podido confirmar cuándo murió Khayt: si es de los años 60, su obra sigue protegida en Rusia y la UE hasta 2036, y en EE. UU. probablemente es de dominio público por su fecha de publicación, pero no está verificado. Para un juego que se vaya a distribuir conviene comprobarlo; para uso propio no hay problema.

### Sacar la melodía de un mp3 (`herramientas/mp3_a_partitura.py`): qué funciona y qué no

Requiere `pip install numpy miniaudio`. Con el mp3 del *Aviamarsh* que se probó:

- **Funciona bien:** el tempo (118,0 bpm exactos y constantes), la rejilla de compases (36 compases, el primer tiempo en 0,00 s) y la **estructura**: una introducción de 4 compases, una frase A de 8 compases (compases 5-12, que se repite idéntica en 13-20) y una frase B de 8 (21-28, que se repite en 29-36).
- **No funciona bien:** la **melodía**. La grabación es una textura de metales con varias voces a la vez, y el análisis de tono de una sola voz salta entre la melodía, sus armónicos y las voces de armonía. Ninguna variante probada da una línea fiable; el borrador que sale (`aviamarsh_borrador.txt` y `aviamarsh_borrador_melodia.wav`) hay que comprobarlo de oído y casi seguro tiene notas mal.
- **Conclusión:** para una pieza real conviene un **MIDI** (que `midi_a_partitura.py` convierte sin errores) y no un mp3 con muchas voces. El mp3 sirve para confirmar el tempo, la tonalidad y la forma.
