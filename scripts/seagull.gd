class_name Seagull
extends Node2D
## A flapping seagull flying toward the dino, bobbing a little. Hitting one wipes you out;
## a spin (scheme D) knocks it tumbling away. The node's origin is the middle of its body.

const FLY := preload("res://art/obstacles/seagull_fly_01.png")  # flap frames, left to right
const FRAMES := 9
const ART_SCALE := 0.5  # the art is made at 2× its in-game size (View3D draws the hazards card at 2×)
const BODY := Vector2(0.58, 0.45)  # the body's middle, as a fraction of a frame (the beak sticks out in front)

@export var fly_speed: float = 60.0  # px/s it flies toward the dino on top of the ocean's scroll
@export var wingspan: float = 60.0  # sets the hit box, which is just the body and inner wings
@export var flap_fps: float = 14.0

var water: Water
var altitude := 200.0  # screen y it cruises at
var knocked := false

var _t := 0.0
var _phase := randf() * TAU  # so gulls don't all bob and flap in step
var _vel := Vector2.ZERO
var _spin := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # it tumbles when knocked; smooth, not jagged


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
	var w := FLY.get_width() / FRAMES
	var h := FLY.get_height()
	var frame := int(_t * flap_fps + _phase) % FRAMES
	var size := Vector2(w, h) * ART_SCALE
	draw_texture_rect_region(FLY, Rect2(-size * BODY, size), Rect2(frame * w, 0, w, h))
