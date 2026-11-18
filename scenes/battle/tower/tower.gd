class_name TabTower
extends Node2D

# Turret mounted on a TabBase. Fires projectiles at enemy tabs or cursors.
# Supports 4 tiers with scaling combat stats and distinct visual indicators.

signal tower_fired()
signal tower_merged(new_tier: int)

enum Tier {
	TIER_1 = 1,
	TIER_2 = 2,
	TIER_3 = 3,
	TIER_4 = 4
}

@export var tier: Tier = Tier.TIER_1
var faction: String = "player" # "player" or "rival"
var target_tab: Node2D = null

var fire_timer: float = 0.0
var base_fire_interval: float = 1.2
var base_damage: float = 12.0
var attack_range: float = 380.0

const ProjectileScene: PackedScene = preload("res://scenes/battle/tower/projectile.tscn")

func _ready() -> void:
	_update_tier_stats()
	queue_redraw()

func set_tier(new_tier: Tier) -> void:
	tier = new_tier
	_update_tier_stats()
	queue_redraw()
	tower_merged.emit(int(tier))

func _update_tier_stats() -> void:
	match tier:
		Tier.TIER_1:
			base_damage = 12.0
			base_fire_interval = 1.2
		Tier.TIER_2:
			base_damage = 26.0
			base_fire_interval = 0.85
		Tier.TIER_3:
			base_damage = 55.0
			base_fire_interval = 0.55
		Tier.TIER_4:
			base_damage = 125.0
			base_fire_interval = 0.32

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
	if not can_fire or fire_rate_multiplier <= 0.0:
		return

	_acquire_target()
	
	if target_tab != null and is_instance_valid(target_tab):
		# Look at target
		var dir: Vector2 = (target_tab.global_position - global_position).normalized()
		rotation = lerp_angle(rotation, dir.angle(), delta * 10.0)
		
		# Tick fire timer
		var effective_interval := base_fire_interval / fire_rate_multiplier
		fire_timer += delta
		if fire_timer >= effective_interval:
			fire_timer = 0.0
			_fire_projectile()
	else:
		fire_timer = 0.0

func _acquire_target() -> void:
	if target_tab != null and is_instance_valid(target_tab):
		if target_tab.has_method("is_alive") and not target_tab.is_alive():
			target_tab = null
		elif global_position.distance_to(target_tab.global_position) > attack_range:
			target_tab = null

	if target_tab == null:
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
	
	# Add to main battle arena
	get_tree().current_scene.add_child(proj)
	tower_fired.emit()

func _draw() -> void:
	var base_col: Color
	var barrel_col: Color
	var accent_col: Color

	match tier:
		Tier.TIER_1:
			base_col = Color(0.2, 0.4, 0.7) if faction == "player" else Color(0.7, 0.25, 0.25)
			barrel_col = Color(0.7, 0.85, 1.0) if faction == "player" else Color(1.0, 0.6, 0.6)
			accent_col = Color(0.25, 0.85, 1.0)
		Tier.TIER_2:
			base_col = Color(0.15, 0.52, 0.42) if faction == "player" else Color(0.75, 0.35, 0.2)
			barrel_col = Color(0.45, 0.95, 0.7) if faction == "player" else Color(1.0, 0.7, 0.5)
			accent_col = Color(0.2, 1.0, 0.5)
		Tier.TIER_3:
			base_col = Color(0.65, 0.48, 0.12) if faction == "player" else Color(0.85, 0.4, 0.1)
			barrel_col = Color(1.0, 0.88, 0.35) if faction == "player" else Color(1.0, 0.8, 0.4)
			accent_col = Color(1.0, 0.85, 0.1)
		Tier.TIER_4:
			base_col = Color(0.55, 0.15, 0.65) if faction == "player" else Color(0.85, 0.15, 0.45)
			barrel_col = Color(1.0, 0.4, 0.95) if faction == "player" else Color(1.0, 0.4, 0.7)
			accent_col = Color(0.9, 0.2, 1.0)

	# Tier 4 outer glow ring
	if tier == Tier.TIER_4:
		draw_circle(Vector2.ZERO, 12.0, Color(accent_col.r, accent_col.g, accent_col.b, 0.25))

	# Turret circle body
	draw_circle(Vector2.ZERO, 9.0, base_col)
	draw_circle(Vector2.ZERO, 7.0, Color(0.12, 0.16, 0.22))

	# Barrel(s)
	match tier:
		Tier.TIER_1:
			draw_rect(Rect2(Vector2(0, -2.5), Vector2(11, 5)), barrel_col, true)
		Tier.TIER_2:
			draw_rect(Rect2(Vector2(0, -4.5), Vector2(11, 3.5)), barrel_col, true)
			draw_rect(Rect2(Vector2(0, 1.0), Vector2(11, 3.5)), barrel_col, true)
		Tier.TIER_3:
			draw_rect(Rect2(Vector2(0, -5.5), Vector2(12, 3)), barrel_col, true)
			draw_rect(Rect2(Vector2(0, -1.5), Vector2(13, 3)), accent_col, true)
			draw_rect(Rect2(Vector2(0, 2.5), Vector2(12, 3)), barrel_col, true)
		Tier.TIER_4:
			draw_rect(Rect2(Vector2(0, -6), Vector2(13, 2.5)), barrel_col, true)
			draw_rect(Rect2(Vector2(0, -2), Vector2(15, 4)), accent_col, true)
			draw_rect(Rect2(Vector2(0, 3.5), Vector2(13, 2.5)), barrel_col, true)

	# Distinct text label T1, T2, T3, T4 above the turret for instant top-down readability
	var font := ThemeDB.fallback_font
	var tier_label_str := "T%d" % int(tier)
	draw_string(font, Vector2(-6, -10), tier_label_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 9, accent_col)
