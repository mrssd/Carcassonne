extends GutTest

var board: Board

const ROAD = CarcassonneTileData.PropertyType.ROAD
const CITY = CarcassonneTileData.PropertyType.CITY
const FIELD = CarcassonneTileData.PropertyType.FIELD

func _make_tile(top, right, bottom, left) -> CarcassonneTileData:
	var td = CarcassonneTileData.new()
	td.edge[0] = top
	td.edge[1] = right
	td.edge[2] = bottom
	td.edge[3] = left
	td.internal_connections = {}
	return td

func _make_tile_node(top, right, bottom, left) -> Tile:
	var t = Tile.new()
	t.tile_data = _make_tile(top, right, bottom, left)
	return t

func before_each():
	board = Board.new()

func after_each():
	for cell in board.placed_tiles.keys():
		board.placed_tiles[cell].free()
	board.free()

func test_first_tile_can_always_be_placed():
	var tile = _make_tile_node(ROAD, FIELD, ROAD, FIELD)
	assert_true(board.can_place(Vector2i(0, 0), tile))
	tile.free()

func test_cannot_place_on_occupied_cell():
	var tile = _make_tile_node(FIELD, FIELD, FIELD, FIELD)
	board.placed_tiles[Vector2i(0, 0)] = tile
	var incoming = _make_tile_node(FIELD, FIELD, FIELD, FIELD)
	assert_false(board.can_place(Vector2i(0, 0), incoming))
	incoming.free()

func test_no_neighbor_blocks_placement():
	var placed = _make_tile_node(FIELD, FIELD, FIELD, FIELD)
	board.placed_tiles[Vector2i(0, 0)] = placed
	var incoming = _make_tile_node(FIELD, FIELD, FIELD, FIELD)
	assert_false(board.can_place(Vector2i(2, 0), incoming))
	incoming.free()

func test_edge_mismatch_blocks_placement():
	# placed tile has ROAD on bottom (index 2)
	var placed = _make_tile_node(FIELD, FIELD, ROAD, FIELD)
	board.placed_tiles[Vector2i(0, 0)] = placed
	# tile below needs ROAD on top (index 0) — use CITY instead to force mismatch
	var incoming = _make_tile_node(CITY, FIELD, FIELD, FIELD)
	assert_false(board.can_place(Vector2i(0, 1), incoming))
	incoming.free()

func test_edge_match_allows_placement():
	var placed = _make_tile_node(FIELD, FIELD, ROAD, FIELD)
	board.placed_tiles[Vector2i(0, 0)] = placed
	var incoming = _make_tile_node(ROAD, FIELD, FIELD, FIELD)
	assert_true(board.can_place(Vector2i(0, 1), incoming))
	incoming.free()

func test_city_edge_match_allows_placement():
	var placed = _make_tile_node(FIELD, CITY, FIELD, FIELD)
	board.placed_tiles[Vector2i(0, 0)] = placed
	var incoming = _make_tile_node(FIELD, FIELD, FIELD, CITY)
	assert_true(board.can_place(Vector2i(1, 0), incoming))
	incoming.free()

func test_get_all_valid_placement_single_tile_gives_four_neighbors():
	var tile = _make_tile_node(FIELD, FIELD, FIELD, FIELD)
	board.placed_tiles[Vector2i(0, 0)] = tile
	var incoming = _make_tile_node(FIELD, FIELD, FIELD, FIELD)
	var results = board.get_all_valid_placement(incoming)
	var cells = results.map(func(r): return r["cell"])
	assert_eq(cells.size(), 4)
	assert_true(cells.has(Vector2i(0, -1)))
	assert_true(cells.has(Vector2i(1, 0)))
	assert_true(cells.has(Vector2i(0, 1)))
	assert_true(cells.has(Vector2i(-1, 0)))
	incoming.free()

func test_get_all_valid_placement_excludes_occupied_cells():
	var F = FIELD
	var t1 = _make_tile_node(F, F, F, F)
	var t2 = _make_tile_node(F, F, F, F)
	board.placed_tiles[Vector2i(0, 0)] = t1
	board.placed_tiles[Vector2i(1, 0)] = t2
	var incoming = _make_tile_node(F, F, F, F)
	var results = board.get_all_valid_placement(incoming)
	var cells = results.map(func(r): return r["cell"])
	assert_false(cells.has(Vector2i(0, 0)))
	assert_false(cells.has(Vector2i(1, 0)))
	incoming.free()
