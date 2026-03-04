class_name GameManager extends Node

signal game_ended(message: String)

@onready var board = $"../Board"
@onready var turn_system = $"../TurnSystem"

@export var tile_deck_resource: TileDeck

var tile_deck: TileDeck
var game_ended_flag: bool = false

func _ready() -> void:
	_initialize_deck()
	call_deferred("start_game")
	
## Initialize deck
func _initialize_deck() -> void:
	if tile_deck_resource:
		tile_deck = TileDeck.load_deck_from_resource("res://resources/tile_deck.tres")

## Game
func start_game():
	if tile_deck == null:
		_initialize_deck()

	_place_starting_tile()
	

	if turn_system:
		turn_system.tile_deck = tile_deck
		turn_system.game_active = true
		turn_system.start_turn()
		print("Game started with %d players" % turn_system.players.size())

## First tile
func _place_starting_tile() -> void:
	## Checking bullshit
	if board == null or tile_deck == null:
		return
	if board.tile_scene == null:
		print("Board.tile_scene not set!")
		return

	var starting_tile_data: CarcassonneTileData = tile_deck.draw_next_tile()
	if starting_tile_data == null:
		return

	## Placing the tile
	var tile_instance: Tile = board.tile_scene.instantiate()
	tile_instance.tile_data = starting_tile_data
	board.add_child(tile_instance)
	board.place_tile(Vector2i.ZERO, tile_instance)
	print("Starting tile placed.")

## Game End
func end_game(message: String) -> void:
	game_ended_flag = true
	game_ended.emit(message)
	print("Game ended: %s" % message)
