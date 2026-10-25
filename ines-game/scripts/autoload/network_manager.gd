extends Node

signal status_changed(message: String)
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal connection_succeeded
signal connection_lost(message: String)

const PORT := 7000
const MAX_CLIENTS := 1

var is_online := false
var is_host := false
var is_connected := false
var status_text := "Offline"

var _peer: ENetMultiplayerPeer


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func host_game() -> bool:
	if is_online:
		leave_game()

	var server := ENetMultiplayerPeer.new()
	var error := server.create_server(PORT, MAX_CLIENTS)
	if error != OK:
		_set_status("Could not host on port %d (error %d)." % [PORT, error])
		return false

	_peer = server
	multiplayer.multiplayer_peer = server
	is_online = true
	is_host = true
	is_connected = true
	_set_status("Hosting on port %d. Waiting for the other Mac." % PORT)
	return true


func join_game(host_ip: String) -> bool:
	var address := host_ip.strip_edges()
	if (
		not _is_valid_ipv4_address(address)
		or address.begins_with("127.")
		or address == "0.0.0.0"
	):
		_set_status("Enter the host Mac's LAN IPv4 address.")
		return false
	if is_online:
		leave_game()

	var client := ENetMultiplayerPeer.new()
	var error := client.create_client(address, PORT)
	if error != OK:
		_set_status("Could not start the connection (error %d)." % error)
		return false

	_peer = client
	multiplayer.multiplayer_peer = client
	is_online = true
	is_host = false
	is_connected = false
	_set_status("Connecting to %s:%d…" % [address, PORT])
	return true


func _is_valid_ipv4_address(address: String) -> bool:
	var octets := address.split(".", true)
	if octets.size() != 4:
		return false

	for octet in octets:
		if octet.is_empty() or octet.length() > 3:
			return false
		for index in range(octet.length()):
			var character := octet.unicode_at(index)
			if character < 48 or character > 57:
				return false
		var value := int(octet)
		if value > 255:
			return false
	return true


func leave_game() -> void:
	if _peer != null:
		_peer.close()
		_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	is_online = false
	is_host = false
	is_connected = false
	_set_status("Offline")


func get_lan_addresses() -> PackedStringArray:
	var addresses := PackedStringArray()
	for address in IP.get_local_addresses():
		if address.contains(":") or address.begins_with("127."):
			continue
		if address.begins_with("169.254.") or address == "0.0.0.0":
			continue
		addresses.append(address)
	return addresses


func _set_status(message: String) -> void:
	status_text = message
	status_changed.emit(status_text)


func _on_peer_connected(peer_id: int) -> void:
	peer_connected.emit(peer_id)
	if is_host:
		_set_status("Player connected. Both Macs can ready up.")


func _on_peer_disconnected(peer_id: int) -> void:
	peer_disconnected.emit(peer_id)
	if is_host:
		_set_status("Player disconnected. Waiting for the other Mac.")


func _on_connected_to_server() -> void:
	is_connected = true
	_set_status("Connected to the host Mac.")
	connection_succeeded.emit()


func _on_connection_failed() -> void:
	connection_lost.emit("Connection failed. Check both Macs are on the same LAN and the host IP is correct.")
	_close_after_connection_loss("Connection failed. Check the host IP, Wi-Fi, and firewall.")


func _on_server_disconnected() -> void:
	connection_lost.emit("The host Mac disconnected.")
	_close_after_connection_loss("The host Mac disconnected.")


func _close_after_connection_loss(message: String) -> void:
	if _peer != null:
		_peer.close()
		_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	is_online = false
	is_host = false
	is_connected = false
	_set_status(message)
