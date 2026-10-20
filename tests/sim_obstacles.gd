extends SceneTree
## Headless bot for tilt-the-world: holds a fixed tilt (-1 always back, 0 level, 1 always forward),
## or with `lead` > 0 stays level and only tilts forward while debris is within `lead` px ahead.
## Prints speed, how often and how high it flew, and how much debris it cleared vs hit.
## Run: Godot_console.exe --headless --fixed-fps 60 --path . --script res://tests/sim_obstacles.gd -- throttle seconds [lead] [no_debris]

var main: Node
var frames := 0
var total_frames := 0
var throttle := 0.0
var lead := 0.0
var passed := {}
var cleared := 0
var hits := 0
var throws := 0
var air_now := 0.0
var heights: Array[float] = []
var speeds: Array[float] = []
var was_on := true


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	throttle = float(args[0]) if args.size() > 0 else throttle
	total_frames = int((float(args[1]) if args.size() > 1 else 60.0) * 60)
	seed(1)
	main = load("res://scenes/main.tscn").instantiate()
	lead = float(args[2]) if args.size() > 2 else 0.0
	if args.size() > 3 and args[3] == "no_debris":
		main.get_node("ObstacleSpawner").first_obstacle_px = INF
	root.add_child(main)


func _physics_process(_delta: float) -> bool:
	Input.action_release("tilt_forward")
	Input.action_release("tilt_back")
	if main.game_over:
		if not passed.has("go%d" % main.wipeouts):
			passed["go%d" % main.wipeouts] = true
			hits += 1
		if main._game_over_time > main.retry_delay + 0.1:
			main.restart()
		frames += 1
		return _done()
	var dino = main.dino
	var t := throttle
	if lead > 0.0:
		t = 0.0
		for o in main.obstacle_spawner.obstacles:
			if is_instance_valid(o) and o.position.x > dino.position.x - 20.0 and o.position.x - dino.position.x < lead:
				t = 1.0
	if t > 0.0:
		Input.action_press("tilt_forward", t)
	elif t < 0.0:
		Input.action_press("tilt_back", -t)
	speeds.append(dino.speed)
	var gap: float = main.water.surface_y(dino.position.x) - dino.position.y
	if was_on and not dino.on_surface and gap > 2.0:
		throws += 1
		air_now = 0.0
	if not dino.on_surface:
		air_now = maxf(air_now, gap)
	elif not was_on and air_now > 2.0:
		heights.append(air_now)
		air_now = 0.0
	if dino.on_surface or gap > 2.0:
		was_on = dino.on_surface
	for o in main.obstacle_spawner.obstacles:
		if is_instance_valid(o) and not passed.has(o.get_instance_id()) and o.position.x < dino.position.x - 25.0:
			passed[o.get_instance_id()] = true
			cleared += 1
	frames += 1
	return _done()


func _done() -> bool:
	if frames < total_frames:
		return false
	speeds.sort()
	heights.sort()
	var med_h: float = heights[heights.size() / 2] if heights.size() > 0 else 0.0
	var max_h: float = heights.back() if heights.size() > 0 else 0.0
	print("throttle=%+.1f lead=%.0f  speed %.0f..%.0f (median %.0f)  throws=%d  height median=%.0f max=%.0f  debris cleared=%d hit=%d" % [
		throttle, lead, speeds[0], speeds.back(), speeds[speeds.size() / 2], throws, med_h, max_h, cleared, hits])
	return true
