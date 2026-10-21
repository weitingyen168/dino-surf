extends Node2D
## Runs a surf session: keeps score (the distance surfed; the best is saved between sessions), ends the run on a
## wipeout and restarts it. R resets.
## Everything else is its own node; tree order is tick order, so the input and spawning run before the water moves:
##   Controls         player input -> world tilt, water pushes, leap, spin (the control schemes live here)
##   Tsunami          the always-on hump behind the dino
##   ObstacleSpawner  plants cacti the player can clear, reports slices and hits
##   GullSpawner      sends in seagulls, reports knocks and hits
##   Background       pixel art behind everything (the furthest card in 3D)
##   Water            the ocean surface
##   Hazards          holds the spawned cacti and gulls, drawn behind the dino
##   Dino             the surfer
##   Camera2D         follow, lean and shake
##   View3D           redraws all of the above as a 3D pop-up book (V: flat 2D view)
##   HUD              score, the WIPEOUT screen, and the start screen (HUD/Title) that holds the game paused

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

var distance := 0.0
var best := 0.0
var wipeouts := 0
var sliced := 0
var game_over := false
var _game_over_time := 0.0


const SAVE_PATH := "user://dino_surf.cfg"  # on the web this lives in the browser's storage


func _ready() -> void:
	get_tree().physics_interpolation = true
	var save := ConfigFile.new()
	if save.load(SAVE_PATH) == OK:
		best = save.get_value("score", "best", 0.0)
	obstacle_spawner.dino_hit.connect(_lose)
	obstacle_spawner.cactus_sliced.connect(_on_cactus_sliced)
	gull_spawner.dino_hit.connect(_lose)
	gull_spawner.gull_knocked.connect(func(): camera.shake(hit_shake_px))
	restart()


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
	water.speed = dino.speed
	distance += water.speed * delta / 10.0
	best = maxf(best, distance)


func _process(_delta: float) -> void:
	hud.show_score(distance, best)


func _on_cactus_sliced() -> void:
	sliced += 1
	camera.shake(hit_shake_px)


func _lose(reason: String) -> void:
	if game_over:
		return
	game_over = true
	_game_over_time = 0.0
	wipeouts += 1
	dino.crash()
	camera.shake(crash_shake_px)
	_set_running(false)
	# Brief slow motion so the crash reads, timed in real seconds.
	Engine.time_scale = crash_slowmo_scale
	get_tree().create_timer(crash_slowmo_s, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)
	hud.set_wipeout(reason, distance, best)
	var save := ConfigFile.new()
	save.set_value("score", "best", best)
	save.save(SAVE_PATH)


func restart() -> void:
	game_over = false
	hud.show_wipeout(false)
	distance = 0.0
	Engine.time_scale = 1.0
	water.reset()
	dino.reset()
	water.speed = dino.speed
	camera.reset()
	controls.reset()
	obstacle_spawner.reset()
	gull_spawner.reset()
	_set_running(true)


## Freezes (or unfreezes) the input, the tsunami, spawning and every hazard, so the wipeout plays out on a still scene.
func _set_running(on: bool) -> void:
	for n in [controls, tsunami, obstacle_spawner, gull_spawner, hazards]:
		n.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
