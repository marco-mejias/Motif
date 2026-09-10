extends Node

# Dictionary links sounds with id values of keys
var piano_sounds = {
	0: preload("res://Audio/25405__tedagame__88-piano-keys-long-reverb/448567__tedagame__a6.ogg"),
	1: preload("res://Audio/25405__tedagame__88-piano-keys-long-reverb/448568__tedagame__b3.ogg"),
	2: preload("res://Audio/25405__tedagame__88-piano-keys-long-reverb/448569__tedagame__b2.ogg"),
	3: preload("res://Audio/25405__tedagame__88-piano-keys-long-reverb/448571__tedagame__a2.ogg"),
	4: preload("res://Audio/25405__tedagame__88-piano-keys-long-reverb/448574__tedagame__a7.ogg"),
	5: preload("res://Audio/25405__tedagame__88-piano-keys-long-reverb/448577__tedagame__a4.ogg")
}

# We assign a dedicated audio streamer for each key
var audio_streamers = {}

func _ready() -> void:
	# 1. Generate a dedicated audio node for each note in the dictionary
	for note_id in piano_sounds.keys():
		var stream = AudioStreamPlayer.new()
		stream.stream = piano_sounds[note_id] # Permanently assign the sound
		add_child(stream)
		audio_streamers[note_id] = stream # Save it in the dictionary
		
	# 2. We connect to the signal of the input manager and call the function in brackets
	InputManager.note_played.connect(_process_note)

func _process_note(note_id: int) -> void:
	# If the note is not in our dictionary, we ignore it
	if not audio_streamers.has(note_id):
		return
		
	# 3. Calling play() will automatically cut the previous sound and restart it from zero
	audio_streamers[note_id].play()
