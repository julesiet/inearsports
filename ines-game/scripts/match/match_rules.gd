class_name MatchRules
extends Resource

@export_range(1, 99, 1) var points_to_win: int = 5
@export_range(0.1, 20.0, 0.1) var court_half_width: float = 5.4
@export_range(0.1, 30.0, 0.1) var court_half_length: float = 14.4
@export_range(1, 3, 1) var max_bounces: int = 1
@export_range(0.0, 10.0, 0.1) var point_reset_delay_s: float = 1.0
