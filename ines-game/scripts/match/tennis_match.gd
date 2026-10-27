extends Node3D

# MatchState's CP-09 enum order is:
# WAITING=0, SERVING=1, RALLY=2, POINT_AWARDED=3, FINISHED=4.
const RALLY_PHASE := 2
const SERVING_PHASE := 1
const POINT_AWARDED_PHASE := 3
const FINISHED_PHASE := 4
const RESULTS_SCENE := "res://scenes/ui/results_screen.tscn"
const RESULTS_SCREEN_DELAY_SECONDS := 3.0

# RacketController's CP-07 enum order is:
# READY=0, WINDUP=1, ACTIVE=2, RECOVERY=3.
const ACTIVE_RACKET_STATE := 2

# Set this to the player who is allowed to hit next.
# After a Player 1 serve, that's usually Player 2.
@export_range(1, 2, 1) var current_hitter_id: int = 2
var last_hitter_id: int = 1

@export var rules: MatchRules

@onready var match_state: Node = $MatchSystems/MatchState
@onready var score_manager: Node = $MatchSystems/ScoreManager
@onready var ball: Node3D = $Ball
@onready var court_rules: Node = $MatchSystems/CourtRules
@onready var serve_manager: Node = $MatchSystems/ServeManager

@onready var racket1: Node = $Players/Player1/VisualRoot/RacketAnchor/Racket
@onready var contact1: Node = $Players/Player1/VisualRoot/RacketAnchor/Racket/AimPivot/SwingPivot/HitArea

@onready var racket2: Node = $Players/Player2/VisualRoot/RacketAnchor/Racket
@onready var contact2: Node = $Players/Player2/VisualRoot/RacketAnchor/Racket/AimPivot/SwingPivot/HitArea

func _ready() -> void:
	contact1.set("player_id", 1)
	contact2.set("player_id", 2)
	score_manager.match_ended.connect(_on_match_ended)
	match_state.phase_changed.connect(_on_match_phase_changed)


func _on_match_ended(winner_id: int) -> void:
	call_deferred("_open_results_screen", winner_id)


func _open_results_screen(winner_id: int) -> void:
	await get_tree().create_timer(RESULTS_SCREEN_DELAY_SECONDS).timeout
	if not is_inside_tree():
		return

	get_tree().set_meta("last_match_result", {
		"winner_id": winner_id,
		"player1_score": int(score_manager.get("player1_points")),
		"player2_score": int(score_manager.get("player2_points")),
	})
	var error := SceneTransitionManager.change_scene_to_file(RESULTS_SCENE)
	if error != OK:
		get_tree().remove_meta("last_match_result")
		push_error("Could not open results screen: %s" % RESULTS_SCENE)


func _on_match_phase_changed(phase: int) -> void:
	var player1: TennisPlayer = $Players/Player1
	var player2: TennisPlayer = $Players/Player2
	if phase == RALLY_PHASE:
		player1.set_movement_locked(false)
		player2.set_movement_locked(false)
		return
	if phase not in [SERVING_PHASE, POINT_AWARDED_PHASE, FINISHED_PHASE]:
		return

	var behind_baseline := rules.court_half_length + 1.0
	player1.set_movement_locked(true, Vector3(0.0, player1.global_position.y, behind_baseline))
	player2.set_movement_locked(true, Vector3(0.0, player2.global_position.y, -behind_baseline))

func _physics_process(_delta: float) -> void:
	_update_receiver_follow()
	if NetworkManager.is_online and not NetworkManager.is_host:
		return
	var ball_previous: Vector3 = ball.get("previous_position")
	var ball_current: Vector3 = ball.global_position
	var ball_radius: float = float(ball.get("ball_radius"))
	var phase := int(match_state.get("phase"))
	if phase == SERVING_PHASE:
		var server_id := current_hitter_id
		var server_racket: Node = racket1 if server_id == 1 else racket2
		var server_contact: Node = contact1 if server_id == 1 else contact2
		if _check_contact(
			server_id, server_racket, server_contact,
			ball_previous, ball_current, ball_radius
		):
			apply_confirmed_shot(server_id, server_racket)
		return
	if phase != RALLY_PHASE:
		return

	# Return immediately after a hit so one physics tick can't accept two.
	if _check_contact(1, racket1, contact1, ball_previous, ball_current, ball_radius):
		apply_confirmed_shot(1, racket1)
		return

	if _check_contact(2, racket2, contact2, ball_previous, ball_current, ball_radius):
		apply_confirmed_shot(2, racket2)


func _update_receiver_follow() -> void:
	var should_follow := (
		int(match_state.get("phase")) == RALLY_PHASE
		and bool(ball.get("active"))
		and (current_hitter_id == 1 or current_hitter_id == 2)
	)
	var ball_velocity: Vector3 = ball.get("velocity")

	for player_id in [1, 2]:
		var player: TennisPlayer = get_node("Players/Player%d" % player_id)
		if not should_follow or player_id != current_hitter_id:
			player.clear_ball_follow_target()
			continue

		var contact: Node3D = contact1 if player_id == 1 else contact2
		var ball_intercept := _predict_next_racket_height_crossing(
			contact.global_position.y,
			ball_velocity
		)
		var racket_offset := contact.global_position - player.global_position
		var follow_target := ball_intercept - Vector3(racket_offset.x, 0.0, racket_offset.z)
		var is_backpedaling: bool = (
			(player_id == 1 and follow_target.z > player.global_position.z)
			or (player_id == 2 and follow_target.z < player.global_position.z)
		)
		var bounced_once := int(court_rules.call("get_receiver_bounces")) == 1
		var speed_multiplier := 0.68 if SessionManager.cpu_opponent and player_id == 2 else 1.0
		if bounced_once and is_backpedaling:
			var recovery_speed := 0.78 if SessionManager.cpu_opponent and player_id == 2 else 1.35
			speed_multiplier = maxf(speed_multiplier, recovery_speed)
		player.set_ball_follow_target(follow_target, speed_multiplier)


