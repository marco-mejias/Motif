extends Control

# A preserved emotion: born from a held bubble, it floats over the scene.
# - Tap: plays its chord, takes the chord's color and glows.
# - Drag: move it anywhere on screen.
# - Double click / right click: rename it.

@onready var sprite: TextureRect = $Sprite
@onready var glow: Panel = $Glow # Soft halo behind the cloud
@onready var dots: HBoxContainer = $Dots
@onready var line_edit: LineEdit = $LineEdit

const DRAG_THRESHOLD: float = 12.0
const REST_COLOR := Color(0.94, 0.93, 1.0)

var notes: Array = []
var chord_color: Color = REST_COLOR
var heard: bool = false # Turns to its chord color the first time it is touched

# Interaction variables
var pressing: bool = false
var dragging: bool = false
var press_pos: Vector2
var drag_offset: Vector2
var drag_velocity: float = 0.0
var is_spawning: bool = false # Prevents floating movement while spawning

# Floating
var rest_pos: Vector2
var float_time: float = 0.0
var floating_vel: float = 1.0
var mov_x: float = 6.0
var mov_y: float = 10.0

var scale_tween: Tween
var color_tween: Tween

func _ready() -> void:
	pivot_offset = size / 2
	sprite.modulate = REST_COLOR
	glow.modulate = Color(1, 1, 1, 0)
	glow.pivot_offset = glow.size / 2
	_set_glow_color(REST_COLOR)
	rest_pos = position
	float_time = randf() * TAU

	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	line_edit.focus_exited.connect(_end_rename)
	line_edit.text_submitted.connect(func(_t): line_edit.release_focus())

func _process(delta: float) -> void:
	# Ignore normal floating if we are dragging, pressing or spawning
	if dragging or pressing or is_spawning:
		return
	float_time += delta * floating_vel
	position = rest_pos + _float_offset()

func _float_offset() -> Vector2:
	return Vector2(sin(float_time * 1.1) * mov_x, cos(float_time * 0.8) * mov_y)

# -------------------------------------------------------------
# INPUT
# -------------------------------------------------------------
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_start_rename()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if event.double_click:
					_start_rename()
				else:
					pressing = true
					press_pos = get_global_mouse_position()
					drag_offset = global_position - press_pos
					_tween_scale(Vector2(0.93, 0.93), 0.08)
			else:
				if dragging:
					_drop()
				elif pressing:
					_tap()
				pressing = false
				dragging = false
			accept_event()

	elif event is InputEventMouseMotion and pressing:
		var mouse = get_global_mouse_position()
		if not dragging and mouse.distance_to(press_pos) > DRAG_THRESHOLD:
			_start_drag()
		if dragging:
			global_position = _clamp_to_screen(mouse + drag_offset)
			# Leans into the movement
			drag_velocity = lerpf(drag_velocity, event.relative.x, 0.3)
			rotation = clampf(drag_velocity * 0.012, -0.3, 0.3)
		accept_event()

func _on_hover(inside: bool) -> void:
	if dragging or pressing or is_spawning:
		return
	_tween_scale(Vector2(1.06, 1.06) if inside else Vector2.ONE, 0.15)

