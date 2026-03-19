extends Node
class_name TurnSystem

signal turn_changed(player_name: String, player_index: int)
signal phase_changed(phase: int)
signal meeple_changed(player_index: int)

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
@onready var UI_manager = $"../UI/UIPanel"

var tile_deck: TileDeck
var current_drawn_tile: Tile = null
var last_placed_tile: Tile = null
var last_placed_cell: Vector2i = Vector2i.ZERO

func _ready() -> void:
	score_system.meeple_returned.connect(_on_meeple_returned)


func start_game() -> void:
	# Initialize players and meeples, wire score manager and deck, then start the first turn.
	players.clear()
	for i in range(GameManager.player_count):
		players.append("Player %d" % (i + 1))

	# initialize meeples per player
	_init_meeples()

	# init score manager (if present)
	var sm = get_node_or_null("../ScoreManager")
	if sm != null:
		sm.init_scores(GameManager.player_count)
	elif game_manager != null and game_manager.score_manager != null:
		# fallback to GameManager's score_manager if present
		game_manager.score_manager.init_scores(GameManager.player_count)
	else:
		push_warning("TurnSystem.start_game: ScoreManager not found, skipping score initialization.")

	# wire the deck from GameManager if available
	if game_manager != null and game_manager.tile_deck != null:
		tile_deck = game_manager.tile_deck
	else:
		push_error("TurnSystem.start_game: tile_deck not available on GameManager")

	game_active = true
	start_turn()

func _on_meeple_returned(player_index: int) -> void:
	if player_index >= 0 and player_index < remaining_meeples.size():
		remaining_meeples[player_index] += 1
		meeple_changed.emit(player_index)
		print("%s meeple returned (%d remaining)" % [players[player_index], remaining_meeples[player_index]])

func _init_meeples() -> void:
	remaining_meeples.clear()
	for i in range(players.size()):
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
		UI_manager.show_hint("Game Over! No more tiles in the deck.")
		print("No more tiles to draw. Game over!")
		game_active = false
		score_system.score_end_game(board)
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
	phase_changed.emit(phase)
	UI_manager.show_hint("Place the tile on a highlighted cell.\nRight-click or Q / E to rotate.")
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
		show_possible_placements([])
		phase = TurnPhase.PLACE_MEEPLE
		Meeple.show_placement_hints(last_placed_tile)
		UI_manager.show_hint("Click a meeple position or press SPACE to skip.")
		print("Tile placed. Left-click on this tile to place meeple, or press space to skip.")
	else:
		UI_manager.show_hint("Cannot place tile here – invalid placement.\nTry another highlighted cell.")
		print("Cannot place tile here – invalid placement.")

func place_meeple(world_click: Vector2) -> void:
	var temp: Meeple = MEEPLE_SCENE.instantiate() as Meeple
	var info = temp.get_placement_feature(last_placed_tile, world_click)
	temp.free()
	if score_system.is_segment_claimed(board, last_placed_cell, info["feature"]):
		UI_manager.show_hint("That feature is already claimed")
		print("That feature is already claimed.")
		return
	var placed = Meeple.try_place_on_board(board, last_placed_tile, world_click, current_player_index, remaining_meeples, MEEPLE_SCENE)
	if placed:
		meeple_changed.emit(current_player_index)
		UI_manager.show_hint("Meeple placed! Turn ending...")
		Meeple.hide_placement_hints(last_placed_tile)
		end_meeple_phase()

func end_meeple_phase() -> void:
	Meeple.hide_placement_hints(last_placed_tile)
	score_system.score_and_apply(board, last_placed_cell)
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
				var valid_placements = board.get_all_valid_placement(current_drawn_tile)
				show_possible_placements(valid_placements)
	elif phase == TurnPhase.PLACE_MEEPLE:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			place_meeple(board.get_global_mouse_position())
		elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
			UI_manager.show_hint("Skipping meeple placement. Turn ending...")
			print("Skipping meeple placement")
			Meeple.hide_placement_hints(last_placed_tile)
			end_meeple_phase()
