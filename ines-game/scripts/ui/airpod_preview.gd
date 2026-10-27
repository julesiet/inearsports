extends Node3D

const MOTION_ZONE := Vector3(1.05, 0.72, 0.65)

var _airpod: Node3D
var _target_position := Vector3.ZERO
var _target_rotation := Quaternion.IDENTITY


func _ready() -> void:
	_build_motion_zone()
	_build_airpod()


func _process(delta: float) -> void:
	var offset: Vector3 = ControllerManager.get_racket_offset()
	_target_position = Vector3(
		offset.x / 0.4 * MOTION_ZONE.x,
		offset.y / 0.36 * MOTION_ZONE.y,
		offset.z / 0.35 * MOTION_ZONE.z
	)
	_target_rotation = ControllerManager.get_preview_orientation()
	var blend := 1.0 - exp(-8.0 * delta)
	_airpod.position = _airpod.position.lerp(_target_position, blend)
	_airpod.quaternion = _airpod.quaternion.slerp(_target_rotation, blend)


func _build_motion_zone() -> void:
	var zone := MeshInstance3D.new()
	var immediate_mesh := ImmediateMesh.new()
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var corners: Array[Vector3] = []
	for x in [-MOTION_ZONE.x, MOTION_ZONE.x]:
		for y in [-MOTION_ZONE.y, MOTION_ZONE.y]:
			for z in [-MOTION_ZONE.z, MOTION_ZONE.z]:
				corners.append(Vector3(x, y, z))
	for index in corners.size():
		for other_index in range(index + 1, corners.size()):
			var a := corners[index]
			var b := corners[other_index]
			var different_axes := 0
			if not is_equal_approx(a.x, b.x):
				different_axes += 1
			if not is_equal_approx(a.y, b.y):
				different_axes += 1
			if not is_equal_approx(a.z, b.z):
				different_axes += 1
			if different_axes == 1:
				immediate_mesh.surface_add_vertex(a)
				immediate_mesh.surface_add_vertex(b)
	immediate_mesh.surface_end()
	zone.mesh = immediate_mesh
	var zone_material := StandardMaterial3D.new()
	zone_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	zone_material.albedo_color = Color(0.22, 0.82, 0.9, 0.68)
	zone_material.emission_enabled = true
	zone_material.emission = Color(0.08, 0.3, 0.36)
	zone_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	zone.material_override = zone_material
	add_child(zone)

	var center_marker := MeshInstance3D.new()
	var marker_mesh := SphereMesh.new()
	marker_mesh.radius = 0.045
	marker_mesh.height = 0.09
	center_marker.mesh = marker_mesh
	var marker_material := StandardMaterial3D.new()
	marker_material.albedo_color = Color(0.4, 0.96, 0.52)
	marker_material.emission_enabled = true
	marker_material.emission = Color(0.15, 0.5, 0.2)
	center_marker.material_override = marker_material
	add_child(center_marker)


func _build_airpod() -> void:
	_airpod = Node3D.new()
	add_child(_airpod)
	var white_material := StandardMaterial3D.new()
	white_material.albedo_color = Color(0.94, 0.98, 1.0)
	white_material.metallic = 0.12
	white_material.roughness = 0.28
	var speaker_material := StandardMaterial3D.new()
	speaker_material.albedo_color = Color(0.18, 0.65, 0.78)
	speaker_material.metallic = 0.15

	var earbud := MeshInstance3D.new()
	var shell := SphereMesh.new()
	shell.radius = 0.19
	shell.height = 0.36
	earbud.mesh = shell
	earbud.scale = Vector3(0.82, 1.0, 0.72)
	earbud.material_override = white_material
	_airpod.add_child(earbud)

	var stem := MeshInstance3D.new()
	var stem_mesh := CapsuleMesh.new()
	stem_mesh.radius = 0.065
	stem_mesh.height = 0.43
	stem.mesh = stem_mesh
	stem.position = Vector3(0.02, -0.25, 0.015)
	stem.rotation.z = -0.12
	stem.material_override = white_material
	_airpod.add_child(stem)

	var speaker := MeshInstance3D.new()
	var speaker_mesh := SphereMesh.new()
	speaker_mesh.radius = 0.075
	speaker_mesh.height = 0.15
	speaker.mesh = speaker_mesh
	speaker.scale = Vector3(0.65, 0.65, 0.35)
	speaker.position = Vector3(0.0, -0.37, 0.055)
	speaker.material_override = speaker_material
	_airpod.add_child(speaker)
