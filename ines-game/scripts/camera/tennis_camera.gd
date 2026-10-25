extends Node3D

@onready var camera: Camera3D = $FollowPivot/LookPivot/Camera3D
var _follow_target: Node3D
var _horizontal_offset := 0.0


func _ready() -> void:
	var local_player_id := SessionManager.local_player_id if NetworkManager.is_online else 1
	_follow_target = get_parent().get_node("Players/Player%d" % local_player_id)
	if local_player_id == 2:
		position.x = -position.x
		position.z = -position.z
		rotation.y += PI
	_horizontal_offset = position.x - _follow_target.position.x
	camera.current = true


func _process(_delta: float) -> void:
	if is_instance_valid(_follow_target):
		position.x = _follow_target.position.x + _horizontal_offset
