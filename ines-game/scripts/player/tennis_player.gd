class_name TennisPlayer
extends CharacterBody3D

@export var move_speed: float = 5.0
@export var min_x: float = -3.0
@export var max_x: float = 3.0

# Player 1 uses +1. Set Player 2's value to -1
# when its camera faces the opposite way.
@export var screen_right_world_sign: float = 1.0

var _frame: ControllerFrame = ControllerFrame.new()


func set_controller_frame(frame: ControllerFrame) -> void:
	_frame = frame


func _physics_process(_delta: float) -> void:
	velocity = Vector3(
		_frame.move_x * screen_right_world_sign * move_speed,
		0.0,
		0.0
	)
	move_and_slide()

	var pos := global_position
	pos.x = clampf(pos.x, min_x, max_x)
	global_position = pos
