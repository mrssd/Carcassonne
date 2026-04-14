extends Node

const DEFAULT_PLAYER_COUNT: int = 2
const DEFAULT_PORT: int = 7000
const MAX_PLAYERS: int = 5
const MIN_PLAYERS: int = 2

var network_manager: NetworkManager
var is_hosting: bool = false
var is_joining: bool = false
var discovery_timer: float = 0.0
var selected_player_count: int = DEFAULT_PLAYER_COUNT

func _ready() -> void:
	# Get reference to NetworkManager (should be autoload)
	network_manager = get_node("/root/NetworkManager") as NetworkManager
	if network_manager == null:
		push_error("NetworkManager not found as autoload")
		return
	
	MusicManager.play_menu_music()
	%back_menu.move_to_front()
	
	# Clear logs
	var logs_label = get_node_or_null("%logs")
	if logs_label != null:
		logs_label.text = "Ready"
	
	# Connect signals
	%back_menu.pressed.connect(_on_back_pressed)
	%host_lan.pressed.connect(_on_host_lan_pressed)
	%join_lan.pressed.connect(_on_join_lan_pressed)
	%start_match.pressed.connect(_on_start_match_pressed)
	%add_bot_player.pressed.connect(_on_add_player_pressed)
	%remove_bot_player.pressed.connect(_on_remove_player_pressed)
	
	# Connect network signals
	network_manager.lobby_updated.connect(_on_lobby_updated)
	network_manager.status_changed.connect(_on_status_changed)
	network_manager.action_failed.connect(_on_action_failed)
	
	# Set default port
	%port.text = str(DEFAULT_PORT)
	
	# Initialize player count display
	selected_player_count = DEFAULT_PLAYER_COUNT
	%players.text = str(selected_player_count)
	
	# Update lobby display
	_update_lobby_display()

func _process(delta: float) -> void:
	# If we're joining, periodically discover servers
	if is_joining and network_manager:
		discovery_timer += delta
		if discovery_timer >= 0.5: # Update discovery every 0.5 seconds
			_update_discovered_servers()
			discovery_timer = 0.0

func _on_host_lan_pressed() -> void:
	var username = %user_name.text
	var port_text = %port.text
	
	if username.is_empty():
		_show_error("Please enter a display name")
		return
	
	if port_text.is_empty():
		_show_error("Please enter a port number")
		return
	
	var port = int(port_text)
	if port < 1024 or port > 65535:
		_show_error("Port must be between 1024 and 65535")
		return
	
	is_hosting = true
	is_joining = false
	
	# Start hosting with selected player count
	var err = network_manager.host_game(selected_player_count, username, port)
	if err != OK:
		_show_error("Failed to host game: %s" % error_string(err))
		is_hosting = false
		return
	
	_append_log("Hosting started on port %d for %d players" % [port, selected_player_count])
	
	# Get local IPv4 address
	var local_ip = IP.get_local_addresses()
	var ipv4_address = ""
	for ip in local_ip:
		if not ip.contains(":"): # IPv4 addresses don't contain colons
			ipv4_address = ip
			break
	if not ipv4_address.is_empty():
		_append_log("Your IP: %s" % ipv4_address)
	
	_update_ui_for_hosting()

func _on_join_lan_pressed() -> void:
	var username = %user_name.text
	var host_ip = %ip_input.text
	var port_text = %port.text
	
	if username.is_empty():
		_show_error("Please enter a display name")
		return
	
	if host_ip.is_empty():
		_show_error("Please enter a host IP address")
		return
	
	if port_text.is_empty():
		_show_error("Please enter a port number")
		return
	
	var port = int(port_text)
	if port < 1024 or port > 65535:
		_show_error("Port must be between 1024 and 65535")
		return
	
	is_joining = true
	is_hosting = false
	
	# Start discovering servers
	network_manager.start_client_discovery()
	
	# Start joining
	var err = network_manager.join_game(host_ip, username, port)
	if err != OK:
		_show_error("Failed to join game: %s" % error_string(err))
		is_joining = false
		return
	
	_append_log("Attempting to join %s:%d" % [host_ip, port])
	
	_update_ui_for_joining()

