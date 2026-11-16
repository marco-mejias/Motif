extends Node

# We create signal for audio, sending the id data with the call
signal note_played(note_id: int)
# Signal to notify when the player lifts the finger from the key
signal note_released(note_id: int)
# Signal to fully send the charged notes to the ConversationController
signal submit_notes(notes: Array)

# Dictionary for the key values (same order as the kalimba samples C D E F G A)
var key_to_note = {
	"note_c": 0,
	"note_d": 1,
	"note_e": 2,
	"note_f": 3,
	"note_g": 4,
	"note_a": 5
}

var held_notes: Array = []
var charge_timer: Timer
var charge_time: float = 2.0 # Seconds holding before the upload the 'message'
var is_answering: bool = false # True while the open chat is waiting for a chord

func _ready() -> void:
	charge_timer = Timer.new()
	charge_timer.one_shot = true
	charge_timer.timeout.connect(_on_charge_timer_timeout)
	add_child(charge_timer)

func _unhandled_input(event: InputEvent) -> void:
	# Ignore inputs that arent mapped
	if not event is InputEventKey or event.is_echo():
		return

	for action in key_to_note.keys():
		if event.is_action_pressed(action):
			press_note(key_to_note[action])
			break
		elif event.is_action_released(action):
			release_note(key_to_note[action])
			break

# Entry points shared by the physical keyboard and the on-screen keys (mouse / touch)
func press_note(note_id: int) -> void:
	if held_notes.has(note_id):
		return
	held_notes.append(note_id)
	note_played.emit(note_id)
	_on_keys_changed()

func release_note(note_id: int) -> void:
	if not held_notes.has(note_id):
		return
	held_notes.erase(note_id)
	note_released.emit(note_id)
	_on_keys_changed()

# If the keys we were pressing have changed, we restart the timer for the final input
func _on_keys_changed() -> void:
	held_notes.sort()

	if held_notes.size() > 0 and is_answering:
		charge_timer.start(charge_time)
	else:
		charge_timer.stop()

func set_answering(value: bool) -> void:
	is_answering = value
	if not is_answering:
		charge_timer.stop()

func _on_charge_timer_timeout():
	if is_answering and held_notes.size() > 0:
		print("InputManager: Chord fully charged! Submitting: ", held_notes)
		is_answering = false
		submit_notes.emit(held_notes.duplicate())
