extends PanelContainer

@onready var textLabel: Label = $MarginContainer/VBox/TextLabel
@onready var nameLabel: Label = $MarginContainer/VBox/NameLabel
@onready var dotsBox: HBoxContainer = $MarginContainer/VBox/Footer/Dots
@onready var timeLabel: Label = $MarginContainer/VBox/Footer/TimeLabel
@onready var anim_player = $AnimationPlayer

var notes: Array = [] # Container for note pattern of msg
var is_npc: bool = true
var timer: Timer # Timer to count the time pressed on each note and activate the cloud
var pressed: bool = false
var time_to_bubble: float = 0.8
var anaconda_tween: Tween # Tween for the hold animation

const CLOUD_SCENE = preload("res://Cloud.tscn")
const RADIUS = 30
const TAIL_RADIUS = 8
const BULGE_SIZE = 0.12

func _ready():
	timer = Timer.new()
	timer.one_shot = true # Timer stops at the end
	timer.timeout.connect(_create_cloud)
	add_child(timer)

	gui_input.connect(_when_input) # We connect for local inputs in the bubble message

# speaker: shown above the text only in chats with more than one voice
func configMsg(text: String, npc: bool, notesAct: Array, speaker: String = "", time_text: String = "", max_width: float = 560.0):
	# 1. We save the data
	notes = notesAct
	is_npc = npc
	textLabel.text = text
	timeLabel.text = time_text

	# 2. Colors: chords tint the bubble, plain messages stay dark
	var tint_color: Color
	if notes.is_empty():
		tint_color = UIStyle.SURFACE_HI if is_npc else UIStyle.PLAYER_NEUTRAL
	else:
		tint_color = Emotion.chord_color(notes)
		if is_npc:
			tint_color = tint_color.darkened(0.05)
	var ink = UIStyle.text_on(tint_color)
	textLabel.add_theme_color_override("font_color", ink)
	timeLabel.add_theme_color_override("font_color", Color(ink, 0.55))

	nameLabel.visible = speaker != ""
	if speaker != "":
		nameLabel.text = speaker
		nameLabel.add_theme_font_override("font", UIStyle.bold_font())
		var name_color = Contacts.color_of_character(speaker)
		nameLabel.add_theme_color_override("font_color", name_color.darkened(0.45) if ink == UIStyle.TEXT_DARK else name_color.lightened(0.15))

	# 3. One small dot per note: the chord can be read at a glance
	for note in notes:
		if note >= 0 and note < Emotion.KEY_COLORS.size():
			var dot = Panel.new()
			dot.custom_minimum_size = Vector2(18, 18)
			var sb = UIStyle.box(Emotion.KEY_COLORS[note], 9)
			sb.border_color = Color(UIStyle.TEXT_DARK, 0.35)
			sb.set_border_width_all(2)
			dot.add_theme_stylebox_override("panel", sb)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			dotsBox.add_child(dot)

	# 4. Shape: rounded with a sharper corner on the speaker's side
	var style = UIStyle.box(tint_color, RADIUS)
	if is_npc:
		style.corner_radius_top_left = TAIL_RADIUS
		self.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	else:
		style.corner_radius_top_right = TAIL_RADIUS
		self.size_flags_horizontal = Control.SIZE_SHRINK_END
	add_theme_stylebox_override("panel", style)

	# 5. Width: as wide as the text, up to max_width, then it wraps
	var font = textLabel.get_theme_font("font")
	var font_size = textLabel.get_theme_font_size("font_size")
	var text_width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 4
	var inner_max = max_width - 52
	textLabel.custom_minimum_size.x = clampf(text_width, 90.0, inner_max)

func _when_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# If we continually press, the timer starts and the bubble deforms
			pressed = true
			timer.start(time_to_bubble)
			_start_anaconda_anim()
		else:
			# If released early, cancel animation and play music
			pressed = false
			if not timer.is_stopped():
				timer.stop()
				_cancel_anaconda_anim()
				_play_music()

func _set_bulge(value: float) -> void:
	material.set_shader_parameter("tamano_bulto", value)

func _start_anaconda_anim():
	if anaconda_tween and anaconda_tween.is_valid():
		anaconda_tween.kill()
	anaconda_tween = create_tween()
	anaconda_tween.tween_method(_set_bulge, 0.0, BULGE_SIZE, 0.15)
	anim_player.play("press_anim")

func _cancel_anaconda_anim():
	anim_player.stop()
	if anaconda_tween and anaconda_tween.is_valid():
		anaconda_tween.kill()
	_set_bulge(0.0)
	scale = Vector2.ONE # Resetea el tamaño si sueltas el clic a medias
	pivot_offset = size / 2

# New live messages pop in from the speaker's side
func animate_entrance() -> void:
	pivot_offset = Vector2(0.0 if is_npc else size.x, size.y)
	scale = Vector2(0.7, 0.7)
	modulate.a = 0.0
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.18)

# Correct chord: the sent bubble flashes white and settles into its color
func flash() -> void:
	modulate = Color(1.6, 1.6, 1.6)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.6).set_trans(Tween.TRANS_SINE)

func _play_music():
	# Little bounce so the tap feels heard
	pivot_offset = size / 2
	var t = create_tween()
	t.tween_property(self, "scale", Vector2(1.04, 1.04), 0.06)
	t.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)
	AudioManager.play_chord(notes)

func _create_cloud() -> void:
	_set_bulge(0.0)
	# The bulge reached the right side. We spit the cloud.
	pivot_offset = size / 2
	var spit_tween = create_tween()
	spit_tween.tween_property(self, "scale", Vector2(0.92, 1.1), 0.1)
	spit_tween.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC)

	# We instantiate the cloud and let it handle its own spawn animation
	# Clouds live in their own layer above the phone, so they can be dragged anywhere
	var new_cloud = CLOUD_SCENE.instantiate()
	var layer = get_tree().get_first_node_in_group("cloud_layer")
	(layer if layer else get_tree().current_scene).add_child(new_cloud)

	var spawn_pos = global_position + Vector2(size.x, size.y / 2)
	new_cloud.spawn_from_bubble(spawn_pos, notes) #We need to send the notes too
