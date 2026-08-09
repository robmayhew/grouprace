class_name ToneGenerator
extends AudioStreamPlayer

# Procedural, sample-free audio. Instead of playing a .wav/.ogg, this node owns an
# AudioStreamGenerator and synthesizes samples every frame. It serves two jobs at once:
#   * a continuous DRONE (the engine) whose frequency/amplitude can change smoothly, and
#   * one-shot NOTE SEQUENCES (blips, chimes, jingles) that play out then fall silent.
# Everything is chiptune-flavoured: a handful of cheap waveforms and short envelopes.

# Waveform kinds accepted by set_drone()/play_notes().
enum { SINE, SQUARE, SAW, TRIANGLE, NOISE }

# 22050 Hz is plenty for arcade bleeps and keeps per-frame synthesis cheap.
const MIX_RATE := 22050.0
const BUFFER_LENGTH := 0.1

# How fast the drone chases its target freq/amp, in units-per-sample. Small enough
# to smear abrupt changes (no zipper noise), large enough to feel responsive.
const DRONE_FREQ_GLIDE := 0.002
const DRONE_AMP_GLIDE := 0.0008

var _playback: AudioStreamGeneratorPlayback
var _phase := 0.0                     # oscillator phase, wrapped to [0,1)

# --- Drone state ----------------------------------------------------------
var _drone_freq := 0.0
var _drone_amp := 0.0
var _drone_wave := SAW
var _drone_freq_target := 0.0
var _drone_amp_target := 0.0

# --- One-shot sequence state ----------------------------------------------
# Each note: { "freq": float, "dur": float, "wave": int, "amp": float }.
var _notes: Array = []
var _note_index := -1
var _note_samples_left := 0           # samples remaining in the current note
var _note_samples_total := 0          # note length in samples (for the envelope)


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = BUFFER_LENGTH
	stream = gen
	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback


func _process(_delta: float) -> void:
	if _playback == null:
		return
	var n := _playback.get_frames_available()
	if n <= 0:
		return
	var buf := PackedVector2Array()
	buf.resize(n)
	for i in n:
		var s := _next_sample()
		buf[i] = Vector2(s, s)
	_playback.push_buffer(buf)


# Produces one mono sample. A running note sequence takes priority over the drone,
# so one-shots are heard clearly over the engine on the same voice when needed.
func _next_sample() -> float:
	var freq := 0.0
	var amp := 0.0
	var wave := SINE

	if _note_index >= 0:
		var note: Dictionary = _notes[_note_index]
		freq = note["freq"]
		wave = note["wave"]
		amp = note["amp"] * _note_envelope()
		_advance_note()
	else:
		# Glide the drone toward its target to avoid clicks on sudden changes.
		_drone_freq = lerpf(_drone_freq, _drone_freq_target, DRONE_FREQ_GLIDE)
		_drone_amp = lerpf(_drone_amp, _drone_amp_target, DRONE_AMP_GLIDE)
		freq = _drone_freq
		amp = _drone_amp
		wave = _drone_wave

	_phase += freq / MIX_RATE
	_phase -= floorf(_phase)
	return _wave(_phase, wave) * amp


# Short linear attack + decay so notes don't click on/off.
func _note_envelope() -> float:
	if _note_samples_total <= 0:
		return 0.0
	var edge := int(min(_note_samples_total * 0.15, MIX_RATE * 0.01))
	edge = max(edge, 1)
	var pos := _note_samples_total - _note_samples_left
	if pos < edge:
		return float(pos) / float(edge)
	if _note_samples_left < edge:
		return float(_note_samples_left) / float(edge)
	return 1.0


func _advance_note() -> void:
	_note_samples_left -= 1
	if _note_samples_left > 0:
		return
	_note_index += 1
	if _note_index >= _notes.size():
		_note_index = -1
		_notes = []
		return
	_start_current_note()


func _start_current_note() -> void:
	var note: Dictionary = _notes[_note_index]
	_note_samples_total = int(note["dur"] * MIX_RATE)
	_note_samples_left = _note_samples_total


func _wave(phase: float, kind: int) -> float:
	match kind:
		SQUARE:
			return 1.0 if phase < 0.5 else -1.0
		SAW:
			return 2.0 * phase - 1.0
		TRIANGLE:
			return 4.0 * absf(phase - 0.5) - 1.0
		NOISE:
			return randf() * 2.0 - 1.0
		_:
			return sin(phase * TAU)


# --- Public API -----------------------------------------------------------

# Hold a continuous tone (the engine). Call every frame with updated freq/amp.
func set_drone(freq: float, amp: float, wave: int = SAW) -> void:
	_drone_freq_target = freq
	_drone_amp_target = amp
	_drone_wave = wave


# Ramp the drone down to silence (glide handles the fade).
func stop_drone() -> void:
	_drone_amp_target = 0.0


# Play a one-shot note sequence, replacing any in progress. Each note is a Dictionary
# { "freq": Hz, "dur": seconds, "wave": <enum>, "amp": 0..1 }.
func play_notes(notes: Array) -> void:
	if notes.is_empty():
		return
	_notes = notes
	_note_index = 0
	_start_current_note()


# Cut everything immediately (used when the race ends).
func silence() -> void:
	_drone_amp = 0.0
	_drone_amp_target = 0.0
	_drone_freq_target = 0.0
	_notes = []
	_note_index = -1
	_note_samples_left = 0
