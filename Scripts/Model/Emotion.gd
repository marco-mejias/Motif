class_name Emotion
extends RefCounted

# Single source of truth for the emotional palette.
# Left [0,1] = weight / pain, center [2,3] = calm / doubt, right [4,5] = light / yes
const KEY_COLORS: Array[Color] = [
	Color("ff4d4d"), # 0: Rojo (Grave / Conflicto)
	Color("ff9933"), # 1: Naranja (Tensión)
	Color("ffcc00"), # 2: Amarillo (Transición)
	Color("33cc33"), # 3: Verde (Calma)
	Color("3399ff"), # 4: Azul (Cariño / Agudo)
	Color("cc33ff")  # 5: Morado (Luz / Extremo agudo)
]

const NEUTRAL_COLOR := Color("f4f4f4") # Messages without notes
const PASTEL_AMOUNT: float = 0.25

# Normalized RGB sum of the chord, softened with white for the lo-fi look.
static func chord_color(notes: Array) -> Color:
	if notes.is_empty():
		return NEUTRAL_COLOR

	var r = 0.0
	var g = 0.0
	var b = 0.0

	for note in notes:
		if note >= 0 and note < KEY_COLORS.size():
			r += KEY_COLORS[note].r
			g += KEY_COLORS[note].g
			b += KEY_COLORS[note].b

	# Normalize by the dominant channel so the mix never turns grey
	var max_val = max(r, max(g, b))
	if max_val <= 0.0:
		return NEUTRAL_COLOR

	var mixed_color = Color(r / max_val, g / max_val, b / max_val)
	return mixed_color.lerp(Color.WHITE, PASTEL_AMOUNT)
