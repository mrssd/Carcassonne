#is new and now owns LAN session state:
#whether a LAN match is active, expected player count, peer IDs, usernames,
#host/client setup, lobby sync, peer removal, and username sanitization. That
#means NetworkManager no longer stores and mutates all of that state directly.


class_name NetworkSession
extends RefCounted

const MAX_PLAYERS: int = 5

var is_lan_match: bool = false
var expected_player_count: int = 2
var player_peer_ids: Array[int] = []
var player_usernames: Dictionary = {}
var local_username: String = "Player"

func reset() -> void:
	is_lan_match = false
	expected_player_count = 2
	player_peer_ids.clear()
	player_usernames.clear()
	local_username = "Player"

func configure_host(peer_id: int, player_count: int, username: String) -> void:
	is_lan_match = true
	expected_player_count = clamp(player_count, 2, MAX_PLAYERS)
	local_username = sanitize_username(username)
	player_peer_ids = [peer_id]
	player_usernames = {peer_id: local_username}

func configure_client(username: String) -> void:
	is_lan_match = true
	local_username = sanitize_username(username)

func sync_lobby(peer_ids: Array[int], player_count: int, usernames: Dictionary) -> void:
	player_peer_ids = peer_ids.duplicate()
	expected_player_count = player_count
	player_usernames = usernames.duplicate(true)
	is_lan_match = true

func register_peer(peer_id: int, username: String) -> void:
	if not player_peer_ids.has(peer_id):
		player_peer_ids.append(peer_id)
		player_peer_ids.sort()
	player_usernames[peer_id] = sanitize_username(username)

func remove_peer(peer_id: int) -> void:
	player_peer_ids.erase(peer_id)
	player_usernames.erase(peer_id)

func is_host(local_peer_id: int) -> bool:
	return is_lan_match and local_peer_id == 1

func get_local_player_index(local_peer_id: int) -> int:
	return player_peer_ids.find(local_peer_id)

func get_player_names() -> Array[String]:
	var names: Array[String] = []
	for peer_id in player_peer_ids:
		names.append(player_usernames.get(peer_id, "Player %d" % (names.size() + 1)))
	return names

func sanitize_username(username: String) -> String:
	var cleaned := username.strip_edges()
	if cleaned.is_empty():
		return "Player"
	return cleaned.substr(0, 20)
