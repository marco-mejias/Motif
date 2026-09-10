extends MarginContainer

@export var text_bubble: PackedScene 
@onready var message_list = $ScrollContainer/MessageList

func upload_new_conversation(hist_msg: Array):
	# 1. Clean old messages
	for child in message_list.get_children():
		child.queue_free()
		
	# 2. Generate new messages
	for msg in hist_msg:
		var new_bubble = text_bubble.instantiate()
		message_list.add_child(new_bubble)
		
		# Function to give format to the bubble
		new_bubble.configMsg(msg["texto"], msg["es_npc"])
