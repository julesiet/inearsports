extends Node3D

# MatchState's CP-09 enum order is:
# WAITING=0, SERVING=1, RALLY=2, POINT_AWARDED=3, FINISHED=4.
const RALLY_PHASE := 2
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

@onready var racket1: Node = $Players/Player1/VisualRoot/RacketAnchor/Racket
@onready var contact1: Node = $Players/Player1/VisualRoot/RacketAnchor/Racket/AimPivot/SwingPivot/HitArea

@onready var racket2: Node = $Players/Player2/VisualRoot/RacketAnchor/Racket
@onready var contact2: Node = $Players/Player2/VisualRoot/RacketAnchor/Racket/AimPivot/SwingPivot/HitArea

func _ready() -> void:
	contact1.set("player_id", 1)
	contact2.set("player_id", 2)
	score_manager.match_ended.connect(_on_match_ended)


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
	var error := get_tree().change_scene_to_file(RESULTS_SCENE)
	if error != OK:
		get_tree().remove_meta("last_match_result")
		push_error("Could not open results screen: %s" % RESULTS_SCENE)

func _physics_process(_delta: float) -> void:
	if NetworkManager.is_online and not NetworkManager.is_host:
		return
	if int(match_state.get("phase")) != RALLY_PHASE:
		return

	var ball_previous: Vector3 = ball.get("previous_position")
	var ball_current: Vector3 = ball.global_position
	var ball_radius: float = float(ball.get("ball_radius"))

	# Return immediately after a hit so one physics tick can't accept two.
	if _check_contact(1, racket1, contact1, ball_previous, ball_current, ball_radius):
		apply_confirmed_shot(1, racket1)
		return

	if _check_contact(2, racket2, contact2, ball_previous, ball_current, ball_radius):
		apply_confirmed_shot(2, racket2)

func apply_confirmed_shot(player_id: int, racket: Node) -> void:
	var aim: Vector2 = racket.get("active_aim")
	var strength: float = float(racket.get("active_swing_strength"))
	var ball_radius := float(ball.get("ball_radius"))
	var gravity := float(ball.get("gravity"))
	var outgoing_velocity: Vector3 = ShotCalculator.calculate_velocity(
		ball.global_position,
		player_id,
		aim,
		strength,
		rules.court_half_width,
		rules.court_half_length,
		ball_radius,
		gravity
	)
	ball.call("set_velocity", outgoing_velocity)
	last_hitter_id = player_id
	current_hitter_id = 3 - player_id
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
		true, # Match is in RALLY because _physics_process checked it.
		player_id == current_hitter_id,
		int(racket.get("state")) == ACTIVE_RACKET_STATE,
		int(racket.get("active_swing_id"))
	))

func set_current_hitter(player_id: int) -> void:
	current_hitter_id = player_id
	last_hitter_id = 3 - player_id
	print("Next hitter: Player ", player_id)
