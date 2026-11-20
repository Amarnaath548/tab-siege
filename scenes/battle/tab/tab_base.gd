class_name TabBase
extends Node2D

# TabBase: The core interactive browser tab base on the grid.
# Supports Drag Relocation (Manhattan range <= 4, 15s pin cooldown, 3s inert),
# Refresh Rush (double click, 5 cursor strikes, 2s enemy capture pause, 4s coin penalty, 30s cd),
# Active Tab Focus (single click, +50% fire & coin boost, bold ring, 1s transition),
# and Close Tab Sacrifice Shield ('X' button, 50% refund, 4s neighbor shield).

signal tab_clicked(tab: TabBase)
signal tab_double_clicked(tab: TabBase)
signal tab_sacrificed(tab: TabBase)
signal tab_captured(tab: TabBase, new_faction: String)

enum Faction {
	PLAYER,
	RIVAL,
	NEUTRAL
}

@export var faction: Faction = Faction.PLAYER
@export var tab_title: String = "Tab #1"
@export var max_hp: float = 100.0

var current_hp: float = 100.0
var is_active_focused: bool = false

# Drag state with 8-pixel deadzone
var is_dragging: bool = false
var drag_start_mouse_pos: Vector2 = Vector2.ZERO
var drag_offset: Vector2 = Vector2.ZERO
var original_grid_pos: Vector2i = Vector2i.ZERO
const DRAG_DEADZONE: float = 8.0

# Timers
var inert_timer: float = 0.0 # 3s inert after relocation
var drag_cooldown_timer: float = 0.0 # 15s cooldown per tab (flat pin icon)
var refresh_cooldown_timer: float = 0.0 # 30s cooldown per tab
var refresh_coin_penalty_timer: float = 0.0 # 4s no coin generation after refresh
var shield_timer: float = 0.0 # 4s sacrifice shield invulnerability
var enemy_capture_pause_timer: float = 0.0 # 2s pause when refreshed under attack

# Double click tracking
var last_click_time: float = -10.0
const DOUBLE_CLICK_WINDOW: float = 0.35

# Attached towers
var towers: Array[TabTower] = []
const MAX_TOWERS: int = 4

# Refresh Rush strike burst queue
var pending_refresh_strikes: int = 0
var refresh_strike_interval: float = 0.4
var refresh_strike_timer: float = 0.0
var _hit_flash_tween: Tween = null

# Node references
var grid_manager: GridManager = null
const CursorStrikeScene: PackedScene = preload("res://scenes/battle/cursor_strike/cursor_strike.tscn")
const TowerScene: PackedScene = preload("res://scenes/battle/tower/tower.tscn")

var _pin_sprite: Sprite2D = null
var pin_sprite: Sprite2D:
	get:
		if _pin_sprite == null:
			_setup_sprites()
		return _pin_sprite

var _shield_sprite: Sprite2D = null
var shield_sprite: Sprite2D:
	get:
		if _shield_sprite == null:
			_setup_sprites()
		return _shield_sprite

const COLOR_PLAYER := Color(0.25, 0.85, 1.0) # Cyan/Blue
const COLOR_RIVAL := Color(0.95, 0.25, 0.25)  # Crimson
const COLOR_FOCUS := Color(1.0, 0.82, 0.15)  # Gold

static func _load_atlas(filename: String) -> Texture2D:
	var paths := [
		"res://assets/sprites/" + filename,
		"res://sprites/" + filename
	]
	for p in paths:
		if ResourceLoader.exists(p):
			return load(p) as Texture2D
	return null

func _setup_sprites() -> void:
	if _pin_sprite == null:
		_pin_sprite = get_node_or_null("PinSprite") as Sprite2D
		if _pin_sprite == null:
			_pin_sprite = Sprite2D.new()
			_pin_sprite.name = "PinSprite"
			add_child(_pin_sprite)
		var pin_tex := _load_atlas("pin_icon.tres")
		if pin_tex != null:
			_pin_sprite.texture = pin_tex
			var max_dim := maxf(pin_tex.get_width(), pin_tex.get_height())
			if max_dim > 0.0:
				var s := 22.0 / max_dim
				_pin_sprite.scale = Vector2(s, s)
		_pin_sprite.position = Vector2(-48.0 + 14.0, 40.0 - 22.0)
		_pin_sprite.visible = false
		_pin_sprite.z_index = 5

	if _shield_sprite == null:
		_shield_sprite = get_node_or_null("ShieldSprite") as Sprite2D
		if _shield_sprite == null:
			_shield_sprite = Sprite2D.new()
			_shield_sprite.name = "ShieldSprite"
			add_child(_shield_sprite)
		var shield_tex := _load_atlas("shield_icon.tres")
		if shield_tex != null:
			_shield_sprite.texture = shield_tex
			var max_dim := maxf(shield_tex.get_width(), shield_tex.get_height())
			if max_dim > 0.0:
				var s := 56.0 / max_dim
				_shield_sprite.scale = Vector2(s, s)
		_shield_sprite.position = Vector2(0, 0)
		_shield_sprite.visible = false
		_shield_sprite.z_index = 6

