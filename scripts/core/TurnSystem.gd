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
const HIGHLIGHT_SCENE = preload("res://scenes/highlight/Highlight.tscn")

var meeples_per_player: int = 7
var remaining_meeples: Array = []
var highlight_nodes := []

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
	var valid_placements = board.get_all_valid_placement(current_drawn_tile)
	show_possible_placements(valid_placements)
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
	current_drawn_tile = tile_instance

	var valid_placements = board.get_all_valid_placement(current_drawn_tile)
	show_possible_placements(valid_placements)
	
	phase = TurnPhase.PLACE_TILE
	tile_deck.print_draw_pile()
	print("Tile drawn for", get_current_player())
	print("Place tile")


func show_possible_placements(valid_placements):
		#refresh the highlighted nodes
		for node in highlight_nodes:
			node.queue_free()
		highlight_nodes.clear()
		#new highlight
		for placement in valid_placements:
			var highlight = HIGHLIGHT_SCENE.instantiate()
			highlight.position = board.index_to_coord(placement["cell"])
			add_child(highlight)
			highlight_nodes.append(highlight)

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
		print("Tile placed. Left-click on this tile to place meeple, or press S to skip.")
	else:
		print("Cannot place tile here – invalid placement.")

func place_meeple(world_click: Vector2) -> void:
	var clicked_cell: Vector2i = board.coord_to_index(world_click)
	if not board.placed_tiles.has(clicked_cell):
		print("Meeple must be placed on an already placed tile.")
		return
	var target_tile: Tile = board.placed_tiles[clicked_cell]
	if not target_tile.can_place_meeple():
		print("That tile already has a meeple.")
		return
	if remaining_meeples[current_player_index] <= 0:
		print("No meeples remaining for", get_current_player())
		end_meeple_phase()
		return
	var meeple_node: Meeple = MEEPLE_SCENE.instantiate() as Meeple
	if meeple_node == null:
		print("Failed to instantiate meeple.")
		return
	meeple_node.set_player(current_player_index)
	target_tile.place_meeple(meeple_node)
	remaining_meeples[current_player_index] -= 1
	print("Meeple placed for", get_current_player(), "remaining:", remaining_meeples[current_player_index])
	end_meeple_phase()

func end_meeple_phase() -> void:
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
			var valid_placements = board.get_all_valid_placement(current_drawn_tile)
			show_possible_placements(valid_placements)
		elif event is InputEventKey and event.pressed:
			if event.keycode == KEY_Q:
				board.current_tile.rotate_counter_clockwise()
				var valid_placements = board.get_all_valid_placement(current_drawn_tile)
				show_possible_placements(valid_placements)
			elif event.keycode == KEY_E:
				board.current_tile.rotate_clockwise()
	elif phase == TurnPhase.PLACE_MEEPLE:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			place_meeple(board.get_global_mouse_position())
		elif event is InputEventKey and event.pressed and event.keycode == KEY_S:
			print("Skipping meeple placement")
			end_meeple_phase()
