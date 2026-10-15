extends Node2D
## Prototype harness for comparing control schemes.
## Scheme D (default): spin slice. Everything from C, plus X / Shift spins the dino: a cactus caught by the spin
## (Dino.slash_rect) is sliced in half and you surf on. Mistime it and you hit the cactus as usual.
## Only one spin per jump: after spinning in the air, you can't spin again until you touch the water,
## unless the spin hit something: every slice or knocked gull gives the spin back, so you can chain them.
## Scheme C: leap and shift. Tilts like B on the water, but Down then Up (within leap_window) leaps,
## and in the air Left / Right shift the whole ocean, debris included, back / forward to pick where you land.
## Scheme B: tilt the world. Right / D tips it forward (downhill, you speed up), Left / A tips it
## back (you slow down); touch: hold the right or left half of the screen. Riding down a face also speeds you up;
## go over a crest fast enough and you fly. Up / W raises the water just behind the dino (build a ramp),
## Down / S pulls it down (flatten a bump).
## Scheme A: hold Up / click to raise the water behind the dino, Down / S to lower it. Tab switches scheme, R resets.
## Hitting floating debris ends the run; press any control to retry.
## Tsunami: in every scheme the water well behind the dino is always pushed up into a big hump (like holding
## scheme A's Up, but bigger and further back), so the dino rides its front slope and keeps getting shoved forward.
## Space (any scheme): bulge the water up just in front of the dino, a ramp to fly off.
## Seagulls fly in the sky, more of them the higher up (gull_height_bias). Hitting one wipes you out.

enum Scheme { A_SHAPE_WAVE, B_TILT_WORLD, C_LEAP_SHIFT, D_SPIN_SLICE }

@export var scheme: Scheme = Scheme.D_SPIN_SLICE

@export_group("Control A: shape the wave")
@export var push_offset: float = -30.0  # where to raise the water, relative to the dino
@export var push_radius: float = 50.0
@export var push_strength: float = 2500.0

@export_group("Control B: tilt the world")
@export var max_tilt_deg: float = 25.0
@export var wave_strength: float = 2500.0  # Up / Down: how hard the water behind the dino is pushed up / pulled down; uses push_offset and push_radius
@export var tilt_response: float = 5.5  # how quickly the tilt eases toward its target; it speeds up and slows down smoothly
@export var camera_tilt_fraction: float = 0.5  # how much of the tilt the camera shows
@export var slosh_strength: float = 800.0  # how much the water rolls when you tilt; 0 turns it off

@export_group("Control C: leap and shift")
@export var leap_window: float = 0.35  # seconds after letting go of Down in which Up still leaps

@export_group("Tsunami")
@export var tsunami_offset: float = -120.0  # centre of the always-on hump, relative to the dino
@export var tsunami_radius: float = 120.0  # half-width; its front foot reaches the dino when radius = -offset
@export var tsunami_strength: float = 3000.0  # how hard it's pushed up (scheme A's Up is 2500 over radius 50); 0 turns it off

@export_group("Bulge (Space)")
@export var bulge_offset: float = 50.0  # centre of the bulge, relative to the dino; + = in front
@export var bulge_radius: float = 45.0
@export var bulge_strength: float = 3000.0

@export_group("Seagulls")
@export var gull_min_gap_px: float = 250.0  # distance travelled between gulls
@export var gull_max_gap_px: float = 550.0
@export var first_gull_px: float = 900.0
@export var gull_min_alt: float = 110.0  # px above the calm water line; low enough to matter, above normal surfing
@export var gull_max_alt: float = 300.0  # keep within the view while surfing
@export var gull_height_bias: float = 1.5  # 0 = spread evenly; higher = packed toward the top, so flying high is riskier

@export_group("Camera")
@export var camera_zoom: float = 0.75  # < 1 zooms out: shows more ocean and sky (0.75 = about 850×480 of the world)
@export var camera_rest_y: float = 160.0  # camera centre while the dino is on the water
@export var camera_headroom: float = 70.0  # when the dino flies high, the camera centre stays this far below it
@export var camera_follow: float = 5.0  # how quickly the camera catches up

