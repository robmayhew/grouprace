@tool
extends RingTrackMap

# Desert Dash — a code-built ring circuit. See res://maps/ring_track_map.gd for the
# shared course logic; this map only sets its size and theme.

func _init() -> void:
	cols = 18
	rows = 9
	road_w = 2
	display_name = "Desert Dash"
	bounds_color = Color("d98a3d")
