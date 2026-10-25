extends VBoxContainer

# when button is pressed --> load the game
const WORLD = preload("res://scenes/world/tennis_match.tscn")

func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_packed(WORLD)

func _on_quit_game_pressed() -> void:
	get_tree().quit()
