class_name DesktopBackdrop
extends Control

# DesktopBackdrop: Vibrant colorful geometric indigo/teal desktop wallpaper
# with decorative floating mini-windows and bookmark ribbons.

func _ready() -> void:
	custom_minimum_size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	var vp := size
	if vp.x <= 0 or vp.y <= 0:
		vp = Vector2(1280, 720)
	
	# Base deep indigo wallpaper (#1E1B4B)
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.12, 0.11, 0.29), true)
	
	# Geometric polygonal accents across the desktop
	# Large teal polygonal beam (#0D9488 / #14B8A6)
	var teal_poly := PackedVector2Array([
		Vector2(0, 0),
		Vector2(vp.x * 0.45, 0),
		Vector2(vp.x * 0.15, vp.y),
		Vector2(0, vp.y)
	])
	draw_colored_polygon(teal_poly, Color(0.05, 0.58, 0.53, 0.35))
	
	# Angled indigo/violet accent (#4F46E5)
	var indigo_poly := PackedVector2Array([
		Vector2(vp.x * 0.4, 0),
		Vector2(vp.x * 0.65, 0),
		Vector2(vp.x * 0.35, vp.y),
		Vector2(vp.x * 0.1, vp.y)
	])
	draw_colored_polygon(indigo_poly, Color(0.31, 0.27, 0.90, 0.28))

	# Soft warm geometric accent on bottom-right (#0284C7)
	var blue_poly := PackedVector2Array([
		Vector2(vp.x * 0.7, vp.y),
		Vector2(vp.x, vp.y * 0.35),
		Vector2(vp.x, vp.y),
	])
	draw_colored_polygon(blue_poly, Color(0.01, 0.52, 0.78, 0.22))

	# Subtle geometric background grid pattern
	var grid_color := Color(1.0, 1.0, 1.0, 0.04)
	for x in range(0, int(vp.x), 40):
		draw_line(Vector2(x, 0), Vector2(x, vp.y), grid_color, 1.0)
	for y in range(0, int(vp.y), 40):
		draw_line(Vector2(0, y), Vector2(vp.x, y), grid_color, 1.0)

	# Decorative bookmark ribbons
	_draw_ribbon(Vector2(20, 100), 28, 55, Color(0.96, 0.62, 0.04)) # Amber #F59E0B
	_draw_ribbon(Vector2(235, 100), 24, 45, Color(0.92, 0.28, 0.60)) # Pink #EC4899
	_draw_ribbon(Vector2(1015, 100), 28, 50, Color(0.06, 0.73, 0.51)) # Emerald #10B981
	_draw_ribbon(Vector2(1230, 100), 24, 48, Color(0.02, 0.71, 0.83)) # Cyan #06B6D4

	# Decorative floating mini-windows
	_draw_mini_window(
		Rect2(32, 140, 220, 150),
		"system_status.log",
		Color(0.95, 0.96, 0.98),
		[
			"> ping gateway 127.0.0.1",
			"> tab-fold engine: ACTIVE",
			"> triangulation hold: 30s",
			"> packets: 0 dropped [OK]"
		]
	)

	_draw_mini_window(
		Rect2(36, 360, 215, 160),
		"downloads.tar.gz",
		Color(0.95, 0.96, 0.98),
		[
			"Downloading extensions...",
			"[=============>    ] 74%",
			"speed: 12.4 MB/s",
			"ad_blocker_v2.crx"
		]
	)

	_draw_mini_window(
		Rect2(1025, 140, 225, 150),
		"network_monitor",
		Color(0.95, 0.96, 0.98),
		[
			"Rival traffic detected!",
			"Pop-Up Swarms incoming",
			"Cookie Trackers active",
			"Deploy Ad-Blockers now!"
		]
	)

	_draw_sticky_note(
		Rect2(1035, 360, 210, 160),
		"tactics_memo.txt",
		Color(0.99, 0.96, 0.68), # Soft yellow sticky note
		[
			"★ TACTICS HINT ★",
			"1. Form L-shape with 3 tabs",
			"2. Hold for 30s to Triangulate",
			"3. Double-click for Refresh",
			"4. X button: Sacrifice Shield"
		]
	)

