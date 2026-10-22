class_name Controls
extends Node
## Turns the player's input into what the dino does.
## Up (or a click / tap) spins the board: a cactus caught by the spin (Dino.slash_rect) is sliced in half, a gull is
## killed, and you surf on. Mistime it and you hit them as usual. One spin per jump, given back by every kill, so
## you can chain them. Down crouches (and fast-falls in the air); Down then Up (within leap_window) leaps, with a
## free takeoff spin. Space bulges the water up just in front of the dino, a ramp to fly off.

@export var water: Water
@export var dino: Dino

@export_group("Leap and spin")
@export var leap_window: float = 0.35  # seconds after letting go of Down in which Up still leaps
@export var spin_buffer: float = 0.25  # an Up press while the spin isn't ready yet still spins if it's ready this soon

@export_group("Bulge (Space)")
@export var bulge_offset: float = 50.0  # centre of the bulge, relative to the dino; + = in front
@export var bulge_radius: float = 45.0
@export var bulge_strength: float = 3000.0

var _leap_window_left := 0.0  # > 0 while Down is held or was just let go: an Up press now leaps
var _spin_buffer_left := 0.0  # > 0 after an Up press that couldn't spin yet: keep trying


func _enter_tree() -> void:
	_setup_input()


func reset() -> void:
	_leap_window_left = 0.0
	_spin_buffer_left = 0.0


## True on the tick any game control is first pressed. Used to retry after a wipeout.
func any_just_pressed() -> bool:
	for action in ["up", "down", "bulge"]:
		if Input.is_action_just_pressed(action):
			return true
	return false


func _physics_process(delta: float) -> void:
	if Input.is_action_pressed("bulge"):
		water.push(dino.position.x + bulge_offset, bulge_radius, bulge_strength, delta)
	_spin_input(_leap_input(delta), delta)


## Up spins. A Down-then-Up leap comes with a free takeoff spin (the leap is the lift), so Up again in the air still
## has the jump's own spin. A press while the spin isn't ready (mid-spin, cooling down) is kept for spin_buffer
## seconds and spins as soon as it can, so a press is never just lost.
func _spin_input(leaped: bool, delta: float) -> void:
	if Input.is_action_just_pressed("up"):
		if leaped:
			dino.spin(true)
		elif not dino.spin():
			_spin_buffer_left = spin_buffer
	elif _spin_buffer_left > 0.0:
		_spin_buffer_left = 0.0 if dino.spin() else _spin_buffer_left - delta


## Down then Up leaps: holding Down crouches, and Up while crouched or within leap_window after letting go jumps.
## Returns true on the tick it leaps.
func _leap_input(delta: float) -> bool:
	dino.crouching = Input.is_action_pressed("down")
	if dino.crouching:
		_leap_window_left = leap_window
	else:
		_leap_window_left = maxf(_leap_window_left - delta, 0.0)
	if Input.is_action_just_pressed("up") and _leap_window_left > 0.0 and dino.leap():
		_leap_window_left = 0.0
		return true
	return false


func _setup_input() -> void:
	var keys := {
		"up": [KEY_UP, KEY_W],
		"down": [KEY_DOWN, KEY_S],
		"bulge": [KEY_SPACE],
	}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for keycode in keys[action]:
			var key := InputEventKey.new()
			key.physical_keycode = keycode
			InputMap.action_add_event(action, key)
		if action == "up":
			var tap := InputEventMouseButton.new()
			tap.button_index = MOUSE_BUTTON_LEFT  # touch arrives as mouse via emulate_mouse_from_touch
			InputMap.action_add_event(action, tap)
