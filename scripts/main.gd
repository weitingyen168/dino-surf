extends Node2D
## Prototype harness for comparing control schemes.
## Hold Space / Up / left mouse / touch to act. Tab switches scheme, R resets.

enum Scheme { A_SHAPE_WAVE, B_TILT_WORLD }

@export var scheme: Scheme = Scheme.A_SHAPE_WAVE

@export_group("Control A: shape the wave")
@export var push_offset: float = -30.0  # where to raise the water, relative to the dino
@export var push_radius: float = 50.0
@export var push_strength: float = 2500.0

@export_group("Control B: tilt the world")
@export var max_tilt_deg: float = 25.0
@export var tilt_speed: float = 3.0
@export var camera_tilt_fraction: float = 0.4  # how much of the tilt the camera shows

@onready var water: Water = $Water
@onready var dino: Dino = $Dino
@onready var camera: Camera2D = $Camera2D
@onready var label: Label = $HUD/Label

var tilt := 0.0
var distance := 0.0
var best := 0.0
var wipeouts := 0


func _ready() -> void:
	_setup_input()
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
	var held := Input.is_action_pressed("surf")
	match scheme:
		Scheme.A_SHAPE_WAVE:
			if held:
				water.push(dino.position.x + push_offset, push_radius, push_strength, delta)
		Scheme.B_TILT_WORLD:
			var target := deg_to_rad(max_tilt_deg) if held else 0.0
			tilt = move_toward(tilt, target, tilt_speed * delta)
	# Positive tilt pulls gravity forward (to the right); the camera leans so the world looks tipped.
	dino.gravity_dir = Vector2.DOWN.rotated(-tilt)
	camera.rotation = -tilt * camera_tilt_fraction

	distance += water.swell_speed * delta / 10.0
	best = maxf(best, distance)


func _process(_delta: float) -> void:
	var names := ["A: shape the wave", "B: tilt the world"]
	label.text = "Scheme %s   (Tab: switch, R: reset)\nHold Space / click\nDistance %d   Best %d   Wipeouts %d" % [
		names[scheme], distance, best, wipeouts]


func _on_wiped_out() -> void:
	wipeouts += 1
	_restart()


func _restart() -> void:
	distance = 0.0
	tilt = 0.0
	water.reset()
	dino.reset()
