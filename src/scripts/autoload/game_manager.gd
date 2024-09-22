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

const DISCORD_RPC_UPDATE_INTERVAL = 3.0
var discord_rich_presence: Node = null
var _discord_rpc_update_timer = 0.0

const STEAM_APP_ID = 3219110
var steam_interface: Node = null

var google_play_payments: Node = null

var achievement_manager: AchievementManager

var cursor = preload("res://assets/images/ui/cursor_big.png")
var cursor_click = preload("res://assets/images/ui/cursor_click_big.png")
var global_camera_scene: PackedScene = preload("res://scenes/camera/global_camera.tscn")

var camera: Camera2D
var is_fullscreen := false

func _ready():
	print("launched game")
	camera = global_camera_scene.instantiate()
	add_child(camera)
	
	process_mode = ProcessMode.PROCESS_MODE_ALWAYS
	
	Input.set_custom_mouse_cursor(cursor)
	#Input.set_custom_mouse_cursor(cursor_click, Input.CURSOR_IBEAM)

	_init_discord_rpc()
	_init_steam()
	_init_google_play_payments()
	_init_achievement_manager()

func _process(delta):
	if discord_rich_presence:
		_discord_rpc_update_timer -= delta
		if _discord_rpc_update_timer < 0:
			discord_rich_presence.update()
			_discord_rpc_update_timer = DISCORD_RPC_UPDATE_INTERVAL


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
	if is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WindowMode.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WindowMode.WINDOW_MODE_MAXIMIZED)

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
	pass
	if not discord_rich_presence:
		return
	
	discord_rich_presence.update()



#caca proute de la par de corentin

#################################################################

# Steam

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

# Google Play payments

func is_google_play_payments_supported() -> bool:
	return game_platform == GamePlatform.MOBILE and Engine.has_singleton("GodotGooglePlayBilling")

func _init_google_play_payments():
	if distribution_platform != DistributionPlatform.PLAY_STORE:
		return
	
	var google_play_payments_scene: PackedScene = load("res://scenes/integration/google_play_payments.tscn")
	google_play_payments = google_play_payments_scene.instantiate()
	add_child(google_play_payments)
	
	var success = google_play_payments.initialize()
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

		DistributionPlatform.PLAY_STORE:
			print("Creating Play Store achievement manager")
			pass
			
		_:
			#TODO
			print("Creating generic achievement manager")
			pass

	add_child(achievement_manager)