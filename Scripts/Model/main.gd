extends Control

@onready var phone: Control = $Phone
@onready var pages: Control = $Phone/Screen/Pages
@onready var chat_list = $Phone/Screen/Pages/ChatList
@onready var conversation = $Phone/Screen/Pages/Conversation
@onready var app_chat = $Phone/Screen/Pages/Conversation/ChatArea/AppChat
@onready var composer = $Phone/Screen/Pages/Conversation/Composer
@onready var keyboard = $Phone/Screen/Pages/Conversation/Keyboard
@onready var status_bar = $Phone/Screen/StatusBar
@onready var banner = $Phone/Screen/Notification
@onready var scenery = $Scenery
@onready var conversation_controller: Node = $ConversationController

const DIALOGUE_HISTORY = preload("res://Dialogue/chat_dialogue.dialogue")
const FIRST_CHAT: String = "diver"
const START_MINUTES: float = 5 * 60 + 2  # 5:02 AM
const MINUTES_PER_MESSAGE: float = 0.5
const MESSAGES_TO_DAWN: float = 260.0   # Messages until the sky is almost light

# Every unlocked chat lives here and keeps running even when it is not on screen.
# chat_id -> {
#   next: String       -> dialogue title/id to read next ("" when idle or finished)
#   running: bool      -> a reading loop is active for this chat
#   pending: Dictionary -> { expected, next, reply_line, reply_text } while waiting for the player's chord
#   unread: int
# }
var chats: Dictionary = {}
var keyboard_unlocked: bool = false
var on_home: bool = true
var open_chat_id: String = ""
var game_minutes: float = START_MINUTES
var total_messages: int = 0

var page_tween: Tween
var buzz_tween: Tween
var composer_state: String = ""

# DialogueManager runs the .dialogue mutations across frames, so only one chat
# reads at a time. That way GameEvents.active_chat always points to the right chat.
var _fetching: bool = false
signal _fetch_released


func _ready() -> void:
	_style_phone()

	# 1. Connect input and game events
	InputManager.submit_notes.connect(_on_chord_submitted)
	GameEvents.new_chat.connect(_on_new_chat)
	GameEvents.show_keyboard.connect(_on_show_keyboard)
	GameEvents.participant_joined.connect(_on_participant_changed.bind(true))
	GameEvents.participant_left.connect(_on_participant_changed.bind(false))
	app_chat.message_added.connect(_on_message_added)
	app_chat.typing_changed.connect(_on_typing_changed)
	app_chat.clock_text = _clock_text
	chat_list.chat_selected.connect(open_chat)
	conversation.back_pressed.connect(go_home)
	banner.tapped.connect(open_chat)

	# 2. Initial UI state: home screen, no keyboard yet
	keyboard.visible = false
	conversation.set_bottom_pad(true)
	composer.set_locked()
	status_bar.set_time(_clock_text())
	_update_home_subtitle()
	await get_tree().process_frame
	conversation.position.x = pages.size.x
	conversation.visible = false
	_intro_animation()

	# 3. Start the first chat automatically
	await get_tree().create_timer(0.8).timeout
	GameEvents.unlock_chat(FIRST_CHAT)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not on_home:
		go_home()


# -------------------------------------------------------------
# NAVIGATION (home screen <-> conversation)
# -------------------------------------------------------------
func open_chat(chat_id: String) -> void:
	if not chats.has(chat_id) or (not on_home and open_chat_id == chat_id):
		return
	var from_home = on_home
	on_home = false
	if banner.chat_id == chat_id:
		banner.hide_banner()
	open_chat_id = chat_id

	app_chat.switch_chat(chat_id)
	conversation.show_chat(chat_id)
	chats[chat_id].unread = 0
	_update_row(chat_id)
	_refresh_header_status()
	_refresh_answer_state(true)
	AudioManager.play_sfx("open", -14.0)

	conversation.visible = true
	if from_home:
		_slide_conversation(0.0)
	else:
		# Jumping from one chat to another (notification): quick fade
		conversation.modulate.a = 0.4
		create_tween().tween_property(conversation, "modulate:a", 1.0, 0.2)


