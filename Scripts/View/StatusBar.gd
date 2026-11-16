extends HBoxContainer

# Phone status bar: clock on the left, signal + a nearly dead battery on the right

var time_label: Label
var battery_fill: Panel
var battery_level: float = 0.14

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 14)

	var left_pad = Control.new()
	left_pad.custom_minimum_size.x = 56
	add_child(left_pad)

	time_label = UIStyle.label("5:02", 30, UIStyle.TEXT, true)
	time_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(time_label)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(spacer)

	var net = UIStyle.label("4G", 24, UIStyle.TEXT, true)
	net.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(net)

	add_child(_build_battery())

	var right_pad = Control.new()
	right_pad.custom_minimum_size.x = 50
	add_child(right_pad)

func _build_battery() -> Control:
	var holder = HBoxContainer.new()
	holder.add_theme_constant_override("separation", 2)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var body = Panel.new()
	body.custom_minimum_size = Vector2(52, 26)
	var outline = UIStyle.box(Color.TRANSPARENT, 7)
	outline.set_border_width_all(3)
	outline.border_color = UIStyle.TEXT.darkened(0.2)
	body.add_theme_stylebox_override("panel", outline)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(body)

	battery_fill = Panel.new()
	battery_fill.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.DANGER, 3))
	battery_fill.position = Vector2(6, 6)
	battery_fill.size = Vector2((52 - 12) * battery_level, 14)
	battery_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(battery_fill)

	var tip = Panel.new()
	tip.custom_minimum_size = Vector2(4, 10)
	tip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tip.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.TEXT.darkened(0.2), 2))
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(tip)
	return holder

func set_time(text: String) -> void:
	if time_label:
		time_label.text = text

# The battery drains as the night goes on
func set_battery(value: float) -> void:
	battery_level = clampf(value, 0.02, 1.0)
	if battery_fill:
		battery_fill.size.x = (52 - 12) * battery_level
