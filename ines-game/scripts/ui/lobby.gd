extends Control

const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"

@onready var host_button: Button = $MarginContainer/LobbyContent/HostButton
@onready var ip_address_input: LineEdit = $MarginContainer/LobbyContent/JoinRow/IPAddressInput
@onready var join_button: Button = $MarginContainer/LobbyContent/JoinRow/JoinButton
@onready var connection_status: Label = $MarginContainer/LobbyContent/ConnectionStatus
@onready var player_list: VBoxContainer = $MarginContainer/LobbyContent/PlayerList
@onready var ready_button: Button = $MarginContainer/LobbyContent/ReadyButton
@onready var start_match_button: Button = $MarginContainer/LobbyContent/StartMatchButton
@onready var back_button: Button = $MarginContainer/LobbyContent/BackButton


func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	ready_button.pressed.connect(_on_ready_pressed)
	start_match_button.pressed.connect(_on_start_match_pressed)
	back_button.pressed.connect(_on_back_pressed)
	ip_address_input.text_submitted.connect(_on_ip_submitted)

	NetworkManager.status_changed.connect(_on_network_status_changed)
	SessionManager.lobby_state_changed.connect(_refresh_lobby)
	SessionManager.match_start_failed.connect(_on_match_start_failed)
	ip_address_input.grab_focus()
	_refresh_lobby()


func _exit_tree() -> void:
	if NetworkManager.status_changed.is_connected(_on_network_status_changed):
		NetworkManager.status_changed.disconnect(_on_network_status_changed)
	if SessionManager.lobby_state_changed.is_connected(_refresh_lobby):
		SessionManager.lobby_state_changed.disconnect(_refresh_lobby)
	if SessionManager.match_start_failed.is_connected(_on_match_start_failed):
		SessionManager.match_start_failed.disconnect(_on_match_start_failed)


func _on_host_pressed() -> void:
	if NetworkManager.host_game():
		SessionManager.begin_host_session()
	_refresh_lobby()


func _on_join_pressed() -> void:
	if NetworkManager.join_game(ip_address_input.text):
		SessionManager.begin_client_session()
	_refresh_lobby()


func _on_ip_submitted(_text: String) -> void:
	_on_join_pressed()


func _on_ready_pressed() -> void:
	SessionManager.toggle_local_ready()
	_refresh_lobby()


func _on_start_match_pressed() -> void:
	SessionManager.start_match()


func _on_back_pressed() -> void:
	SessionManager.leave_session()
	var error := SceneTransitionManager.change_scene_to_file(MAIN_MENU_SCENE)
	if error != OK:
		push_error("Could not return to the main menu.")


func _on_network_status_changed(_message: String) -> void:
	_refresh_lobby()


func _on_match_start_failed(message: String) -> void:
	_refresh_lobby()
	connection_status.text = message


func _refresh_lobby() -> void:
	host_button.disabled = NetworkManager.is_online
	join_button.disabled = NetworkManager.is_online
	ip_address_input.editable = not NetworkManager.is_online
	ready_button.disabled = not NetworkManager.is_connected
	ready_button.text = "NOT READY — CLICK TO READY" if not SessionManager.is_player_ready(
		SessionManager.local_player_id
	) else "READY — CLICK TO UNREADY"
	start_match_button.visible = NetworkManager.is_host
	start_match_button.disabled = not SessionManager.can_start_match()

	connection_status.text = _status_for_current_peer()
	_refresh_player_list()


func _status_for_current_peer() -> String:
	if NetworkManager.is_host:
		var addresses := NetworkManager.get_lan_addresses()
		if addresses.is_empty():
			return "HOSTING ON PORT %d — FIND THIS MAC'S LAN IP TO SHARE" % NetworkManager.PORT
		return "HOSTING · GIVE THE OTHER MAC THIS IP: %s · PORT %d" % [
			", ".join(addresses),
			NetworkManager.PORT,
		]
	return NetworkManager.status_text.to_upper()


func _refresh_player_list() -> void:
	for child in player_list.get_children():
		player_list.remove_child(child)
		child.queue_free()

	_add_player_row(1, "HOST", true, SessionManager.player1_ready)
	_add_player_row(2, "CLIENT", SessionManager.player2_connected, SessionManager.player2_ready)


func _add_player_row(player_id: int, role: String, connected: bool, is_ready: bool) -> void:
	var row := Label.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_theme_font_size_override("font_size", 22)
	row.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	var local_marker := " · YOU" if SessionManager.local_player_id == player_id else ""
	var connection_label := "CONNECTED" if connected else "WAITING FOR CONNECTION"
	var ready_label := "READY" if is_ready else "NOT READY"
	row.text = "PLAYER %d · %s%s · %s · %s" % [
		player_id,
		role,
		local_marker,
		connection_label,
		ready_label,
	]
	player_list.add_child(row)
