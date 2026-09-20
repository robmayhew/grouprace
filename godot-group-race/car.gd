class_name Car

extends CharacterBody2D

# =============================================================================
# Car — common base class for every playable animal character.
#
# Each character lives in its own folder under res://cars/<name>/ and extends
# this class. A subclass only needs to:
#   * set its identity   (character_name, theme_color)
#   * set its four stats (speed, acceleration, turn, recovery_time)
#   * ship its images    (res://cars/<name>/images/<state>.svg)
# All driving physics, sound, power-ups and the per-state sprite swapping are
# implemented here once, so every character shares identical behaviour and only
# differs by its stats and artwork.
# =============================================================================

var damage: int
var car_name: String = "Give Me A name"

# --- Identity -------------------------------------------------------------
# Shown in the character-select menu and the win/lose screens. Subclasses set
# these in _init(); theme_color also tints that character's HUD accents.
@export var character_name: String = "Racer"
@export var theme_color: Color = Color.WHITE

# --- Adjustable stats -----------------------------------------------------
# The four tunable stats from the design. All are on a 1..10 scale (higher is
# always better) and are mapped to concrete physics values by the _derived_*
# helpers below, so tuning a character never means touching the physics code.
@export_range(1.0, 10.0, 0.1) var speed: float = 6.0           # top speed
@export_range(1.0, 10.0, 0.1) var acceleration: float = 6.0    # how fast it builds speed
@export_range(1.0, 10.0, 0.1) var turn: float = 6.0            # steering sharpness
@export_range(1.0, 10.0, 0.1) var recovery_time: float = 6.0   # how quickly it recovers from a crash

# --- This car's own input source ------------------------------------------
# A car only ever knows about its own controller, never any other car's.
var controller: CarController

# --- Power-ups ------------------------------------------------------------
# Multiplier applied to this car's speed/steer. 1.0 = normal. The shared physics
# below reads these, so power-ups affect every character uniformly.
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
		steer_multiplier /= multiplier
		print("Steer boost removed")

# --- Stat -> physics mapping ----------------------------------------------
# Each stat is 1..10; these lerp it onto a sensible physics range. Kept in one
# place so the whole roster stays balanced by editing these curves alone.
func _stat01(value: float) -> float:
	return clampf((value - 1.0) / 9.0, 0.0, 1.0)

func _derived_top_speed() -> float:
	return lerpf(350.0, 1250.0, _stat01(speed))

func _derived_engine_power() -> float:
	return lerpf(900.0, 2600.0, _stat01(acceleration))

func _derived_steering_angle() -> float:
	return lerpf(18.0, 52.0, _stat01(turn))

func _derived_recovery_seconds() -> float:
	# Higher recovery stat -> shorter stun, so the bar reads "higher is better".
	return lerpf(2.8, 0.4, _stat01(recovery_time))

# --- Sound ----------------------------------------------------------------
# All car audio is synthesized at runtime (see ToneGenerator) — no sample files.
@export var engine_base_hz := 60.0
@export var engine_pitch_min := 0.8
@export var engine_pitch_max := 2.0
@export var engine_speed_for_max_pitch := 2000.0
@export var steer_sound_threshold := 0.4

var _engine: ToneGenerator
var _sfx: ToneGenerator
var _was_turning := false
var _was_braking := false

# --- Sprite / image state -------------------------------------------------
# Each character ships one image per state under its own images/ folder. We load
# them by convention from this script's directory, then swap the Sprite2D texture
# each frame to match what the car is doing (see _resolve_state).
enum State { GAS, BRAKE, TURN_LEFT, TURN_RIGHT, POWER_POSE, WIN, LOSE, SELECTION }

const _STATE_FILES := {
	State.GAS: "gas",
	State.BRAKE: "break",
	State.TURN_LEFT: "turn_left",
	State.TURN_RIGHT: "turn_right",
	State.POWER_POSE: "power_pose",
	State.WIN: "win",
	State.LOSE: "lose",
	State.SELECTION: "character_selection",
}

