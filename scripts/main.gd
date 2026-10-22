extends Node2D
## Runs a surf session: keeps score (the distance surfed, plus combo points for kills; the best is saved between
## sessions), ends the run on a
## wipeout and restarts it. R resets.
## Everything else is its own node; tree order is tick order, so the input and spawning run before the water moves:
##   Controls         player input -> leap, spin, fast fall, bulge
##   Tsunami          the always-on hump behind the dino
##   ObstacleSpawner  plants cacti the player can clear, reports slices and hits
##   GullSpawner      sends in seagulls, reports kills and hits
##   Background       pixel art behind everything (the furthest card in 3D)
##   Water            the ocean surface
##   Hazards          holds the spawned cacti and gulls, drawn behind the dino
##   Dino             the surfer
##   Camera2D         follow, lean and shake
##   View3D           redraws all of the above as a 3D pop-up book (V: flat 2D view)
##   Sounds           music and sound effects
##   Invert           flips the colours at every 1000 points
##   HUD              score, combo, warning markers for what's coming, the WIPEOUT screen, and the start screen (HUD/Title) that holds the game paused

@export var milestone_points: float = 1000.0  # a chime and a colour flip every this many points

@export_group("Combo")
## Every kill (a sliced cactus, a knocked gull) scores kill_points times how many in a row: 25, 50, 75...
## The chain keeps going while each kill comes within combo_window_s of the last; a missed spin ends it.
@export var kill_points: float = 25.0
@export var combo_window_s: float = 2.0

@export_group("Pace")
## Like the Chrome Dino, the run speeds up steadily the longer you last, from pace_start_speed to pace_end_speed
## by pace_ramp_points; the waves carry the dino up and down but don't change its speed. To show it, the water
## tilts downhill toward the dino's way (only the water: the sand and the camera stay level).
@export var pace_start_speed: float = 260.0
@export var pace_end_speed: float = 680.0
@export var pace_tilt_deg: float = 12.0
@export var pace_ramp_points: float = 3500.0
@export var retry_delay: float = 0.8  # seconds after a wipeout before a press restarts, so a held button doesn't skip the screen

@export_group("Wipeout")
@export var crash_slowmo_scale: float = 0.35  # time runs this slow right after a wipeout
@export var crash_slowmo_s: float = 0.45  # real seconds of slow motion
@export var crash_shake_px: float = 5.0
@export var hit_shake_px: float = 2.0  # slicing a cactus or knocking a gull
@export var show_wipeout_after: float = 0.5  # let the tumble play before the WIPEOUT text covers it

@onready var controls: Controls = $Controls
@onready var tsunami: Tsunami = $Tsunami
@onready var obstacle_spawner: ObstacleSpawner = $ObstacleSpawner
@onready var gull_spawner: GullSpawner = $GullSpawner
@onready var water: Water = $Water
@onready var hazards: Node2D = $Hazards
@onready var dino: Dino = $Dino
@onready var camera: GameCamera = $Camera2D
@onready var hud: Hud = $HUD
@onready var sounds: Sounds = $Sounds
@onready var invert: InvertScreen = $Invert
@onready var view: View3D = $View3D

var distance := 0.0  # surfed this run, in points; drives the pace
var bonus := 0.0  # combo points this run
var combo := 0  # kills in a row
var best := 0.0
var _combo_left := 0.0  # seconds left for the next kill to keep the combo going
var _milestones := 0  # milestone_points passed this run
var wipeouts := 0
var sliced := 0
var game_over := false
var _game_over_time := 0.0


const SAVE_PATH := "user://dino_surf.cfg"  # on the web this lives in the browser's storage


func _ready() -> void:
	get_tree().physics_interpolation = true
	water.tilt_pivot_x = dino.home_x
	$HUD/Lookahead.setup(obstacle_spawner, gull_spawner, view)
	var save := ConfigFile.new()
	if save.load(SAVE_PATH) == OK:
		best = save.get_value("score", "best", 0.0)
	obstacle_spawner.dino_hit.connect(_lose)
	obstacle_spawner.cactus_sliced.connect(_on_cactus_sliced)
	gull_spawner.dino_hit.connect(_lose)
	gull_spawner.gull_knocked.connect(_on_kill)
	dino.spin_missed.connect(_end_combo)
	dino.spun.connect(sounds.spin)
	restart()
	# The start screen holds the first run: ocean waves until the player starts, then the music.
	var title := get_node_or_null("HUD/Title") as TitleScreen
	if title and not title.is_queued_for_deletion():
		sounds.menu()
		title.started.connect(sounds.run_started)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_R:
				restart()


func _physics_process(delta: float) -> void:
	if game_over:
		water.speed = move_toward(water.speed, 0.0, 600.0 * delta)  # the ocean coasts to a stop behind the crash
		_game_over_time += delta
		hud.show_wipeout(_game_over_time > show_wipeout_after)
		if _game_over_time > retry_delay and controls.any_just_pressed():
			restart()
		return
	var pace := clampf(distance / pace_ramp_points, 0.0, 1.0)
	water.tilt = deg_to_rad(pace_tilt_deg) * pace
	dino.speed = lerpf(pace_start_speed, pace_end_speed, pace)
	water.speed = dino.speed
	distance += water.speed * delta / 10.0
	_combo_left -= delta
	if combo > 0 and _combo_left <= 0.0:
		_end_combo()
	if floorf(score() / milestone_points) > _milestones:
		_milestones = int(floorf(score() / milestone_points))
		sounds.milestone()
		invert.toggle()
		hud.set_inverted(invert.inverted)
	best = maxf(best, score())


func _process(_delta: float) -> void:
	hud.show_score(score(), best)


## The run's score: distance surfed plus combo points.
func score() -> float:
	return distance + bonus


func _on_cactus_sliced() -> void:
	sliced += 1
	_on_kill()


## A kill keeps the combo going and scores kill_points times the length of the chain.
func _on_kill() -> void:
	camera.shake(hit_shake_px)
	combo += 1
	_combo_left = combo_window_s
	var points := kill_points * combo
	bonus += points
	hud.show_combo(combo, points)


func _end_combo() -> void:
	combo = 0
	hud.show_combo(0, 0.0)


func _lose(reason: String) -> void:
	if game_over:
		return
	game_over = true
	_game_over_time = 0.0
	wipeouts += 1
	sounds.wipeout()
	dino.crash()
	camera.shake(crash_shake_px)
	_set_running(false)
	# Brief slow motion so the crash reads, timed in real seconds.
	Engine.time_scale = crash_slowmo_scale
	get_tree().create_timer(crash_slowmo_s, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)
	hud.set_wipeout(reason, score(), best)
	var save := ConfigFile.new()
	save.set_value("score", "best", best)
	save.save(SAVE_PATH)


func restart() -> void:
	game_over = false
	hud.show_wipeout(false)
	distance = 0.0
	water.tilt = 0.0
	bonus = 0.0
	_milestones = 0
	_end_combo()
	Engine.time_scale = 1.0
	water.reset()
	dino.reset()
	dino.speed = pace_start_speed
	water.speed = dino.speed
	camera.reset()
	controls.reset()
	obstacle_spawner.reset()
	gull_spawner.reset()
	_set_running(true)
	sounds.run_started()
	invert.set_inverted(false, true)
	hud.set_inverted(false)


## Freezes (or unfreezes) the input, the tsunami, spawning and every hazard, so the wipeout plays out on a still scene.
func _set_running(on: bool) -> void:
	for n in [controls, tsunami, obstacle_spawner, gull_spawner, hazards]:
		n.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
