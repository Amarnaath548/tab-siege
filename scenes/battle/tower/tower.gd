class_name TabTower
extends Node2D

# Turret mounted on a TabBase. Fires projectiles at enemy tabs or cursors.
# Supports 4 tiers with scaling combat stats and distinct visual indicators.
# Renders AtlasTexture sprites (turret_t1 .. turret_t4) modulated by faction/focus.

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
var is_active_focused: bool = false

var _sprite: Sprite2D = null
var sprite: Sprite2D:
	get:
		if _sprite == null:
			_setup_sprite()
		return _sprite

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
			_setup_tier_label()
		return _tier_label
	set(val):
		_tier_label = val

const COLOR_PLAYER := Color(0.25, 0.85, 1.0) # Cyan/Blue
const COLOR_RIVAL := Color(0.95, 0.25, 0.25)  # Crimson
const COLOR_FOCUS := Color(1.0, 0.82, 0.15)  # Gold

const ProjectileScene: PackedScene = preload("res://scenes/battle/tower/projectile.tscn")

static func _load_atlas(filename: String) -> Texture2D:
	var paths := [
		"res://assets/sprites/" + filename,
		"res://sprites/" + filename
	]
	for p in paths:
		if ResourceLoader.exists(p):
			return load(p) as Texture2D
	return null

func _enter_tree() -> void:
	_setup_sprite()
	_setup_tier_label()
	_update_tier_stats()
	_update_visuals()

func _ready() -> void:
	_setup_sprite()
	_setup_tier_label()
	_update_tier_stats()
	_update_visuals()
	queue_redraw()

func _setup_sprite() -> void:
	if _sprite == null:
		_sprite = get_node_or_null("Sprite2D") as Sprite2D
		if _sprite == null:
			_sprite = Sprite2D.new()
			_sprite.name = "Sprite2D"
			add_child(_sprite)
	if _sprite != null and _sprite.texture == null:
		_update_visuals()

func set_tier(new_tier: Tier) -> void:
	tier = new_tier
	_update_tier_stats()
	_update_visuals()
	_update_tier_label()
	queue_redraw()
	tower_merged.emit(int(tier))

func set_active_focus(focused: bool) -> void:
	is_active_focused = focused
	_update_visuals()
	_update_tier_label()
	queue_redraw()

func _update_visuals() -> void:
	if _sprite == null:
		_setup_sprite()
	if _sprite == null:
		return

	var tex: Texture2D = null
	match tier:
		Tier.TIER_1:
			tex = _load_atlas("turret_t1.tres")
		Tier.TIER_2:
			tex = _load_atlas("turret_t2.tres")
		Tier.TIER_3:
			tex = _load_atlas("turret_t3.tres")
		Tier.TIER_4:
			tex = _load_atlas("turret_t4.tres")

	if tex != null:
		_sprite.texture = tex
		var max_dim := maxf(tex.get_width(), tex.get_height())
		if max_dim > 0.0:
			var target_size := 26.0 + (int(tier) - 1) * 2.0
			var s := target_size / max_dim
			_sprite.scale = Vector2(s, s)

	# The turret sprite barrel points UP in the atlas sheet.
	# Rotate 90 degrees (PI * 0.5) so it aligns with forward (+X) firing axis.
	_sprite.rotation = PI * 0.5

	# Modulate colors for Player (cyan/blue), Rival (crimson), and Active Focus (gold)
	if faction == "rival":
		_sprite.modulate = COLOR_RIVAL
	elif is_active_focused:
		_sprite.modulate = COLOR_FOCUS
	else:
		_sprite.modulate = COLOR_PLAYER

	_update_tier_label()

func _setup_tier_label() -> void:
	if _tier_label == null:
		_tier_label = get_node_or_null("TierLabel") as Node2D
		if _tier_label == null:
			_tier_label = TierLabel.new()
			add_child(_tier_label)
		_tier_label.position = Vector2(0, -15)
	_update_tier_label()

func _update_tier_label() -> void:
	if _tier_label == null:
		return
	if "text" in _tier_label:
		_tier_label.text = "T%d" % int(tier)
	var badge_col := COLOR_RIVAL if faction == "rival" else (COLOR_FOCUS if is_active_focused else COLOR_PLAYER)
	if _tier_label.has_method("add_theme_color_override"):
		_tier_label.add_theme_color_override("font_color", badge_col)

func _process(_delta: float) -> void:
	if _tier_label != null and is_instance_valid(_tier_label):
		_tier_label.global_rotation = 0.0
		_tier_label.global_position = global_position + Vector2(0, -15)

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
		if _tier_label != null and is_instance_valid(_tier_label):
			_tier_label.global_rotation = 0.0
			_tier_label.global_position = global_position + Vector2(0, -15)
		
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
	# Tier badge is rendered upright via tier_label Label node
	pass
