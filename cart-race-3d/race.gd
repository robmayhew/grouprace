extends Node

## Wires each chase camera to the car it should follow. The two SubViewports
## share one World3D (set in race.tscn), so all track/car geometry lives under
## the top viewport and both cameras render the same scene.

@onready var car1: CharacterBody3D = $Split/TopContainer/TopViewport/Car1
@onready var car2: CharacterBody3D = $Split/TopContainer/TopViewport/Car2
@onready var camera1: Camera3D = $Split/TopContainer/TopViewport/Camera1
@onready var camera2: Camera3D = $Split/BottomContainer/BottomViewport/Camera2


func _ready() -> void:
	camera1.target = car1
	camera2.target = car2
