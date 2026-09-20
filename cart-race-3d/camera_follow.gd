extends Camera3D

## Simple chase camera. Sits behind and above its target car and smoothly
## follows it. The target lives in the shared 3D world; this camera may be in
## a different SubViewport, which is fine because transforms are global.

@export var target_path: NodePath
@export var distance: float = 9.0
@export var height: float = 4.5
@export var look_height: float = 1.2
@export var follow_speed: float = 6.0

var target: Node3D


func _ready() -> void:
	if target == null and not target_path.is_empty():
		target = get_node_or_null(target_path)
	if target:
		# Snap to a sensible starting spot so the first frame isn't jarring.
		global_position = _desired_position()
		look_at(target.global_position + Vector3.UP * look_height, Vector3.UP)


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var weight := clampf(follow_speed * delta, 0.0, 1.0)
	global_position = global_position.lerp(_desired_position(), weight)
	look_at(target.global_position + Vector3.UP * look_height, Vector3.UP)


func _desired_position() -> Vector3:
	# +Z is behind the car (car faces -Z).
	var behind := target.global_transform.basis.z
	return target.global_position + behind * distance + Vector3.UP * height
