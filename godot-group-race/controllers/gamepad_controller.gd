class_name GamepadController

extends CarController

# Drives a car from one gamepad, identified by its device id. Multiple pads can
# each get their own controller by passing a different device id.

var device: int
var deadzone := 0.2

func _init(device_id: int) -> void:
	device = device_id

func get_steering() -> float:
	var x := Input.get_joy_axis(device, JOY_AXIS_LEFT_X)
	return 0.0 if absf(x) < deadzone else x

func get_throttle() -> float:
	# Trigger axes report 0..1 in Godot. Swap to a button read here if your pad
	# reports differently (e.g. Input.is_joy_button_pressed(device, JOY_BUTTON_A)).
	return Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT)

func get_brake() -> float:
	return Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT)
