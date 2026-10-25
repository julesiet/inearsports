extends CanvasLayer

const PHASE_LABELS := ["WAITING", "SERVING", "RALLY", "POINT", "FINISHED"]

@onready var player1_score: Label = $HUDRoot/TopBar/Player1Score
@onready var rally_status: Label = $HUDRoot/TopBar/RallyStatus
@onready var player2_score: Label = $HUDRoot/TopBar/Player2Score
@onready var controller_status: Label = $HUDRoot/ControllerStatus
@onready var centered_message: Label = $HUDRoot/CenteredMessage

var _last_player1_points := 0
var _last_player2_points := 0
var _last_point_reason := ""


func _ready() -> void:
	var match_root := get_parent()
	var score_manager: Node = match_root.get_node("MatchSystems/ScoreManager")
	var match_state: Node = match_root.get_node("MatchSystems/MatchState")

	score_manager.connect("score_changed", _on_score_changed)
	score_manager.connect("point_awarded", _on_point_awarded)
	score_manager.connect("match_ended", _on_match_ended)
	match_state.connect("phase_changed", _on_phase_changed)

	centered_message.text = ""
	controller_status.text = "KEYBOARD CONTROLS ACTIVE"
	_on_score_changed(
		int(score_manager.get("player1_points")),
		int(score_manager.get("player2_points"))
	)
	_on_phase_changed(int(match_state.get("phase")))

	player1_score.add_theme_font_size_override("font_size", 24)
	rally_status.add_theme_font_size_override("font_size", 18)
	player2_score.add_theme_font_size_override("font_size", 24)
	controller_status.add_theme_font_size_override("font_size", 14)
	centered_message.add_theme_font_size_override("font_size", 28)

	for label in [player1_score, rally_status, player2_score, controller_status, centered_message]:
		label.add_theme_color_override("font_color", Color(0.91, 0.95, 1.0))

	centered_message.add_theme_color_override("font_color", Color(0.45, 0.95, 0.78))


func _on_score_changed(player1_points: int, player2_points: int) -> void:
	player1_score.text = "PLAYER 1   %d" % player1_points
	player2_score.text = "PLAYER 2   %d" % player2_points
	if player1_points > _last_player1_points:
		centered_message.text = "POINT — PLAYER 1"
	elif player2_points > _last_player2_points:
		centered_message.text = "POINT — PLAYER 2"
	_last_player1_points = player1_points
	_last_player2_points = player2_points


func _on_phase_changed(phase: int) -> void:
	if phase < 0 or phase >= PHASE_LABELS.size():
		rally_status.text = "UNKNOWN"
		return

	rally_status.text = PHASE_LABELS[phase]
	if phase == 0:
		centered_message.text = "READY"
	elif phase == 1:
		centered_message.text = "SERVE"
	elif phase == 2:
		centered_message.text = ""
	elif phase == 4:
		# The winner message arrives from ScoreManager.match_ended.
		centered_message.text = "MATCH OVER"


func _on_match_ended(winner_id: int) -> void:
	var ending_reason := _last_point_reason.to_upper()
	centered_message.text = "PLAYER %d WINS" % winner_id
	if not ending_reason.is_empty():
		centered_message.text += "\n" + ending_reason


func _on_point_awarded(winner_id: int, reason: String) -> void:
	_last_point_reason = reason
	centered_message.text = "PLAYER %d SCORES\n%s" % [winner_id, reason.to_upper()]
