class_name PowerUp

extends Node2D

signal power_up_hit(info: PowerUpHitInfo)

# Authored in the inspector: what this powerup does and for how long.
@export var effect: PowerUpEffect

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass




func _on_area_2d_area_entered(area: Area2D) -> void:
	print("POWER UP")
	var car := _find_car(area)
	var info := PowerUpHitInfo.new(self, car, PowerUpEffect.new())
	power_up_hit.emit(info)
	queue_free()


# The powerup's Area2D reports the *other* Area2D that overlapped it. That area
# lives under the car node, so walk up the tree until we reach the Car.
func _find_car(area: Area2D) -> Car:
	var node: Node = area
	while node != null and not (node is Car):
		node = node.get_parent()
	return node as Car
