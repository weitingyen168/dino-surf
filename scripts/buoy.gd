class_name Buoy
extends Obstacle
## A rare floating buoy, in pixel art. Unlike the planted cacti it rides the swell, bobbing and leaning with it.
## It's solid: a spin doesn't cut it (ObstacleSpawner skips it), so the only way past is over it.
## The node's origin is its waterline.

const ART := preload("res://art/obstacles/buoy_float_01.png")
const PIXEL_SCALE := 1.5  # world px per art pixel
const WATERLINE_ROW := 32.0  # art row that sits on the water; the base below it is under
const LEAN := 0.6  # how much of the swell's slope it leans with


func _init() -> void:
	size = Vector2(40, 46)  # the hit box: body and mast above the water, a little inside the drawing to be fair
	sunk = 0.0


func top_y() -> float:
	return position.y - size.y


func hit_rect() -> Rect2:
	return Rect2(position + Vector2(-size.x / 2.0, -size.y), size)



func _physics_process(delta: float) -> void:
	position.x -= water.speed * delta
	position.y = water.surface_y(position.x)
	rotation = lerp_angle(rotation, water.slope_angle(position.x) * LEAN, 5.0 * delta)
	if position.x < -220.0:
		queue_free()


func _draw() -> void:
	var drawn := ART.get_size() * PIXEL_SCALE
	draw_texture_rect(ART, Rect2(-drawn.x / 2.0, -WATERLINE_ROW * PIXEL_SCALE, drawn.x, drawn.y), false)
