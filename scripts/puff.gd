class_name Puff
extends Node2D
## A quick puff where something was killed: a ring of dots bursting out and fading. Drifts with the ocean, then
## frees itself. Spawned into the Hazards container, so it shows on the same card as what it replaced.

const LIFE := 0.25  # seconds
const DOTS := 8

var water: Water
var color := Color.WHITE
var _t := 0.0


static func spawn(parent: Node, at: Vector2, tint: Color, ocean: Water) -> void:
	var puff := Puff.new()
	puff.position = at
	puff.color = tint
	puff.water = ocean
	parent.add_child(puff)


func _physics_process(delta: float) -> void:
	_t += delta
	position.x -= water.speed * delta
	if _t >= LIFE:
		queue_free()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var k := clampf(_t / LIFE, 0.0, 1.0)
	for i in DOTS:
		var out := Vector2.from_angle(i * TAU / DOTS) * lerpf(4.0, 24.0, k)
		draw_circle(out, lerpf(4.0, 1.0, k), Color(color, 1.0 - k))
