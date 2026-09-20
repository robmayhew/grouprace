extends Node

# =============================================================================
# Race — top-level controller for the split-screen 3D racer.
#
# Flow: scan res://cars and res://maps for scenes -> show a character + map
# select menu -> spawn the chosen cars and map into the shared 3D world, wire up
# the chase cameras, a per-player HUD (laps + race time) and lap scoring, and run
# the race to a winner.
# =============================================================================

@onready var _top_vp: SubViewport = $Split/TopContainer/TopViewport
@onready var _camera1: Camera3D = $Split/TopContainer/TopViewport/Camera1
@onready var _camera2: Camera3D = $Split/BottomContainer/BottomViewport/Camera2

# Discovered content, plus one throwaway instance each for menu metadata / art.
var cars: Array[PackedScene] = []
var maps: Array[PackedScene] = []
var car_instances: Array[Car] = []
var map_instances: Array[RaceMap] = []

const WIN_LAPS := 3

# --- Race state -----------------------------------------------------------
var _map: RaceMap
var _race_cars: Array[Car] = []
var _scores := {}
var _hit_waypoints := {}
var _waypoint_total := 0
var _game_over := false

var _race_time := 0.0
var _race_running := false
# Per player: { "car": Car, "label": Label, "accent": Color }.
var _huds: Array = []


func _ready() -> void:
	cars = _load_scenes("cars", car_instances)
	maps = _load_scenes("maps", map_instances)
	_show_menu()


func _process(delta: float) -> void:
	if _race_running and not _game_over:
		_race_time += delta
	for hud in _huds:
		_update_hud(hud)


# =============================================================================
# Menu
# =============================================================================
var _menu_layer: CanvasLayer
var _p1_pick: Dictionary
var _p2_pick: Dictionary
var _map_option: OptionButton

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
	title.text = "Cart Race 3D"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	vbox.add_child(title)

	_add_controls_help(vbox)

	var pickers := HBoxContainer.new()
	pickers.add_theme_constant_override("separation", 40)
	pickers.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(pickers)

	# Player 1 drives with WASD (top screen), Player 2 with the arrow keys.
	_p1_pick = _build_character_picker(pickers, "Player 1 (WASD)", Color(0.9, 0.3, 0.25), 0)
	_p2_pick = _build_character_picker(pickers, "Player 2 (Arrows)", Color(0.3, 0.55, 1.0), 1)

	var map_row := HBoxContainer.new()
	map_row.alignment = BoxContainer.ALIGNMENT_CENTER
	map_row.add_theme_constant_override("separation", 10)
	vbox.add_child(map_row)
	var map_label := Label.new()
	map_label.text = "Map"
	map_label.custom_minimum_size = Vector2(120, 0)
	map_row.add_child(map_label)
	_map_option = OptionButton.new()
	_map_option.custom_minimum_size = Vector2(220, 0)
	for m in map_instances:
		_map_option.add_item(m.fetch_map_name())
	if maps.size() > 0:
		_map_option.select(0)
	map_row.add_child(_map_option)

	var start_button := Button.new()
	start_button.text = "Start Race"
	start_button.add_theme_font_size_override("font_size", 22)
	start_button.pressed.connect(_on_start_pressed)
	vbox.add_child(start_button)


func _add_controls_help(parent: Control) -> void:
	var heading := Label.new()
	heading.text = "Pick a character and a map — first to %d laps wins!" % WIN_LAPS
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(heading)

	var p1 := Label.new()
	p1.text = "Player 1 (top):   W accelerate   S brake/reverse   A / D steer"
	p1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p1.add_theme_color_override("font_color", Color(0.95, 0.5, 0.4))
	parent.add_child(p1)

	var p2 := Label.new()
	p2.text = "Player 2 (bottom):   ↑ accelerate   ↓ brake/reverse   ← / → steer"
	p2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p2.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
	parent.add_child(p2)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	parent.add_child(spacer)


# One player's character picker: name dropdown, art preview and stat bars.
func _build_character_picker(parent: Control, player_label: String, accent: Color, default_index: int) -> Dictionary:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.custom_minimum_size = Vector2(240, 0)
	parent.add_child(col)

	var heading := Label.new()
	heading.text = player_label
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 20)
	heading.add_theme_color_override("font_color", accent)
	col.add_child(heading)

	var option := OptionButton.new()
	for inst in car_instances:
		option.add_item(inst.character_name)
	col.add_child(option)

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
	option.item_selected.connect(func(_idx): _refresh_picker(ctx))
	if car_instances.size() > 0:
		option.select(clampi(default_index, 0, car_instances.size() - 1))
	_refresh_picker(ctx)
	return ctx


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
	fill.size = Vector2(0, 12)
	track.add_child(fill)
	return fill

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
	fill.size = Vector2(120.0 * clampf(stat_value / 10.0, 0.0, 1.0), 12)


