class_name Controls
extends Node
## Turns the player's input into what the current control scheme does to the world. Tab switches scheme.
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
## Scheme A: hold Up / click to raise the water behind the dino, Down / S to lower it.
## Space (any scheme): bulge the water up just in front of the dino, a ramp to fly off.

enum Scheme { A_SHAPE_WAVE, B_TILT_WORLD, C_LEAP_SHIFT, D_SPIN_SLICE }

const SCHEME_NAMES := [
	"A: shape the wave (hold Up to raise, Down to lower)",
	"B: tilt the world (Right/Left: tip forward/back, Up/Down: raise/lower water)",
	"C: leap and shift (Down then Up: leap, Right/Left: tilt, in the air shift the ocean)",
	"D: spin slice (X/Shift: spin through a cactus, plus everything from C)",
]

@export var scheme: Scheme = Scheme.D_SPIN_SLICE
@export var water: Water
@export var dino: Dino

@export_group("Control A: shape the wave")
@export var push_offset: float = -30.0  # where to raise the water, relative to the dino
@export var push_radius: float = 50.0
@export var push_strength: float = 2500.0

@export_group("Control B: tilt the world")
@export var max_tilt_deg: float = 25.0
@export var wave_strength: float = 2500.0  # Up / Down: how hard the water behind the dino is pushed up / pulled down; uses push_offset and push_radius
@export var tilt_response: float = 5.5  # how quickly the tilt eases toward its target; it speeds up and slows down smoothly
@export var slosh_strength: float = 800.0  # how much the water rolls when you tilt; 0 turns it off

@export_group("Control C: leap and shift")
@export var leap_window: float = 0.35  # seconds after letting go of Down in which Up still leaps

@export_group("Bulge (Space)")
@export var bulge_offset: float = 50.0  # centre of the bulge, relative to the dino; + = in front
@export var bulge_radius: float = 45.0
@export var bulge_strength: float = 3000.0

var tilt := 0.0  # world tilt in radians, + = tipped down toward the direction of travel
var tilt_vel := 0.0
var _leap_window_left := 0.0  # > 0 while Down is held or was just let go: an Up press now leaps


func _enter_tree() -> void:
	_setup_input()


func reset() -> void:
	tilt = 0.0
	tilt_vel = 0.0
	_leap_window_left = 0.0


func next_scheme() -> void:
	scheme = ((scheme + 1) % Scheme.size()) as Scheme


func describe() -> String:
	return SCHEME_NAMES[scheme]


## Schemes C and D can leap, so any debris can be cleared without needing a flight off a crest.
func can_leap() -> bool:
	return scheme in [Scheme.C_LEAP_SHIFT, Scheme.D_SPIN_SLICE]


## True on the tick any game control is first pressed. Used to retry after a wipeout.
func any_just_pressed() -> bool:
	for action in ["surf", "tilt_back", "tilt_forward", "wave_down", "bulge", "spin"]:
		if Input.is_action_just_pressed(action):
			return true
	return false


## -1 = tilting back, 1 = tilting forward, 0 = level. Holding the mouse / a finger on one half of the screen counts too.
func tilt_input() -> float:
	var dir := Input.get_axis("tilt_back", "tilt_forward")
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var vp := get_viewport()
		dir = -1.0 if vp.get_mouse_position().x < vp.get_visible_rect().size.x / 2.0 else 1.0
	return dir


## One tick of the critically damped tilt spring: eases in and out with no overshoot, so the camera and water
## never jerk. Returns (new value, new velocity). FlightPlanner uses the same spring to look ahead.
static func spring_step(value: float, vel: float, target: float, response: float, dt: float) -> Vector2:
	vel += (response * response * (target - value) - 2.0 * response * vel) * dt
	return Vector2(value + vel * dt, vel)


func _physics_process(delta: float) -> void:
	if Input.is_action_pressed("bulge"):
		water.push(dino.position.x + bulge_offset, bulge_radius, bulge_strength, delta)
	match scheme:
		Scheme.A_SHAPE_WAVE:
			if Input.is_action_pressed("surf"):
				water.push(dino.position.x + push_offset, push_radius, push_strength, delta)
			elif Input.is_action_pressed("wave_down"):
				water.push(dino.position.x + push_offset, push_radius, -push_strength, delta)
		Scheme.B_TILT_WORLD, Scheme.C_LEAP_SHIFT, Scheme.D_SPIN_SLICE:
			_update_tilt(delta)
			if scheme == Scheme.B_TILT_WORLD:
				var wave := Input.get_axis("wave_down", "wave_up")
				if wave != 0.0:
					water.push(dino.position.x + push_offset, push_radius, wave_strength * wave, delta)
			else:
				_leap_input(delta)
	# Schemes C / D: in the air, Left / Right speed up / slow down the whole ocean (and the debris riding it).
	dino.air_input = tilt_input() if can_leap() else 0.0
	if scheme == Scheme.D_SPIN_SLICE and Input.is_action_just_pressed("spin"):
		dino.spin()
	dino.tilt = tilt


func _update_tilt(delta: float) -> void:
	var target := deg_to_rad(max_tilt_deg) * tilt_input()
	var prev_tilt := tilt
	var next := spring_step(tilt, tilt_vel, target, tilt_response, delta)
	tilt = next.x
	tilt_vel = next.y
	water.slosh(-slosh_strength * (tilt - prev_tilt))


## Down then Up leaps: holding Down crouches, and Up while crouched or within leap_window after letting go jumps.
func _leap_input(delta: float) -> void:
	dino.crouching = Input.is_action_pressed("wave_down")
	if dino.crouching:
		_leap_window_left = leap_window
	else:
		_leap_window_left = maxf(_leap_window_left - delta, 0.0)
	if Input.is_action_just_pressed("wave_up") and _leap_window_left > 0.0 and dino.leap():
		_leap_window_left = 0.0


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
