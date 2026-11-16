extends Node

signal waiting_answer(chat_id: String, expected_notes: Array, reply_text: String) # A chat is waiting for the player's chord
signal new_chat(chat_id: String, start_title: String) # Unlock a chat (or resume an idle one from a new title)
signal show_keyboard
signal participant_joined(chat_id: String, character: String)
signal participant_left(chat_id: String, character: String)

# Chat whose dialogue is being read right now. Main sets it around every
# DialogueManager call, so the functions below know which chat called them.
var active_chat: String = ""

# chat_id -> { expected: Array, next: String }
var _pending_requests: Dictionary = {}

# Dialogue Manager calls this to wait for the response of the player. Until then, he doesnt input more text.
# The line right after this call in the .dialogue is the protagonist's reply: it stays hidden until the chord is right.
func wait_response(notes: Array, next_title: String) -> void:
	_pending_requests[active_chat] = { "expected": notes, "next": next_title }
	print("El diálogo de '", active_chat, "' se pausa. Esperando que el jugador toque: ", notes)

# Used by Main right after reading a line
func take_request(chat_id: String) -> Dictionary:
	var request: Dictionary = _pending_requests.get(chat_id, {})
	_pending_requests.erase(chat_id)
	return request

# Unlock new chats from .dialogue. By default the chat starts at "<chat_id>_1".
# Calling it on an already finished chat makes that chat continue from start_title.
func unlock_chat(chat_id: String, start_title: String = "") -> void:
	if start_title == "":
		start_title = chat_id + "_1"
	new_chat.emit(chat_id, start_title)

func unlock_keyboard():
	show_keyboard.emit()

# Someone enters / leaves the chat that is currently being read.
# Speaking in a chat also makes a character join automatically.
func join_chat(character: String) -> void:
	participant_joined.emit(active_chat, character)

func leave_chat(character: String) -> void:
	participant_left.emit(active_chat, character)
