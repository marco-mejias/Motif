extends PanelContainer

@onready var textLabel = $MarginContainer/RichTextLabel

func configMsg(text: String, is_npc: bool):
	textLabel.text = text
	var style = get_theme_stylebox("panel").duplicate()
	
	if is_npc:
		#NPC MSG: Gray, on the left
		style.bg_color = Color("e5e5ea")
		textLabel.add_theme_color_override("default_color", Color.BLACK)
		self.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	else:
		#User MSG: Green, on the right
		style.bg_color = Color("dcf8c6")
		textLabel.add_theme_color_override("default_color", Color.BLACK)
		self.size_flags_horizontal = Control.SIZE_SHRINK_END
		
	add_theme_stylebox_override("panel", style)
