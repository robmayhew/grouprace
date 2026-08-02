extends Car

# --- Tuning ---------------------------------------------------------------
@export var engine_power := 800.0       # forward acceleration force
@export var braking := -450.0           # reverse / brake force
@export var max_speed_reverse := 250.0
@export var friction := -55.0           # constant slowdown
@export var drag := -0.06               # slowdown that grows with speed
@export var wheel_base := 70.0          # distance between front and rear axle (px)
@export var steering_angle := 15.0      # how far the front wheels turn (degrees)
@export var slip_speed := 400.0         # speed at which the car starts to slide
@export var traction_slow := 10.0       # grip at low speed
@export var traction_fast := 2.5        # grip at high speed

# --- State ----------------------------------------------------------------
var acceleration := Vector2.ZERO
var steer_direction := 0.0


func _physics_process(delta: float) -> void:
	acceleration = Vector2.ZERO
	_get_input()
	_apply_friction(delta)
	_calculate_steering(delta)
	velocity += acceleration * delta
	move_and_slide()


func _get_input() -> void:
	# All input comes from this car's own injected controller. With no
	# controller the car simply sits still.
	if controller == null:
		return

	# Steering: only sets which way the front wheels point.
	steer_direction = controller.get_steering() * deg_to_rad(steering_angle)

	# Throttle / brake act along the car's forward axis (+X).
	var throttle := controller.get_throttle()
	var brake := controller.get_brake()
	if throttle > 0.0:
		acceleration = transform.x * engine_power * throttle
	if brake > 0.0:
		acceleration = transform.x * braking * brake


func _apply_friction(delta: float) -> void:
	# Come to a full stop instead of creeping forever.
	if velocity.length() < 5.0 and acceleration == Vector2.ZERO:
		velocity = Vector2.ZERO
	var friction_force := velocity * friction * delta
	var drag_force := velocity * velocity.length() * drag * delta
	acceleration += drag_force + friction_force


func _calculate_steering(delta: float) -> void:
	# Bicycle model: move a front and rear wheel, derive a new heading from them.
	var rear_wheel := position - transform.x * wheel_base / 2.0
	var front_wheel := position + transform.x * wheel_base / 2.0
	rear_wheel += velocity * delta
	front_wheel += velocity.rotated(steer_direction) * delta

	var new_heading := rear_wheel.direction_to(front_wheel)

	# Less grip at high speed so the car can drift.
	var traction := traction_slow
	if velocity.length() > slip_speed:
		traction = traction_fast

	var d := new_heading.dot(velocity.normalized())
	if d > 0:
		velocity = velocity.lerp(new_heading * velocity.length(), traction * delta)
	if d < 0:
		# Reversing.
		velocity = -new_heading * min(velocity.length(), max_speed_reverse)

	rotation = new_heading.angle()
