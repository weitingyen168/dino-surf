class_name Water
extends Node2D
## Spring-chain water surface with rolling ocean swells on top.
## The ocean scrolls left at `speed` (how fast the dino is surfing), and each swell also travels on its own,
## like a real sea: long swells roll forward, short chop runs back, so crests drift, gang up into sets and
## break apart again. Crests are peaked and troughs flat. The springs handle local pushes.
## Heights are in pixels, positive = up. Screen y = base_y - height.

@export var start_x: float = -220.0
@export var width: float = 1100.0  # wider than the zoomed-out view so edges stay off-screen
@export var point_count: int = 170  # keeps the spacing about 6.5 px
@export var base_y: float = 250.0
@export var bottom_y: float = 640.0  # well below the screen, so the fill still covers it when the camera moves
@export var max_height: float = 140.0

@export_group("appearance")
@export var fill_color:Color = Color.NAVY_BLUE
@export var border_color:Color = Color.DARK_BLUE

@export_group("Springs")
@export var stiffness: float = 30.0  # pull back toward rest height
@export var damping: float = 4.0
@export var spread: float = 0.2  # how much neighbours share motion, keep < 0.5
@export var spread_passes: int = 6
@export var ripple_speed: float = 6.0  # how fast pushes travel along the chain
@export var smoothing: float = 0.15  # 0..0.5, irons out jagged spikes each tick so the surface stays rounded

@export_group("Swell")
## Three overlapping swells; where their crests line up you get a big launch ramp.
@export var swell_amplitude: float = 34.0
@export var swell_wavelength: float = 700.0
@export var mid_amplitude: float = 16.0
@export var mid_wavelength: float = 330.0
@export var small_amplitude: float = 6.0
@export var small_wavelength: float = 150.0
@export var size_variation: float = 0.35  # 0..1, how much swell size rises and falls over a long stretch
@export var variation_length: float = 2600.0
## How fast each swell travels on its own, px/s; + = forward with the dino, - = back toward it.
## Different speeds keep the sea changing: crests line up into big sets, then drift apart.
@export var swell_travel: float = 40.0
@export var mid_travel: float = -25.0
@export var small_travel: float = -70.0
@export var set_travel: float = 15.0  # how fast the big-and-small stretches (size_variation) drift
@export var crest_sharpness: float = 0.6  # 0 = smooth sine, 1 = peaked crests and wide flat troughs, like real swell

var speed := 200.0  # px/s the ocean scrolls left, i.e. how fast the dino surfs; set by Main
var tilt := 0.0  # radians the whole surface is tipped, + = downhill toward the right; set by Main as the pace rises
var tilt_pivot_x := 220.0  # screen x the tilt turns about (the dino), so the dino's height doesn't jump; set by Main

var _h := PackedFloat32Array()
var _v := PackedFloat32Array()
var _prev_h := PackedFloat32Array()  # last tick's heights, for smooth drawing between physics ticks
var _prev_scroll := 0.0
var _left := PackedFloat32Array()
var _right := PackedFloat32Array()
var _spacing: float
var _scroll := 0.0  # how far the ocean has scrolled, in px
var _time := 0.0  # seconds since reset; the swells travel with it
var _prev_time := 0.0
var _drawn_scroll := 0.0  # the scroll the surface was last drawn at, between physics ticks
var _fill: Polygon2D
var _line: Line2D
var _points := PackedVector2Array()  # the surface as drawn this frame
var draw_flat := true  # keep the flat 2D water (fill and line) up to date; View3D turns it off while it draws the water


func _ready() -> void:
	_spacing = width / (point_count - 1)
	_h.resize(point_count)
	_v.resize(point_count)
	_prev_h.resize(point_count)
	_left.resize(point_count)
	_right.resize(point_count)
	_fill = Polygon2D.new()
	_fill.color = fill_color
	add_child(_fill)
	_line = Line2D.new()
	_line.width = 2.0
	_line.default_color = border_color
	add_child(_line)


func reset() -> void:
	_h.fill(0.0)
	_v.fill(0.0)
	_prev_h.fill(0.0)
	_scroll = 0.0
	_prev_scroll = 0.0
	_time = 0.0
	_prev_time = 0.0


func _physics_process(delta: float) -> void:
	_prev_h = _h.duplicate()
	_prev_scroll = _scroll
	_prev_time = _time
	_scroll += speed * delta
	_time += delta
	for i in point_count:
		_v[i] += (-stiffness * _h[i] - damping * _v[i]) * delta
		_h[i] += _v[i] * delta

	# Classic spring-water spread: neighbours tug on each other so pushes ripple outward.
	for _pass in spread_passes:
		for i in point_count:
			if i > 0:
				_left[i] = spread * (_h[i] - _h[i - 1])
				_v[i - 1] += _left[i] * ripple_speed
			if i < point_count - 1:
				_right[i] = spread * (_h[i] - _h[i + 1])
				_v[i + 1] += _right[i] * ripple_speed
		for i in point_count:
			if i > 0:
				_h[i - 1] += _left[i]
			if i < point_count - 1:
				_h[i + 1] += _right[i]

	# Light blur so pushes make rounded swells, not sharp zig-zags.
	if smoothing > 0.0:
		var src := _h.duplicate()
		for i in range(1, point_count - 1):
			_h[i] = lerpf(src[i], (src[i - 1] + src[i + 1]) * 0.5, smoothing)

	for i in point_count:
		_h[i] = clampf(_h[i], -max_height, max_height)


