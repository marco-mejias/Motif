extends PanelContainer

# Emotional keyboard of the phone: six kalimba tines.
# Left = low / heavy (long tines), right = high / light (short tines).

const KEY_LETTERS = ["A", "S", "D", "F", "G", "H"]
const KEY_HEIGHTS = [250, 236, 222, 208, 194, 180]
const KEY_IDLE := Color("2a2e48")
const KEY_RADIUS = 26

var keys: Dictionary = {}    # note_id -> Panel
var styles: Dictionary = {}  # note_id -> StyleBoxFlat
var letters: Dictionary = {} # note_id -> Label
var active_notes: Array = []
var key_tweens: Dictionary = {}
var shake_tween: Tween
var key_row: HBoxContainer

func _ready() -> void:
	add_theme_stylebox_override("panel", UIStyle.box(UIStyle.SURFACE))

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 52) # Room for the home bar
	add_child(margin)

	key_row = HBoxContainer.new()
	key_row.add_theme_constant_override("separation", 16)
	key_row.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(key_row)

	for note_id in 6:
		_build_key(note_id)

	# We connect to BOTH signals: when pressed and when released
	InputManager.note_played.connect(_on_key_pressed)
	InputManager.note_released.connect(_on_key_released)

func _build_key(note_id: int) -> void:
	var key = Panel.new()
	key.custom_minimum_size = Vector2(0, KEY_HEIGHTS[note_id])
	key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key.size_flags_vertical = Control.SIZE_SHRINK_END

	var sb = UIStyle.box(KEY_IDLE, KEY_RADIUS)
	sb.border_width_bottom = 10
	sb.border_color = Emotion.KEY_COLORS[note_id]
	sb.shadow_color = Color(Emotion.KEY_COLORS[note_id], 0.0)
	sb.shadow_size = 22
	key.add_theme_stylebox_override("panel", sb)

	# Small colored dot on top tells the emotion of the tine
	var dot = Panel.new()
	dot.add_theme_stylebox_override("panel", UIStyle.box(Emotion.KEY_COLORS[note_id], 9))
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.set_anchors_preset(Control.PRESET_CENTER_TOP)
	dot.offset_left = -9
	dot.offset_right = 9
	dot.offset_top = 22
	dot.offset_bottom = 40
	key.add_child(dot)

	# Physical key hint
	var letter = UIStyle.label(KEY_LETTERS[note_id], 24, UIStyle.TEXT_DIM, true)
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	letter.offset_left = -30
	letter.offset_right = 30
	letter.offset_top = -56
	letter.offset_bottom = -20
	key.add_child(letter)
	letters[note_id] = letter

	key.gui_input.connect(_on_key_gui_input.bind(note_id))
	key.resized.connect(func(): key.pivot_offset = Vector2(key.size.x / 2, key.size.y))
	key_row.add_child(key)
	keys[note_id] = key
	styles[note_id] = sb

# On-screen keys feed the same InputManager as the physical keyboard
func _on_key_gui_input(event: InputEvent, note_id: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			InputManager.press_note(note_id)
		else:
			InputManager.release_note(note_id)
		accept_event()

# 1. Called when the user presses the key down
func _on_key_pressed(note_id: int) -> void:
	if not keys.has(note_id):
		return
	if not note_id in active_notes:
		active_notes.append(note_id)

	# The tine sinks a little
	var t = create_tween()
	t.tween_property(keys[note_id], "scale", Vector2(0.96, 0.93), 0.06)
	_update_active_keys_color()

# 2. Called only when the user completely lifts the finger
func _on_key_released(note_id: int) -> void:
	if not keys.has(note_id):
		return
	active_notes.erase(note_id)

	var t = create_tween()
	t.tween_property(keys[note_id], "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_tween_key_color(note_id, KEY_IDLE, 0.0, 0.35)
	_update_active_keys_color()

# 3. Every held tine takes the color of the whole chord and glows
func _update_active_keys_color() -> void:
	if active_notes.is_empty():
		return
	var target_color = Emotion.chord_color(active_notes)
	for n_id in active_notes:
		_tween_key_color(n_id, target_color, 0.55, 0.2)

func _tween_key_color(note_id: int, target_color: Color, glow: float, duration: float) -> void:
	if key_tweens.has(note_id) and key_tweens[note_id].is_valid():
		key_tweens[note_id].kill()
	var sb: StyleBoxFlat = styles[note_id]
	var t = create_tween().set_parallel(true)
	t.tween_property(sb, "bg_color", target_color, duration).set_trans(Tween.TRANS_SINE)
	t.tween_property(sb, "shadow_color", Color(target_color if glow > 0.0 else sb.border_color, glow), duration)
	# The letter stays readable on light chords
	t.tween_property(letters[note_id], "modulate", Color(0.2, 0.2, 0.3) if target_color.get_luminance() > 0.45 else Color.WHITE, duration)
	key_tweens[note_id] = t

# 4. Wrong chord: the keyboard shakes and the played keys flash dark
func play_wrong_feedback(played_notes: Array) -> void:
	if shake_tween and shake_tween.is_valid():
		shake_tween.kill()
	shake_tween = create_tween()
	for offset in [-14.0, 12.0, -8.0, 6.0, -3.0, 0.0]:
		shake_tween.tween_property(key_row, "position:x", offset, 0.045)

	for note_id in played_notes:
		if keys.has(note_id):
			styles[note_id].bg_color = UIStyle.DANGER.darkened(0.3)
			_tween_key_color(note_id, KEY_IDLE, 0.0, 0.6)
