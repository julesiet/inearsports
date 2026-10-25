extends Node

signal score_changed(player1_points: int, player2_points: int)
signal point_awarded(winner_id: int, reason: String)
signal match_ended(winner_id: int)

const POINT_AWARDED_PHASE := 3
const FINISHED_PHASE := 4

@export var rules: MatchRules

@onready var match_state: Node = $"../MatchState"

var player1_points := 0
var player2_points := 0
var winner_id := 0
var _seen_point_events: Dictionary = {}


func record_point(scoring_player_id: int, event_id: int, reason: String = "point") -> bool:
	if scoring_player_id != 1 and scoring_player_id != 2:
		return false
	if event_id < 0 or _seen_point_events.has(event_id):
		return false
	if int(match_state.get("phase")) != POINT_AWARDED_PHASE:
		return false

	_seen_point_events[event_id] = true
	if scoring_player_id == 1:
		player1_points += 1
	else:
		player2_points += 1

	print("Score: Player 1 ", player1_points, " - Player 2 ", player2_points,
		" (point to Player ", scoring_player_id, ")")
	score_changed.emit(player1_points, player2_points)
	point_awarded.emit(scoring_player_id, reason)

	if winner_id == 0 and _points_for(scoring_player_id) >= rules.points_to_win:
		winner_id = scoring_player_id
		if bool(match_state.call("transition_to", FINISHED_PHASE)):
			print("Match finished. Winner: Player ", winner_id)
			match_ended.emit(winner_id)
		return true

	return true


func reset() -> void:
	player1_points = 0
	player2_points = 0
	winner_id = 0
	_seen_point_events.clear()
	score_changed.emit(player1_points, player2_points)


func _points_for(player_id: int) -> int:
	return player1_points if player_id == 1 else player2_points