var _textures := {}                 # State -> Texture2D (whatever imported)
var _sprite: Sprite2D
# When set (win / lose), the sprite is locked to this state and stops reacting to
# input — used to freeze the pose on the results screen.
var _forced_state: int = -1

# --- Crash / recovery -----------------------------------------------------
# After a crash the car is briefly stunned: throttle is cut and grip drops for
# `recovery_seconds`. Lower recovery_time stat = longer stun.
var _recovering := false


func _ready() -> void:
	_engine = ToneGenerator.new()
	add_child(_engine)
	_sfx = ToneGenerator.new()
	add_child(_sfx)

	_sprite = get_node_or_null("Sprite2D")
	_load_state_textures()
	_set_sprite(State.POWER_POSE)


func _process(_delta: float) -> void:
	_update_engine_sound()
	_update_action_sounds()


# --- Shared driving physics ----------------------------------------------
# A bicycle model (front + rear wheel) drives every character; the four stats
# only change the numbers fed into it. Subclasses inherit this unchanged.
var _accel := Vector2.ZERO
var _steer_direction := 0.0

# Physics constants shared by all characters (feel, not identity).
const BRAKE_FORCE := -450.0
const MAX_SPEED_REVERSE := 250.0
const FRICTION := -55.0
const DRAG := -0.06
const WHEEL_BASE := 70.0
const SLIP_SPEED := 400.0
const TRACTION_SLOW := 10.0
const TRACTION_FAST := 2.5


func _physics_process(delta: float) -> void:
	_accel = Vector2.ZERO
	_read_input()
	_apply_friction(delta)
	_calculate_steering(delta)
	velocity += _accel * delta

	# Clamp to this character's top speed (power-ups can push past it).
	var max_v := _derived_top_speed() * speed_multiplier
	if velocity.length() > max_v:
		velocity = velocity.normalized() * max_v

	move_and_slide()
	_update_state_image()


func _read_input() -> void:
	if controller == null:
		return

	var steer_scale := steer_multiplier
	var power := _derived_engine_power() * speed_multiplier
	if _recovering:
		# Stunned: barely any throttle, sloppy steering.
		power *= 0.15
		steer_scale *= 0.4

	_steer_direction = controller.get_steering() * deg_to_rad(_derived_steering_angle() * steer_scale)

	var throttle := controller.get_throttle()
	var brake := controller.get_brake()
	if throttle > 0.0:
		_accel = transform.x * power * throttle
	if brake > 0.0:
		_accel = transform.x * BRAKE_FORCE * brake


func _apply_friction(delta: float) -> void:
	if velocity.length() < 5.0 and _accel == Vector2.ZERO:
		velocity = Vector2.ZERO
	# Extra drag while stunned so a crash actually slows you.
	var friction := FRICTION * (3.0 if _recovering else 1.0)
	var friction_force := velocity * friction * delta
	var drag_force := velocity * velocity.length() * DRAG * delta
	_accel += drag_force + friction_force


func _calculate_steering(delta: float) -> void:
	var rear_wheel := position - transform.x * WHEEL_BASE / 2.0
	var front_wheel := position + transform.x * WHEEL_BASE / 2.0
	rear_wheel += velocity * delta
	front_wheel += velocity.rotated(_steer_direction) * delta

	var new_heading := rear_wheel.direction_to(front_wheel)

	var traction := TRACTION_SLOW
	if velocity.length() > SLIP_SPEED:
		traction = TRACTION_FAST

	var d := new_heading.dot(velocity.normalized())
	if d > 0:
		velocity = velocity.lerp(new_heading * velocity.length(), traction * delta)
	if d < 0:
		velocity = -new_heading * min(velocity.length(), MAX_SPEED_REVERSE)

	rotation = new_heading.angle()


# Puts the car into its stunned recovery state for `_derived_recovery_seconds`,
# unless it is already recovering. Called by main.gd when the car crashes.
func crash() -> void:
	if _recovering or _forced_state != -1:
		return
	_recovering = true
	# Angry blip so a crash is audible as well as visible.
	if _sfx:
		_sfx.play_notes([
			{"freq": 240.0, "dur": 0.08, "wave": ToneGenerator.SAW, "amp": 0.3},
			{"freq": 140.0, "dur": 0.12, "wave": ToneGenerator.NOISE, "amp": 0.28},
		])
	await get_tree().create_timer(_derived_recovery_seconds()).timeout
	if is_instance_valid(self):
		_recovering = false

