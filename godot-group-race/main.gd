extends Node2D

# Selectable content, discovered by scanning res://cars and res://maps for scenes.
# `car_instances` / `map_instances` hold one throwaway instance per scene so the
# menu can read a character's name, stats and preview art without starting a race.
var cars: Array[PackedScene] = []
var maps: Array[PackedScene] = []
var car_instances: Array[Car] = []
var map_instances: Array[Map] = []

var maps_bounds: Vector2 = Vector2(600, 800)

# Cars we watch against the map bounds, plus their last inside/outside state so we
# only react the moment they cross out (not every frame).
var tracked_cars: Array[Car] = []
var _car_inside := {}

# Player 2's camera lives in its own viewport, so it follows car2 manually.
var _cam2: Camera2D
var _car2: Car

# The current map and the cars racing on it.
var _map: Map
var _race_cars: Array[Car] = []

# --- Race clock -----------------------------------------------------------
# Counts up from the green light; each split-screen HUD shows it. Frozen when the
# race ends because pausing the tree stops this node's _process.
var _race_time := 0.0
var _race_running := false
var _time_labels: Array[Label] = []


func _ready() -> void:
	cars = _load_scenes("cars", car_instances)
	maps = _load_scenes("maps", map_instances)
	_show_menu()


# Builds and runs the race with the chosen scenes.
func _start_race(car1_scene: PackedScene, car2_scene: PackedScene, map_scene: PackedScene, p1_controller: CarController, p2_controller: CarController) -> void:
	_game_over = false
	_race_cars.clear()
	_time_labels.clear()

	# --- Split-screen plumbing --------------------------------------------
	var layer := CanvasLayer.new()
	add_child(layer)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	layer.add_child(hbox)

	var half1 := _make_split_viewport(hbox, Color.CYAN)
	var half2 := _make_split_viewport(hbox, Color.ORANGE)
	var vp1: SubViewport = half1["viewport"]
	var vp2: SubViewport = half2["viewport"]
	vp2.world_2d = vp1.get_world_2d()
	_time_labels = [half1["time_label"], half2["time_label"]]

	# --- Game world (lives inside viewport 1) -----------------------------
	var map = map_scene.instantiate() as Map
	vp1.add_child(map)
	_map = map
	map.play_start_sound()
	map.power_up_hit_by.connect(power_up_hit)
	maps_bounds = map.fetch_map_bounds()

	var waypoints: Array[Area2D] = map.fetch_waypoints()
	_waypoint_total = waypoints.size()

	var car = car1_scene.instantiate() as Car
	var car2 = car2_scene.instantiate() as Car
	car.set_car_name("P1 " + car.character_name)
	car2.set_car_name("P2 " + car2.character_name)
	_race_cars.append(car)
	_race_cars.append(car2)

	_register_score(car, half1["score_label"])
	_register_score(car2, half2["score_label"])

	car.set_controller(p1_controller)
	car2.set_controller(p2_controller)
	_car2 = car2
	vp1.add_child(car2)
	vp1.add_child(car)
	_track_car(car)
	_track_car(car2)

	# Player 1's camera rides along with car1 in viewport 1.
	var cam: Camera2D = Camera2D.new()
	car.add_child(cam)
	cam.make_current()

	# Player 2's camera is current in viewport 2 and follows car2 (see _process).
	_cam2 = Camera2D.new()
	vp2.add_child(_cam2)
	_cam2.make_current()

	for i in waypoints.size():
		waypoints[i].body_entered.connect(_on_waypoint_entered.bind(i))

	var start_finish_line: Area2D = map.fetch_start_finish_line()
	start_finish_line.body_entered.connect(on_start_finish_line_entered)

	var start_positions: Array[Area2D] = map.fetch_start_positions()
	var start1 = start_positions.get(0)
	car.position = start1.position
	car.rotation = start1.rotation
	var start2 = start_positions.get(1)
	car2.position = start2.position
	car2.rotation = start2.rotation

	# Start the race clock.
	_race_time = 0.0
	_race_running = true


# --- Startup menu ---------------------------------------------------------
var _menu_layer: CanvasLayer
var _p1_pick: Dictionary
var _p2_pick: Dictionary
var _map_option: OptionButton
var _p1_input_option: OptionButton
var _p2_input_option: OptionButton

# Selectable input sources: two keyboard schemes plus one entry per gamepad.
var _input_options: Array = []

