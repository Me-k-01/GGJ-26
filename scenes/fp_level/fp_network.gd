extends Node

const SERVER_ADDRESS: String = "127.0.0.1"
const SERVER_PORT: int = 8080
const MAX_PLAYERS : int = 10

var players = {}
var player_info = {
	"nick" : "host",
	"skin" : Character.SkinColor.BLUE,
}

signal player_connected(peer_id, player_info)
signal server_disconnected

func _ready() -> void:
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.connected_to_server.connect(_on_connected_ok)

# --- AUTHORITY LOGIC ---

@rpc("authority", "call_local", "reliable")
func _set_global_physics_authority(new_owner_id: int):
	# Find all physics objects. 
	# IMPORTANT: Add your RigidBodies to a group called "sync_physics"
	var bodies = get_tree().get_nodes_in_group("sync_physics")
	
	for body in bodies:
		if body is RigidBody3D or body is RigidBody2D:
			# 1. Update the body itself
			body.set_multiplayer_authority(new_owner_id)
			
			# 2. Update the Synchronizer (prevents the infinite loop error)
			for child in body.get_children():
				if child is MultiplayerSynchronizer:
					child.set_multiplayer_authority(new_owner_id)
			
			# 3. Handle Physics State
			# Only the new authority simulates; others are "puppets"
			if multiplayer.get_unique_id() == new_owner_id:
				body.freeze = false
			else:
				body.freeze = true

# --- NETWORK EVENTS ---

func _on_player_connected(id: int):
	if multiplayer.is_server():
		# Every time someone joins, they become the "Master of Physics"
		_set_global_physics_authority.rpc(id)
		
	if DisplayServer.get_name() == "headless":
		return
	_register_player.rpc_id(id, player_info)

func _on_player_disconnected(id: int):
	players.erase(id)
	# Safety: If the last client leaves, give authority back to the server (ID 1)
	if multiplayer.is_server():
		_set_global_physics_authority.rpc(1)

# --- BOILERPLATE / CONNECTION ---

func start_host(nickname: String, skin_color_str: String):
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(SERVER_PORT, MAX_PLAYERS)
	if error: return error
	multiplayer.multiplayer_peer = peer

	player_info["nick"] = nickname if nickname.strip_edges() != "" else "Host"
	player_info["skin"] = skin_str_to_e(skin_color_str)
	
	players[1] = player_info
	player_connected.emit(1, player_info)
	_set_global_physics_authority(1) # Host starts as owner

func join_game(nickname: String, skin_color_str: String, address: String = SERVER_ADDRESS):
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, SERVER_PORT)
	if error: return error
	multiplayer.multiplayer_peer = peer

	player_info["nick"] = nickname if nickname.strip_edges() != "" else "Player"
	player_info["skin"] = skin_str_to_e(skin_color_str)

func _on_connected_ok():
	var peer_id = multiplayer.get_unique_id()
	players[peer_id] = player_info
	player_connected.emit(peer_id, player_info)

@rpc("any_peer", "reliable")
func _register_player(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	players[new_player_id] = new_player_info
	player_connected.emit(new_player_id, new_player_info)

func _on_connection_failed():
	multiplayer.multiplayer_peer = null

func _on_server_disconnected():
	multiplayer.multiplayer_peer = null
	players.clear()
	server_disconnected.emit()

func skin_str_to_e(s):
	match s.to_lower():
		"blue": return Character.SkinColor.BLUE
		"yellow": return Character.SkinColor.YELLOW
		"green": return Character.SkinColor.GREEN
		"red": return Character.SkinColor.RED
		_: return Character.SkinColor.BLUE