func _update_visual_nodes() -> void:
	if _pin_sprite == null or _shield_sprite == null:
		_setup_sprites()

	var base_col := COLOR_RIVAL if faction == Faction.RIVAL else (COLOR_FOCUS if is_active_focused else COLOR_PLAYER)

	if _pin_sprite:
		_pin_sprite.visible = (drag_cooldown_timer > 0.0)
		_pin_sprite.modulate = base_col

	if _shield_sprite:
		if is_shielded():
			_shield_sprite.visible = true
			var pulse: float = (sin(Time.get_ticks_msec() * 0.008) + 1.0) * 0.5
			var alpha: float = 0.5 + pulse * 0.45
			_shield_sprite.modulate = Color(base_col.r, base_col.g, base_col.b, alpha)
		else:
			_shield_sprite.visible = false

func _enter_tree() -> void:
	_setup_sprites()
	_update_visual_nodes()

func _ready() -> void:
	add_to_group("tabs")
	current_hp = max_hp
	_setup_sprites()
	_update_visual_nodes()
	queue_redraw()

func set_faction(new_faction: Faction) -> void:
	faction = new_faction
	for t in towers:
		if is_instance_valid(t):
			t.faction = "player" if faction == Faction.PLAYER else ("rival" if faction == Faction.RIVAL else "neutral")
			if t.has_method("set_active_focus"):
				t.set_active_focus(is_active_focused and is_player())
			elif t.has_method("_update_visuals"):
				t._update_visuals()
			t.queue_redraw()
	_update_visual_nodes()
	queue_redraw()

func is_player() -> bool: return faction == Faction.PLAYER
func is_rival() -> bool: return faction == Faction.RIVAL
func is_neutral() -> bool: return faction == Faction.NEUTRAL
func is_inert() -> bool: return inert_timer > 0.0
func is_shielded() -> bool: return shield_timer > 0.0
func is_alive() -> bool: return current_hp > 0.0

func can_generate_coins() -> bool:
	return is_player() and is_active_focused and not is_inert() and refresh_coin_penalty_timer <= 0.0

func set_focused(focused: bool) -> void:
	is_active_focused = focused
	for t in towers:
		if is_instance_valid(t) and t.has_method("set_active_focus"):
			t.set_active_focus(focused and is_player())
	_update_visual_nodes()
	queue_redraw()

func _process(delta: float) -> void:
	_update_visual_nodes()

	# Tick cooldowns and state timers
	if inert_timer > 0.0:
		inert_timer = maxf(0.0, inert_timer - delta)
		if inert_timer == 0.0 and grid_manager != null:
			grid_manager.check_triangulation()
		queue_redraw()

	if drag_cooldown_timer > 0.0:
		drag_cooldown_timer = maxf(0.0, drag_cooldown_timer - delta)
		queue_redraw()

	if refresh_cooldown_timer > 0.0:
		refresh_cooldown_timer = maxf(0.0, refresh_cooldown_timer - delta)

	if refresh_coin_penalty_timer > 0.0:
		refresh_coin_penalty_timer = maxf(0.0, refresh_coin_penalty_timer - delta)

	if shield_timer > 0.0:
		shield_timer = maxf(0.0, shield_timer - delta)
		queue_redraw()

	if enemy_capture_pause_timer > 0.0:
		enemy_capture_pause_timer = maxf(0.0, enemy_capture_pause_timer - delta)

	# Process Refresh Rush cursor burst (5 strikes over 2 seconds)
	if pending_refresh_strikes > 0:
		refresh_strike_timer -= delta
		if refresh_strike_timer <= 0.0:
			refresh_strike_timer = refresh_strike_interval
			pending_refresh_strikes -= 1
			_launch_mini_cursor_strike()

	# Process attached towers
	var fire_multiplier: float = 1.0
	if is_player():
		if is_active_focused:
			var gd = get_node_or_null("/root/GameData")
			fire_multiplier = gd.get_focus_boost_multiplier() if gd else 1.5
		else:
			fire_multiplier = 0.5 # Unfocused tabs fire at 50% rate
	
	var can_fire := not is_inert() and not is_dragging
	for tower in towers:
		if is_instance_valid(tower):
			tower.process_firing(delta, fire_multiplier, can_fire)

	# Follow mouse if actively dragging
	if is_dragging:
		global_position = get_global_mouse_position() - drag_offset