func _build_input_options() -> void:
	_input_options = [
		{ "label": "Keyboard (Arrows)", "kind": "keyboard",
			"keys": [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT] },
		{ "label": "Keyboard (WASD)", "kind": "keyboard",
			"keys": [KEY_W, KEY_S, KEY_A, KEY_D] },
	]
	for device in Input.get_connected_joypads():
		_input_options.append({
			"label": "Gamepad %d: %s" % [device, Input.get_joy_name(device)],
			"kind": "gamepad",
			"device": device,
		})

func _make_controller(index: int) -> CarController:
	var desc: Dictionary = _input_options[index]
	if desc["kind"] == "gamepad":
		return GamepadController.new(desc["device"])
	var keys: Array = desc["keys"]
	return KeyboardController.new(keys[0], keys[1], keys[2], keys[3])


# Builds the character / map selection menu shown at startup.
func _show_menu() -> void:
	_menu_layer = CanvasLayer.new()
	add_child(_menu_layer)

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
	title.add_theme_font_size_override("font_size", 40)
	vbox.add_child(title)

	_add_controls_help(vbox)

	_build_input_options()
	var has_gamepad := _input_options.size() > 2
	var p1_input_default := 2 if has_gamepad else 0

	# The two character pickers sit side by side, each with a live preview.
	var pickers := HBoxContainer.new()
	pickers.add_theme_constant_override("separation", 40)
	pickers.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(pickers)

	_p1_pick = _build_character_picker(pickers, "Player 1", Color.CYAN, 0)
	_p2_pick = _build_character_picker(pickers, "Player 2", Color.ORANGE, 1)

	# Input + map rows below the pickers.
	_p1_input_option = _add_input_row(vbox, "Player 1 Input", p1_input_default)
	_p2_input_option = _add_input_row(vbox, "Player 2 Input", 1)
	_map_option = _add_menu_row(vbox, "Map")
	for m in map_instances:
		_map_option.add_item(m.fetch_map_name())
	if maps.size() > 0:
		_map_option.select(0)

	var start_button := Button.new()
	start_button.text = "Start Race"
	start_button.add_theme_font_size_override("font_size", 22)
	start_button.pressed.connect(_on_start_pressed)
	vbox.add_child(start_button)


# One player's character picker: a name dropdown, an art preview and stat bars,
# all kept in sync when the selection changes. Returns { "option": OptionButton }.
func _build_character_picker(parent: Control, player_label: String, accent: Color, default_index: int) -> Dictionary:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.custom_minimum_size = Vector2(240, 0)
	parent.add_child(col)

	var heading := Label.new()
	heading.text = player_label
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", accent)
	col.add_child(heading)

	var option := OptionButton.new()
	for inst in car_instances:
		option.add_item(inst.character_name)
	col.add_child(option)

	# Framed art preview.
	var frame := PanelContainer.new()
	var fstyle := StyleBoxFlat.new()
	fstyle.bg_color = Color(0.14, 0.14, 0.17)
	fstyle.border_color = accent
	fstyle.set_border_width_all(3)
	fstyle.set_corner_radius_all(8)
	frame.add_theme_stylebox_override("panel", fstyle)
	col.add_child(frame)

	var preview := TextureRect.new()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = Vector2(220, 120)
	frame.add_child(preview)

	# Four stat bars: Speed, Acceleration, Turn, Recovery.
	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 2)
	col.add_child(stats)
	var fills := {
		"speed": _make_stat_bar(stats, "Speed", accent),
		"acceleration": _make_stat_bar(stats, "Acceleration", accent),
		"turn": _make_stat_bar(stats, "Turn", accent),
		"recovery": _make_stat_bar(stats, "Recovery", accent),
	}

	var ctx := { "option": option, "preview": preview, "fills": fills }
	option.item_selected.connect(func(idx): _refresh_picker(ctx))
	if car_instances.size() > 0:
		option.select(clampi(default_index, 0, car_instances.size() - 1))
	_refresh_picker(ctx)
	return ctx


# Builds one labelled stat bar and returns the fill rect (resized in _refresh_picker).
func _make_stat_bar(parent: Control, label_text: String, accent: Color) -> ColorRect:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(96, 0)
	label.add_theme_font_size_override("font_size", 13)
	row.add_child(label)

	var track := ColorRect.new()
	track.color = Color(0.25, 0.25, 0.3)
	track.custom_minimum_size = Vector2(120, 12)
	row.add_child(track)

	var fill := ColorRect.new()
	fill.color = accent
	fill.position = Vector2(0, 0)
	fill.size = Vector2(0, 12)
	track.add_child(fill)
	return fill


