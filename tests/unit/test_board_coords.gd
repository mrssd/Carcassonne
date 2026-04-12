extends GutTest

var board: Board

func before_each():
	board = Board.new()

func after_each():
	board.free()

func test_coord_to_index_origin():
	assert_eq(board.coord_to_index(Vector2(0, 0)), Vector2i(0, 0))

func test_coord_to_index_positive():
	assert_eq(board.coord_to_index(Vector2(128, 256)), Vector2i(1, 2))

func test_coord_to_index_negative():
	assert_eq(board.coord_to_index(Vector2(-128, -256)), Vector2i(-1, -2))

func test_index_to_coord_origin():
	assert_eq(board.index_to_coord(Vector2i(0, 0)), Vector2(0, 0))

func test_index_to_coord_positive():
	assert_eq(board.index_to_coord(Vector2i(2, 3)), Vector2(256, 384))

func test_index_to_coord_roundtrip():
	var idx = Vector2i(3, -2)
	var world = board.index_to_coord(idx)
	assert_eq(board.coord_to_index(world), idx)

func test_snap_to_grid_already_aligned():
	assert_eq(board.snap_to_grid(Vector2(128, 256)), Vector2(128, 256))

func test_snap_to_grid_rounds_to_nearest():
	var snapped = board.snap_to_grid(Vector2(70, 190))
	assert_eq(snapped, Vector2(128.0, 128.0))

func test_snap_to_grid_negative_coords():
	var snapped = board.snap_to_grid(Vector2(-70, -190))
	assert_eq(snapped, Vector2(-128.0, -128.0))
