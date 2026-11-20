class_name Enemy
extends Node2D

# Enemy units marching/rushing toward player tabs:
# - Pop-Up Swarm: Fast, low-HP rusher bot.
# - Cookie Tracker: Medium unit that steals coins unless intercepted.
# - Malware Brute: Heavy tank that anchors on L-shape corners.

signal enemy_defeated(enemy: Enemy)

enum EnemyType {
	POP_UP_SWARM,
	COOKIE_TRACKER,
	MALWARE_BRUTE
}

@export var enemy_type: EnemyType = EnemyType.POP_UP_SWARM
var max_hp: float = 30.0
var current_hp: float = 30.0
var base_speed: float = 80.0
var move_speed: float = 80.0

var target_tab: Node2D = null
var is_slowed: bool = false
var slow_timer: float = 0.0

var coin_steal_timer: float = 0.0
var attack_timer: float = 0.0
var _hit_flash_tween: Tween = null

func _ready() -> void:
	add_to_group("enemies")
	_setup_stats()
	queue_redraw()

func _setup_stats() -> void:
	match enemy_type:
		EnemyType.POP_UP_SWARM:
			max_hp = 25.0
			base_speed = 110.0
		EnemyType.COOKIE_TRACKER:
			max_hp = 60.0
			base_speed = 55.0
		EnemyType.MALWARE_BRUTE:
			max_hp = 200.0
			base_speed = 32.0
	current_hp = max_hp
	move_speed = base_speed

func init_enemy(type: EnemyType, spawn_pos: Vector2) -> void:
	enemy_type = type
	global_position = spawn_pos
	_setup_stats()
	queue_redraw()

func _process(delta: float) -> void:
	# Tick slow debuff (e.g. from Firewall)
	if slow_timer > 0.0:
		slow_timer -= delta
		move_speed = base_speed * 0.5
		if slow_timer <= 0.0:
			move_speed = base_speed
	else:
		move_speed = base_speed

	_find_target()
	
	if target_tab != null and is_instance_valid(target_tab):
		var target_pos: Vector2 = target_tab.global_position
		var dist := global_position.distance_to(target_pos)
		
		# Movement toward target tab
		if dist > 32.0:
			var dir := (target_pos - global_position).normalized()
			global_position += dir * move_speed * delta
		else:
			# Close range interaction with target tab
			_interact_with_tab(delta)
	
	# Cookie Tracker passive coin stealing
	if enemy_type == EnemyType.COOKIE_TRACKER:
		coin_steal_timer += delta
		if coin_steal_timer >= 2.0:
			coin_steal_timer = 0.0
			_steal_coins()

func _find_target() -> void:
	if target_tab != null and is_instance_valid(target_tab):
		if target_tab.has_method("is_alive") and not target_tab.is_alive():
			target_tab = null
		elif target_tab.has_method("is_player") and not target_tab.is_player():
			target_tab = null

	if target_tab == null:
		var bm = get_node_or_null("/root/BattleManager")
		var player_tabs := get_tree().get_nodes_in_group("tabs").filter(
			func(t): return is_instance_valid(t) and t.has_method("is_player") and t.is_player() and t.is_alive()
		)
		if player_tabs.is_empty():
			return
		
		# Malware Brute prioritizes L-shape corner tabs
		if enemy_type == EnemyType.MALWARE_BRUTE and bm and not bm.triangulation_nodes.is_empty():
			var l_tabs = bm.triangulation_nodes.filter(
				func(t): return is_instance_valid(t) and t.has_method("is_alive") and t.is_alive()
			)
			if not l_tabs.is_empty():
				target_tab = l_tabs[0]
				return
		
		# Otherwise target closest player tab
		var closest_tab: Node2D = null
		var min_dist: float = 999999.0
		for t in player_tabs:
			var d := global_position.distance_to(t.global_position)
			if d < min_dist:
				min_dist = d
				closest_tab = t
		target_tab = closest_tab

func _interact_with_tab(delta: float) -> void:
	match enemy_type:
		EnemyType.POP_UP_SWARM:
			# Fast rush explosion
			if is_instance_valid(target_tab) and target_tab.has_method("take_damage"):
				target_tab.take_damage(15.0, "rival")
			_spawn_explosion()
			queue_free()
		EnemyType.MALWARE_BRUTE:
			# Heavy tank pound
			attack_timer += delta
			if attack_timer >= 1.2:
				attack_timer = 0.0
				if is_instance_valid(target_tab) and target_tab.has_method("take_damage"):
					target_tab.take_damage(20.0, "rival")
				var synth = get_node_or_null("/root/AudioSynth")
				if synth and synth.has_method("play_strike"):
					synth.play_strike()
		EnemyType.COOKIE_TRACKER:
			# Marches around player tab stealing coins
			pass

func _steal_coins() -> void:
	var bm = get_node_or_null("/root/BattleManager")
	if bm and bm.coins > 5:
		bm.spend_coins(5)
		_show_steal_popup("-5 COINS!")

func _show_steal_popup(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color(0.85, 0.25, 0.95)) # Purple alert
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.position = global_position + Vector2(-20, -25)
	lbl.z_index = 30
	get_tree().current_scene.add_child(lbl)
	
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 20.0, 0.7)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.7)
	tw.chain().tween_callback(lbl.queue_free)

