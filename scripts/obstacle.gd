class_name Obstacle
extends Node2D
## Placeholder cactus, Chrome Dino style: a tall saguaro with arms, or a short stubby one.
## Planted in the flooded desert floor: it stands still and upright while the swell rises and falls around it,
## so a crest can bury its foot and a trough shows more of it. It only moves left as the ocean scrolls.
## The node's origin is the calm waterline (Water.base_y) at its centre; `size` is the trunk (arms are decoration,
## not hit). The trunk carries on down to the seabed, so riding low in a trough still runs into it.

var water: Water
var size := Vector2(12, 40)  # trunk width, trunk height measured from the calm waterline down by `sunk`
var sunk := 0.15  # fraction of the height below the calm waterline
var arms := 2  # 0, 1 or 2 arms
var sliced := false  # cut in half by a spin (scheme D): harmless from then on

var _cut := 0.0  # local y of the cut
var _top_off := Vector2.ZERO  # the top half's flight, relative to the cut
var _top_vel := Vector2.ZERO
var _top_rot := 0.0
var _top_spin := 0.0


## Screen y of the trunk's top. Fixed, since the cactus doesn't bob.
func top_y() -> float:
	return position.y - size.y * (1.0 - sunk)


## Cuts it in two at world height `at_y`: the top flies off spinning, the stump stays planted.
func slice(at_y: float) -> void:
	sliced = true
	var top := -size.y * (1.0 - sunk)
	var waterline := water.surface_y(position.x) - position.y
	_cut = clampf(at_y - position.y, top + 10.0, maxf(top + 10.0, waterline - 4.0))
	_top_vel = Vector2(randf_range(40, 120), randf_range(-260, -180))
	_top_spin = randf_range(5.0, 9.0)


## The trunk from its top down to the seabed, in world space. A little smaller than the drawing to be fair.
func hit_rect() -> Rect2:
	var top := top_y() + 1.0
	return Rect2(position.x - size.x / 2.0 + 1.0, top, size.x - 2.0, water.bottom_y - top)


func _physics_process(delta: float) -> void:
	position.x -= water.speed * delta
	if sliced:
		_top_vel.y += 600.0 * delta
		_top_off += _top_vel * delta
		_top_rot += _top_spin * delta
	if position.x < -220.0:
		queue_free()


func _process(_delta: float) -> void:
	queue_redraw()  # the waterline moves up and down the trunk


func _draw() -> void:
	var ink := Color("535353")
	var wet := Color("b4b4b4")  # the sunk part, seen through the water
	var top := -size.y * (1.0 - sunk)
	var deep := water.bottom_y - position.y
	var waterline := minf(water.surface_y(position.x) - position.y, deep)
	_draw_piece(_cut if sliced else top, deep, ink)  # whole cactus, or the stump
	draw_rect(Rect2(-size.x / 2.0, waterline, size.x, deep - waterline), wet)
	if sliced:
		# Top half, flying off and spinning about the cut.
		draw_set_transform(Vector2(0, _cut) + _top_off, _top_rot)
		_draw_piece(top - _cut, 0.0, ink, _cut)
		draw_set_transform(Vector2.ZERO)


## Draws the trunk from local y `from` (up) down to `to`, plus the arms attached in that stretch.
## `shift` moves everything up by that much, so the top half can be drawn around its own cut.
func _draw_piece(from: float, to: float, ink: Color, shift: float = 0.0) -> void:
	var top := -size.y * (1.0 - sunk)
	var w := size.x
	var is_top := absf(from + shift - top) < 0.01
	var y0 := from + (w / 2.0 if is_top else 0.0)
	draw_rect(Rect2(-w / 2.0, y0, w, to - y0), ink)
	if is_top:
		draw_circle(Vector2(0, y0), w / 2.0, ink)  # rounded top
	# Arms: an elbow out, then up, rounded at the tip. Each goes with the piece it's attached to.
	var arm := maxf(w * 0.55, 5.0)
	var lo := from + shift
	var hi := to + shift
	if arms >= 1 and top * 0.45 >= lo and top * 0.45 < hi:
		_arm(Vector2(-w / 2.0, top * 0.45 - shift), -1.0, arm, -top * 0.3, ink)
	if arms >= 2 and top * 0.62 >= lo and top * 0.62 < hi:
		_arm(Vector2(w / 2.0, top * 0.62 - shift), 1.0, arm, -top * 0.22, ink)


func _arm(from: Vector2, side: float, thick: float, rise: float, ink: Color) -> void:
	var out := thick * 1.1
	var x0 := from.x if side > 0 else from.x - out
	draw_rect(Rect2(x0, from.y - thick / 2.0, out, thick), ink)  # elbow out from the trunk
	var cx := from.x + side * (out - thick / 2.0)
	draw_rect(Rect2(cx - thick / 2.0, from.y - rise, thick, rise), ink)  # forearm up
	draw_circle(Vector2(cx, from.y - rise), thick / 2.0, ink)
