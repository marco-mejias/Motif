class_name Contacts
extends RefCounted

# Every voice that can own a chat or join one.
# chat_id -> { name: shown in the UI and used as Dialogue Manager character, color }
const DATA: Dictionary = {
	"diver": { "name": "Diver", "color": Color("ff9933") },
	"poker": { "name": "Poker", "color": Color("33cc33") },
	"robot": { "name": "Robot", "color": Color("ff4d4d") },
	"blind": { "name": "Blind", "color": Color("3399ff") },
	"astro": { "name": "Astro", "color": Color("cc33ff") },
	"chica": { "name": "Chica", "color": Color("ffcc00") },
	"paper": { "name": "Paper", "color": Color("dddddd") },
}

const PLAYER_NAME: String = "Prota"
const DEFAULT_COLOR := Color("bbbbbb")

static func display_name(chat_id: String) -> String:
	if DATA.has(chat_id):
		return DATA[chat_id]["name"]
	return chat_id.capitalize()

# Characters that are not contacts (or unknown names) still get a neutral color
static func color_of_character(character: String) -> Color:
	for chat_id in DATA:
		if DATA[chat_id]["name"] == character:
			return DATA[chat_id]["color"]
	return DEFAULT_COLOR
