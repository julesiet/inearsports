extends Control

const LOBBY_SCENE := "res://scenes/ui/lobby.tscn"
const CONTROLLER_SETUP_SCENE := "res://scenes/ui/controller_setup.tscn"
const CREDITS_SCENE := "res://scenes/ui/credits_screen.tscn"
const MATCH_SCENE := "res://scenes/world/tennis_match.tscn"

@onready var play_button: Button = $CenterContainer/MenuContent/ButtonIndent/ButtonsStack/PlayButton
@onready var controller_button: Button = $CenterContainer/MenuContent/ButtonIndent/ButtonsStack/ControllerButton
@onready var debug_toggle: CheckBox = $DebugToggle
@onready var debug_button: Button = $CenterContainer/MenuContent/ButtonIndent/ButtonsStack/DebugButton
@onready var credits_button: Button = $CenterContainer/MenuContent/ButtonIndent/ButtonsStack/CreditsButton
@onready var quit_button: Button = $CenterContainer/MenuContent/ButtonIndent/ButtonsStack/QuitButton
@onready var menu_content: VBoxContainer = $CenterContainer/MenuContent
@onready var title_label: Label = $CenterContainer/MenuContent/TitleLabel
@onready var background_material: ShaderMaterial = $Background.material

var notice_dialog: AcceptDialog


func _ready() -> void:
	menu_content.visible = false
	title_label.modulate.a = 0.0
	for control in [play_button, controller_button, debug_toggle, debug_button, credits_button, quit_button]:
		control.modulate.a = 0.0

	notice_dialog = AcceptDialog.new()
	notice_dialog.title = "AirPod Tennis"
	add_child(notice_dialog)

	play_button.pressed.connect(_on_play_pressed)
	controller_button.pressed.connect(_on_controller_pressed)
	debug_toggle.toggled.connect(_on_debug_toggle_toggled)
	debug_button.pressed.connect(_on_debug_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	_update_debug_button_visibility(debug_toggle.button_pressed)
	_play_intro_animation()


func _play_intro_animation() -> void:
	var background_tween := create_tween()
	background_tween.tween_method(_set_background_reveal, 0.0, 1.0, 1.45)
	background_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await background_tween.finished

	menu_content.visible = true
	var content_tween := create_tween()
	content_tween.tween_property(title_label, "modulate:a", 1.0, 0.5)
	for button in [play_button, controller_button, debug_toggle, debug_button, credits_button, quit_button]:
		content_tween.tween_interval(0.08)
		if button != debug_button or debug_button.visible:
			content_tween.tween_property(button, "modulate:a", 1.0, 0.28)
	await content_tween.finished
	play_button.grab_focus()


func _set_background_reveal(value: float) -> void:
	background_material.set_shader_parameter("reveal", value)


func _on_debug_toggle_toggled(enabled: bool) -> void:
	_update_debug_button_visibility(enabled)
	if enabled:
		debug_button.modulate.a = 1.0


func _update_debug_button_visibility(enabled: bool) -> void:
	if not enabled and debug_button.has_focus():
		debug_toggle.grab_focus()
	debug_button.visible = enabled
	if enabled:
		debug_toggle.focus_neighbor_bottom = NodePath(
			"CenterContainer/MenuContent/ButtonIndent/ButtonsStack/DebugButton"
		)
		debug_button.focus_neighbor_top = NodePath("../../../../../DebugToggle")
		debug_button.focus_neighbor_bottom = NodePath("../CreditsButton")
		credits_button.focus_neighbor_top = NodePath("../DebugButton")
	else:
		debug_toggle.focus_neighbor_bottom = NodePath(
			"CenterContainer/MenuContent/ButtonIndent/ButtonsStack/CreditsButton"
		)
		credits_button.focus_neighbor_top = NodePath("../../../../../DebugToggle")


func _on_play_pressed() -> void:
	var error := SceneTransitionManager.change_scene_to_file(LOBBY_SCENE)
	if error != OK:
		_show_notice("Could not open the lobby. Check the Output panel for details.")


func _on_controller_pressed() -> void:
	var error := SceneTransitionManager.change_scene_to_file(CONTROLLER_SETUP_SCENE)
	if error != OK:
		_show_notice("Could not open controller setup. Check the Output panel for details.")


func _on_debug_pressed() -> void:
	SessionManager.leave_session()
	SessionManager.hud_debug_mode = true
	var error := SceneTransitionManager.change_scene_to_file(MATCH_SCENE)
	if error != OK:
		_show_notice("Could not open the match debug scene. Check the Output panel for details.")


func _on_credits_pressed() -> void:
	var error := SceneTransitionManager.change_scene_to_file(CREDITS_SCENE)
	if error != OK:
		_show_notice("Could not open the credits screen. Check the Output panel for details.")


func _on_quit_pressed() -> void:
	get_tree().quit()


func _show_notice(message: String) -> void:
	notice_dialog.dialog_text = message
	notice_dialog.popup_centered()
