extends Car
# Tron light-cycle style: constant forward speed and instant 90-degree turns.
# No coasting, no drift — the bike only ever travels along perpendicular axes.

# --- Tuning ---------------------------------------------------------------
@export var cruise_speed := 400.0       # constant forward speed (px/s)
@export var turn_step := 90.0           # degrees rotated per turn
@export var steer_threshold := 0.5      # how far steering must move to count as a turn
var moving = false
# --- State ----------------------------------------------------------------
var prev_steer := 0.0                   # last frame's steering, for edge detection


func _physics_process(_delta: float) -> void:
	_handle_turning()
	# Always drive straight ahead along the current heading.
	if moving:
		velocity = transform.x * cruise_speed
	else:
		velocity = Vector2.ZERO
		
	move_and_slide()


func _handle_turning() -> void:
	# With no controller the bike simply sits still.
	if controller == null:
		velocity = Vector2.ZERO
		return

	var steer := controller.get_steering()
	
	if controller.get_throttle() > 0:
		moving = true
	
	if controller.get_brake() > 0:
		moving = false

	# Only turn on the edge (neutral -> pushed). Holding the stick does nothing
	# extra, so one press = exactly one 90-degree turn.
	var pushed_now := absf(steer) >= steer_threshold
	var pushed_before := absf(prev_steer) >= steer_threshold
	if pushed_now and not pushed_before:
		if steer > 0.0:
			rotation += deg_to_rad(turn_step)    # turn right
		else:
			rotation -= deg_to_rad(turn_step)    # turn left

	prev_steer = steer
