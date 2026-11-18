class_name TriangulationOverlay
extends Node2D

# Visualizer for Tab Bar Triangulation:
# Renders laser beams connecting the 3 tabs of the L-formation
# and displays a central holographic 30-second countdown ring.

var is_active: bool = false
var l_tabs: Array = [] # [Corner, Arm1, Arm2]
var hold_time: float = 0.0
var target_time: float = 30.0

var pulse_time: float = 0.0

func _ready() -> void:
	z_index = 10
	var bm = get_node_or_null("/root/BattleManager")
	if bm:
		bm.triangulation_hold_updated.connect(_on_hold_updated)

func _on_hold_updated(current: float, target: float) -> void:
	hold_time = current
	target_time = target
	queue_redraw()

func set_triangulation(active: bool, tabs: Array) -> void:
	is_active = active
	l_tabs = tabs
	queue_redraw()

func _process(delta: float) -> void:
	if is_active:
		pulse_time += delta * 6.0
		queue_redraw()

func _draw() -> void:
	if not is_active or l_tabs.size() < 3:
		return

	# Verify all tabs are still valid instances
	for t in l_tabs:
		if not is_instance_valid(t):
			return

	var p1: Vector2 = (l_tabs[0] as Node2D).global_position
	var p2: Vector2 = (l_tabs[1] as Node2D).global_position
	var p3: Vector2 = (l_tabs[2] as Node2D).global_position

	var pulse: float = (sin(pulse_time) + 1.0) * 0.5
	var beam_col := Color(0.1, 0.9, 1.0, 0.75 + pulse * 0.25)
	var glow_col := Color(0.2, 0.6, 1.0, 0.35 + pulse * 0.2)

	# Outer glow lines
	draw_line(p1, p2, glow_col, 8.0)
	draw_line(p1, p3, glow_col, 8.0)
	draw_line(p2, p3, glow_col, 4.0) # hypotenuse bracket

	# Core laser lines
	draw_line(p1, p2, beam_col, 3.0)
	draw_line(p1, p3, beam_col, 3.0)
	draw_line(p2, p3, beam_col, 1.5)

	# Holographic center ring between the 3 tabs
	var center := (p1 + p2 + p3) / 3.0
	var ring_radius: float = 28.0
	draw_circle(center, ring_radius + 4.0, Color(0.05, 0.1, 0.15, 0.7))
	draw_arc(center, ring_radius, 0, TAU, 32, beam_col, 2.5)

	# Progress arc
	var progress := clampf(hold_time / target_time, 0.0, 1.0)
	if progress > 0.0:
		draw_arc(center, ring_radius - 4.0, -PI * 0.5, -PI * 0.5 + (TAU * progress), 32, Color(1.0, 0.8, 0.2), 3.5)

	# Hold countdown text
	var remaining: float = maxf(0.0, target_time - hold_time)
	var time_str := "%.1fs" % remaining
	var font := ThemeDB.fallback_font
	draw_string(font, center + Vector2(-16, 4), time_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.WHITE)

	var label_str := "HOLD"
	draw_string(font, center + Vector2(-16, -10), label_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color(0.3, 0.9, 1.0))