func _process(_delta: float) -> void:
	# Physics runs at a fixed 60 Hz; blend the last two ticks so the surface moves smoothly on faster screens.
	var f := Engine.get_physics_interpolation_fraction()
	var sc := lerpf(_prev_scroll, _scroll, f)
	var tm := lerpf(_prev_time, _time, f)
	_drawn_scroll = sc
	var pts := PackedVector2Array()
	var deepest := 0.0
	for i in point_count:
		var x := start_x + i * _spacing
		var y := base_y - lerpf(_prev_h[i], _h[i], f) - _swell(x + sc, tm) + tilt_offset(x)
		deepest = maxf(deepest, y)
		pts.append(Vector2(x, y))
	_points = pts
	if not draw_flat:
		return  # rebuilding the fill polygon every frame isn't free, and nobody sees it
	_line.points = pts
	# The fill's bottom must stay below every surface point, or the polygon folds over itself,
	# Godot can't triangulate it, and the fill vanishes for that frame (the flashing).
	var bottom := maxf(bottom_y, deepest + 20.0)
	var poly := pts.duplicate()
	poly.append(Vector2(start_x + width, bottom))
	poly.append(Vector2(start_x, bottom))
	_fill.polygon = poly


## Adds upward acceleration to the springs within `radius` of `x`, with a smooth falloff.
func push(x: float, radius: float, strength: float, delta: float) -> void:
	for i in point_count:
		var d := absf(start_x + i * _spacing - x)
		if d < radius:
			var falloff := 0.5 + 0.5 * cos(PI * d / radius)
			_v[i] += strength * falloff * delta


## Surface height at x, positive = up.
func height_at(x: float) -> float:
	var fi := (x - start_x) / _spacing
	var i := clampi(int(floor(fi)), 0, point_count - 2)
	var t := clampf(fi - i, 0.0, 1.0)
	return lerpf(_h[i], _h[i + 1], t) + _swell(x + _scroll, _time)


## Screen-space y of the surface at x.
func surface_y(x: float) -> float:
	return base_y - height_at(x) + tilt_offset(x)


## How far the tilt moves the surface down at screen x (negative = up).
func tilt_offset(x: float) -> float:
	return (x - tilt_pivot_x) * tan(tilt)


## Screen y of the calm water line at x, tilt included: where planted cacti stand.
func calm_y(x: float) -> float:
	return base_y + tilt_offset(x)


## Angle of the surface at x, in radians (0 = flat, negative = rising to the right).
func slope_angle(x: float) -> float:
	var dx := 4.0
	return atan2(surface_y(x + dx) - surface_y(x - dx), 2.0 * dx)


## Screen-space vertical velocity of the surface at x (negative = moving up).
## The swell's rise rate at a fixed screen x comes from both the scrolling and the swells' own travel.
func surface_velocity_y(x: float) -> float:
	var fi := (x - start_x) / _spacing
	var i := clampi(int(floor(fi)), 0, point_count - 2)
	var t := clampf(fi - i, 0.0, 1.0)
	var spring_v := lerpf(_v[i], _v[i + 1], t)
	var w := x + _scroll
	var e := 1.0 / 240.0
	var swell_rate := (_swell(w + speed * e, _time + e) - _swell(w - speed * e, _time - e)) / (2.0 * e)
	return -(spring_v + swell_rate)


## Screen x of the first swell crest at or after screen x `from` (searches up to `reach` px ahead).
func next_crest(from: float, reach: float = 800.0) -> float:
	var step := 4.0
	var x := from
	while x < from + reach:
		var here := _swell(x + _scroll, _time)
		if _swell(x + _scroll + step, _time) < here and here >= _swell(x + _scroll - step, _time):
			return x
		x += step
	return from


## The surface as drawn this frame (smoothed between physics ticks), left to right in screen space. View3D extrudes it.
func surface_points() -> PackedVector2Array:
	return _points


## The scroll that goes with surface_points(), so art laid along the surface moves with it.
func drawn_scroll() -> float:
	return _drawn_scroll


## How far the ocean has scrolled, in px. Screen x + scroll = world position.
func scroll() -> float:
	return _scroll


## Seconds the swells have been travelling. Pass now + n to swell_y to look n seconds ahead.
func time() -> float:
	return _time


## Screen-space y of the swell alone (no spring ripples, no tilt) at world position w and time t. Fully
## predictable, so it's what you look ahead with.
func swell_y(w: float, t: float) -> float:
	return base_y - _swell(w, t)


## Swell height at world position w (screen x + scroll) and time t.
func _swell(w: float, t: float) -> float:
	var size := 1.0 - size_variation * 0.5 * (1.0 + cos(TAU * (w - set_travel * t) / variation_length))
	return size * (_wave(swell_amplitude, swell_wavelength, w - swell_travel * t, 0.0)
		+ _wave(mid_amplitude, mid_wavelength, w - mid_travel * t, 1.3)
		+ _wave(small_amplitude, small_wavelength, w - small_travel * t, 0.7))


## One swell: a sine with a second harmonic that sharpens the crests and flattens the troughs (Stokes-like).
func _wave(amplitude: float, wavelength: float, w: float, phase: float) -> float:
	var a := TAU * w / wavelength + phase
	return amplitude * (sin(a) - crest_sharpness * 0.25 * cos(2.0 * a))
