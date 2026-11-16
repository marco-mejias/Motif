class_name UIStyle
extends RefCounted

# Night lo-fi palette shared by every screen of the phone
const SCREEN_BG := Color("12131f")
const SURFACE := Color("1b1d2e")       # Headers, composer, keyboard
const SURFACE_HI := Color("25283d")    # Rows hover, neutral NPC bubbles
const PLAYER_NEUTRAL := Color("3b3f6b") # Protagonist bubble without notes
const BEZEL := Color("0a0a0f")
const BEZEL_EDGE := Color("2c2e3d")
const TEXT := Color("eceaf6")
const TEXT_DIM := Color("8d8fa8")
const TEXT_DARK := Color("1b1b26")
const ACCENT := Color("8be9b5")        # Unread badges, online dot
const DANGER := Color("ff6b7a")

static func box(color: Color, radius: int = 0, margin: float = 0.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	sb.anti_aliasing = true
	return sb

static func bold_font() -> FontVariation:
	var f := FontVariation.new()
	f.base_font = ThemeDB.fallback_font
	f.variation_embolden = 0.7
	return f

# Dark text on light bubbles, light text on dark ones
static func text_on(bg: Color) -> Color:
	return TEXT_DARK if bg.get_luminance() > 0.45 else TEXT

static func label(text: String, size: int, color: Color = TEXT, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", bold_font())
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

# Round avatar with the contact's initial
static func avatar(character: String, diameter: int) -> PanelContainer:
	var color := Contacts.color_of_character(character)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(diameter, diameter)
	p.add_theme_stylebox_override("panel", box(color, diameter / 2))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(character.substr(0, 1).to_upper(), int(diameter * 0.45), text_on(color), true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p
