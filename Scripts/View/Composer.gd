extends PanelContainer

# Input bar of the open chat.
# - Locked: the protagonist still can't speak.
# - Idle: nothing to answer, the keyboard only plays notes.
# - Waiting: the reply appears as a pale draft. Holding a chord fills the bar with its color
#   and the draft gains ink; when it is full the chord is sent.
# - Typing: the protagonist writes a line by himself (typewriter), then it is sent.

enum Mode { LOCKED, IDLE, WAITING, TYPING }

var mode: Mode = Mode.LOCKED
var draft_label: Label
var send_dot: Panel
var charge: float = 0.0
var charge_color: Color = UIStyle.PLAYER_NEUTRAL
var shake_tween: Tween
var type_tween: Tween
var draft_text: String = ""

const BAR_RADIUS = 40

func _ready() -> void:
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	custom_minimum_size.y = 120

	var margin = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 20)
	margin.add_child(hbox)

	draft_label = UIStyle.label("", 28, UIStyle.TEXT_DIM)
	draft_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	draft_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	draft_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	draft_label.custom_minimum_size.x = 10
	hbox.add_child(draft_label)

	send_dot = Panel.new()
	send_dot.custom_minimum_size = Vector2(64, 64)
	send_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	send_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(send_dot)

	set_locked()

func _process(_delta: float) -> void:
	if mode != Mode.WAITING:
		return

	var held: Array = InputManager.held_notes
	var target := 0.0
	if InputManager.is_answering and not held.is_empty() and not InputManager.charge_timer.is_stopped():
		target = 1.0 - InputManager.charge_timer.time_left / InputManager.charge_time
		charge_color = Emotion.chord_color(held)
	charge = target if target > charge else lerpf(charge, target, 0.25)

	# The draft gains ink as the chord charges
	var ink = UIStyle.text_on(charge_color) if charge > 0.5 else UIStyle.TEXT
	draft_label.add_theme_color_override("font_color", UIStyle.TEXT_DIM.lerp(ink, clampf(charge * 1.4, 0.0, 1.0)))
	send_dot.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.SURFACE_HI.lerp(charge_color, clampf(charge * 2.0, 0.0, 1.0)), 32))
	queue_redraw()

func _draw() -> void:
	var rect = Rect2(Vector2(16, 12), size - Vector2(32, 24))
	draw_style_box(UIStyle.box(UIStyle.SURFACE_HI, BAR_RADIUS), rect)
	if mode == Mode.WAITING and charge > 0.01:
		var fill = Rect2(rect.position, Vector2(max(rect.size.x * charge, BAR_RADIUS * 2), rect.size.y))
		draw_style_box(UIStyle.box(charge_color, BAR_RADIUS), fill)
	if mode == Mode.WAITING:
		# Dashed hint that something is expected
		var outline = UIStyle.box(Color.TRANSPARENT, BAR_RADIUS)
		outline.set_border_width_all(3)
		outline.border_color = charge_color.lerp(UIStyle.ACCENT, 0.5) if charge > 0.01 else Color(UIStyle.ACCENT, 0.35 + 0.25 * sin(Time.get_ticks_msec() / 300.0))
		draw_style_box(outline, rect)

func _set_text(text: String, color: Color) -> void:
	if type_tween and type_tween.is_valid():
		type_tween.kill()
	draft_label.text = text
	draft_label.visible_ratio = 1.0
	draft_label.add_theme_color_override("font_color", color)

func set_locked() -> void:
	mode = Mode.LOCKED
	_set_text("No sabes qué decir...", UIStyle.TEXT_DIM.darkened(0.3))
	send_dot.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.SURFACE, 32))
	queue_redraw()

func set_idle() -> void:
	mode = Mode.IDLE
	charge = 0.0
	_set_text("Escucha.", UIStyle.TEXT_DIM)
	send_dot.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.SURFACE, 32))
	queue_redraw()

func set_waiting(reply_text: String) -> void:
	mode = Mode.WAITING
	charge = 0.0
	charge_color = UIStyle.PLAYER_NEUTRAL
	draft_text = reply_text if reply_text != "" else "..."
	_set_text(draft_text, UIStyle.TEXT_DIM)

# The protagonist writes a line on his own
func typewrite(text: String, duration: float) -> void:
	mode = Mode.TYPING
	_set_text(text, UIStyle.TEXT)
	draft_label.visible_ratio = 0.0
	type_tween = create_tween()
	type_tween.tween_property(draft_label, "visible_ratio", 1.0, max(duration * 0.75, 0.1))
	queue_redraw()

# Wrong chord: the bar shakes and blinks red
func play_wrong() -> void:
	charge = 0.0
	charge_color = UIStyle.DANGER
	if shake_tween and shake_tween.is_valid():
		shake_tween.kill()
	shake_tween = create_tween()
	for offset in [-16.0, 14.0, -10.0, 8.0, -4.0, 0.0]:
		shake_tween.tween_property(margin_node(), "position:x", offset, 0.045)
	shake_tween.tween_callback(func(): charge_color = UIStyle.PLAYER_NEUTRAL)

func margin_node() -> Control:
	return get_child(0)

# Message leaves the bar
func play_sent() -> void:
	var t = create_tween()
	draft_label.pivot_offset = Vector2(0, draft_label.size.y / 2)
	t.tween_property(draft_label, "modulate:a", 0.0, 0.15)
	t.tween_callback(func(): draft_label.modulate.a = 1.0)
