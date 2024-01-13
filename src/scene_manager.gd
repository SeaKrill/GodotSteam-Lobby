extends Node

signal finished_loading
signal end_game

var loading_screen = preload("res://ui/loading_screen.tscn")

var changing_scenes := false

#FIXME add in a "finished_loading" signal to maps that need to be recieved before scene fully transitions
func change_scene(next: String):
	if changing_scenes: return
	changing_scenes = true
	var screen = loading_screen.instantiate()
	ResourceLoader.load_threaded_request(next)

	get_tree().root.add_child(screen)
	await _fade(screen, "IN")
	_load_progress(next, screen)
	
func _load_progress(next: String, screen):
	var progress = []
	while true:
		var status = ResourceLoader.load_threaded_get_status(next, progress)
		if status == ResourceLoader.THREAD_LOAD_FAILED:
			Console.add_log("[LOADER] Loading failed, returning to previous scene.")
			_fade(screen, "OUT")
			break
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var loaded_scene = ResourceLoader.load_threaded_get(next).instantiate()
			get_tree().current_scene.queue_free()
			get_tree().root.add_child(loaded_scene)
			get_tree().current_scene = loaded_scene
			#get_tree().set_deferred("current_scene", loaded_scene)
			await finished_loading
			_fade(screen, "OUT")
			break
	return

func _fade(screen, dir: String):
	var tween = get_tree().create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUINT)
	if dir == "IN":
		tween.tween_property(screen.get_node("ColorRect"), "modulate", Color(1,1,1,1), 1.0).from(Color(1,1,1,0))
		await tween.finished
		return
	if dir == "OUT":
		tween.tween_property(screen.get_node("ColorRect"), "modulate", Color(1,1,1,0), 1.0).from(Color(1,1,1,1))
		await tween.finished
		screen.queue_free()
		changing_scenes = false

