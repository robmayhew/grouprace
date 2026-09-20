@tool
class_name RingTrackMap
extends Map

# =============================================================================
# RingTrackMap — shared, code-built racing circuit.
#
# A subclass only sets the grid size, road width and theme colour; this base:
#   * paints a grass field with a drivable asphalt ring around the edge,
#   * drops the three lap waypoints (top / right / left) and the bottom
#     start-finish line, plus two start slots,
#   * and periodically spawns power-ups on the road.
# Every one of the four maps is just a different set of these numbers, so all of
# them share identical, tested course logic.
# =============================================================================

const ATLAS_PATH := "res://assets/racing/spritesheet_tiles.png"
const TILE := 128                       # px per tile in the Kenney atlas
const GRASS := Vector2i(12, 2)          # collidable off-track grass
const ROAD := Vector2i(4, 10)           # plain drivable asphalt
const POWERUP_SCENE := preload("res://powerups/powerup.tscn")

# --- Per-map knobs (subclasses override in _init) -------------------------
var cols := 14                          # track width in tiles
var rows := 10                          # track height in tiles
var road_w := 2                         # road ring thickness in tiles
var display_name := "Ring Track"
var spawn_powerups := true

# Populated when the course is built so main.gd can wire scoring to it.
var _finish_line: Area2D


func _ready() -> void:
	# Bounds must be known before the base builds its boundary walls.
	map_bounds = Vector2(cols * TILE, rows * TILE)
	_build_track()
	super._ready()                      # boundary walls + audio (runtime only)
	if Engine.is_editor_hint():
		return
	_build_course()
	if spawn_powerups:
		# Delay the first spawn a beat so we're not adding siblings while the
		# viewport is still parenting this map (and it gives players a head start).
		get_tree().create_timer(2.0, false).timeout.connect(_spawn_loop)


func fetch_map_bounds() -> Vector2:
	return Vector2(cols * TILE, rows * TILE)

func fetch_map_name() -> String:
	return display_name

func fetch_waypoints() -> Array[Area2D]:
	var result: Array[Area2D] = []
	for n in get_tree().get_nodes_in_group("waypoint"):
		result.append(n)
	return result

func fetch_start_positions() -> Array[Area2D]:
	var result: Array[Area2D] = []
	for n in get_tree().get_nodes_in_group("start"):
		result.append(n)
	return result

func fetch_start_finish_line() -> Area2D:
	return _finish_line


# --- Track painting -------------------------------------------------------
# A grass field with a `road_w`-tile asphalt ring hugging the edge. Grass is
# collidable (solid), road is not, so the ring is the only drivable surface.
func _build_track() -> void:
	var existing := get_node_or_null("Track")
	if existing:
		existing.free()

	var tex := load(ATLAS_PATH) as Texture2D
	if tex == null:
		push_warning("RingTrackMap: atlas not imported yet (%s) — open the project in the Godot editor once." % ATLAS_PATH)
		return

	var layer := TileMapLayer.new()
	layer.name = "Track"
	layer.tile_set = _build_tile_set(tex)
	layer.z_index = -1
	add_child(layer)

	for x in cols:
		for y in rows:
			var d := mini(mini(x, cols - 1 - x), mini(y, rows - 1 - y))
			var coord := ROAD if d < road_w else GRASS
			layer.set_cell(Vector2i(x, y), 0, coord)


func _build_tile_set(tex: Texture2D) -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	tile_set.add_physics_layer(0)

	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE, TILE)
	for coord in [GRASS, ROAD]:
		src.create_tile(coord)
	tile_set.add_source(src, 0)

	# Only grass carries collision, so cars are confined to the road ring.
	var half := TILE / 2.0
	var square := PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half),
		Vector2(half, half), Vector2(-half, half),
	])
	var grass_data := src.get_tile_data(GRASS, 0)
	grass_data.add_collision_polygon(0)
	grass_data.set_collision_polygon_points(0, 0, square)
	return tile_set


# --- Course nodes ---------------------------------------------------------
func _build_course() -> void:
	var w := float(cols * TILE)
	var h := float(rows * TILE)
	var band := float(road_w * TILE)      # road ring thickness
	var half_band := band * 0.5
	var bar := 48.0                       # trigger thickness across the road

	# Three lap waypoints, each a bar spanning the full road width.
	_make_area("waypoint", Vector2(w * 0.5, half_band), Vector2(bar, band))          # top
	_make_area("waypoint", Vector2(w - half_band, h * 0.5), Vector2(band, bar))      # right
	_make_area("waypoint", Vector2(half_band, h * 0.5), Vector2(band, bar))          # left

	# Start-finish line across the bottom straight.
	_finish_line = _make_area("finish", Vector2(w * 0.5, h - half_band), Vector2(bar, band))

	# Two start slots on the bottom straight, side by side, facing +X (right).
	var start_x := w * 0.32
	var start_y := h - half_band
	var gap := minf(60.0, half_band - 24.0)
	_make_start(Vector2(start_x, start_y - gap))
	_make_start(Vector2(start_x, start_y + gap))


func _make_area(group: String, pos: Vector2, size: Vector2) -> Area2D:
	var a := Area2D.new()
	a.position = pos
	a.add_to_group(group)
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	cs.shape = shape
	a.add_child(cs)
	add_child(a)
	return a


func _make_start(pos: Vector2) -> Area2D:
	var a := _make_area("start", pos, Vector2(40, 40))
	a.rotation = 0.0
	return a


# --- Power-ups ------------------------------------------------------------
# Keeps one power-up alive at a time, respawning it on the road every 10-15s.
var _current_powerup: Node2D

func _spawn_loop() -> void:
	if is_instance_valid(_current_powerup):
		_current_powerup.queue_free()
	_current_powerup = _spawn_powerup()
	get_tree().create_timer(randf_range(10.0, 15.0), false).timeout.connect(_spawn_loop)


func _spawn_powerup() -> Node2D:
	var pu := POWERUP_SCENE.instantiate() as PowerUp
	pu.effect = _random_effect()
	pu.global_position = _random_road_point()
	pu.power_up_hit.connect(func(info: PowerUpHitInfo):
		if _current_powerup == pu:
			_current_powerup = null
		power_up_hit_by.emit(info))
	get_parent().add_child(pu)
	return pu


# Picks a random point that sits on the drivable road ring.
func _random_road_point() -> Vector2:
	var band := float(road_w * TILE)
	var w := float(cols * TILE)
	var h := float(rows * TILE)
	match randi() % 4:
		0: return Vector2(randf_range(band, w - band), band * 0.5)             # top
		1: return Vector2(w - band * 0.5, randf_range(band, h - band))         # right
		2: return Vector2(randf_range(band, w - band), h - band * 0.5)         # bottom
		_: return Vector2(band * 0.5, randf_range(band, h - band))             # left


func _random_effect() -> PowerUpEffect:
	var kinds := PowerUpEffect.Kind.values()
	var effect := PowerUpEffect.new()
	effect.kind = kinds[randi() % kinds.size()]
	match effect.kind:
		PowerUpEffect.Kind.SPEED_BOOST:
			effect.magnitude = 2.0
			effect.duration = 5.0
		PowerUpEffect.Kind.FIRE:
			effect.magnitude = 3.0
			effect.duration = 0.0
		PowerUpEffect.Kind.OIL_SLICK:
			effect.magnitude = 0.5
			effect.duration = 3.0
		PowerUpEffect.Kind.SHIELD:
			effect.magnitude = 1.5
			effect.duration = 8.0
	return effect
