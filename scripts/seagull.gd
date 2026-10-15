class_name Seagull
extends Node2D
## Placeholder seagull: a big flapping gull flying toward the dino, bobbing a little. Hitting one wipes you out;
## a spin (scheme D) knocks it tumbling away. The node's origin is the middle of its body.

@export var fly_speed: float = 60.0  # px/s it flies toward the dino on top of the ocean's scroll
@export var wingspan: float = 60.0

var water: Water
var altitude := 200.0  # screen y it cruises at
var knocked := false

var _t := 0.0
var _phase := randf() * TAU
var _vel := Vector2.ZERO
var _spin := 0.0


## Body plus the inner wings, in world space. The flapping tips don't count, to be fair.
func hit_rect() -> Rect2:
	var w := wingspan * 0.55
	return Rect2(position + Vector2(-w / 2.0, -8), Vector2(w, 16))


## Spun into: it tumbles off up and back, harmless.
func knock() -> void:
	knocked = true
	_vel = Vector2(randf_range(80, 160), randf_range(-260, -160))
	_spin = randf_range(8.0, 12.0)


func _physics_process(delta: float) -> void:
	_t += delta
	if knocked:
		_vel.y += 500.0 * delta
		position += _vel * delta
		rotation += _spin * delta
		position.x -= water.speed * delta
	else:
		position.x -= (water.speed + fly_speed) * delta
		position.y = altitude + sin(_t * 1.7 + _phase) * 6.0
	if position.x < -220.0 or position.y > 900.0:
		queue_free()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var ink := Color("535353")
	var half := wingspan / 2.0
	# Wings: a gull's M shape, tips flapping up and down.
	var flap := sin(_t * 9.0 + _phase) * 0.5 + 0.5  # 0 = down, 1 = up
	var tip_y := lerpf(10.0, -18.0, flap)
	var elbow_y := lerpf(-2.0, -10.0, flap)
	for side in [-1.0, 1.0]:
		draw_polyline(PackedVector2Array([
			Vector2(side * 6.0, -1.0), Vector2(side * half * 0.45, elbow_y), Vector2(side * half, tip_y),
		]), ink, 4.0)
	# Body, head facing left (it flies toward the dino), beak, eye, tail.
	draw_rect(Rect2(-12, -4, 26, 9), ink)
	draw_rect(Rect2(-20, -7, 10, 9), ink)
	draw_rect(Rect2(-27, -3, 7, 3), Color("8a8a8a"))  # beak
	draw_rect(Rect2(-17, -5, 2, 2), Color.WHITE)  # eye
	draw_rect(Rect2(14, -3, 6, 5), ink)  # tail
