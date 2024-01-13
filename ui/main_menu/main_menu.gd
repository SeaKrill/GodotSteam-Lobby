extends Control

@onready var multi = $Multiplayer

func _ready():
	await get_tree().process_frame
	SceneManager.finished_loading.emit()

func _on_multiplayer_pressed():
	#multi._refresh_lobbies()
	multi.show()

func _on_multiplayer_cancel_pressed():
	multi.hide()

func _on_quit_pressed():
	get_tree().quit()
