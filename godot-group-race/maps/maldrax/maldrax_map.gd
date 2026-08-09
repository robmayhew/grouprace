extends Map

func fetch_waypoints() -> Array[Area2D]:
	var result:Array[Area2D] = []
	var waypoints = get_tree().get_nodes_in_group("waypoint")
	for n in waypoints:
		result.append(n)
	return result
	
func fetch_start_positions() -> Array[Area2D]:
	var result:Array[Area2D] = []
	var waypoints = get_tree().get_nodes_in_group("start")
	for n in waypoints:
		result.append(n)
	return result
	
func fetch_map_bounds() -> Vector2:
	return Vector2(1000,1000)
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
