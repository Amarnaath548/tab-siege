class_name TabTower
extends Node2D

# Turret mounted on a TabBase.
# Implements 3 distinct towers with procedural vector icons & badges:
# 1. Ad-Blocker (Red Octagon / X shield): Fast single-target projectile tower.
# 2. Firewall (Orange Flame shield): Short-range AoE pulse that slows enemy swarms.
# 3. Cache Cannon (Blue Lightning bolt): Long-range sniper targeting high-HP rival tabs.
# Supports 4 tiers with cascade merging and 3px dark navy outlines with hard drop shadows.

signal tower_fired()
signal tower_merged(new_tier: int)

enum Tier {
	TIER_1 = 1,
	TIER_2 = 2,
	TIER_3 = 3,
	TIER_4 = 4
}

enum TowerType {
	AD_BLOCKER,
	FIREWALL,
	CACHE_CANNON
}

@export var tier: Tier = Tier.TIER_1
@export var tower_type: TowerType = TowerType.AD_BLOCKER

var faction: String = "player" # "player" or "rival"
var target_tab: Node2D = null

var fire_timer: float = 0.0
var base_fire_interval: float = 0.65
var base_damage: float = 14.0
var attack_range: float = 380.0
var is_active_focused: bool = false

# Firewall pulse visual
var pulse_anim_radius: float = 0.0
var pulse_anim_alpha: float = 0.0

const COLOR_PLAYER := Color(0.25, 0.85, 1.0) # Cyan/Blue
const COLOR_RIVAL := Color(0.95, 0.25, 0.25)  # Crimson
const COLOR_FOCUS := Color(1.0, 0.82, 0.15)  # Gold

class TierLabel extends Node2D:
	var label: Label = null
	
	var text: String:
		get:
			return label.text if label else ""
		set(v):
			if label:
				label.text = v
	
	func _init() -> void:
		name = "TierLabel"
		label = Label.new()
		label.name = "Label"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 9)
		label.size = Vector2(24, 14)
		label.position = Vector2(-12, -7)
		add_child(label)
		z_index = 2
	
	func add_theme_color_override(prop: String, col: Color) -> void:
		if label:
			label.add_theme_color_override(prop, col)

var _tier_label: Node2D = null
var tier_label: Node2D:
	get:
		if _tier_label == null:
			_tier_label = TierLabel.new()
			add_child(_tier_label)
			_tier_label.position = Vector2(0, -15)
		return _tier_label
	set(val):
		_tier_label = val

const ProjectileScene: PackedScene = preload("res://scenes/battle/tower/projectile.tscn")

func _ready() -> void:
	if tier_label:
		tier_label.text = "T%d" % int(tier)
	_update_tower_stats()
	queue_redraw()

func _process(_delta: float) -> void:
	if _tier_label != null and is_instance_valid(_tier_label):
		_tier_label.global_rotation = 0.0
		_tier_label.global_position = global_position + Vector2(0, -15)

func set_tier(new_tier: Tier) -> void:
	tier = new_tier
	if tier_label:
		tier_label.text = "T%d" % int(tier)
	match tier:
		Tier.TIER_1, Tier.TIER_2:
			tower_type = TowerType.AD_BLOCKER
		Tier.TIER_3:
			tower_type = TowerType.FIREWALL
		Tier.TIER_4:
			tower_type = TowerType.CACHE_CANNON
	_update_tower_stats()
	queue_redraw()
	tower_merged.emit(int(tier))

func set_tower_type(new_type: TowerType) -> void:
	tower_type = new_type
	_update_tower_stats()
	queue_redraw()

func set_active_focus(focused: bool) -> void:
	is_active_focused = focused
	queue_redraw()

func _update_tower_stats() -> void:
	match tower_type:
		TowerType.AD_BLOCKER:
			base_damage = 12.0 * float(tier)
			base_fire_interval = maxf(0.25, 0.60 / float(tier))
			attack_range = 380.0
		TowerType.FIREWALL:
			base_damage = 25.0 * float(tier)
			base_fire_interval = 1.30
			attack_range = 220.0
		TowerType.CACHE_CANNON:
			base_damage = 50.0 * float(tier)
			base_fire_interval = 1.80
			attack_range = 580.0

func get_cost() -> int:
	match tier:
		Tier.TIER_1: return 20
		Tier.TIER_2: return 45
		Tier.TIER_3: return 90
		Tier.TIER_4: return 180
	return 20

func can_merge_with(other: TabTower) -> bool:
	return other != null and other != self and other.tier == tier and int(tier) < int(Tier.TIER_4)

