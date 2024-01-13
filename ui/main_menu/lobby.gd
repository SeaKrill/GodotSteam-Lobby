extends Control

@onready var server = preload("res://ui/main_menu/lobby_server.tscn")
@onready var player = preload("res://ui/main_menu/lobby_player.tscn")

@onready var output = $Container/Lobby/Chat/Scroll/Output

var join_id := 0

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	Steam.lobby_match_list.connect(_update_lobbies)
	Steam.lobby_chat_update.connect(_on_lobby_chat_update)
	Steam.lobby_message.connect(_on_lobby_message)
	
	Networking.player_list_changed.connect(_on_player_list_changed)
	Networking.connection_success.connect(_on_connection_success)
	Networking.connection_failed.connect(_on_connection_failed)
	Networking.game_error.connect(_on_game_error)
	
#region BUTTON FUNCTIONS
func _on_create_pressed():
	Networking.lobby_name = "%s's Lobby" % Steam.getFriendPersonaName(SteamInit.steam_id)
	$Container/CreateLobby/LobbyName.text = Networking.lobby_name
	$Container/JoinLobby.hide()
	$Container/CreateLobby.show()

func _on_host_pressed():
	Networking.host_game()
	$Container/CreateLobby.hide()

func _on_join_pressed():
	Networking.join_game(join_id)
	
#DEBUG LOCAL
#func _on_create_pressed():
	#Networking.create_socket()
	#
#func _on_join_pressed():
	#Networking.connect_socket(0)
	
@rpc("call_local", "reliable")
func _on_leave_pressed():
	Networking.reset_network()
	for _player in $Container/Lobby/Players.get_children():
		_player.queue_free()
	
	$Container/Lobby.hide()
	$Container/JoinLobby.show()
	$Container/Lobby/Choice/StartGame.disabled = true
	
func _on_kick_pressed(id: int):
	_on_leave_pressed.rpc_id(id)
	
func _on_cancel_pressed(_cancel: int):
	match _cancel:
		0:
			self.hide()
		1:
			$Container/CreateLobby.hide()
			$Container/JoinLobby.show()
	
func _on_availability_pressed(num: int):
	var availability = $Container/CreateLobby/Availability
	for i in availability.get_child_count():
		if i == num: continue
		availability.get_child(i).button_pressed = false
	Networking.lobby_type = num
	
func _on_lobby_name_text_changed(text):
	Networking.lobby_name = text
	$Container/Lobby/Label.text = text
	
func _on_start_pressed():
	Networking.begin_game()
#endregion

#region LOBBY BROWSER
func _update_lobbies(lobbies: Array):
	for _lobby in lobbies:
		var _name: String = Steam.getLobbyData(_lobby, "name")
		var _type: String = Steam.getLobbyData(_lobby, "mode")
		var _nums: int = Steam.getNumLobbyMembers(_lobby)
		var _server = server.instantiate()
		_server.get_node("Button").connect("pressed", Callable(self, "_on_lobby_selected").bind(_lobby))
		_server.get_node("Button").set_text(_name)
		_server.get_node("Amount").set_text("%s/%s" % [_nums, SteamInit.MAX_PEERS])
		_server.get_node("Private").button_pressed = int(_type) == 2
		
		$Container/JoinLobby/Lobbies/Scroll/List.add_child(_server)
	$Container/JoinLobby/Search/Refresh.set_disabled(false)
	
func _refresh_lobbies():
	for _lobby in $Container/JoinLobby/Lobbies/Scroll/List.get_children():
		_lobby.queue_free()
		
	$Container/JoinLobby/Search/Refresh.set_disabled(true)
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	Steam.requestLobbyList()
	
func _on_lobby_selected(_lobby_id: int):
	join_id = _lobby_id
#endregion

#region LOBBY FUNCTIONS
func _on_player_list_changed():
	if multiplayer.is_server(): _update_player_list.rpc(Networking.players)
	
@rpc("call_local", "reliable")
func _update_player_list(_players):
	await get_tree().process_frame
	Networking.players_ready = []
	for _player in $Container/Lobby/Players.get_children():
		_player.queue_free()

	for _player in _players:
		await get_tree().process_frame
		var _steam_id: int = _players[_player]
		var _name: String = Steam.getFriendPersonaName(_steam_id)
		var _p = player.instantiate()
		_p.name = str(_player)
		_p.get_node("Player").text = _name
		_p.get_node("Kick").connect("pressed", Callable(self, "_on_kick_pressed").bind(_player))
		_p.get_node("Ready").connect("pressed", Callable(self, "_ready_pressed"))
		$Container/Lobby/Players.add_child(_p, true)
		if SteamInit.steam_id != _steam_id:
			_p.get_node("Ready").disabled = true
		if SteamInit.steam_id == Steam.getLobbyOwner(Networking.lobby_id):
			_p.get_node("Kick").show()
			
