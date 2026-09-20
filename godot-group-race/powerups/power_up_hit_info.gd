class_name PowerUpHitInfo
extends RefCounted

# Transient message carried by the PowerUp.power_up_hit signal. Bundles which
# powerup was hit, which car hit it, and the effect (kind / magnitude / duration).
var power_up: PowerUp        # the powerup that was hit
var car: Car                 # the car that hit it (may be null if unresolved)
var effect: PowerUpEffect    # effects + duration

func _init(p_power_up: PowerUp, p_car: Car, p_effect: PowerUpEffect) -> void:
	power_up = p_power_up
	car = p_car
	effect = p_effect
