extends Control
class_name UIManager

@onready var turn_system: TurnSystem = $"../../TurnSystem"
@onready var game_manager = $"../../GameManager"
@onready var score_manager = $"../../ScoreManager"
@onready var deck_label: Label = %tile_remaining
@onready var current_action_user_display_name: Label = %current_action_user_display_name
@onready var current_action_user_status_mark: Panel = %current_action_user_status_mark
@onready var current_action_tile_texture: TextureRect = %current_action_tile
@onready var hint_label: Label = %hint_label
@onready var hint_panel: PanelContainer = %hint_panel
@onready var player_stack_container: MarginContainer = %player_stack
@onready var options_menu_trigger: Button = %options_menu_triger
@onready var in_game_options_menu: PanelContainer = %OptionsMenu
@onready var options_menu_close: Button = %options_menu_close
@onready var highlight_placement_toggle: CheckButton = %highlight_placement
@onready var hint_messages_toggle: CheckButton = %hint_messages

var highlight_placements_enabled: bool = true
var hint_messages_enabled: bool = true

# Player card references
var player_cards: Array[PanelContainer] = []
var player_card_scene = preload("res://scenes/PlayerCard/PlayerCard.tscn")
var is_stack_expanded: bool = false

# Color for each player (supports up to 5)
var player_colors = [
	Color.BLUE,
	Color.RED,
	Color.GREEN,
	Color.YELLOW,
	Color.ORANGE,
]

# Glow/shadow colors for each player
var player_glow_colors = [
	Color("#0000c712"), # Blue glow
	Color("#c7000012"), # Red glow
	Color("#00c70012"), # Green glow
	Color("#c7c70012"), # Yellow glow
	Color("#c7640012"), # Orange glow
]

func _ready() -> void:
	# Use call_deferred to ensure GameManager has initialized its deck
	call_deferred("_setup_connections")

func _setup_connections() -> void:
	# Initialize player stack
	call_deferred("_setup_player_stack")
	
	if turn_system:
		turn_system.turn_changed.connect(_on_turn_changed)
		turn_system.meeple_changed.connect(_on_meeple_changed)
		turn_system.tile_drawn.connect(_on_tile_drawn)
		# Set initial turn display
		_on_turn_changed(turn_system.get_current_player(), turn_system.current_player_index)
	
	if game_manager:
		#game_manager.game_ended.connect(_on_game_ended)
		call_deferred("_bind_deck_signal")

	if score_manager:
		score_manager.score_updated.connect(_on_score_changed)
		# Set initial score display
		_on_score_changed()

	# FIXME: NetworkManager not implemented
	#NetworkManager.action_failed.connect(_on_network_action_failed)
	
	# Connect options menu buttons
	if options_menu_trigger:
		options_menu_trigger.pressed.connect(_on_in_game_options_menu_open)
	if options_menu_close:
		options_menu_close.pressed.connect(_on_in_game_options_menu_close)
	if highlight_placement_toggle:
		highlight_placement_toggle.toggled.connect(_on_highlight_placement_toggled)
	if hint_messages_toggle:
		hint_messages_toggle.toggled.connect(_on_hint_messages_toggled)

func _on_tile_drawn(tile: Tile) -> void:
	if current_action_tile_texture and tile and tile.tile_data and tile.tile_data.tile_texture:
		current_action_tile_texture.texture = tile.tile_data.tile_texture

func _update_player_status_mark(player_index: int) -> void:
	if player_index < player_colors.size():
		var style_box = current_action_user_status_mark.get_theme_stylebox("panel") as StyleBoxFlat
		if style_box:
			style_box = style_box.duplicate()
			style_box.bg_color = player_colors[player_index]
			# Add glow effect
			if player_index < player_glow_colors.size():
				style_box.shadow_color = player_glow_colors[player_index]
				style_box.shadow_size = 8
				style_box.shadow_offset = Vector2(0, 0)
			current_action_user_status_mark.add_theme_stylebox_override("panel", style_box)

func _bind_deck_signal() -> void:
	if game_manager and game_manager.tile_deck:
		game_manager.tile_deck.deck_changed.connect(_on_deck_changed)
		# Set initial display
		_update_deck_display()

func _on_deck_changed() -> void:
	_update_deck_display()

func _update_deck_display() -> void:
	if game_manager and game_manager.tile_deck:
		var remaining = game_manager.tile_deck.get_draw_pile_size()
		var total = remaining + game_manager.tile_deck.get_discard_pile_size()
		deck_label.text = "%d / %d" % [remaining, total]

func _on_game_ended(_message: String) -> void:
	# game_over_label.text = _message
	# game_over_label.visible = true
	pass

func _update_scoreboard_display() -> void:
	pass

func show_hint(message: String) -> void:
	if not hint_messages_enabled:
		return
	hint_label.text = message
	hint_panel.show()

func hide_hint() -> void:
	hint_panel.hide()

func _on_network_action_failed(message: String) -> void:
	show_hint(message)


# ===== PLAYER STACK MANAGEMENT =====