func _on_start_match_pressed() -> void:
	if not is_hosting:
		_show_error("Only the host can start the match")
		return
	
	if network_manager.player_peer_ids.size() < DEFAULT_PLAYER_COUNT:
		_show_error("Waiting for %d players, have %d" % [DEFAULT_PLAYER_COUNT, network_manager.player_peer_ids.size()])
		return
	
	_append_log("Starting match...")
	network_manager.start_lan_match()

func _on_lobby_updated() -> void:
	_update_lobby_display()

func _on_status_changed(message: String) -> void:
	print("Network Status: %s" % message)
	_append_log("Status: %s" % message)

func _on_action_failed(message: String) -> void:
	_show_error("Network Error: %s" % message)

func _on_back_pressed() -> void:
	# Clean up network session before leaving
	if network_manager:
		network_manager.reset_session()
	get_tree().change_scene_to_file("res://scenes/menu/mainMenu.tscn")

func _on_add_player_pressed() -> void:
	if selected_player_count < MAX_PLAYERS:
		selected_player_count += 1
		%players.text = str(selected_player_count)
		_append_log("Player count increased to %d" % selected_player_count)

func _on_remove_player_pressed() -> void:
	if selected_player_count > MIN_PLAYERS:
		selected_player_count -= 1
		%players.text = str(selected_player_count)
		_append_log("Player count decreased to %d" % selected_player_count)

func _update_lobby_display() -> void:
	var player_names = network_manager.get_player_names()
	var display_text = ""
	
	if is_hosting:
		display_text = "Players connected: %d/%d\n" % [player_names.size(), DEFAULT_PLAYER_COUNT]
	else:
		display_text = "Players connected: %d\n" % player_names.size()
	
	if player_names.is_empty():
		display_text += "No players connected"
	else:
		for i in range(player_names.size()):
			display_text += "%d. %s\n" % [i + 1, player_names[i]]
	
	%players_lobby.text = display_text

func _update_discovered_servers() -> void:
	if not is_joining:
		return
	
	var servers = network_manager.get_discovered_servers()
	if servers.is_empty():
		return
	
	# Auto-populate IP if servers are discovered (use the first one)
	if servers.size() > 0 and %ip_input.text.is_empty():
		%ip_input.text = servers[0]["ip"]
		_append_log("Server discovered: %s (%s)" % [servers[0]["name"], servers[0]["ip"]])

func _update_ui_for_hosting() -> void:
	%user_name.editable = false
	%port.editable = false
	%ip_input.editable = false
	
	%host_lan.disabled = true
	%join_lan.disabled = true
	%start_match.disabled = false
	
	# Hide player count controls - hide the entire container
	var player_controls = get_node_or_null("VBoxContainer/Panel2/VBoxContainer/MarginContainer3/MarginContainer2")
	if player_controls:
		player_controls.visible = false

func _update_ui_for_joining() -> void:
	%user_name.editable = false
	%ip_input.editable = false
	%port.editable = false
	
	%host_lan.disabled = true
	%join_lan.disabled = true
	%start_match.disabled = true
	
	# Hide player count controls - hide the entire container
	var player_controls = get_node_or_null("VBoxContainer/Panel2/VBoxContainer/MarginContainer3/MarginContainer2")
	if player_controls:
		player_controls.visible = false

func _show_error(message: String) -> void:
	print("ERROR: %s" % message)
	_append_log("ERROR: %s" % message)

func _append_log(message: String) -> void:
	"""Append a message to the logs label"""
	var logs_label = get_node_or_null("%logs")
	if logs_label == null:
		return
	
	var current_text = logs_label.text
	if current_text.is_empty():
		logs_label.text = message
	else:
		logs_label.text = current_text + "\n" + message
	
	# Keep only the last 5 lines to prevent overflow
	var lines = logs_label.text.split("\n")
	if lines.size() > 5:
		lines = lines.slice(lines.size() - 5, lines.size())
		logs_label.text = "\n".join(lines)
