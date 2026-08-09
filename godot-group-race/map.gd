@tool
class_name Map
extends Node2D

# Thickness of the boundary walls in pixels.
const WALL_THICKNESS := 40.0

# Play-area size, set per-map in the Inspector. The bounds rectangle runs from
# (0,0) to (map_bounds.x, map_bounds.y). Changing it redraws the outline live.
@export var map_bounds: Vector2 = Vector2(1000, 1000):
	set(value):
		map_bounds = value
		queue_redraw()
# Outline style for the bounds rectangle (drawn in editor and at runtime).
@export var bounds_color: Color = Color.RED
@export var bounds_width: float = 4.0

# --- Sound ----------------------------------------------------------------
# Map event sounds are synthesized at runtime (see ToneGenerator) — no sample
# files. main.gd calls the play_* methods below at the matching moments.
var _synth: ToneGenerator

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Don't spawn physics walls or audio while editing in the 2D editor.
	if Engine.is_editor_hint():
		return
	_synth = ToneGenerator.new()
	# Keep synthesizing (e.g. the win jingle) even after the race pauses the tree.
	_synth.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_synth)
	build_boundary_walls()

# --- Event sounds ---------------------------------------------------------
# Countdown: three low beeps and a higher "go".
func play_start_sound() -> void:
	if _synth == null:
		return
	_synth.play_notes([
		{"freq": 440.0, "dur": 0.15, "wave": ToneGenerator.SQUARE, "amp": 0.3},
		{"freq": 0.0, "dur": 0.20, "wave": ToneGenerator.SQUARE, "amp": 0.0},
		{"freq": 440.0, "dur": 0.15, "wave": ToneGenerator.SQUARE, "amp": 0.3},
		{"freq": 0.0, "dur": 0.20, "wave": ToneGenerator.SQUARE, "amp": 0.0},
		{"freq": 440.0, "dur": 0.15, "wave": ToneGenerator.SQUARE, "amp": 0.3},
		{"freq": 0.0, "dur": 0.20, "wave": ToneGenerator.SQUARE, "amp": 0.0},
		{"freq": 880.0, "dur": 0.35, "wave": ToneGenerator.SQUARE, "amp": 0.35},
	])

# Lap: a short two-note rising chime.
func play_lap_sound() -> void:
	if _synth == null:
		return
	_synth.play_notes([
		{"freq": 784.0, "dur": 0.10, "wave": ToneGenerator.TRIANGLE, "amp": 0.35},
		{"freq": 1047.0, "dur": 0.16, "wave": ToneGenerator.TRIANGLE, "amp": 0.35},
	])

# Win: a short chiptune arpeggio fanfare (C-E-G-C major).
func play_win_sound() -> void:
	if _synth == null:
		return
	_synth.play_notes([
		{"freq": 523.0, "dur": 0.12, "wave": ToneGenerator.SQUARE, "amp": 0.32},
		{"freq": 659.0, "dur": 0.12, "wave": ToneGenerator.SQUARE, "amp": 0.32},
		{"freq": 784.0, "dur": 0.12, "wave": ToneGenerator.SQUARE, "amp": 0.32},
		{"freq": 1047.0, "dur": 0.30, "wave": ToneGenerator.SQUARE, "amp": 0.36},
	])

# Draws the bounds rectangle outline. Runs in the editor (via @tool) and at
# runtime, so the play area is visible while laying out a map and during play.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, map_bounds), bounds_color, false, bounds_width)

func fetch_waypoints() -> Array[Area2D]:
	push_error("No waypoint defined")
	return []

func fetch_start_positions() -> Array[Area2D]:
	push_error("No start positions defined")
	return []

func fetch_map_bounds() -> Vector2:
	return map_bounds

func fetch_map_name() -> String:
	push_error("Map name not found");
	return "No Name"
	
	

# Builds four collidable StaticBody2D walls around the map bounds so cars
# can't drive off the edge. Walls sit just outside the play area, with their
# inner faces flush against the bounds rectangle (0,0)..(bounds.x, bounds.y).
func build_boundary_walls() -> void:
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
