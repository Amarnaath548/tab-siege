class_name CursorStrike
extends Node2D

# Stylized OS mouse cursor that swoops down and strikes a target tab.
# Renders AtlasTexture cursor_icon with Sprite2D modulated by faction/focus.

signal strike_impacted(target: Node)

var target_node: Node = null
var target_pos: Vector2 = Vector2.ZERO
var damage: float = 15.0
var faction: String = "player" # "player" or "rival"
var is_mini: bool = false # Mini cursor strikes used in Refresh Rush
var is_active_focus: bool = false

var elapsed: float = 0.0
var strike_duration: float = 0.35
var impacted: bool = false
var ripple_radius: float = 0.0
var ripple_alpha: float = 1.0

var _sprite: Sprite2D = null
var sprite: Sprite2D:
	get:
		if _sprite == null:
			_setup_sprite()
		return _sprite

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

func _enter_tree() -> void:
	_setup_sprite()
	_update_visuals()

func _ready() -> void:
	_setup_sprite()
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

func init_strike(target: Node, dmg: float, p_faction: String, p_is_mini: bool = false, p_is_active_focus: bool = false) -> void:
	target_node = target
	damage = dmg
	faction = p_faction
	is_mini = p_is_mini
	is_active_focus = p_is_active_focus
	if is_instance_valid(target):
		target_pos = target.global_position
	# Start slightly above and to the left of the target
	var offset := Vector2(-40.0, -60.0) if not is_mini else Vector2(randf_range(-30, 30), -45.0)
	position = target_pos + offset
	_update_visuals()

func _update_visuals() -> void:
	if _sprite == null:
		_setup_sprite()
	if _sprite == null:
		return

	var tex := _load_atlas("cursor_icon.tres")
	if tex != null:
		_sprite.texture = tex
		var max_dim := maxf(tex.get_width(), tex.get_height())
		if max_dim > 0.0:
			var target_size := 30.0 if not is_mini else 20.0
			var s := target_size / max_dim
			_sprite.scale = Vector2(s, s)

	# Modulate colors for Player (cyan/blue), Rival (crimson), and Active Focus (gold)
	if faction == "rival":
		_sprite.modulate = COLOR_RIVAL
	elif is_active_focus:
		_sprite.modulate = COLOR_FOCUS
	else:
		_sprite.modulate = COLOR_PLAYER

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
	if _sprite:
		var fade_tween := create_tween()
		fade_tween.tween_property(_sprite, "modulate:a", 0.0, 0.18)

	var synth := get_node_or_null("/root/AudioSynth")
	if synth:
		synth.play_strike()
	
	if is_instance_valid(target_node) and target_node.has_method("take_damage"):
		target_node.take_damage(damage, faction)
	
	strike_impacted.emit(target_node)
	queue_redraw()

func _draw() -> void:
	# Shockwave click ring on impact
	if impacted and ripple_alpha > 0.0:
		var ring_col := COLOR_RIVAL if faction == "rival" else (COLOR_FOCUS if is_active_focus else COLOR_PLAYER)
		var c := Color(ring_col.r, ring_col.g, ring_col.b, ripple_alpha)
		draw_arc(Vector2.ZERO, ripple_radius, 0, TAU, 24, c, 2.5)
