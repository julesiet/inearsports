extends Control

signal rematch_requested
signal return_to_lobby_requested

@onready var winner_label: Label = $CenterContainer/ResultsContent/WinnerLabel
@onready var final_score_label: Label = $CenterContainer/ResultsContent/FinalScoreLabel
@onready var rematch_button: Button = $CenterContainer/ResultsContent/RematchButton
@onready var return_to_lobby_button: Button = $CenterContainer/ResultsContent/ReturnToLobbyButton

var _winner_id := 0
var _player1_score := 0
var _player2_score := 0
var _has_result := false


func _ready() -> void:
	rematch_button.pressed.connect(_on_rematch_pressed)
	return_to_lobby_button.pressed.connect(_on_return_to_lobby_pressed)
	rematch_button.grab_focus()
	_read_match_result_handoff()
	_refresh_result_labels()


## Displays the authoritative result supplied by the match/session flow.
## This screen presents the result; it does not determine or award points.
func set_result(winner_id: int, player1_score: int, player2_score: int) -> void:
	if winner_id != 1 and winner_id != 2:
		push_warning("ResultsScreen received an invalid winner id.")
		return
	if player1_score < 0 or player2_score < 0:
		push_warning("ResultsScreen received a negative score.")
		return

	_winner_id = winner_id
	_player1_score = player1_score
	_player2_score = player2_score
	_has_result = true
	if is_node_ready():
		_refresh_result_labels()


func _read_match_result_handoff() -> void:
	var tree := get_tree()
	if not tree.has_meta("last_match_result"):
		return

	var result: Variant = tree.get_meta("last_match_result")
	tree.remove_meta("last_match_result")
	if not result is Dictionary:
		return

	set_result(
		int(result.get("winner_id", 0)),
		int(result.get("player1_score", -1)),
		int(result.get("player2_score", -1))
	)


func _refresh_result_labels() -> void:
	if not _has_result:
		winner_label.text = "WINNER: —"
		final_score_label.text = "FINAL SCORE: —"
		return

	winner_label.text = "PLAYER %d WINS" % _winner_id
	final_score_label.text = "PLAYER 1   %d   —   %d   PLAYER 2" % [
		_player1_score,
		_player2_score,
	]


func _on_rematch_pressed() -> void:
	rematch_requested.emit()
	SessionManager.request_rematch()


func _on_return_to_lobby_pressed() -> void:
	return_to_lobby_requested.emit()
	SessionManager.return_to_lobby()
