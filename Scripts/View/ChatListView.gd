extends VBoxContainer

# Home screen of the phone: one row per unlocked voice, most recent first

signal chat_selected(chat_id: String)

var rows_box: VBoxContainer
var subtitle: Label
var rows: Dictionary = {} # chat_id -> { button, preview, time, badge, badge_label }

func _ready() -> void:
	add_theme_constant_override("separation", 0)

	# Title
	var title_margin = MarginContainer.new()
	for side in ["left", "right"]:
		title_margin.add_theme_constant_override("margin_" + side, 44)
	title_margin.add_theme_constant_override("margin_top", 26)
	title_margin.add_theme_constant_override("margin_bottom", 22)
	add_child(title_margin)

	var title_box = VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 2)
	title_margin.add_child(title_box)
	title_box.add_child(UIStyle.label("Chats", 64, UIStyle.TEXT, true))
	subtitle = UIStyle.label("No puedes dormir.", 26, UIStyle.TEXT_DIM)
	title_box.add_child(subtitle)

	# Rows
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	rows_box = VBoxContainer.new()
	rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_box.add_theme_constant_override("separation", 4)
	scroll.add_child(rows_box)

func set_subtitle(text: String) -> void:
	subtitle.text = text

func add_chat(chat_id: String) -> void:
	if rows.has(chat_id):
		return
	var contact_name: String = Contacts.display_name(chat_id)

	var button = Button.new()
	button.custom_minimum_size.y = 136
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func(): chat_selected.emit(chat_id))

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 40)
	button.add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 26)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(hbox)

	var avatar = UIStyle.avatar(contact_name, 96)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(avatar)

	var text_box = VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.alignment = BoxContainer.ALIGNMENT_CENTER
	text_box.add_theme_constant_override("separation", 4)
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(text_box)

	text_box.add_child(UIStyle.label(contact_name, 34, UIStyle.TEXT, true))
	var preview = UIStyle.label("", 26, UIStyle.TEXT_DIM)
	preview.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	preview.custom_minimum_size.x = 10
	text_box.add_child(preview)

	var side_box = VBoxContainer.new()
	side_box.alignment = BoxContainer.ALIGNMENT_CENTER
	side_box.add_theme_constant_override("separation", 10)
	side_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(side_box)

	var time = UIStyle.label("", 22, UIStyle.TEXT_DIM)
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	side_box.add_child(time)

	var badge = PanelContainer.new()
	badge.custom_minimum_size = Vector2(44, 44)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_END
	badge.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.ACCENT, 22, 4))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_label = UIStyle.label("", 22, UIStyle.TEXT_DARK, true)
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(badge_label)
	badge.visible = false
	side_box.add_child(badge)

	rows_box.add_child(button)
	rows_box.move_child(button, 0)
	rows[chat_id] = { "button": button, "preview": preview, "time": time, "badge": badge, "badge_label": badge_label }

	# New voice: the row fades in
	button.modulate.a = 0.0
	create_tween().tween_property(button, "modulate:a", 1.0, 0.5)

func update_chat(chat_id: String, preview_text: String, time_text: String, unread: int, typing: bool = false) -> void:
	if not rows.has(chat_id):
		add_chat(chat_id)
	var row = rows[chat_id]

	if typing:
		row.preview.text = "escribiendo..."
		row.preview.add_theme_color_override("font_color", UIStyle.ACCENT)
	else:
		row.preview.text = preview_text
		row.preview.add_theme_color_override("font_color", UIStyle.TEXT if unread > 0 else UIStyle.TEXT_DIM)
	if time_text != "":
		row.time.text = time_text
	row.time.add_theme_color_override("font_color", UIStyle.ACCENT if unread > 0 else UIStyle.TEXT_DIM)

	var had_badge: bool = row.badge.visible
	row.badge.visible = unread > 0
	row.badge_label.text = str(unread)
	if unread > 0 and not had_badge:
		row.badge.pivot_offset = row.badge.custom_minimum_size / 2
		row.badge.scale = Vector2.ZERO
		create_tween().tween_property(row.badge, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# The chat with the newest message goes first
func bump_to_top(chat_id: String) -> void:
	if rows.has(chat_id):
		rows_box.move_child(rows[chat_id].button, 0)
