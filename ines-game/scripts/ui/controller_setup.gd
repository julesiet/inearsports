extends Control

const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const LOBBY_SCENE := "res://scenes/ui/lobby.tscn"

@onready var connection_status: Label = $MarginContainer/SetupContent/ConnectionStatus
@onready var input_mode_selector: OptionButton = $MarginContainer/SetupContent/InputModeSelector
@onready var calibrate_button: Button = $MarginContainer/SetupContent/CalibrateButton
@onready var tilt_meter: ProgressBar = $MarginContainer/SetupContent/MotionPreview/TiltMeter
@onready var swing_indicator: ColorRect = $MarginContainer/SetupContent/MotionPreview/SwingIndicator
@onready var sensitivity_control: HSlider = $MarginContainer/SetupContent/SensitivityControl
@onready var continue_button: Button = $MarginContainer/SetupContent/ContinueButton
@onready var back_button: Button = $MarginContainer/SetupContent/BackButton


func _ready() -> void:
	input_mode_selector.add_item("Keyboard")
	input_mode_selector.add_item("AirPods")
	input_mode_selector.select(int(ControllerManager.input_mode))
	sensitivity_control.value = ControllerManager.sensitivity

	input_mode_selector.item_selected.connect(_on_input_mode_selected)
	calibrate_button.pressed.connect(_on_calibrate_pressed)
	sensitivity_control.value_changed.connect(_on_sensitivity_changed)
	continue_button.pressed.connect(_on_continue_pressed)
	back_button.pressed.connect(_on_back_pressed)
	ControllerManager.motion_updated.connect(_on_motion_updated)
	_update_controls()


func _process(_delta: float) -> void:
	_update_controls()


func _exit_tree() -> void:
	if ControllerManager.motion_updated.is_connected(_on_motion_updated):
		ControllerManager.motion_updated.disconnect(_on_motion_updated)


func _on_input_mode_selected(index: int) -> void:
	ControllerManager.set_input_mode(index)
	_update_controls()


func _on_calibrate_pressed() -> void:
	if not ControllerManager.calibrate():
		connection_status.text = "NO AIRPOD STREAM — START THE AIRPOD BRIDGE FIRST"
	_update_controls()


func _on_sensitivity_changed(value: float) -> void:
	ControllerManager.set_sensitivity(value)


func _on_motion_updated(steering: float, swing_detected: bool) -> void:
	tilt_meter.value = steering
	if swing_detected:
		swing_indicator.color = Color(0.54, 0.94, 0.38, 1.0)
		var tween := create_tween()
		tween.tween_property(swing_indicator, "color", Color(0.23, 0.48, 0.48, 1.0), 0.35)


func _update_controls() -> void:
	connection_status.text = ControllerManager.get_status_text()
	var using_airpods := ControllerManager.is_airpod_mode()
	calibrate_button.disabled = not using_airpods or not ControllerManager.is_streaming()
	sensitivity_control.editable = using_airpods
	continue_button.disabled = not ControllerManager.can_continue()
	if not using_airpods:
		tilt_meter.value = 0.0


func _on_continue_pressed() -> void:
	ControllerManager.reset_pending_input()
	var error := SceneTransitionManager.change_scene_to_file(LOBBY_SCENE)
	if error != OK:
		connection_status.text = "COULD NOT OPEN THE LOBBY. CHECK THE OUTPUT PANEL."


func _on_back_pressed() -> void:
	var error := SceneTransitionManager.change_scene_to_file(MAIN_MENU_SCENE)
	if error != OK:
		push_error("Could not return to the main menu.")