# Refreshes a picker's preview art and stat bars to match its selected character.
func _refresh_picker(ctx: Dictionary) -> void:
	var idx: int = ctx["option"].selected
	if idx < 0 or idx >= car_instances.size():
		return
	var c: Car = car_instances[idx]
	ctx["preview"].texture = c.get_selection_texture()
	var fills: Dictionary = ctx["fills"]
	_set_stat_fill(fills["speed"], c.speed)
	_set_stat_fill(fills["acceleration"], c.acceleration)
	_set_stat_fill(fills["turn"], c.turn)
	_set_stat_fill(fills["recovery"], c.recovery_time)

func _set_stat_fill(fill: ColorRect, stat_value: float) -> void:
	# Stats are 1..10 (higher is better, recovery included); bar width tracks that.
	var t := clampf(stat_value / 10.0, 0.0, 1.0)
	fill.size = Vector2(120.0 * t, 12)


# Adds a "How to Play" block.
func _add_controls_help(parent: Control) -> void:
	var heading := Label.new()
	heading.text = "How to Play"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 20)
	parent.add_child(heading)

	var objective := Label.new()
	objective.text = "Pick a character and a map, then race — first to %d laps wins!" % WIN_SCORE
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(objective)

	var p1 := Label.new()
	p1.text = "Player 1 (cyan):   Arrow Keys   —   ↑ gas    ↓ brake    ← → steer"
	p1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p1.add_theme_color_override("font_color", Color.CYAN)
	parent.add_child(p1)

	var p2 := Label.new()
	p2.text = "Player 2 (orange):   W A S D   —   W gas    S brake    A D steer"
	p2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p2.add_theme_color_override("font_color", Color.ORANGE)
	parent.add_child(p2)

	var pad := Label.new()
	pad.text = "Or pick a gamepad below — left stick to steer, RT gas, LT brake."
	pad.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(pad)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	parent.add_child(spacer)


func _add_menu_row(parent: Control, label_text: String) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(120, 0)
	row.add_child(label)

	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(220, 0)
	row.add_child(option)
	return option

func _add_input_row(parent: Control, label_text: String, default_index: int) -> OptionButton:
	var option := _add_menu_row(parent, label_text)
	for desc in _input_options:
		option.add_item(desc["label"])
	if _input_options.size() > 0:
		option.select(clampi(default_index, 0, _input_options.size() - 1))
	return option


func _on_start_pressed() -> void:
	var p1_idx: int = _p1_pick["option"].selected
	var p2_idx: int = _p2_pick["option"].selected
	var map_idx := _map_option.selected
	var p1_controller := _make_controller(_p1_input_option.selected)
	var p2_controller := _make_controller(_p2_input_option.selected)
	_menu_layer.queue_free()
	_start_race(cars[p1_idx], cars[p2_idx], maps[map_idx], p1_controller, p2_controller)


# Builds one split-screen half: the game view plus a HUD (score + race time).
func _make_split_viewport(parent: Control, border_color: Color) -> Dictionary:
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

	# Colored frame.
	var frame := Panel.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = border_color
	style.set_border_width_all(4)
	frame.add_theme_stylebox_override("panel", style)
	half.add_child(frame)

	# HUD, top-left: score on top, race time below.
	var hud := VBoxContainer.new()
	hud.position = Vector2(12, 8)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	half.add_child(hud)

	var score_label := Label.new()
	score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_label.add_theme_color_override("font_color", border_color)
	hud.add_child(score_label)

	var time_label := Label.new()
	time_label.text = "Time  00:00.00"
	time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	time_label.add_theme_color_override("font_color", border_color)
	hud.add_child(time_label)

	return { "viewport": vp, "score_label": score_label, "time_label": time_label }


# --- Scoring --------------------------------------------------------------
var _scores := {}
var _score_labels := {}
var _hit_waypoints := {}
var _waypoint_total := 0

const WIN_SCORE := 3
var _game_over := false

func _register_score(c: Car, label: Label) -> void:
	_scores[c] = 0
	_hit_waypoints[c] = {}
	_score_labels[c] = label
	_update_score_label(c)

func _update_score_label(c: Car) -> void:
	var label: Label = _score_labels[c]
	label.text = "%s — Laps: %d/%d" % [c.fetch_car_name(), _scores[c], WIN_SCORE]

