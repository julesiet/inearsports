extends Node

const BALL_CONTACT_SOUND: AudioStreamMP3 = preload("res://assets/audio/Serving1.mp3")
const RACKET_HIT_SOUNDS: Array[AudioStreamMP3] = [
	preload("res://assets/audio/RacketHit1.mp3"),
	preload("res://assets/audio/RacketHit2.mp3"),
	preload("res://assets/audio/RacketHit3.mp3"),
	preload("res://assets/audio/RacketHit4.mp3"),
]
const BALL_GROUND_SOUNDS: Array[AudioStreamMP3] = [
	preload("res://assets/audio/BallGround1.mp3"),
	preload("res://assets/audio/BallGround2.mp3"),
	preload("res://assets/audio/BallGround3.mp3"),
]
const RACKET_SWING_SOUNDS: Array[AudioStreamMP3] = [
	preload("res://assets/audio/RacketSwing1.mp3"),
	preload("res://assets/audio/RacketSwing2.mp3"),
]
const BACKHAND_SWING_SOUND: AudioStreamMP3 = preload("res://assets/audio/BackhandSwing.mp3")
const SNAPSHOT_INTERVAL := 1.0 / 20.0
const FINISHED_PHASE := 4

@onready var match_root: Node3D = get_node("../..")
@onready var ball: Node3D = get_node("../../Ball")
@onready var player1: Node3D = get_node("../../Players/Player1")
@onready var player2: Node3D = get_node("../../Players/Player2")
@onready var match_state: Node = get_node("../MatchState")
@onready var score_manager: Node = get_node("../ScoreManager")
@onready var racket1: Node = get_node("../../Players/Player1/VisualRoot/RacketAnchor/Racket")
@onready var racket2: Node = get_node("../../Players/Player2/VisualRoot/RacketAnchor/Racket")

var _snapshot_elapsed := 0.0
var _remote_state_sequence := 0
var _last_remote_swing_id := -1
var _last_client_swing_id := -1
var _last_received_swing_ids := {1: -1, 2: -1}
var _ball_contact_player: AudioStreamPlayer
var _ball_ground_player: AudioStreamPlayer
var _racket_swing_player: AudioStreamPlayer
var _audio_rng := RandomNumberGenerator.new()
var _next_swing_sound_index := 0
var _confirmed_swing_ids: Dictionary = {}


func _ready() -> void:
	_ball_contact_player = AudioStreamPlayer.new()
	_ball_contact_player.name = "BallContactAudioPlayer"
	_ball_contact_player.stream = BALL_CONTACT_SOUND
	add_child(_ball_contact_player)
	_ball_ground_player = AudioStreamPlayer.new()
	_ball_ground_player.name = "BallGroundAudioPlayer"
	add_child(_ball_ground_player)
	_racket_swing_player = AudioStreamPlayer.new()
	_racket_swing_player.name = "RacketSwingAudioPlayer"
	add_child(_racket_swing_player)
	_audio_rng.randomize()
	ball.connect("ground_bounced", _on_ball_ground_bounced)
	racket1.connect("swing_window_finished", _on_swing_window_finished.bind(1))
	racket2.connect("swing_window_finished", _on_swing_window_finished.bind(2))
	match_root.get_node("Players/Player1/VisualRoot/RacketAnchor/Racket/AimPivot/SwingPivot/HitArea") \
		.connect("hit_confirmed", _on_racket_hit_confirmed)
	match_root.get_node("Players/Player2/VisualRoot/RacketAnchor/Racket/AimPivot/SwingPivot/HitArea") \
		.connect("hit_confirmed", _on_racket_hit_confirmed)
	if NetworkManager.is_online and not NetworkManager.is_host:
		ball.set_physics_process(false)


func announce_ball_contact(is_serve: bool) -> void:
	var sound_index := -1
	if not is_serve:
		sound_index = _audio_rng.randi_range(0, RACKET_HIT_SOUNDS.size() - 1)
	if NetworkManager.is_online and NetworkManager.is_host:
		broadcast_ball_contact_sound.rpc(is_serve, sound_index)
	else:
		_play_ball_contact_sound(is_serve, sound_index)


func broadcast_point_awarded(winner_id: int, reason: String) -> void:
	if NetworkManager.is_online and NetworkManager.is_host:
		receive_point_awarded.rpc(winner_id, reason)


@rpc("authority", "call_remote", "reliable")
func receive_point_awarded(winner_id: int, reason: String) -> void:
	score_manager.point_awarded.emit(winner_id, reason)


@rpc("authority", "call_local", "reliable")
func broadcast_ball_contact_sound(is_serve: bool, sound_index: int) -> void:
	_play_ball_contact_sound(is_serve, sound_index)


func _play_ball_contact_sound(is_serve: bool, sound_index: int) -> void:
	if is_serve:
		_ball_contact_player.stream = BALL_CONTACT_SOUND
	else:
		if sound_index < 0 or sound_index >= RACKET_HIT_SOUNDS.size():
			return
		_ball_contact_player.stream = RACKET_HIT_SOUNDS[sound_index]
	_ball_contact_player.play()


