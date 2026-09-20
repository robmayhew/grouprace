@tool
extends RaceMap

# Desert Dash — a code-built circuit. See res://maps/race_map.gd for the shared course
# logic; this map only sets its size and theme.

func _init() -> void:
	map_name = "Desert Dash"
	ground_size = Vector2(150, 80)
	ground_color = Color("b5883f")
	road_color = Color("6e5a34")
	accent_color = Color("f2d98a")