## Initialize player cards stack
func _setup_player_stack() -> void:
	if not player_stack_container or not turn_system or not score_manager:
		return
	
	# Ensure mouse filter allows detection
	player_stack_container.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Create a Control node to manage the stack layout
	var stack_control = Control.new()
	stack_control.mouse_filter = Control.MOUSE_FILTER_STOP # Changed to STOP so it captures mouse events
	player_stack_container.add_child(stack_control)
	
	# Create player cards for each player
	for i in range(turn_system.players.size()):
		var card = player_card_scene.instantiate() as PlayerCardUI
		stack_control.add_child(card)
		player_cards.append(card)
		
		# Set player index on the card for identification
		card.set_player_index(i)
		
		# Position card with stack flow effect to the right
		card.set_stack_position(i)
		
		# Update initial player info
		_update_player_card(i)
		
		# Set border color based on player color
		if i < player_colors.size():
			card.set_border_color(player_colors[i])
		
		# Set as current turn if this player is starting
		if i == turn_system.current_player_index:
			card.set_current_turn(true)
		else:
			card.set_current_turn(false)
	
	# Setup hover detection on the stack control
	stack_control.mouse_entered.connect(_on_player_stack_hovered)
	stack_control.mouse_exited.connect(_on_player_stack_unhovered)

## Update a specific player card with current data
func _update_player_card(player_index: int) -> void:
	if player_index < 0 or player_index >= player_cards.size():
		return
	
	var card = player_cards[player_index]
	var player_name = turn_system.players[player_index]
	var score = score_manager.get_score(player_index)
	var meeples = turn_system.remaining_meeples[player_index] if player_index < turn_system.remaining_meeples.size() else 0
	
	# TODO: Load player avatar from assets (currently using default from PlayerCard.tscn)
	var avatar: Texture2D = null
	
	card.update_player_info(player_name, avatar, meeples, score)

## Handle turn change - reorganize card stack
func _on_turn_changed(player_name: String, player_index: int) -> void:
	current_action_user_display_name.text = "%s's turn" % player_name
	_update_player_status_mark(player_index)
	
	# Collapse stack before reorganizing
	if is_stack_expanded:
		_animate_stack_expansion(false)
	
	# Update card visual states for new current turn
	for card in player_cards:
		if card:
			# Check the card's actual player index, not the array position
			card.set_current_turn(card.get_player_index() == player_index)
	
	# Reorder cards so current player is on top/left
	_reorder_player_cards(player_index)

## Reorder cards so current turn player is at the top/leftmost position
func _reorder_player_cards(current_player_index: int) -> void:
	if not player_stack_container or player_cards.is_empty():
		return
	
	var stack_control = player_stack_container.get_child(0)
	if not stack_control:
		return
	
	# Calculate new order: current player first, then others in circular order
	var new_order: Array[int] = []
	for i in range(turn_system.players.size()):
		new_order.append((current_player_index + i) % turn_system.players.size())
	
	# Rearrange children based on new order
	for display_position in range(new_order.size()):
		var original_index = new_order[display_position]
		stack_control.move_child(player_cards[original_index], display_position)
		
		# Update position with new stacking order to show flow to the right
		var card = player_cards[original_index] as PlayerCardUI
		if card:
			card.set_stack_position(display_position)

## Handle player meeple changes
func _on_meeple_changed(player_index: int) -> void:
	_update_player_card(player_index)
	_update_scoreboard_display()

## Handle score changes
func _on_score_changed(player_index := -1, _new_score := -1) -> void:
	if player_index >= 0 and player_index < player_cards.size():
		_update_player_card(player_index)
	else:
		# Update all cards if no specific player
		for i in range(player_cards.size()):
			_update_player_card(i)

## Handle stack hover for expansion animation
func _on_player_stack_hovered() -> void:
	is_stack_expanded = true
	_animate_stack_expansion(true)

## Handle stack unhover to collapse
func _on_player_stack_unhovered() -> void:
	is_stack_expanded = false
	_animate_stack_expansion(false)

## Animate stack expansion/collapse
func _animate_stack_expansion(expand: bool) -> void:
	if player_cards.is_empty():
		return
	
	# Create tween for smooth animation
	var tween = create_tween()
	tween.set_trans(Tween.TransitionType.TRANS_QUAD)
	tween.set_ease(Tween.EaseType.EASE_OUT)
	tween.set_parallel(true) # Run all animations in parallel
	
	if expand:
		# Expand: spread cards to the right with larger spacing to show all cards
		for i in range(player_cards.size()):
			var card = player_cards[i]
			var offset_x = 210 * i
			tween.tween_property(card, "position:x", offset_x, 0.4)
	else:
		# Collapse: stack cards back together with flowing effect to the right
		for i in range(player_cards.size()):
			var card = player_cards[i]
			var offset_x = 20 * i # Compact stacking with flow to right
			tween.tween_property(card, "position:x", offset_x, 0.4)

func _on_highlight_placement_toggled(pressed: bool) -> void:
	highlight_placements_enabled = pressed
	if not pressed and turn_system:
		turn_system.show_possible_placements([])

func _on_hint_messages_toggled(pressed: bool) -> void:
	hint_messages_enabled = pressed
	if not pressed:
		hint_panel.hide()

## Open options menu
func _on_in_game_options_menu_open() -> void:
	if in_game_options_menu:
		in_game_options_menu.visible = true

## Close options menu
func _on_in_game_options_menu_close() -> void:
	if in_game_options_menu:
		in_game_options_menu.visible = false
