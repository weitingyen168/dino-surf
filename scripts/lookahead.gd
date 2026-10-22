class_name Lookahead
extends Control
## Warning markers for what's coming: every cactus, buoy and gull still off the right edge of the screen gets an
## arrow on that edge, at the height you'll meet it (a cactus's top, a gull's body), growing as it gets close.
## Green = cactus, red = buoy, white = gull. Main hands it the spawners and the 3D view in setup().

const CACTUS := Color("6a9a4e")
const BUOY := Color("c0393b")
const GULL := Color.WHITE

@export var reach_px: float = 520.0  # off-screen distance (in screen px) at which a marker first shows
@export var edge_px: float = 12.0  # how far in from the right edge the markers sit

var _obstacles: ObstacleSpawner
var _gulls: GullSpawner
var _view: View3D


func setup(obstacles: ObstacleSpawner, gulls: GullSpawner, view: View3D) -> void:
	_obstacles = obstacles
	_gulls = gulls
	_view = view


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not _obstacles:
		return
	for o in _obstacles.obstacles:
		if is_instance_valid(o) and not o.sliced:
			_marker(Vector2(o.position.x, o.top_y()), _view.hazards_z, BUOY if o is Buoy else CACTUS)
	for g in _gulls.gulls:
		if is_instance_valid(g) and not g.knocked:
			_marker(g.position, _view.hazards_z, GULL)


## An arrow on the right edge for the thing at 2D world point `at` (on the card at depth `z`), if it's off-screen.
func _marker(at: Vector2, z: float, color: Color) -> void:
	var p := _to_screen(at, z)
	var past := p.x - size.x  # how far beyond the right edge
	if past < 0.0 or past > reach_px:
		return
	var k := 1.0 - past / reach_px  # 0 far away, 1 about to come into view
	var r := lerpf(5.0, 10.0, k)
	var tip := Vector2(size.x - edge_px - r * 1.6, clampf(p.y, 24.0, size.y - 24.0))
	var arrow := PackedVector2Array([tip, tip + Vector2(r * 1.6, -r), tip + Vector2(r * 1.6, r)])
	var ink := Color(0.1, 0.1, 0.1, lerpf(0.4, 0.9, k))
	draw_colored_polygon(arrow, Color(color, lerpf(0.4, 1.0, k)))
	draw_polyline(arrow + PackedVector2Array([tip]), ink, 1.5)


## A 2D world point as it shows on screen, in this control's coordinates: through the 3D camera, or the 2D one
## in the flat view.
func _to_screen(at: Vector2, z: float) -> Vector2:
	if _view.on:
		var cam := get_viewport().get_camera_3d()
		var px := cam.unproject_position(_view.card_point(at, z))
		return px * size / get_viewport().get_visible_rect().size
	return get_viewport().get_canvas_transform() * at
