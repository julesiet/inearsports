extends Area3D

signal hit_confirmed(player_id: int, swing_id: int, contact_position: Vector3)

@export var player_id: int = 1
@export var hit_radius: float = 0.7

var _previous_hit_position: Vector3
var _last_consumed_swing_id: int = -1


func _ready() -> void:
	_previous_hit_position = global_position


func try_contact(
	ball_previous: Vector3,
	ball_current: Vector3,
	ball_radius: float,
	is_rally: bool,
	is_player_turn: bool,
	racket_active: bool,
	swing_id: int
) -> bool:
	var hit_now := global_position
	var relative_start := ball_previous - _previous_hit_position
	var relative_end := ball_current - hit_now
	_previous_hit_position = hit_now

	if not is_rally or not is_player_turn or not racket_active:
		return false
	if swing_id < 0 or swing_id <= _last_consumed_swing_id:
		return false

	var segment := relative_end - relative_start
	var t := 0.0
	if segment.length_squared() > 0.000001:
		t = clampf(-relative_start.dot(segment) / segment.length_squared(), 0.0, 1.0)

	var closest := relative_start + segment * t
	var combined_radius := ball_radius + hit_radius
	if closest.length_squared() > combined_radius * combined_radius:
		return false

	_last_consumed_swing_id = swing_id
	var contact_position := ball_previous.lerp(ball_current, t)
	hit_confirmed.emit(player_id, swing_id, contact_position)
	print("BALL_HIT player=", player_id, " swing=", swing_id,
		" at=", contact_position)
	return true
