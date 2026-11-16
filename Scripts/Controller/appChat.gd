extends MarginContainer

@export var text_bubble: PackedScene
@onready var message_list = $ScrollContainer/MessageList
@onready var scroll_container = $ScrollContainer

# Emitted for every normal message stored in any chat (open or not)
signal message_added(chat_id: String, msg: Dictionary)
# Someone starts / stops writing in a chat. character == "" when they stop.
signal typing_changed(chat_id: String, character: String, text: String, duration: float)

# Diccionario para almacenar el historial de cada conversación:
# Estructura: { "diver": [ {type, texto, es_npc, notes, speaker, time}, ... ], "poker": [ ... ] }
var chat_histories: Dictionary = {}
# Voces presentes en cada chat (sin contar al Prota): { "blind": ["Blind", "Diver"] }
var chat_participants: Dictionary = {}
# Quién está escribiendo ahora mismo en cada chat
var typing: Dictionary = {}
var current_chat_id: String = ""

# Main gives us the in-game clock ("5:07")
var clock_text: Callable = func(): return ""

var typing_bubble: Control

const DEFAULT_DELAY: float = 3.0 # Time default from text to text

func _ready() -> void:
	add_theme_constant_override("margin_left", 22)
	add_theme_constant_override("margin_right", 22)
	message_list.add_theme_constant_override("separation", 12)
	scroll_container.mouse_filter = Control.MOUSE_FILTER_PASS

# -------------------------------------------------------------
# 0. REGISTRAR UN CHAT (su dueño es el primer participante)
# -------------------------------------------------------------
func register_chat(chat_id: String) -> void:
	if chat_histories.has(chat_id):
		return
	chat_histories[chat_id] = [{ "type": "system", "texto": "HOY" }]
	chat_participants[chat_id] = [Contacts.display_name(chat_id)]
	typing[chat_id] = ""

# -------------------------------------------------------------
# 1. CAMBIAR DE CONVERSACIÓN (Limpia UI y carga el historial del contacto)
# -------------------------------------------------------------
func switch_chat(conversation_id: String) -> void:
	current_chat_id = conversation_id
	register_chat(current_chat_id)

	# Limpiar los mensajes visibles en pantalla
	for child in message_list.get_children():
		child.queue_free()
	typing_bubble = null

	# Reconstruir las burbujas guardadas de este contacto
	for msg in chat_histories[current_chat_id]:
		_render(msg, false)
	_refresh_typing_bubble()

	_scroll_to_bottom()

# -------------------------------------------------------------
# 2. ENTREGAR UNA LÍNEA DE DIALOGUE MANAGER A UN CHAT
# Se guarda siempre en su historial, aunque el jugador esté mirando otro chat.
# -------------------------------------------------------------
func deliver_line(chat_id: String, line, delay_override: float = -1.0) -> void:
	register_chat(chat_id)
	var parsed = parse_line(line)
	var delay_time: float = parsed["delay"] if delay_override < 0.0 else delay_override

	# "escribiendo..." mientras dura la pausa
	if delay_time > 0.4:
		_set_typing(chat_id, line.character, parsed["text"], delay_time)
	await get_tree().create_timer(delay_time).timeout
	_set_typing(chat_id, "", "", 0.0)

	# Depuración para que veas en consola qué notas recibe exactamente cada mensaje
	print("[", chat_id, "] ", line.character, ": '", parsed["text"], "' | Notas asignadas: ", parsed["notes"])

	append_new_message(chat_id, parsed["text"], line.character, parsed["notes"])

# Extracts the clean text, notes and delay of a line (from native tags or inline "#notes:[...]")
func parse_line(line) -> Dictionary:
	var raw_text: String = line.text
	var notes_array: Array = []
	var delay_time: float = DEFAULT_DELAY

	# 1. Comprobar tags nativos de Dialogue Manager
	if "tags" in line and line.tags.size() > 0:
		for tag in line.tags:
			if tag.begins_with("notes:"):
				notes_array = _parse_notes_string(tag.trim_prefix("notes:"))
			elif tag.begins_with("delay:"):
				delay_time = tag.trim_prefix("delay:").to_float()

	# 2. Si el tag venía dentro del propio texto (#notes:[0,2,4])
	if "#delay:" in raw_text:
		var parts = raw_text.split("#delay:")
		var delay_str = parts[1].split(" ")[0] # Aislar el número
		delay_time = delay_str.to_float()
		raw_text = raw_text.replace("#delay:" + delay_str, "")

	if "#notes:" in raw_text:
		var parts = raw_text.split("#notes:")
		if notes_array.is_empty() and parts.size() > 1:
			notes_array = _parse_notes_string(parts[1])
		raw_text = parts[0]

	return { "text": raw_text.strip_edges(), "notes": notes_array, "delay": delay_time }

# Función auxiliar para limpiar corchetes y espacios
func _parse_notes_string(raw_str: String) -> Array:
	var result: Array = []
	# Quitamos corchetes [, ], espacios y comillas
	var cleaned = raw_str.replace("[", "").replace("]", "").replace(" ", "").strip_edges()

	for n in cleaned.split(","):
		if n.is_valid_int():
			result.append(n.to_int())

	return result

