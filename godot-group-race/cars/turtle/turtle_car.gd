extends Car

# Turtle — see res://car.gd for the shared behaviour. This character only
# supplies its identity, its four stats, and the images in images/.

func _init() -> void:
	character_name = "Turtle"
	theme_color = Color("3f8f4f")
	speed = 3.0
	acceleration = 3.0
	turn = 5.0
	recovery_time = 10.0
