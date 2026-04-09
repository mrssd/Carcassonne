class_name GameManager extends Node

signal game_ended(message: String)

static var player_count: int = 2
static var player_types: Array = [] #array for cpu and human player

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
func _initialize_deck() -> void:
	if tile_deck_resource:
		tile_deck = TileDeck.load_deck_from_resource(tile_deck_resource.resource_path)
	else:
		tile_deck = TileDeck.load_deck_from_resource("res://resources/tile_deck.tres")

## Game
func start_game():
	if tile_deck == null:
		_initialize_deck()
	_place_starting_tile()
	if turn_system:
		turn_system.start_game()

## First tile
func _place_starting_tile() -> void:
	if board == null or tile_deck == null:
		return
	if board.tile_scene == null:
		push_error("Board.tile_scene not set!")
		return

	var starting_tile_data: CarcassonneTileData = tile_deck.draw_next_tile()
	if starting_tile_data == null:
		return

	## Placing the tile
	var tile_instance: Tile = board.tile_scene.instantiate()
	tile_instance.tile_data = starting_tile_data
	board.add_child(tile_instance)
	board.place_tile(Vector2i.ZERO, tile_instance)

## Game End
func end_game(message: String) -> void:
	game_ended_flag = true
	# Short delay so end-game score animations finish before the overlay appears
	await get_tree().create_timer(1.5).timeout
	game_ended.emit(message)