func _on_ball_ground_bounced(_at_position: Vector3) -> void:
	var sound_index := _audio_rng.randi_range(0, BALL_GROUND_SOUNDS.size() - 1)
	if NetworkManager.is_online and NetworkManager.is_host:
		broadcast_ball_ground_sound.rpc(sound_index)
	else:
		_play_ball_ground_sound(sound_index)


@rpc("authority", "call_local", "reliable")
func broadcast_ball_ground_sound(sound_index: int) -> void:
	_play_ball_ground_sound(sound_index)


func _play_ball_ground_sound(sound_index: int) -> void:
	if sound_index < 0 or sound_index >= BALL_GROUND_SOUNDS.size():
		return
	_ball_ground_player.stream = BALL_GROUND_SOUNDS[sound_index]
	_ball_ground_player.play()


func _on_racket_hit_confirmed(player_id: int, swing_id: int, _contact_position: Vector3) -> void:
	_confirmed_swing_ids["%d:%d" % [player_id, swing_id]] = true


func _on_swing_window_finished(swing_id: int, is_backhand: bool, player_id: int) -> void:
	if NetworkManager.is_online and not NetworkManager.is_host:
		return
	var swing_key := "%d:%d" % [player_id, swing_id]
	if _confirmed_swing_ids.has(swing_key):
		_confirmed_swing_ids.erase(swing_key)
		return

	var sound_index := -1
	if not is_backhand:
		sound_index = _next_swing_sound_index
		_next_swing_sound_index = (_next_swing_sound_index + 1) % RACKET_SWING_SOUNDS.size()
	if NetworkManager.is_online and NetworkManager.is_host:
		broadcast_racket_swing_sound.rpc(is_backhand, sound_index)
	else:
		_play_racket_swing_sound(is_backhand, sound_index)


@rpc("authority", "call_local", "reliable")
func broadcast_racket_swing_sound(is_backhand: bool, sound_index: int) -> void:
	_play_racket_swing_sound(is_backhand, sound_index)


func _play_racket_swing_sound(is_backhand: bool, sound_index: int) -> void:
	if is_backhand:
		_racket_swing_player.stream = BACKHAND_SWING_SOUND
	else:
		if sound_index < 0 or sound_index >= RACKET_SWING_SOUNDS.size():
			return
		_racket_swing_player.stream = RACKET_SWING_SOUNDS[sound_index]
	_racket_swing_player.play()


func _physics_process(delta: float) -> void:
	if not NetworkManager.is_online or not NetworkManager.is_host:
		return

	_snapshot_elapsed += delta
	if _snapshot_elapsed < SNAPSHOT_INTERVAL:
		return
	_snapshot_elapsed = 0.0
	receive_match_snapshot.rpc(_make_snapshot())


func apply_controller_frame(player_id: int, frame: ControllerFrame) -> void:
	if int(match_state.get("phase")) == FINISHED_PHASE:
		return
	if player_id != 1 and player_id != 2:
		return
	var player: Node = player1 if player_id == 1 else player2
	player.call("set_controller_frame", frame)
	var racket: Node = racket1 if player_id == 1 else racket2
	racket.call("set_controller_offset", frame.racket_offset)
	if frame.swing_id < 0:
		return
	racket.call("request_swing", frame.swing_id, frame.swing_strength, frame.aim)


func send_controller_frame(frame: ControllerFrame) -> void:
	if (
		not is_inside_tree()
		or not NetworkManager.is_online
		or NetworkManager.is_host
		or int(match_state.get("phase")) == FINISHED_PHASE
	):
		return
	submit_controller_state.rpc_id(
		1, frame.move_x, frame.aim.x,
		frame.racket_offset.x, frame.racket_offset.y, frame.racket_offset.z
	)
	if frame.swing_id >= 0:
		submit_swing_event.rpc_id(
			1, frame.swing_id, frame.swing_strength, frame.aim.x,
			frame.racket_offset.x, frame.racket_offset.y, frame.racket_offset.z
		)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func submit_controller_state(
	move_x: float,
	aim_x: float,
	racket_x: float,
	racket_y: float,
	racket_z: float
) -> void:
	if not is_inside_tree() or multiplayer == null or not NetworkManager.is_host:
		return
	if int(match_state.get("phase")) == FINISHED_PHASE:
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if SessionManager.player_id_for_peer(sender_id) != 2:
		return
	if (
		not is_finite(move_x) or not is_finite(aim_x)
		or not is_finite(racket_x) or not is_finite(racket_y) or not is_finite(racket_z)
	):
		return

	_remote_state_sequence += 1
	var frame := ControllerFrame.new(
		clampf(move_x, -1.0, 1.0),
		Vector2(clampf(aim_x, -1.0, 1.0), 0.0),
		-1,
		0.0,
		_remote_state_sequence,
		Time.get_ticks_msec(),
		true,
		Vector3(racket_x, racket_y, racket_z)
	)
	apply_controller_frame(2, frame)


