extends Node

@onready var keyboard: KeyboardAdapter = $KeyboardAdapter
@onready var match_root: Node3D = get_node("../..")


func _physics_process(_delta: float) -> void:
	var frame: ControllerFrame = ControllerManager.read_frame(keyboard)
	if NetworkManager.is_online:
		var local_player_id := int(SessionManager.local_player_id)
		if local_player_id < 1 or local_player_id > 2:
			return
		var network_sync: Node = match_root.get_node("MatchSystems/MatchNetworkSync")
		network_sync.call("apply_controller_frame", local_player_id, frame)
		if not NetworkManager.is_host:
			network_sync.call("send_controller_frame", frame)
		return

	var player_id := int(match_root.get("current_hitter_id"))
	if player_id < 1 or player_id > 2:
		return

	var player: TennisPlayer = match_root.get_node(
		"Players/Player%d" % player_id
	)
	player.set_controller_frame(frame)

	if frame.swing_id >= 0:
		var racket: Node = player.get_node("VisualRoot/RacketAnchor/Racket")
		racket.call(
			"request_swing",
			frame.swing_id,
			frame.swing_strength,
			frame.aim
		)
