## Partituras y arreglos de la musica de cada pais: marchas originales en el estilo de la aviacion de cada uno.
## No son los himnos reales (varios siguen protegidos por derechos de autor): son composiciones propias. Para anadir
## una pieza real de dominio publico basta con escribir su melodia, sus acordes y un estilo con el mismo formato.
## Todas las melodias se mueven entre Re4 y Fa5 (294-698 Hz): graves y suaves, nada de agudos.
##
## Formato: "melody" = notas "D4:1.5" (nombre, octava y duracion en tiempos) y "r:1" para silencios, barras "|" entre
## compases; "chords" = un simbolo por compas ("Dm", "A7", "F#m", "Bb"; el 7 anade la septima menor). Cada compas
## suma 4 tiempos. El "style" es el arreglo (ver ChipSynth):
##   swing    0.5 = recto; mas = la segunda corchea se retrasa
##   lead     duty (ciclo de la onda), amp, gap (silencio al final de la nota), sustain y decay (como cae), double (octava abajo)
##   harmony  segunda voz en terceras por debajo: amp, duty y la escala (clases de nota) para que sea diatonica
##   bass     pattern: pedal, alt, walk, walk6 o drone
##   chords   pattern: afterbeat, offbeat, pad o none
##   drums    kick, snare, tom, hat y click: 8 casillas por compas ("X" marcado, "x" suave, "." nada); tom_hz, tom_decay, fills
class_name MusicScores
extends RefCounted