# -------------------------------------------------------------
# TAP: listen to the emotion
# -------------------------------------------------------------
func _tap() -> void:
	AudioManager.play_chord(notes)

	if not heard:
		heard = true
		_reveal_color()

	# Squash & stretch
	if scale_tween and scale_tween.is_valid():
		scale_tween.kill()
	scale_tween = create_tween()
	scale_tween.tween_property(self, "scale", Vector2(1.18, 0.86), 0.07)
	scale_tween.tween_property(self, "scale", Vector2(0.94, 1.08), 0.09)
	scale_tween.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	# Flash of light in its color
	if color_tween and color_tween.is_valid():
		color_tween.kill()
	sprite.modulate = chord_color.lightened(0.55)
	_set_glow_color(chord_color)
	glow.modulate = Color(1, 1, 1, 1)
	glow.scale = Vector2.ONE
	color_tween = create_tween().set_parallel(true)
	color_tween.tween_property(sprite, "modulate", chord_color, 0.5).set_trans(Tween.TRANS_SINE)
	color_tween.tween_property(glow, "modulate:a", 0.0, 0.9).set_trans(Tween.TRANS_SINE)
	color_tween.tween_property(glow, "scale", Vector2(1.3, 1.3), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_burst_notes()

func _set_glow_color(color: Color) -> void:
	var sb = UIStyle.box(Color(color, 0.35), 80)
	sb.shadow_color = Color(color, 0.7)
	sb.shadow_size = 70
	glow.add_theme_stylebox_override("panel", sb)

# First touch: the cloud turns into its emotion
func _reveal_color() -> void:
	var ink = UIStyle.text_on(chord_color)
	line_edit.add_theme_color_override("font_color", ink)
	line_edit.add_theme_color_override("font_placeholder_color", Color(ink, 0.45))
	line_edit.add_theme_color_override("caret_color", ink)

	for i in dots.get_child_count():
		var dot = dots.get_child(i)
		dot.visible = true
		dot.pivot_offset = dot.custom_minimum_size / 2
		dot.scale = Vector2.ZERO
		var t = create_tween()
		t.tween_interval(0.06 * i)
		t.tween_property(dot, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# Little notes fly out of the cloud, one per key of the chord
func _burst_notes() -> void:
	var layer = get_parent()
	var center = position + size / 2
	for i in notes.size():
		var note = notes[i]
		if note < 0 or note >= Emotion.KEY_COLORS.size():
			continue
		var p = Panel.new()
		p.size = Vector2(22, 22)
		p.pivot_offset = p.size / 2
		p.add_theme_stylebox_override("panel", UIStyle.box(Emotion.KEY_COLORS[note], 11))
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.position = center - p.size / 2
		layer.add_child(p)
		var angle = lerpf(-2.4, -0.7, (i + 0.5) / max(notes.size(), 1)) + randf_range(-0.15, 0.15)
		var target = p.position + Vector2(cos(angle), sin(angle)) * randf_range(110, 170)
		var t = p.create_tween().set_parallel(true)
		t.tween_property(p, "position", target, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(p, "scale", Vector2(0.3, 0.3), 0.7)
		t.tween_property(p, "modulate:a", 0.0, 0.7).set_delay(0.15)
		t.chain().tween_callback(p.queue_free)

# -------------------------------------------------------------
# DRAG
# -------------------------------------------------------------
func _start_drag() -> void:
	dragging = true
	move_to_front()
	_tween_scale(Vector2(1.12, 1.12), 0.12)
	var t = create_tween()
	t.tween_property(sprite, "self_modulate", Color(1.15, 1.15, 1.15), 0.12)

func _drop() -> void:
	dragging = false
	rest_pos = position - _float_offset()
	drag_velocity = 0.0
	if scale_tween and scale_tween.is_valid():
		scale_tween.kill()
	scale_tween = create_tween().set_parallel(true)
	scale_tween.tween_property(self, "rotation", 0.0, 0.3).set_trans(Tween.TRANS_BACK)
	scale_tween.tween_property(sprite, "self_modulate", Color.WHITE, 0.2)
	var squash = create_tween()
	squash.tween_property(self, "scale", Vector2(1.1, 0.9), 0.08)
	squash.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

# Keeps at least part of the cloud visible
func _clamp_to_screen(pos: Vector2) -> Vector2:
	var area: Vector2 = get_parent().size if get_parent() is Control else get_viewport_rect().size
	return Vector2(
		clampf(pos.x, -size.x * 0.3, area.x - size.x * 0.7),
		clampf(pos.y, -size.y * 0.2, area.y - size.y * 0.8))

func _tween_scale(target: Vector2, duration: float) -> void:
	if scale_tween and scale_tween.is_valid():
		scale_tween.kill()
	scale_tween = create_tween()
	scale_tween.tween_property(self, "scale", target, duration).set_trans(Tween.TRANS_SINE)

# -------------------------------------------------------------
# RENAME
# -------------------------------------------------------------
func _start_rename() -> void:
	pressing = false
	line_edit.mouse_filter = Control.MOUSE_FILTER_STOP
	line_edit.grab_focus()
	line_edit.select_all()

func _end_rename() -> void:
	line_edit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line_edit.deselect()

# -------------------------------------------------------------
# SPAWN (from a held bubble)
# -------------------------------------------------------------
func spawn_from_bubble(spawn_pos: Vector2, notes_to_copy: Array = []) -> void:
	notes = notes_to_copy
	chord_color = Emotion.chord_color(notes) if not notes.is_empty() else REST_COLOR.darkened(0.15)

	# Note dots stay hidden until the cloud is heard
	for note in notes:
		if note < 0 or note >= Emotion.KEY_COLORS.size():
			continue
		var dot = Panel.new()
		dot.custom_minimum_size = Vector2(20, 20)
		var sb = UIStyle.box(Emotion.KEY_COLORS[note], 10)
		sb.set_border_width_all(2)
		sb.border_color = Color(UIStyle.TEXT_DARK, 0.4)
		dot.add_theme_stylebox_override("panel", sb)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.visible = false
		dots.add_child(dot)

	is_spawning = true
	position = spawn_pos - size / 2
	scale = Vector2.ZERO

	# It drifts out of the phone into the sky when there is room, otherwise just up and to the right
	var end_pos = _clamp_to_screen(position + Vector2(randf_range(200, 300), randf_range(-180, -60)))
	var phone = get_tree().get_first_node_in_group("phone")
	var area: Vector2 = get_parent().size if get_parent() is Control else get_viewport_rect().size
	if phone:
		var phone_rect: Rect2 = phone.get_global_rect()
		var right_room = area.x - phone_rect.end.x
		var left_room = phone_rect.position.x
		var y = clampf(position.y + randf_range(-200, 120), 40.0, area.y - size.y - 200.0)
		if right_room > size.x + 60:
			end_pos = Vector2(phone_rect.end.x + randf_range(40, minf(right_room - size.x - 20, 420)), y)
		elif left_room > size.x + 60:
			end_pos = Vector2(phone_rect.position.x - size.x - randf_range(40, minf(left_room - size.x - 20, 420)), y)
	var cloud_tween = create_tween().set_parallel(true)
	cloud_tween.tween_property(self, "position", end_pos, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	cloud_tween.tween_property(self, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	# When animation finishes, save its actual position and let it float
	cloud_tween.chain().tween_callback(_on_spawn_finished)

func _on_spawn_finished() -> void:
	is_spawning = false
	float_time = 0.0
	rest_pos = position - _float_offset()
