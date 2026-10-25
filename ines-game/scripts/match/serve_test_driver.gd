extends Node

@onready var serve_manager: Node = $"../ServeManager"
@onready var match_root: Node = get_node("../..")
@onready var match_state: Node = $"../MatchState"
@onready var ball: Node = get_node("../../Ball")

func _ready() -> void:
	if NetworkManager.is_online and not NetworkManager.is_host:
		return
	await get_tree().process_frame
	serve_manager.call("start_match")


func _unhandled_input(event: InputEvent) -> void:
	if NetworkManager.is_online and not NetworkManager.is_host:
		return
	if event.is_action_pressed("debug_point") and not event.is_echo():
		var winner_id := int(match_root.get("current_hitter_id"))
		serve_manager.call("award_point", winner_id, "debug point")

	if event.is_action_pressed("debug_serve") and not event.is_echo():
		serve_manager.call("launch_serve")

	if event.is_action_pressed("debug_out_fault") and not event.is_echo():
		if int(match_state.get("phase")) != 2:
			return
		var rules: MatchRules = serve_manager.get("rules")
		var outside_x := rules.court_half_width + 1.0
		ball.call("launch", Vector3(outside_x, 1.0, 0.0), Vector3(0.0, -2.0, 0.0))

	if event.is_action_pressed("debug_net_fault") and not event.is_echo():
		if int(match_state.get("phase")) != 2:
			return
		ball.call("launch", Vector3(0.0, 0.5, 0.25), Vector3(0.0, 0.0, -5.0))
