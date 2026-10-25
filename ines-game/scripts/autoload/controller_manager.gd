extends Node

signal motion_updated(steering: float, swing_detected: bool)

enum InputMode { KEYBOARD, AIRPODS }

const UDP_PORT := 5055
const SWING_THRESHOLD := 8.0
const SWING_COOLDOWN_MS := 400
const STREAM_TIMEOUT_MS := 1500
const STEERING_RANGE_RADIANS := 0.7

var input_mode: InputMode = InputMode.KEYBOARD
var sensitivity := 1.0

var _udp := PacketPeerUDP.new()
var _udp_error := OK
var _last_packet_time_msec := -1
var _rotation_rate := Vector3.ZERO
var _current_orientation := Quaternion.IDENTITY
var _neutral_orientation := Quaternion.IDENTITY
var _is_calibrated := false
var _last_swing_time_msec := -SWING_COOLDOWN_MS
var _next_swing_id := 0
var _pending_swing_id := -1
var _pending_swing_strength := 0.0
var _frame_sequence := 0


func _ready() -> void:
	_udp_error = _udp.bind(UDP_PORT, "127.0.0.1")
	if _udp_error != OK:
		push_error("ControllerManager could not bind UDP port %d." % UDP_PORT)


func _process(_delta: float) -> void:
	while _udp.get_available_packet_count() > 0:
		_read_packet(_udp.get_packet().get_string_from_utf8())


func _read_packet(packet_text: String) -> void:
	var packet: Variant = JSON.parse_string(packet_text)
	if not packet is Dictionary:
		return

	var rate_data: Variant = packet.get("rotation_rate", {})
	var orientation_data: Variant = packet.get("orientation", {})
	if not rate_data is Dictionary or not orientation_data is Dictionary:
		return
	if not rate_data.has("x") or not rate_data.has("y") or not rate_data.has("z"):
		return
	if (
		not orientation_data.has("x")
		or not orientation_data.has("y")
		or not orientation_data.has("z")
		or not orientation_data.has("w")
	):
		return

	_rotation_rate = Vector3(
		float(rate_data["x"]),
		float(rate_data["y"]),
		float(rate_data["z"])
	)
	_current_orientation = Quaternion(
		float(orientation_data["x"]),
		float(orientation_data["y"]),
		float(orientation_data["z"]),
		float(orientation_data["w"])
	).normalized()
	_last_packet_time_msec = Time.get_ticks_msec()

	var swing_detected := _detect_swing()
	motion_updated.emit(get_steering_value(), swing_detected)


func _detect_swing() -> bool:
	if input_mode != InputMode.AIRPODS:
		return false

	var now := Time.get_ticks_msec()
	if _rotation_rate.length() <= SWING_THRESHOLD:
		return false
	if now - _last_swing_time_msec < SWING_COOLDOWN_MS:
		return false

	_last_swing_time_msec = now
	_next_swing_id += 1
	_pending_swing_id = _next_swing_id
	_pending_swing_strength = clampf(
		(_rotation_rate.length() - SWING_THRESHOLD) / 12.0,
		0.35,
		1.0
	)
	return true


func set_input_mode(mode_index: int) -> void:
	if mode_index < InputMode.KEYBOARD or mode_index > InputMode.AIRPODS:
		return
	if input_mode == mode_index:
		return

	input_mode = InputMode.AIRPODS if mode_index == InputMode.AIRPODS else InputMode.KEYBOARD
	_is_calibrated = false
	reset_pending_input()


func calibrate() -> bool:
	if not is_streaming():
		return false

	_neutral_orientation = _current_orientation
	_is_calibrated = true
	reset_pending_input()
	return true


func set_sensitivity(value: float) -> void:
	sensitivity = clampf(value, 0.5, 2.0)


func reset_pending_input() -> void:
	_pending_swing_id = -1
	_pending_swing_strength = 0.0


func is_streaming() -> bool:
	return (
		_udp_error == OK
		and _last_packet_time_msec >= 0
		and Time.get_ticks_msec() - _last_packet_time_msec <= STREAM_TIMEOUT_MS
	)


func can_continue() -> bool:
	return input_mode == InputMode.KEYBOARD or (is_streaming() and _is_calibrated)


func is_airpod_mode() -> bool:
	return input_mode == InputMode.AIRPODS


func get_status_text() -> String:
	if input_mode == InputMode.KEYBOARD:
		return "KEYBOARD READY — A/D TO MOVE, ARROWS TO AIM, SPACE TO SWING"
	if _udp_error != OK:
		return "UDP PORT %d IS UNAVAILABLE" % UDP_PORT
	if _last_packet_time_msec < 0:
		return "DISCONNECTED — START THE AIRPOD BRIDGE"
	if not is_streaming():
		return "STALE — WAITING FOR AIRPOD MOTION"
	if not _is_calibrated:
		return "STREAMING — HOLD NEUTRAL AND CALIBRATE"
	return "AIRPODS READY — MOTION STREAMING"


func get_steering_value() -> float:
	if input_mode != InputMode.AIRPODS or not is_streaming():
		return 0.0

	var relative_orientation := _neutral_orientation.inverse() * _current_orientation
	var roll_radians := relative_orientation.get_euler().z
	return clampf(roll_radians / STEERING_RANGE_RADIANS * sensitivity, -1.0, 1.0)


func read_frame(keyboard_adapter: KeyboardAdapter) -> ControllerFrame:
	if input_mode == InputMode.KEYBOARD:
		return keyboard_adapter.read_frame()

	_frame_sequence += 1
	var valid := is_streaming() and _is_calibrated
	var swing_id := _pending_swing_id if valid else -1
	var swing_strength := _pending_swing_strength if valid else 0.0
	reset_pending_input()
	return ControllerFrame.new(
		get_steering_value() if valid else 0.0,
		Vector2.ZERO,
		swing_id,
		swing_strength,
		_frame_sequence,
		Time.get_ticks_msec(),
		valid
	)
