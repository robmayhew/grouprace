class_name PowerUp

extends Node2D

signal power_up_hit(info: PowerUpHitInfo)

# Authored in the inspector: what this powerup does and for how long.
@export var effect: PowerUpEffect

# One icon per PowerUpEffect.Kind, shown on the powerup's Sprite2D so players can
# tell at a glance what they're about to pick up.
const ICONS := {
	PowerUpEffect.Kind.SPEED_BOOST: preload("res://assets/powerups/speed_boost.svg"),
	PowerUpEffect.Kind.FIRE: preload("res://assets/powerups/fire.svg"),
	PowerUpEffect.Kind.OIL_SLICK: preload("res://assets/powerups/oil_slick.svg"),
	PowerUpEffect.Kind.SHIELD: preload("res://assets/powerups/shield.svg"),
}

@onready var _sprite: Sprite2D = $Sprite2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_update_icon()

# Picks the sprite that matches this powerup's effect kind. Safe to call before
# an effect is assigned (the sprite is just left blank in that case).
func _update_icon() -> void:
	if effect == null or not ICONS.has(effect.kind):
		return
	_sprite.texture = ICONS[effect.kind]


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass




func _on_area_2d_area_entered(area: Area2D) -> void:
	print("POWER UP")
	var car := _find_car(area)
	var info := PowerUpHitInfo.new(self, car, effect)
	power_up_hit.emit(info)
	queue_free()


# The powerup's Area2D reports the *other* Area2D that overlapped it. That area
# lives under the car node, so walk up the tree until we reach the Car.
func _find_car(area: Area2D) -> Car:
	var node: Node = area
	while node != null and not (node is Car):
		node = node.get_parent()
	return node as Car
