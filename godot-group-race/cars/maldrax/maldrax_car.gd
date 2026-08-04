extends Car

var acceleration := Vector2.ZERO
@export var engine_power := 800.0     
@export var braking := -450.0           # reverse / brake force
@export var steering_angle := 15.0      # how far the front wheels turn (degrees)
var steer_direction := 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _physics_process(delta: float) -> void:
	acceleration = Vector2.ZERO
	_get_input()

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
		
	rotation = steer_direction

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