func go_home() -> void:
	if on_home:
		return
	on_home = true
	open_chat_id = ""
	app_chat.current_chat_id = "" # Messages arriving now count as unread
	banner.hide_banner()
	InputManager.set_answering(false)
	AudioManager.play_sfx("back", -14.0)
	_slide_conversation(pages.size.x)


func _slide_conversation(target_x: float) -> void:
	if page_tween and page_tween.is_valid():
		page_tween.kill()
	page_tween = create_tween().set_parallel(true)
	page_tween.tween_property(conversation, "position:x", target_x, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# The list behind moves a bit, like real phones
	page_tween.tween_property(chat_list, "position:x", -pages.size.x * 0.25 if target_x == 0.0 else 0.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	page_tween.tween_property(chat_list, "modulate", Color(0.6, 0.6, 0.7) if target_x == 0.0 else Color.WHITE, 0.32)
	if target_x > 0.0:
		page_tween.chain().tween_callback(func(): conversation.visible = false)


# -------------------------------------------------------------
# CHATS
# -------------------------------------------------------------
# Unlocks a contact, or makes an idle chat continue from start_title
func _on_new_chat(chat_id: String, start_title: String) -> void:
	if chats.has(chat_id):
		var chat = chats[chat_id]
		if not chat.running and chat.pending.is_empty():
			chat.next = start_title
			_run_chat(chat_id)
		return

	chats[chat_id] = { "next": start_title, "running": false, "pending": {}, "unread": 0 }
	app_chat.register_chat(chat_id)
	chat_list.add_chat(chat_id)
	_update_row(chat_id)
	AudioManager.play_sfx("unlock", -12.0)
	_update_home_subtitle()
	_run_chat(chat_id)


# Reads the dialogue of one chat and delivers its lines until it ends or waits for the player
func _run_chat(chat_id: String) -> void:
	var chat = chats[chat_id]
	if chat.running or not chat.pending.is_empty():
		return
	chat.running = true

	while chat.next != "":
		var line = await _fetch_line(chat_id, chat.next)
		var request: Dictionary = GameEvents.take_request(chat_id)

		if not request.is_empty():
			# The line after wait_response is the protagonist's reply: hold it until the chord is right
			request["reply_line"] = line
			request["reply_text"] = app_chat.parse_line(line)["text"] if line else ""
			chat.pending = request
			chat.next = ""
			_update_row(chat_id)
			if chat_id == open_chat_id:
				_refresh_answer_state()
			GameEvents.waiting_answer.emit(chat_id, request.expected, request.reply_text)
			break

		if line == null:
			chat.next = ""
			break

		await app_chat.deliver_line(chat_id, line)
		chat.next = line.next_id

	chat.running = false


func _fetch_line(chat_id: String, key: String):
	while _fetching:
		await _fetch_released
	_fetching = true
	GameEvents.active_chat = chat_id

	var line = await DialogueManager.get_next_dialogue_line(DIALOGUE_HISTORY, key)

	GameEvents.active_chat = ""
	_fetching = false
	_fetch_released.emit()
	return line


# -------------------------------------------------------------
# ANSWERS (any chat can be waiting; you answer the one that is open)
# -------------------------------------------------------------
func _on_chord_submitted(notes: Array) -> void:
	var chat_id: String = open_chat_id
	if on_home or not chats.has(chat_id) or chats[chat_id].pending.is_empty():
		return
	var chat = chats[chat_id]
	var request: Dictionary = chat.pending

	var ok: bool = conversation_controller.process_played_notes(notes, request.expected)
	if not ok:
		composer.play_wrong()
		keyboard.play_wrong_feedback(notes)
		AudioManager.play_sfx("error", -8.0)
		_buzz(1.2)
		Input.vibrate_handheld(120)
		InputManager.set_answering(true)
		return

	chat.pending = {}
	composer.play_sent()
	AudioManager.play_sfx("send", -10.0)

	# Keep the chat busy while the reply appears, so nothing can jump ahead of it
	chat.running = true
	_refresh_answer_state(true)
	if request.reply_line != null:
		await app_chat.deliver_line(chat_id, request.reply_line, 0.05)
		if chat_id == open_chat_id:
			var bubble = app_chat.last_bubble()
			if bubble:
				bubble.flash.call_deferred()
	chat.running = false

	chat.next = request.next
	_run_chat(chat_id)


func _on_show_keyboard() -> void:
	keyboard_unlocked = true
	conversation.set_bottom_pad(false)
	AudioManager.play_sfx("unlock", -8.0)
	_buzz(0.8)
	keyboard.visible = true
	keyboard.modulate.a = 0.0
	var t = create_tween().set_parallel(true)
	t.tween_property(keyboard, "modulate:a", 1.0, 0.6)
	_refresh_answer_state(true)


# Answering is automatic: if the open chat waits for a chord, holding one sends it.
# You can always leave and come back: the pending answer stays in its chat.
func _refresh_answer_state(force: bool = false) -> void:
	var chat_id = open_chat_id
	var waiting: bool = not on_home and keyboard_unlocked and chats.has(chat_id) and not chats[chat_id].pending.is_empty()
	InputManager.set_answering(waiting)

	var state: String
	if not keyboard_unlocked:
		state = "locked"
	elif waiting:
		state = "waiting:" + chat_id
	else:
		state = "idle"
	if state == composer_state and not force:
		return
	composer_state = state

	match state:
		"locked":
			composer.set_locked()
		"idle":
			composer.set_idle()
		_:
			composer.set_waiting(chats[chat_id].pending.get("reply_text", ""))


# -------------------------------------------------------------
# MESSAGES, TYPING, NOTIFICATIONS
# -------------------------------------------------------------
func _on_message_added(chat_id: String, msg: Dictionary) -> void:
	# Time passes with every message; the night slowly ends
	game_minutes += MINUTES_PER_MESSAGE
	total_messages += 1
	status_bar.set_time(_clock_text())
	status_bar.set_battery(0.14 - total_messages * 0.0004)
	_update_home_subtitle()
	if total_messages % 8 == 0:
		scenery.set_dawn(minf(total_messages / MESSAGES_TO_DAWN, 0.85))

	var is_open = chat_id == open_chat_id and not on_home
	if is_open:
		if msg.es_npc:
			if not msg.notes.is_empty():
				AudioManager.play_chord_echo(msg.notes) # Every message has a melody
			else:
				AudioManager.play_sfx("back", -22.0)
		else:
			AudioManager.play_sfx("send", -18.0)
		if chat_id == open_chat_id:
			_refresh_header_status()
	elif msg.es_npc:
		chats[chat_id].unread += 1
		AudioManager.play_sfx("notify", -12.0)
		_buzz(0.5)
		if not on_home:
			banner.show_message(chat_id, msg.character, msg.texto)

	chat_list.bump_to_top(chat_id)
	_update_row(chat_id)


func _on_typing_changed(chat_id: String, character: String, text: String, duration: float) -> void:
	_update_row(chat_id)
	if chat_id != open_chat_id or on_home:
		return
	_refresh_header_status()

	if character == Contacts.PLAYER_NAME:
		# The protagonist writes by himself: we see it being typed in the bar
		composer.typewrite(text, duration)
		composer_state = "typing"
	elif character == "" and composer_state == "typing":
		_refresh_answer_state(true)


func _on_participant_changed(chat_id: String, _character: String, joined: bool) -> void:
	if joined:
		app_chat.add_participant(chat_id, _character)
	else:
		app_chat.remove_participant(chat_id, _character)
	if chat_id == open_chat_id:
		_refresh_header_status()


func _refresh_header_status() -> void:
	if open_chat_id == "":
		return
	var who: String = app_chat.typing.get(open_chat_id, "")
	if who != "" and who != Contacts.PLAYER_NAME:
		var many = app_chat.chat_participants[open_chat_id].size() > 1
		conversation.set_status((who + " está escribiendo...") if many else "escribiendo...", true)
		return
	var people: Array = app_chat.chat_participants[open_chat_id]
	if people.size() > 1:
		conversation.set_status(", ".join(people) + " y tú")
	else:
		conversation.set_status("en línea")


func _update_row(chat_id: String) -> void:
	if not chats.has(chat_id):
		return
	var history: Array = app_chat.chat_histories.get(chat_id, [])
	var preview = ""
	var time = ""
	for i in range(history.size() - 1, -1, -1):
		var msg = history[i]
		if msg.type == "msg":
			if not msg.es_npc:
				preview = "Tú: " + msg.texto
			elif app_chat.chat_participants[chat_id].size() > 1:
				preview = msg.character + ": " + msg.texto
			else:
				preview = msg.texto
			time = msg.get("time", "")
			break
	if not chats[chat_id].pending.is_empty() and keyboard_unlocked:
		preview = "Te está esperando..."
	var typing_now: String = app_chat.typing.get(chat_id, "")
	chat_list.update_chat(chat_id, preview, time, chats[chat_id].unread, typing_now != "" and typing_now != Contacts.PLAYER_NAME)


func _clock_text() -> String:
	var total = int(game_minutes)
	return "%d:%02d" % [(total / 60) % 24, total % 60]


func _update_home_subtitle() -> void:
	var lines = ["No puedes dormir.", "Tu cabeza no se calla.", "Todavía es de noche.", "Empieza a clarear."]
	var idx = clampi(int(total_messages / MESSAGES_TO_DAWN * 4.0), 0, lines.size() - 1)
	chat_list.set_subtitle(_clock_text() + " · " + lines[idx])


# -------------------------------------------------------------
# PHONE LOOK & FEEL
# -------------------------------------------------------------
func _style_phone() -> void:
	var body = UIStyle.box(UIStyle.BEZEL, 104)
	body.set_border_width_all(5)
	body.border_color = UIStyle.BEZEL_EDGE
	body.shadow_color = Color(0, 0, 0, 0.55)
	body.shadow_size = 70
	body.shadow_offset = Vector2(0, 30)
	$Phone/Body.add_theme_stylebox_override("panel", body)
	$Phone/Screen.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.SCREEN_BG, 86))
	$Phone/Screen/Island.add_theme_stylebox_override("panel", UIStyle.box(Color.BLACK, 22))
	$Phone/Screen/HomeBar.add_theme_stylebox_override("panel", UIStyle.box(Color(UIStyle.TEXT, 0.55), 5))
	for side_button in [$Phone/VolumeButton, $Phone/PowerButton]:
		side_button.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.BEZEL_EDGE, 6))


func _intro_animation() -> void:
	var rest_y = phone.position.y
	phone.position.y = rest_y + 300
	phone.modulate.a = 0.0
	var t = create_tween().set_parallel(true)
	t.tween_property(phone, "position:y", rest_y, 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(phone, "modulate:a", 1.0, 0.8)
	t.chain().tween_callback(_idle_float.bind(rest_y))


# The phone breathes slowly in your hand
func _idle_float(rest_y: float) -> void:
	var t = create_tween().set_loops()
	t.tween_property(phone, "position:y", rest_y - 8, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(phone, "position:y", rest_y + 8, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# Vibration: the phone shakes a little
func _buzz(strength: float = 1.0) -> void:
	if buzz_tween and buzz_tween.is_valid():
		buzz_tween.kill()
	buzz_tween = create_tween()
	for angle in [1.0, -1.0, 0.8, -0.8, 0.4, 0.0]:
		buzz_tween.tween_property(phone, "rotation_degrees", angle * strength, 0.035)
