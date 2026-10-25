class_name TennisPlayer
extends CharacterBody3D

const PLAYER_MODEL_SCALE := 0.75

@export var move_speed: float = 5.0
@export var min_x: float = -7.0
@export var max_x: float = 7.0
@export var min_z: float = -17.0
@export var max_z: float = 17.0
@export var ball_follow_speed: float = 5.5
@export var ball_follow_gain: float = 3.5
@export var player_model_scene: PackedScene
@export var player_model_mirror_center_x: float = 0.0
@export var avatar_foot_color := Color(0.96, 0.47, 0.25, 1.0)

# Player 1 uses +1. Set Player 2's value to -1
# when its camera faces the opposite way.
@export var screen_right_world_sign: float = 1.0

@onready var _model_root: Node3D = $VisualRoot/PlayerMesh/ModelRoot
@onready var _racket_controller: Node = $VisualRoot/RacketAnchor/Racket

var _frame: ControllerFrame = ControllerFrame.new()
var _ball_follow_enabled := false
var _ball_follow_target := Vector3.ZERO
var _ball_follow_speed_multiplier := 1.0
var _movement_locked := false
var _model_skeletons: Array[Skeleton3D] = []
var _skeleton_bone_indices: Array[Dictionary] = []
var _skeleton_is_mirrored: Array[bool] = []
var _avatar_legs: Array[MeshInstance3D] = []
var _leg_rest_positions: Array[Vector3] = []
var _avatar_feet: Array[MeshInstance3D] = []
var _foot_rest_positions: Array[Vector3] = []
var _model_rest_position := Vector3.ZERO
var _model_rest_rotation := Vector3.ZERO
var _animation_time := 0.0
var _walk_phase := 0.0
var _locomotion_blend := 0.0
var _previous_racket_state := 0
var _swing_elapsed := 0.5
var _swing_is_backhand := false


func _ready() -> void:
	if player_model_scene == null:
		return
	var player_model := player_model_scene.instantiate() as Node3D
	if player_model == null:
		push_warning("Player model scene must have a Node3D root.")
		return
	player_model.name = "ImportedPlayerModel"
	player_model.scale *= PLAYER_MODEL_SCALE
	var mirrored_model := player_model_scene.instantiate() as Node3D
	if mirrored_model == null:
		push_warning("Player model scene must have a Node3D root.")
		return
	mirrored_model.name = "MirroredPlayerModel"
	mirrored_model.scale *= PLAYER_MODEL_SCALE
	mirrored_model.scale.x = -mirrored_model.scale.x
	mirrored_model.position.x = player_model_mirror_center_x * 2.0 * PLAYER_MODEL_SCALE
	# The imported models face +Z; turn them toward the opposing end of the court.
	_model_root.rotation.y = PI
	_model_rest_position = _model_root.position
	_model_rest_rotation = _model_root.rotation
	_model_root.add_child(player_model)
	_model_root.add_child(mirrored_model)
	_set_model_unshaded(player_model)
	_set_model_unshaded(mirrored_model)
	_cache_model_skeletons(player_model, false)
	_cache_model_skeletons(mirrored_model, true)
	_create_avatar_feet()


func _cache_model_skeletons(model: Node3D, is_mirrored: bool) -> void:
	for skeleton_node in model.find_children("*", "Skeleton3D", true, false):
		var skeleton := skeleton_node as Skeleton3D
		if skeleton.get_bone_count() < 100:
			continue
		var bone_indices: Dictionary = {}
		for bone_index in skeleton.get_bone_count():
			bone_indices[skeleton.get_bone_name(bone_index)] = bone_index
		_model_skeletons.append(skeleton)
		_skeleton_bone_indices.append(bone_indices)
		_skeleton_is_mirrored.append(is_mirrored)


