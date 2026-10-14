class_name Dino
extends Node2D
## Placeholder surfer. It stays at home_x on screen while the ocean scrolls past at `speed`.
## Speed: gravity along the slope. Riding down a swell's face speeds it up, riding up one slows it,
## and the player tilting the world (`tilt`) adds to that slope: tip it forward and you speed up,
## tip it back and you slow down. Landing on a down-slope turns the fall into extra speed.
## Height: a floating body — gravity pulls it down; in the water, buoyancy pushes it up and drag
## carries it with the surface. Nothing scripts a jump: going over a crest fast enough means the
## surface drops away faster than gravity can follow, so it flies.
## Landing is always safe; only debris ends a run.
## The node's origin is where the board touches the water.

@export var gravity: float = 900.0
@export var home_x: float = 220.0

@export_group("Speed")
@export var start_speed: float = 220.0
@export var min_speed: float = 100.0
@export var max_speed: float = 650.0
@export var slope_gain: float = 1.0  # how much riding down / up a slope (water + tilt) speeds up / slows down
@export var water_friction: float = 0.12  # per second while on the water, so speed settles if you do nothing

@export_group("Floating")
@export var buoyancy: float = 600.0  # how hard the water pushes back per px the board is pushed under
@export var water_drag: float = 10.0  # how strongly the dino is dragged along with the water's motion while in it; lower = carries its upward speed off a crest
@export var stickiness: float = 0.0  # extra pull back onto the water (px/s²) right after leaving it; higher = stays on more
@export var stick_range: float = 6.0  # px above the water where stickiness still acts

var water: Water
var velocity := Vector2.ZERO
var speed := 220.0
var tilt := 0.0  # world tilt in radians, + = tipped down toward the direction of travel; set by Main
var on_surface := true
var crashed := false

var _touching := true  # in contact since the last time it got clear of stick_range
var _spin := 0.0
var _splashed := false
var _board_pos := Vector2.ZERO  # world space, only used once crashed
var _board_vel := Vector2.ZERO
var _board_rot := 0.0
var _drops: Array = []  # [pos, vel] pairs in world space


func reset() -> void:
	velocity = Vector2.ZERO
	speed = start_speed
	tilt = 0.0
	on_surface = true
	_touching = true
	crashed = false
	_splashed = false
	_drops.clear()
	rotation = 0.0
	position = Vector2(home_x, water.surface_y(home_x))
	reset_physics_interpolation()  # teleport, don't slide from where it wiped out


## Body box in world space, for debris hits. Ignores rotation; a little smaller than the drawing to be fair.
func hit_rect() -> Rect2:
	return Rect2(position + Vector2(-14, -30), Vector2(26, 30))


## Throws the dino off its board. Main calls this when it hits debris.
func crash() -> void:
	if crashed:
		return
	crashed = true
	on_surface = false
	_board_pos = position
	_board_rot = rotation
	velocity = Vector2(-90, -240)
	_board_vel = Vector2(140, -160)
	_spin = -9.0


func _physics_process(delta: float) -> void:
	if water == null:
		return
	_update_drops(delta)
	if crashed:
		_tumble(delta)
	else:
		_float(delta)


func _float(delta: float) -> void:
	position.x = home_x
	var slope := water.slope_angle(position.x)  # > 0 = surface going down to the right (downhill)
	var depth := position.y - water.surface_y(position.x)  # > 0 = board pushed under the surface
	var accel := gravity
	if depth >= 0.0:
		if not on_surface:
			_land(slope)
		# In the water: buoyancy holds it at the surface and drag carries it along with the water.
		var rel_vy := velocity.y - water.surface_velocity_y(position.x)
		accel -= gravity + buoyancy * depth + water_drag * rel_vy
		_touching = true
		# Gravity along the face, with the world's tilt added: downhill speeds you up, uphill slows you down.
		var downhill := slope + tilt
		speed += gravity * sin(downhill) * cos(downhill) * slope_gain * delta
		speed -= speed * water_friction * delta
	elif _touching and depth > -stick_range:
		accel += stickiness  # surface tension: a gentle lift-off gets pulled back down
	else:
		_touching = false
	speed = clampf(speed, min_speed, max_speed)
	velocity.y += accel * delta
	position.y += velocity.y * delta
	on_surface = depth > -1.0

	# On the water the board follows the face; in the air the nose follows the arc.
	var target := slope if on_surface else clampf(atan2(velocity.y, speed), -0.7, 0.7)
	rotation = lerp_angle(rotation, target, (12.0 if on_surface else 4.0) * delta)


