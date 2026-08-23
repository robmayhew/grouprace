@tool
extends Map

# --- Tilemap track --------------------------------------------------------
# The visible track is generated in code (see build_track) rather than hand
# painted into the .tscn, mirroring how Map.build_boundary_walls generates its
# collision walls. A single Kenney atlas supplies every tile; grass tiles carry
# a full-tile collision polygon so cars physically can't leave the road, while
# road tiles have no collision (they're drivable). Runs in the editor too (@tool)
# so the track is visible while laying the scene out.

const ATLAS_PATH := "res://assets/racing/spritesheet_tiles.png"
const TILE := 128          # px per tile in the Kenney pack
const COLS := 14           # track is COLS x ROWS tiles -> map_bounds 1792 x 1280
const ROWS := 10
const ROAD_W := 2          # road ring width in tiles (2 = twice as wide as a single lane)

# Atlas coordinates (pixel offset / 128) into spritesheet_tiles.png.
const GRASS := Vector2i(12, 2)       # land_grass04  — plain grass, off-track / infield (collidable)
const ROAD_FULL := Vector2i(4, 10)   # road_asphalt22 — plain asphalt, no curb (middle / inner corners)
const ROAD_CURB := Vector2i(5, 10)   # road_asphalt04 — straight, curb on the top edge only
const ROAD_CORNER := Vector2i(5, 11) # road_asphalt03 — outer rounded corner, curb in the top-left

# Per-cell tile transforms (dihedral flags OR-ed together). Rotations are the
# standard TileMap equivalences: 90° CW = transpose+flip_h, 90° CCW = transpose+flip_v.
const T_H := TileSetAtlasSource.TRANSFORM_FLIP_H
const T_V := TileSetAtlasSource.TRANSFORM_FLIP_V
const T_T := TileSetAtlasSource.TRANSFORM_TRANSPOSE

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

func fetch_start_finish_line() -> Area2D:
	return $StartFinishLine

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#build_track()
	super._ready()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


# Builds the TileSet + a "Track" TileMapLayer that paints a rounded-rectangle
# racing circuit: a grass field with a ROAD_W-tile-wide asphalt ring around the
# edge. Grass tiles are collidable (solid off-track), road tiles are not.
func build_track() -> void:
	# Idempotent: drop any track from a previous build before making a new one.
	var existing := get_node_or_null("Track")
	if existing:
		existing.free()

	var tex := load(ATLAS_PATH) as Texture2D
	if tex == null:
		push_warning("example_map: atlas not imported yet (%s) — open the project in the Godot editor once to import it." % ATLAS_PATH)
		return

	var tile_set := _build_tile_set(tex)

	var layer := TileMapLayer.new()
	layer.name = "Track"
	layer.tile_set = tile_set
	layer.z_index = -1  # ground sits under cars, waypoints and the bounds outline
	add_child(layer)

	# Paint every cell. The road is a ROAD_W-wide ring hugging the map edge; the
	# interior stays grass. Both edges of the ring carry a curb — the outer lane's
	# curb faces the map edge (rounded at the four corners), the inner lane's curb
	# faces the grass infield — with plain asphalt filling between them, so the
	# whole ring reads as one wide road framed by curbs on both sides.
	for x in COLS:
		for y in ROWS:
			var d := mini(mini(x, COLS - 1 - x), mini(y, ROWS - 1 - y))  # ring depth from edge
			var pos := Vector2i(x, y)
			var in_corner := (x < ROAD_W or x >= COLS - ROAD_W) and (y < ROAD_W or y >= ROWS - ROAD_W)
			if d >= ROAD_W:
				layer.set_cell(pos, 0, GRASS)                              # infield
			elif (x == 0 or x == COLS - 1) and (y == 0 or y == ROWS - 1):
				layer.set_cell(pos, 0, ROAD_CORNER, _corner_flags(x, y))   # outer rounded corner
			elif d == 0:
				layer.set_cell(pos, 0, ROAD_CURB, _curb_out_flags(x, y))   # outer curbed lane
			elif d == ROAD_W - 1 and not in_corner:
				layer.set_cell(pos, 0, ROAD_CURB, _curb_in_flags(x, y))    # inner curbed lane
			else:
				layer.set_cell(pos, 0, ROAD_FULL)                          # plain asphalt / inner corners


# Flip flags that point the corner tile's curb at the outside of the map corner.
func _corner_flags(x: int, y: int) -> int:
	var f := 0
	if x == COLS - 1:
		f |= T_H
	if y == ROWS - 1:
		f |= T_V
	return f


# Orients the outer curb straight so its curb faces the nearest map edge.
func _curb_out_flags(x: int, y: int) -> int:
	if y == 0:
		return 0            # curb up
	if y == ROWS - 1:
		return T_V          # curb down
	if x == 0:
		return T_T | T_V    # 90° CCW -> curb left
	return T_T | T_H        # 90° CW  -> curb right


# Orients the inner curb straight so its curb faces the grass infield (inward).
func _curb_in_flags(x: int, y: int) -> int:
	if y < ROAD_W:
		return T_V          # top band -> curb down
	if y >= ROWS - ROAD_W:
		return 0            # bottom band -> curb up
	if x < ROAD_W:
		return T_T | T_H    # left band -> curb right
	return T_T | T_V        # right band -> curb left


# Assembles a TileSet from the Kenney atlas: one atlas source holding just the
# tiles we use, plus a physics layer whose only collidable tile is grass.
func _build_tile_set(tex: Texture2D) -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	tile_set.add_physics_layer(0)  # defaults to collision_layer/mask 1 — matches the cars

	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE, TILE)
	for coord in [GRASS, ROAD_FULL, ROAD_CURB, ROAD_CORNER]:
		src.create_tile(coord)
	tile_set.add_source(src, 0)

	# Full-tile collision square on grass only, so the road ring is the sole
	# drivable surface (cars bump off the curbs / infield).
	var half := TILE / 2.0
	var square := PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half),
		Vector2(half, half), Vector2(-half, half),
	])
	var grass_data := src.get_tile_data(GRASS, 0)
	grass_data.add_collision_polygon(0)
	grass_data.set_collision_polygon_points(0, 0, square)

	return tile_set
