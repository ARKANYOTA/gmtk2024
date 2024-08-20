extends Control

@onready var main = get_node("/root/Main")

# Called when the node enters the scene tree for the first time.
func _ready():
	hide_gui()

func show_level_select():
	$PauseButton.show()
	$RetryButton.hide()
	$FullscreenButton.show()

func hide_gui():
	$PauseButton.hide()
	$RetryButton.hide()
	$FullscreenButton.show()

func show_gui():
	$PauseButton.show()
	$RetryButton.show()
	$FullscreenButton.hide()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_pause_button_pressed():
	if PauseMenuAutoload.paused:
		PauseMenuAutoload.pause_menu.back()
	else:
		PauseMenuAutoload.pause_menu.pause()


func _on_retry_button_pressed():
	PauseMenuAutoload.pause_menu.exit_menu()
	LevelData.reload_scene()
	GameManager.on_restart()