# Input handling with 8-pixel drag deadzone
func _unhandled_input(event: InputEvent) -> void:
	if not is_player():
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			var local_pos := to_local(mouse_event.global_position)
			var tab_rect := Rect2(Vector2(-48, -40), Vector2(96, 80))
			var close_rect := Rect2(Vector2(28, -38), Vector2(16, 16))

			if mouse_event.pressed:
				if tab_rect.has_point(local_pos):
					# Check close button 'X' click
					if close_rect.has_point(local_pos):
						_on_close_sacrifice_clicked()
						get_viewport().set_input_as_handled()
						return
					
					drag_start_mouse_pos = mouse_event.global_position
					drag_offset = local_pos
			else:
				# Left button released
				if is_dragging:
					_end_drag(mouse_event.global_position)
					get_viewport().set_input_as_handled()
				elif tab_rect.has_point(local_pos):
					# Released within tab without exceeding deadzone -> It's a click!
					_handle_tab_click()
					get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		var motion_event := event as InputEventMouseMotion
		if not is_dragging and drag_start_mouse_pos != Vector2.ZERO:
			# 8-pixel deadzone check
			if drag_start_mouse_pos.distance_to(motion_event.global_position) >= DRAG_DEADZONE:
				_start_drag()

func _handle_tab_click() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if (now - last_click_time) <= DOUBLE_CLICK_WINDOW:
		# Double Click -> Refresh Rush
		last_click_time = -10.0
		execute_refresh_rush()
	else:
		# Single Click -> Active Tab Focus
		last_click_time = now
		_request_active_focus()

func _request_active_focus() -> void:
	var bm = get_node_or_null("/root/BattleManager")
	if bm:
		bm.request_tab_focus(self)
	tab_clicked.emit(self)

# Execute Refresh Rush:
# Resets merge progress, launches 5 cursor strikes, pauses enemy capture 2s, 4s coin penalty
func execute_refresh_rush() -> void:
	var bm = get_node_or_null("/root/BattleManager")
	if bm == null or not bm.can_use_refresh_rush():
		return
	if refresh_cooldown_timer > 0.0:
		return
	
	if not bm.use_refresh_rush_charge():
		return

	var synth = get_node_or_null("/root/AudioSynth")
	if synth:
		synth.play_refresh_rush()

	# Cooldowns and penalties
	refresh_cooldown_timer = 30.0
	refresh_coin_penalty_timer = 4.0
	enemy_capture_pause_timer = 2.0

	# Apply pending merge progress across attached towers
	merge_available_towers()

	# Queue 5 mini-cursor strikes over 2 seconds
	var gd = get_node_or_null("/root/GameData")
	pending_refresh_strikes = gd.get_refresh_cursor_count() if gd else 5
	refresh_strike_interval = 2.0 / float(pending_refresh_strikes)
	refresh_strike_timer = 0.0
	_launch_mini_cursor_strike()

	tab_double_clicked.emit(self)
	queue_redraw()

func _launch_mini_cursor_strike() -> void:
	var rival_tabs := get_tree().get_nodes_in_group("tabs").filter(func(t): return is_instance_valid(t) and t.has_method("is_rival") and t.is_rival() and t.is_alive())
	if rival_tabs.is_empty():
		return
	
	# Target closest or lowest HP rival tab
	var target: TabBase = rival_tabs[randi() % rival_tabs.size()]
	var strike: CursorStrike = CursorStrikeScene.instantiate()
	strike.init_strike(target, 12.0, "player", true, is_active_focused)
	get_tree().current_scene.add_child(strike)

func merge_available_towers() -> void:
	merge_cascade()

