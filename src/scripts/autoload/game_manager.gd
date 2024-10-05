extends Node

enum GamePlatform {
	UNDEFINED,

	WEB,
	MOBILE,
	PC,
	UNKNOWN,
}

enum DistributionPlatform {
	UNDEFINED,

	NATIVE,
	STEAM,
	PLAY_STORE,
}

var rng = RandomNumberGenerator.new()

var distribution_platform: DistributionPlatform = DistributionPlatform.UNDEFINED:
	get:
		if distribution_platform == DistributionPlatform.UNDEFINED:
			if is_steam_api_supported():
				distribution_platform = DistributionPlatform.STEAM
			else:
				distribution_platform = DistributionPlatform.NATIVE
		return distribution_platform

var game_platform: GamePlatform = GamePlatform.UNDEFINED:
	get:
		if game_platform == GamePlatform.UNDEFINED:
			match OS.get_name():
				"Windows", "macOS", "Linux":#, "FreeBSD", "NetBSD", "OpenBSD", "BSD":
					game_platform = GamePlatform.PC
				"Android", "iOS":
					game_platform = GamePlatform.MOBILE
				"Web":
					game_platform = GamePlatform.WEB
				_:
					game_platform = GamePlatform.UNKNOWN
		return game_platform

var discord_rich_presence: Node = null

const STEAM_APP_ID = 3219110
var steam_interface: Node = null

var options_manager: OptionsManager
var achievement_manager: AchievementManager

var cursor = preload("res://assets/images/ui/cursor_big.png")
var cursor_click = preload("res://assets/images/ui/cursor_click_big.png")
var global_camera_scene: PackedScene = preload("res://scenes/camera/global_camera.tscn")

var camera: Camera2D
var _loaded_fullscreen_option = false
var is_fullscreen: bool = true:
	set(value):
		is_fullscreen = value
		update_fullscreen()
		save_option("graphics", "is_fullscreen", is_fullscreen)

func _ready():
	print("launched game")
	options_manager = OptionsManager.new()

	camera = global_camera_scene.instantiate()
	add_child(camera)
	
	process_mode = ProcessMode.PROCESS_MODE_ALWAYS
	
	#Input.set_custom_mouse_cursor(cursor_click, Input.CURSOR_IBEAM)
	Input.set_custom_mouse_cursor(cursor)

	_init_discord_rpc()
	_init_steam()
	_init_achievement_manager()


func _process(delta):
	# It is necessary to wait one frame after the scene has been instanciated to avoid an ugly gray frame
	if not _loaded_fullscreen_option:
		is_fullscreen = load_option("graphics", "is_fullscreen", true)
		_loaded_fullscreen_option = true

		for bus in ["Master", "Music"]:
			set_bus_volume(bus, load_option("volume", bus, 1.0))


func set_bus_volume(bus: String, value: float):
	var bus_index = AudioServer.get_bus_index(bus)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))


func _input(event):
	if event.is_action_pressed("left_click"):
		Input.set_custom_mouse_cursor(cursor_click)
	
	if event.is_action_released("left_click"):
		Input.set_custom_mouse_cursor(cursor)
	
	if event.is_action_pressed("undo_action"):
		var scene = get_tree().get_current_scene()
		if scene == null:
			return
		
		if scene is Level:
			scene.undo_action()
	
	if event.is_action_pressed("toggle_fullscreen"):
		toggle_fullscreen()

	if event.is_action_pressed("removeme_achievement_test"):
		print("about to grant ACH_TEST_01")
		achievement_manager.grant("ACH_TEST_01")
	
	if event.is_action_pressed("removeme_achievement_revokeall"):
		print("about to revoke all achievements")
		achievement_manager.revoke_all()
	
	if event.is_action_pressed("removeme_winlevel"):
		print("about to win level")
		win()


func win():
	var current_level_data = LevelData.get_current_level_data()
	if current_level_data:
		if current_level_data.has("achievement") and achievement_manager:
			achievement_manager.grant(current_level_data["achievement"])

	#check if level in level data
	var level_in_data = false
	var next_level_name = "res://scenes/ui/world_select/world_select.tscn"
	var next_sound = "city"
	var next_level_data: Dictionary = {}
	for i in range(LevelData.levels.size()):
		if LevelData.levels[i]["scene"] == get_tree().current_scene.scene_file_path:
			#check if level is not the last level
			level_in_data = true
			if i + 1 < LevelData.levels.size():
				next_level_name = LevelData.levels[i + 1]["scene"]
				next_sound = LevelData.levels[i + 1]["music"]
	LevelData.make_level_completed()
	LevelData.selected_level_name = next_level_name
	SceneTransitionAutoLoad.change_scene_with_transition(next_level_name, true)

func on_restart():
	pass

func before_scene_change():
	BlockManagerAutoload.blocks.clear()
	BlockManagerAutoload.reset()

func toggle_fullscreen():
	is_fullscreen = not is_fullscreen

func update_fullscreen():
	if is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WindowMode.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WindowMode.WINDOW_MODE_MAXIMIZED)

## Saves an option and returns whether it was saved successfully.  
## NOTE: this could become quite slow if the options file are updated very frequently or is very big 
func save_option(section: String, key: String, value: Variant) -> bool:
	return options_manager.save(section, key, value)

## Return an option or a default value if impossible to load the options file.  
## NOTE: this could become quite slow if the options file are read very frequently or is very big 
func load_option(section: String, key: String, default_value: Variant):
	return options_manager.load(section, key, default_value)

#################################################################

func is_discord_rpc_supported() -> bool:
	return game_platform == GamePlatform.PC and GDExtensionManager.is_extension_loaded("res://addons/discord-rpc-gd/bin/discord-rpc-gd.gdextension")

func _init_discord_rpc():
	if not is_discord_rpc_supported():
		return
	
	var discord_rich_presence_scene: PackedScene = load("res://scenes/integration/discord_rich_presence.tscn")
	discord_rich_presence = discord_rich_presence_scene.instantiate()
	add_child(discord_rich_presence)
	
	discord_rich_presence.initialize()

func _update_discord_rpc():
	if not discord_rich_presence:
		return
	
	discord_rich_presence.update()



#caca proute de la par de corentin

#################################################################

func is_steam_api_supported() -> bool:
	return game_platform == GamePlatform.PC and GDExtensionManager.is_extension_loaded("res://addons/godotsteam/godotsteam.gdextension")

func _init_steam():
	if distribution_platform != DistributionPlatform.STEAM:
		return
	
	var steam_interface_scene: PackedScene = load("res://scenes/integration/steam_interface.tscn")
	steam_interface = steam_interface_scene.instantiate()
	add_child(steam_interface)
	
	var success = steam_interface.initialize()
	if not success:
		# TODO
		pass

#################################################################

func _init_achievement_manager():
	match distribution_platform:
		DistributionPlatform.STEAM:
			print("Creating Steam achievement manager")
			var scene: PackedScene = load("res://scenes/achievements/achievement_manager_steam.tscn")
			achievement_manager = scene.instantiate()
		_:
			#TODO
			print("Creating generic achievement manager")
			pass

	add_child(achievement_manager)