func merge_upgrade() -> bool:
	if int(tier) < int(Tier.TIER_4):
		set_tier((int(tier) + 1) as Tier)
		var synth := get_node_or_null("/root/AudioSynth")
		if synth:
			synth.play_merge()
		return true
	return false

func process_firing(delta: float, fire_rate_multiplier: float, can_fire: bool) -> void:
	# Animate Firewall pulse ring if active
	if pulse_anim_alpha > 0.0:
		pulse_anim_radius += delta * 240.0
		pulse_anim_alpha = maxf(0.0, pulse_anim_alpha - delta * 2.8)
		queue_redraw()

	if not can_fire or fire_rate_multiplier <= 0.0:
		return

	if tower_type == TowerType.FIREWALL:
		# Firewall pulses AoE around tab
		fire_timer += delta
		var effective_interval := base_fire_interval / fire_rate_multiplier
		if fire_timer >= effective_interval:
			fire_timer = 0.0
			_execute_firewall_pulse()
		return

	_acquire_target()
	
	if target_tab != null and is_instance_valid(target_tab):
		# Look at target
		var dir: Vector2 = (target_tab.global_position - global_position).normalized()
		rotation = lerp_angle(rotation, dir.angle(), delta * 12.0)
		
		# Tick fire timer
		var effective_interval := base_fire_interval / fire_rate_multiplier
		fire_timer += delta
		if fire_timer >= effective_interval:
			fire_timer = 0.0
			_fire_projectile()
	else:
		fire_timer = 0.0

func _execute_firewall_pulse() -> void:
	pulse_anim_radius = 16.0
	pulse_anim_alpha = 1.0
	queue_redraw()

	var synth := get_node_or_null("/root/AudioSynth")
	if synth:
		synth.play_strike()

	# Damage & slow enemy units and tabs in range
	if faction == "player":
		var enemies = get_tree().get_nodes_in_group("enemies")
		for e in enemies:
			if is_instance_valid(e) and global_position.distance_to(e.global_position) <= attack_range:
				if e.has_method("take_damage"):
					e.take_damage(base_damage, "player")
				if e.has_method("apply_slow"):
					e.apply_slow(2.0)
		
		var rival_tabs = get_tree().get_nodes_in_group("tabs").filter(
			func(t): return is_instance_valid(t) and t.has_method("is_rival") and t.is_rival() and t.is_alive()
		)
		for rt in rival_tabs:
			if global_position.distance_to(rt.global_position) <= attack_range:
				rt.take_damage(base_damage * 0.6, "player")

	tower_fired.emit()

func _acquire_target() -> void:
	if target_tab != null and is_instance_valid(target_tab):
		if target_tab.has_method("is_alive") and not target_tab.is_alive():
			target_tab = null
		elif global_position.distance_to(target_tab.global_position) > attack_range:
			target_tab = null

	if target_tab == null:
		# If Cache Cannon: sniper targeting highest HP rival tab or brute
		if tower_type == TowerType.CACHE_CANNON and faction == "player":
			var candidate_tabs := get_tree().get_nodes_in_group("tabs").filter(
				func(t): return is_instance_valid(t) and t.has_method("is_rival") and t.is_rival() and t.is_alive()
			)
			var max_hp_val := -1.0
			for t in candidate_tabs:
				if global_position.distance_to(t.global_position) <= attack_range:
					if t.current_hp > max_hp_val:
						max_hp_val = t.current_hp
						target_tab = t
			if target_tab != null:
				return

		# First check enemy bots if player
		if faction == "player":
			var enemies = get_tree().get_nodes_in_group("enemies").filter(
				func(e): return is_instance_valid(e) and e.current_hp > 0.0
			)
			var closest_enemy_dist := attack_range
			for e in enemies:
				var d = global_position.distance_to(e.global_position)
				if d < closest_enemy_dist:
					closest_enemy_dist = d
					target_tab = e
			if target_tab != null:
				return

		# Otherwise target opposing tabs
		var candidate_tabs := get_tree().get_nodes_in_group("tabs")
		var closest_dist := attack_range
		for tab in candidate_tabs:
			if not is_instance_valid(tab):
				continue
			var is_enemy := false
			if faction == "player" and tab.has_method("is_rival") and tab.is_rival():
				is_enemy = true
			elif faction == "rival" and tab.has_method("is_player") and tab.is_player():
				is_enemy = true
			
			if is_enemy and tab.has_method("is_alive") and tab.is_alive():
				var d: float = global_position.distance_to((tab as Node2D).global_position)
				if d < closest_dist:
					closest_dist = d
					target_tab = tab as Node2D

