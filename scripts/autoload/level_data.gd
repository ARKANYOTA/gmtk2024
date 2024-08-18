extends Node

var levels = [
	{ "name": "1-1", "scene": "res://scenes/levels/level_100_intro.tscn"},
	{ "name": "1-1", "scene": "res://scenes/levels/level_110_push.tscn"},
	{ "name": "1-1", "scene": "res://scenes/levels/level_120_support.tscn"},
	{ "name": "1-1", "scene": "res://scenes/levels/level_140_only_red_wins.tscn"},
	
	{ "name": "1-1", "scene": "res://scenes/levels/level_100.tscn"},
	{ "name": "1-1", "scene": "res://scenes/levels/level_100.tscn"},
	{ "name": "1-1", "scene": "res://scenes/levels/level_100.tscn"},
	{ "name": "1-1", "scene": "res://scenes/levels/level_100.tscn"},
	{ "name": "1-1", "scene": "res://scenes/levels/level_100.tscn"},
	{ "name": "1-1", "scene": "res://scenes/levels/level_100.tscn"},
	{ "name": "1-2", "scene": "res://scenes/levels/level_101.tscn"},
	{ "name": "2-1", "scene": "res://scenes/levels/world_2/level_10.tscn"},
	{ "name": "You Win", "scene": "res://scenes/levels/you_win.tscn"},
]

var level = 1

func increment_level() -> void:
	level += 1
	if level >= len(levels):
		level = len(levels)
	save_level_data()

func increment_level_and_change_scene() -> void:
	BlockManagerAutoload.block_manager_instance.end_drag()
	increment_level()
	var scene_path = levels[level - 1]["scene"]
	SceneTransitionAutoLoad.change_scene_with_transition(scene_path)

func reload_scene() -> void:
	BlockManagerAutoload.block_manager_instance.end_drag()
	var scene_path = levels[level - 1]["scene"]
	SceneTransitionAutoLoad.change_scene_with_transition(scene_path)

func save_level_data() -> void:
	var config = ConfigFile.new()
	config.set_value("level_section","level", level)
	config.save("user://level_data.cfg")

func load_level_data() -> void:
	var config = ConfigFile.new()
	config.load("user://level_data.cfg")
	level = config.get_value("level_section","level", level)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _input(event):
	if event.is_action_pressed("removeme2_nolan_usge_to_change_scene"):
		increment_level_and_change_scene()
	
	if event.is_action_pressed("reload_button"):
		reload_scene()
