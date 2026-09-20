extends Car

# Golden Retriever — see res://car.gd for the shared behaviour. This character only
# supplies its identity, its four stats, and the images in images/.

func _init() -> void:
	character_name = "Golden Retriever"
	theme_color = Color("e0a45b")
	speed = 6.0
	acceleration = 7.0
	turn = 6.0
	recovery_time = 7.0
