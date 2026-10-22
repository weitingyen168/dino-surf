class_name Sounds
extends Node
## Music and sound effects. Main tells it what's happening:
##   menu()         ocean waves loop on the start screen
##   run_started()  the surf theme starts from the top (and the waves stop)
##   wipeout()      the theme fades out and the wipeout sound plays
##   spin()         the dino's spin attack
##   milestone()    every 1000 points, like the Chrome Dino
## M mutes and unmutes everything.

@export var waves_db: float = -4.0
@export var music_db: float = -8.0
@export var wipeout_db: float = 0.0
@export var spin_db: float = 8.0  # the spin sound is mixed quietly, so it gets a boost
@export var milestone_db: float = 2.0
@export var music_fade_s: float = 0.4

var _waves := _player(preload("res://audio/music/ocean_waves_01.mp3"), true)
var _music := _player(preload("res://audio/music/surf_theme_01.mp3"), true)
var _wipeout := _player(preload("res://audio/sfx/wipeout_01.mp3"), false)
var _spin := _player(preload("res://audio/sfx/spin_01.mp3"), false)
var _milestone := _player(preload("res://audio/sfx/score_01.wav"), false)
var _fade: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # the start screen pauses the game, and its waves still play
	_waves.volume_db = waves_db
	_wipeout.volume_db = wipeout_db
	_spin.volume_db = spin_db
	_spin.max_polyphony = 4  # chained spins overlap instead of cutting each other off
	_milestone.volume_db = milestone_db
	for p in [_waves, _music, _wipeout, _spin, _milestone]:
		add_child(p)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))


func menu() -> void:
	if _fade:
		_fade.kill()
	_music.stop()  # straight away: on the start screen there's nothing to fade from
	if not _waves.playing:
		_waves.play()


func run_started() -> void:
	_waves.stop()
	if _fade:
		_fade.kill()
	_music.volume_db = music_db
	_music.play()


func wipeout() -> void:
	_stop_music()
	_wipeout.play()


func spin() -> void:
	_spin.play()


func milestone() -> void:
	_milestone.play()


func _stop_music() -> void:
	if not _music.playing:
		return
	if _fade:
		_fade.kill()
	_fade = create_tween().set_ignore_time_scale()  # the crash slow motion shouldn't stretch the fade
	_fade.tween_property(_music, "volume_db", -60.0, music_fade_s)
	_fade.tween_callback(_music.stop)


static func _player(stream: AudioStream, loop: bool) -> AudioStreamPlayer:
	if stream is AudioStreamMP3:
		stream.loop = loop
	var p := AudioStreamPlayer.new()
	p.stream = stream
	return p