# Safe Cascade Merge Loop:
# Merges identical tiers (tier < 4) and repeats until no duplicate tiers remain on the tab
func merge_cascade() -> void:
	var merged := true
	while merged:
		merged = false
		for i in range(towers.size()):
			var t1: TabTower = towers[i]
			if not is_instance_valid(t1) or t1.is_queued_for_deletion():
				continue
			if int(t1.tier) >= int(TabTower.Tier.TIER_4):
				continue

			for j in range(i + 1, towers.size()):
				var t2: TabTower = towers[j]
				if not is_instance_valid(t2) or t2.is_queued_for_deletion():
					continue
				if t1.tier == t2.tier and int(t1.tier) < int(TabTower.Tier.TIER_4):
					# Found a duplicate tier pair: remove t2 cleanly
					towers.erase(t2)
					remove_child(t2)
					t2.queue_free()

					# Upgrade surviving turret t1 to tier + 1
					t1.set_tier((int(t1.tier) + 1) as TabTower.Tier)

					var synth = get_node_or_null("/root/AudioSynth") if is_inside_tree() else null
					if synth:
						synth.play_merge()

					# Repeat loop to check if the new tier matches an existing turret
					merged = true
					break
			if merged:
				break

	# Sort towers descending by tier (e.g. [T4, T3, T2, T1])
	towers.sort_custom(func(a: TabTower, b: TabTower): return int(a.tier) > int(b.tier))
	_reposition_towers()

# Tab Drag Relocation
func _start_drag() -> void:
	if drag_cooldown_timer > 0.0:
		# On 15s cooldown (pinned), cannot drag
		return
	
	is_dragging = true
	z_index = 20 # Render above other tabs during drag
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var synth = get_node_or_null("/root/AudioSynth")
	if synth:
		synth.play_drag_pickup()

	if grid_manager:
		original_grid_pos = grid_manager.get_tab_grid_pos(self)
		var gd = get_node_or_null("/root/GameData")
		var max_range: int = gd.get_drag_max_range() if gd else 4
		grid_manager.highlight_valid_drop_tiles(self, max_range)

