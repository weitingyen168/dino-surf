extends Node2D
## Prototype harness for comparing control schemes.
## Scheme B (default): tilt the world. Right / D tips it forward (downhill, you speed up), Left / A tips it
## back (you slow down); touch: hold the right or left half of the screen. Riding down a face also speeds you up;
## go over a crest fast enough and you fly. Up / W raises the water just behind the dino (build a ramp),
## Down / S pulls it down (flatten a bump).
## Scheme A: hold Space / Up / click to raise the water behind the dino, Down / S to lower it. Tab switches scheme, R resets.
## Hitting floating debris ends the run; press any control to retry.

enum Scheme { A_SHAPE_WAVE, B_TILT_WORLD }

@export var scheme: Scheme = Scheme.B_TILT_WORLD

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

@export_group("Camera")
@export var camera_rest_y: float = 180.0  # camera centre while the dino is on the water
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
@export var spawn_x: float = 680.0  # just off the right edge
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
var game_over := false
var _shake := 0.0
var _game_over_time := 0.0
var _game_over_label: Label
var _next_spawn := 1500.0  # px to go until the next debris; matches first_obstacle_px, _restart resets it
var _obstacles: Array[Obstacle] = []


func _ready() -> void:
	# Smooths motion between 60 Hz physics ticks on faster screens (fixes the stutter).
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	get_tree().physics_interpolation = true
	_setup_input()
	_make_game_over_label()
	dino.water = water
	dino.reset()
	water.speed = dino.speed


func _setup_input() -> void:
	var keys := {
		"surf": [KEY_SPACE, KEY_UP, KEY_W],
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
			or Input.is_action_just_pressed("tilt_forward") or Input.is_action_just_pressed("wave_down")
		if _game_over_time > retry_delay and pressed:
			_restart()
		return
	match scheme:
		Scheme.A_SHAPE_WAVE:
			if Input.is_action_pressed("surf"):
				water.push(dino.position.x + push_offset, push_radius, push_strength, delta)
			elif Input.is_action_pressed("wave_down"):
				water.push(dino.position.x + push_offset, push_radius, -push_strength, delta)
		Scheme.B_TILT_WORLD:
			var target := deg_to_rad(max_tilt_deg) * _tilt_input()
			# Critically damped spring: eases in and out with no overshoot, so the camera and water never jerk.
			var prev_tilt := tilt
			_tilt_vel += (tilt_response * tilt_response * (target - tilt) - 2.0 * tilt_response * _tilt_vel) * delta
			tilt += _tilt_vel * delta
			water.slosh(-slosh_strength * (tilt - prev_tilt))
			var wave := Input.get_axis("wave_down", "wave_up")
			if wave != 0.0:
				water.push(dino.position.x + push_offset, push_radius, wave_strength * wave, delta)
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
		if body.intersects(o.hit_rect()):
			_lose("Hit floating debris")
			return


## Returns false, spawning nothing, when no spot in reach can be cleared from the dino's current state.
func _spawn_obstacle() -> bool:
	var o := Obstacle.new()
	o.water = water
	# Debris: long flat planks or small crates, mostly sunk so a modest throw clears them.
	if randf() < 0.6:
		o.size = Vector2(randf_range(26, 40), randf_range(8, 10))
		o.sunk = 0.5
	else:
		o.size = Vector2(randf_range(14, 20), randf_range(12, 16))
		o.sunk = 0.45
	# Sit it under a flight the player can actually make, so the answer is "hit that crest fast and fly over".
	var spots := _clearable_spots(o.size.x, o.size.y * (1.0 - o.sunk) + clear_margin_px)
	if spots.is_empty():
		o.free()
		return false
	var x: float = spots.pick_random() - water.scroll()
	o.rotation = water.slope_angle(x)
	o.position = Vector2(x, water.surface_y(x))
	add_child(o)
	move_child(o, dino.get_index())  # draw behind the dino
	_obstacles.append(o)
	return true


## World positions (screen x + scroll) past spawn_x where debris `width` wide, standing `height` px above the
## water, would be cleared by the first flight a full forward tilt from right now produces.
## Plays the dino forward on the swell alone (the spring ripples are small): same physics as Dino._float,
## same tilt spring as _physics_process. Debris is fixed in world space, so its top never changes.
func _clearable_spots(width: float, height: float) -> Array[float]:
	var d := dino
	var dt := 1.0 / Engine.physics_ticks_per_second
	var target := deg_to_rad(max_tilt_deg)
	var s := water.scroll()
	var first := spawn_x + s
	var last := first + plan_reach_px
	var y := d.position.y
	var vy := d.velocity.y
	var v := d.speed
	var t := tilt
	var tv := _tilt_vel
	var on := d.on_surface
	var touching := d._touching
	var flights: Array = []  # [dino world x, board y] while airborne
	var in_air := false
	while d.home_x + s < last + width:
		tv += (tilt_response * tilt_response * (target - t) - 2.0 * tilt_response * tv) * dt
		t += tv * dt
		s += v * dt
		var w := d.home_x + s
		var surf := water.swell_y(w)
		var slope := atan2(water.swell_y(w + 4.0) - water.swell_y(w - 4.0), 8.0)
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
			var surf_vy := (surf - water.swell_y(w - v * dt)) / dt
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
			flights.append(Vector2(w, y))
	var spots: Array[float] = []
	if not in_air:
		return spots
	# Body box spans x -14..+12 around the dino; its bottom (the board) must stay above the debris top.
	var x := first
	while x < last:
		var top := water.swell_y(x) - height
		var clear := _covered(flights, x - width / 2.0 - 14.0, x + width / 2.0 + 12.0)
		for p in flights:
			if clear and p.x + 12.0 > x - width / 2.0 and p.x - 14.0 < x + width / 2.0:
				clear = p.y <= top
		if clear:
			spots.append(x)
		x += 4.0
	return spots


## True if the dino is airborne for the whole stretch from x0 to x1 (not on the water anywhere in it).
func _covered(flights: Array, x0: float, x1: float) -> bool:
	return flights.size() > 0 and flights[0].x <= x0 and flights.back().x >= x1


func _process(_delta: float) -> void:
	var names := ["A: shape the wave (hold Space/Up to raise, Down to lower)", "B: tilt the world (Right/Left: tip forward/back, Up/Down: raise/lower water)"]
	label.text = "Scheme %s   (Tab: switch, R: reset)\nSpeed %d   Distance %d   Best %d   Wipeouts %d" % [
		names[scheme], dino.speed, distance, best, wipeouts]


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
	_shake = 0.0
	Engine.time_scale = 1.0
	water.reset()
	dino.reset()
	water.speed = dino.speed
	for o in _obstacles:
		o.queue_free()
	_obstacles.clear()
	_next_spawn = first_obstacle_px


func _make_game_over_label() -> void:
	_game_over_label = Label.new()
	_game_over_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_game_over_label.add_theme_color_override("font_color", Color("535353"))
	_game_over_label.add_theme_font_size_override("font_size", 16)
	_game_over_label.visible = false
	$HUD.add_child(_game_over_label)
