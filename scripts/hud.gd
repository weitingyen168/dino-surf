class_name Hud
extends CanvasLayer
## The score in the top right (Chrome Dino style: best, then this run), the combo under it, and the WIPEOUT screen.

@onready var _score: Label = $Score
@onready var _combo: Label = $Combo
@onready var _big_combo: Label = $BigCombo

var _pop: Tween
@onready var _wipeout: Label = $Wipeout


## Light text while the colours are flipped (InvertScreen), dark otherwise, so the score always reads.
func set_inverted(on: bool) -> void:
	for label in [_score, _combo]:
		label.add_theme_color_override("font_color", Color("d8d8d8") if on else Color("535353"))


func show_score(score: float, best: float) -> void:
	_score.text = "HI %05d  %05d" % [best, score]


## "+25" for a single kill, "x3 COMBO  +75" for a chain; combo 0 hides it. From 3 in a row a big gold
## "COMBO x3!" pops up at the top too, pulsing on each kill.
func show_combo(combo: int, points: float) -> void:
	_combo.visible = combo > 0
	_combo.text = ("x%d COMBO  +%d" % [combo, points]) if combo > 1 else "+%d" % points
	_big_combo.visible = combo >= 3
	if combo >= 3:
		_big_combo.text = "COMBO x%d!" % combo
		_big_combo.pivot_offset = _big_combo.size / 2.0
		if _pop:
			_pop.kill()
		_pop = create_tween().set_ignore_time_scale()
		_big_combo.scale = Vector2.ONE * 1.6
		_pop.tween_property(_big_combo, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func set_wipeout(reason: String, score: float, best: float) -> void:
	var record := "  NEW BEST!" if score >= best and score > 0.0 else ""
	_wipeout.text = "WIPEOUT
%s

Score %d   Best %d%s
Press any control to surf again" % [reason, score, best, record]


func show_wipeout(on: bool) -> void:
	_wipeout.visible = on
