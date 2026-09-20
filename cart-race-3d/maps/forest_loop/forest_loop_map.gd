@tool
extends RaceMap

# Forest Loop — a code-built circuit. See res://maps/race_map.gd for the shared course
# logic; this map only sets its size and theme.

func _init() -> void:
	map_name = "Forest Loop"
	ground_size = Vector2(110, 110)
	ground_color = Color("24402a")
	road_color = Color("3b4a3b")
	accent_color = Color("8fd36a")