func _ready_pressed():
	_on_ready_pressed.rpc()
			
@rpc("any_peer", "call_local", "reliable")
func _on_ready_pressed():
	var id = multiplayer.get_remote_sender_id()
	var btn = $Container/Lobby/Players.get_node("%s/Ready" % str(id))
	if Networking.players_ready.has(id):
		Networking.players_ready.erase(id)
		btn.text = "Ready"
	else:
		Networking.players_ready.append(id)
		btn.text = "Unready"
		
	var start_game = multiplayer.is_server() and Networking.players_ready.size() == Steam.getNumLobbyMembers(Networking.lobby_id)
	$Container/Lobby/Choice/StartGame.disabled = !start_game
		
#endregion

#region CHAT FUNCTIONS
func _on_lobby_chat_update(_lobby_id, changed_user_steam_id, user_made_change_steam_id, chat_state):
	match chat_state:
		Steam.CHAT_MEMBER_STATE_CHANGE_ENTERED:
			output.set_text("Player joined lobby %s\n" % changed_user_steam_id)
		Steam.CHAT_MEMBER_STATE_CHANGE_LEFT:
			output.set_text("Player left the lobby %s\n" % changed_user_steam_id)
		Steam.CHAT_MEMBER_STATE_CHANGE_KICKED:
			output.set_text("Player %s was kicked by %s\n" % [changed_user_steam_id, user_made_change_steam_id])
		Steam.CHAT_MEMBER_STATE_CHANGE_BANNED:
			output.set_text("Player %s was banned by %s\n" % [changed_user_steam_id, user_made_change_steam_id])
		Steam.CHAT_MEMBER_STATE_CHANGE_DISCONNECTED:
			output.set_text("Player disconnected %s\n" % [changed_user_steam_id, user_made_change_steam_id])
			
func _on_lobby_message(_result: int, _user: int, message: String, _type: int):
	var sender = Steam.getFriendPersonaName(_user)
	if _type == 1:
		output.append_text(str(sender)+": "+str(message)+"\n")
	else:
		match _type:
			2: Console.add_log(str(sender)+" is typing...\n")
			3: Console.add_log(str(sender)+" sent an invite that won't work in this chat!\n")
			4: Console.add_log(str(sender)+" sent a text emote that is deprecated.\n")
			6: Console.add_log(str(sender)+" has left the chat.\n")
			7: Console.add_log(str(sender)+" has entered the chat.\n")
			8: Console.add_log(str(sender)+" was kicked!\n")
			9: Console.add_log(str(sender)+" was banned!\n")
			10:Console.add_log(str(sender)+" disconnected.\n")
			11: Console.add_log(str(sender)+" sent an old, offline message.\n")
			12: Console.add_log(str(sender)+" sent a link that was removed by the chat filter.\n")

func _on_send_chat_pressed(message: String = "") -> void:
	if message.length() == 0: message = $Container/Lobby/Input/Input.get_text()
	if message.length() > 0:
		var is_sent: bool = Steam.sendLobbyChatMsg(Networking.lobby_id, message)
		if not is_sent:
			Console.add_log("[ERROR] Chat message '"+str(message)+"' failed to send.\n")
		$Container/Lobby/Input/Input.clear()
#endregion

#region SIGNALS AND HELPERS
func _on_connection_success():
	$Container/Lobby/Label.text = Steam.getLobbyData(Networking.lobby_id, "name")
	show()
	$Container/JoinLobby.hide()
	$Container/Lobby.show()
	Console.add_log("Connection Success")

func _on_connection_failed():
	Networking.reset_network()
	$Container/JoinLobby.show()
	$Container/Lobby.hide()
	Console.add_log("Connection Failed")

func _on_game_error(errtxt: String):
	Networking.reset_network()
	var availability = $Container/CreateLobby/Availability
	for i in availability.get_child_count():
		if i == Networking.lobby_type:
			availability.get_child(i).button_pressed = true
			continue
		availability.get_child(i).button_pressed = false
	$Container/JoinLobby.show()
	$Container/Lobby.hide()
	Console.add_log(errtxt)
	
#endregion
