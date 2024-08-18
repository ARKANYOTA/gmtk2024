extends Control
class_name PauseMenu

@onready var main = get_parent()
@onready var click_audio = $ClickAudio

func _on_resume_pressed():
	main.exit_menu()

func _on_quit_pressed():
	get_tree().quit()

func _on_levels_pressed():
	main.exit_menu()
	SceneTransitionAutoLoad.change_scene_with_transition("res://scenes/level_select.tscn")

func _on_restart_pressed():
	main.exit_menu()
	LevelData.reload_scene()
