class_name Car

extends CharacterBody2D

var damage:int
var car_name:String = "Give Me A name"

# This car's own input source. A car only ever knows about its own controller,
# never any other car's controls.
var controller: CarController

func set_controller(c: CarController) -> void:
	controller = c

func fetch_controller() -> CarController:
	return controller

func fetch_damange() -> int:
	return damage
	
func apply_damage(i:int) -> void:
	damage = i	

func fetch_body() -> CharacterBody2D:
	push_error("Car has no body")
	return null

func fetch_car_name() -> String:
	return car_name
	
func set_car_name(s:String):
	car_name = s
