extends Node
class_name TurnSystem #script name

enum TurnPhase { #enum is a group of const ints
	DRAW_TILE, # Turn phases for a Carcassonne
	PLACE_TILE,
	PLACE_MEEPLE
}

var players = ["Player 1", "Player 2"]
var current_player_index := 0
var phase := TurnPhase.DRAW_TILE

func _ready(): 
	start_turn()

func get_current_player(): # returns the current player based on the index
	return players[current_player_index]

func start_turn(): # beginning of turn
	print("Turn stared:", get_current_player())
	phase = TurnPhase.DRAW_TILE
	draw_tile()

func draw_tile():
	print("Tile drawn for", get_current_player())
	phase = TurnPhase.PLACE_TILE # on to the next phase 
	print("Place tile")

func on_tile_placed(): # called when a tile is placed checks if it's the right phase
	if phase != TurnPhase.PLACE_TILE:
		return
	print("Tile placed by", get_current_player())
	phase = TurnPhase.PLACE_MEEPLE # on to the next phase 
	print("Place meeple or skip")

func on_meeple_placed_or_skipped(): # checks if meeple step is done
	if phase != TurnPhase.PLACE_MEEPLE:
		return
	end_turn()

func end_turn():
	print("Turn ended:", get_current_player())
	next_turn()
	start_turn()

func next_turn(): # rotate player logic
	current_player_index = (current_player_index + 1) % players.size()
	# 0 -> 1 -> 0 -> 1 ...

func _input(event):
	if event.is_action_pressed("ui_accept"):
		on_tile_placed()
	if event.is_action_pressed("ui_select"):
		on_meeple_placed_or_skipped()
