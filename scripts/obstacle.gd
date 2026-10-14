class_name Obstacle
extends Node2D
## Placeholder floating obstacle (rock or buoy). Drifts left with the swell and bobs on the surface.
## The node's origin is the waterline at its centre.

var water: Water
var size := Vector2(14, 18)


## Box above the waterline, in world space.
func hit_rect() -> Rect2:
	return Rect2(position + Vector2(-size.x / 2.0, -size.y), size)


func _physics_process(delta: float) -> void:
	position.x -= water.swell_speed * delta
	position.y = water.surface_y(position.x)
	if position.x < -40.0:
		queue_free()


func _draw() -> void:
	var ink := Color("535353")
	var w := size.x / 2.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(-w, 0), Vector2(-w + 2, -size.y + 3), Vector2(0, -size.y), Vector2(w - 2, -size.y + 3), Vector2(w, 0)]), ink)