@onready var water: Water = $Water
@onready var dino: Dino = $Dino
@onready var camera: Camera2D = $Camera2D
@onready var label: Label = $HUD/Label

@export var retry_delay: float = 0.8  # seconds after a wipeout before a press restarts, so a held button doesn't skip the screen

@export_group("Wipeout")
@export var crash_slowmo_scale: float = 0.35  # time runs this slow right after a wipeout
@export var crash_slowmo_s: float = 0.45  # real seconds of slow motion
@export var crash_shake_px: float = 5.0
@export var show_wipeout_after: float = 0.5  # let the tumble play before the WIPEOUT text covers it

@export_group("Obstacles")
@export var spawn_x: float = 820.0  # just off the right edge (the zoomed-out view reaches about x = 750)
@export var min_gap_px: float = 450.0  # distance travelled between debris
@export var max_gap_px: float = 900.0
@export var first_obstacle_px: float = 1500.0  # breathing room at the start of a run
## Debris only goes where a full forward tilt from right now would fly over it with this many px to spare,
## so every piece is clearable from wherever the last one left you. Higher = more forgiving.
@export var clear_margin_px: float = 8.0
@export var plan_reach_px: float = 700.0  # how far past spawn_x to look for a spot
@export var retry_spawn_px: float = 60.0  # no clearable spot in reach: look again after this far

var tilt := 0.0
var _tilt_vel := 0.0
var distance := 0.0
var best := 0.0
var wipeouts := 0
var sliced := 0
var game_over := false
var _shake := 0.0
var _game_over_time := 0.0
var _game_over_label: Label
var _leap_window_left := 0.0  # > 0 while Down is held or was just let go: an Up press now leaps
var _next_spawn := 1500.0  # px to go until the next debris; matches first_obstacle_px, _restart resets it
var _obstacles: Array[Obstacle] = []
var _gulls: Array[Seagull] = []
var _next_gull := 900.0  # px to go until the next gull; _restart resets it to first_gull_px


func _ready() -> void:
	# Smooths motion between 60 Hz physics ticks on faster screens (fixes the stutter).
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	camera.zoom = Vector2.ONE * camera_zoom
	get_tree().physics_interpolation = true
	_setup_input()
	_make_game_over_label()
	dino.water = water
	dino.reset()
	water.speed = dino.speed


func _setup_input() -> void:
	var keys := {
		"surf": [KEY_UP, KEY_W],
		"bulge": [KEY_SPACE],
		"spin": [KEY_X, KEY_SHIFT],
		"tilt_back": [KEY_LEFT, KEY_A],
		"tilt_forward": [KEY_RIGHT, KEY_D],
		"wave_up": [KEY_UP, KEY_W],
		"wave_down": [KEY_DOWN, KEY_S],
	}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for keycode in keys[action]:
			var key := InputEventKey.new()
			key.physical_keycode = keycode
			InputMap.action_add_event(action, key)
		if action == "surf":
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT  # touch arrives as mouse via emulate_mouse_from_touch
			InputMap.action_add_event("surf", click)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_TAB:
				scheme = ((scheme + 1) % Scheme.size()) as Scheme
				_restart()
			KEY_R:
				_restart()


## -1 = tilting back, 1 = tilting forward, 0 = level. Holding the mouse / a finger on one half of the screen counts too.
func _tilt_input() -> float:
	var dir := Input.get_axis("tilt_back", "tilt_forward")
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		dir = -1.0 if get_viewport().get_mouse_position().x < get_viewport().get_visible_rect().size.x / 2.0 else 1.0
	return dir


