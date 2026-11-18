class_name CursorStrike
extends Node2D

# Stylized OS mouse cursor that swoops down and strikes a target tab

signal strike_impacted(target: Node)

var target_node: Node = null
var target_pos: Vector2 = Vector2.ZERO
var damage: float = 15.0
var faction: String = "player" # "player" or "rival"
var is_mini: bool = false # Mini cursor strikes used in Refresh Rush

var elapsed: float = 0.0
var strike_duration: float = 0.35
var impacted: bool = false
var ripple_radius: float = 0.0
var ripple_alpha: float = 1.0

func _ready() -> void:
	queue_redraw()

func init_strike(target: Node, dmg: float, p_faction: String, p_is_mini: bool = false) -> void:
	target_node = target
	damage = dmg
	faction = p_faction
	is_mini = p_is_mini
	if is_instance_valid(target):
		target_pos = target.global_position
	# Start slightly above and to the left of the target
	var offset := Vector2(-40.0, -60.0) if not is_mini else Vector2(randf_range(-30, 30), -45.0)
	position = target_pos + offset

func _process(delta: float) -> void:
	elapsed += delta
	if not impacted:
		var t := clampf(elapsed / strike_duration, 0.0, 1.0)
		# Smooth ease-in plunge
		var start_pos := target_pos + (Vector2(-40.0, -60.0) if not is_mini else Vector2(-20.0, -45.0))
		position = start_pos.lerp(target_pos, t * t)
		
		if t >= 1.0:
			_trigger_impact()
	else:
		# Expanding shockwave ripple
		ripple_radius += delta * 120.0
		ripple_alpha = maxf(0.0, ripple_alpha - delta * 3.5)
		queue_redraw()
		if ripple_alpha <= 0.0:
			queue_free()

func _trigger_impact() -> void:
	impacted = true
	var synth := get_node_or_null("/root/AudioSynth")
	if synth:
		synth.play_strike()
	
	if is_instance_valid(target_node) and target_node.has_method("take_damage"):
		target_node.take_damage(damage, faction)
	
	strike_impacted.emit(target_node)
	queue_redraw()

func _draw() -> void:
	var scale_factor: float = 0.7 if is_mini else 1.0
	var col_cursor: Color = Color.WHITE if faction == "player" else Color(1.0, 0.4, 0.4)
	var col_border: Color = Color(0.1, 0.1, 0.1, 0.9)

	# Draw Cursor pointer polygon
	var points := PackedVector2Array([
		Vector2(0, 0) * scale_factor,
		Vector2(0, 16) * scale_factor,
		Vector2(4, 12) * scale_factor,
		Vector2(8, 19) * scale_factor,
		Vector2(11, 18) * scale_factor,
		Vector2(7, 11) * scale_factor,
		Vector2(13, 11) * scale_factor
	])

	draw_colored_polygon(points, col_cursor)
	draw_polyline(points, col_border, 1.5)

	# Shockwave click ring on impact
	if impacted and ripple_alpha > 0.0:
		var ring_col := Color(0.2, 0.9, 1.0, ripple_alpha) if faction == "player" else Color(1.0, 0.2, 0.2, ripple_alpha)
		draw_arc(Vector2.ZERO, ripple_radius, 0, TAU, 24, ring_col, 2.5)
