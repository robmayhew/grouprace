extends Node2D

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

# The current map (for its event sounds) and the cars racing on it (so we can
# silence their engines when the race ends).
var _map: Map
var _race_cars: Array[Car] = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	cars = load_packed_scene("cars")
	maps = load_packed_scene("maps")

	# Let the players pick their cars and a map before building the race.
	_show_menu()


# Builds and runs the race with the chosen scenes. Called once the player
# presses Start in the menu (see _show_menu). Everything here used to live in
# _ready(); the only difference is the map/car scenes are now passed in instead
# of being hard-coded.
func _start_race(car1_scene: PackedScene, car2_scene: PackedScene, map_scene: PackedScene) -> void:
	_game_over = false
	_race_cars.clear()
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
	var map = map_scene.instantiate() as Map
	vp1.add_child(map)
	_map = map
	# Race is underway -> play the map's start sound.
	map.play_start_sound()
	
	map.power_up_hit_by.connect(power_up_hit)

	# The map draws its own bounds outline (see Map._draw); we still read the
	# size here for the out-of-bounds gameplay checks below.
	maps_bounds = map.fetch_map_bounds()

	# Waypoint scoring: a car scores a point once it has cleared *every* waypoint,
	# then the lap resets so it can score again by clearing them all once more.
	# We fetch the list once here and reuse it for the signal wiring below.
	var waypoints: Array[Area2D] = map.fetch_waypoints()
	_waypoint_total = waypoints.size()

	var car = car1_scene.instantiate() as Car
	var car2 = car2_scene.instantiate() as Car
	car.set_car_name("Car 1")
	car2.set_car_name("Car 2")
	_race_cars.append(car)
	_race_cars.append(car2)

	# Wire each car to its viewport's score label (waypoints hit, starts at 0).
	_register_score(car, half1["score_label"])
	_register_score(car2, half2["score_label"])

	# Assign each car its own input source. Cars stay agnostic about anyone
	# else's controls.
	# Player 1 -> Logitech F310. Set the back switch to "X" (XInput) and plug in
	# before launching. Steer = left stick, throttle = RT, brake = LT.
	# car.set_controller(GamepadController.new(0))   # first connected pad
	# Player 2 -> keyboard (WASD).
	car2.set_controller(KeyboardController.new(KEY_W, KEY_S, KEY_A, KEY_D))

	# No pad handy? Fall back to a second keyboard scheme:
	car.set_controller(KeyboardController.new(KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT))
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

	for i in waypoints.size():
		# bind(i) passes the waypoint index to the callback so we know which one.
		waypoints[i].body_entered.connect(_on_waypoint_entered.bind(i))

	var start_positions:Array[Area2D] = map.fetch_start_positions()
	var start1 = start_positions.get(0)
	car.position = start1.position
	car.rotation = start1.rotation
	var start2 = start_positions.get(1)
	car2.position = start2.position
	car2.rotation = start2.rotation


# --- Startup menu ---------------------------------------------------------
# The menu lives on its own CanvasLayer so it sits on top of everything. When
# Start is pressed we free the whole layer and hand the chosen scenes to
# _start_race. Kept references so the Start handler can read the selections.
var _menu_layer: CanvasLayer
var _p1_option: OptionButton
var _p2_option: OptionButton
var _map_option: OptionButton

# Turns a scene file path into a readable label, e.g.
# "res://cars/maldrax/maldrax_car.tscn" -> "maldrax_car".
func _scene_display_name(scene: PackedScene) -> String:
	return scene.resource_path.get_file().get_basename()

# Fills an OptionButton with one item per scene, then selects a default index
# (clamped so we never select out of range when there are few scenes).
func _populate_options(option: OptionButton, scenes: Array[PackedScene], default_index: int) -> void:
	for scene in scenes:
		option.add_item(_scene_display_name(scene))
	if scenes.size() > 0:
		option.select(clampi(default_index, 0, scenes.size() - 1))

# Builds the car/map selection menu shown at startup.
func _show_menu() -> void:
	_menu_layer = CanvasLayer.new()
	add_child(_menu_layer)

	# Opaque backdrop so the (empty) game world behind it doesn't show through.
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.1, 0.1, 0.12)
	_menu_layer.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_layer.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "Group Race"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Show players how to drive and how to win before they start.
	_add_controls_help(vbox)

	# Player 1 defaults to car index 1 and Player 2 to index 0, matching the
	# selections this game used before the menu existed.
	_p1_option = _add_menu_row(vbox, "Player 1 Car")
	_populate_options(_p1_option, cars, 1)
	_p2_option = _add_menu_row(vbox, "Player 2 Car")
	_populate_options(_p2_option, cars, 0)
	_map_option = _add_menu_row(vbox, "Map")
	_populate_options(_map_option, maps, 0)

	var start_button := Button.new()
	start_button.text = "Start"
	start_button.pressed.connect(_on_start_pressed)
	vbox.add_child(start_button)

