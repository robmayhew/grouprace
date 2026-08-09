class_name Car

extends CharacterBody2D

var damage:int
var car_name:String = "Give Me A name"

# This car's own input source. A car only ever knows about its own controller,
# never any other car's controls.
var controller: CarController

# --- Sound ----------------------------------------------------------------
# Per-car sounds, assigned in each car scene's Inspector. Any left unset stays
# silent. The engine loops while the car is active, its pitch rising with speed;
# turning and braking fire as one-shots on the rising edge of the input.
@export var engine_sound: AudioStream
@export var turn_sound: AudioStream
@export var brake_sound: AudioStream
@export var engine_pitch_min := 0.8            # pitch at a standstill
@export var engine_pitch_max := 2.0            # pitch at engine_speed_for_max_pitch
@export var engine_speed_for_max_pitch := 500.0
@export var steer_sound_threshold := 0.4       # steering magnitude that counts as turning

var _engine_player: AudioStreamPlayer
var _turn_player: AudioStreamPlayer
var _brake_player: AudioStreamPlayer
var _was_turning := false
var _was_braking := false


func _ready() -> void:
	_engine_player = AudioStreamPlayer.new()
	add_child(_engine_player)
	_turn_player = AudioStreamPlayer.new()
	add_child(_turn_player)
	_brake_player = AudioStreamPlayer.new()
	add_child(_brake_player)

	# Loop the engine by replaying it whenever it ends. Harmless if the stream
	# already loops on its own (in which case `finished` never fires).
	_engine_player.finished.connect(_on_engine_finished)
	if engine_sound:
		_engine_player.stream = engine_sound
		_engine_player.play()


func _process(_delta: float) -> void:
	_update_engine_sound()
	_update_action_sounds()


# Raises the engine pitch from engine_pitch_min (stopped) to engine_pitch_max
# (at/above engine_speed_for_max_pitch) based on the car's current speed.
func _update_engine_sound() -> void:
	if _engine_player == null or _engine_player.stream == null:
		return
	var speed := velocity.length()
	var t := clampf(speed / maxf(engine_speed_for_max_pitch, 1.0), 0.0, 1.0)
	_engine_player.pitch_scale = lerpf(engine_pitch_min, engine_pitch_max, t)


# Fires the turn / brake one-shots on the rising edge so each press plays once.
func _update_action_sounds() -> void:
	var steering := controller.get_steering() if controller != null else 0.0
	var braking := (controller.get_brake() if controller != null else 0.0) > 0.0

	var turning := absf(steering) >= steer_sound_threshold and velocity.length() > 1.0
	if turning and not _was_turning:
		_play_oneshot(_turn_player, turn_sound)
	_was_turning = turning

	if braking and not _was_braking:
		_play_oneshot(_brake_player, brake_sound)
	_was_braking = braking


func _play_oneshot(player: AudioStreamPlayer, stream: AudioStream) -> void:
	if player == null or stream == null:
		return
	player.stream = stream
	player.play()


func _on_engine_finished() -> void:
	if _engine_player.stream:
		_engine_player.play()


# Silences every engine/turn/brake sound (used when the race ends).
func stop_sounds() -> void:
	if _engine_player:
		_engine_player.stop()
	if _turn_player:
		_turn_player.stop()
	if _brake_player:
		_brake_player.stop()


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
