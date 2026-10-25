class_name KeyboardAdapter
extends Node

## Reads the CP-04 Input Map actions and returns a shared ControllerFrame.
## Call read_frame() from the owning controller's _physics_process().
@export var move_left_action: StringName = &"move_left"
@export var move_right_action: StringName = &"move_right"
@export var swing_action: StringName = &"swing"
@export var aim_left_action: StringName = &"aim_left"
@export var aim_right_action: StringName = &"aim_right"
@export var weak_swing_action: StringName = &"swing_weak"
@export var medium_swing_action: StringName = &"swing_medium"
@export var strong_swing_action: StringName = &"swing_strong"

var _next_swing_id: int = 0
var _sequence: int = 0


func read_frame() -> ControllerFrame:
	_sequence += 1
	var move_x := Input.get_axis(move_left_action, move_right_action)
	var aim_x := Input.get_axis(aim_left_action, aim_right_action)
	var swing_id := -1
	var swing_strength := 0.0

	# Aim is screen-relative; select a strength modifier while pressing swing.
	# Space without a modifier remains a full-strength neutral shot.
	if Input.is_action_just_pressed(swing_action):
		_next_swing_id += 1
		swing_id = _next_swing_id
		swing_strength = 1.0
		if Input.is_action_pressed(weak_swing_action):
			swing_strength = 0.35
		elif Input.is_action_pressed(medium_swing_action):
			swing_strength = 0.65
		elif Input.is_action_pressed(strong_swing_action):
			swing_strength = 1.0

	return ControllerFrame.new(
		move_x,
		Vector2(aim_x, 0.0),
		swing_id,
		swing_strength,
		_sequence,
		Time.get_ticks_msec(),
		true
	)
