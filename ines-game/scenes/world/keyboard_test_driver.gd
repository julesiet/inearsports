extends Node

@onready var keyboard: KeyboardAdapter = $KeyboardAdapter
@onready var player1: TennisPlayer = get_node("../../Players/Player2")


func _physics_process(_delta: float) -> void:
	player1.set_controller_frame(keyboard.read_frame())
