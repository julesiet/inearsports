extends Node

signal lobby_state_changed
signal match_start_failed(message: String)

const MATCH_SCENE := "res://scenes/world/tennis_match.tscn"

var local_player_id := 1
var player1_ready := false
var player2_ready := false
var player2_connected := false
var match_started := false

var _peer_to_player_id := {1: 1}


func _ready() -> void:
	NetworkManager.peer_connected.connect(_on_peer_connected)
	NetworkManager.peer_disconnected.connect(_on_peer_disconnected)
	NetworkManager.connection_succeeded.connect(_on_connection_succeeded)
	NetworkManager.connection_lost.connect(_on_connection_lost)


func begin_host_session() -> void:
	local_player_id = 1
	player1_ready = false
	player2_ready = false
	player2_connected = false
	match_started = false
	_peer_to_player_id = {1: 1}
	lobby_state_changed.emit()


func begin_client_session() -> void:
	local_player_id = 2
	player1_ready = false
	player2_ready = false
	player2_connected = false
	match_started = false
	_peer_to_player_id = {1: 1, multiplayer.get_unique_id(): 2}
	lobby_state_changed.emit()


func leave_session() -> void:
	NetworkManager.leave_game()
	local_player_id = 1
	player1_ready = false
	player2_ready = false
	player2_connected = false
	match_started = false
	_peer_to_player_id = {1: 1}
	lobby_state_changed.emit()


func player_id_for_peer(peer_id: int) -> int:
	return int(_peer_to_player_id.get(peer_id, 0))


func is_player_ready(player_id: int) -> bool:
	return player1_ready if player_id == 1 else player2_ready


func toggle_local_ready() -> void:
	if not NetworkManager.is_connected:
		return
	var ready_value := not is_player_ready(local_player_id)
	if NetworkManager.is_host:
		player1_ready = ready_value
		_broadcast_lobby_state()
	else:
		request_ready_state.rpc_id(1, ready_value)


func can_start_match() -> bool:
	return (
		NetworkManager.is_host
		and player2_connected
		and player1_ready
		and player2_ready
		and not match_started
	)


func start_match() -> void:
	if can_start_match():
		start_match_for_peers.rpc()


func request_rematch() -> void:
	if not NetworkManager.is_online:
		var error := await SceneTransitionManager.change_scene_to_file(MATCH_SCENE)
		if error != OK:
			match_start_failed.emit("Could not reopen the match scene.")
		return

	if NetworkManager.is_host:
		if match_started:
			player1_ready = false
			player2_ready = false
			match_started = false
		player1_ready = true
		_broadcast_lobby_state()
	else:
		request_rematch_ready.rpc_id(1)
	await _change_to_lobby()


func return_to_lobby() -> void:
	if NetworkManager.is_host:
		player1_ready = false
		player2_ready = false
		match_started = false
		_broadcast_lobby_state()
	elif NetworkManager.is_online:
		request_lobby_reset.rpc_id(1)
	await _change_to_lobby()


@rpc("any_peer", "call_remote", "reliable")
func request_lobby_state() -> void:
	if not NetworkManager.is_host:
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if not multiplayer.get_peers().has(sender_id):
		return
	_peer_to_player_id[sender_id] = 2
	player2_connected = true
	_send_lobby_state(sender_id)


@rpc("any_peer", "call_remote", "reliable")
func request_ready_state(ready_value: bool) -> void:
	if not NetworkManager.is_host:
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if player_id_for_peer(sender_id) != 2:
		return
	player2_ready = ready_value
	_broadcast_lobby_state()


@rpc("any_peer", "call_remote", "reliable")
func request_rematch_ready() -> void:
	if not NetworkManager.is_host:
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if player_id_for_peer(sender_id) != 2:
		return
	if match_started:
		player1_ready = false
		player2_ready = false
		match_started = false
	player2_ready = true
	_broadcast_lobby_state()


@rpc("any_peer", "call_remote", "reliable")
func request_lobby_reset() -> void:
	if not NetworkManager.is_host:
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if player_id_for_peer(sender_id) != 2:
		return
	player1_ready = false
	player2_ready = false
	match_started = false
	_broadcast_lobby_state()


@rpc("authority", "call_remote", "reliable")
func receive_lobby_state(ready1: bool, ready2: bool, connected2: bool) -> void:
	_apply_lobby_state(ready1, ready2, connected2)


@rpc("authority", "call_local", "reliable")
func start_match_for_peers() -> void:
	if not NetworkManager.is_host and not multiplayer.is_server():
		match_started = true
		await _change_to_match()
		return
	if not can_start_match():
		return
	match_started = true
	await _change_to_match()


func _on_peer_connected(peer_id: int) -> void:
	if not NetworkManager.is_host:
		return
	_peer_to_player_id[peer_id] = 2
	player2_connected = true
	player2_ready = false
	_broadcast_lobby_state()


func _on_peer_disconnected(peer_id: int) -> void:
	if player_id_for_peer(peer_id) == 2:
		_peer_to_player_id.erase(peer_id)
		player2_connected = false
		player2_ready = false
		if NetworkManager.is_host:
			_broadcast_lobby_state()
		else:
			lobby_state_changed.emit()


func _on_connection_succeeded() -> void:
	local_player_id = 2
	_peer_to_player_id = {1: 1, multiplayer.get_unique_id(): 2}
	request_lobby_state.rpc_id(1)


func _on_connection_lost(_message: String) -> void:
	player1_ready = false
	player2_ready = false
	player2_connected = false
	match_started = false
	lobby_state_changed.emit()


func _broadcast_lobby_state() -> void:
	_apply_lobby_state(player1_ready, player2_ready, player2_connected)
	receive_lobby_state.rpc(player1_ready, player2_ready, player2_connected)


func _send_lobby_state(peer_id: int) -> void:
	receive_lobby_state.rpc_id(peer_id, player1_ready, player2_ready, player2_connected)


func _apply_lobby_state(ready1: bool, ready2: bool, connected2: bool) -> void:
	player1_ready = ready1
	player2_ready = ready2
	player2_connected = connected2
	lobby_state_changed.emit()


func _change_to_match() -> void:
	var error := await SceneTransitionManager.change_scene_to_file(MATCH_SCENE)
	if error != OK:
		match_started = false
		match_start_failed.emit("Could not open the match scene.")


func _change_to_lobby() -> void:
	match_started = false
	var error := await SceneTransitionManager.change_scene_to_file("res://scenes/ui/lobby.tscn")
	if error != OK:
		match_start_failed.emit("Could not open the lobby scene.")