func _physics_process(delta: float) -> void:
	_shake = move_toward(_shake, 0.0, 30.0 * delta)
	var cam_target := minf(camera_rest_y, dino.position.y + camera_headroom)
	camera.position.y = lerpf(camera.position.y, cam_target, camera_follow * delta)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	if game_over:
		water.speed = move_toward(water.speed, 0.0, 600.0 * delta)  # the ocean coasts to a stop behind the crash
		_game_over_time += delta
		_game_over_label.visible = _game_over_time > show_wipeout_after
		var pressed := Input.is_action_just_pressed("surf") or Input.is_action_just_pressed("tilt_back") \
			or Input.is_action_just_pressed("tilt_forward") or Input.is_action_just_pressed("wave_down") \
			or Input.is_action_just_pressed("bulge") or Input.is_action_just_pressed("spin")
		if _game_over_time > retry_delay and pressed:
			_restart()
		return
	if tsunami_strength > 0.0:
		water.push(dino.position.x + tsunami_offset, tsunami_radius, tsunami_strength, delta)
	if Input.is_action_pressed("bulge"):
		water.push(dino.position.x + bulge_offset, bulge_radius, bulge_strength, delta)
	match scheme:
		Scheme.A_SHAPE_WAVE:
			if Input.is_action_pressed("surf"):
				water.push(dino.position.x + push_offset, push_radius, push_strength, delta)
			elif Input.is_action_pressed("wave_down"):
				water.push(dino.position.x + push_offset, push_radius, -push_strength, delta)
		Scheme.B_TILT_WORLD, Scheme.C_LEAP_SHIFT, Scheme.D_SPIN_SLICE:
			var target := deg_to_rad(max_tilt_deg) * _tilt_input()
			# Critically damped spring: eases in and out with no overshoot, so the camera and water never jerk.
			var prev_tilt := tilt
			_tilt_vel += (tilt_response * tilt_response * (target - tilt) - 2.0 * tilt_response * _tilt_vel) * delta
			tilt += _tilt_vel * delta
			water.slosh(-slosh_strength * (tilt - prev_tilt))
			if scheme == Scheme.B_TILT_WORLD:
				var wave := Input.get_axis("wave_down", "wave_up")
				if wave != 0.0:
					water.push(dino.position.x + push_offset, push_radius, wave_strength * wave, delta)
			else:
				_leap_input(delta)
	# Scheme C: in the air, Left / Right speed up / slow down the whole ocean (and the debris riding it).
	dino.air_input = _tilt_input() if scheme in [Scheme.C_LEAP_SHIFT, Scheme.D_SPIN_SLICE] else 0.0
	if scheme == Scheme.D_SPIN_SLICE and Input.is_action_just_pressed("spin"):
		dino.spin()
	# Positive tilt tips the world down toward the direction of travel; the camera leans to show it.
	dino.tilt = tilt
	camera.rotation = -tilt * camera_tilt_fraction
	water.speed = dino.speed

	distance += water.speed * delta / 10.0
	best = maxf(best, distance)

	_next_spawn -= water.speed * delta
	if _next_spawn <= 0.0:
		_next_spawn = randf_range(min_gap_px, max_gap_px) if _spawn_obstacle() else retry_spawn_px
	_obstacles = _obstacles.filter(func(o): return is_instance_valid(o))
	var body := dino.hit_rect()
	for o in _obstacles:
		if o.sliced:
			continue
		if dino.slashing() and dino.slash_rect().intersects(o.hit_rect()):
			o.slice(dino.position.y - 16.0)  # cut through where the dino's middle meets it
			dino.refund_spin()
			sliced += 1
			_shake = maxf(_shake, 2.0)
			continue
		if body.intersects(o.hit_rect()):
			_lose("Hit a floating cactus")
			return

	_next_gull -= water.speed * delta
	if _next_gull <= 0.0:
		_spawn_gull()
		_next_gull = randf_range(gull_min_gap_px, gull_max_gap_px)
	_gulls = _gulls.filter(func(g): return is_instance_valid(g))
	for g in _gulls:
		if g.knocked:
			continue
		if dino.slashing() and dino.slash_rect().intersects(g.hit_rect()):
			g.knock()
			dino.refund_spin()
			_shake = maxf(_shake, 2.0)
			continue
		if body.intersects(g.hit_rect()):
			_lose("Hit a seagull")
			return


