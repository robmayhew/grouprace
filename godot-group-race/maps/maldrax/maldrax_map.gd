@tool
extends Map

var last_spawn:Node2D = null

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
	
	
@export var entity_to_spawn: PackedScene = preload("res://maps/maldrax/powerup.tscn")

@onready var spawn_zone: ReferenceRect = $Spawner/SpawnZone

func _ready() -> void:
	super._ready()  # base Map sets up audio + boundary walls (no-ops in the editor)
	if Engine.is_editor_hint():
		return
	_spawn_loop()

# Spawns one object, then schedules the next spawn 10–15s later. Each spawn frees
# the previous object (see spawn_object), so exactly one is ever alive at a time.
func _spawn_loop() -> void:
	spawn_object()
	var delay := randf_range(10.0, 15.0)
	# process_always = false so the timer pauses when the race pauses.
	get_tree().create_timer(delay, false).timeout.connect(_spawn_loop)

func spawn_object() -> void:
	if is_instance_valid(last_spawn):
		last_spawn.queue_free()
	last_spawn = null
	if not entity_to_spawn:
		print("Please assign an entity to spawn in the Inspector!")
		return
		
	# 1. Calculate the bounding box positions based on the UI layout
	var zone_position: Vector2 = spawn_zone.global_position
	var zone_size: Vector2 = spawn_zone.size
	
	# 2. Pick a random X and Y coordinate within those boundaries
	var random_x: float = randf_range(zone_position.x, zone_position.x + zone_size.x)
	var random_y: float = randf_range(zone_position.y, zone_position.y + zone_size.y)
	var random_position := Vector2(random_x, random_y)
	
	# 3. Create the instance of your object
	var new_entity: Node2D = entity_to_spawn.instantiate()
	last_spawn = new_entity
	var pu = new_entity as PowerUp
	pu.power_up_hit.connect(func():
		print("Hit power up")
		last_spawn = null		
		)
	# 4. Position the instance and add it to the scene tree
	new_entity.global_position = random_position
	get_parent().add_child(new_entity) 
