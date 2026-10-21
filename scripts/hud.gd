class_name Hud
extends CanvasLayer
## The score in the top right (Chrome Dino style: best, then this run) and the WIPEOUT screen.

@onready var _score: Label = $Score
@onready var _wipeout: Label = $Wipeout


func show_score(score: float, best: float) -> void:
	_score.text = "HI %05d  %05d" % [best, score]


func set_wipeout(reason: String, score: float, best: float) -> void:
	var record := "  NEW BEST!" if score >= best and score > 0.0 else ""
	_wipeout.text = "WIPEOUT
%s

Score %d   Best %d%s
Press any control to surf again" % [reason, score, best, record]


func show_wipeout(on: bool) -> void:
	_wipeout.visible = on
