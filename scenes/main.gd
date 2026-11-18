class_name MainController
extends Node

# MainController: Top-level scene router managing Battle and Bookmark Atlas transitions.

@onready var content_holder: Node = $ContentHolder

const BattleScene: PackedScene = preload("res://scenes/battle/battle.tscn")
const AtlasScene: PackedScene = preload("res://scenes/atlas/bookmark_atlas.tscn")

var current_view: Node = null

func _ready() -> void:
	load_battle()

func clear_current_view() -> void:
	if current_view != null and is_instance_valid(current_view):
		current_view.queue_free()
		current_view = null

func load_battle() -> void:
	clear_current_view()
	var battle: Node = BattleScene.instantiate()
	if battle.has_signal("open_atlas_requested"):
		battle.open_atlas_requested.connect(load_atlas)
	if battle.has_signal("battle_restarted"):
		battle.battle_restarted.connect(load_battle)
	content_holder.add_child(battle)
	current_view = battle

func load_atlas() -> void:
	clear_current_view()
	var atlas: Node = AtlasScene.instantiate()
	if atlas.has_signal("start_battle_requested"):
		atlas.start_battle_requested.connect(load_battle)
	content_holder.add_child(atlas)
	current_view = atlas
