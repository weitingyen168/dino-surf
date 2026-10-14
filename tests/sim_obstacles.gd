extends SceneTree
## Headless bot for the obstacle game: when the next obstacle is `lead` px away, holds surf for `hold_s`, then lets go.
## Prints how many obstacles it cleared vs hit, so we can tell if jumps are reliable.
## Run: Godot_console.exe --headless --fixed-fps 60 --path . --script res://tests/sim_obstacles.gd -- lead_px hold_s seconds

var main: Node
var frames := 0
var total_frames := 0
var lead := 150.0
var hold_s := 0.25
var hold_left := 0.0
var targeted := {}
var passed := {}
var cleared := 0
var hits := 0
var landings := 0
var hooked := false
var launches := 0
var max_air := 0.0
var was_on := true


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	lead = float(args[0]) if args.size() > 0 else lead
	hold_s = float(args[1]) if args.size() > 1 else hold_s
	total_frames = int((float(args[2]) if args.size() > 2 else 60.0) * 60)
	seed(1)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _physics_process(delta: float) -> bool:
	if not hooked:
		hooked = true
		main.dino.wiped_out.connect(func(): if not main.game_over: landings += 1)
	if main.game_over:
		if not passed.has("go%d" % main.wipeouts):
			passed["go%d" % main.wipeouts] = true
			if main._game_over_label.text.contains("obstacle"):
				hits += 1
		Input.action_release("surf")
		if main._game_over_time > main.retry_delay + 0.1:
			Input.action_press("surf")
			main._restart()
		frames += 1
		return _done()
	var dx: float = main.dino.position.x
	if was_on and not main.dino.on_surface:
		launches += 1
	was_on = main.dino.on_surface
	if not main.dino.on_surface:
		max_air = maxf(max_air, main.water.surface_y(dx) - main.dino.position.y)
	for o in main._obstacles:
		if not is_instance_valid(o):
			continue
		var id: int = o.get_instance_id()
		if not targeted.has(id) and o.position.x - dx < lead and o.position.x > dx:
			targeted[id] = true
			hold_left = hold_s
		if not passed.has(id) and o.position.x < dx - 25.0:
			passed[id] = true
			cleared += 1
	if hold_left > 0.0:
		hold_left -= delta
		Input.action_press("surf")
	else:
		Input.action_release("surf")
	frames += 1
	return _done()


func _done() -> bool:
	if frames < total_frames:
		return false
	var tries := cleared + hits
	print("lead=%3.0fpx hold=%.2fs  cleared=%d  hit=%d  bad_landings=%d  clear_rate=%d%%  launches=%d  max_air=%.0fpx" % [
		lead, hold_s, cleared, hits, landings, 100 * cleared / maxi(tries, 1), launches, max_air])
	return true
