class_name GameCamera
extends Camera2D
## Rises to follow the dino when it flies high, and shakes on hits.

@export var dino: Dino
@export var view_zoom: float = 0.75  # < 1 zooms out: shows more ocean and sky (0.75 = about 850×480 of the world)
@export var rest_y: float = 160.0  # camera centre while the dino is on the water
@export var headroom: float = 70.0  # when the dino flies high, the camera centre stays this far below it
@export var follow: float = 5.0  # how quickly the camera catches up

var _shake := 0.0


func _ready() -> void:
	# Smooths motion between 60 Hz physics ticks on faster screens (fixes the stutter).
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	zoom = Vector2.ONE * view_zoom


func reset() -> void:
	_shake = 0.0


## Shakes by `px`, unless it's already shaking harder.
func shake(px: float) -> void:
	_shake = maxf(_shake, px)


func _physics_process(delta: float) -> void:
	_shake = move_toward(_shake, 0.0, 30.0 * delta)
	var target_y := minf(rest_y, dino.position.y + headroom)
	position.y = lerpf(position.y, target_y, follow * delta)
	offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
