extends CanvasLayer

const PHASE_LABELS := ["WAITING", "SERVING", "RALLY", "POINT", "FINISHED"]

@onready var player1_score: Label = $HUDRoot/Scoreboard/ScoreRow/Player1Group/Player1Row/Player1ScoreBox/Player1Score
@onready var rally_status: Label = $HUDRoot/Scoreboard/RallyStatus
@onready var player2_score: Label = $HUDRoot/Scoreboard/ScoreRow/Player2Group/Player2Row/Player2ScoreBox/Player2Score
@onready var player1_serve_arrow: Label = $HUDRoot/Scoreboard/ScoreRow/Player1Group/Player1ServeArrow
@onready var player2_serve_arrow: Label = $HUDRoot/Scoreboard/ScoreRow/Player2Group/Player2ServeArrow
@onready var controller_status: Label = $HUDRoot/ControllerStatus
@onready var message_banner: PanelContainer = $HUDRoot/MessageBanner
@onready var centered_message: Label = $HUDRoot/MessageBanner/CenteredMessage
@onready var cheer_hands: TextureRect = $HUDRoot/CheerHands
@onready var shader_debug_panel: PanelContainer = $HUDRoot/ShaderDebugPanel
@onready var shader_preset_selector: OptionButton = $HUDRoot/ShaderDebugPanel/ShaderDebugContent/ShaderPresetSelector

var _last_player1_points := 0
var _last_player2_points := 0
var _last_point_reason := ""
var _message_tween: Tween
var _serve_prompt_token := 0
var _celebration_token := 0


func _ready() -> void:
	var match_root := get_parent()
	shader_debug_panel.visible = SessionManager.hud_debug_mode
	if SessionManager.hud_debug_mode:
		shader_preset_selector.clear()
		shader_preset_selector.add_item("ORIGINAL MATCH")
		shader_preset_selector.add_item("CEL SHADING")
		shader_preset_selector.add_item("CEL + RIM LIGHT")
		shader_preset_selector.add_item("HALFTONE CEL")
		shader_preset_selector.select(0)
		shader_preset_selector.item_selected.connect(_on_shader_preset_selected)
	var score_manager: Node = match_root.get_node("MatchSystems/ScoreManager")
	var match_state: Node = match_root.get_node("MatchSystems/MatchState")

	score_manager.connect("score_changed", _on_score_changed)
	score_manager.connect("point_awarded", _on_point_awarded)
	score_manager.connect("match_ended", _on_match_ended)
	match_state.connect("phase_changed", _on_phase_changed)
	_set_centered_message("")
	controller_status.text = "KEYBOARD CONTROLS ACTIVE"
	_on_score_changed(
		int(score_manager.get("player1_points")),
		int(score_manager.get("player2_points"))
	)
	_on_phase_changed(int(match_state.get("phase")))


func _on_shader_preset_selected(preset_index: int) -> void:
	get_parent().get_node("MatchSystems/MatchShaderDebug").call("set_preset", preset_index)


func _on_score_changed(player1_points: int, player2_points: int) -> void:
	player1_score.text = "%d" % player1_points
	player2_score.text = "%d" % player2_points
	if player1_points > _last_player1_points:
		_set_centered_message("POINT — PLAYER 1")
	elif player2_points > _last_player2_points:
		_set_centered_message("POINT — PLAYER 2")
	_last_player1_points = player1_points
	_last_player2_points = player2_points


func _on_phase_changed(phase: int) -> void:
	_serve_prompt_token += 1
	_hide_serve_arrows()
	if phase < 0 or phase >= PHASE_LABELS.size():
		rally_status.text = "UNKNOWN"
		return

	rally_status.text = PHASE_LABELS[phase]
	if phase == 0:
		_set_centered_message("READY")
	elif phase == 1:
		_set_centered_message("SERVE")
		_show_serve_arrow_after_delay(_serve_prompt_token)
	elif phase == 2:
		_set_centered_message("")
	elif phase == 4:
		# The winner message arrives from ScoreManager.match_ended.
		_set_centered_message("MATCH OVER")


func _on_match_ended(winner_id: int) -> void:
	var ending_reason := _last_point_reason.to_upper()
	var message := "PLAYER %d WINS" % winner_id
	if not ending_reason.is_empty():
		message += "\n" + ending_reason
	_set_centered_message(message)


func _on_point_awarded(winner_id: int, reason: String) -> void:
	_last_point_reason = reason
	var score_manager: Node = get_parent().get_node("MatchSystems/ScoreManager")
	var result_label := "WINS" if int(score_manager.get("winner_id")) == winner_id else "SCORES"
	_set_centered_message("PLAYER %d %s\n%s" % [winner_id, result_label, reason.to_upper()])
	_play_point_celebration()


func _show_serve_arrow_after_delay(token: int) -> void:
	await get_tree().create_timer(2.0).timeout
	if not is_inside_tree() or token != _serve_prompt_token:
		return
	var match_state: Node = get_parent().get_node("MatchSystems/MatchState")
	if int(match_state.get("phase")) != 1:
		return
	_set_centered_message("")
	var serving_player_id := int(get_parent().get("current_hitter_id"))
	player1_serve_arrow.visible = serving_player_id == 1
	player2_serve_arrow.visible = serving_player_id == 2


func _hide_serve_arrows() -> void:
	player1_serve_arrow.visible = false
	player2_serve_arrow.visible = false


func _play_point_celebration() -> void:
	_celebration_token += 1
	var token := _celebration_token
	MusicManager.play_crowd_cheer()
	cheer_hands.visible = true
	cheer_hands.modulate.a = 0.0
	var fade_in := create_tween()
	fade_in.tween_property(cheer_hands, "modulate:a", 0.88, 0.2)
	await get_tree().create_timer(2.0).timeout
	if not is_inside_tree() or token != _celebration_token:
		return
	var fade_out := create_tween()
	fade_out.tween_property(cheer_hands, "modulate:a", 0.0, 0.35)
	await fade_out.finished
	if is_inside_tree() and token == _celebration_token:
		cheer_hands.visible = false


func _set_centered_message(message: String) -> void:
	centered_message.text = message
	if message.is_empty():
		message_banner.visible = false
		return

	message_banner.visible = true
	if is_instance_valid(_message_tween) and _message_tween.is_running():
		_message_tween.kill()
	message_banner.modulate.a = 0.0
	message_banner.scale = Vector2(0.98, 0.98)
	message_banner.pivot_offset = message_banner.size * 0.5
	_message_tween = create_tween().set_parallel()
	_message_tween.tween_property(message_banner, "modulate:a", 1.0, 0.18)
	_message_tween.tween_property(message_banner, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
