class_name TennisPlayer
extends CharacterBody3D

@export var move_speed: float = 5.0
@export var min_x: float = -4.5
@export var max_x: float = 4.5
@export var min_z: float = -13.0
@export var max_z: float = 13.0
@export var ball_follow_speed: float = 4.5
@export var ball_follow_gain: float = 2.5

# Player 1 uses +1. Set Player 2's value to -1
# when its camera faces the opposite way.
@export var screen_right_world_sign: float = 1.0

var _frame: ControllerFrame = ControllerFrame.new()
var _ball_follow_enabled := false
var _ball_follow_target := Vector3.ZERO


func set_controller_frame(frame: ControllerFrame) -> void:
	_frame = frame


func set_ball_follow_target(target: Vector3) -> void:
	_ball_follow_target = Vector3(
		clampf(target.x, min_x, max_x),
		global_position.y,
		clampf(target.z, min_z, max_z)
	)
	_ball_follow_enabled = true


func clear_ball_follow_target() -> void:
	_ball_follow_enabled = false


func _physics_process(_delta: float) -> void:
	if _ball_follow_enabled:
		var follow_error := Vector2(
			_ball_follow_target.x - global_position.x,
			_ball_follow_target.z - global_position.z
		)
		var follow_velocity := follow_error * ball_follow_gain
		if follow_velocity.length() > ball_follow_speed:
			follow_velocity = follow_velocity.normalized() * ball_follow_speed
		velocity = Vector3(follow_velocity.x, 0.0, follow_velocity.y)
	else:
		velocity = Vector3(
			_frame.move_x * screen_right_world_sign * move_speed,
			0.0,
			0.0
		)
	move_and_slide()

	var pos := global_position
	pos.x = clampf(pos.x, min_x, max_x)
	pos.z = clampf(pos.z, min_z, max_z)
	global_position = pos