func apply_slow(duration: float) -> void:
	slow_timer = duration
	is_slowed = true

func take_damage(amount: float, attacker_faction: String = "player") -> void:
	if attacker_faction != "player":
		return
	
	current_hp = maxf(0.0, current_hp - amount)
	
	# Hit flash
	if _hit_flash_tween and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(self, "modulate", Color.WHITE, 0.08).from(Color(3.0, 3.0, 3.0, 1.0))
	
	queue_redraw()
	
	if current_hp <= 0.0:
		_on_defeated()

func _on_defeated() -> void:
	var bm = get_node_or_null("/root/BattleManager")
	if bm:
		bm.add_coins(8) # Coin reward for defeating enemy
	_spawn_explosion()
	enemy_defeated.emit(self)
	queue_free()

func _spawn_explosion() -> void:
	var particles := CPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = 0.35
	particles.amount = 16
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 40.0
	particles.initial_velocity_max = 90.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = Color(0.96, 0.62, 0.04) if enemy_type == EnemyType.POP_UP_SWARM else (Color(0.66, 0.33, 0.97) if enemy_type == EnemyType.COOKIE_TRACKER else Color(0.86, 0.15, 0.15))
	particles.global_position = global_position
	var cur_scene = get_tree().current_scene if get_tree() else null
	if cur_scene:
		cur_scene.add_child(particles)
		particles.emitting = true
		get_tree().create_timer(particles.lifetime + 0.1).timeout.connect(particles.queue_free)

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var border_col := Color(0.06, 0.09, 0.16) # #0F172A
	var shadow_offset := Vector2(3, 4)

	match enemy_type:
		EnemyType.POP_UP_SWARM:
			# Yellow '!' / 'ADS' mini window bot
			var w := 32.0
			var h := 26.0
			var rect := Rect2(-w * 0.5, -h * 0.5, w, h)
			# Hard shadow
			draw_rect(Rect2(rect.position + shadow_offset, rect.size), border_col, true)
			# Yellow window body (#FBBF24)
			draw_rect(rect, Color(0.98, 0.75, 0.14), true)
			draw_rect(rect, border_col, false, 3.0)
			# Mini title bar
			var bar_rect := Rect2(-w * 0.5, -h * 0.5, w, 7.0)
			draw_rect(bar_rect, Color(0.96, 0.62, 0.04), true)
			draw_line(Vector2(-w * 0.5, -h * 0.5 + 7.0), Vector2(w * 0.5, -h * 0.5 + 7.0), border_col, 1.5)
			# Red '!' exclamation badge
			draw_string(font, Vector2(-4, 7), "!", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(0.86, 0.15, 0.15))
			
		EnemyType.COOKIE_TRACKER:
			# Purple Eye bot (#A855F7)
			var radius := 16.0
			# Hard shadow
			draw_circle(shadow_offset, radius, border_col)
			# Purple body
			draw_circle(Vector2.ZERO, radius, Color(0.66, 0.33, 0.97))
			draw_arc(Vector2.ZERO, radius, 0, TAU, 32, border_col, 3.0)
			# White eyeball
			draw_circle(Vector2(0, 0), 9.0, Color.WHITE)
			draw_arc(Vector2(0, 0), 9.0, 0, TAU, 24, border_col, 1.5)
			# Iris & pupil tracking
			var pupil_pos := Vector2(cos(Time.get_ticks_msec() * 0.005) * 3.0, sin(Time.get_ticks_msec() * 0.005) * 2.0)
			draw_circle(pupil_pos, 4.5, Color(0.40, 0.15, 0.65))
			draw_circle(pupil_pos, 2.0, border_col)

		EnemyType.MALWARE_BRUTE:
			# Skull Error box tank
			var w := 44.0
			var h := 34.0
			var rect := Rect2(-w * 0.5, -h * 0.5, w, h)
			# Hard shadow
			draw_rect(Rect2(rect.position + shadow_offset, rect.size), border_col, true)
			# Crimson/Dark-red error body (#BE123C)
			draw_rect(rect, Color(0.75, 0.07, 0.24), true)
			draw_rect(rect, border_col, false, 3.0)
			# Header bar
			var bar_rect := Rect2(-w * 0.5, -h * 0.5, w, 8.0)
			draw_rect(bar_rect, Color(0.06, 0.09, 0.16), true)
			# Skull text / emblem
			draw_string(font, Vector2(-12, 6), "ERR!", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color.WHITE)

	# Mini HP bar
	if current_hp < max_hp:
		var hp_w := 24.0
		var hp_pct := clampf(current_hp / max_hp, 0.0, 1.0)
		var bg_r := Rect2(-hp_w * 0.5, -20.0, hp_w, 4.0)
		var fill_r := Rect2(-hp_w * 0.5, -20.0, hp_w * hp_pct, 4.0)
		draw_rect(bg_r, Color(0.06, 0.09, 0.16), true)
		draw_rect(fill_r, Color(0.13, 0.77, 0.36), true)
		draw_rect(bg_r, border_col, false, 1.0)
