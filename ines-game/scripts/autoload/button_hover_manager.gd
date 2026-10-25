extends Node

const BUTTON_HOVER_SOUND: AudioStreamMP3 = preload("res://assets/audio/ButtonHover.mp3")
const BUTTON_SELECT_SOUND: AudioStreamMP3 = preload("res://assets/audio/ButtonSelect.mp3")
const HOVER_VOLUME_DB := 6.0

var _hover_player: AudioStreamPlayer
var _select_player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hover_player = AudioStreamPlayer.new()
	_hover_player.name = "ButtonHoverAudioPlayer"
	_hover_player.stream = BUTTON_HOVER_SOUND
	_hover_player.volume_db = HOVER_VOLUME_DB
	add_child(_hover_player)
	_select_player = AudioStreamPlayer.new()
	_select_player.name = "ButtonSelectAudioPlayer"
	_select_player.stream = BUTTON_SELECT_SOUND
	add_child(_select_player)
	get_tree().node_added.connect(_on_node_added)
	_connect_buttons_in_tree(get_tree().root)


func _on_node_added(node: Node) -> void:
	_connect_button(node)


func _connect_buttons_in_tree(node: Node) -> void:
	_connect_button(node)
	for child in node.get_children():
		_connect_buttons_in_tree(child)


func _connect_button(node: Node) -> void:
	if node is BaseButton:
		if not node.mouse_entered.is_connected(_play_hover_sound):
			node.mouse_entered.connect(_play_hover_sound)
		if not node.pressed.is_connected(_play_select_sound):
			node.pressed.connect(_play_select_sound)


func _play_hover_sound() -> void:
	_hover_player.play()


func _play_select_sound() -> void:
	_select_player.play()
