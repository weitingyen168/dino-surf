class_name Dino
extends Node2D
## Placeholder surfer. Stays at a fixed x like the Chrome dino; the water and
## obstacles move past it. Gets thrown when the water rises fast under it,
## and wipes out if it lands at a bad angle.
## The node's origin is where the board touches the water.

signal wiped_out

@export var gravity: float = 900.0
@export var home_x: float = 220.0
@export var launch_speed: float = 150.0  # surface rising faster than this (px/s) throws the dino
@export var launch_boost: float = 1.6  # multiplies the surface's speed at launch, so throws go higher than the water
@export var max_landing_angle_deg: float = 55.0
@export var jump_speed: float = 330.0  # upward speed when the player pops the dino
@export var hold_gravity_scale: float = 0.45  # gravity while rising with the button held: tap = short hop, hold = high jump

var water: Water
var velocity := Vector2.ZERO
var gravity_dir := Vector2.DOWN  # control scheme B tilts this
var on_surface := true
var holding := false  # set by Main each tick


func reset() -> void:
	velocity = Vector2.ZERO
	on_surface = true
	rotation = 0.0
	position = Vector2(home_x, water.surface_y(home_x))
	reset_physics_interpolation()  # teleport, don't slide from where it wiped out


## Body box in world space, for obstacle hits. Ignores rotation; a little smaller than the drawing to be fair.
func hit_rect() -> Rect2:
	return Rect2(position + Vector2(-14, -30), Vector2(26, 30))


## Pops the dino off the water. Does nothing in the air.
func jump() -> void:
	if not on_surface:
		return
	on_surface = false
	velocity.y = -jump_speed


func _physics_process(delta: float) -> void:
	if water == null:
		return
	position.x = home_x
	if on_surface:
		_ride(delta)
	else:
		_fly(delta)

	if position.y > 380.0:
		wiped_out.emit()


func _ride(delta: float) -> void:
	position.y = water.surface_y(position.x)
	rotation = lerp_angle(rotation, water.slope_angle(position.x), 12.0 * delta)

	var surface_vy := water.surface_velocity_y(position.x)
	if surface_vy < -launch_speed:
		on_surface = false
		velocity.y = surface_vy * launch_boost


func _fly(delta: float) -> void:
	var grav_scale := hold_gravity_scale if holding and velocity.y < 0.0 else 1.0
	velocity.y += gravity_dir.y * gravity * grav_scale * delta
	position.y += velocity.y * delta
	# Nose follows the arc (forward speed = how fast the world scrolls), so a steep fall onto a rising face is a wipeout.
	var travel := atan2(velocity.y, water.swell_speed)
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
