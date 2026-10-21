class_name TitleScreen
extends Control
## Start screen: the animated handheld (the artist's Animation.GIF, as a strip) with the title on its dark lower
## screen, over the paused game. Any key, click or tap starts the run. Launch with `-- --skip-title` to skip it.

const STRIP := preload("res://art/ui/title_handheld_01.png")
const FRAME := Vector2(50, 50)  # one frame of the strip, in art px
const FRAME_S := 0.1  # seconds per frame, as in the GIF
const PANEL := Rect2(3, 23, 44, 15)  # the handheld's dark lower screen, in art px: the title goes here

@export var art_scale: float = 7.0  # screen px per art px
@export var blink_s: float = 0.5  # the "press any key" line blinks on and off this often

var _handheld := TextureRect.new()
var _atlas := AtlasTexture.new()
var _prompt := Label.new()
var _t := 0.0
var _frames := 0


func _ready() -> void:
	if "--skip-title" in OS.get_cmdline_user_args():  # straight into a run, for testing: godot --path . -- --skip-title
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS  # it runs while the game behind it is paused
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
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
	add_child(_handheld)

	var title := _label("DINO SURF", 32, Color.WHITE)
	_prompt = _label("Press any key to surf", 8, Color("c8c8c8"))
	var keys := _label("Left/Right tilt   Down+Up leap   X spin", 8, Color("8a8a8a"))
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(title)
	column.add_child(_prompt)
	column.add_child(keys)
	_handheld.add_child(column)
	column.position = PANEL.position * art_scale
	column.size = PANEL.size * art_scale

	resized.connect(_layout)
	_layout()


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


func _input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		get_viewport().set_input_as_handled()
		get_tree().paused = false
		queue_free()
