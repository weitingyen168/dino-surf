extends SceneTree
## Headless tuning harness. Plays main.tscn with a scripted hold pattern and prints stats.
## Run (from the project folder; --fixed-fps skips real-time waiting):
##   Godot_console.exe --headless --fixed-fps 60 --path . --script res://tests/sim_scheme.gd -- scheme hold_s release_s seconds [stickiness]
## scheme: 0 = A, 1 = B. A stickiness below 0 keeps the default.

var main: Node
var frames := 0
var total_frames := 0
var hold_s := 0.4
var release_s := 0.6
var launches := 0
var wipeouts := 0
var max_air := 0.0
var air_time := 0.0
var min_surface_vy := 0.0
var was_on := true
var launch_y := 0.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var scheme := int(args[0]) if args.size() > 0 else 0
	hold_s = float(args[1]) if args.size() > 1 else hold_s
	release_s = float(args[2]) if args.size() > 2 else release_s
	total_frames = int((float(args[3]) if args.size() > 3 else 20.0) * 60)
	main = load("res://scenes/main.tscn").instantiate()
	main.get_node("Controls").scheme = scheme
	if args.size() > 4 and float(args[4]) >= 0.0:
		main.get_node("Dino").stickiness = float(args[4])
	root.add_child(main)


func _physics_process(delta: float) -> bool:
	var t := frames * delta
	var action := "surf" if main.controls.scheme == 0 else "tilt_forward"  # A holds surf, B tilts forward
	if fmod(t, hold_s + release_s) < hold_s:
		Input.action_press(action)
	else:
		Input.action_release(action)
	var dino = main.dino
	min_surface_vy = minf(min_surface_vy, main.water.surface_velocity_y(dino.position.x))
	if was_on and not dino.on_surface:
		launches += 1
		launch_y = dino.position.y
	if not dino.on_surface:
		air_time += delta
		max_air = maxf(max_air, main.water.surface_y(dino.position.x) - dino.position.y)
	was_on = dino.on_surface
	wipeouts = main.wipeouts
	frames += 1
	if frames >= total_frames:
		print("stick=%.0f hold=%.2f release=%.2f  launches=%d  wipeouts=%d  airtime=%.1fs  max_air=%.0fpx  fastest_rise=%.0fpx/s" % [
			main.dino.stickiness, hold_s, release_s, launches, wipeouts, air_time, max_air, -min_surface_vy])
		return true
	return false
