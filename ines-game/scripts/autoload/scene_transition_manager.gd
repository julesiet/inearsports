extends Node

signal transition_finished

const TRANSITION_SCENE: PackedScene = preload(
	"res://assets/TransitionKit/transitions/t_cells.tscn"
)
const TRANSITION_COLOR := Color("#007fa6")
const TRANSITION_DURATION := 0.38
const TRANSITION_LAYER := 100

var _transition_in_progress := false


func change_scene_to_file(scene_path: String) -> int:
	while _transition_in_progress:
		await transition_finished

	var tree := get_tree()
	if tree.current_scene != null and tree.current_scene.scene_file_path == scene_path:
		return OK

	_transition_in_progress = true
	var transition_layer := CanvasLayer.new()
	transition_layer.layer = TRANSITION_LAYER
	tree.root.add_child(transition_layer)

	var transition := TRANSITION_SCENE.instantiate() as ColorRect
	transition.mouse_filter = Control.MOUSE_FILTER_STOP
	transition.set("base_color", TRANSITION_COLOR)
	transition.set("factor", 0.0)
	transition_layer.add_child(transition)

	await _animate_factor(transition, 1.0)
	var error := tree.change_scene_to_file(scene_path)
	if error == OK:
		await tree.scene_changed
	else:
		push_error("Could not open scene: %s" % scene_path)
	await _animate_factor(transition, 0.0)

	transition_layer.queue_free()
	_transition_in_progress = false
	transition_finished.emit()
	return error


func _animate_factor(transition: ColorRect, target_factor: float) -> void:
	var tween := transition.create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(transition, "factor", target_factor, TRANSITION_DURATION)
	await tween.finished
