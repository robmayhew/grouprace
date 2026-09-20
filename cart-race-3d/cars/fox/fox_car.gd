extends Car

# Fox — see res://car.gd for the shared behaviour. This character only
# supplies its identity, its four stats, and the images in images/.

func _init() -> void:
	character_name = "Fox"
	theme_color = Color("e8622c")
	speed = 8.0
	acceleration = 7.0
	turn = 8.0
	recovery_time = 6.0
