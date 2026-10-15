class_name Obstacle
extends Node2D
## Placeholder floating cactus, Chrome Dino style: a tall saguaro with arms, or a short stubby one.
## Part sunk, bobbing and leaning with the swell as it drifts left.
## The node's origin is the waterline at its centre; `size` is the trunk (arms are decoration, not hit).

var water: Water
var size := Vector2(12, 40)  # trunk width, full trunk height (above + below the waterline)
var sunk := 0.15  # fraction of the height below the waterline
var arms := 2  # 0, 1 or 2 arms
var lean := 0.5  # how much of the swell's slope it leans with; tall cacti look wrong tipping all the way
var sliced := false  # cut in half by a spin (scheme D): harmless from then on

var _cut := 0.0  # local y of the cut
var _top_off := Vector2.ZERO  # the top half's flight, relative to the cut
var _top_vel := Vector2.ZERO
var _top_rot := 0.0
var _top_spin := 0.0
var _sink := 0.0  # the stump slowly goes under


## Cuts it in two at world height `at_y`: the top flies off spinning, the stump sinks.
func slice(at_y: float) -> void:
	sliced = true
	var top := -size.y * (1.0 - sunk)
	_cut = clampf(at_y - position.y, top + 10.0, -4.0)
	_top_vel = Vector2(randf_range(40, 120), randf_range(-260, -180))
	_top_spin = randf_range(5.0, 9.0)


## The trunk above the waterline, in world space, following its lean. A little smaller than the drawing to be fair.
func hit_rect() -> Rect2:
	var above := size.y * (1.0 - sunk)
	var xf := Transform2D(rotation, position)
	var r := Rect2(xf * Vector2(-size.x / 2.0 + 1.0, -above + 1.0), Vector2.ZERO)
	for c in [Vector2(size.x / 2.0 - 1.0, -above + 1.0), Vector2(-size.x / 2.0 + 1.0, 0), Vector2(size.x / 2.0 - 1.0, 0)]:
		r = r.expand(xf * c)
	return r


func _physics_process(delta: float) -> void:
	position.x -= water.speed * delta
	position.y = water.surface_y(position.x)
	rotation = lerp_angle(rotation, water.slope_angle(position.x) * lean, 5.0 * delta)
	if sliced:
		_top_vel.y += 600.0 * delta
		_top_off += _top_vel * delta
		_top_rot += _top_spin * delta
		_sink += 40.0 * delta
		position.y += _sink
	if position.x < -220.0:
		queue_free()


func _process(_delta: float) -> void:
	queue_redraw()  # the waterline cut follows the bob


func _draw() -> void:
	var ink := Color("535353")
	var wet := Color("b4b4b4")  # the sunk part, seen through the water
	var top := -size.y * (1.0 - sunk)
	var sub := size.y * sunk
	draw_rect(Rect2(-size.x / 2.0, 0, size.x, sub), wet)
	if not sliced:
		_draw_piece(top, 0.0, ink)
		return
	_draw_piece(_cut, 0.0, ink)  # stump
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
