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

# Thickness of the boundary walls in pixels.
const WALL_THICKNESS := 40.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_build_boundary_walls()

# Builds four collidable StaticBody2D walls around the map bounds so cars
# can't drive off the edge. Walls sit just outside the play area, with their
# inner faces flush against the bounds rectangle (0,0)..(bounds.x, bounds.y).
func _build_boundary_walls() -> void:
	var bounds := fetch_map_bounds()
	var t := WALL_THICKNESS

	var walls := StaticBody2D.new()
	walls.name = "BoundaryWalls"
	add_child(walls)

	# Each entry: rectangle size (Vector2) and center position (Vector2).
	var specs := [
		# Top
		[Vector2(bounds.x + t * 2.0, t), Vector2(bounds.x * 0.5, -t * 0.5)],
		# Bottom
		[Vector2(bounds.x + t * 2.0, t), Vector2(bounds.x * 0.5, bounds.y + t * 0.5)],
		# Left
		[Vector2(t, bounds.y + t * 2.0), Vector2(-t * 0.5, bounds.y * 0.5)],
		# Right
		[Vector2(t, bounds.y + t * 2.0), Vector2(bounds.x + t * 0.5, bounds.y * 0.5)],
	]

	for spec in specs:
		var shape := RectangleShape2D.new()
		shape.size = spec[0]
		var cs := CollisionShape2D.new()
		cs.shape = shape
		cs.position = spec[1]
		walls.add_child(cs)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
