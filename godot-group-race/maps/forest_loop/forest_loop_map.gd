@tool
extends RingTrackMap

# Forest Loop — a code-built ring circuit. See res://maps/ring_track_map.gd for the
# shared course logic; this map only sets its size and theme.

func _init() -> void:
	cols = 13
	rows = 13
	road_w = 2
	display_name = "Forest Loop"
	bounds_color = Color("2f7d3a")