@rpc("any_peer", "call_remote", "reliable")
func submit_swing_event(
	swing_id: int,
	strength: float,
	aim_x: float,
	racket_x: float,
	racket_y: float,
	racket_z: float
) -> void:
	if not is_inside_tree() or multiplayer == null or not NetworkManager.is_host:
		return
	if int(match_state.get("phase")) == FINISHED_PHASE:
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if SessionManager.player_id_for_peer(sender_id) != 2:
		return
	if swing_id < 0 or swing_id <= _last_remote_swing_id:
		return
	if (
		not is_finite(strength) or not is_finite(aim_x)
		or not is_finite(racket_x) or not is_finite(racket_y) or not is_finite(racket_z)
	):
		return

	_last_remote_swing_id = swing_id
	var frame := ControllerFrame.new(
		0.0,
		Vector2(clampf(aim_x, -1.0, 1.0), 0.0),
		swing_id,
		clampf(strength, 0.0, 1.0),
		_remote_state_sequence,
		Time.get_ticks_msec(),
		true,
		Vector3(racket_x, racket_y, racket_z)
	)
	apply_controller_frame(2, frame)


@rpc("authority", "call_remote", "unreliable_ordered")
func receive_match_snapshot(snapshot: Dictionary) -> void:
	if not NetworkManager.is_online or NetworkManager.is_host:
		return

	ball.global_position = snapshot["ball_position"]
	ball.set("velocity", snapshot["ball_velocity"])
	ball.set("active", snapshot["ball_active"])
	player1.global_position = snapshot["player1_position"]
	player2.global_position = snapshot["player2_position"]
	racket1.call("set_controller_offset", snapshot["racket1_offset"])
	racket2.call("set_controller_offset", snapshot["racket2_offset"])
	match_root.set("current_hitter_id", int(snapshot["current_hitter_id"]))
	match_root.set("last_hitter_id", int(snapshot["last_hitter_id"]))
	ball.set("curve_acceleration", float(snapshot["ball_curve_acceleration"]))

	_sync_racket(1, int(snapshot["racket1_swing_id"]), float(snapshot["racket1_strength"]), snapshot["racket1_aim"])
	_sync_racket(2, int(snapshot["racket2_swing_id"]), float(snapshot["racket2_strength"]), snapshot["racket2_aim"])
	_sync_score_and_phase(snapshot)


func _make_snapshot() -> Dictionary:
	return {
		"ball_position": ball.global_position,
		"ball_velocity": ball.get("velocity"),
		"ball_curve_acceleration": ball.get("curve_acceleration"),
		"ball_active": ball.get("active"),
		"player1_position": player1.global_position,
		"player2_position": player2.global_position,
		"current_hitter_id": match_root.get("current_hitter_id"),
		"last_hitter_id": match_root.get("last_hitter_id"),
		"phase": match_state.get("phase"),
		"player1_score": score_manager.get("player1_points"),
		"player2_score": score_manager.get("player2_points"),
		"winner_id": score_manager.get("winner_id"),
		"racket1_swing_id": racket1.get("active_swing_id"),
		"racket1_strength": racket1.get("active_swing_strength"),
		"racket1_aim": racket1.get("active_aim"),
		"racket1_offset": racket1.get("controller_offset"),
		"racket2_swing_id": racket2.get("active_swing_id"),
		"racket2_strength": racket2.get("active_swing_strength"),
		"racket2_aim": racket2.get("active_aim"),
		"racket2_offset": racket2.get("controller_offset"),
	}


func _sync_racket(player_id: int, swing_id: int, strength: float, aim: Vector2) -> void:
	if swing_id < 0 or swing_id <= int(_last_received_swing_ids[player_id]):
		return
	_last_received_swing_ids[player_id] = swing_id
	var racket: Node = racket1 if player_id == 1 else racket2
	racket.call("request_swing", swing_id, strength, aim)


func _sync_score_and_phase(snapshot: Dictionary) -> void:
	var old_player1_score := int(score_manager.get("player1_points"))
	var old_player2_score := int(score_manager.get("player2_points"))
	var new_player1_score := int(snapshot["player1_score"])
	var new_player2_score := int(snapshot["player2_score"])
	score_manager.set("player1_points", new_player1_score)
	score_manager.set("player2_points", new_player2_score)
	if old_player1_score != new_player1_score or old_player2_score != new_player2_score:
		score_manager.score_changed.emit(new_player1_score, new_player2_score)

	var previous_phase := int(match_state.get("phase"))
	var new_phase := int(snapshot["phase"])
	match_state.set("phase", new_phase)
	if previous_phase != new_phase:
		match_state.phase_changed.emit(new_phase)

	var winner_id := int(snapshot["winner_id"])
	var previous_winner_id := int(score_manager.get("winner_id"))
	if winner_id > 0 and previous_winner_id == 0:
		score_manager.set("winner_id", winner_id)
		score_manager.match_ended.emit(winner_id)
