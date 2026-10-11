class_name Dino
extends Node2D
## Placeholder surfer. Rides the water surface, gets thrown when the water
## rises fast under it, and wipes out if it lands at a bad angle.
## The node's origin is where the board touches the water.

signal wiped_out

@export var gravity: float = 900.0
@export var home_x: float = 220.0
@export var home_pull: float = 1.5  # drifts back toward home_x so it stays on screen
@export var slope_push: float = 0.6  # how much of gravity along the slope becomes sideways speed
@export var drag: float = 0.8
@export var max_speed_x: float = 260.0
@export var launch_speed: float = 150.0  # surface rising faster than this (px/s) throws the dino
@export var max_landing_angle_deg: float = 55.0

var water: Water
var velocity := Vector2.ZERO
var gravity_dir := Vector2.DOWN  # control scheme B tilts this
var on_surface := true


func reset() -> void:
	velocity = Vector2.ZERO
	on_surface = true
	rotation = 0.0
	position = Vector2(home_x, water.surface_y(home_x))


func _physics_process(delta: float) -> void:
	if water == null:
		return
	var g := gravity_dir * gravity
	velocity.x += (home_x - position.x) * home_pull * delta
	velocity.x -= velocity.x * drag * delta

	if on_surface:
		_ride(g, delta)
	else:
		_fly(g, delta)

	if position.x < -20.0 or position.x > 660.0 or position.y > 380.0:
		wiped_out.emit()


func _ride(g: Vector2, delta: float) -> void:
	var angle := water.slope_angle(position.x)
	var tangent := Vector2.RIGHT.rotated(angle)
	velocity.x += g.dot(tangent) * slope_push * tangent.x * delta
	velocity.x = clampf(velocity.x, -max_speed_x, max_speed_x)
	position.x += velocity.x * delta
	position.y = water.surface_y(position.x)
	rotation = lerp_angle(rotation, angle, 12.0 * delta)

	var surface_vy := water.surface_velocity_y(position.x)
	if surface_vy < -launch_speed:
		on_surface = false
		velocity.y = surface_vy


func _fly(g: Vector2, delta: float) -> void:
	velocity += g * delta
	position += velocity * delta
	# Nose follows the arc, so a steep fall onto a rising face is a wipeout.
	var travel := atan2(velocity.y, maxf(absf(velocity.x), 120.0))
	rotation = lerp_angle(rotation, travel, 3.0 * delta)

	var surf_y := water.surface_y(position.x)
	if position.y >= surf_y:
		var surf_angle := water.slope_angle(position.x)
		if absf(angle_difference(rotation, surf_angle)) > deg_to_rad(max_landing_angle_deg):
			wiped_out.emit()
			return
		on_surface = true
		position.y = surf_y
		velocity.y = 0.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var ink := Color("535353")
	draw_line(Vector2(-18, -1), Vector2(18, -1), ink, 3.0)  # board
	draw_rect(Rect2(-7, -26, 14, 23), ink)  # body
	draw_rect(Rect2(-1, -32, 14, 9), ink)  # head
	draw_rect(Rect2(7, -30, 2, 2), Color.WHITE)  # eye
	if not on_surface:
		draw_rect(Rect2(-9, -18, 4, 2), ink)  # arm out for balance
