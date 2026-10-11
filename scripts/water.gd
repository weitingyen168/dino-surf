class_name Water
extends Node2D
## Spring-chain water surface with a travelling swell on top.
## Heights are in pixels, positive = up. Screen y = base_y - height.

@export var start_x: float = -60.0
@export var width: float = 760.0  # wider than the 640px viewport so edges stay off-screen
@export var point_count: int = 120
@export var base_y: float = 250.0
@export var bottom_y: float = 400.0
@export var max_height: float = 140.0

@export_group("Springs")
@export var stiffness: float = 30.0  # pull back toward rest height
@export var damping: float = 3.0
@export var spread: float = 0.2  # how much neighbours share motion, keep < 0.5
@export var spread_passes: int = 6
@export var ripple_speed: float = 6.0  # how fast pushes travel along the chain

@export_group("Swell")
@export var swell_amplitude: float = 14.0
@export var swell_wavelength: float = 320.0
@export var swell_speed: float = 120.0  # px/s, scrolls left so the dino appears to move right
@export var chop_amplitude: float = 4.0
@export var chop_wavelength: float = 90.0
@export var chop_speed: float = 200.0

var _h := PackedFloat32Array()
var _v := PackedFloat32Array()
var _spacing: float
var _time := 0.0
var _fill: Polygon2D
var _line: Line2D


func _ready() -> void:
	_spacing = width / (point_count - 1)
	_h.resize(point_count)
	_v.resize(point_count)
	_fill = Polygon2D.new()
	_fill.color = Color("dcdcdc")
	add_child(_fill)
	_line = Line2D.new()
	_line.width = 2.0
	_line.default_color = Color("535353")
	add_child(_line)


func reset() -> void:
	_h.fill(0.0)
	_v.fill(0.0)


func _physics_process(delta: float) -> void:
	_time += delta
	for i in point_count:
		_v[i] += (-stiffness * _h[i] - damping * _v[i]) * delta
		_h[i] += _v[i] * delta

	# Classic spring-water spread: neighbours tug on each other so pushes ripple outward.
	var left := PackedFloat32Array()
	var right := PackedFloat32Array()
	left.resize(point_count)
	right.resize(point_count)
	for _pass in spread_passes:
		for i in point_count:
			if i > 0:
				left[i] = spread * (_h[i] - _h[i - 1])
				_v[i - 1] += left[i] * ripple_speed
			if i < point_count - 1:
				right[i] = spread * (_h[i] - _h[i + 1])
				_v[i + 1] += right[i] * ripple_speed
		for i in point_count:
			if i > 0:
				_h[i - 1] += left[i]
			if i < point_count - 1:
				_h[i + 1] += right[i]

	for i in point_count:
		_h[i] = clampf(_h[i], -max_height, max_height)


func _process(_delta: float) -> void:
	var pts := PackedVector2Array()
	for i in point_count:
		var x := start_x + i * _spacing
		pts.append(Vector2(x, surface_y(x)))
	_line.points = pts
	var poly := pts.duplicate()
	poly.append(Vector2(start_x + width, bottom_y))
	poly.append(Vector2(start_x, bottom_y))
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
	return lerpf(_h[i], _h[i + 1], t) + _swell(x)


## Screen-space y of the surface at x.
func surface_y(x: float) -> float:
	return base_y - height_at(x)


## Angle of the surface at x, in radians (0 = flat, negative = rising to the right).
func slope_angle(x: float) -> float:
	var dx := 4.0
	return atan2(surface_y(x + dx) - surface_y(x - dx), 2.0 * dx)


## Screen-space vertical velocity of the surface at x (negative = moving up).
func surface_velocity_y(x: float) -> float:
	var fi := (x - start_x) / _spacing
	var i := clampi(int(floor(fi)), 0, point_count - 2)
	var t := clampf(fi - i, 0.0, 1.0)
	var spring_v := lerpf(_v[i], _v[i + 1], t)
	return -(spring_v + _swell_rate(x))


func _swell(x: float) -> float:
	return swell_amplitude * sin(TAU * (x + swell_speed * _time) / swell_wavelength) \
		+ chop_amplitude * sin(TAU * (x + chop_speed * _time) / chop_wavelength)


func _swell_rate(x: float) -> float:
	return swell_amplitude * TAU * swell_speed / swell_wavelength * cos(TAU * (x + swell_speed * _time) / swell_wavelength) \
		+ chop_amplitude * TAU * chop_speed / chop_wavelength * cos(TAU * (x + chop_speed * _time) / chop_wavelength)
