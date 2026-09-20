@tool
extends RingTrackMap

# Sunny Speedway — a code-built ring circuit. See res://maps/ring_track_map.gd for the
# shared course logic; this map only sets its size and theme.

func _init() -> void:
	cols = 16
	rows = 11
	road_w = 3
	display_name = "Sunny Speedway"
	bounds_color = Color("e0a45b")
