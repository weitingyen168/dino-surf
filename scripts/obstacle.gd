class_name Obstacle
extends Node2D
## Cactus, Chrome Dino style: a tall saguaro with arms, or a short stubby one, in the backdrop cacti's colours.
## Planted in the flooded desert floor: it stands still and upright while the swell rises and falls around it,
## so a crest can bury its foot and a trough shows more of it. It only moves left as the ocean scrolls (keeping to
## the calm line as the water tilts). The node's origin is the calm waterline (Water.calm_y) at its centre; `size` is the trunk (arms are decoration,
## not hit). The trunk carries on down to the seabed, so riding low in a trough still runs into it.

const GREEN := Color("6a9a4e")  # the backdrop cacti's palette
const SHADE := Color("3f6b4a")
const FLOWER := Color("eab8de")
const OUTLINE := Color("26402a")  # dark edge so it stands out against the sand
const OUTLINE_PX := 2.0

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


func _ready() -> void:
	scale = _drawn_scale()


## How much bigger it's drawn than its hit box, to read easily. A cactus only gets thicker: taller would change
## what has to be jumped.
func _drawn_scale() -> Vector2:
	return Vector2(1.3, 1.0)


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
	position.y = water.calm_y(position.x)
	if sliced:
		_top_vel.y += 600.0 * delta
		_top_off += _top_vel * delta
		_top_rot += _top_spin * delta
	if position.x < -220.0:
		queue_free()


func _process(_delta: float) -> void:
	queue_redraw()  # the waterline moves up and down the trunk


func _draw() -> void:
	var top := -size.y * (1.0 - sunk)
	# Drawn down to the water only, so nothing shows through it. The hit box still reaches the seabed.
	var waterline := water.surface_y(position.x) - position.y
	var from := _cut if sliced else top
	# Each piece twice: grown in the outline colour, then filled in.
	for grow in [OUTLINE_PX, 0.0]:
		if waterline > from:
			_draw_piece(from, waterline, grow)  # whole cactus, or the stump
	if sliced:
		# Top half, flying off and spinning about the cut.
		draw_set_transform(Vector2(0, _cut) + _top_off, _top_rot)
		for grow in [OUTLINE_PX, 0.0]:
			_draw_piece(top - _cut, 0.0, grow, _cut)
		draw_set_transform(Vector2.ZERO)


## Draws the trunk from local y `from` (up) down to `to`, plus the arms attached in that stretch.
## `shift` moves everything up by that much, so the top half can be drawn around its own cut.
## `grow` > 0 draws just the outline: every shape that much bigger, in the outline colour.
func _draw_piece(from: float, to: float, grow: float, shift: float = 0.0) -> void:
	var ink := OUTLINE if grow > 0.0 else GREEN
	var top := -size.y * (1.0 - sunk)
	var w := size.x
	var is_top := absf(from + shift - top) < 0.01
	var y0 := from + (w / 2.0 if is_top else 0.0)
	draw_rect(Rect2(-w / 2.0 - grow, y0 - (0.0 if is_top else grow), w + 2.0 * grow, to - y0 + (0.0 if is_top else grow)), ink)
	if grow == 0.0:
		draw_rect(Rect2(w / 2.0 - w * 0.3, y0, w * 0.3, to - y0), SHADE)  # shaded side
	if is_top:
		draw_circle(Vector2(0, y0), w / 2.0 + grow, ink)  # rounded top
		if grow == 0.0:
			draw_rect(Rect2(-2.0, y0 - w / 2.0 - 3.0, 4.0, 4.0), FLOWER)
	# Arms: an elbow out, then up, rounded at the tip. Each goes with the piece it's attached to.
	var arm := maxf(w * 0.55, 5.0)
	var lo := from + shift
	var hi := to + shift
	if arms >= 1 and top * 0.45 >= lo and top * 0.45 < hi:
		_arm(Vector2(-w / 2.0, top * 0.45 - shift), -1.0, arm, -top * 0.3, ink, grow)
	if arms >= 2 and top * 0.62 >= lo and top * 0.62 < hi:
		_arm(Vector2(w / 2.0, top * 0.62 - shift), 1.0, arm, -top * 0.22, ink, grow)


func _arm(from: Vector2, side: float, thick: float, rise: float, ink: Color, grow: float) -> void:
	var out := thick * 1.1
	var x0 := from.x if side > 0 else from.x - out
	draw_rect(Rect2(x0, from.y - thick / 2.0, out, thick).grow(grow), ink)  # elbow out from the trunk
	var cx := from.x + side * (out - thick / 2.0)
	draw_rect(Rect2(cx - thick / 2.0, from.y - rise, thick, rise).grow(grow), ink)  # forearm up
	draw_circle(Vector2(cx, from.y - rise), thick / 2.0 + grow, ink)
