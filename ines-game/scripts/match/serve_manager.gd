extends Node

const SERVING := 1
const RALLY := 2
const POINT_AWARDED := 3

@export var rules: MatchRules

@onready var match_state: Node = $"../MatchState"
@onready var score_manager: Node = $"../ScoreManager"
@onready var ball: Node3D = get_node("../../Ball")
@onready var match_root: Node = get_node("../..")

var next_server_is_player1 := true
var _next_point_event_id := 1


func start_match() -> void:
	if int(score_manager.get("winner_id")) != 0:
		return
	if bool(match_state.call("transition_to", SERVING)):
		launch_serve()


func launch_serve() -> void:
	if int(match_state.get("phase")) != SERVING:
		print("Serve ignored: match is not in SERVING phase.")
		return
	if int(score_manager.get("winner_id")) != 0:
		print("Serve ignored: match is finished.")
		return

	var server_id := 1 if next_server_is_player1 else 2
	var racket_path := (
		"Players/Player%d/VisualRoot/RacketAnchor/Racket/AimPivot/SwingPivot/HitArea"
		% server_id
	)
	var contact: Node3D = match_root.get_node(racket_path)
	var serve_direction_z := -1.0 if server_id == 1 else 1.0
	var serve_position := contact.global_position + Vector3(0.0, 0.05, serve_direction_z * 0.22)
	ball.call("stop")
	ball.global_position = serve_position
	ball.set("previous_position", serve_position)
	ball.set("curve_acceleration", 0.0)
	match_root.call("set_current_hitter", server_id)
	get_parent().get_node("CourtRules").call("reset_bounces")
	print("Player ", server_id, " is ready to serve.")


func confirm_serve(server_id: int) -> void:
	if int(match_state.get("phase")) != SERVING:
		return
	if server_id != (1 if next_server_is_player1 else 2):
		return
	match_root.call("set_current_hitter", 3 - server_id)
	if bool(match_state.call("transition_to", RALLY)):
		next_server_is_player1 = not next_server_is_player1


func award_point(winner_id: int, reason: String = "fault") -> void:
	if winner_id != 1 and winner_id != 2:
		return
	if int(match_state.get("phase")) != RALLY:
		return
	if not bool(match_state.call("transition_to", POINT_AWARDED)):
		return

	ball.call("stop")
	var event_id := _next_point_event_id
	_next_point_event_id += 1
	print("Awarding point to Player ", winner_id, ": ", reason)
	if not bool(score_manager.call("record_point", winner_id, event_id, reason)):
		print("Point event rejected: ", event_id)
		return

	# ScoreManager transitions to FINISHED when the target is reached.
	if int(match_state.get("phase")) != POINT_AWARDED:
		return

	await get_tree().create_timer(rules.point_reset_delay_s).timeout
	if int(match_state.get("phase")) != POINT_AWARDED:
		return
	if bool(match_state.call("transition_to", SERVING)):
		launch_serve()
