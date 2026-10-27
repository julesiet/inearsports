extends Node

const SERVING_PHASE := 1
const RALLY_PHASE := 2

@onready var match_root: Node3D = get_node("../..")
@onready var ball: Node3D = get_node("../../Ball")
@onready var match_state: Node = get_node("../MatchState")
@onready var human_player: TennisPlayer = get_node("../../Players/Player1")
@onready var racket: Node3D = get_node("../../Players/Player2/VisualRoot/RacketAnchor/Racket")
@onready var contact: Node3D = get_node(
	"../../Players/Player2/VisualRoot/RacketAnchor/Racket/AimPivot/SwingPivot/HitArea"
)

var _next_swing_id := 10000
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func _physics_process(_delta: float) -> void:
	if not SessionManager.cpu_opponent or NetworkManager.is_online:
		return
	if int(match_root.get("current_hitter_id")) != 2:
		return
	var phase := int(match_state.get("phase"))
	if phase not in [SERVING_PHASE, RALLY_PHASE]:
		return
	if int(racket.get("state")) != 0:
		return
	if phase == SERVING_PHASE:
		# The serve ball is intentionally stationary at the racket, so do not
		# rely on the rally's moving-ball distance trigger to start a CPU serve.
		_request_swing()
		return

	var distance := ball.global_position.distance_to(contact.global_position)
	var ball_velocity: Vector3 = ball.get("velocity")
	var to_contact := contact.global_position - ball.global_position
	var closing_speed := maxf(ball_velocity.dot(to_contact.normalized()), 0.0)
	var windup := float(racket.get("windup_s"))
	var active_window := float(racket.get("active_window_s"))
	var ball_radius := float(ball.get("ball_radius"))
	var hit_radius := float(contact.get("hit_radius"))
	var lead_time := maxf(windup + active_window * 0.5 - 0.04, 0.08)
	var swing_range := hit_radius + ball_radius + closing_speed * lead_time
	if distance > swing_range:
		return

	_request_swing()


func _request_swing() -> void:
	_next_swing_id += 1
	# Aim away from the human's current side, with slight shot variation.
	var aim_sign := signf(human_player.global_position.x)
	if absf(human_player.global_position.x) < 1.0:
		aim_sign = -1.0 if _rng.randf() < 0.5 else 1.0
	var aim_x := clampf(aim_sign * 0.4 + _rng.randf_range(-0.22, 0.22), -0.7, 0.7)
	var shot_aim := Vector2(aim_x, 0.0)
	racket.call("set_controller_offset", Vector3.ZERO)
	racket.call("request_swing", _next_swing_id, 0.58, shot_aim)