## A gull just off the right edge. Altitude density rises with height: the pdf is proportional to
## altitude^gull_height_bias, so u^(1 / (bias + 1)) samples it.
func _spawn_gull() -> void:
	var g := Seagull.new()
	g.water = water
	var u := pow(randf(), 1.0 / (gull_height_bias + 1.0))
	g.altitude = water.base_y - lerpf(gull_min_alt, gull_max_alt, u)
	g.position = Vector2(spawn_x + 30.0, g.altitude)
	add_child(g)
	move_child(g, dino.get_index())  # draw behind the dino
	_gulls.append(g)


## Returns false, spawning nothing, when no spot in reach can be cleared from the dino's current state.
## Down then Up leaps: holding Down crouches, and Up while crouched or within leap_window after letting go jumps.
func _leap_input(delta: float) -> void:
	dino.crouching = Input.is_action_pressed("wave_down")
	if dino.crouching:
		_leap_window_left = leap_window
	else:
		_leap_window_left = maxf(_leap_window_left - delta, 0.0)
	if Input.is_action_just_pressed("wave_up") and _leap_window_left > 0.0 and dino.leap():
		_leap_window_left = 0.0


func _spawn_obstacle() -> bool:
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
	var spots := _clearable_spots(o.size.x, o.size.y * (1.0 - o.sunk) + clear_margin_px)
	var x: float
	if not spots.is_empty():
		x = spots.pick_random() - water.scroll()
	elif scheme in [Scheme.C_LEAP_SHIFT, Scheme.D_SPIN_SLICE]:
		x = water.next_crest(spawn_x) + randf_range(40.0, 110.0)  # a leap clears anything, so no flight needed
	else:
		o.free()
		return false
	o.rotation = water.slope_angle(x) * o.lean
	o.position = Vector2(x, water.surface_y(x))
	add_child(o)
	move_child(o, dino.get_index())  # draw behind the dino
	_obstacles.append(o)
	return true


## World positions (screen x + scroll) past spawn_x where debris `width` wide, standing `height` px above the
## water, would be cleared by the first flight a full forward tilt from right now produces.
## Plays the dino forward on the swell alone (the spring ripples are small): same physics as Dino._float,
## same tilt spring as _physics_process. The swells travel, so it steps time too; debris stays put in world
## space but bobs with the swell under it.
func _clearable_spots(width: float, height: float) -> Array[float]:
	var d := dino
	var dt := 1.0 / Engine.physics_ticks_per_second
	var target := deg_to_rad(max_tilt_deg)
	var s := water.scroll()
	var now := water.time()
	var first := spawn_x + s
	var last := first + plan_reach_px
	var y := d.position.y
	var vy := d.velocity.y
	var v := d.speed
	var t := tilt
	var tv := _tilt_vel
	var on := d.on_surface
	var touching := d._touching
	var flights: Array[Vector3] = []  # (dino world x, board y, time) while airborne
	var in_air := false
	while d.home_x + s < last + width:
		tv += (tilt_response * tilt_response * (target - t) - 2.0 * tilt_response * tv) * dt
		t += tv * dt
		s += v * dt
		now += dt
		var w := d.home_x + s
		var surf := water.swell_y(w, now)
		var slope := atan2(water.swell_y(w + 4.0, now) - water.swell_y(w - 4.0, now), 8.0)
		var depth := y - surf
		var accel := d.gravity
		if depth >= 0.0:
			if not on:
				var along := Vector2.from_angle(slope)
				v = clampf(maxf(Vector2(v, vy).dot(along) * along.x, d.min_speed), d.min_speed, d.max_speed)
				if in_air and flights.back().x >= first:
					break  # landed: only the first flight that reaches the spawn point counts, later ones depend on it
				flights.clear()  # a flight that ends before the spawn point (e.g. the current one) doesn't help
				in_air = false
			var surf_vy := (surf - water.swell_y(w - v * dt, now - dt)) / dt
			accel -= d.gravity + d.buoyancy * depth + d.water_drag * (vy - surf_vy)
			touching = true
			var downhill := slope + t
			v += d.gravity * sin(downhill) * cos(downhill) * d.slope_gain * dt
			v -= v * d.water_friction * dt
		elif touching and depth > -d.stick_range:
			accel += d.stickiness
		else:
			touching = false
		v = clampf(v, d.min_speed, d.max_speed)
		vy += accel * dt
		y += vy * dt
		on = depth > -1.0
		if not on:
			in_air = in_air or depth < -2.0
			flights.append(Vector3(w, y, now))
	var spots: Array[float] = []
	if not in_air:
		return spots
	# Body box spans x -14..+12 around the dino; its bottom (the board) must stay above the debris top.
	var x := first
	while x < last:
		var clear := _covered(flights, x - width / 2.0 - 14.0, x + width / 2.0 + 12.0)
		for p in flights:
			if clear and p.x + 12.0 > x - width / 2.0 and p.x - 14.0 < x + width / 2.0:
				clear = p.y <= water.swell_y(x, p.z) - height
		if clear:
			spots.append(x)
		x += 4.0
	return spots