func is_recovering() -> bool:
	return _recovering


# --- Image state handling -------------------------------------------------
func _script_dir() -> String:
	var s: Script = get_script()
	if s == null:
		return ""
	return s.resource_path.get_base_dir()

func _load_state_textures() -> void:
	var dir := _script_dir()
	if dir == "":
		return
	var exts: Array[String] = [".svg", ".png"]
	for state in _STATE_FILES:
		var base: String = dir.path_join("images").path_join(_STATE_FILES[state])
		# Accept whichever format the character shipped / Godot imported.
		for ext in exts:
			var path := base + ext
			if ResourceLoader.exists(path):
				var tex := load(path)
				if tex is Texture2D:
					_textures[state] = tex
					break

func _set_sprite(state: int) -> void:
	if _sprite == null:
		return
	if _textures.has(state):
		_sprite.texture = _textures[state]

# Chooses the sprite that matches what the car is doing right now.
func _update_state_image() -> void:
	if _forced_state != -1:
		return
	_set_sprite(_resolve_state())

func _resolve_state() -> int:
	if _recovering:
		return State.POWER_POSE
	if controller == null:
		return State.POWER_POSE
	if controller.get_brake() > 0.0:
		return State.BRAKE
	var steering := controller.get_steering()
	if steering <= -0.3:
		return State.TURN_LEFT
	if steering >= 0.3:
		return State.TURN_RIGHT
	if controller.get_throttle() > 0.0:
		return State.GAS
	return State.POWER_POSE

# Loads this character's images on demand. Safe to call before _ready (e.g. on a
# menu-preview instance that never enters the tree), so the character select can
# show artwork without spinning up a live car.
func load_images() -> void:
	if _textures.is_empty():
		_load_state_textures()

# Texture used by the character-select menu preview.
func get_selection_texture() -> Texture2D:
	load_images()
	if _textures.has(State.SELECTION):
		return _textures[State.SELECTION]
	if _textures.has(State.POWER_POSE):
		return _textures[State.POWER_POSE]
	return null

# Lock the sprite to the victory / defeat pose on the results screen.
func show_win() -> void:
	_forced_state = State.WIN
	_set_sprite(State.WIN)

func show_lose() -> void:
	_forced_state = State.LOSE
	_set_sprite(State.LOSE)


# Raises the engine drone frequency from engine_pitch_min (stopped) to
# engine_pitch_max (at/above engine_speed_for_max_pitch) based on current speed.
func _update_engine_sound() -> void:
	if _engine == null:
		return
	var s := velocity.length()
	var t := clampf(s / maxf(engine_speed_for_max_pitch, 1.0), 0.0, 1.0)
	var freq := engine_base_hz * lerpf(engine_pitch_min, engine_pitch_max, t)
	var amp := lerpf(0.12, 0.22, t)
	_engine.set_drone(freq, amp, ToneGenerator.SAW)


# Fires the turn / brake one-shots on the rising edge so each press plays once.
func _update_action_sounds() -> void:
	var steering := controller.get_steering() if controller != null else 0.0
	var braking := (controller.get_brake() if controller != null else 0.0) > 0.0

	var turning := absf(steering) >= steer_sound_threshold and velocity.length() > 1.0
	if turning and not _was_turning:
		_sfx.play_notes([
			{"freq": 899.0, "dur": 0.10, "wave": ToneGenerator.SINE, "amp": 0.25},
			{"freq": 899.0, "dur": 0.10, "wave": ToneGenerator.SINE, "amp": 0.25},
		])
	_was_turning = turning

	if braking and not _was_braking:
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

func apply_damage(i: int) -> void:
	damage = i

func fetch_body() -> CharacterBody2D:
	push_error("Car has no body")
	return null

func fetch_car_name() -> String:
	return car_name

func set_car_name(s: String):
	car_name = s

func fetch_character_name() -> String:
	return character_name
