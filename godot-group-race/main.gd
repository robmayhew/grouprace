extends Node2D

# Draws the red map-bounds outline. It lives in the shared World2D (see
# _add_bounds_drawer) so it shows up in both split-screen halves.
class BoundsDrawer extends Node2D:
	var bounds: Rect2
	func _draw() -> void:
		draw_rect(bounds, Color.RED, false, 4.0)

var cars: Array[PackedScene] = []
var maps: Array[PackedScene] = []
var maps_bounds:Vector2 = Vector2(600,800)

# Cars we watch against the map bounds, plus their last inside/outside state
# so we only log the moment they cross out (not every frame).
var tracked_cars: Array[Car] = []
var _car_inside := {}

# Player 2's camera lives in its own viewport, so it can't just be parented to
# the car. We keep references and make it follow car2 every frame instead.
var _cam2: Camera2D
var _car2: Car

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	cars = load_packed_scene("cars")
	maps = load_packed_scene("maps")

	# --- Split-screen plumbing ---------------------------------------------
	# Two SubViewports side by side. Each SubViewport renders its own current
	# Camera2D independently (a single viewport can only show one camera at a
	# time), which is what makes this a *true* split screen. Both viewports
	# share the same World2D so they render the exact same game world.
	var layer := CanvasLayer.new()
	add_child(layer)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	layer.add_child(hbox)

	# Each half gets a colored frame + score label. Car 1 = cyan, Car 2 = orange.
	var half1 := _make_split_viewport(hbox, Color.CYAN)
	var half2 := _make_split_viewport(hbox, Color.ORANGE)
	var vp1: SubViewport = half1["viewport"]
	var vp2: SubViewport = half2["viewport"]
	# Player 2's viewport renders the same 2D world as player 1's.
	vp2.world_2d = vp1.get_world_2d()

	# --- Game world (lives inside viewport 1) ------------------------------
	var map = maps.get(0).instantiate() as Map
	vp1.add_child(map)

	maps_bounds = map.fetch_map_bounds()
	# A single drawer in the shared World2D renders in both split-screen halves.
	_add_bounds_drawer(vp1)

	var car = cars.get(1).instantiate() as Car
	var car2 = cars.get(0).instantiate() as Car
	car.set_car_name("Car 1")
	car2.set_car_name("Car 2")

	# Wire each car to its viewport's score label (waypoints hit, starts at 0).
	_register_score(car, half1["score_label"])
	_register_score(car2, half2["score_label"])

	# Assign each car its own input source. Cars stay agnostic about anyone
	# else's controls.
	# Player 1 -> Logitech F310. Set the back switch to "X" (XInput) and plug in
	# before launching. Steer = left stick, throttle = RT, brake = LT.
	car.set_controller(GamepadController.new(0))   # first connected pad
	# Player 2 -> keyboard (WASD).
	car2.set_controller(KeyboardController.new(KEY_W, KEY_S, KEY_A, KEY_D))

	# No pad handy? Fall back to a second keyboard scheme:
	#   car.set_controller(KeyboardController.new(KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT))
	_car2 = car2
	vp1.add_child(car2)
	vp1.add_child(car)
	_track_car(car)

	# Player 1's camera rides along with car1 and is current in viewport 1.
	var cam:Camera2D = Camera2D.new()
	car.add_child(cam)
	cam.make_current()

	# Player 2's camera is current in viewport 2 and follows car2 (see _process).
	_cam2 = Camera2D.new()
	vp2.add_child(_cam2)
	_cam2.make_current()

	var waypoints:Array[Area2D] = map.fetch_waypoints()
	for i in waypoints.size():
		# bind(i) passes the waypoint index to the callback so we know which one.
		waypoints[i].body_entered.connect(_on_waypoint_entered.bind(i))

	var start_positions:Array[Area2D] = map.fetch_start_positions()
	var start1 = start_positions.get(0)
	car.position = start1.position
	var start2 = start_positions.get(1)
	car2.position = start2.position


# Builds one split-screen half: the game view (SubViewport) with a colored frame
# and a score Label layered on top. Returns { "viewport": SubViewport,
# "score_label": Label } so the caller can wire the label to the right car.
func _make_split_viewport(parent: Control, border_color: Color) -> Dictionary:
	# A plain Control holds the stack: game view on the bottom, HUD on top.
	var half := Control.new()
	half.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	half.size_flags_vertical = Control.SIZE_EXPAND_FILL
	half.clip_contents = true
	parent.add_child(half)

	var container := SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	half.add_child(container)

	var vp := SubViewport.new()
	vp.handle_input_locally = false
	container.add_child(vp)

	# Frame: a transparent panel whose only job is the colored border.
	var frame := Panel.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = border_color
	style.set_border_width_all(4)
	frame.add_theme_stylebox_override("panel", style)
	half.add_child(frame)

	# Score label, top-left, colored to match the frame.
	var score_label := Label.new()
	score_label.position = Vector2(12, 8)
	score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_label.add_theme_color_override("font_color", border_color)
	half.add_child(score_label)

	return { "viewport": vp, "score_label": score_label }


# Adds a red map-bounds outline to a viewport's world.
func _add_bounds_drawer(vp: SubViewport) -> void:
	var drawer := BoundsDrawer.new()
	drawer.bounds = _bounds_rect()
	drawer.z_index = 100
	vp.add_child(drawer)
	drawer.queue_redraw()

# Per-car score = number of waypoints that car has hit, plus the Label showing it.
var _scores := {}
var _score_labels := {}

func _register_score(c: Car, label: Label) -> void:
	_scores[c] = 0
	_score_labels[c] = label
	_update_score_label(c)

func _update_score_label(c: Car) -> void:
	var label: Label = _score_labels[c]
	label.text = "%s — Waypoints: %d" % [c.fetch_car_name(), _scores[c]]

func _on_waypoint_entered(body: Node2D, index: int) -> void:
	var car := body as Car
	if car == null:
		return
	if _scores.has(car):
		_scores[car] += 1
		_update_score_label(car)
	print("Entered waypoint ", index, " -> ", car.fetch_car_name(), " score ", _scores.get(car, 0))


func _bounds_rect() -> Rect2:
	return Rect2(Vector2.ZERO, maps_bounds)


func _track_car(c: Car) -> void:
	tracked_cars.append(c)
	_car_inside[c] = _bounds_rect().has_point(c.global_position)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Player 2's camera isn't parented to its car (it lives in the other
	# viewport), so keep it centered on car2 manually.
	if _cam2 and _car2:
		_cam2.global_position = _car2.global_position

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
			if dir.current_is_dir():
				# Skip Godot's "." / ".." and recurse into real sub-folders
				if file_name != "." and file_name != "..":
					result.append_array(load_packed_scene(dir_path.path_join(file_name)))
			elif file_name.ends_with(".tscn"):
				var scene_path := ("res://" + dir_path).path_join(file_name)
				var packed_scene: PackedScene = load(scene_path)
				result.append(packed_scene)
				var instance: Node = packed_scene.instantiate()
				instances.append(instance)
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		push_error("An error occurred when trying to access the path: " + dir_path)
	return result
