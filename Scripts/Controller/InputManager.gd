extends Node

# We create signal for audio, sending the id data with the call
signal note_played(note_id: int)

# Diccionary for the key values
var key_to_note = {
	"note_c": 0,
	"note_c_sharp": 1,
	"note_d": 2,
	"note_d_sharp": 3,
	"note_e": 4,
	"note_e_sharp": 5
}

var current_chord: Array = []
var chord_timer: Timer
var charge_time: float = 1.5 # Segundos de margen para completar el acorde

func _unhandled_input(event: InputEvent) -> void:
	# Ignore inputs that arent mapped
	if not event is InputEventKey:
		return
		
	for action in key_to_note.keys():
		# is_action_pressed checks if key pressed, not mantained
		if event.is_action_pressed(action):
			var note_id = key_to_note[action]
			note_played.emit(note_id)
