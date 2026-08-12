extends Control

# Standalone sound test harness. Run THIS scene directly (F6 / "Run Current Scene")
# to audition the game's procedural sounds and to experiment with the ToneGenerator
# synth — no cars or maps needed.
#
# The game-sound buttons mirror the note definitions in car.gd and map.gd; the
# engine section mirrors car.gd's drone tuning. The freeform section lets you dial
# in an arbitrary tone (waveform / frequency / duration / amplitude) and play it.

# Engine drone tuning, mirrored from car.gd so the test matches the game.
const ENGINE_BASE_HZ := 60.0
const ENGINE_PITCH_MIN := 0.8
const ENGINE_PITCH_MAX := 2.0
const ENGINE_SPEED_FOR_MAX_PITCH := 500.0

var _voice: ToneGenerator      # one-shots (game stings + freeform tones)
var _engine: ToneGenerator     # continuous drone for the engine test

var _engine_on := false
var _speed_slider: HSlider
var _wave_option: OptionButton
var _freq_slider: HSlider
var _dur_slider: HSlider
var _amp_slider: HSlider


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_voice = ToneGenerator.new()
	add_child(_voice)
	_engine = ToneGenerator.new()
	add_child(_engine)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.1, 0.1, 0.12)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.custom_minimum_size = Vector2(460, 0)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "Sound Test"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	# --- Game sounds (mirror car.gd / map.gd) ------------------------------
	_add_heading(vbox, "Game Sounds")
	_add_button(vbox, "Turn blip", _play_turn)
	_add_button(vbox, "Brake", _play_brake)
	_add_button(vbox, "Start countdown", _play_start)
	_add_button(vbox, "Lap chime", _play_lap)
	_add_button(vbox, "Win fanfare", _play_win)

	# --- Engine drone ------------------------------------------------------
	_add_heading(vbox, "Engine (drone)")
	_add_button(vbox, "Toggle engine on/off", _toggle_engine)
	_speed_slider = _add_slider(vbox, "Speed", 0.0, 600.0, 0.0, 1.0)
	_speed_slider.value_changed.connect(func(_v): _update_engine())

	# --- Freeform tone -----------------------------------------------------
	_add_heading(vbox, "Freeform Tone")
	_wave_option = _add_wave_option(vbox)
	_freq_slider = _add_slider(vbox, "Freq (Hz)", 50.0, 2000.0, 440.0, 1.0)
	_dur_slider = _add_slider(vbox, "Duration", 0.05, 1.0, 0.25, 0.01)
	_amp_slider = _add_slider(vbox, "Amplitude", 0.0, 0.5, 0.3, 0.01)
	_add_button(vbox, "Play tone", _play_tone)


# --- Game sound callbacks (kept in sync with car.gd / map.gd) --------------
func _play_turn() -> void:
	_voice.play_notes([
		{"freq": 660.0, "dur": 0.05, "wave": ToneGenerator.SQUARE, "amp": 0.25},
		{"freq": 880.0, "dur": 0.05, "wave": ToneGenerator.SQUARE, "amp": 0.25},
	])

func _play_brake() -> void:
	_voice.play_notes([
		{"freq": 320.0, "dur": 0.06, "wave": ToneGenerator.SAW, "amp": 0.3},
		{"freq": 180.0, "dur": 0.08, "wave": ToneGenerator.NOISE, "amp": 0.25},
	])

func _play_start() -> void:
	_voice.play_notes([
		{"freq": 440.0, "dur": 0.15, "wave": ToneGenerator.SQUARE, "amp": 0.3},
		{"freq": 0.0, "dur": 0.20, "wave": ToneGenerator.SQUARE, "amp": 0.0},
		{"freq": 440.0, "dur": 0.15, "wave": ToneGenerator.SQUARE, "amp": 0.3},
		{"freq": 0.0, "dur": 0.20, "wave": ToneGenerator.SQUARE, "amp": 0.0},
		{"freq": 440.0, "dur": 0.15, "wave": ToneGenerator.SQUARE, "amp": 0.3},
		{"freq": 0.0, "dur": 0.20, "wave": ToneGenerator.SQUARE, "amp": 0.0},
		{"freq": 880.0, "dur": 0.35, "wave": ToneGenerator.SQUARE, "amp": 0.35},
	])

func _play_lap() -> void:
	_voice.play_notes([
		{"freq": 784.0, "dur": 0.10, "wave": ToneGenerator.TRIANGLE, "amp": 0.35},
		{"freq": 1047.0, "dur": 0.16, "wave": ToneGenerator.TRIANGLE, "amp": 0.35},
	])

func _play_win() -> void:
	_voice.play_notes([
		{"freq": 523.0, "dur": 0.12, "wave": ToneGenerator.SQUARE, "amp": 0.32},
		{"freq": 659.0, "dur": 0.12, "wave": ToneGenerator.SQUARE, "amp": 0.32},
		{"freq": 784.0, "dur": 0.12, "wave": ToneGenerator.SQUARE, "amp": 0.32},
		{"freq": 1047.0, "dur": 0.30, "wave": ToneGenerator.SQUARE, "amp": 0.36},
	])


# --- Engine drone ----------------------------------------------------------
func _toggle_engine() -> void:
	_engine_on = not _engine_on
	if _engine_on:
		_update_engine()
	else:
		_engine.stop_drone()

func _update_engine() -> void:
	if not _engine_on:
		return
	var speed: float = _speed_slider.value
	var t := clampf(speed / ENGINE_SPEED_FOR_MAX_PITCH, 0.0, 1.0)
	var freq := ENGINE_BASE_HZ * lerpf(ENGINE_PITCH_MIN, ENGINE_PITCH_MAX, t)
	var amp := lerpf(0.12, 0.22, t)
	_engine.set_drone(freq, amp, ToneGenerator.SAW)


# --- Freeform tone ---------------------------------------------------------
func _play_tone() -> void:
	_voice.play_notes([{
		"freq": _freq_slider.value,
		"dur": _dur_slider.value,
		"wave": _wave_option.selected,   # item index == ToneGenerator enum value
		"amp": _amp_slider.value,
	}])


# --- Small UI builders -----------------------------------------------------
func _add_heading(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	parent.add_child(l)

func _add_button(parent: Control, text: String, on_press: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.pressed.connect(on_press)
	parent.add_child(btn)
	return btn

# A "<name> [slider] <value>" row. Returns the slider; the value label tracks it.
func _add_slider(parent: Control, label_text: String, min_v: float, max_v: float, value: float, step: float) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var name_label := Label.new()
	name_label.text = label_text
	name_label.custom_minimum_size = Vector2(90, 0)
	row.add_child(name_label)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(56, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.text = "%.2f" % value
	row.add_child(value_label)
	slider.value_changed.connect(func(v: float): value_label.text = "%.2f" % v)
	return slider

# A "Waveform [OptionButton]" row whose item indices match the ToneGenerator enum.
func _add_wave_option(parent: Control) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var label := Label.new()
	label.text = "Waveform"
	label.custom_minimum_size = Vector2(90, 0)
	row.add_child(label)

	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Order matches enum { SINE, SQUARE, SAW, TRIANGLE, NOISE } in tone_generator.gd.
	for wave_name in ["Sine", "Square", "Saw", "Triangle", "Noise"]:
		option.add_item(wave_name)
	option.select(ToneGenerator.SAW)
	row.add_child(option)
	return option
