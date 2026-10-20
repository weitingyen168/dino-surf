extends SceneTree
## Fairness probe for tilt-the-world. Every time debris spawns, snapshots the game and searches tilt input
## sequences (hold one tilt, switch once or twice) from that moment for one that clears it. Debris that no
## sequence clears is reported as impossible, with what the game looked like when it spawned.
## Run: Godot_console.exe --headless --path . --script res://tests/probe_fairness.gd -- [obstacles] [seed]

const DT := 1.0 / 60.0
const STEP := 6  # frames between switch points in the search

var main: Node
var water: Water
var dino: Dino
var controls: Controls
var spawner: ObstacleSpawner
var gulls: GullSpawner
var tsunami: Tsunami


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	want_count = int(args[0]) if args.size() > 0 else 60
	seed(int(args[1]) if args.size() > 1 else 1)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	_run(want_count)
	return true


var want_count := 60
var idle_ok := 0
var forward_ok := 0


func _run(want: int) -> void:
	water = main.water
	dino = main.dino
	controls = main.controls
	spawner = main.obstacle_spawner
	gulls = main.gull_spawner
	tsunami = main.tsunami
	for n in [main, controls, tsunami, spawner, gulls, water, dino]:
		n.set_physics_process(false)

	var impossible := 0
	var done := 0
	var since_last := 0.0
	var gaps: Array = []
	while done < want:
		var px_before: float = spawner.next_spawn_px
		var last = spawner.obstacles.back() if spawner.obstacles.size() > 0 else null
		_step(0.0)
		since_last += dino.speed * DT
		if main.game_over:
			main.restart()
			continue
		if spawner.obstacles.is_empty() or spawner.obstacles.back() == last:
			continue
		var o: Obstacle = spawner.obstacles.back()
		o.set_physics_process(false)
		var info := _describe(o, since_last, px_before)
		since_last = 0.0
		var snap := _snapshot()
		if _play([[1, 0.0]], o, false):
			idle_ok += 1
		_restore(snap)
		if _play([[1, 1.0]], o, false):
			forward_ok += 1
		_restore(snap)
		var plan := _search(o)
		done += 1
		if plan.is_empty():
			impossible += 1
			print("IMPOSSIBLE  ", info)
			main.restart()  # what a player would get: a wipeout, so start fresh
		else:
			_play(plan, o, true)
			gaps.append(info)
	print("debris %d  impossible %d (%.0f%%)  cleared by doing nothing %d  by holding forward %d" % [
		done, impossible, 100.0 * impossible / done, idle_ok, forward_ok])
	quit()


func _describe(o: Obstacle, since_last: float, _px: float) -> String:
	var crest_x: float = o.position.x
	var x := o.position.x
	while x > o.position.x - 200.0:  # walk back to the crest it sits behind
		if water.surface_y(x - 4.0) > water.surface_y(x) and water.surface_y(x + 4.0) >= water.surface_y(x):
			crest_x = x
			break
		x -= 4.0
	var trough := -INF
	x = crest_x - 4.0
	while x > crest_x - 400.0 and water.surface_y(x - 4.0) >= water.surface_y(x):
		x -= 4.0
	trough = water.surface_y(x)
	return "speed %3.0f  air %s  crest_height %3.0f  behind_crest %3.0f  px_since_prev %4.0f  size %.0fx%.0f" % [
		dino.speed, str(not dino.on_surface), trough - water.surface_y(crest_x), o.position.x - crest_x,
		since_last, o.size.x, o.size.y]


## One physics tick in tree order: Main, Controls, Tsunami, spawners, Water, debris, Dino.
func _step(tilt_dir: float) -> void:
	Input.action_release("tilt_forward")
	Input.action_release("tilt_back")
	if tilt_dir > 0.0:
		Input.action_press("tilt_forward")
	elif tilt_dir < 0.0:
		Input.action_press("tilt_back")
	main._physics_process(DT)
	if not main.game_over:
		controls._physics_process(DT)
		tsunami._physics_process(DT)
		spawner._physics_process(DT)
	if not main.game_over:  # a cactus hit just now freezes the gulls too
		gulls._physics_process(DT)
	water._physics_process(DT)
	for o in spawner.obstacles:
		if is_instance_valid(o):
			o.set_physics_process(false)
			o._physics_process(DT)
	dino._physics_process(DT)


