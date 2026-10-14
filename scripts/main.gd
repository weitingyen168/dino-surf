extends Node2D
## Prototype harness for comparing control schemes.
## Hold Space / Up / left mouse / touch to act. Tab switches scheme, R resets.
## Tilt to pop the dino over floating obstacles. Hitting one or landing badly ends the run; press surf again to retry.

enum Scheme { A_SHAPE_WAVE, B_TILT_WORLD }

@export var scheme: Scheme = Scheme.B_TILT_WORLD

@export_group("Control A: shape the wave")
@export var push_offset: float = -30.0  # where to raise the water, relative to the dino
@export var push_radius: float = 50.0
@export var push_strength: float = 2500.0

@export_group("Control B: tilt the world")
@export var max_tilt_deg: float = 25.0
@export var tilt_speed: float = 3.0
@export var camera_tilt_fraction: float = 0.4  # how much of the tilt the camera shows
@export var slosh_strength: float = 600.0  # how much the water surges under the dino when you tilt (looks only; the jump is fixed)

@onready var water: Water = $Water
@onready var dino: Dino = $Dino
@onready var camera: Camera2D = $Camera2D
@onready var label: Label = $HUD/Label

@export var retry_delay: float = 0.6  # seconds after a wipeout before surf restarts, so a held button doesn't skip the screen

@export_group("Obstacles")
@export var spawn_x: float = 680.0  # just off the right edge
@export var min_gap_s: float = 1.6  # seconds between obstacles
@export var max_gap_s: float = 3.0
@export var first_obstacle_s: float = 2.0  # breathing room at the start of a run

var tilt := 0.0
var distance := 0.0
var best := 0.0
var wipeouts := 0
var game_over := false
var _game_over_time := 0.0
var _game_over_label: Label
var _next_spawn := 2.0  # matches first_obstacle_s; _restart resets it
var _obstacles: Array[Obstacle] = []


func _ready() -> void:
	# Smooths motion between 60 Hz physics ticks on faster screens (fixes the stutter).
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	get_tree().physics_interpolation = true
	_setup_input()
	_make_game_over_label()
	dino.water = water
	dino.wiped_out.connect(_on_wiped_out)
	dino.reset()


func _setup_input() -> void:
	if InputMap.has_action("surf"):
		return
	InputMap.add_action("surf")
	for keycode in [KEY_SPACE, KEY_UP, KEY_W]:
		var key := InputEventKey.new()
		key.physical_keycode = keycode
		InputMap.action_add_event("surf", key)
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


func _physics_process(delta: float) -> void:
	if game_over:
		_game_over_time += delta
		if _game_over_time > retry_delay and Input.is_action_just_pressed("surf"):
			_restart()
		return
	var held := Input.is_action_pressed("surf")
	match scheme:
		Scheme.A_SHAPE_WAVE:
			if held:
				water.push(dino.position.x + push_offset, push_radius, push_strength, delta)
		Scheme.B_TILT_WORLD:
			if Input.is_action_just_pressed("surf"):
				dino.jump()
			dino.holding = held
			var target := deg_to_rad(max_tilt_deg) if held else 0.0
			var prev_tilt := tilt
			tilt = move_toward(tilt, target, tilt_speed * delta)
			water.slosh(-slosh_strength * (tilt - prev_tilt))
	# Positive tilt pulls gravity forward (to the right); the camera leans so the world looks tipped.
	dino.gravity_dir = Vector2.DOWN.rotated(-tilt)
	camera.rotation = -tilt * camera_tilt_fraction

	distance += water.swell_speed * delta / 10.0
	best = maxf(best, distance)

	_next_spawn -= delta
	if _next_spawn <= 0.0:
		_spawn_obstacle()
		_next_spawn = randf_range(min_gap_s, max_gap_s)
	_obstacles = _obstacles.filter(func(o): return is_instance_valid(o))
	var body := dino.hit_rect()
	for o in _obstacles:
		if body.intersects(o.hit_rect()):
			_lose("Hit an obstacle")
			return


func _spawn_obstacle() -> void:
	var o := Obstacle.new()
	o.water = water
	o.size = Vector2(14, 18) if randf() < 0.6 else Vector2(18, 28)  # small rock or tall buoy
	o.position = Vector2(spawn_x, water.surface_y(spawn_x))
	add_child(o)
	move_child(o, dino.get_index())  # draw behind the dino
	_obstacles.append(o)


func _process(_delta: float) -> void:
	var names := ["A: shape the wave", "B: tilt the world"]
	label.text = "Scheme %s   (Tab: switch, R: reset)\nHold Space / click\nDistance %d   Best %d   Wipeouts %d" % [
		names[scheme], distance, best, wipeouts]


func _on_wiped_out() -> void:
	_lose("Bad landing")


func _lose(reason: String) -> void:
	if game_over:
		return
	game_over = true
	_game_over_time = 0.0
	wipeouts += 1
	dino.set_physics_process(false)
	for o in _obstacles:
		o.set_physics_process(false)
	_game_over_label.text = "WIPEOUT
" + reason + "

Distance %d   Best %d
Press Space or click to surf again" % [distance, best]
	_game_over_label.visible = true


func _restart() -> void:
	game_over = false
	_game_over_label.visible = false
	distance = 0.0
	tilt = 0.0
	water.reset()
	dino.reset()
	dino.set_physics_process(true)
	for o in _obstacles:
		o.queue_free()
	_obstacles.clear()
	_next_spawn = first_obstacle_s


func _make_game_over_label() -> void:
	_game_over_label = Label.new()
	_game_over_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_game_over_label.add_theme_color_override("font_color", Color("535353"))
	_game_over_label.add_theme_font_size_override("font_size", 16)
	_game_over_label.visible = false
	$HUD.add_child(_game_over_label)