func _end_drag(drop_mouse_pos: Vector2) -> void:
	is_dragging = false
	z_index = 0
	drag_start_mouse_pos = Vector2.ZERO

	var scale_tween := create_tween()
	scale_tween.tween_property(self, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if grid_manager == null:
		return

	grid_manager.clear_tile_highlights()
	var target_grid_pos := grid_manager.world_to_grid(drop_mouse_pos)
	var gd = get_node_or_null("/root/GameData")
	var max_range: int = gd.get_drag_max_range() if gd else 4
	var cooldown: float = gd.get_drag_cooldown() if gd else 15.0

	if grid_manager.can_relocate_tab_to(self, target_grid_pos, max_range):
		var target_pos := grid_manager.grid_to_world_center(target_grid_pos)
		var current_pos := position
		grid_manager.relocate_tab(self, target_grid_pos, max_range)
		position = current_pos
		var pos_tween := create_tween()
		pos_tween.tween_property(self, "position", target_pos, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		# Trigger 3-second inert downtime and 15-second cooldown
		inert_timer = 3.0
		drag_cooldown_timer = cooldown
		var synth = get_node_or_null("/root/AudioSynth")
		if synth:
			synth.play_drag_drop()
	else:
		# Snap back to original tile
		var return_pos := grid_manager.grid_to_world_center(original_grid_pos)
		var pos_tween := create_tween()
		pos_tween.tween_property(self, "position", return_pos, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	queue_redraw()

# Close Tab Sacrifice Shield
func _on_close_sacrifice_clicked() -> void:
	if not is_player():
		return

	var synth = get_node_or_null("/root/AudioSynth")
	if synth:
		synth.play_sacrifice()

	# Refund half tower coins (or upgraded ratio)
	var gd = get_node_or_null("/root/GameData")
	var refund_ratio: float = gd.get_sacrifice_refund_ratio() if gd else 0.50
	var shield_duration: float = gd.get_shield_duration() if gd else 4.0

	var total_tower_cost: int = 0
	for t in towers:
		if is_instance_valid(t):
			total_tower_cost += t.get_cost()
	
	var refund_amount: int = int(round(float(total_tower_cost) * refund_ratio))
	var bm = get_node_or_null("/root/BattleManager")
	if bm:
		bm.add_coins(refund_amount)

	# Shield adjacent friendly tab
	if grid_manager != null:
		var current_pos := grid_manager.get_tab_grid_pos(self)
		var neighbors := grid_manager.get_adjacent_friendly_tabs(current_pos)
		for neighbor in neighbors:
			if neighbor != self and is_instance_valid(neighbor) and neighbor.has_method("apply_sacrifice_shield"):
				neighbor.apply_sacrifice_shield(shield_duration)
				break
		grid_manager.unregister_tab(self)

	_spawn_death_particles()
	tab_sacrificed.emit(self)
	queue_free()

func apply_sacrifice_shield(duration: float) -> void:
	shield_timer = duration
	queue_redraw()

func take_damage(amount: float, attacker_faction: String) -> void:
	if is_shielded():
		var synth = get_node_or_null("/root/AudioSynth")
		if synth:
			synth.play_shield_hit()
		return

	if is_inert() and attacker_faction == "player":
		return

	# Paused enemy capture
	if enemy_capture_pause_timer > 0.0 and attacker_faction != "player":
		return

	# Tab hit flash (white for 0.1s) using Tween
	if _hit_flash_tween and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(self, "modulate", Color.WHITE, 0.1).from(Color(8.0, 8.0, 8.0, 1.0))

	current_hp = maxf(0.0, current_hp - amount)
	queue_redraw()

	if current_hp <= 0.0:
		_on_tab_death()
		_on_captured(attacker_faction)

func _on_tab_death() -> void:
	_screen_shake()
	_spawn_death_particles()
	var synth = get_node_or_null("/root/AudioSynth")
	if synth and synth.has_method("play_tab_destroyed"):
		synth.play_tab_destroyed()

func _screen_shake() -> void:
	var battle_node: Node2D = get_node_or_null("/root/Main/ContentHolder/Battle") as Node2D
	if battle_node == null and get_tree() != null and get_tree().root != null:
		battle_node = get_tree().root.find_child("Battle", true, false) as Node2D
	if battle_node == null:
		return
	var orig: Vector2 = battle_node.position
	var shake_tween := create_tween()
	shake_tween.tween_property(battle_node, "position", orig + Vector2(randf_range(-5, 5), randf_range(-5, 5)), 0.03)
	shake_tween.tween_property(battle_node, "position", orig + Vector2(randf_range(-3, 3), randf_range(-3, 3)), 0.03)
	shake_tween.tween_property(battle_node, "position", orig + Vector2(randf_range(-2, 2), randf_range(-2, 2)), 0.03)
	shake_tween.tween_property(battle_node, "position", orig, 0.04)

func _spawn_death_particles() -> void:
	var particles := CPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = 0.45
	particles.amount = 24
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 60.0
	particles.initial_velocity_max = 140.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.5
	particles.color = Color(1.0, 0.4, 0.3) if is_rival() else Color(0.3, 0.8, 1.0)
	particles.global_position = global_position
	var parent_node := get_parent() if get_parent() else get_tree().current_scene
	if parent_node:
		parent_node.add_child(particles)
		particles.emitting = true
		get_tree().create_timer(particles.lifetime + 0.1).timeout.connect(particles.queue_free)

func _on_captured(by_faction: String) -> void:
	current_hp = max_hp
	var new_f := Faction.PLAYER if by_faction == "player" else Faction.RIVAL
	set_faction(new_f)
	tab_captured.emit(self, by_faction)
	if grid_manager:
		grid_manager.check_triangulation()

func add_tower(tier: TabTower.Tier = TabTower.Tier.TIER_1) -> bool:
	var tower: TabTower = TowerScene.instantiate()
	tower.tier = tier
	tower.faction = "player" if is_player() else ("rival" if is_rival() else "neutral")
	if tower.has_method("set_active_focus"):
		tower.set_active_focus(is_active_focused and is_player())
	add_child(tower)
	towers.append(tower)
	
	# Execute safe cascade merging across existing turrets
	merge_cascade()
	return true

func get_tower_tiers() -> Array[int]:
	var result: Array[int] = []
	for t in towers:
		if is_instance_valid(t) and not t.is_queued_for_deletion():
			result.append(int(t.tier))
	return result

func _reposition_towers() -> void:
	var count := towers.size()
	if count == 0:
		return
	if count == 1:
		towers[0].position = Vector2(0, 10)
	elif count == 2:
		towers[0].position = Vector2(-22, 10)
		towers[1].position = Vector2(22, 10)
	elif count == 3:
		towers[0].position = Vector2(-28, 10)
		towers[1].position = Vector2(0, 10)
		towers[2].position = Vector2(28, 10)
	else:
		var spacing: float = 68.0 / float(count - 1)
		for idx in range(count):
			towers[idx].position = Vector2(-34.0 + (idx * spacing), 10)

func _draw() -> void:
	var tab_w: float = 96.0
	var tab_h: float = 80.0
	var rect := Rect2(-tab_w * 0.5, -tab_h * 0.5, tab_w, tab_h)

	# Faction theme colors
	var header_col: Color
	var body_col: Color
	var border_col: Color

	match faction:
		Faction.PLAYER:
			header_col = Color(0.18, 0.38, 0.65)
			body_col = Color(0.14, 0.20, 0.28, 0.95)
			border_col = COLOR_FOCUS if is_active_focused else COLOR_PLAYER
		Faction.RIVAL:
			header_col = Color(0.65, 0.22, 0.22)
			body_col = Color(0.28, 0.14, 0.14, 0.95)
			border_col = COLOR_RIVAL
		Faction.NEUTRAL:
			header_col = Color(0.28, 0.32, 0.38)
			body_col = Color(0.18, 0.20, 0.24, 0.95)
			border_col = Color(0.45, 0.50, 0.58)

	# 1. Bold flat-color ring for Active Tab Focus
	if is_active_focused and is_player():
		var ring_rect := rect.grow(5.0)
		draw_rect(ring_rect, COLOR_FOCUS, false, 3.5)

	# 2. Tab Body background & border
	draw_rect(rect, body_col, true)
	draw_rect(rect, border_col, false, 1.5)

	# 3. Tab Header bar
	var header_rect := Rect2(-tab_w * 0.5, -tab_h * 0.5, tab_w, 20.0)
	draw_rect(header_rect, header_col, true)
	draw_rect(header_rect, border_col, false, 1.0)

	# 4. Favicon dot
	var fav_col := COLOR_FOCUS if (is_active_focused and is_player()) else (COLOR_PLAYER if is_player() else (COLOR_RIVAL if is_rival() else Color(0.8, 0.8, 0.8)))
	draw_circle(Vector2(-tab_w * 0.5 + 10.0, -tab_h * 0.5 + 10.0), 4.0, fav_col)

	# 5. Tab Title string
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-tab_w * 0.5 + 20.0, -tab_h * 0.5 + 14.0), tab_title, HORIZONTAL_ALIGNMENT_LEFT, 52, 10, Color.WHITE)

	# 6. Close button 'X' (only shown for player tabs)
	if is_player():
		var close_center := Vector2(tab_w * 0.5 - 10.0, -tab_h * 0.5 + 10.0)
		draw_line(close_center + Vector2(-3, -3), close_center + Vector2(3, 3), Color(0.9, 0.6, 0.6), 1.5)
		draw_line(close_center + Vector2(3, -3), close_center + Vector2(-3, 3), Color(0.9, 0.6, 0.6), 1.5)

	# 7. HP / Capture Progress Bar at the bottom of the tab
	var hp_pct := clampf(current_hp / max_hp, 0.0, 1.0)
	var hp_bg_rect := Rect2(-tab_w * 0.5 + 6.0, tab_h * 0.5 - 10.0, tab_w - 12.0, 5.0)
	var hp_fill_rect := Rect2(-tab_w * 0.5 + 6.0, tab_h * 0.5 - 10.0, (tab_w - 12.0) * hp_pct, 5.0)
	draw_rect(hp_bg_rect, Color(0.1, 0.1, 0.1, 0.8), true)
	var hp_col := Color(0.2, 0.85, 0.3) if hp_pct > 0.4 else Color(0.95, 0.7, 0.1)
	draw_rect(hp_fill_rect, hp_col, true)

	# Note: Pin and Shield icons are rendered via Sprite2D nodes (pin_sprite, shield_sprite)
	# with AtlasTextures pin_icon.tres and shield_icon.tres instead of primitive drawn shapes.

	# 8. Inert downtime visual (3s relocation downtime)
	if is_inert():
		var inert_overlay := Rect2(-tab_w * 0.5, -tab_h * 0.5, tab_w, tab_h)
		draw_rect(inert_overlay, Color(0.1, 0.1, 0.15, 0.6), true)
		var inert_str := "INERT (%.1fs)" % inert_timer
		draw_string(font, Vector2(-32, 2), inert_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, COLOR_FOCUS)
