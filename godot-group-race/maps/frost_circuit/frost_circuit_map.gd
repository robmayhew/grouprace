@tool
extends RingTrackMap

# Frost Circuit — a code-built ring circuit. See res://maps/ring_track_map.gd for the
# shared course logic; this map only sets its size and theme.

func _init() -> void:
	cols = 12
	rows = 12
	road_w = 3
	display_name = "Frost Circuit"
	bounds_color = Color("4fb0c9")
