class_name BallSimulator
extends Node3D

signal ground_bounced(at_position: Vector3)
signal net_hit(at_position: Vector3)

@export var gravity: float = 9.8
@export var ball_radius: float = 0.10
@export var ground_y: float = 0.0
@export var bounce_factor: float = 0.72

@export var net_z: float = 0.0
@export var net_half_width: float = 4.5
@export var net_bottom_y: float = 0.0
@export var net_top_y: float = 1.0
@export var net_rebound: float = 0.25

var velocity: Vector3 = Vector3.ZERO
var curve_acceleration: float = 0.0
@export var active: bool = true
var previous_position: Vector3

@onready var ball_trail: GPUParticles3D = $VisualRoot/BallTrail
@onready var ball_shadow: MeshInstance3D = $VisualRoot/BallShadow

func _ready() -> void:
	previous_position = global_position
	ball_trail.emitting = active
	ball_trail.process_material = ball_trail.process_material.duplicate()
	_update_visual_effects()


func _process(_delta: float) -> void:
	_update_visual_effects()


func _update_visual_effects() -> void:
	ball_trail.emitting = active and velocity.length_squared() > 0.0001
	if ball_trail.emitting:
		var trail_material := ball_trail.process_material as ParticleProcessMaterial
		trail_material.direction = -velocity.normalized()

	var shadow_y := ground_y + ball_radius + 0.002
	ball_shadow.position = Vector3(0.0, shadow_y - global_position.y, 0.0)
	var height_above_ground := maxf(global_position.y - shadow_y, 0.0)
	var shadow_scale := 1.0 + minf(height_above_ground * 0.25, 1.2)
	ball_shadow.scale = Vector3(shadow_scale, 1.0, shadow_scale)

func launch(start_position: Vector3, start_velocity: Vector3) -> void:
	global_position = start_position
	previous_position = start_position
	velocity = start_velocity
	curve_acceleration = 0.0
	active = true


func stop() -> void:
	active = false
	velocity = Vector3.ZERO


func _physics_process(delta: float) -> void:
	previous_position = global_position
	if not active:
		return

	var previous := global_position
	velocity.y -= gravity * delta
	velocity.x += curve_acceleration * delta
	var next := previous + velocity * delta

	# Check the whole step across the net plane so a fast ball can't skip it.
	var z_step := next.z - previous.z
	if absf(z_step) > 0.000001:
		var crossed_net := (previous.z - net_z) * (next.z - net_z) <= 0.0
		if crossed_net:
			var t := (net_z - previous.z) / z_step
			if t >= 0.0 and t <= 1.0:
				var crossing := previous.lerp(next, t)
				var overlaps_net_height := (
					crossing.y + ball_radius >= net_bottom_y
					and crossing.y - ball_radius <= net_top_y
				)
				if absf(crossing.x) <= net_half_width and overlaps_net_height:
					net_hit.emit(crossing)
					print("Net hit at: ", crossing)
					next = crossing
					next.z = net_z + signf(previous.z - net_z) * (ball_radius + 0.001)
					velocity.z = -velocity.z * net_rebound

	# Detect the ball crossing the floor between physics frames.
	var ball_bottom := ground_y + ball_radius
	if previous.y > ball_bottom and next.y <= ball_bottom and velocity.y < 0.0:
		var fraction := (previous.y - ball_bottom) / (previous.y - next.y)
		next = previous.lerp(next, clampf(fraction, 0.0, 1.0))
		next.y = ball_bottom
		velocity.y = absf(velocity.y) * bounce_factor
		ground_bounced.emit(next)
		print("Ground bounce at: ", next)

	global_position = next

func set_velocity(new_velocity: Vector3) -> void:
	velocity = new_velocity
	curve_acceleration = 0.0
	active = true
	previous_position = global_position


func set_curve_acceleration(value: float) -> void:
	curve_acceleration = clampf(value, -2.5, 2.5)
