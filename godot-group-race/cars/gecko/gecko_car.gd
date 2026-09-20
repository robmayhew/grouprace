extends Car

# Gecko — see res://car.gd for the shared behaviour. This character only
# supplies its identity, its four stats, and the images in images/.

func _init() -> void:
	character_name = "Gecko"
	theme_color = Color("5fce3f")
	speed = 5.0
	acceleration = 6.0
	turn = 10.0
	recovery_time = 6.0
