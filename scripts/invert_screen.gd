class_name InvertScreen
extends CanvasLayer
## Chrome Dino style colour flip: Main calls toggle() at every 1000 points, so the picture inverts at 1000, flips
## back at 2000, and so on, with a quick fade. It sits above the game and below the HUD, so the score stays as is.

@export var fade_s: float = 0.6

var inverted := false
var _rect := ColorRect.new()
var _material := ShaderMaterial.new()
var _fade: Tween


func _ready() -> void:
	layer = 1  # the HUD is on layer 2, above this
	_material.shader = preload("res://shaders/invert_screen.gdshader")
	_rect.material = _material
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_set_amount(0.0)


func toggle() -> void:
	set_inverted(not inverted)


## Fades to inverted or back; `instant` skips the fade (a new run starts the right way round).
func set_inverted(on: bool, instant: bool = false) -> void:
	inverted = on
	if _fade:
		_fade.kill()
	if instant:
		_set_amount(1.0 if on else 0.0)
		return
	_fade = create_tween()
	_fade.tween_method(_set_amount, _material.get_shader_parameter("amount"), 1.0 if on else 0.0, fade_s)


func _set_amount(amount: float) -> void:
	_material.set_shader_parameter("amount", amount)
	_rect.visible = amount > 0.0  # nothing to draw (or pay for) while it's the right way round
