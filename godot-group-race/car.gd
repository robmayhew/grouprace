class_name Car

extends CharacterBody2D

var damage:int
var car_name:String = "Give Me A name"

# This car's own input source. A car only ever knows about its own controller,
# never any other car's controls.
var controller: CarController

# --- Power-ups ------------------------------------------------------------
# Multiplier applied to this car's speed. 1.0 = normal. Each car subclass reads
# this when computing its velocity, so power-ups affect every car type uniformly.
var speed_multiplier := 1.0
var steer_multiplier := 1.0


# Temporarily scale this car's speed by `multiplier` for `duration` seconds, then
# undo exactly this boost. Reverting by dividing (rather than resetting to 1.0)
# keeps overlapping boosts independent, so one expiring doesn't cancel another.
func apply_speed_boost(multiplier: float, duration: float) -> void:
	speed_multiplier *= multiplier
	print("Speed boost applied")
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(self):
		speed_multiplier /= multiplier
		print("Speed boost removed")
		
func apply_steer_bost(multiplier: float, duration: float) -> void:
	steer_multiplier *= multiplier
	print("Steer boost applied")
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(self):
		speed_multiplier /= multiplier
		print("Steer boost removed")

# --- Sound ----------------------------------------------------------------
# All car audio is synthesized at runtime (see ToneGenerator) — no sample files.
# The engine is a continuous drone whose frequency rises with speed; turning and
# braking fire as one-shot blips on the rising edge of the input.
@export var engine_base_hz := 60.0             # engine drone frequency at engine_pitch_min
@export var engine_pitch_min := 0.8            # pitch factor at a standstill
@export var engine_pitch_max := 2.0            # pitch factor at engine_speed_for_max_pitch
@export var engine_speed_for_max_pitch := 2000.0
@export var steer_sound_threshold := 0.4       # steering magnitude that counts as turning

var _engine: ToneGenerator                     # continuous engine drone
var _sfx: ToneGenerator                        # shared voice for turn/brake one-shots
var _was_turning := false
var _was_braking := false


func _ready() -> void:
	_engine = ToneGenerator.new()
	add_child(_engine)
	_sfx = ToneGenerator.new()
	add_child(_sfx)


func _process(_delta: float) -> void:
	_update_engine_sound()
	_update_action_sounds()


# Raises the engine drone frequency from engine_pitch_min (stopped) to
# engine_pitch_max (at/above engine_speed_for_max_pitch) based on current speed.
func _update_engine_sound() -> void:
	if _engine == null:
		return
	var speed := velocity.length()
	var t := clampf(speed / maxf(engine_speed_for_max_pitch, 1.0), 0.0, 1.0)
	var freq := engine_base_hz * lerpf(engine_pitch_min, engine_pitch_max, t)
	# A touch louder as it revs, so speeding up reads in the mix as well as the pitch.
	var amp := lerpf(0.12, 0.22, t)
	_engine.set_drone(freq, amp, ToneGenerator.SAW)


# Fires the turn / brake one-shots on the rising edge so each press plays once.
func _update_action_sounds() -> void:
	var steering := controller.get_steering() if controller != null else 0.0
	var braking := (controller.get_brake() if controller != null else 0.0) > 0.0

	var turning := absf(steering) >= steer_sound_threshold and velocity.length() > 1.0
	if turning and not _was_turning:
		# Quick upward blip.
		_sfx.play_notes([
			{"freq": 899.0, "dur": 0.10, "wave": ToneGenerator.SINE, "amp": 0.25},
			{"freq": 899.0, "dur": 0.10, "wave": ToneGenerator.SINE, "amp": 0.25},
		])
	_was_turning = turning

	if braking and not _was_braking:
		# Short descending noisy tone.
		_sfx.play_notes([
			{"freq": 320.0, "dur": 0.06, "wave": ToneGenerator.SAW, "amp": 0.3},
			{"freq": 180.0, "dur": 0.08, "wave": ToneGenerator.NOISE, "amp": 0.25},
		])
	_was_braking = braking


# Silences every engine/turn/brake voice (used when the race ends).
func stop_sounds() -> void:
	if _engine:
		_engine.silence()
	if _sfx:
		_sfx.silence()


func set_controller(c: CarController) -> void:
	controller = c

func fetch_controller() -> CarController:
	return controller

func fetch_damange() -> int:
	return damage
	
func apply_damage(i:int) -> void:
	damage = i	

func fetch_body() -> CharacterBody2D:
	push_error("Car has no body")
	return null

func fetch_car_name() -> String:
	return car_name
	
func set_car_name(s:String):
	car_name = s
