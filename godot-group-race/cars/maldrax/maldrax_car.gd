extends Car

const SPEED = 1200
const POWER = 10

func _physics_process(_delta: float) -> void:
	var THROTTLE = controller.get_throttle() > 0;
	var BRAKE = controller.get_brake() > 0;
	var TURN_LEFT = controller.get_steering() > 0;
	var TURN_RIGHT = controller.get_steering() < 0;
	var drag = 10
	if(BRAKE):
		velocity = velocity + vectorFromAngle(rotation,-1 * POWER)
	if(THROTTLE):
		velocity = velocity + vectorFromAngle(rotation,1 * POWER * speed_multiplier);
	if(TURN_RIGHT):
		var amt = 0.1 * steer_multiplier
		rotation += amt
		velocity = velocity.rotated(amt)
	if(TURN_LEFT):
		var amt = -0.1 * steer_multiplier
		rotation += amt
		velocity = velocity.rotated(amt)
	velocity = velocity.move_toward(Vector2.ZERO, drag * _delta)
	move_and_slide()

func vectorFromAngle(r:float, m:float) -> Vector2:
	return Vector2.from_angle(r) * m
