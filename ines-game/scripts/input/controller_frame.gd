class_name ControllerFrame
extends RefCounted

## A snapshot of the input requested for one update.
## swing_id is -1 when this frame contains no new swing event.
var move_x: float = 0.0
var aim: Vector2 = Vector2.ZERO
var swing_id: int = -1
var swing_strength: float = 0.0
var sequence: int = 0
var time_msec: int = 0
var valid: bool = true


func _init(
	move_x_value: float = 0.0,
	aim_value: Vector2 = Vector2.ZERO,
	swing_id_value: int = -1,
	swing_strength_value: float = 0.0,
	sequence_value: int = 0,
	time_msec_value: int = 0,
	valid_value: bool = true
) -> void:
	move_x = clampf(move_x_value, -1.0, 1.0)
	aim = aim_value
	swing_id = swing_id_value
	swing_strength = clampf(swing_strength_value, 0.0, 1.0)
	sequence = sequence_value
	time_msec = time_msec_value
	valid = valid_value