## Plan = [[frames, dir], ...]; the last entry holds until the target is passed. Returns true if cleared.
func _play(plan: Array, target: Obstacle, keep_spawning: bool) -> bool:
	var saved_spawn: float = spawner.next_spawn_px
	if not keep_spawning:
		spawner.next_spawn_px = INF
	var seg := 0
	var left: int = plan[0][0]
	var ok := false
	for _f in 600:
		while seg < plan.size() - 1 and left <= 0:
			seg += 1
			left = plan[seg][0]
		_step(plan[seg][1])
		left -= 1
		if main.game_over:
			break
		if target.position.x < dino.position.x - 25.0:
			ok = true
			break
	if not keep_spawning:
		spawner.next_spawn_px = saved_spawn
	return ok


func _search(target: Obstacle) -> Array:
	var snap := _snapshot()
	var frames_to_reach := int((target.position.x - dino.position.x) / maxf(dino.speed, 100.0) / DT) + 30
	var dirs := [1.0, 0.0, -1.0]
	var plans: Array = []
	for d in dirs:
		plans.append([[1, d]])
	for a in dirs:
		for b in dirs:
			if a == b:
				continue
			for s in range(STEP, frames_to_reach, STEP):
				plans.append([[s, a], [1, b]])
	for a in dirs:
		for b in dirs:
			for c in dirs:
				if a == b or b == c:
					continue
				for s in range(STEP * 3, frames_to_reach, STEP * 3):
					for l in range(STEP * 3, frames_to_reach - s, STEP * 3):
						plans.append([[s, a], [l, b], [1, c]])
	for plan in plans:
		_restore(snap)
		if _play(plan, target, false):
			_restore(snap)
			return plan
	_restore(snap)
	return []


func _snapshot() -> Dictionary:
	var obs := []
	for o in spawner.obstacles:
		if is_instance_valid(o):
			obs.append([o, o.position, o.rotation])
	return {
		"h": water._h.duplicate(), "v": water._v.duplicate(), "ph": water._prev_h.duplicate(),
		"scroll": water._scroll, "pscroll": water._prev_scroll, "time": water._time, "ptime": water._prev_time, "wspeed": water.speed,
		"pos": dino.position, "vel": dino.velocity, "speed": dino.speed, "dtilt": dino.tilt, "rot": dino.rotation,
		"on": dino.on_surface, "touch": dino._touching,
		"tilt": controls.tilt, "tv": controls.tilt_vel, "dist": main.distance, "spawn": spawner.next_spawn_px, "obs": obs,
	}


func _restore(s: Dictionary) -> void:
	water._h = s.h.duplicate()
	water._v = s.v.duplicate()
	water._prev_h = s.ph.duplicate()
	water._scroll = s.scroll
	water._prev_scroll = s.pscroll
	water._time = s.time
	water._prev_time = s.ptime
	water.speed = s.wspeed
	dino.position = s.pos
	dino.velocity = s.vel
	dino.speed = s.speed
	dino.tilt = s.dtilt
	dino.rotation = s.rot
	dino.on_surface = s.on
	dino._touching = s.touch
	dino.crashed = false
	controls.tilt = s.tilt
	controls.tilt_vel = s.tv
	main.distance = s.dist
	spawner.next_spawn_px = s.spawn
	main.game_over = false
	Engine.time_scale = 1.0
	spawner.obstacles.clear()
	for e in s.obs:
		e[0].position = e[1]
		e[0].rotation = e[2]
		spawner.obstacles.append(e[0])
