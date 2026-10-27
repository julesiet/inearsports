extends Node3D

@export_range(1.0, 8.0, 0.1) var camera_height := 3.5
@export_range(4.0, 12.0, 0.1) var camera_distance := 5.5
@export_range(4.0, 12.0, 0.1) var look_ahead_distance := 7.0
@export_range(0.5, 10.0, 0.1) var follow_smoothness := 3.0
@export_range(0.5, 12.0, 0.1) var look_smoothness := 5.0

@onready var camera: Camera3D = $FollowPivot/LookPivot/Camera3D
var _follow_target: Node3D
var _player_side := 1.0
var _smoothed_look_target := Vector3.ZERO


func _ready() -> void:
	var local_player_id := SessionManager.local_player_id if NetworkManager.is_online else 1
	_follow_target = get_parent().get_node("Players/Player%d" % local_player_id)
	_player_side = 1.0 if local_player_id == 1 else -1.0
	global_rotation = Vector3.ZERO
	global_position = _desired_camera_position()
	_smoothed_look_target = _desired_look_target()
	camera.current = true
	camera.look_at(_smoothed_look_target, Vector3.UP)


func _process(delta: float) -> void:
	if not is_instance_valid(_follow_target):
		return

	var follow_weight := 1.0 - exp(-follow_smoothness * delta)
	global_position = global_position.lerp(_desired_camera_position(), follow_weight)

	var look_weight := 1.0 - exp(-look_smoothness * delta)
	_smoothed_look_target = _smoothed_look_target.lerp(_desired_look_target(), look_weight)
	camera.look_at(_smoothed_look_target, Vector3.UP)


func _desired_camera_position() -> Vector3:
	return _follow_target.global_position + Vector3(
		0.0,
		camera_height,
		camera_distance * _player_side
	)


func _desired_look_target() -> Vector3:
	return _follow_target.global_position + Vector3(
		0.0,
		1.2,
		-look_ahead_distance * _player_side
	)
