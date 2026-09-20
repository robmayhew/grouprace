extends CharacterBody3D

## Basic arcade car controller for the split-screen racing prototype.
## Movement is kinematic: accelerate forward/back, steer to rotate, gravity
## keeps the car on the track. Each player instance uses a different set of
## input actions (see the exported action names) so both cars can be driven
## from the keyboard at the same time.

@export_group("Handling")
@export var max_speed: float = 22.0
@export var acceleration: float = 26.0
@export var braking: float = 38.0
@export var friction: float = 18.0
@export var turn_speed: float = 2.4
@export var gravity: float = 24.0

@export_group("Input actions")
@export var action_accel: String = "p1_accel"
@export var action_brake: String = "p1_brake"
@export var action_left: String = "p1_left"
@export var action_right: String = "p1_right"

@export_group("Appearance")
@export var body_color: Color = Color(0.9, 0.2, 0.2)
## Sprite shown when driving straight and when turning.
@export var texture_straight: Texture2D = preload("res://example_car.png")
@export var texture_turning: Texture2D = preload("res://example_car_2.png")
## How hard the player must press a steer key before the turning sprite shows.
@export var steer_display_threshold: float = 0.1

# Current speed along the car's facing direction (negative = reversing).
var forward_speed: float = 0.0

@onready var _sprite: MeshInstance3D = $MeshInstance3D
# Per-instance material so swapping the texture on one car never affects the other.
var _material: StandardMaterial3D


func _ready() -> void:
	if _sprite:
		# Copy the scene material (which the car instances would otherwise share)
		# so each car has its own, then start on the straight sprite.
		var base := _sprite.material_override as StandardMaterial3D
		_material = base.duplicate() if base else StandardMaterial3D.new()
		_material.albedo_texture = texture_straight
		_sprite.material_override = _material


func _physics_process(delta: float) -> void:
	var accel_input := Input.get_action_strength(action_accel) - Input.get_action_strength(action_brake)
	var steer_input := Input.get_action_strength(action_left) - Input.get_action_strength(action_right)

	# Show the turning sprite while a steer key is held, straight sprite otherwise.
	_update_sprite(steer_input)

	# Throttle / brake / coast.
	if accel_input > 0.0:
		forward_speed = move_toward(forward_speed, max_speed * accel_input, acceleration * delta)
	elif accel_input < 0.0:
		# Reverse tops out at half speed.
		forward_speed = move_toward(forward_speed, max_speed * accel_input * 0.5, braking * delta)
	else:
		forward_speed = move_toward(forward_speed, 0.0, friction * delta)

	# Steering scales with speed and flips when reversing, like a real car.
	if absf(forward_speed) > 0.2:
		var reverse_sign := signf(forward_speed)
		rotate_y(steer_input * turn_speed * delta * reverse_sign)

	# Drive along the car's forward axis (-Z is forward in Godot).
	var forward := -global_transform.basis.z
	velocity.x = forward.x * forward_speed
	velocity.z = forward.z * forward_speed

	# Gravity so the car stays grounded on the track.
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta

	move_and_slide()


func _update_sprite(steer_input: float) -> void:
	if _material == null:
		return
	var turning := absf(steer_input) > steer_display_threshold
	_material.albedo_texture = texture_turning if turning else texture_straight
