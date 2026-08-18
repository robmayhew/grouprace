class_name PowerUp

extends Node2D

signal power_up_hit
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass




func _on_area_2d_area_entered(area: Area2D) -> void:
	print("POWER UP")
	power_up_hit.emit()
	queue_free()
	pass # Replace with function body.
