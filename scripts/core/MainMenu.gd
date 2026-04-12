extends Node

var player_count: int = 2
var count_label: Label
var status_label: Label
var players_label: Label
var host_ip_label: Label
var ip_input: LineEdit
var port_input: LineEdit
var username_input: LineEdit
var host_start_button: Button
var discovery_button: Button
var servers_label: Label
var selected_server: Dictionary = {}

func _ready() -> void:
	var vbox = $VBoxContainer
	vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vbox.custom_minimum_size = Vector2(0, 0)

	var start_button := $VBoxContainer/start
	var options_button := $VBoxContainer/options
	var exit_button := $VBoxContainer/exit
	start_button.custom_minimum_size = Vector2(0, 56)
	options_button.custom_minimum_size = Vector2(0, 56)
	exit_button.custom_minimum_size = Vector2(0, 56)
	start_button.add_theme_font_size_override("font_size", 28)
	options_button.add_theme_font_size_override("font_size", 28)
	exit_button.add_theme_font_size_override("font_size", 28)

	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var title = Label.new()
	title.text = "Players: "
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_font_size_override("font_size", 30)
	row.add_child(title)

	var minus_btn = Button.new()
	minus_btn.text = " - "
	minus_btn.add_theme_font_size_override("font_size", 30)
	minus_btn.pressed.connect(_on_minus_pressed)
	row.add_child(minus_btn)

	count_label = Label.new()
	count_label.text = str(player_count)
	count_label.add_theme_color_override("font_color", Color.WHITE)
	count_label.add_theme_font_size_override("font_size", 30)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.custom_minimum_size = Vector2(40, 0)
	row.add_child(count_label)

	var plus_btn = Button.new()
	plus_btn.text = " + "
	plus_btn.add_theme_font_size_override("font_size", 30)
	plus_btn.pressed.connect(_on_plus_pressed)
	row.add_child(plus_btn)

	vbox.add_child(row)
	vbox.move_child(row, 0)
	_build_network_panel(vbox)
	NetworkManager.status_changed.connect(_on_network_status_changed)
	NetworkManager.lobby_updated.connect(_refresh_lobby)
	_refresh_lobby()

func _on_minus_pressed() -> void:
	player_count = max(2, player_count - 1)
	count_label.text = str(player_count)

func _on_plus_pressed() -> void:
	player_count = min(5, player_count + 1)
	count_label.text = str(player_count)

func _on_start_pressed() -> void:
	NetworkManager.reset_session()
	GameManager.player_count = player_count
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")

func _on_options_pressed() -> void:
	pass

func _on_exit_pressed() -> void:
	get_tree().quit()

# Builds the LAN section of the menu with host/join controls.
func _build_network_panel(vbox: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 260)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.custom_minimum_size = Vector2(0, 260)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	var panel_box := VBoxContainer.new()
	panel_box.add_theme_constant_override("separation", 8)
	panel_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(panel_box)

	var title := Label.new()
	title.text = "LAN Multiplayer"
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_box.add_child(title)

	username_input = LineEdit.new()
	username_input.placeholder_text = "Username"
	username_input.text = OS.get_environment("USER")
	username_input.custom_minimum_size = Vector2(0, 36)
	panel_box.add_child(username_input)

	var row_ip := HBoxContainer.new()
	row_ip.add_theme_constant_override("separation", 8)
	ip_input = LineEdit.new()
	ip_input.placeholder_text = "Host IP (e.g. 192.168.1.5)"
	ip_input.text = ""
	ip_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip_input.custom_minimum_size = Vector2(0, 36)
	row_ip.add_child(ip_input)

	port_input = LineEdit.new()
	port_input.placeholder_text = str(NetworkManager.DEFAULT_PORT)
	port_input.text = str(NetworkManager.DEFAULT_PORT)
	port_input.custom_minimum_size = Vector2(88, 36)
	row_ip.add_child(port_input)
	panel_box.add_child(row_ip)

	var row_buttons := HBoxContainer.new()
	row_buttons.add_theme_constant_override("separation", 8)
	var host_button := Button.new()
	host_button.text = "Host LAN"
	host_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host_button.pressed.connect(_on_host_pressed)
	row_buttons.add_child(host_button)

	var join_button := Button.new()
	join_button.text = "Join LAN"
	join_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_button.pressed.connect(_on_join_pressed)
	row_buttons.add_child(join_button)

	host_start_button = Button.new()
	host_start_button.text = "Start Match"
	host_start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host_start_button.visible = false
	host_start_button.pressed.connect(_on_host_start_pressed)
	row_buttons.add_child(host_start_button)
	panel_box.add_child(row_buttons)

	# Discovery Testing Section
	var discovery_title := Label.new()
	discovery_title.text = "Auto LAN Discovery (Testing)"
	discovery_title.add_theme_color_override("font_color", Color.CYAN)
	discovery_title.add_theme_font_size_override("font_size", 17)
	discovery_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_box.add_child(discovery_title)

	var discovery_row := HBoxContainer.new()
	discovery_row.add_theme_constant_override("separation", 8)
	discovery_button = Button.new()
	discovery_button.text = "Scan for Servers"
	discovery_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	discovery_button.pressed.connect(_on_discovery_scan_pressed)
	discovery_row.add_child(discovery_button)

	var connect_discovered_btn := Button.new()
	connect_discovered_btn.text = "Connect to Selected"
	connect_discovered_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	connect_discovered_btn.pressed.connect(_on_connect_discovered_pressed)
	discovery_row.add_child(connect_discovered_btn)
	panel_box.add_child(discovery_row)

	servers_label = Label.new()
	servers_label.text = "No servers discovered"
	servers_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	servers_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	servers_label.custom_minimum_size = Vector2(0, 60)
	panel_box.add_child(servers_label)

	status_label = Label.new()
	status_label.text = "Offline"
	status_label.add_theme_color_override("font_color", Color.WHITE)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_box.add_child(status_label)

	host_ip_label = Label.new()
	host_ip_label.add_theme_color_override("font_color", Color.YELLOW)
	host_ip_label.visible = false
	panel_box.add_child(host_ip_label)

	players_label = Label.new()
	players_label.add_theme_color_override("font_color", Color.WHITE)
	players_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_box.add_child(players_label)

	vbox.add_child(panel)

