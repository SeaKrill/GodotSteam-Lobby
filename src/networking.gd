extends Node

signal player_list_changed()
signal connection_failed()
signal connection_success()
signal game_ended()
signal game_error(err)

const DEFAULT_PORT = 4000

var peer = null

var players := {}
var players_ready := []

var lobby_id := -1
var lobby_type := 0
var lobby_name : String

func _ready():
	multiplayer.peer_connected.connect(_player_connected)
	multiplayer.peer_disconnected.connect(_player_disconnected)
	multiplayer.connected_to_server.connect(_connected_ok)
	multiplayer.connection_failed.connect(_connected_fail)
	multiplayer.server_disconnected.connect(_server_disconnected)
	
	Steam.join_requested.connect(_on_lobby_join_requested)
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)

#region LOBBY FUNCTION
func host_game():
	Steam.createLobby(lobby_type, SteamInit.MAX_PEERS)
	Console.add_log("Host Pressed")
	
func join_game(_lobby_id: int):
	Steam.joinLobby(_lobby_id)
	
func _on_lobby_join_requested(_lobby_id: int, friend_id: int):
	var OWNER_NAME = Steam.getFriendPersonaName(friend_id)
	Console.add_log("[STEAM] Joining "+str(OWNER_NAME)+"'s lobby...")
	join_game(_lobby_id)
	
func _on_lobby_created(_connect: int, _lobby_id: int):
	if _connect == 1:
		lobby_id = _lobby_id
		Steam.setLobbyData(_lobby_id, "name", lobby_name)
		Steam.setLobbyData(_lobby_id, "mode", str(lobby_type))
		Console.add_log("Lobby Created")
		create_socket()
	else:
		connection_failed.emit()
		Console.add_log("Error creating lobby")

func _on_lobby_joined(_lobby_id: int, _permissions: int, _locked: bool, response: int):
	if response == 1:
		var id = Steam.getLobbyOwner(_lobby_id)
		if id != Steam.getSteamID():
			lobby_id = _lobby_id
			lobby_name = Steam.getLobbyData(lobby_id, "name")
			Console.add_log("Joined Lobby")
			connect_socket(id)
	else:
		# Get the failure reason
		var FAIL_REASON: String
		match response:
			2:  FAIL_REASON = "This lobby no longer exists."
			3:  FAIL_REASON = "You don't have permission to join this lobby."
			4:  FAIL_REASON = "The lobby is now full."
			5:  FAIL_REASON = "Uh... something unexpected happened!"
			6:  FAIL_REASON = "You are banned from this lobby."
			7:  FAIL_REASON = "You cannot join due to having a limited account."
			8:  FAIL_REASON = "This lobby is locked or disabled."
			9:  FAIL_REASON = "This lobby is community locked."
			10: FAIL_REASON = "A user in the lobby has blocked you from joining."
			11: FAIL_REASON = "A user you have blocked is in the lobby."
		Console.add_log(FAIL_REASON)
		
func create_socket():
	peer = SteamMultiplayerPeer.new()
	peer.create_host(DEFAULT_PORT, [])
	multiplayer.set_multiplayer_peer(peer)
	Console.add_log("Host Created")
	
	_player_connected(1)
	connection_success.emit()

func connect_socket(steam_id : int):
	peer = SteamMultiplayerPeer.new()
	peer.create_client(steam_id, DEFAULT_PORT, [])
	multiplayer.set_multiplayer_peer(peer)
	Console.add_log("Client Created")
#endregion

#region GAME FUNCTION
func begin_game():
	assert(multiplayer.is_server())
	load_world.rpc()

@rpc("call_local", "reliable")
func load_world():
	SceneManager.change_scene("res://multiplayer/world.tscn")
	Console.add_log("Loaded World:")
	Console.add_log(str(get_tree().root))

#region PLAYER STATUS
func _player_connected(id):
	players[id] = peer.get_steam64_from_peer_id(id)
	player_list_changed.emit()
	Console.add_log("Connected: %s" % id)

func _player_disconnected(id):
	players.erase(id)
	players_ready.erase(id)
	player_list_changed.emit()
	Console.add_log("Disconnected: %s" % id)

#region HELPERS AND SIGNALS
func _connected_ok():
	connection_success.emit()

func _server_disconnected():
	reset_network()
	game_error.emit("Server disconnected")

func _connected_fail():
	connection_failed.emit()
	
func reset_network():
	multiplayer.multiplayer_peer.close()
	Steam.leaveLobby(lobby_id)
	players = {}
	players_ready = []
	peer = null
	lobby_id = 0
	lobby_type = 0
#endregion