const SCORES := {
	# URSS: marcha pesada en re menor armonico. Coro a dos voces en terceras con las octavas dobladas, bajo de pedal
	# muy grave, bombo y timbal marcando cada tiempo y redobles de caja al final de cada frase. Sin acordes sueltos.
	"ussr": {
		"title": "Marcha del Ala Roja (estilo sovietico)",
		"bpm": 92.0,
		"melody": "A4:2 D5:1.5 C5:.5 | Bb4:1 A4:1 G4:1 F4:1 | G4:2 Bb4:1.5 A4:.5 | G4:1 F4:1 E4:1 C#5:1 | " \
				+ "D5:2 F5:1.5 E5:.5 | D5:1 C5:1 Bb4:1 A4:1 | G4:1 A4:1 C#5:1 E5:1 | D5:3 r:1 | " \
				+ "A4:1.5 C5:.5 F5:2 | E5:1.5 D5:.5 C5:2 | Bb4:1.5 D5:.5 D5:2 | C#5:1 D5:1 E5:2 | " \
				+ "F5:1 E5:1 D5:1 C5:1 | Bb4:1 A4:1 G4:1 Bb4:1 | A4:1 C#5:1 E5:1 A4:1 | D4:3 r:1",
		"chords": "Dm Dm Gm A Dm Dm A7 Dm F C Gm A7 Dm Gm A7 Dm",
		"style": {
			"swing": 0.5,
			"lead": {"duty": 0.5, "amp": 0.28, "gap": 0.04, "sustain": 0.85, "decay": 1.0, "double": 0.18},
			"harmony": {"amp": 0.16, "duty": 0.5, "scale": [2, 4, 5, 7, 9, 10, 1]},
			"bass": {"pattern": "pedal", "amp": 0.36},
			"chords": {"pattern": "none"},
			"drums": {"kick": "X...X...", "snare": "..x...x.", "tom": "x.x.x.x.", "tom_hz": 90.0, "tom_decay": 10.0, "fills": true},
		},
	},
	# Alemania: marcha prusiana en fa mayor. Notas muy cortas (staccato) de pulso fino, corcheas continuas, bajo que
	# alterna raiz y quinta en cada tiempo, acordes en los tiempos flojos y una caja que repica sin parar.
	"germany": {
		"title": "Marcha del Aire (estilo aleman)",
		"bpm": 136.0,
		"melody": "F4:.5 A4:.5 C5:.5 A4:.5 F5:1 C5:1 | A4:.5 C5:.5 A4:.5 F4:.5 A4:2 | G4:.5 Bb4:.5 C5:.5 E5:.5 D5:1 C5:1 | C5:.5 A4:.5 F4:1 F4:2 | " \
				+ "Bb4:.5 D5:.5 F5:.5 D5:.5 Bb4:1 D5:1 | C5:.5 A4:.5 F4:.5 A4:.5 C5:2 | E5:.5 D5:.5 C5:.5 Bb4:.5 G4:1 Bb4:1 | A4:.5 G4:.5 F4:1 F4:1 r:1 | " \
				+ "C5:.5 F5:.5 E5:.5 D5:.5 C5:1 A4:1 | D5:.5 C5:.5 D5:.5 F5:.5 D5:1 A4:1 | Bb4:.5 D5:.5 Bb4:.5 A4:.5 G4:1 Bb4:1 | C5:.5 E5:.5 G4:.5 Bb4:.5 C5:1 r:1 | " \
				+ "A4:.5 C5:.5 F5:.5 C5:.5 A4:1 F4:1 | D5:.5 Bb4:.5 D5:.5 F5:.5 D5:1 Bb4:1 | E5:.5 D5:.5 C5:.5 Bb4:.5 A4:1 G4:1 | F4:2 F4:1 r:1",
		"chords": "F F C7 F Bb F C7 F F Dm Gm C7 F Bb C7 F",
		"style": {
			"swing": 0.5,
			"lead": {"duty": 0.25, "amp": 0.30, "gap": 0.45, "sustain": 0.5, "decay": 6.0},
			"bass": {"pattern": "alt", "amp": 0.34},
			"chords": {"pattern": "afterbeat"},
			"drums": {"kick": "X...x...", "snare": "XxXxXxXx", "fills": true},
		},
	},
	# Reino Unido: marcha pomposa en sol mayor, animada. Figuras con puntillo (corchea con puntillo y semicorchea) en casi
	# todos los compases, notas ligadas, segunda voz en terceras, bajo caminante, colchon de acordes sostenido (a modo de
	# organo), timbales afinados y redobles.
	"uk": {
		"title": "Marcha de la RAF (estilo britanico)",
		"bpm": 116.0,
		"melody": "D5:.75 D5:.25 B4:.75 G4:.25 B4:1 D5:1 | E5:.75 E5:.25 D5:.75 B4:.25 G4:2 | C5:.75 C5:.25 E5:.75 C5:.25 G4:1 C5:1 | B4:.75 A4:.25 F#4:1 A4:1 D5:1 | " 				+ "G4:.75 G4:.25 B4:.75 D5:.25 B4:1 G4:1 | E5:.75 D5:.25 B4:.75 G4:.25 B4:2 | A4:.75 C5:.25 E5:.75 C5:.25 A4:1 C5:1 | C5:.75 B4:.25 A4:1 F#4:1 A4:1 | " 				+ "E5:.75 E5:.25 G4:.75 C5:.25 E5:2 | D5:.75 B4:.25 G4:.75 B4:.25 D5:2 | C5:.75 E5:.25 A4:.75 C5:.25 E5:1 C5:1 | D5:.75 C5:.25 A4:1 F#4:2 | " 				+ "B4:.75 D5:.25 B4:.75 G4:.25 D5:1 B4:1 | C5:.75 E5:.25 C5:.75 G4:.25 E5:2 | A4:.75 C5:.25 B4:.75 A4:.25 F#4:1 A4:1 | G4:3 r:1",
		"chords": "G Em C D7 G Em Am D7 C G Am D7 G C D7 G",
		"style": {
			"swing": 0.5,
			"lead": {"duty": 0.5, "amp": 0.28, "gap": 0.02, "sustain": 0.9, "decay": 0.8},
			"harmony": {"amp": 0.17, "duty": 0.5, "scale": [7, 9, 11, 0, 2, 4, 6]},
			"bass": {"pattern": "walk", "amp": 0.34},
			"chords": {"pattern": "pad"},
			"drums": {"tom": "X...x...", "tom_hz": 110.0, "tom_decay": 9.0, "snare": "..x...x.", "fills": true},
		},
	},
	# EE. UU.: blues de 12 compases en do con swing marcado. Riff sincopado con silencios en los tiempos fuertes,
	# bajo caminante que acaba en sexta o septima, acordes en los contratiempos y un plato de swing con bombo suave.
	"usa": {
		"title": "Marcha del Cielo Azul (estilo estadounidense)",
		"bpm": 120.0,
		"melody": "E4:.5 G4:.5 r:.5 C5:.5 r:1 Bb4:.5 G4:.5 | E4:.5 G4:.5 r:.5 C5:.5 r:1 E5:1 | D5:.5 C5:.5 Bb4:.5 G4:.5 E4:1 G4:1 | C5:1.5 r:.5 G4:1 r:1 | " \
				+ "F4:.5 A4:.5 r:.5 C5:.5 r:1 Eb5:1 | F4:.5 A4:.5 r:.5 C5:.5 r:.5 Eb5:.5 C5:1 | E4:.5 G4:.5 r:.5 C5:.5 r:1 Bb4:1 | G4:1 E4:.5 G4:.5 C5:2 | " \
				+ "D5:.5 D5:.5 r:.5 B4:.5 r:.5 F5:.5 D5:1 | C5:.5 C5:.5 r:.5 A4:.5 r:.5 Eb5:.5 C5:1 | G4:.5 E4:.5 G4:.5 C5:.5 Bb4:1 G4:1 | D5:1 B4:.5 G4:.5 r:2",
		"chords": "C7 C7 C7 C7 F7 F7 C7 C7 G7 F7 C7 G7",
		"style": {
			"swing": 0.64,
			"lead": {"duty": 0.25, "amp": 0.30, "gap": 0.15, "sustain": 0.6, "decay": 4.0},
			"bass": {"pattern": "walk6", "amp": 0.34},
			"chords": {"pattern": "offbeat"},
			"drums": {"kick": "x...x...", "snare": "..X...X.", "hat": "x.xxx.xx"},
		},
	},
	# Japon: pieza muy escasa de 12 compases en la escala "in" (re, mi bemol, sol, la, si bemol), lenta (60). Apenas dos
	# notas por compas, casi siempre entrando a contratiempo y con mucho silencio ("ma"), adornos rapidos, notas que
	# se pulsan y se apagan enseguida (como un koto), un bordon de quinta muy suave en lugar de bajo y un taiko grave
	# con un bloque de madera sueltos.
	"japan": {
		"title": "Marcha de las Alas del Sol (estilo japones)",
		"bpm": 60.0,
		"melody": "r:1.5 A4:1 G4:1.5 | D4:3 r:1 | r:.5 G4:.5 A4:.25 G4:.25 Bb4:2.5 | r:2 A4:1 r:1 | " 				+ "r:1 D5:1.5 Bb4:1.5 | A4:.5 G4:.5 r:1 Bb4:2 | r:1.5 Bb4:1 A4:.5 G4:1 | A4:2.5 r:1.5 | " 				+ "r:.5 D5:.5 Eb5:.25 D5:.25 Bb4:1.5 G4:1 | r:2 A4:.5 Bb4:.5 A4:1 | G4:3 r:1 | r:1 D4:3",
		"chords": "Dm Dm Gm Dm Dm Gm Bb Dm Gm Dm Gm Dm",
		"style": {
			"swing": 0.5,
			"lead": {"duty": 0.25, "amp": 0.38, "gap": 0.0, "sustain": 0.15, "decay": 8.0},
			"bass": {"pattern": "drone", "amp": 0.18},
			"chords": {"pattern": "none"},
			"drums": {"tom": "X.....x.", "tom_hz": 70.0, "tom_decay": 6.0, "click": "....x..."},
		},
	},
}

## Partitura de un pais ("ussr", "germany", "uk", "usa", "japan").
static func score(country: String) -> Dictionary:
	assert(SCORES.has(country), "Sin partitura para " + country)
	return SCORES[country]