## Touchdown: keep the part of the motion that runs along the face. Coming down onto a
## down-slope turns the fall into speed; slamming into an up-slope costs speed.
func _land(slope: float) -> void:
	var along := Vector2.from_angle(slope)
	var kept := Vector2(speed, velocity.y).dot(along) * along.x
	speed = clampf(maxf(kept, min_speed), min_speed, max_speed)


func _tumble(delta: float) -> void:
	var surf_y := water.surface_y(position.x)
	if position.y < surf_y:
		velocity.y += gravity * delta
		rotation += _spin * delta
	else:
		if not _splashed:
			_splashed = true
			_splash(Vector2(position.x, surf_y), 14)
		velocity = velocity.lerp(Vector2(-water.speed * 0.3, 25.0), 4.0 * delta)  # sink and drift
		_spin = lerpf(_spin, 0.0, 3.0 * delta)
		rotation += _spin * delta
	position += velocity * delta

	# The board flies off on its own, then floats.
	var board_surf := water.surface_y(_board_pos.x)
	if _board_pos.y < board_surf or _board_vel.y < 0.0:
		_board_vel.y += gravity * delta
		_board_rot += 8.0 * delta
	else:
		if _board_vel.y > 200.0:
			_splash(Vector2(_board_pos.x, board_surf), 6)
		_board_vel = Vector2(-water.speed * 0.3, 0.0)
		_board_pos.y = board_surf
		_board_rot = lerp_angle(_board_rot, water.slope_angle(_board_pos.x), 6.0 * delta)
	_board_pos += _board_vel * delta


func _splash(at: Vector2, count: int) -> void:
	for i in count:
		_drops.append([at + Vector2(randf_range(-8, 8), 0), Vector2(randf_range(-110, 110), randf_range(-260, -90))])


func _update_drops(delta: float) -> void:
	for d in _drops:
		d[1].y += gravity * 0.8 * delta
		d[0] += d[1] * delta
	_drops = _drops.filter(func(d): return d[0].y < water.surface_y(d[0].x) + 4.0 or d[1].y < 0.0)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var ink := Color("535353")
	if not crashed:
		draw_line(Vector2(-18, -1), Vector2(18, -1), ink, 3.0)  # board
	draw_rect(Rect2(-7, -26, 14, 23), ink)  # body
	draw_rect(Rect2(-1, -32, 14, 9), ink)  # head
	if crashed:
		draw_line(Vector2(7, -30), Vector2(10, -27), Color.WHITE, 1.0)  # x eyes
		draw_line(Vector2(10, -30), Vector2(7, -27), Color.WHITE, 1.0)
	else:
		draw_rect(Rect2(7, -30, 2, 2), Color.WHITE)  # eye
	if not on_surface:
		draw_rect(Rect2(-9, -18, 4, 2), ink)  # arm out for balance

	# Board and spray live in world space once they leave the dino.
	draw_set_transform_matrix(get_global_transform().affine_inverse())
	if crashed:
		draw_set_transform_matrix(get_global_transform().affine_inverse() * Transform2D(_board_rot, _board_pos))
		draw_line(Vector2(-18, -1), Vector2(18, -1), ink, 3.0)
		draw_set_transform_matrix(get_global_transform().affine_inverse())
	for d in _drops:
		draw_rect(Rect2(d[0] - Vector2(1.5, 1.5), Vector2(3, 3)), ink)
