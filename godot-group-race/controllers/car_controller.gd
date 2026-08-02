class_name CarController

extends RefCounted

# Input abstraction for a single car. Each car is handed its own controller and
# never sees any other car's controls. All values are normalized; subclasses
# (keyboard, gamepad, ...) override these to read their own device.

func get_steering() -> float:  # -1 (left) .. +1 (right)
	return 0.0

func get_throttle() -> float:  # 0 .. 1
	return 0.0

func get_brake() -> float:     # 0 .. 1
	return 0.0
