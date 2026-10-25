extends Node

const RALLY_PHASE := 2

@export var rules: MatchRules

@onready var ball: BallSimulator = get_node("../../Ball")
@onready var match_root: Node = get_node("../..")
@onready var match_state: Node = $"../MatchState"
@onready var serve_manager: Node = $"../ServeManager"

var _receiver_bounces := 0


func _ready() -> void:
	ball.ground_bounced.connect(_on_ground_bounced)
	ball.net_hit.connect(_on_net_hit)


func reset_bounces() -> void:
	_receiver_bounces = 0


func _on_net_hit(at_position: Vector3) -> void:
	if int(match_state.get("phase")) != RALLY_PHASE:
		return

	var last_hitter_id := int(match_root.get("last_hitter_id"))
	var receiver_id := 3 - last_hitter_id
	print("Net fault at ", at_position, "; last_hitter=", last_hitter_id,
		" receiver=", receiver_id)
	_request_point(receiver_id, "net fault")


func _on_ground_bounced(at_position: Vector3) -> void:
	if int(match_state.get("phase")) != RALLY_PHASE:
		return

	var last_hitter_id := int(match_root.get("last_hitter_id"))
	var receiver_id := int(match_root.get("current_hitter_id"))
	var radius := float(ball.get("ball_radius"))
	var in_bounds := (
		absf(at_position.x) <= rules.court_half_width + radius
		and absf(at_position.z) <= rules.court_half_length + radius
	)

	if not in_bounds:
		print("Out ball at ", at_position, "; last_hitter=", last_hitter_id,
			" receiver=", receiver_id)
		_request_point(3 - last_hitter_id, "out ball")
		return

	var receiver_side_sign := 1.0 if receiver_id == 1 else -1.0
	if at_position.z * receiver_side_sign < 0.0:
		print("Short/wrong-side bounce at ", at_position,
			"; last_hitter=", last_hitter_id, " receiver=", receiver_id)
		_request_point(receiver_id, "wrong-side bounce")
		return

	_receiver_bounces += 1
	print("Receiver-side bounce ", _receiver_bounces, " at ", at_position,
		"; last_hitter=", last_hitter_id, " receiver=", receiver_id)
	if _receiver_bounces > rules.max_bounces:
		_request_point(last_hitter_id, "second bounce")


func _request_point(winner_id: int, reason: String) -> void:
	serve_manager.call("award_point", winner_id, reason)