## True if the dino is airborne for the whole stretch from x0 to x1 (not on the water anywhere in it).
func _covered(flights: Array[Vector3], x0: float, x1: float) -> bool:
	return flights.size() > 0 and flights[0].x <= x0 and flights.back().x >= x1


func _process(_delta: float) -> void:
	var names := ["A: shape the wave (hold Up to raise, Down to lower)", "B: tilt the world (Right/Left: tip forward/back, Up/Down: raise/lower water)",
		"C: leap and shift (Down then Up: leap, Right/Left: tilt, in the air shift the ocean)",
		"D: spin slice (X/Shift: spin through a cactus, plus everything from C)"]
	label.text = "Scheme %s   (Space: bulge ahead, Tab: switch, R: reset)\nSpeed %d   Distance %d   Best %d   Wipeouts %d   Sliced %d" % [
		names[scheme], dino.speed, distance, best, wipeouts, sliced]


func _lose(reason: String) -> void:
	if game_over:
		return
	game_over = true
	_game_over_time = 0.0
	wipeouts += 1
	dino.crash()
	_shake = crash_shake_px
	for o in _obstacles:
		o.set_physics_process(false)
	for g in _gulls:
		if is_instance_valid(g):
			g.set_physics_process(false)
	# Brief slow motion so the crash reads, timed in real seconds.
	Engine.time_scale = crash_slowmo_scale
	get_tree().create_timer(crash_slowmo_s, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)
	_game_over_label.text = "WIPEOUT
" + reason + "

Distance %d   Best %d
Press any control to surf again" % [distance, best]


func _restart() -> void:
	game_over = false
	_game_over_label.visible = false
	distance = 0.0
	tilt = 0.0
	_tilt_vel = 0.0
	_leap_window_left = 0.0
	_shake = 0.0
	Engine.time_scale = 1.0
	water.reset()
	dino.reset()
	water.speed = dino.speed
	for o in _obstacles:
		o.queue_free()
	_obstacles.clear()
	_next_spawn = first_obstacle_px
	for g in _gulls:
		if is_instance_valid(g):
			g.queue_free()
	_gulls.clear()
	_next_gull = first_gull_px


func _make_game_over_label() -> void:
	_game_over_label = Label.new()
	_game_over_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_game_over_label.add_theme_color_override("font_color", Color("535353"))
	_game_over_label.add_theme_font_size_override("font_size", 16)
	_game_over_label.visible = false
	$HUD.add_child(_game_over_label)
