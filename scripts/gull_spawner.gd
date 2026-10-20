class_name GullSpawner
extends Node
## Sends seagulls in from the right, more of them the higher up (height_bias), and checks the dino against them:
## a spin knocks one away (`gull_knocked`), a body hit ends the run (`dino_hit`).
## Spawned gulls go into `container`, which sits before the Dino in the tree so they draw behind it.

signal dino_hit(reason: String)
signal gull_knocked

@export var water: Water
@export var dino: Dino
@export var container: Node2D

@export var spawn_x: float = 850.0  # just off the right edge
@export var min_gap_px: float = 250.0  # distance travelled between gulls
@export var max_gap_px: float = 550.0
@export var first_gull_px: float = 900.0
@export var min_alt: float = 110.0  # px above the calm water line; low enough to matter, above normal surfing
@export var max_alt: float = 300.0  # keep within the view while surfing
@export var height_bias: float = 1.5  # 0 = spread evenly; higher = packed toward the top, so flying high is riskier

var gulls: Array[Seagull] = []
var next_gull_px := 900.0  # px to go until the next gull; reset() sets it to first_gull_px


func reset() -> void:
	for g in gulls:
		if is_instance_valid(g):
			g.queue_free()
	gulls.clear()
	next_gull_px = first_gull_px


func _physics_process(delta: float) -> void:
	next_gull_px -= water.speed * delta
	if next_gull_px <= 0.0:
		_spawn()
		next_gull_px = randf_range(min_gap_px, max_gap_px)
	gulls = gulls.filter(func(g): return is_instance_valid(g))
	var body := dino.hit_rect()
	for g in gulls:
		if g.knocked:
			continue
		if dino.slashing() and dino.slash_rect().intersects(g.hit_rect()):
			g.knock()
			dino.refund_spin()
			gull_knocked.emit()
			continue
		if body.intersects(g.hit_rect()):
			dino_hit.emit("Hit a seagull")
			return


## Altitude density rises with height: the pdf is proportional to altitude^height_bias, so u^(1 / (bias + 1)) samples it.
func _spawn() -> void:
	var g := Seagull.new()
	g.water = water
	var u := pow(randf(), 1.0 / (height_bias + 1.0))
	g.altitude = water.base_y - lerpf(min_alt, max_alt, u)
	g.position = Vector2(spawn_x, g.altitude)
	container.add_child(g)
	gulls.append(g)
