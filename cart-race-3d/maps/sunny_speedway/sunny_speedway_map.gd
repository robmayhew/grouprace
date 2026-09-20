@tool
extends RaceMap

# Sunny Speedway — a code-built circuit. See res://maps/race_map.gd for the shared course
# logic; this map only sets its size and theme.

func _init() -> void:
	map_name = "Sunny Speedway"
	ground_size = Vector2(130, 90)
	ground_color = Color("3a5a34")
	road_color = Color("444448")
	accent_color = Color("e0a45b")
