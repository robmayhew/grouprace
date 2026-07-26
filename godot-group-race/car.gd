class_name Car

extends CharacterBody2D

var damage:int

func fetch_damange() -> int:
	return damage
	
func apply_damage(i:int) -> void:
	damage = i	

func fetch_body() -> CharacterBody2D:
	push_error("Car has no body")
	return null
