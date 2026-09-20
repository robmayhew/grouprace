extends Car

# Lion — see res://car.gd for the shared behaviour. This character only
# supplies its identity, its four stats, and the images in images/.

func _init() -> void:
	character_name = "Lion"
	theme_color = Color("c8902f")
	speed = 9.0
	acceleration = 8.0
	turn = 4.0
	recovery_time = 5.0
