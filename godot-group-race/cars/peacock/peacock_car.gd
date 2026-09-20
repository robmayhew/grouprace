extends Car

# Peacock — see res://car.gd for the shared behaviour. This character only
# supplies its identity, its four stats, and the images in images/.

func _init() -> void:
	character_name = "Peacock"
	theme_color = Color("1e8fa6")
	speed = 7.0
	acceleration = 6.0
	turn = 7.0
	recovery_time = 8.0
