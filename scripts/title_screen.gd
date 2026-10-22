class_name TitleScreen
extends Control
## Start screen: the animated handheld (the artist's Animation.GIF, as a strip) with the title on its dark lower
## screen, over the paused game. Any key, click or tap starts the run; the Story button (or L) opens the lore
## slideshow instead. Launch with `-- --skip-title` to skip it.

signal started  # the player pressed a key to surf

const STRIP := preload("res://art/ui/title_handheld_01.png")
const KEY_UP := preload("res://art/ui/key_up_01.png")
const KEY_DOWN := preload("res://art/ui/key_down_01.png")
const KEY_LEFT := preload("res://art/ui/key_left_01.png")
const KEY_RIGHT := preload("res://art/ui/key_right_01.png")
const HINT := Color("8a8a8a")
const FRAME := Vector2(50, 50)  # one frame of the strip, in art px
const FRAME_S := 0.1  # seconds per frame, as in the GIF
const PANEL := Rect2(3, 23, 44, 15)  # the handheld's dark lower screen, in art px: the title goes here

@export var art_scale: float = 7.0  # screen px per art px
@export var blink_s: float = 0.5  # the "press any key" line blinks on and off this often

var _handheld := TextureRect.new()
var _atlas := AtlasTexture.new()
var _prompt := Label.new()
var _lore: LoreSlideshow  # open while valid
# Browsers keep a page silent until the player clicks or presses a key, so on the web the first press only
# turns the sound on (the menu waves are already playing, just muted); the next one starts the run.
var _awake := not OS.has_feature("web")
var _t := 0.0
var _frames := 0


func _ready() -> void:
	if "--skip-title" in OS.get_cmdline_user_args():  # straight into a run, for testing: godot --path . -- --skip-title
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS  # it runs while the game behind it is paused
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # clicks that miss the Story button start the run (_unhandled_input)

	var dim := ColorRect.new()
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	# The handheld stands on the bottom edge of the screen, centred, as if you're holding it.
	_atlas.atlas = STRIP
	_atlas.region = Rect2(Vector2.ZERO, FRAME)
	_handheld.texture = _atlas
	_handheld.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_handheld.stretch_mode = TextureRect.STRETCH_SCALE
	_handheld.size = FRAME * art_scale
	_handheld.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_handheld)

	var title := _label("DINO SURF", 32, Color.WHITE)
	_prompt = _label("Press any key to surf" if _awake else "Click to turn on sound", 8, Color("c8c8c8"))
	var spin_keys := _key_row([KEY_UP, "spin: cuts cacti & seagulls"])
	var other_keys := _key_row([KEY_DOWN, KEY_UP, "leap + spin", "  ", KEY_DOWN, "fall", "  ", KEY_LEFT, KEY_RIGHT, "lean"])
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 0)  # four lines on a small screen
	column.add_child(title)
	column.add_child(_prompt)
	column.add_child(spin_keys)
	column.add_child(other_keys)
	column.add_child(_story_button())
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_handheld.add_child(column)
	column.position = PANEL.position * art_scale
	column.size = PANEL.size * art_scale

	resized.connect(_layout)
	_layout()


## A small framed button on the handheld's screen that opens the lore slideshow.
func _story_button() -> Button:
	var button := Button.new()
	button.text = "Story (L)"
	button.focus_mode = Control.FOCUS_NONE  # keys start the run; only a click or L opens the story
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 8)
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("333333") if state == "normal" else Color("555555")
		style.border_color = Color("c8c8c8")
		style.set_border_width_all(1)
		style.set_content_margin_all(3)
		style.content_margin_left = 8
		style.content_margin_right = 8
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(_open_lore)
	return button


func _open_lore() -> void:
	_lore = LoreSlideshow.new()
	add_child(_lore)


## A centred row of key icons (textures) and words (strings), for the controls.
func _key_row(parts: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for part in parts:
		if part is Texture2D:
			var key := TextureRect.new()
			key.texture = part
			key.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			key.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			key.custom_minimum_size = Vector2(11, 11)
			key.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			key.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(key)
		else:
			row.add_child(_label(part, 8, HINT))
	return row


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _layout() -> void:
	_handheld.position = Vector2((size.x - _handheld.size.x) / 2.0, size.y - _handheld.size.y)


func _process(delta: float) -> void:
	_frames += 1
	if _frames == 3:
		get_tree().paused = true  # after the game has drawn itself once, so there's a scene behind the title
	_t += delta
	var frame := int(_t / FRAME_S) % int(STRIP.get_width() / FRAME.x)
	_atlas.region = Rect2(Vector2(frame * FRAME.x, 0.0), FRAME)
	_prompt.visible = fmod(_t, blink_s * 2.0) < blink_s


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_lore):
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_L:
		get_viewport().set_input_as_handled()
		_open_lore()
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if pressed and not _awake:
		get_viewport().set_input_as_handled()
		_awake = true
		_prompt.text = "Press any key to surf"
	elif pressed:
		get_viewport().set_input_as_handled()
		get_tree().paused = false
		started.emit()
		queue_free()
