extends Car

# Rabbit — see res://car.gd for the shared behaviour. This character only
# supplies its identity, its four stats, and the images in images/.

func _init() -> void:
	character_name = "Rabbit"
	theme_color = Color("c9bca8")
	speed = 6.0
	acceleration = 10.0
	turn = 9.0
	recovery_time = 7.0