func _create_avatar_feet() -> void:
	for side in [-1.0, 1.0]:
		var leg := MeshInstance3D.new()
		leg.name = "AvatarLegLeft" if side < 0.0 else "AvatarLegRight"
		var leg_mesh := CapsuleMesh.new()
		leg_mesh.radius = 0.075
		leg_mesh.height = 0.42
		leg_mesh.radial_segments = 8
		leg_mesh.rings = 3
		leg.mesh = leg_mesh
		leg.position = Vector3(side * 0.16, -0.055, -0.18)
		var leg_material := StandardMaterial3D.new()
		leg_material.albedo_color = avatar_foot_color
		leg_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		leg.material_override = leg_material
		_model_root.add_child(leg)
		_avatar_legs.append(leg)
		_leg_rest_positions.append(leg.position)

		var foot := MeshInstance3D.new()
		foot.name = "AvatarFootLeft" if side < 0.0 else "AvatarFootRight"
		var foot_mesh := SphereMesh.new()
		foot_mesh.radius = 0.12
		foot_mesh.height = 0.14
		foot_mesh.radial_segments = 8
		foot_mesh.rings = 4
		foot.mesh = foot_mesh
		foot.position = Vector3(side * 0.16, -0.23, -0.28)
		foot.scale = Vector3(1.0, 0.8, 1.45)
		var foot_material := StandardMaterial3D.new()
		foot_material.albedo_color = avatar_foot_color
		foot_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		foot.material_override = foot_material
		_model_root.add_child(foot)
		_avatar_feet.append(foot)
		_foot_rest_positions.append(foot.position)


func _set_model_unshaded(model: Node3D) -> void:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var material := mesh_instance.mesh.surface_get_material(surface_index)
			if material is BaseMaterial3D:
				var flat_material := material.duplicate() as BaseMaterial3D
				flat_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mesh_instance.set_surface_override_material(surface_index, flat_material)


func set_controller_frame(frame: ControllerFrame) -> void:
	if _movement_locked:
		_frame = ControllerFrame.new()
		return
	_frame = frame


func set_ball_follow_target(target: Vector3, speed_multiplier: float = 1.0) -> void:
	_ball_follow_target = Vector3(
		clampf(target.x, min_x, max_x),
		global_position.y,
		clampf(target.z, min_z, max_z)
	)
	_ball_follow_speed_multiplier = clampf(speed_multiplier, 1.0, 1.5)
	_ball_follow_enabled = true


func clear_ball_follow_target() -> void:
	_ball_follow_enabled = false
	_ball_follow_speed_multiplier = 1.0


func set_movement_locked(locked: bool, reset_position: Vector3 = Vector3.ZERO) -> void:
	_movement_locked = locked
	_ball_follow_enabled = false
	_ball_follow_speed_multiplier = 1.0
	_frame = ControllerFrame.new()
	velocity = Vector3.ZERO
	if locked:
		global_position = reset_position


func _physics_process(_delta: float) -> void:
	if _movement_locked:
		velocity = Vector3.ZERO
		return
	if _ball_follow_enabled:
		var follow_error := Vector2(
			_ball_follow_target.x - global_position.x,
			_ball_follow_target.z - global_position.z
		)
		var follow_velocity := follow_error * ball_follow_gain
		var max_follow_speed := ball_follow_speed * _ball_follow_speed_multiplier
		if follow_velocity.length() > max_follow_speed:
			follow_velocity = follow_velocity.normalized() * max_follow_speed
		velocity = Vector3(follow_velocity.x, 0.0, follow_velocity.y)
	else:
		velocity = Vector3(
			_frame.move_x * screen_right_world_sign * move_speed,
			0.0,
			0.0
		)
	move_and_slide()

	var pos := global_position
	pos.x = clampf(pos.x, min_x, max_x)
	pos.z = clampf(pos.z, min_z, max_z)
	global_position = pos


func _process(delta: float) -> void:
	if _model_skeletons.is_empty():
		return
	_animation_time += delta
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var desired_locomotion := clampf(horizontal_speed / maxf(move_speed, 0.1), 0.0, 1.0)
	_locomotion_blend = move_toward(_locomotion_blend, desired_locomotion, delta * 7.0)
	_walk_phase += delta * lerpf(2.2, 8.5, _locomotion_blend)

	var racket_state := int(_racket_controller.get("state"))
	if racket_state == 1 and _previous_racket_state != 1:
		_swing_elapsed = 0.0
		_swing_is_backhand = bool(_racket_controller.get("active_swing_is_backhand"))
	elif racket_state != 0:
		_swing_elapsed += delta
	else:
		_swing_elapsed = 0.5
	_previous_racket_state = racket_state

	_update_model_pose()


