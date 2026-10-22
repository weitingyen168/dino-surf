class_name LoreSlideshow
extends Control
## The story so far, as a slideshow over the start screen: the artist's lore slides, a caption under each.
## Right / Space / Enter / click: next (past the last slide it closes). Left / right-click: back. Esc: close.

signal closed

## [slide, caption]. The slides come from the artist's LORE folder via tools/prepare_art.gd.
const SLIDES := [
	[preload("res://art/ui/lore_01.png"), "Defeated by a cactus. Again."],
	[preload("res://art/ui/lore_02.png"), "Then, half buried in the sand... a handheld?"],
	[preload("res://art/ui/lore_03.png"), "It grew. And grew."],
	[preload("res://art/ui/lore_04.png"), "That night a storm hit, the handheld burst, and the desert flooded. Surf's up."],
]

var _i := 0
var _image := TextureRect.new()
var _caption := Label.new()
var _count := Label.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # the game behind is paused
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(black)

	_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # painted slides, not pixel art
	add_child(_image)

	# Caption on a dark strip along the bottom, easy to read over any slide.
	var strip := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.7)
	style.set_content_margin_all(8)
	strip.add_theme_stylebox_override("panel", style)
	strip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	strip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.add_theme_font_size_override("font_size", 16)
	_caption.add_theme_color_override("font_color", Color.WHITE)
	strip.add_child(_caption)
	add_child(strip)

	_count.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_count.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_count.position += Vector2(-8, 6)
	_count.add_theme_font_size_override("font_size", 8)
	_count.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	_count.add_theme_color_override("font_outline_color", Color.BLACK)
	_count.add_theme_constant_override("outline_size", 4)
	add_child(_count)

	for child in get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE  # clicks come to _input
	_show(0)


func _show(i: int) -> void:
	_i = i
	_image.texture = SLIDES[i][0]
	_caption.text = SLIDES[i][1]
	_count.text = "%d / %d    Left/Right  Esc" % [i + 1, SLIDES.size()]


func _input(event: InputEvent) -> void:
	# While open it takes every input, so nothing reaches the start screen behind it.
	get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_RIGHT, KEY_D, KEY_SPACE, KEY_ENTER:
				_step(1)
			KEY_LEFT, KEY_A:
				_step(-1)
			KEY_ESCAPE, KEY_L:
				_close()
	elif event is InputEventMouseButton and event.pressed:
		_step(-1 if event.button_index == MOUSE_BUTTON_RIGHT else 1)
	elif event is InputEventScreenTouch and event.pressed:
		_step(1)


func _step(by: int) -> void:
	if _i + by >= SLIDES.size():
		_close()
	else:
		_show(maxi(_i + by, 0))


func _close() -> void:
	closed.emit()
	queue_free()
