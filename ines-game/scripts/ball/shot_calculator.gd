class_name ShotCalculator
extends RefCounted


static func calculate_velocity(
	start_position: Vector3,
	player_id: int,
	aim: Vector2,
	strength: float,
	court_half_width: float,
	court_half_length: float,
	ball_radius: float,
	gravity: float,
	aim_limit: float = 3.0
) -> Vector3:
	strength = clampf(strength, 0.0, 1.0)
	aim = aim.clamp(Vector2(-1, -1), Vector2(1, 1))

	# Player 1 is on +Z and shoots toward -Z; Player 2 is opposite.
	var toward_z := -1.0 if player_id == 1 else 1.0
	var screen_right_world_sign := 1.0 if player_id == 1 else -1.0

	var target_x := start_position.x + aim.x * aim_limit * screen_right_world_sign
	target_x = clampf(
		target_x,
		-court_half_width + ball_radius,
		court_half_width - ball_radius
	)

	var target_z := toward_z * court_half_length * 0.45
	var target_y := ball_radius
	var flight_time := lerpf(1.35, 1.10, strength)

	var displacement := Vector3(
		target_x - start_position.x,
		target_y - start_position.y,
		target_z - start_position.z
	)

	return Vector3(
		displacement.x / flight_time,
		(displacement.y + 0.5 * gravity * flight_time * flight_time) / flight_time,
		displacement.z / flight_time
	)
