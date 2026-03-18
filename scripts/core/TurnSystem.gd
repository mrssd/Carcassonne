extends Node
class_name TurnSystem

signal turn_changed(player_name: String, player_index: int)

enum TurnPhase {
	DRAW_TILE,
	PLACE_TILE,
	PLACE_MEEPLE
}

var players = ["Player 1", "Player 2"]
var current_player_index := 0
var phase := TurnPhase.DRAW_TILE
var game_active: bool = false

const MEEPLE_SCENE: PackedScene = preload("res://scenes/meeple/Meeple.tscn")
var meeples_per_player: int = 7
var remaining_meeples: Array = []

@onready var board = $"../Board"
@onready var game_manager = $"../GameManager"
@onready var score_system = $"../ScoreSystem"

var tile_deck: TileDeck
var current_drawn_tile: Tile = null
var last_placed_tile: Tile = null
var last_placed_cell: Vector2i = Vector2i.ZERO

func _ready() -> void:
	_init_meeples()

func _init_meeples() -> void:
	remaining_meeples.clear()
	for i in players.size():
		remaining_meeples.append(meeples_per_player)

func get_current_player() -> String:
	return players[current_player_index]

func start_turn() -> void:
	print("Turn started:", get_current_player())
	turn_changed.emit(get_current_player(), current_player_index)
	phase = TurnPhase.DRAW_TILE
	draw_tile()

func draw_tile() -> void:
	if tile_deck == null:
		push_error("TurnSystem: tile_deck is null.")
		return
	
	var tile_data: CarcassonneTileData = tile_deck.draw_next_tile()
	if tile_data == null:
		print("No more tiles to draw. Game over!")
		game_active = false
		game_manager.end_game("No more tiles! Game Over!")
		return
	
	# instance tile
	var tile_instance: Tile = board.tile_scene.instantiate()
	# duplicate tile data resource so runtime rotations/mutations don't affect other instances
	tile_instance.tile_data = tile_data.duplicate(true)
	board.add_child(tile_instance)
	board.current_tile = tile_instance
	
	phase = TurnPhase.PLACE_TILE
	tile_deck.print_draw_pile()
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
		last_placed_tile = board.placed_tiles[cell]
		last_placed_cell = cell
		board.current_tile = null
		score_system.score_and_apply(board, cell, current_player_index)
		phase = TurnPhase.PLACE_MEEPLE
		Meeple.show_placement_hints(last_placed_tile)
		print("Tile placed. Left-click on this tile to place meeple, or press space to skip.")
	else:
		print("Cannot place tile here – invalid placement.")

func place_meeple(world_click: Vector2) -> void:
	var placed = Meeple.try_place_on_board(board, last_placed_tile, world_click, current_player_index, remaining_meeples, MEEPLE_SCENE)
	if placed:
		Meeple.hide_placement_hints(last_placed_tile)
		end_meeple_phase()

func end_meeple_phase() -> void:
	Meeple.hide_placement_hints(last_placed_tile)
	last_placed_tile = null
	phase = TurnPhase.DRAW_TILE
	end_turn()

func end_turn() -> void:
	print("Turn ended:", get_current_player())
	next_turn()
	start_turn()

func next_turn() -> void:
	current_player_index = (current_player_index + 1) % players.size()

func _input(event) -> void:
	if not game_active:
		return

	if phase == TurnPhase.PLACE_TILE:
		if board.current_tile == null:
			return
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				on_tile_placed()
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				board.current_tile.rotate_clockwise()
		elif event is InputEventKey and event.pressed:
			if event.keycode == KEY_Q:
				board.current_tile.rotate_counter_clockwise()
			elif event.keycode == KEY_E:
				board.current_tile.rotate_clockwise()
	elif phase == TurnPhase.PLACE_MEEPLE:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			place_meeple(board.get_global_mouse_position())
		elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
			print("Skipping meeple placement")
			Meeple.hide_placement_hints(last_placed_tile)
			end_meeple_phase()
