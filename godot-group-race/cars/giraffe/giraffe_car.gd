extends Car

# Giraffe — see res://car.gd for the shared behaviour. This character only
# supplies its identity, its four stats, and the images in images/.

func _init() -> void:
	character_name = "Giraffe"
	theme_color = Color("e4c264")
	speed = 8.0
	acceleration = 4.0
	turn = 3.0
	recovery_time = 4.0
