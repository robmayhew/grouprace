@tool
extends RaceMap

# Frost Circuit — a code-built circuit. See res://maps/race_map.gd for the shared course
# logic; this map only sets its size and theme.

func _init() -> void:
	map_name = "Frost Circuit"
	ground_size = Vector2(100, 100)
	ground_color = Color("5f7f92")
	road_color = Color("889fae")
	accent_color = Color("d6f0ff")