func _draw_ribbon(pos: Vector2, w: float, h: float, col: Color) -> void:
	var shadow_offset := Vector2(3, 4)
	var pts := PackedVector2Array([
		pos,
		pos + Vector2(w, 0),
		pos + Vector2(w, h),
		pos + Vector2(w * 0.5, h - 10),
		pos + Vector2(0, h)
	])
	var shadow_pts := PackedVector2Array()
	for pt in pts:
		shadow_pts.append(pt + shadow_offset)
	
	# Hard shadow
	draw_colored_polygon(shadow_pts, Color(0.06, 0.09, 0.16, 0.9))
	# Fill
	draw_colored_polygon(pts, col)
	# 3px dark navy border
	for i in range(pts.size()):
		var p1 = pts[i]
		var p2 = pts[(i + 1) % pts.size()]
		draw_line(p1, p2, Color(0.06, 0.09, 0.16), 3.0)

func _draw_mini_window(rect: Rect2, title: String, bg_col: Color, lines: Array) -> void:
	var shadow_rect := Rect2(rect.position + Vector2(3, 4), rect.size)
	# Hard shadow
	draw_rect(shadow_rect, Color(0.06, 0.09, 0.16), true)
	# Body fill
	draw_rect(rect, bg_col, true)
	# 3px dark navy border
	draw_rect(rect, Color(0.06, 0.09, 0.16), false, 3.0)
	
	# Title bar
	var bar_h := 24.0
	var bar_rect := Rect2(rect.position, Vector2(rect.size.x, bar_h))
	draw_rect(bar_rect, Color(0.85, 0.88, 0.92), true)
	draw_line(
		Vector2(rect.position.x, rect.position.y + bar_h),
		Vector2(rect.position.x + rect.size.x, rect.position.y + bar_h),
		Color(0.06, 0.09, 0.16),
		2.0
	)
	
	# Traffic dots
	var dot_y := rect.position.y + bar_h * 0.5
	draw_circle(Vector2(rect.position.x + 10, dot_y), 3.5, Color(0.94, 0.27, 0.27))
	draw_circle(Vector2(rect.position.x + 20, dot_y), 3.5, Color(0.96, 0.62, 0.04))
	draw_circle(Vector2(rect.position.x + 30, dot_y), 3.5, Color(0.06, 0.73, 0.51))
	
	# Title
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(rect.position.x + 40, rect.position.y + 16), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.18, 0.22, 0.29))
	
	# Body content
	var cur_y := rect.position.y + bar_h + 18.0
	for line in lines:
		draw_string(font, Vector2(rect.position.x + 10, cur_y), str(line), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.3, 0.35, 0.45))
		cur_y += 18.0

func _draw_sticky_note(rect: Rect2, title: String, bg_col: Color, lines: Array) -> void:
	var shadow_rect := Rect2(rect.position + Vector2(3, 4), rect.size)
	# Hard shadow
	draw_rect(shadow_rect, Color(0.06, 0.09, 0.16), true)
	# Body fill
	draw_rect(rect, bg_col, true)
	# 3px dark navy border
	draw_rect(rect, Color(0.06, 0.09, 0.16), false, 3.0)
	
	# Tape piece at top
	var tape_rect := Rect2(rect.position.x + rect.size.x * 0.5 - 25, rect.position.y - 6, 50, 12)
	draw_rect(tape_rect, Color(1.0, 1.0, 1.0, 0.6), true)
	draw_rect(tape_rect, Color(0.06, 0.09, 0.16), false, 1.5)
	
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(rect.position.x + 10, rect.position.y + 22), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.45, 0.35, 0.05))
	
	var cur_y := rect.position.y + 44.0
	for line in lines:
		draw_string(font, Vector2(rect.position.x + 10, cur_y), str(line), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.35, 0.30, 0.10))
		cur_y += 20.0
