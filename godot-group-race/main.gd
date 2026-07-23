extends Node2D

var cars: Array[PackedScene] = []
var maps: Array[PackedScene] = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	cars = load_packed_scene("cars")
	maps = load_packed_scene("maps")
	var map = maps.get(0).instantiate()
	add_child(map)
	var cam:Camera2D = Camera2D.new()
	var car = cars.get(0).instantiate()
	car.add_child(cam)
	cam.make_current()
	
	
	add_child(car)
	
	var waypoints:Array[Area2D] = map.fetch_waypoints()
	for i in waypoints.size():
		# bind(i) passes the waypoint index to the callback so we know which one.
		waypoints[i].body_entered.connect(_on_waypoint_entered.bind(i))


func _on_waypoint_entered(body: Node2D, index: int) -> void:
	print("Entered waypoint ", index, " -> ", body.name)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

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
