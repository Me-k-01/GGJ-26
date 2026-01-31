extends Node3D

var players = {}

func register_player(id: int, node: Node):
	players[id] = node

func unregister_player(id: int):
	players.erase(id)

func get_player(id: int) -> Node:
	print("TEST, ", players)
	return players.get(id)
