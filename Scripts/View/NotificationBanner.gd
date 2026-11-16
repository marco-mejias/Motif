extends PanelContainer

# Banner that drops from the top of the screen when a voice writes in another chat

signal tapped(chat_id: String)

const SHOW_TIME: float = 2.8
const HIDDEN_Y: float = -220.0
const SHOWN_Y: float = 96.0

var chat_id: String = ""
var avatar_holder: CenterContainer
var title_label: Label
var body_label: Label
var hide_timer: Timer
var slide_tween: Tween

func _ready() -> void:
	var sb = UIStyle.box(Color(UIStyle.SURFACE_HI, 0.97), 34, 0)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 24
	sb.shadow_offset = Vector2(0, 8)
	add_theme_stylebox_override("panel", sb)

	var margin = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 20)
	margin.add_child(hbox)

	avatar_holder = CenterContainer.new()
	avatar_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(avatar_holder)

	var text_box = VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_theme_constant_override("separation", 2)
	hbox.add_child(text_box)

	title_label = UIStyle.label("", 28, UIStyle.TEXT, true)
	text_box.add_child(title_label)
	body_label = UIStyle.label("", 26, UIStyle.TEXT_DIM)
	body_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	body_label.custom_minimum_size.x = 10
	text_box.add_child(body_label)

	hide_timer = Timer.new()
	hide_timer.one_shot = true
	hide_timer.timeout.connect(hide_banner)
	add_child(hide_timer)

	gui_input.connect(_on_gui_input)
	position.y = HIDDEN_Y
	visible = false

func show_message(new_chat_id: String, speaker: String, text: String) -> void:
	chat_id = new_chat_id
	var chat_name = Contacts.display_name(chat_id)
	title_label.text = chat_name if speaker == chat_name else speaker + " · " + chat_name
	body_label.text = text
	for child in avatar_holder.get_children():
		child.queue_free()
	avatar_holder.add_child(UIStyle.avatar(speaker, 64))

	visible = true
	_slide_to(SHOWN_Y, 0.35)
	hide_timer.start(SHOW_TIME)

func hide_banner() -> void:
	_slide_to(HIDDEN_Y, 0.3)

func _slide_to(y: float, duration: float) -> void:
	if slide_tween and slide_tween.is_valid():
		slide_tween.kill()
	slide_tween = create_tween()
	slide_tween.tween_property(self, "position:y", y, duration).set_trans(Tween.TRANS_BACK if y > 0 else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if y < 0:
		slide_tween.tween_callback(func(): visible = false)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hide_banner()
		tapped.emit(chat_id)
		accept_event()
