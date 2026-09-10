extends Control

# Asegúrate de tener la ruta correcta hacia tu nodo AppChat
@onready var app_chat = $Divisor/MarginContainer/AppChat

func _ready():
	# 1. Creamos unos datos falsos idénticos a los que nos daría el JSON
	var datos_de_prueba = [
		{"texto": "Cariño, ¿cómo estás hoy?", "es_npc": true},
		{"texto": "Te noto ausente últimamente.", "es_npc": true},
		{"texto": "[Acorde Menor]", "es_npc": false},
		{"texto": "Sigo un poco triste...", "es_npc": false},
		{"texto": "Lo siento mucho, mi amor. Todo mejorará.", "es_npc": true}
	]
	
	# 2. Le enviamos los datos a la función que creaste antes
	# Ponemos un pequeño temporizador para asegurarnos de que la UI haya cargado
	await get_tree().create_timer(0.5).timeout
	app_chat.upload_new_conversation(datos_de_prueba)
