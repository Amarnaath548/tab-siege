class_name Projectile
extends Node2D

# Projectile fired by tab towers towards rival tabs or targets

var target_node: Node = null
var target_pos: Vector2 = Vector2.ZERO
var speed: float = 650.0
var damage: float = 10.0
var faction: String = "player" # "player" or "rival"

func _ready() -> void:
	queue_redraw()

func init_projectile(from_pos: Vector2, target: Node, dmg: float, p_faction: String) -> void:
	position = from_pos
	target_node = target
	damage = dmg
	faction = p_faction
	if is_instance_valid(target):
		target_pos = target.global_position

func _process(delta: float) -> void:
	if is_instance_valid(target_node):
		target_pos = target_node.global_position
	
	var dir := (target_pos - position).normalized()
	var dist := position.distance_to(target_pos)
	var step := speed * delta
	
	if dist <= step or dist < 8.0:
		_hit_target()
	else:
		position += dir * step
		rotation = dir.angle()

func _hit_target() -> void:
	if is_instance_valid(target_node) and target_node.has_method("take_damage"):
		target_node.take_damage(damage, faction)
	queue_free()

func _draw() -> void:
	var col := Color(0.2, 0.8, 1.0) if faction == "player" else Color(1.0, 0.3, 0.3)
	draw_circle(Vector2.ZERO, 3.5, col)
	draw_line(Vector2(-6, 0), Vector2(6, 0), col, 2.0)
