class_name Backdrop
extends Node2D
## One pixel-art background layer, tiled sideways and scrolling with the ocean. Every other tile is mirrored,
## so the seams always match. The node's origin is the art's top-left corner; all the layers share one frame,
## so they stack the way the artist drew them.
## A layer can use just a band of rows of its art (first_row..last_row), still placed where it is in the frame,
## so one picture can be split across depths, e.g. the small far cacti on the sand and the big ones on the shore.
## Further-back layers scroll slower: View3D sets `parallax` from `depth` so the 3D view and the flat one agree.

@export var texture: Texture2D
@export var water: Water
@export var depth: float = -800.0  # px, + = toward the camera; where View3D stands this layer's card
@export var pixel_scale: float = 3.0  # world px per art pixel
@export var first_row: int = 0  # art rows this layer shows
@export var last_row: int = -1  # -1 = to the bottom

var parallax := 1.0  # fraction of the ocean's speed this layer scrolls at
var _prev_x := 0.0


## One past the last art row this layer shows.
func end_row() -> int:
	return texture.get_height() if last_row < 0 else last_row + 1


## First and one-past-last art rows with anything drawn in them, within this layer's band.
func used_rows() -> Vector2i:
	var used := texture.get_image().get_used_rect()
	return Vector2i(maxi(used.position.y, first_row), mini(used.end.y, end_row()))


## Scroll as drawn this frame, between physics ticks (View3D's card samples the art at this offset).
func drawn_x() -> float:
	return lerpf(_prev_x, position.x, Engine.get_physics_interpolation_fraction())


func _physics_process(delta: float) -> void:
	var pair := 2.0 * texture.get_width() * pixel_scale  # a tile and its mirror: the pattern repeats after this
	_prev_x = position.x
	position.x -= water.speed * parallax * delta
	if position.x < -pair:
		position.x += pair
		_prev_x += pair
		reset_physics_interpolation()  # same picture after the jump, so don't slide back across it


func _draw() -> void:
	var band := Rect2(0, first_row, texture.get_width(), end_row() - first_row)
	var size := band.size * pixel_scale
	# From well left of the view to well right of it, wherever the scroll is.
	for i in range(-2, 6):
		var flip := i % 2 != 0
		draw_set_transform(Vector2(size.x * (i + 1 if flip else i), first_row * pixel_scale), 0.0,
			Vector2(-1.0 if flip else 1.0, 1.0))
		draw_texture_rect_region(texture, Rect2(Vector2.ZERO, size), band)
	draw_set_transform(Vector2.ZERO)
