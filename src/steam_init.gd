extends Node

const MAX_PEERS = 4

#FIXME Youre going to need your own app_id eventually
var app_id = 480
var steam_id
var is_online: bool
var is_game_owned: bool
var is_on_steam: bool

func _ready() -> void:
	OS.set_environment("SteamAppId", str(480))
	OS.set_environment("SteamGameId", str(480))
	print("Starting the GodotSteam Example project...")
	_initialize_Steam()

	#if IS_ON_STEAM_DECK:
		#get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN

func _initialize_Steam() -> void:
	if Engine.has_singleton("Steam"):
		var INIT: Dictionary = Steam.steamInit(false)
		if INIT['status'] != 1:
			print("[STEAM] Failed to initialize: "+str(INIT['verbal'])+" Shutting down...")
			get_tree().quit()

		is_on_steam = true
		#IS_ON_STEAM_DECK = Steam.isSteamRunningOnSteamDeck()
		is_online = Steam.loggedOn()
		is_game_owned = Steam.isSubscribed()
		steam_id = Steam.getSteamID()

		if is_game_owned == false:
			print("[STEAM] User does not own this game")
			# Uncomment this line to close the game if the user does not own the game
			#get_tree().quit()

func _process(_delta: float) -> void:
	if is_on_steam:
		Steam.run_callbacks()
