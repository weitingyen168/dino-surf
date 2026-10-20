class_name ObstacleSpawner
extends Node
## Floats cacti in from the right edge, only where the player can actually clear them (see FlightPlanner),
## and checks the dino against them: a spin slices one (`cactus_sliced`), a body hit ends the run (`dino_hit`).
## Spawned cacti go into `container`, which sits before the Dino in the tree so they draw behind it.

signal dino_hit(reason: String)
signal cactus_sliced

@export var water: Water
@export var dino: Dino
@export var controls: Controls
@export var container: Node2D

@export var spawn_x: float = 820.0  # just off the right edge (the zoomed-out view reaches about x = 750)
@export var min_gap_px: float = 450.0  # distance travelled between debris
@export var max_gap_px: float = 900.0
@export var first_obstacle_px: float = 1500.0  # breathing room at the start of a run
## Debris only goes where a full forward tilt from right now would fly over it with this many px to spare,
## so every piece is clearable from wherever the last one left you. Higher = more forgiving.
@export var clear_margin_px: float = 8.0
@export var plan_reach_px: float = 700.0  # how far past spawn_x to look for a spot
@export var retry_spawn_px: float = 60.0  # no clearable spot in reach: look again after this far

var obstacles: Array[Obstacle] = []
var next_spawn_px := 1500.0  # px to go until the next debris; reset() sets it to first_obstacle_px


func reset() -> void:
	for o in obstacles:
		if is_instance_valid(o):
			o.queue_free()
	obstacles.clear()
	next_spawn_px = first_obstacle_px


func _physics_process(delta: float) -> void:
	next_spawn_px -= water.speed * delta
	if next_spawn_px <= 0.0:
		next_spawn_px = randf_range(min_gap_px, max_gap_px) if _spawn() else retry_spawn_px
	obstacles = obstacles.filter(func(o): return is_instance_valid(o))
	var body := dino.hit_rect()
	for o in obstacles:
		if o.sliced:
			continue
		if dino.slashing() and dino.slash_rect().intersects(o.hit_rect()):
			o.slice(dino.position.y - 16.0)  # cut through where the dino's middle meets it
			dino.refund_spin()
			cactus_sliced.emit()
			continue
		if body.intersects(o.hit_rect()):
			dino_hit.emit("Hit a floating cactus")
			return


## Returns false, spawning nothing, when no spot in reach can be cleared from the dino's current state.
func _spawn() -> bool:
	var o := Obstacle.new()
	o.water = water
	# Floating cacti: tall saguaros with arms, or short stubby ones. A real leap or flight needed to clear them.
	if randf() < 0.6:
		o.size = Vector2(randf_range(12, 16), randf_range(120, 150))
		o.arms = 2 if randf() < 0.6 else 1
	else:
		o.size = Vector2(randf_range(16, 20), randf_range(75, 95))
		o.arms = 1 if randf() < 0.5 else 0
	o.sunk = 0.15
	# Sit it under a flight the player can actually make, so the answer is "hit that crest fast and fly over".
	var spots := FlightPlanner.clearable_spots(dino, water, controls, spawn_x, plan_reach_px,
		o.size.x, o.size.y * (1.0 - o.sunk) + clear_margin_px)
	var x: float
	if not spots.is_empty():
		x = spots.pick_random() - water.scroll()
	elif controls.can_leap():
		x = water.next_crest(spawn_x) + randf_range(40.0, 110.0)  # a leap clears anything, so no flight needed
	else:
		o.free()
		return false
	o.rotation = water.slope_angle(x) * o.lean
	o.position = Vector2(x, water.surface_y(x))
	container.add_child(o)
	obstacles.append(o)
	return true
