class_name CursorStrike
extends Node2D

# Giant crisp white/black-outlined OS mouse cursor that swoops down and strikes targets
# with comic-style orange/yellow impact bursts on hit.

signal strike_impacted(target: Node)

var target_node: Node = null
var target_pos: Vector2 = Vector2.ZERO
var damage: float = 15.0
var faction: String = "player" # "player" or "rival"
var is_mini: bool = false # Mini cursor strikes used in Refresh Rush
var is_active_focus: bool = false

var elapsed: float = 0.0
var strike_duration: float = 0.32
var impacted: bool = false
var impact_anim_time: float = 0.0
var impact_duration: float = 0.40

const COLOR_PLAYER := Color(0.25, 0.85, 1.0) # Cyan/Blue
const COLOR_RIVAL := Color(0.95, 0.25, 0.25)  # Crimson
const COLOR_FOCUS := Color(1.0, 0.82, 0.15)  # Gold

func _ready() -> void:
	z_index = 25
	queue_redraw()

func init_strike(target: Node, dmg: float, p_faction: String, p_is_mini: bool = false, p_is_active_focus: bool = false) -> void:
	target_node = target
	damage = dmg
	faction = p_faction
	is_mini = p_is_mini
	is_active_focus = p_is_active_focus
	if is_instance_valid(target):
		target_pos = target.global_position
	# Start above and slightly left
	var offset := Vector2(-50.0, -75.0) if not is_mini else Vector2(randf_range(-30, 30), -50.0)
	position = target_pos + offset
	queue_redraw()

func _process(delta: float) -> void:
	if not impacted:
		elapsed += delta
		var t := clampf(elapsed / strike_duration, 0.0, 1.0)
		var start_pos := target_pos + (Vector2(-50.0, -75.0) if not is_mini else Vector2(-25.0, -50.0))
		position = start_pos.lerp(target_pos, t * t)
		queue_redraw()
		
		if t >= 1.0:
			_trigger_impact()
	else:
		impact_anim_time += delta
		queue_redraw()
		if impact_anim_time >= impact_duration:
			queue_free()

func _trigger_impact() -> void:
	impacted = true
	position = target_pos
	
	var synth := get_node_or_null("/root/AudioSynth")
	if synth:
		synth.play_strike()
	
	if is_instance_valid(target_node) and target_node.has_method("take_damage"):
		target_node.take_damage(damage, faction)
	
	strike_impacted.emit(target_node)
	queue_redraw()

func _draw() -> void:
	var border_col := Color(0.06, 0.09, 0.16) # #0F172A
	var shadow_offset := Vector2(3, 4)

	if not impacted:
		# Draw giant crisp white/black-outlined OS mouse cursor
		var s: float = 1.3 if not is_mini else 0.85
		var pts := PackedVector2Array([
			Vector2(0, 0) * s,
			Vector2(0, 28) * s,
			Vector2(7, 21) * s,
			Vector2(14, 32) * s,
			Vector2(18, 29) * s,
			Vector2(12, 18) * s,
			Vector2(20, 18) * s
		])
		var shadow_pts := PackedVector2Array()
		for pt in pts:
			shadow_pts.append(pt + shadow_offset)

		# Hard drop shadow
		draw_colored_polygon(shadow_pts, border_col)
		# Crisp white cursor body (or modulated if rival)
		var fill_col := Color.WHITE if faction == "player" else Color(1.0, 0.7, 0.7)
		if is_active_focus:
			fill_col = Color(1.0, 0.95, 0.65)
		draw_colored_polygon(pts, fill_col)
		# 3px crisp dark navy border
		for i in range(pts.size()):
			draw_line(pts[i], pts[(i + 1) % pts.size()], border_col, 3.0)
	else:
		# Comic-style orange/yellow impact bursts on hit
		var t := impact_anim_time / impact_duration
		var scale_burst := 1.0 + sin(t * PI) * 0.8
		var alpha := 1.0 - t
		var num_points := 14
		var outer_r := (34.0 if not is_mini else 22.0) * scale_burst
		var inner_r := outer_r * 0.45

		var star_pts := PackedVector2Array()
		var shadow_star := PackedVector2Array()
		for i in range(num_points * 2):
			var angle := i * (TAU / float(num_points * 2))
			var r := outer_r if (i % 2 == 0) else inner_r
			# Slight jitter for comic style
			if i % 4 == 0:
				r *= 1.15
			var pt := Vector2(cos(angle), sin(angle)) * r
			star_pts.append(pt)
			shadow_star.append(pt + shadow_offset)

		# Hard drop shadow
		var shadow_alpha := Color(border_col.r, border_col.g, border_col.b, alpha)
		draw_colored_polygon(shadow_star, shadow_alpha)
		
		# Vibrant orange/yellow fill
		var burst_col := Color(0.99, 0.85, 0.20, alpha) # Yellow #FDE047
		draw_colored_polygon(star_pts, burst_col)
		
		# Inner orange starburst
		var inner_star := PackedVector2Array()
		for pt in star_pts:
			inner_star.append(pt * 0.65)
		draw_colored_polygon(inner_star, Color(0.96, 0.40, 0.10, alpha)) # Orange #F97316

		# 3px dark navy border
		for i in range(star_pts.size()):
			draw_line(star_pts[i], star_pts[(i + 1) % star_pts.size()], shadow_alpha, 3.0)
		
		# Center shockwave ring
		draw_arc(Vector2.ZERO, outer_r * 0.9, 0, TAU, 24, Color(1, 1, 1, alpha * 0.8), 2.5)