# -------------------------------------------------------------
# 3. AÑADIR UN MENSAJE INDIVIDUAL (A la memoria y, si el chat está abierto, a la pantalla)
# -------------------------------------------------------------
func append_new_message(chat_id: String, text: String, speaker: String, notes: Array = []) -> Dictionary:
	register_chat(chat_id)
	var es_npc: bool = speaker != Contacts.PLAYER_NAME

	# Cualquier voz que hable en un chat ajeno entra en él
	if es_npc:
		add_participant(chat_id, speaker)

	var msg_data = {
		"type": "msg",
		"texto": text,
		"es_npc": es_npc,
		"notes": notes,
		"character": speaker,
		# El nombre solo se muestra cuando hay más de una voz en el chat
		"speaker": speaker if es_npc and chat_participants[chat_id].size() > 1 else "",
		"time": clock_text.call()
	}
	_store(chat_id, msg_data)
	message_added.emit(chat_id, msg_data)
	return msg_data

# -------------------------------------------------------------
# 4. PARTICIPANTES (otras voces que entran / salen de un chat)
# -------------------------------------------------------------
func add_participant(chat_id: String, character: String) -> void:
	register_chat(chat_id)
	if chat_participants[chat_id].has(character):
		return
	chat_participants[chat_id].append(character)
	_store(chat_id, { "type": "system", "texto": character + " ha entrado en el chat" })

func remove_participant(chat_id: String, character: String) -> void:
	register_chat(chat_id)
	if not chat_participants[chat_id].has(character):
		return
	chat_participants[chat_id].erase(character)
	_store(chat_id, { "type": "system", "texto": character + " ha salido del chat" })

# The newest bubble on screen (to flash it after a correct chord)
func last_bubble() -> Control:
	for i in range(message_list.get_child_count() - 1, -1, -1):
		var child = message_list.get_child(i)
		if child != typing_bubble and child.has_method("flash"):
			return child
	return null

# -------------------------------------------------------------
# MÉTODOS AUXILIARES
# -------------------------------------------------------------
func _store(chat_id: String, msg: Dictionary) -> void:
	chat_histories[chat_id].append(msg)
	if chat_id == current_chat_id:
		_render(msg, true)
		_scroll_to_bottom()

func _render(msg: Dictionary, animate: bool) -> void:
	var node: Control
	if msg["type"] == "system":
		node = _instantiate_system_pill(msg["texto"])
	else:
		node = _instantiate_bubble(msg)
	# The typing indicator always stays last
	if typing_bubble and is_instance_valid(typing_bubble):
		message_list.move_child(typing_bubble, -1)
	if animate and node.has_method("animate_entrance"):
		node.animate_entrance.call_deferred()

func _instantiate_bubble(msg: Dictionary) -> Control:
	var new_bubble = text_bubble.instantiate()
	message_list.add_child(new_bubble)
	var max_width = (message_list.size.x if message_list.size.x > 100 else 780.0) * 0.78
	new_bubble.configMsg(msg["texto"], msg["es_npc"], msg["notes"], msg["speaker"], msg.get("time", ""), max_width)
	return new_bubble

func _instantiate_system_pill(text: String) -> Control:
	var center = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pill = PanelContainer.new()
	pill.add_theme_stylebox_override("panel", UIStyle.box(Color(UIStyle.SURFACE, 0.9), 20, 0))
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(margin)
	margin.add_child(UIStyle.label(text, 22, UIStyle.TEXT_DIM))
	center.add_child(pill)
	message_list.add_child(center)
	return center

func _set_typing(chat_id: String, character: String, text: String, duration: float) -> void:
	typing[chat_id] = character
	typing_changed.emit(chat_id, character, text, duration)
	if chat_id == current_chat_id:
		_refresh_typing_bubble()

# Three bouncing dots while a voice (not the protagonist) is writing in the open chat
func _refresh_typing_bubble() -> void:
	var who: String = typing.get(current_chat_id, "")
	var show_it = who != "" and who != Contacts.PLAYER_NAME

	if not show_it:
		if typing_bubble and is_instance_valid(typing_bubble):
			typing_bubble.queue_free()
		typing_bubble = null
		return
	if typing_bubble and is_instance_valid(typing_bubble):
		return

	typing_bubble = PanelContainer.new()
	var sb = UIStyle.box(UIStyle.SURFACE_HI, 30, 0)
	sb.corner_radius_top_left = 8
	typing_bubble.add_theme_stylebox_override("panel", sb)
	typing_bubble.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	typing_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin = MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	typing_bubble.add_child(margin)
	var dots = HBoxContainer.new()
	dots.add_theme_constant_override("separation", 10)
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(dots)
	for i in 3:
		var dot = Panel.new()
		dot.custom_minimum_size = Vector2(16, 16)
		dot.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.TEXT_DIM, 8))
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dots.add_child(dot)
		var t = dot.create_tween().set_loops()
		t.tween_interval(i * 0.15)
		t.tween_property(dot, "modulate:a", 1.0, 0.25)
		t.tween_property(dot, "modulate:a", 0.3, 0.35)
		t.tween_interval(0.45 - i * 0.15)
		dot.modulate.a = 0.3
	message_list.add_child(typing_bubble)
	_scroll_to_bottom()

func _scroll_to_bottom() -> void:
	# Esperar un frame a que Godot calcule el nuevo tamaño del contenedor
	await get_tree().process_frame
	var bar = scroll_container.get_v_scroll_bar()
	var t = create_tween()
	t.tween_property(scroll_container, "scroll_vertical", int(bar.max_value), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