func _on_waypoint_entered(body: Node2D, index: int) -> void:
	if _game_over:
		return
	var car := body as Car
	if car == null:
		return
	if not _hit_waypoints.has(car):
		return
	var hits: Dictionary = _hit_waypoints[car]
	hits[index] = true

func on_start_finish_line_entered(body: Node2D) -> void:
	var car := body as Car
	if car == null:
		return
	if not _hit_waypoints.has(car):
		return
	var hits: Dictionary = _hit_waypoints[car]

	if _waypoint_total > 0 and hits.size() >= _waypoint_total:
		_scores[car] += 1
		hits.clear()
		if _map and _scores[car] < WIN_SCORE:
			_map.play_lap_sound()
	_update_score_label(car)

	if _scores[car] >= WIN_SCORE:
		_show_winner(car)


# Freezes the race and shows a "<car> Wins!" overlay with each car's win/lose pose.
func _show_winner(winner: Car) -> void:
	_game_over = true
	_race_running = false
	if _map:
		_map.play_win_sound()
	for c in _race_cars:
		c.stop_sounds()
		if c == winner:
			c.show_win()
		else:
			c.show_lose()
	get_tree().paused = true

	var layer := CanvasLayer.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.layer = 100
	add_child(layer)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.05, 0.08, 0.85)
	layer.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	# Winner's victory artwork.
	var art := TextureRect.new()
	art.texture = winner.get_selection_texture()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = Vector2(320, 160)
	vbox.add_child(art)

	var title := Label.new()
	title.text = "%s Wins!" % winner.fetch_car_name()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", winner.theme_color)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Finish time  %s   •   first to %d laps" % [_format_time(_race_time), WIN_SCORE]
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	var again := Button.new()
	again.text = "Play Again"
	again.add_theme_font_size_override("font_size", 22)
	again.pressed.connect(_on_play_again_pressed)
	vbox.add_child(again)

func _on_play_again_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _bounds_rect() -> Rect2:
	return Rect2(Vector2.ZERO, maps_bounds)

func _track_car(c: Car) -> void:
	tracked_cars.append(c)
	_car_inside[c] = _bounds_rect().has_point(c.global_position)


func _process(delta: float) -> void:
	# Advance and display the race clock (stops once the tree pauses on win).
	if _race_running:
		_race_time += delta
		var t := _format_time(_race_time)
		for lbl in _time_labels:
			lbl.text = "Time  " + t

	# Player 2's camera isn't parented to its car, so keep it on car2.
	if _cam2 and _car2:
		_cam2.global_position = _car2.global_position

	# Out-of-bounds cars take damage and are briefly stunned (recovery stat).
	var rect := _bounds_rect()
	for c in tracked_cars:
		var inside := rect.has_point(c.global_position)
		if _car_inside[c] and not inside:
			c.apply_damage(c.fetch_damange() + 1)
			c.crash()
		_car_inside[c] = inside


func _format_time(t: float) -> String:
	var minutes := int(t) / 60
	var seconds := int(t) % 60
	var centis := int((t - floorf(t)) * 100.0)
	return "%02d:%02d.%02d" % [minutes, seconds, centis]


# --- Scene discovery ------------------------------------------------------
# Scans a res:// folder tree for .tscn files whose root is a Car or Map, keeping
# both the PackedScene (to spawn) and one instance (for menu metadata/art).
func _load_scenes(dir_path: String, out_instances: Array) -> Array[PackedScene]:
	var result: Array[PackedScene] = []
	var dir := DirAccess.open("res://" + dir_path + "/")
	if dir == null:
		push_error("Could not open path: " + dir_path)
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			if file_name != "." and file_name != "..":
				result.append_array(_load_scenes(dir_path.path_join(file_name), out_instances))
		elif file_name.ends_with(".tscn"):
			var scene_path := ("res://" + dir_path).path_join(file_name)
			var packed: PackedScene = load(scene_path)
			var instance: Node = packed.instantiate()
			if instance is Car or instance is Map:
				out_instances.append(instance)
				result.append(packed)
		file_name = dir.get_next()
	dir.list_dir_end()
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
			c.apply_damage(c.fetch_damange() + int(effect.magnitude))
		PowerUpEffect.Kind.OIL_SLICK:
			c.apply_speed_boost(effect.magnitude, effect.duration)
		PowerUpEffect.Kind.SHIELD:
			c.apply_steer_bost(effect.magnitude, effect.duration)
