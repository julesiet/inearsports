extends Control

const LOBBY_SCENE := "res://scenes/ui/lobby.tscn"
const CONTROLLER_SETUP_SCENE := "res://scenes/ui/controller_setup.tscn"
const MATCH_SCENE := "res://scenes/world/tennis_match.tscn"

@onready var play_button: Button = $CenterContainer/MenuContent/PlayButton
@onready var controller_button: Button = $CenterContainer/MenuContent/ControllerButton
@onready var debug_button: Button = $CenterContainer/MenuContent/DebugButton
@onready var quit_button: Button = $CenterContainer/MenuContent/QuitButton

var notice_dialog: AcceptDialog


func _ready() -> void:
	notice_dialog = AcceptDialog.new()
	notice_dialog.title = "AirPod Tennis"
	add_child(notice_dialog)

	play_button.pressed.connect(_on_play_pressed)
	controller_button.pressed.connect(_on_controller_pressed)
	debug_button.pressed.connect(_on_debug_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	play_button.grab_focus()


func _on_play_pressed() -> void:
	var error := get_tree().change_scene_to_file(LOBBY_SCENE)
	if error != OK:
		_show_notice("Could not open the lobby. Check the Output panel for details.")


func _on_controller_pressed() -> void:
	var error := get_tree().change_scene_to_file(CONTROLLER_SETUP_SCENE)
	if error != OK:
		_show_notice("Could not open controller setup. Check the Output panel for details.")


func _on_debug_pressed() -> void:
	SessionManager.leave_session()
	var error := get_tree().change_scene_to_file(MATCH_SCENE)
	if error != OK:
		_show_notice("Could not open the match debug scene. Check the Output panel for details.")


func _on_quit_pressed() -> void:
	get_tree().quit()


func _show_notice(message: String) -> void:
	notice_dialog.dialog_text = message
	notice_dialog.popup_centered()
