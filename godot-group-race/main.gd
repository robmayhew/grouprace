extends Node2D

var cars: Array[PackedScene] = []
var maps: Array[PackedScene] = []
var maps_bounds:Vector2 = Vector2(600,800)

# Cars we watch against the map bounds, plus their last inside/outside state
# so we only log the moment they cross out (not every frame).
var tracked_cars: Array[Car] = []
var _car_inside := {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	cars = load_packed_scene("cars")
	maps = load_packed_scene("maps")
	var map = maps.get(0).instantiate() as Map
	add_child(map)
	
	maps_bounds = map.fetch_map_bounds()
	queue_redraw() # draw the red bounds outline now that we know the size

	var cam:Camera2D = Camera2D.new()
	var car = cars.get(0).instantiate() as Car
	car.add_child(cam)
	cam.make_current()


	add_child(car)
	_track_car(car)

	var waypoints:Array[Area2D] = map.fetch_waypoints()
	for i in waypoints.size():
		# bind(i) passes the waypoint index to the callback so we know which one.
		waypoints[i].body_entered.connect(_on_waypoint_entered.bind(i))

	var start_positions:Array[Area2D] = map.fetch_start_positions()
	var start1 = start_positions.get(0)
	car.position = start1.position

func _on_waypoint_entered(body: Node2D, index: int) -> void:
	print("Entered waypoint ", index, " -> ", body.name)


func _bounds_rect() -> Rect2:
	return Rect2(Vector2.ZERO, maps_bounds)


# Draw the map bounds as a red outline (Node2D draws in its own local space,
# and the map sits at the origin, so this lines up with the map).
func _draw() -> void:
	draw_rect(_bounds_rect(), Color.RED, false, 4.0)


func _track_car(c: Car) -> void:
	tracked_cars.append(c)
	_car_inside[c] = _bounds_rect().has_point(c.global_position)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var rect := _bounds_rect()
	for c in tracked_cars:
		var inside := rect.has_point(c.global_position)
		if _car_inside[c] and not inside:
			var d = c.fetch_damange()
			d = d + 1
			c.apply_damage(d)
			print("Car '", c.name, "' hit the map bounds at ", c.global_position, " damage is ", c.fetch_damange())
		_car_inside[c] = inside

var instances: Array[Node] = []

func load_packed_scene(dir_path:String) -> Array[PackedScene]:
	var result: Array[PackedScene] = []
	var dir := DirAccess.open("res://" + dir_path + "/")
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tscn"):
				var scene_path := ("res://" + dir_path).path_join(file_name)
				var packed_scene: PackedScene = load(scene_path)
				result.append(packed_scene)
				var instance: Node = packed_scene.instantiate()
				instances.append(instance)
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		push_error("An error occurred when trying to access the path.")
	return result	
