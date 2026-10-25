extends Node

@onready var ball := get_node("../../Ball")


func _ready() -> void:
	ball.launch(Vector3(0, 2, 3), Vector3(0, 2, -10))
