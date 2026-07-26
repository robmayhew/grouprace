class_name Map
extends Node2D

func fetch_waypoints() -> Array[Area2D]:
	push_error("No waypoint defined")
	return []
	
func fetch_start_positions() -> Array[Area2D]:
	push_error("No start positions defined")
	return []
	
func fetch_map_bounds() -> Vector2:
	push_error("Map bounds not defined")
	return Vector2(100,100)
