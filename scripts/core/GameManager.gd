class_name GameManager extends Node

signal game_ended(message: String)

static var player_count: int = 2

@onready var board = $"../Board"
@onready var turn_system = $"../TurnSystem"
@onready var score_manager = $"../ScoreManager"

@export var tile_deck_resource: TileDeck

var tile_deck: TileDeck
var game_ended_flag: bool = false
var match_started: bool = false

func _ready() -> void:
	_initialize_deck()
	call_deferred("_complete_scene_setup")
		
## Initialize deck
# Loads the tile deck resource used for the current match.
func _initialize_deck() -> void:
	if tile_deck_resource:
		tile_deck = TileDeck.load_deck_from_resource(tile_deck_resource.resource_path)
	else:
		tile_deck = TileDeck.load_deck_from_resource("res://resources/tile_deck.tres")

func _complete_scene_setup() -> void:
	var ready := await _wait_for_scene_dependencies("scene setup")
	if not ready:
		push_error("GameManager: scene dependencies did not become ready")
		return
	print("GameManager: scene dependencies ready. lan=%s host=%s" % [NetworkManager.is_lan_match, NetworkManager.is_host()])
	if NetworkManager.is_lan_match:
		NetworkManager.notify_game_scene_ready()
	else:
		begin_network_match()

func begin_network_match() -> void:
	if match_started:
		return
	call_deferred("_begin_match_when_ready")

func has_started_match() -> bool:
	return match_started

func _begin_match_when_ready() -> void:
	if match_started:
		return
	var ready := await _wait_for_scene_dependencies("match start")
	if not ready:
		push_error("GameManager: could not start match because dependencies are missing")
		return
	match_started = true
	print("GameManager: begin match. lan=%s host=%s" % [NetworkManager.is_lan_match, NetworkManager.is_host()])
	if tile_deck == null:
		_initialize_deck()
	# Only the host places the starting tile in a LAN match to keep boards in sync.
	if not NetworkManager.is_lan_match or NetworkManager.is_host():
		_place_starting_tile()
	# Delegate player / turn initialization to TurnSystem
	if turn_system:
		turn_system.start_game()

func _wait_for_scene_dependencies(context: String, max_frames: int = 120) -> bool:
	for _i in range(max_frames):
		if _are_scene_dependencies_ready():
			return true
		await get_tree().process_frame
	print("GameManager: waiting for scene dependencies timed out during %s" % context)
	return _are_scene_dependencies_ready()

func _are_scene_dependencies_ready() -> bool:
	if board == null or turn_system == null or score_manager == null:
		return false
	var ui_manager := get_node_or_null("../UI/UIPanel")
	if ui_manager == null:
		return false
	if turn_system.has_method("is_runtime_ready") and not turn_system.is_runtime_ready():
		return false
	if ui_manager.has_method("is_setup_complete") and not ui_manager.is_setup_complete():
		return false
	return true

## First tile
# Places the mandatory starting tile at the center of the board.
func _place_starting_tile() -> void:
	if board == null or tile_deck == null:
		return
	if board.tile_scene == null:
		push_error("Board.tile_scene not set!")
		return

	var starting_tile_data: CarcassonneTileData = tile_deck.draw_next_tile()
	if starting_tile_data == null:
		return

	var tile_instance: Tile = board.tile_scene.instantiate()
	tile_instance.tile_data = starting_tile_data
	board.add_child(tile_instance)
	board.place_tile(Vector2i.ZERO, tile_instance)

	# Broadcast the starting tile to non-host clients.
	if NetworkManager.is_lan_match and NetworkManager.is_host():
		NetworkManager.sync_starting_tile(starting_tile_data.name)

# Called on non-host clients via RPC to place the synced starting tile.
func receive_starting_tile(tile_name: String) -> void:
	if board == null or board.tile_scene == null:
		return
	var tile_data = TileDeck.create_tile_data_by_name(tile_name)
	if tile_data == null:
		push_error("GameManager: could not find starting tile data for '%s'" % tile_name)
		return
	var tile_instance: Tile = board.tile_scene.instantiate()
	tile_instance.tile_data = tile_data
	board.add_child(tile_instance)
	board.place_tile(Vector2i.ZERO, tile_instance)

## Game End
# Ends the match, shows the final message, then returns to the menu.
func end_game(message: String) -> void:
	game_ended_flag = true
	game_ended.emit(message)
	if NetworkManager.is_lan_match:
		NetworkManager.finish_local_match()
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://scenes/menu/mainMenu.tscn")
