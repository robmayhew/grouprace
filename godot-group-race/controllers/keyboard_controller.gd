class_name KeyboardController

extends CarController

# Drives a car from four physical keys. Reading keys directly (not InputMap
# actions) lets two schemes -- e.g. arrows and WASD -- coexist on one keyboard.

var key_up: Key
var key_down: Key
var key_left: Key
var key_right: Key

func _init(up: Key, down: Key, left: Key, right: Key) -> void:
	key_up = up
	key_down = down
	key_left = left
	key_right = right

func get_steering() -> float:
	var right := 1.0 if Input.is_physical_key_pressed(key_right) else 0.0
	var left := 1.0 if Input.is_physical_key_pressed(key_left) else 0.0
	return right - left

func get_throttle() -> float:
	return 1.0 if Input.is_physical_key_pressed(key_up) else 0.0

func get_brake() -> float:
	return 1.0 if Input.is_physical_key_pressed(key_down) else 0.0
