extends Node

const TRANSITION_SCENE: PackedScene = preload(
	"res://assets/TransitionKit/transitions/t_circle.tscn"
)
const TRANSITION_COLOR := Color(0.02, 0.61, 0.78, 1.0)
const TRANSITION_DURATION := 0.35

var _is_transitioning := false


func change_scene_to_file(scene_path: String) -> Error:
	if _is_transitioning:
		return ERR_BUSY
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		return ERR_FILE_NOT_FOUND

	_is_transitioning = true
	call_deferred("_run_transition", scene_path)
	return OK


func _run_transition(scene_path: String) -> void:
	var transition_layer := CanvasLayer.new()
	transition_layer.layer = 100
	var transition_rect := TRANSITION_SCENE.instantiate() as ColorRect
	transition_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	transition_layer.add_child(transition_rect)
	get_tree().root.add_child(transition_layer)
	var transition_material := transition_rect.material as ShaderMaterial
	transition_material.set_shader_parameter("base_color", TRANSITION_COLOR)
	transition_rect.set("factor", 0.0)

	await get_tree().process_frame
	transition_rect.call("set_shader_resolution")
	var cover_tween := create_tween()
	cover_tween.tween_property(transition_rect, "factor", 1.0, TRANSITION_DURATION)
	await cover_tween.finished

	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("Could not open scene: %s" % scene_path)
	else:
		await get_tree().process_frame

	var reveal_tween := create_tween()
	reveal_tween.tween_property(transition_rect, "factor", 0.0, TRANSITION_DURATION)
	await reveal_tween.finished
	transition_layer.queue_free()
	_is_transitioning = false