func _predict_next_racket_height_crossing(
	target_y: float,
	ball_velocity: Vector3
) -> Vector3:
	var position := ball.global_position
	var gravity := float(ball.get("gravity"))
	var curve_acceleration := float(ball.get("curve_acceleration"))
	var ground_y := float(ball.get("ground_y")) + float(ball.get("ball_radius"))
	if gravity <= 0.0:
		return position

	var vertical_speed := ball_velocity.y
	var ground_discriminant := vertical_speed * vertical_speed + 2.0 * gravity * (position.y - ground_y)
	if ground_discriminant < 0.0:
		return position
	var time_to_ground := maxf(
		(vertical_speed + sqrt(ground_discriminant)) / gravity,
		0.0
	)

	var intercept_time := -1.0
	var height_discriminant := vertical_speed * vertical_speed + 2.0 * gravity * (position.y - target_y)
	if height_discriminant >= 0.0:
		var root := sqrt(height_discriminant)
		for candidate_time in [
			(vertical_speed - root) / gravity,
			(vertical_speed + root) / gravity,
		]:
			if candidate_time >= 0.0 and candidate_time <= time_to_ground:
				if intercept_time < 0.0 or candidate_time < intercept_time:
					intercept_time = candidate_time

	if intercept_time < 0.0:
		var bounce_speed := sqrt(ground_discriminant) * float(ball.get("bounce_factor"))
		var post_bounce_discriminant := (
			bounce_speed * bounce_speed
			- 2.0 * gravity * (target_y - ground_y)
		)
		if post_bounce_discriminant >= 0.0:
			intercept_time = time_to_ground + (
				bounce_speed - sqrt(post_bounce_discriminant)
			) / gravity
		else:
			return position + Vector3(
				ball_velocity.x * time_to_ground
					+ 0.5 * curve_acceleration * time_to_ground * time_to_ground,
				ground_y - position.y,
				ball_velocity.z * time_to_ground
			)

	return Vector3(
		position.x + ball_velocity.x * intercept_time
			+ 0.5 * curve_acceleration * intercept_time * intercept_time,
		target_y,
		position.z + ball_velocity.z * intercept_time
	)

func apply_confirmed_shot(player_id: int, racket: Node) -> void:
	$MatchSystems/MatchNetworkSync.call(
		"announce_ball_contact", int(match_state.get("phase")) == SERVING_PHASE
	)
	var aim: Vector2 = racket.get("active_aim")
	var strength: float = float(racket.get("active_swing_strength"))
	var swing_direction: Vector3 = racket.get("active_swing_direction")
	var timing_quality := float(racket.call("get_timing_quality"))
	var timing_error := 1.0 - timing_quality
	strength *= lerpf(0.55, 1.0, timing_quality)
	aim = (aim + Vector2(swing_direction.x, swing_direction.z) * timing_error * 0.2).clamp(
		Vector2(-1.0, -1.0),
		Vector2(1.0, 1.0)
	)
	var ball_radius := float(ball.get("ball_radius"))
	var gravity := float(ball.get("gravity"))
	var curve_sign := 1.0 if player_id == 1 else -1.0
	var curve_acceleration := clampf(
		swing_direction.x * strength * curve_sign * 2.5,
		-2.5,
		2.5
	)
	var outgoing_velocity: Vector3 = ShotCalculator.calculate_velocity(
		ball.global_position,
		player_id,
		aim,
		strength,
		rules.court_half_width,
		rules.court_half_length,
		ball_radius,
		gravity,
		4.5,
		swing_direction,
		curve_acceleration
	)
	ball.call("set_velocity", outgoing_velocity)
	ball.call("set_curve_acceleration", curve_acceleration)
	last_hitter_id = player_id
	current_hitter_id = 3 - player_id
	if int(match_state.get("phase")) == SERVING_PHASE:
		serve_manager.call("confirm_serve", player_id)
	else:
		court_rules.call("reset_bounces")
	print("Confirmed shot player=", player_id, " aim=", aim,
		" strength=", strength, " velocity=", outgoing_velocity)
	
func _check_contact(
	player_id: int,
	racket: Node,
	contact: Node,
	ball_previous: Vector3,
	ball_current: Vector3,
	ball_radius: float
) -> bool:
	return bool(contact.call(
		"try_contact",
		ball_previous,
		ball_current,
		ball_radius,
		int(match_state.get("phase")) in [SERVING_PHASE, RALLY_PHASE],
		player_id == current_hitter_id,
		int(racket.get("state")) == ACTIVE_RACKET_STATE,
		int(racket.get("active_swing_id"))
	))

func set_current_hitter(player_id: int) -> void:
	current_hitter_id = player_id
	last_hitter_id = 3 - player_id
	print("Next hitter: Player ", player_id)
