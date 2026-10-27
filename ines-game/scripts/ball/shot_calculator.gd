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
	racket_swing_direction: Vector3 = Vector3.ZERO,
	curve_acceleration: float = 0.0
) -> Vector3:
	strength = clampf(strength, 0.0, 1.0)
	aim = aim.clamp(Vector2(-1, -1), Vector2(1, 1))

	# Player 1 is on +Z and shoots toward -Z; Player 2 is opposite.
	var toward_z := -1.0 if player_id == 1 else 1.0
	var screen_right_world_sign := 1.0 if player_id == 1 else -1.0

	var target_x := start_position.x + (
		aim.x * aim_limit + racket_swing_direction.x * (3.0 + strength * 1.5)
	) * screen_right_world_sign
	var side_margin := ball_radius + 0.35
	var x_limit := maxf(court_half_width - side_margin, 0.1)
	target_x = clampf(
		target_x,
		-x_limit,
		x_limit
	)

	var depth_fraction := clampf(
		0.52 + racket_swing_direction.z * 0.2 + racket_swing_direction.y * 0.07,
		0.4,
		0.75
	)
	var target_z := toward_z * court_half_length * depth_fraction
	# Shots keep their timing-based strength, but travel more slowly with extra hang time.
	var flight_time := clampf(
		lerpf(2.25, 1.35, strength) + racket_swing_direction.y * 0.2,
		1.1,
		2.7
	)
	var target_y := ball_radius

	var displacement := Vector3(
		target_x - start_position.x,
		target_y - start_position.y,
		target_z - start_position.z
	)

	return Vector3(
		(displacement.x - 0.5 * curve_acceleration * flight_time * flight_time)
			/ flight_time,
		(displacement.y + 0.5 * gravity * flight_time * flight_time) / flight_time,
		displacement.z / flight_time
	)
