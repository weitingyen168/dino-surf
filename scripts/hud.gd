class_name Hud
extends CanvasLayer
## The stats line in the corner and the WIPEOUT screen.

@onready var _stats: Label = $Stats
@onready var _wipeout: Label = $Wipeout


func show_stats(scheme_name: String, speed: float, distance: float, best: float, wipeouts: int, sliced: int) -> void:
	_stats.text = "Scheme %s   (Space: bulge ahead, Tab: switch, R: reset, V: 3D / flat)\nSpeed %d   Distance %d   Best %d   Wipeouts %d   Sliced %d" % [
		scheme_name, speed, distance, best, wipeouts, sliced]


func set_wipeout(reason: String, distance: float, best: float) -> void:
	_wipeout.text = "WIPEOUT\n%s\n\nDistance %d   Best %d\nPress any control to surf again" % [reason, distance, best]


func show_wipeout(on: bool) -> void:
	_wipeout.visible = on