# Adds a "How to Play" block: the objective plus each player's keys. The player
# colors match the split-screen frames (Car 1 = cyan, Car 2 = orange) and the
# keys match the controllers wired up in _start_race.
func _add_controls_help(parent: Control) -> void:
	var heading := Label.new()
	heading.text = "How to Play"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 20)
	parent.add_child(heading)

	var objective := Label.new()
	objective.text = "Drive through every waypoint to score a lap. First to %d wins!" % WIN_SCORE
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(objective)

	var p1 := Label.new()
	p1.text = "Player 1 (cyan):   Arrow Keys   —   ↑ accelerate    ↓ brake    ← → steer"
	p1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p1.add_theme_color_override("font_color", Color.CYAN)
	parent.add_child(p1)

	var p2 := Label.new()
	p2.text = "Player 2 (orange):   W A S D   —   W accelerate    S brake    A D steer"
	p2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p2.add_theme_color_override("font_color", Color.ORANGE)
	parent.add_child(p2)

	# A little breathing room before the car/map pickers.
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	parent.add_child(spacer)

# Adds a "<label> + OptionButton" row to the menu and returns the OptionButton.
func _add_menu_row(parent: Control, label_text: String) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(120, 0)
	row.add_child(label)

	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(option)
	return option

# Reads the selections, tears down the menu, and starts the race.
func _on_start_pressed() -> void:
	var p1_idx := _p1_option.selected
	var p2_idx := _p2_option.selected
	var map_idx := _map_option.selected
	_menu_layer.queue_free()
	_start_race(cars[p1_idx], cars[p2_idx], maps[map_idx])


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


# Per-car scoring: a car scores one point each time it has cleared *all* of the
# map's waypoints. _hit_waypoints tracks which waypoint indices a car has cleared
# in the current lap; once it holds them all we bump the score, then reset the lap
# so the car can score again by clearing every waypoint once more.
var _scores := {}
var _score_labels := {}
var _hit_waypoints := {}
var _waypoint_total := 0

# First car to reach this many points wins the race.
const WIN_SCORE := 3
# Set once a winner is decided so further waypoint hits are ignored.
var _game_over := false

func _register_score(c: Car, label: Label) -> void:
	_scores[c] = 0
	_hit_waypoints[c] = {}
	_score_labels[c] = label
	_update_score_label(c)

func _update_score_label(c: Car) -> void:
	var label: Label = _score_labels[c]
	var hits: int = _hit_waypoints[c].size()
	label.text = "%s — Score: %d  (%d/%d)" % [c.fetch_car_name(), _scores[c], hits, _waypoint_total]

func _on_waypoint_entered(body: Node2D, index: int) -> void:
	if _game_over:
		return
	var car := body as Car
	if car == null:
		return
	if not _hit_waypoints.has(car):
		return
	# A dictionary keyed by waypoint index acts as a set, so re-hitting the same
	# waypoint within a lap doesn't count twice.
	var hits: Dictionary = _hit_waypoints[car]
	hits[index] = true
	# All waypoints cleared -> score a point and reset for another lap.
	if _waypoint_total > 0 and hits.size() >= _waypoint_total:
		_scores[car] += 1
		hits.clear()
		print(car.fetch_car_name(), " cleared all waypoints -> score ", _scores[car])
		# Lap sound for a normal lap; the winning lap plays the win sound instead
		# (handled in _show_winner), so we don't stack both on the same frame.
		if _map and _scores[car] < WIN_SCORE:
			_map.play_lap_sound()
	_update_score_label(car)
	# First car to reach WIN_SCORE wins the race.
	if _scores[car] >= WIN_SCORE:
		_show_winner(car)


# Freezes the race and shows a full-screen "<car> Wins!" overlay with a button to
# play again. The overlay lives on its own CanvasLayer set to PROCESS_MODE_ALWAYS
# so its button still responds while the rest of the tree is paused.
func _show_winner(winner: Car) -> void:
	_game_over = true
	# Play the win sound before pausing, and silence the cars' engines.
	if _map:
		_map.play_win_sound()
	for c in _race_cars:
		c.stop_sounds()
	get_tree().paused = true

	var layer := CanvasLayer.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.layer = 100  # Sit above the split-screen HUD.
	add_child(layer)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.05, 0.08, 0.85)
	layer.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "%s Wins!" % winner.fetch_car_name()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "First to %d points" % WIN_SCORE
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	var again := Button.new()
	again.text = "Play Again"
	again.pressed.connect(_on_play_again_pressed)
	vbox.add_child(again)

# Unpauses and reloads the scene, which drops the player back at the car/map menu.
func _on_play_again_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


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
	
func power_up_hit(info: PowerUpHitInfo):
	var c := info.car
	if c == null:
		push_warning("Power up hit but no car resolved")
		return
	var effect := info.effect
	if effect == null:
		return
	print("%s hit a power up: kind=%s magnitude=%.1f duration=%.1fs" % [
		c.car_name, effect.kind, effect.magnitude, effect.duration])
	match effect.kind:
		PowerUpEffect.Kind.SPEED_BOOST:
			c.apply_speed_boost(effect.magnitude, effect.duration)
		PowerUpEffect.Kind.FIRE:
			# Offensive pickup: singes the car, adding to its damage tally.
			c.apply_damage(c.fetch_damange() + int(effect.magnitude))
		PowerUpEffect.Kind.OIL_SLICK:
			# Hazard: temporarily scales speed (magnitude < 1 slows the car down).
			c.apply_speed_boost(effect.magnitude, effect.duration)
		PowerUpEffect.Kind.SHIELD:
			c.apply_steer_bost(effect.magnitude, effect.duration)