func _update_model_pose() -> void:
	var walk_cycle := sin(_walk_phase)
	var stride := walk_cycle * 0.42 * _locomotion_blend
	var recovery_leg := maxf(0.0, -walk_cycle)
	var idle_breath := sin(_animation_time * 1.7)
	var swing_amount := _get_swing_pose_amount()
	var swing_direction := -1.0 if _swing_is_backhand else 1.0

	var idle_bob := idle_breath * 0.014 * (1.0 - _locomotion_blend)
	var walk_bob := absf(sin(_walk_phase * 2.0)) * 0.055 * _locomotion_blend
	_model_root.position = _model_rest_position + Vector3(0.0, idle_bob + walk_bob, 0.0)
	_model_root.rotation = _model_rest_rotation + Vector3(
		0.0,
		0.0,
		idle_breath * 0.012 * (1.0 - _locomotion_blend)
	)

	_set_rig_bone_pose("DEF-thigh.L", Vector3(stride, 0.0, 0.0))
	_set_rig_bone_pose("DEF-thigh.R", Vector3(-stride, 0.0, 0.0))
	_set_rig_bone_pose("DEF-shin.L", Vector3(recovery_leg * 0.48 * _locomotion_blend, 0.0, 0.0))
	_set_rig_bone_pose("DEF-shin.R", Vector3(maxf(0.0, walk_cycle) * 0.48 * _locomotion_blend, 0.0, 0.0))
	_set_rig_bone_pose("DEF-foot.L", Vector3(-recovery_leg * 0.2 * _locomotion_blend, 0.0, 0.0))
	_set_rig_bone_pose("DEF-foot.R", Vector3(-maxf(0.0, walk_cycle) * 0.2 * _locomotion_blend, 0.0, 0.0))
	_set_rig_bone_pose("DEF-toe.L", Vector3(recovery_leg * 0.12 * _locomotion_blend, 0.0, 0.0))
	_set_rig_bone_pose("DEF-toe.R", Vector3(maxf(0.0, walk_cycle) * 0.12 * _locomotion_blend, 0.0, 0.0))
	_set_rig_bone_pose("DEF-spine.003", Vector3(0.0, 0.0, idle_breath * 0.025 + stride * 0.10))
	_set_rig_bone_pose("DEF-upper_arm.L", Vector3(-stride * 0.22, 0.0, -stride * 0.35))
	_set_rig_bone_pose(
		"DEF-upper_arm.R",
		Vector3(
			-stride * 0.12,
			0.0,
			stride * 0.16 + idle_breath * 0.025 + swing_amount * swing_direction * 0.78
		)
	)
	_set_rig_bone_pose("DEF-forearm.L", Vector3(0.0, 0.0, stride * 0.18))
	_set_rig_bone_pose(
		"DEF-forearm.R",
		Vector3(0.0, 0.0, swing_amount * 0.28 * swing_direction)
	)
	for foot_index in _avatar_feet.size():
		var foot_lift := maxf(0.0, walk_cycle if foot_index == 0 else -walk_cycle)
		_avatar_legs[foot_index].position = _leg_rest_positions[foot_index] + Vector3(
			0.0,
			foot_lift * 0.07 * _locomotion_blend,
			absf(stride) * 0.04
		)
		_avatar_feet[foot_index].position = _foot_rest_positions[foot_index] + Vector3(
			0.0,
			foot_lift * 0.14 * _locomotion_blend,
			absf(stride) * 0.04
		)
		_avatar_feet[foot_index].rotation.x = -foot_lift * 0.16 * _locomotion_blend


func _get_swing_pose_amount() -> float:
	if _swing_elapsed >= 0.5:
		return 0.0
	if _swing_elapsed < 0.16:
		return lerpf(0.0, -0.65, _swing_elapsed / 0.16)
	if _swing_elapsed < 0.34:
		return lerpf(-0.65, 1.0, (_swing_elapsed - 0.16) / 0.18)
	return lerpf(1.0, 0.0, (_swing_elapsed - 0.34) / 0.16)


func _set_rig_bone_pose(bone_name: String, euler_rotation: Vector3) -> void:
	var pose_rotation := Quaternion.from_euler(euler_rotation)
	for skeleton_index in _model_skeletons.size():
		var bone_index := int(_skeleton_bone_indices[skeleton_index].get(bone_name, -1))
		if bone_index >= 0:
			var bone_pose := pose_rotation
			if _skeleton_is_mirrored[skeleton_index]:
				bone_pose = Quaternion.from_euler(
					Vector3(euler_rotation.x, -euler_rotation.y, -euler_rotation.z)
				)
			_model_skeletons[skeleton_index].set_bone_pose_rotation(bone_index, bone_pose)