func _fire_projectile() -> void:
	if target_tab == null or not is_instance_valid(target_tab):
		return
	
	var proj: Projectile = ProjectileScene.instantiate()
	var spawn_pos := global_position + Vector2(cos(rotation), sin(rotation)) * 14.0
	proj.init_projectile(spawn_pos, target_tab, base_damage, faction)
	
	get_tree().current_scene.add_child(proj)
	tower_fired.emit()

func _draw() -> void:
	var border_col := Color(0.06, 0.09, 0.16) # #0F172A
	var shadow_offset := Vector2(3, 4)

	# Firewall Pulse shockwave
	if pulse_anim_alpha > 0.0:
		var p_col := Color(0.98, 0.45, 0.09, pulse_anim_alpha) # Orange flame #F97316
		draw_arc(Vector2.ZERO, pulse_anim_radius, 0, TAU, 32, p_col, 3.5)

	# Distinct Procedural Vector Badges
	match tower_type:
		TowerType.AD_BLOCKER:
			# Red Octagon / X Shield
			var r := 15.0
			var shadow_pts := PackedVector2Array()
			var pts := PackedVector2Array()
			for i in range(8):
				var angle := i * (TAU / 8.0) + (PI / 8.0)
				var pt := Vector2(cos(angle), sin(angle)) * r
				pts.append(pt)
				shadow_pts.append(pt + shadow_offset)
			
			# Hard drop shadow
			draw_colored_polygon(shadow_pts, border_col)
			# Solid Red fill (#EF4444)
			draw_colored_polygon(pts, Color(0.94, 0.27, 0.27))
			# 3px dark navy border
			for i in range(pts.size()):
				draw_line(pts[i], pts[(i + 1) % pts.size()], border_col, 3.0)
			
			# Center white 'X'
			draw_line(Vector2(-5, -5), Vector2(5, 5), Color.WHITE, 2.5)
			draw_line(Vector2(5, -5), Vector2(-5, 5), Color.WHITE, 2.5)

		TowerType.FIREWALL:
			# Orange Flame Shield
			var r := 16.0
			# Hard shadow
			draw_circle(shadow_offset, r, border_col)
			# Orange solid fill (#F97316)
			draw_circle(Vector2.ZERO, r, Color(0.98, 0.45, 0.09))
			draw_arc(Vector2.ZERO, r, 0, TAU, 32, border_col, 3.0)
			
			# Inner Flame teardrop
			var flame_pts := PackedVector2Array([
				Vector2(0, -9),
				Vector2(6, 2),
				Vector2(4, 7),
				Vector2(-4, 7),
				Vector2(-6, 2)
			])
			draw_colored_polygon(flame_pts, Color(0.99, 0.88, 0.28)) # Yellow #FDE047
			for i in range(flame_pts.size()):
				draw_line(flame_pts[i], flame_pts[(i + 1) % flame_pts.size()], border_col, 1.5)

		TowerType.CACHE_CANNON:
			# Blue Lightning Bolt Sniper
			var r := 16.0
			# Hard shadow
			draw_circle(shadow_offset, r, border_col)
			# Blue solid fill (#2563EB)
			draw_circle(Vector2.ZERO, r, Color(0.15, 0.39, 0.92))
			draw_arc(Vector2.ZERO, r, 0, TAU, 32, border_col, 3.0)
			
			# Yellow/White Lightning bolt
			var bolt_pts := PackedVector2Array([
				Vector2(2, -9),
				Vector2(-6, 0),
				Vector2(0, 1),
				Vector2(-3, 9),
				Vector2(6, -1),
				Vector2(0, -2)
			])
			draw_colored_polygon(bolt_pts, Color(0.99, 0.90, 0.20))
			for i in range(bolt_pts.size()):
				draw_line(bolt_pts[i], bolt_pts[(i + 1) % bolt_pts.size()], border_col, 1.5)

	# Tier pill badge in corner
	var font := ThemeDB.fallback_font
	var pill_pos := Vector2(-12, -22)
	var pill_box := Rect2(pill_pos, Vector2(24, 14))
	draw_rect(Rect2(pill_box.position + Vector2(2, 2), pill_box.size), border_col, true)
	var badge_col := Color(0.96, 0.62, 0.04) if is_active_focused else (Color(0.25, 0.85, 1.0) if faction == "player" else Color(0.95, 0.25, 0.25))
	draw_rect(pill_box, badge_col, true)
	draw_rect(pill_box, border_col, false, 2.0)
	draw_string(font, pill_pos + Vector2(5, 11), "T%d" % int(tier), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.06, 0.09, 0.16))