func _on_start_pressed() -> void:
	var p1_idx: int = _p1_pick["option"].selected
	var p2_idx: int = _p2_pick["option"].selected
	var map_idx := _map_option.selected
	_menu_layer.queue_free()
	_start_race(cars[p1_idx], cars[p2_idx], maps[map_idx])


# =============================================================================
# Race setup
# =============================================================================
func _start_race(car1_scene: PackedScene, car2_scene: PackedScene, map_scene: PackedScene) -> void:
	_game_over = false
	_race_cars.clear()
	_huds.clear()

	_map = map_scene.instantiate() as RaceMap
	_top_vp.add_child(_map)

	var waypoints := _map.fetch_waypoints()
	_waypoint_total = waypoints.size()
	var starts := _map.fetch_start_positions()

	var car1 := car1_scene.instantiate() as Car
	var car2 := car2_scene.instantiate() as Car
	car1.set_input_actions("p1_accel", "p1_brake", "p1_left", "p1_right")
	car2.set_input_actions("p2_accel", "p2_brake", "p2_left", "p2_right")
	_top_vp.add_child(car1)
	_top_vp.add_child(car2)
	if starts.size() > 0:
		car1.global_transform = starts[0]
	if starts.size() > 1:
		car2.global_transform = starts[1]
	_race_cars = [car1, car2]

	_camera1.target = car1
	_camera2.target = car2

	# Per-player HUD overlay (P1 top, P2 in the lower half).
	_build_huds(car1, Color(0.95, 0.5, 0.4), car2, Color(0.5, 0.7, 1.0))

	# Scoring.
	for c in _race_cars:
		_scores[c] = 0
		_hit_waypoints[c] = {}
	for i in waypoints.size():
		waypoints[i].body_entered.connect(_on_waypoint_entered.bind(i))
	var finish := _map.fetch_start_finish()
	if finish:
		finish.body_entered.connect(_on_finish_entered)

	_race_time = 0.0
	_race_running = true


func _build_huds(car1: Car, accent1: Color, car2: Car, accent2: Color) -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var l1 := _make_hud_label(root, accent1, 0.0)
	var l2 := _make_hud_label(root, accent2, 0.5)
	_huds = [
		{ "car": car1, "label": l1, "accent": accent1 },
		{ "car": car2, "label": l2, "accent": accent2 },
	]
	for hud in _huds:
		_update_hud(hud)

func _make_hud_label(parent: Control, accent: Color, anchor_top: float) -> Label:
	var label := Label.new()
	label.anchor_top = anchor_top
	label.offset_left = 16
	label.offset_top = 12
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", accent)
	label.add_theme_font_size_override("font_size", 20)
	parent.add_child(label)
	return label

func _update_hud(hud: Dictionary) -> void:
	var c: Car = hud["car"]
	var laps: int = _scores.get(c, 0)
	hud["label"].text = "%s\nLaps %d/%d   Time %s" % [
		c.character_name, laps, WIN_LAPS, _format_time(_race_time)]


# =============================================================================
# Scoring
# =============================================================================
func _on_waypoint_entered(body: Node3D, index: int) -> void:
	if _game_over:
		return
	var car := body as Car
	if car == null or not _hit_waypoints.has(car):
		return
	_hit_waypoints[car][index] = true

func _on_finish_entered(body: Node3D) -> void:
	if _game_over:
		return
	var car := body as Car
	if car == null or not _hit_waypoints.has(car):
		return
	var hits: Dictionary = _hit_waypoints[car]
	if _waypoint_total > 0 and hits.size() >= _waypoint_total:
		_scores[car] += 1
		hits.clear()
	if _scores[car] >= WIN_LAPS:
		_show_winner(car)


func _show_winner(winner: Car) -> void:
	_game_over = true
	_race_running = false
	for c in _race_cars:
		c.finish(c == winner)

	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.05, 0.08, 0.88)
	layer.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var art := TextureRect.new()
	art.texture = winner.get_selection_texture()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = Vector2(320, 160)
	vbox.add_child(art)

	var title := Label.new()
	title.text = "%s Wins!" % winner.character_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", winner.theme_color)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Finish time  %s   •   first to %d laps" % [_format_time(_race_time), WIN_LAPS]
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	var again := Button.new()
	again.text = "Play Again"
	again.add_theme_font_size_override("font_size", 22)
	again.pressed.connect(func(): get_tree().reload_current_scene())
	vbox.add_child(again)


# =============================================================================
# Helpers
# =============================================================================
func _format_time(t: float) -> String:
	var minutes := int(t) / 60
	var seconds := int(t) % 60
	var centis := int((t - floorf(t)) * 100.0)
	return "%02d:%02d.%02d" % [minutes, seconds, centis]


# Scans a res:// folder tree for .tscn files whose root is a Car or RaceMap,
# keeping both the PackedScene (to spawn) and one instance (for menu metadata).
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
			if instance is Car or instance is RaceMap:
				out_instances.append(instance)
				result.append(packed)
		file_name = dir.get_next()
	dir.list_dir_end()
	return result
