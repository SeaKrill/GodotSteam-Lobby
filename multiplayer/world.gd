extends Node

@onready var player_controller = preload("res://entities/player/player_controller.tscn")

#FIXME add in a pause that goes away once the "loading_finished" signal is called
#possibly wait for all players to finish loading?
func _enter_tree():
	get_tree().paused = true

func _ready():
	#multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(_player_disconnected)
	multiplayer.server_disconnected.connect(exit_game)
	SceneManager.end_game.connect(exit_game)
	
	if not multiplayer.is_server(): return
	await get_tree().create_timer(1.0).timeout
	for id in Networking.players:
		add_player(id, Networking.players[id])
			
	await get_tree().process_frame
	_game_loaded.rpc()
		
@rpc("call_local", "reliable")
func _game_loaded():
	SceneManager.finished_loading.emit()
	get_tree().paused = false
	
func add_player(id: int, _steam_id:int):
	var _name = Steam.getFriendPersonaName(_steam_id)
	var _player = player_controller.instantiate()
	_player.steam_id = _steam_id
	_player.name = str(id)
	$Players.call_deferred("add_child", _player)
	Console.add_log("Spawned: %s, %s" % [id, _name])
	
func _player_disconnected(id: int):
	rpc("_delete_player", id)
	
@rpc("call_local", "reliable")
func _delete_player(id: int):
	$Players.get_node(str(id)).queue_free()

func exit_game():
	SceneManager.change_scene("res://ui/main_menu/main_menu.tscn")
	Networking.reset_network()
