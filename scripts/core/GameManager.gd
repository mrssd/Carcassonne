class_name GameManager extends Node

signal game_ended(message: String)

static var player_count: int = 2

@onready var board = $"../Board"
@onready var turn_system = $"../TurnSystem"
@onready var score_manager = $"../ScoreManager"

@export var tile_deck_resource: TileDeck

var tile_deck: TileDeck
var game_ended_flag: bool = false

func _ready() -> void:
	_initialize_deck()
	call_deferred("start_game")
		
## Initialize deck
# Loads the tile deck resource used for the current match.
func _initialize_deck() -> void:
	if tile_deck_resource:
		tile_deck = TileDeck.load_deck_from_resource(tile_deck_resource.resource_path)
	else:
		tile_deck = TileDeck.load_deck_from_resource("res://resources/tile_deck.tres")

## Game
# Starts the local game state for the current scene.
func start_game():
	if tile_deck == null:
		_initialize_deck()
	# Only the host places the starting tile in a LAN match to keep boards in sync.
	if not NetworkManager.is_lan_match or NetworkManager.is_host():
		_place_starting_tile()
	# Delegate player / turn initialization to TurnSystem
	if turn_system:
		turn_system.start_game()

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
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://scenes/menu/mainMenu.tscn")
