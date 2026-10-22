class_name Seagull
extends Node2D
## A flapping seagull flying toward the dino, bobbing a little. Hitting one wipes you out;
## a spin kills it on the spot, in a puff. The node's origin is the middle of its body.

const FLY := preload("res://art/obstacles/seagull_fly_01.png")  # flap frames, left to right
const FRAMES := 9
const ART_SCALE := 0.6  # the art is made at 2× (View3D draws the hazards card at 2×); a bit bigger, to stand out
const OUTLINE_PX := 1.5  # black outline around it, so it reads against the sky
const BODY := Vector2(0.58, 0.45)  # the body's middle, as a fraction of a frame (the beak sticks out in front)

@export var fly_speed: float = 60.0  # px/s it flies toward the dino on top of the ocean's scroll
@export var wingspan: float = 60.0  # sets the hit box, which is just the body and inner wings
@export var flap_fps: float = 14.0

var water: Water
var altitude := 200.0  # screen y it cruises at

var _t := 0.0
var _phase := randf() * TAU  # so gulls don't all bob and flap in step


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # drawn scaled; smooth, not jagged


## Body plus the inner wings, in world space. The flapping tips don't count, to be fair.
func hit_rect() -> Rect2:
	var w := wingspan * 0.55
	return Rect2(position + Vector2(-w / 2.0, -8), Vector2(w, 16))


## Spun into: gone at once, in a puff.
func kill() -> void:
	Puff.spawn(get_parent(), position, Color.WHITE, water)
	queue_free()


func _physics_process(delta: float) -> void:
	_t += delta
	position.x -= (water.speed + fly_speed) * delta
	position.y = altitude + sin(_t * 1.7 + _phase) * 6.0
	if position.x < -220.0:
		queue_free()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var w := FLY.get_width() / FRAMES
	var h := FLY.get_height()
	var frame := int(_t * flap_fps + _phase) % FRAMES
	var size := Vector2(w, h) * ART_SCALE
	var rect := Rect2(-size * BODY, size)
	var region := Rect2(frame * w, 0, w, h)
	# Outline: the frame in black, nudged out in eight directions, then the gull itself on top.
	for i in 8:
		var nudge := Vector2.from_angle(i * TAU / 8.0) * OUTLINE_PX
		draw_texture_rect_region(FLY, Rect2(rect.position + nudge, size), region, Color.BLACK)
	draw_texture_rect_region(FLY, rect, region)
