class_name Obstacle
extends Node2D
## Placeholder floating debris: a plank or crate, part sunk, tilting with the swell as it drifts left.
## The node's origin is the waterline at its centre.

var water: Water
var size := Vector2(30, 12)
var sunk := 0.35  # fraction of the height below the waterline


## The part above the waterline, in world space. Ignores the tilt (the swell is gentle).
func hit_rect() -> Rect2:
	var above := size.y * (1.0 - sunk)
	return Rect2(position + Vector2(-size.x / 2.0, -above), Vector2(size.x, above))


func _physics_process(delta: float) -> void:
	position.x -= water.speed * delta
	position.y = water.surface_y(position.x)
	rotation = lerp_angle(rotation, water.slope_angle(position.x), 5.0 * delta)
	if position.x < -60.0:
		queue_free()


func _draw() -> void:
	var ink := Color("535353")
	var top := -size.y * (1.0 - sunk)
	var r := Rect2(-size.x / 2.0, top, size.x, size.y)
	draw_rect(r, Color("b4b4b4"))  # the sunk part, seen through the water
	draw_rect(Rect2(r.position, Vector2(size.x, -top)), ink)
	# Plank seams so it reads as wood, not a rock.
	var seams := maxi(1, int(-top / 5.0))
	for i in range(1, seams + 1):
		var y := top - top * i / (seams + 1)
		draw_line(Vector2(r.position.x + 2, y), Vector2(r.end.x - 2, y), Color("8a8a8a"), 1.0)
	draw_rect(Rect2(r.position.x + 2, top + 2, 2, 2), Color("8a8a8a"))  # nail heads
	draw_rect(Rect2(r.end.x - 4, top + 2, 2, 2), Color("8a8a8a"))
