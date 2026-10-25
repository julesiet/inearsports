extends Node

const SERVING := 1
const RALLY := 2
const POINT_AWARDED := 3

@export var rules: MatchRules

@export var player1_start := Vector3(0, 1.2, 8)
@export var player1_velocity := Vector3(0, 6, -8)

@export var player2_start := Vector3(0, 1.2, -8)
@export var player2_velocity := Vector3(0, 6, 8)

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

	var start_position: Vector3
	var start_velocity: Vector3
	if next_server_is_player1:
		start_position = player1_start
		start_velocity = player1_velocity
	else:
		start_position = player2_start
		start_velocity = player2_velocity

	ball.call("launch", start_position, start_velocity)
	var server_id := 1 if next_server_is_player1 else 2
	var receiver_id := 3 - server_id
	match_root.call("set_current_hitter", receiver_id)
	get_parent().get_node("CourtRules").call("reset_bounces")
	print("Serve launched by Player ", server_id,
		" toward Player ", receiver_id,
		". Ball instance ID: ", ball.get_instance_id())

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
