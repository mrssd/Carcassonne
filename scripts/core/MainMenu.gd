extends Node

var player_count: int = 2
var count_label: Label
var status_label: Label
var players_label: Label
var ip_input: LineEdit
var port_input: LineEdit
var host_start_button: Button

func _ready() -> void:
	var vbox = $VBoxContainer

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
	var panel_box := VBoxContainer.new()
	panel_box.add_theme_constant_override("separation", 8)
	panel.add_child(panel_box)

	var title := Label.new()
	title.text = "LAN Multiplayer"
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_box.add_child(title)

	var row_ip := HBoxContainer.new()
	ip_input = LineEdit.new()
	ip_input.placeholder_text = "Host IP"
	ip_input.text = "127.0.0.1"
	ip_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_ip.add_child(ip_input)

	port_input = LineEdit.new()
	port_input.placeholder_text = str(NetworkManager.DEFAULT_PORT)
	port_input.text = str(NetworkManager.DEFAULT_PORT)
	port_input.custom_minimum_size = Vector2(120, 0)
	row_ip.add_child(port_input)
	panel_box.add_child(row_ip)

	var row_buttons := HBoxContainer.new()
	var host_button := Button.new()
	host_button.text = "Host LAN"
	host_button.pressed.connect(_on_host_pressed)
	row_buttons.add_child(host_button)

	var join_button := Button.new()
	join_button.text = "Join LAN"
	join_button.pressed.connect(_on_join_pressed)
	row_buttons.add_child(join_button)

	host_start_button = Button.new()
	host_start_button.text = "Start Match"
	host_start_button.visible = false
	host_start_button.pressed.connect(_on_host_start_pressed)
	row_buttons.add_child(host_start_button)
	panel_box.add_child(row_buttons)

	status_label = Label.new()
	status_label.text = "Offline"
	status_label.add_theme_color_override("font_color", Color.WHITE)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_box.add_child(status_label)

	players_label = Label.new()
	players_label.add_theme_color_override("font_color", Color.WHITE)
	panel_box.add_child(players_label)

	vbox.add_child(panel)

# Starts hosting a LAN lobby on the configured port.
func _on_host_pressed() -> void:
	var err := NetworkManager.host_game(player_count, _get_port())
	if err != OK:
		status_label.text = "Could not host on port %d" % _get_port()
	_refresh_lobby()

# Joins a LAN lobby using the configured host IP and port.
func _on_join_pressed() -> void:
	var err := NetworkManager.join_game(ip_input.text.strip_edges(), _get_port())
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

# Parses the port field and falls back to the default LAN port when empty.
func _get_port() -> int:
	var port := int(port_input.text)
	if port <= 0:
		return NetworkManager.DEFAULT_PORT
	return port
