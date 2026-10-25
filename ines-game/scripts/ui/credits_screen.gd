extends Control

const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"

@onready var back_button: Button = $CenterContainer/CreditsContent/BackButton


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	back_button.grab_focus()


func _on_back_pressed() -> void:
	var error := SceneTransitionManager.change_scene_to_file(MAIN_MENU_SCENE)
	if error != OK:
		push_error("Could not return to the main menu.")
