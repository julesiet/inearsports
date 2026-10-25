extends Node

const MAIN_MENU_MUSIC: AudioStreamMP3 = preload("res://assets/audio/MainMenuMusic.mp3")
const CROWD_CHEER: AudioStreamMP3 = preload("res://assets/audio/CrowdCheer.mp3")
const MUSIC_START_VOLUME_DB := -50.0
const MENU_VOLUME_DB := -8.0
const MATCH_VOLUME_DB := -18.0
const VOLUME_TRANSITION_SECONDS := 0.6
const MUSIC_FADE_IN_SECONDS := 2.0
const CHEER_FADE_IN_SECONDS := 0.35
const CHEER_FADE_OUT_SECONDS := 0.25
const CHEER_SILENT_VOLUME_DB := -50.0

var _music_player: AudioStreamPlayer
var _volume_tween: Tween
var _cheer_player: AudioStreamPlayer
var _cheer_tween: Tween
var _cheer_play_id := 0
var _initial_music_fade_pending := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MainMenuMusicPlayer"
	_music_player.stream = MAIN_MENU_MUSIC
	(_music_player.stream as AudioStreamMP3).loop = true
	_music_player.volume_db = MUSIC_START_VOLUME_DB
	add_child(_music_player)
	_cheer_player = AudioStreamPlayer.new()
	_cheer_player.name = "CrowdCheerAudioPlayer"
	_cheer_player.stream = CROWD_CHEER
	add_child(_cheer_player)
	get_tree().scene_changed.connect(_on_scene_changed)
	_music_player.play()
	_update_volume(get_tree().current_scene, MUSIC_FADE_IN_SECONDS)


func _on_scene_changed() -> void:
	var duration := MUSIC_FADE_IN_SECONDS if _initial_music_fade_pending else VOLUME_TRANSITION_SECONDS
	_update_volume(get_tree().current_scene, duration)


func _update_volume(scene: Node, duration: float = VOLUME_TRANSITION_SECONDS) -> void:
	var target_volume := MENU_VOLUME_DB
	if scene != null and scene.scene_file_path.ends_with("/tennis_match.tscn"):
		target_volume = MATCH_VOLUME_DB
	if _music_player == null:
		return
	if is_instance_valid(_volume_tween) and _volume_tween.is_running():
		_volume_tween.kill()
	_volume_tween = create_tween()
	_volume_tween.tween_property(
		_music_player, "volume_db", target_volume, duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _initial_music_fade_pending:
		_volume_tween.finished.connect(_on_initial_music_fade_finished)


func _on_initial_music_fade_finished() -> void:
	_initial_music_fade_pending = false


func play_crowd_cheer() -> void:
	if _cheer_player.playing:
		return
	_cheer_play_id += 1
	var play_id := _cheer_play_id
	if is_instance_valid(_cheer_tween) and _cheer_tween.is_running():
		_cheer_tween.kill()
	_cheer_player.stop()
	_cheer_player.volume_db = CHEER_SILENT_VOLUME_DB
	_cheer_player.play()
	_cheer_tween = create_tween()
	_cheer_tween.tween_property(
		_cheer_player, "volume_db", 0.0, CHEER_FADE_IN_SECONDS
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_fade_crowd_cheer_out(play_id)


func _fade_crowd_cheer_out(play_id: int) -> void:
	var fade_delay := maxf(_cheer_player.stream.get_length() - CHEER_FADE_OUT_SECONDS, 0.0)
	await get_tree().create_timer(fade_delay).timeout
	if play_id != _cheer_play_id or not is_inside_tree():
		return
	_cheer_tween = create_tween()
	_cheer_tween.tween_property(
		_cheer_player, "volume_db", CHEER_SILENT_VOLUME_DB, CHEER_FADE_OUT_SECONDS
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _cheer_tween.finished
	if play_id == _cheer_play_id:
		_cheer_player.stop()
