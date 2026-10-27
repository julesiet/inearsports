class_name RacketController
extends Node3D

signal swing_window_finished(swing_id: int, is_backhand: bool)

enum SwingState {
	READY,
	WINDUP,
	ACTIVE,
	RECOVERY,
}

@export var windup_s: float = 0.16
@export var active_window_s: float = 0.20
@export var racket_reach: Vector3 = Vector3(0.4, 0.36, 0.35)

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var aim_pivot: Node3D = $AimPivot
@onready var hit_area: Area3D = $AimPivot/SwingPivot/HitArea

var state: SwingState = SwingState.READY
var _last_swing_id: int = -1
var active_swing_id: int = -1

var active_swing_strength: float = 1.0
var active_aim: Vector2 = Vector2.ZERO
var active_swing_is_backhand := false
var controller_offset := Vector3.ZERO
var active_swing_direction := Vector3.ZERO
var _last_controller_motion := Vector3.ZERO
var _last_controller_motion_msec := -1
var _active_window_started_msec := -1

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
	active_swing_direction = (
		_last_controller_motion
		if (
			_last_controller_motion.length_squared() > 0.0001
			and Time.get_ticks_msec() - _last_controller_motion_msec <= 600
		)
		else Vector3.ZERO
	)
	_last_controller_motion = Vector3.ZERO
	_last_controller_motion_msec = -1
	active_swing_is_backhand = active_swing_direction.x < -0.1
	if absf(active_swing_direction.x) <= 0.1:
		active_swing_is_backhand = active_aim.x < -0.2
	_run_swing()
	


func set_controller_offset(offset: Vector3) -> void:
	var bounded_offset := Vector3(
		clampf(offset.x, -racket_reach.x, racket_reach.x),
		clampf(offset.y, -racket_reach.y, racket_reach.y),
		clampf(offset.z, -racket_reach.z, racket_reach.z)
	)
	var movement := bounded_offset - controller_offset
	if movement.length_squared() > 0.0001:
		_last_controller_motion = movement.normalized()
		_last_controller_motion_msec = Time.get_ticks_msec()
	controller_offset = bounded_offset
	aim_pivot.position = controller_offset


func _run_swing() -> void:
	_set_state(SwingState.WINDUP)
	hit_area.monitoring = false
	animation_player.play("swing_forehand")

	await get_tree().create_timer(windup_s).timeout
	_set_state(SwingState.ACTIVE)
	_active_window_started_msec = Time.get_ticks_msec()
	hit_area.monitoring = true

	await get_tree().create_timer(active_window_s).timeout
	hit_area.monitoring = false
	_set_state(SwingState.RECOVERY)
	swing_window_finished.emit(active_swing_id, active_swing_is_backhand)

	# swing_forehand must be non-looping and end at its neutral pose.
	await animation_player.animation_finished
	_set_state(SwingState.READY)
	_active_window_started_msec = -1


func get_timing_quality() -> float:
	if state != SwingState.ACTIVE or _active_window_started_msec < 0:
		return 0.0
	var window_progress := clampf(
		float(Time.get_ticks_msec() - _active_window_started_msec)
			/ (active_window_s * 1000.0),
		0.0,
		1.0
	)
	return 1.0 - absf(window_progress - 0.5) * 2.0


func _set_state(new_state: SwingState) -> void:
	state = new_state
	hit_area.monitoring = state == SwingState.ACTIVE
	print(
        "Racket: %s | HitArea monitoring: %s"
		% [SwingState.keys()[state], hit_area.monitoring]
	)
