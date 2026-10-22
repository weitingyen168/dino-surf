class_name Buoy
extends Obstacle
## A rare floating buoy, in pixel art. Unlike the planted cacti it rides the swell, bobbing and leaning with it.
## A spin knocks it tumbling away. The node's origin is its waterline.

const ART := preload("res://art/obstacles/buoy_float_01.png")
const PIXEL_SCALE := 1.5  # world px per art pixel
const WATERLINE_ROW := 32.0  # art row that sits on the water; the base below it is under
const LEAN := 0.6  # how much of the swell's slope it leans with

var _vel := Vector2.ZERO
var _spin := 0.0


func _init() -> void:
	size = Vector2(40, 46)  # the hit box: body and mast above the water, a little inside the drawing to be fair
	sunk = 0.0


func top_y() -> float:
	return position.y - size.y


func hit_rect() -> Rect2:
	return Rect2(position + Vector2(-size.x / 2.0, -size.y), size)


## A spin knocks it away rather than cutting it.
func slice(_at_y: float) -> void:
	sliced = true
	_vel = Vector2(randf_range(80, 160), randf_range(-260, -180))
	_spin = randf_range(6.0, 10.0)


func _physics_process(delta: float) -> void:
	position.x -= water.speed * delta
	if sliced:
		_vel.y += 600.0 * delta
		position += _vel * delta
		rotation += _spin * delta
	else:
		position.y = water.surface_y(position.x)
		rotation = lerp_angle(rotation, water.slope_angle(position.x) * LEAN, 5.0 * delta)
	if position.x < -220.0 or position.y > 900.0:
		queue_free()


func _draw() -> void:
	var drawn := ART.get_size() * PIXEL_SCALE
	draw_texture_rect(ART, Rect2(-drawn.x / 2.0, -WATERLINE_ROW * PIXEL_SCALE, drawn.x, drawn.y), false)
