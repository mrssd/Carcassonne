extends Node
class_name TurnSystem

enum TurnPhase {
	DRAW_TILE,
	PLACE_TILE
}

var players = ["Player 1", "Player 2"]
var current_player_index := 0
var phase := TurnPhase.DRAW_TILE
var game_active := false

@onready var board: Board = $"../Board"
@export var tile_deck_resource: TileDeck   # your deck resource
var tile_deck: TileDeck
var current_drawn_tile: Tile = null

func _ready() -> void:
	if tile_deck_resource:
		tile_deck = tile_deck_resource
	else:
		push_error("TurnSystem: tile_deck_resource not set!")

func get_current_player() -> String:
	return players[current_player_index]

func start_turn() -> void:
	print("Turn started:", get_current_player())
	phase = TurnPhase.DRAW_TILE
	draw_tile()

func draw_tile() -> void:
	if tile_deck == null:
		push_error("TurnSystem: tile_deck is null.")
		return
	
	var tile_data: CarcassonneTileData = tile_deck.draw_next_tile()
	if tile_data == null:
		print("No more tiles to draw.")
		return
	
	# instance tile
	var tile_instance: Tile = board.tile_scene.instantiate()
	tile_instance.tile_data = tile_data
	board.add_child(tile_instance)
	board.current_tile = tile_instance
	
	phase = TurnPhase.PLACE_TILE
	print("Tile drawn for", get_current_player())
	print("Place tile")

func on_tile_placed() -> void:
	if not game_active:
		return
	if phase != TurnPhase.PLACE_TILE:
		return
	if board.current_tile == null:
		return
	
	var world_pos: Vector2 = board.current_tile.position
	var cell: Vector2i = board.coord_to_index(world_pos)
	
	if board.can_place(cell, board.current_tile):
		board.place_tile(cell, board.current_tile)
		board.current_tile = null
		end_turn()
	else:
		print("Cannot place tile here – invalid placement.")

func end_turn() -> void:
	print("Turn ended:", get_current_player())
	next_turn()
	start_turn()

func next_turn() -> void:
	current_player_index = (current_player_index + 1) % players.size()

func _input(event) -> void:
	if not game_active:
		return
	if board.current_tile == null:
		return
	
	if event.is_action_pressed("ui_accept"):
		on_tile_placed()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_Q or event.keycode == KEY_LEFT:
			board.current_tile.rotate_counter_clockwise()
		elif event.keycode == KEY_E or event.keycode == KEY_RIGHT:
			board.current_tile.rotate_clockwise()