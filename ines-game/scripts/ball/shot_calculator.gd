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
	aim_limit: float = 4.5,
	racket_swing_direction: Vector3 = Vector3.ZERO
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

	var depth_fraction := clampf(0.45 + racket_swing_direction.z * 0.15, 0.25, 0.65)
	var target_z := toward_z * court_half_length * depth_fraction
	var target_y := clampf(
		ball_radius + maxf(racket_swing_direction.y, -0.5) * 1.5,
		ball_radius + 0.05,
		2.5
	)
	var flight_time := lerpf(1.75, 1.50, strength)

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
