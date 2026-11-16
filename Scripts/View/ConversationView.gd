extends VBoxContainer

# Open chat screen: header (back, avatar, name, status) + messages + composer + keyboard

signal back_pressed

@export var header: PanelContainer
@export var chat_area: PanelContainer

var avatar_holder: Control
var name_label: Label
var status_label: Label
var bottom_pad: Control

func _ready() -> void:
	add_theme_constant_override("separation", 0)
	header.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.SURFACE, 0, 0))
	chat_area.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.SCREEN_BG))

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 18)
	header.add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	margin.add_child(hbox)

	var back = Button.new()
	back.text = "‹"
	back.focus_mode = Control.FOCUS_NONE
	back.custom_minimum_size = Vector2(84, 84)
	back.add_theme_font_size_override("font_size", 72)
	back.pressed.connect(func(): back_pressed.emit())
	hbox.add_child(back)

	avatar_holder = CenterContainer.new()
	avatar_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(avatar_holder)

	var text_box = VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.alignment = BoxContainer.ALIGNMENT_CENTER
	text_box.add_theme_constant_override("separation", 0)
	hbox.add_child(text_box)

	name_label = UIStyle.label("", 34, UIStyle.TEXT, true)
	text_box.add_child(name_label)
	status_label = UIStyle.label("", 24, UIStyle.TEXT_DIM)
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_label.custom_minimum_size.x = 10
	text_box.add_child(status_label)
	
	# Room for the home bar while the keyboard is not there
	bottom_pad = Control.new()
	bottom_pad.custom_minimum_size.y = 44
	bottom_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom_pad)

func set_bottom_pad(value: bool) -> void:
	bottom_pad.visible = value

func show_chat(chat_id: String) -> void:
	var contact_name = Contacts.display_name(chat_id)
	name_label.text = contact_name
	for child in avatar_holder.get_children():
		child.queue_free()
	avatar_holder.add_child(UIStyle.avatar(contact_name, 76))

# "en línea", "Diver está escribiendo...", or the group members
func set_status(text: String, highlight: bool = false) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", UIStyle.ACCENT if highlight else UIStyle.TEXT_DIM)
