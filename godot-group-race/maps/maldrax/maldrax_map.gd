@tool
extends Map

# Tracks the currently-alive spawned object for each spawn zone, keyed by the
# spawner ReferenceRect. Each zone spawns/frees independently, so multiple
# powerups can be alive at once (one per zone).
var last_spawns: Dictionary = {}

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
	return $StartLine
	
	
@export var entity_to_spawn: PackedScene = preload("res://maps/maldrax/powerup.tscn")

@onready var spawn_zone: ReferenceRect = $Spawner/SpawnZone

func _ready() -> void:
	super._ready()  # base Map sets up audio + boundary walls (no-ops in the editor)
	if Engine.is_editor_hint():
		return
	_spawn_loop()

# Respawns one object in every spawn zone, freeing that zone's previous object
# first, then schedules the next cycle 10–15s later. One object stays alive per
# zone, so multiple spawn areas each keep their own powerup.
func _spawn_loop() -> void:
	var spawns = get_tree().get_nodes_in_group("spawner")
	for spawn in spawns:
		var spawn_obj = spawn as ReferenceRect
		spawn_object(spawn_obj)
	var delay := randf_range(10.0, 15.0)
	# process_always = false so the timer pauses when the race pauses.
	get_tree().create_timer(delay, false).timeout.connect(_spawn_loop)

func spawn_object(local_spawn_zone:ReferenceRect) -> void:
	# Free only this zone's previous object, leaving other zones untouched.
	var previous = last_spawns.get(local_spawn_zone)
	if is_instance_valid(previous):
		previous.queue_free()
	last_spawns.erase(local_spawn_zone)
	if not entity_to_spawn:
		print("Please assign an entity to spawn in the Inspector!")
		return
	print("Spawning powerup")
	# 1. Calculate the bounding box positions based on the UI layout
	var zone_position: Vector2 = local_spawn_zone.global_position
	var zone_size: Vector2 = local_spawn_zone.size

	# 2. Pick a random X and Y coordinate within those boundaries
	var random_x: float = randf_range(zone_position.x, zone_position.x + zone_size.x)
	var random_y: float = randf_range(zone_position.y, zone_position.y + zone_size.y)
	var random_position := Vector2(random_x, random_y)

	# 3. Create the instance of your object
	var new_entity: Node2D = entity_to_spawn.instantiate()
	last_spawns[local_spawn_zone] = new_entity
	var pu = new_entity as PowerUp
	pu.effect = _random_effect()


	pu.power_up_hit.connect(func(info: PowerUpHitInfo):
		print("Hit power up")
		# Clear this zone's slot only if it still points at the hit object.
		if last_spawns.get(local_spawn_zone) == new_entity:
			last_spawns.erase(local_spawn_zone)
		# Bubble the payload up to main.gd via map.gd's signal.
		power_up_hit_by.emit(info)
		)
	# 4. Position the instance and add it to the scene tree
	new_entity.global_position = random_position
	get_parent().add_child(new_entity)

# Builds a randomly-chosen powerup effect. magnitude means different things per
# kind (see main.gd's power_up_hit): a speed/steer multiplier, a slowdown factor,
# or a damage amount — so each kind gets its own sensible value.
func _random_effect() -> PowerUpEffect:
	var kinds := PowerUpEffect.Kind.values()
	var kind: int = kinds[randi() % kinds.size()]
	var effect := PowerUpEffect.new()
	effect.kind = kind
	match kind:
		PowerUpEffect.Kind.SPEED_BOOST:
			effect.magnitude = 2.0   # 2x speed
			effect.duration = 5.0
		PowerUpEffect.Kind.FIRE:
			effect.magnitude = 3.0   # damage dealt
			effect.duration = 0.0
		PowerUpEffect.Kind.OIL_SLICK:
			effect.magnitude = 0.5   # half speed
			effect.duration = 3.0
		PowerUpEffect.Kind.SHIELD:
			effect.magnitude = 1.5   # steer boost
			effect.duration = 8.0
	return effect