# Starts hosting a LAN lobby on the configured port.
func _on_host_pressed() -> void:
	var err := NetworkManager.host_game(player_count, _get_username(), _get_port())
	if err != OK:
		status_label.text = "Could not host on port %d" % _get_port()
	_refresh_lobby()

# Joins a LAN lobby using the configured host IP and port.
func _on_join_pressed() -> void:
	var err := NetworkManager.join_game(ip_input.text.strip_edges(), _get_username(), _get_port())
	if err != OK:
		status_label.text = "Could not join %s:%d" % [ip_input.text.strip_edges(), _get_port()]
	_refresh_lobby()

# Lets the host transition all connected peers into the match scene.
func _on_host_start_pressed() -> void:
	NetworkManager.start_lan_match()

# Mirrors network status text into the menu UI.
func _on_network_status_changed(message: String) -> void:
	if status_label:
		status_label.text = message

# Refreshes the displayed lobby roster and host-only start button.
func _refresh_lobby() -> void:
	if players_label == null:
		return
	var lines: Array[String] = []
	var names = NetworkManager.get_player_names()
	for i in range(names.size()):
		var suffix := ""
		if i == NetworkManager.get_local_player_index():
			suffix = " (You)"
		lines.append("%s%s" % [names[i], suffix])
	players_label.text = "Lobby:\n%s" % ("\n".join(lines) if not lines.is_empty() else "No players connected")
	host_start_button.visible = NetworkManager.is_host()
	if host_ip_label != null:
		if NetworkManager.is_host():
			host_ip_label.text = "Your IP: %s" % _get_local_ip()
			host_ip_label.visible = true
		else:
			host_ip_label.visible = false

# Parses the port field and falls back to the default LAN port when empty.
func _get_port() -> int:
	var port := int(port_input.text)
	if port <= 0:
		return NetworkManager.DEFAULT_PORT
	return port

func _get_username() -> String:
	if username_input == null:
		return "Player"
	var username := username_input.text.strip_edges()
	if username.is_empty():
		return "Player"
	return username

func _get_local_ip() -> String:
	for addr in IP.get_local_addresses():
		if addr.begins_with("192.168.") or addr.begins_with("10.") or addr.begins_with("172."):
			return addr
	return "unknown"

# Discovery Testing Functions
func _on_discovery_scan_pressed() -> void:
	"""Start scanning for servers on the LAN"""
	status_label.text = "Scanning for servers..."
	NetworkManager.start_client_discovery()
	discovery_button.disabled = true
	await get_tree().create_timer(2.0).timeout # Wait 2 seconds for responses
	_display_discovered_servers()
	discovery_button.disabled = false

func _display_discovered_servers() -> void:
	"""Display the list of discovered servers"""
	var servers = NetworkManager.get_discovered_servers()
	
	if servers.is_empty():
		servers_label.text = "No servers found"
		status_label.text = "Scan complete: No servers found"
		return
	
	var server_text = "Discovered Servers:\n"
	for i in range(servers.size()):
		var server = servers[i]
		server_text += "[%d] %s at %s:%d\n" % [i + 1, server["name"], server["ip"], server["port"]]
	
	servers_label.text = server_text
	selected_server = servers[0] # Auto-select first server
	status_label.text = "Found %d server(s). Selected: %s" % [servers.size(), selected_server["name"]]

func _on_connect_discovered_pressed() -> void:
	"""Connect to the selected discovered server"""
	if selected_server.is_empty():
		status_label.text = "No server selected. Scan first."
		return
	
	var err := NetworkManager.join_game(
		selected_server["ip"],
		_get_username(),
		selected_server["port"]
	)
	
	if err != OK:
		status_label.text = "Failed to connect to %s:%d" % [selected_server["ip"], selected_server["port"]]
	else:
		status_label.text = "Connecting to %s..." % selected_server["name"]
	
	NetworkManager.stop_discovery()
