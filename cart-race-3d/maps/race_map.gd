@tool
class_name RaceMap
extends Node3D

# =============================================================================
# RaceMap — shared, code-built 3D circuit.
#
# A subclass sets the ground size and theme colours; this base builds the ground
# (with a boundary wall so cars can't drive off), drops the three lap waypoints
# (north / east / west) plus a bottom start-finish line, and reports two start
# slots. Every one of the four maps is just a different set of these numbers.
# =============================================================================

var map_name := "Track"
var ground_size := Vector2(120.0, 90.0)          # X (width) by Z (depth)
var ground_color := Color(0.16, 0.16, 0.19)
var road_color := Color(0.28, 0.28, 0.33)
var accent_color := Color(0.95, 0.85, 0.35)

var _finish: Area3D


func _ready() -> void:
	_build_ground()
	if Engine.is_editor_hint():
		return
	_build_course()


func fetch_map_name() -> String:
	return map_name

func fetch_bounds() -> Vector2:
	return ground_size

func fetch_waypoints() -> Array[Area3D]:
	var result: Array[Area3D] = []
	for n in get_tree().get_nodes_in_group("waypoint"):
		result.append(n)
	return result

func fetch_start_finish() -> Area3D:
	return _finish

# Two starting transforms on the bottom straight, side by side, facing the loop.
func fetch_start_positions() -> Array[Transform3D]:
	var rz := ground_size.y * 0.5 - 10.0
	var facing := Basis(Vector3.UP, deg_to_rad(90.0))  # face -X to begin the loop
	return [
		Transform3D(facing, Vector3(-6.0, 0.6, rz)),
		Transform3D(facing, Vector3(6.0, 0.6, rz)),
	]


# --- Ground + boundary ----------------------------------------------------
func _build_ground() -> void:
	var existing := get_node_or_null("Ground")
	if existing:
		existing.free()

	var w := ground_size.x
	var d := ground_size.y

	var ground := StaticBody3D.new()
	ground.name = "Ground"
	add_child(ground)
	if Engine.is_editor_hint() and owner:
		ground.owner = owner

	# Visible floor.
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(w, d)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = ground_color
	gmat.roughness = 0.95
	plane.material = gmat
	mesh.mesh = plane
	ground.add_child(mesh)

	# A painted road ring so the racing line reads on the flat ground.
	_add_road_ring(ground, w, d)

	# Floor collision.
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(w, 1.0, d)
	col.shape = box
	col.position = Vector3(0, -0.5, 0)
	ground.add_child(col)

	# Perimeter walls so cars stay on the map.
	var t := 2.0
	var hw := w * 0.5
	var hd := d * 0.5
	var wall_h := 3.0
	var specs := [
		[Vector3(w + t * 2.0, wall_h, t), Vector3(0, wall_h * 0.5, -hd - t * 0.5)],  # north
		[Vector3(w + t * 2.0, wall_h, t), Vector3(0, wall_h * 0.5, hd + t * 0.5)],   # south
		[Vector3(t, wall_h, d + t * 2.0), Vector3(-hw - t * 0.5, wall_h * 0.5, 0)],  # west
		[Vector3(t, wall_h, d + t * 2.0), Vector3(hw + t * 0.5, wall_h * 0.5, 0)],   # east
	]
	for spec in specs:
		var wc := CollisionShape3D.new()
		var wb := BoxShape3D.new()
		wb.size = spec[0]
		wc.shape = wb
		wc.position = spec[1]
		ground.add_child(wc)


# Lays a lighter-coloured rectangular ring on the ground to suggest the road.
func _add_road_ring(parent: Node3D, w: float, d: float) -> void:
	var rx := w * 0.32
	var rz := d * 0.32
	var lane := minf(w, d) * 0.16
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = road_color
	rmat.roughness = 0.9
	# Four straights (thin boxes) forming a loop, sitting just above the floor.
	var straights := [
		[Vector3(rx * 2.0 + lane, 0.1, lane), Vector3(0, 0.06, -rz)],  # north
		[Vector3(rx * 2.0 + lane, 0.1, lane), Vector3(0, 0.06, rz)],   # south
		[Vector3(lane, 0.1, rz * 2.0 + lane), Vector3(-rx, 0.06, 0)],  # west
		[Vector3(lane, 0.1, rz * 2.0 + lane), Vector3(rx, 0.06, 0)],   # east
	]
	for s in straights:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = s[0]
		bm.material = rmat
		mi.mesh = bm
		mi.position = s[1]
		parent.add_child(mi)


# --- Course triggers ------------------------------------------------------
func _build_course() -> void:
	var rx := ground_size.x * 0.32
	var rz := ground_size.y * 0.32
	var span_x := ground_size.x * 0.28
	var span_z := ground_size.y * 0.28

	_make_waypoint(Vector3(0, 0, -rz), Vector3(span_x, 5, 6))   # north
	_make_waypoint(Vector3(rx, 0, 0), Vector3(6, 5, span_z))    # east
	_make_waypoint(Vector3(-rx, 0, 0), Vector3(6, 5, span_z))   # west
	_finish = _make_area(Vector3(0, 0, rz), Vector3(span_x, 5, 6), "finish")


func _make_waypoint(pos: Vector3, size: Vector3) -> Area3D:
	return _make_area(pos, size, "waypoint")

func _make_area(pos: Vector3, size: Vector3, group: String) -> Area3D:
	var a := Area3D.new()
	a.position = pos
	a.add_to_group(group)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	a.add_child(cs)
	add_child(a)
	return a
