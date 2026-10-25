class_name RacketController
extends Node3D

enum SwingState {
	READY,
	WINDUP,
	ACTIVE,
	RECOVERY,
}

@export var windup_s: float = 0.16
@export var active_window_s: float = 0.1

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hit_area: Area3D = $AimPivot/SwingPivot/HitArea

var state: SwingState = SwingState.READY
var _last_swing_id: int = -1
var active_swing_id: int = -1

var active_swing_strength: float = 1.0
var active_aim: Vector2 = Vector2.ZERO

func _ready() -> void:
	hit_area.monitoring = false


func request_swing(
	swing_id: int,
	strength: float = 1.0,
	aim: Vector2 = Vector2.ZERO
) -> void:
	# Ignore duplicate/old events and requests while a swing is underway.
	if swing_id <= _last_swing_id:
		return
	if state != SwingState.READY:
		return

	_last_swing_id = swing_id
	active_swing_id = swing_id
	active_swing_strength = clampf(strength, 0.0, 1.0)
	active_aim = aim.clamp(Vector2(-1, -1), Vector2(1, 1))
	_run_swing()
	

func _run_swing() -> void:
	_set_state(SwingState.WINDUP)
	hit_area.monitoring = false
	animation_player.play("swing_forehand")

	await get_tree().create_timer(windup_s).timeout
	_set_state(SwingState.ACTIVE)
	hit_area.monitoring = true

	await get_tree().create_timer(active_window_s).timeout
	hit_area.monitoring = false
	_set_state(SwingState.RECOVERY)

	# swing_forehand must be non-looping and end at its neutral pose.
	await animation_player.animation_finished
	_set_state(SwingState.READY)


func _set_state(new_state: SwingState) -> void:
	state = new_state
	hit_area.monitoring = state == SwingState.ACTIVE
	print(
        "Racket: %s | HitArea monitoring: %s"
		% [SwingState.keys()[state], hit_area.monitoring]
	)
