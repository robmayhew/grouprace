class_name PowerUpEffect
extends Resource

# Authored per-powerup in the inspector: describes what the powerup does and
# for how long. Attach one of these to a PowerUp via its `effect` property.
enum Kind { SPEED_BOOST, FIRE, OIL_SLICK, SHIELD}

@export var kind: Kind = Kind.SPEED_BOOST
@export var magnitude: float = 5.0      # meaning depends on kind (SPEED_BOOST: speed multiplier)
@export var duration: float = 20.0      # seconds the effect lasts (0 = instant / permanent)
