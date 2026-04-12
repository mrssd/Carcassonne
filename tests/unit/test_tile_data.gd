extends GutTest

var tile_data: CarcassonneTileData

func before_each():
	tile_data = CarcassonneTileData.new()
	tile_data.edge = [
		CarcassonneTileData.PropertyType.ROAD,
		CarcassonneTileData.PropertyType.CITY,
		CarcassonneTileData.PropertyType.FIELD,
		CarcassonneTileData.PropertyType.NONE
	]

func test_rotate_clockwise_shifts_edges():
	tile_data.rotate_clockwise()
	assert_eq(tile_data.edge[0], CarcassonneTileData.PropertyType.NONE)
	assert_eq(tile_data.edge[1], CarcassonneTileData.PropertyType.ROAD)
	assert_eq(tile_data.edge[2], CarcassonneTileData.PropertyType.CITY)
	assert_eq(tile_data.edge[3], CarcassonneTileData.PropertyType.FIELD)

func test_rotate_counter_clockwise_shifts_edges():
	tile_data.rotate_counter_clockwise()
	assert_eq(tile_data.edge[0], CarcassonneTileData.PropertyType.CITY)
	assert_eq(tile_data.edge[1], CarcassonneTileData.PropertyType.FIELD)
	assert_eq(tile_data.edge[2], CarcassonneTileData.PropertyType.NONE)
	assert_eq(tile_data.edge[3], CarcassonneTileData.PropertyType.ROAD)

func test_four_clockwise_rotations_returns_to_original():
	var original = tile_data.edge.duplicate()
	for i in range(4):
		tile_data.rotate_clockwise()
	assert_eq(tile_data.edge, original)

func test_four_counter_clockwise_rotations_returns_to_original():
	var original = tile_data.edge.duplicate()
	for i in range(4):
		tile_data.rotate_counter_clockwise()
	assert_eq(tile_data.edge, original)

func test_clockwise_then_counter_clockwise_is_identity():
	var original = tile_data.edge.duplicate()
	tile_data.rotate_clockwise()
	tile_data.rotate_counter_clockwise()
	assert_eq(tile_data.edge, original)

func test_internal_connections_rotate_with_edges():
	tile_data.internal_connections = {"road_0": [0, 2]}
	tile_data.rotate_clockwise()
	assert_true(tile_data.internal_connections["road_0"].has(1))
	assert_true(tile_data.internal_connections["road_0"].has(3))

func test_field_internal_connections_use_mod8():
	tile_data.internal_connections = {"field_0": [6, 7]}
	tile_data.rotate_clockwise()
	assert_true(tile_data.internal_connections["field_0"].has(0))
	assert_true(tile_data.internal_connections["field_0"].has(1))
