extends Node

# 1. ASSIGN YOUR 6 KALIMBA NOTES HERE
var piano_sounds: Dictionary = {
	0: preload("res://Audio/coconut-kalimba-c-single-note_104bpm_C_major.wav"),
	1: preload("res://Audio/coconut-kalimba-d-single-note_103bpm_D.wav"),
	2: preload("res://Audio/coconut-kalimba-e-single-note_102bpm_E.wav"),
	3: preload("res://Audio/coconut-kalimba-f-single-note_103bpm_F.wav"),
	4: preload("res://Audio/coconut-kalimba-g-single-note_117bpm_G.wav"),
	5: preload("res://Audio/coconut-kalimba-a-single-note_102bpm_A_minor.wav")
}

const SFX_DIR = "res://Assets/JDSherbert - Ultimate UI SFX Pack (FREE)/Stereo/ogg/JDSherbert - Ultimate UI SFX Pack - "
# UI sounds of the phone
var sfx_streams: Dictionary = {
	"notify": load(SFX_DIR + "Popup Open - 1.ogg"),
	"send": load(SFX_DIR + "Swipe - 1.ogg"),
	"open": load(SFX_DIR + "Select - 1.ogg"),
	"back": load(SFX_DIR + "Cursor - 2.ogg"),
	"error": load(SFX_DIR + "Error - 1.ogg"),
	"unlock": load(SFX_DIR + "Select - 2.ogg"),
}
var sfx_player: AudioStreamPlayer
# Separate kalimba players for message chords, so they never cut the notes the player is holding
var echo_players: Dictionary = {}

var audio_streamers: Dictionary = {}
var active_tweens: Dictionary = {} 

# --- RHYTHM SYSTEM ---
var bgm_stream = preload("res://Audio/freesound_community-hg-dark-pad-loop-100bpm-16bars-222992-32922.mp3") 
var bgm_player: AudioStreamPlayer
var background_bpm: int = 100 # Adjust this to your background music tempo
var pending_notes: Array = []
var metronome: Timer

func _ready() -> void:
	# 1. Setup Background Music Player
	bgm_player = AudioStreamPlayer.new()
	bgm_player.stream = bgm_stream
	bgm_player.bus = "Master" 
	bgm_player.volume_db = -20.0 # BGM slightly lower so the piano stands out
	add_child(bgm_player)
	
	# Prepare audio players with your Kalimba sounds
	for note_id in piano_sounds.keys():
		var stream = AudioStreamPlayer.new()
		stream.stream = piano_sounds[note_id] 
		stream.max_polyphony = 4 
		stream.bus = "Piano" # Remember to add a Reverb effect to this audio bus
		add_child(stream)
		audio_streamers[note_id] = stream
		
	# UI sounds
	sfx_player = AudioStreamPlayer.new()
	sfx_player.max_polyphony = 4
	sfx_player.volume_db = -10.0
	add_child(sfx_player)
	
	for note_id in piano_sounds.keys():
		var echo = AudioStreamPlayer.new()
		echo.stream = piano_sounds[note_id]
		echo.max_polyphony = 2
		echo.bus = "Piano"
		add_child(echo)
		echo_players[note_id] = echo
	
	# Configure the metronome for quantization
	metronome = Timer.new()
	metronome.wait_time = 60.0 / (background_bpm * 2.0) 
	metronome.autostart = true
	metronome.timeout.connect(_on_beat_tick)
	add_child(metronome)
		
	# Connect signals from InputManager
	InputManager.note_played.connect(_on_note_pressed)
	if InputManager.has_signal("note_released"):
		InputManager.note_released.connect(_on_note_released)
		
	# 5. START BGM AND METRONOME TOGETHER
	bgm_player.play()
	metronome.start()

# --- INPUT HANDLING ---
func _on_note_pressed(note_id: int) -> void:
	if not audio_streamers.has(note_id) or pending_notes.has(note_id):
		return
	pending_notes.append(note_id)

func _on_note_released(note_id: int) -> void:
	if pending_notes.has(note_id):
		pending_notes.erase(note_id) 
	_fade_out_note(note_id)

# --- PLAYBACK (SYNCED WITH TEMPO) ---
func _on_beat_tick() -> void:
	if pending_notes.size() > 0:
		for note in pending_notes:
			_play_note(note)
		pending_notes.clear()

func _play_note(note_id: int) -> void:
	var player = audio_streamers[note_id]
	
	if active_tweens.has(note_id) and active_tweens[note_id].is_valid():
		active_tweens[note_id].kill()
		
	player.volume_db = 0.0
	player.play() 

# Simulates releasing the kalimba tine by fading out the sound
func _fade_out_note(note_id: int) -> void:
	if not audio_streamers.has(note_id): return
	var player = audio_streamers[note_id]
	
	var tween = get_tree().create_tween()
	tween.tween_property(player, "volume_db", -40.0, 0.3)
	tween.tween_callback(player.stop)
	
	active_tweens[note_id] = tween 

# --- DIALOGUES AND CLOUDS ---
func play_chord(notes: Array) -> void:
	for note_id in notes:
		_play_note(note_id)

# Soft chord when a musical message arrives (lower volume, slightly arpeggiated)
func play_chord_echo(notes: Array, volume_db: float = -14.0) -> void:
	for i in notes.size():
		var note_id = notes[i]
		if not echo_players.has(note_id):
			continue
		var player: AudioStreamPlayer = echo_players[note_id]
		player.volume_db = volume_db
		get_tree().create_timer(i * 0.06).timeout.connect(player.play)

func play_sfx(sfx_name: String, volume_db: float = -10.0) -> void:
	if not sfx_streams.has(sfx_name) or sfx_streams[sfx_name] == null:
		return
	sfx_player.stream = sfx_streams[sfx_name]
	sfx_player.volume_db = volume_db
	sfx_player.play()
