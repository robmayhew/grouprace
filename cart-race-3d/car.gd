class_name Car
extends CharacterBody3D

# =============================================================================
# Car — common base class for every playable animal character (3D).
#
# Each character lives in its own folder under res://cars/<name>/ and extends
# this class. A subclass only needs to:
#   * set its identity   (character_name, theme_color)
#   * set its four stats  (speed, acceleration, turn, recovery_time)
#   * ship its images     (res://cars/<name>/images/<state>.svg)
# All driving physics, the per-state sprite swapping, and crash recovery are
# implemented here once, so every character shares identical behaviour and only
# differs by its stats and artwork. The car is drawn as a billboard sprite quad
# ($MeshInstance3D) whose texture is swapped to match what the car is doing.
# =============================================================================

# --- Identity -------------------------------------------------------------
@export var character_name: String = "Racer"
@export var theme_color: Color = Color.WHITE

# --- Adjustable stats (1..10, higher is always better) --------------------
@export_range(1.0, 10.0, 0.1) var speed: float = 6.0           # top speed
@export_range(1.0, 10.0, 0.1) var acceleration: float = 6.0    # how fast it builds speed
@export_range(1.0, 10.0, 0.1) var turn: float = 6.0            # steering rate
@export_range(1.0, 10.0, 0.1) var recovery_time: float = 6.0   # how quickly it recovers from a crash

# --- Input actions (set per player when the car is spawned) ---------------
@export var action_accel: String = "p1_accel"
@export var action_brake: String = "p1_brake"
@export var action_left: String = "p1_left"
@export var action_right: String = "p1_right"

# --- Fixed feel (shared by every character) -------------------------------
const FRICTION := 18.0
const GRAVITY := 24.0

# Current speed along the car's facing direction (negative = reversing).
var forward_speed: float = 0.0

# --- Stat -> physics mapping ----------------------------------------------
func _stat01(value: float) -> float:
	return clampf((value - 1.0) / 9.0, 0.0, 1.0)

func _max_speed() -> float:
	return lerpf(12.0, 34.0, _stat01(speed))

func _accel_force() -> float:
	return lerpf(14.0, 40.0, _stat01(acceleration))

func _brake_force() -> float:
	return _accel_force() * 1.4

func _turn_speed() -> float:
	return lerpf(1.6, 3.4, _stat01(turn))

func _recovery_seconds() -> float:
	return lerpf(2.5, 0.4, _stat01(recovery_time))

# --- Sprite / image state -------------------------------------------------
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

var _textures := {}
@onready var _sprite: MeshInstance3D = get_node_or_null("MeshInstance3D")
var _material: StandardMaterial3D
# When set (win / lose), the sprite locks to this state on the results screen.
var _forced_state: int = -1

# --- Crash / recovery -----------------------------------------------------
var _recovering := false
var _finished := false


func _ready() -> void:
	_load_state_textures()
	if _sprite:
		var base := _sprite.material_override as StandardMaterial3D
		_material = base.duplicate() if base else StandardMaterial3D.new()
		# Flat, double-sided, alpha-cut billboard so the art reads as a sprite
		# from both split-screen cameras.
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		_material.billboard_keep_scale = true
		_sprite.material_override = _material
	_set_sprite(State.POWER_POSE)


func _physics_process(delta: float) -> void:
	if _finished:
		# Coast to a halt but keep gravity so the car stays grounded.
		forward_speed = move_toward(forward_speed, 0.0, FRICTION * delta)
		_drive(0.0, delta)
		return

	var accel_input := Input.get_action_strength(action_accel) - Input.get_action_strength(action_brake)
	var steer_input := Input.get_action_strength(action_left) - Input.get_action_strength(action_right)

	_update_state_image(accel_input, steer_input)

	# Stunned: no throttle, sloppy steering.
	if _recovering:
		accel_input = minf(accel_input, 0.0)
		steer_input *= 0.4

	var top := _max_speed()
	if accel_input > 0.0:
		forward_speed = move_toward(forward_speed, top * accel_input, _accel_force() * delta)
	elif accel_input < 0.0:
		forward_speed = move_toward(forward_speed, top * accel_input * 0.5, _brake_force() * delta)
	else:
		forward_speed = move_toward(forward_speed, 0.0, FRICTION * delta)

	_drive(steer_input, delta)


# Applies steering + forward motion + gravity for this frame.
func _drive(steer_input: float, delta: float) -> void:
	if absf(forward_speed) > 0.2:
		var reverse_sign := signf(forward_speed)
		rotate_y(steer_input * _turn_speed() * delta * reverse_sign)

	var forward := -global_transform.basis.z
	velocity.x = forward.x * forward_speed
	velocity.z = forward.z * forward_speed

	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta

	move_and_slide()

	# A hard, roughly-horizontal hit (a wall or another car) triggers recovery.
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_normal().y < 0.5 and absf(forward_speed) > _max_speed() * 0.4:
			crash()
			break


# Puts the car into its stunned recovery state, unless it is already recovering.
func crash() -> void:
	if _recovering or _finished:
		return
	_recovering = true
	forward_speed *= 0.3
	await get_tree().create_timer(_recovery_seconds()).timeout
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
		for ext in exts:
			var path := base + ext
			if ResourceLoader.exists(path):
				var tex = load(path)
				if tex is Texture2D:
					_textures[state] = tex
					break

func _set_sprite(state: int) -> void:
	if _material == null:
		return
	if _textures.has(state):
		_material.albedo_texture = _textures[state]

func _update_state_image(accel_input: float, steer_input: float) -> void:
	if _forced_state != -1:
		return
	_set_sprite(_resolve_state(accel_input, steer_input))

func _resolve_state(accel_input: float, steer_input: float) -> int:
	if _recovering:
		return State.POWER_POSE
	if accel_input < 0.0:
		return State.BRAKE
	if steer_input >= 0.3:
		return State.TURN_LEFT
	if steer_input <= -0.3:
		return State.TURN_RIGHT
	if accel_input > 0.0:
		return State.GAS
	return State.POWER_POSE

# Loads images on demand — safe before _ready (e.g. a menu-preview instance).
func load_images() -> void:
	if _textures.is_empty():
		_load_state_textures()

func get_selection_texture() -> Texture2D:
	load_images()
	if _textures.has(State.SELECTION):
		return _textures[State.SELECTION]
	if _textures.has(State.POWER_POSE):
		return _textures[State.POWER_POSE]
	return null

# Lock the sprite to the victory / defeat pose on the results screen.
func finish(won: bool) -> void:
	_finished = true
	_forced_state = State.WIN if won else State.LOSE
	_set_sprite(_forced_state)


func set_input_actions(accel: String, brake: String, left: String, right: String) -> void:
	action_accel = accel
	action_brake = brake
	action_left = left
	action_right = right
