# the foundational tile class
# its properties include:
#	1) name
#	2) texture
#	3) edges
#	4) internal connections

class_name CarcassonneTileData extends Resource

enum PropertyType {
	NONE, FIELD, ROAD, CITY, MONASTERY, RIVER
}
enum Orientation {
	TOP, RIGHT, BOTTOM, LEFT
}

@export var name: String = "Unnamed Tile"
@export var tile_texture: Texture2D = null

#Variables for monestary and shield
@export var is_monastery : bool;
@export var has_shield: bool;

## Array for tile edges. Array indexing:
# 0 - top
# 1 - right
# 2 - bottom
# 3 - left
@export var edge: Array[PropertyType] = [
	PropertyType.NONE,
	PropertyType.NONE,
	PropertyType.NONE,
	PropertyType.NONE
]

## Dictionary for maintaining edges of the graph as pairs of numbers
# should be implemented together with scoring
@export var internal_connections: Dictionary = {}

## Dictionary holding positions for possible meeple placement
# Vector2i holds the position relatively to the CENTER of the tile
# x and y variables are in the range between -2 and 2
# (0,0) is the coordinate of the center
@export var meeple_positions: Dictionary[Vector2i, PropertyType] = {}

## "public" functions
func rotate_clockwise():
	var tmp = edge[0]
	edge[0] = edge[3]
	edge[3] = edge[2]
	edge[2] = edge[1]
	edge[1] = tmp
	_rotate_internal_connections_clockwise()

func rotate_counter_clockwise():
	var tmp = edge[0]
	edge[0] = edge[1]
	edge[1] = edge[2]
	edge[2] = edge[3]
	edge[3] = tmp
	_rotate_internal_connections_counter_clockwise()

func print_debug() -> void:
	print("Tile name: ", name)
	for i in range(edge.size()):
		print(i, " - ", orientation_to_string(i), ": ", property_type_to_string(edge[i]))

static func property_type_to_string(value: PropertyType) -> String:
	match value:
		PropertyType.NONE: return "none"
		PropertyType.FIELD: return "field"
		PropertyType.ROAD: return "road"
		PropertyType.CITY: return "city"
		PropertyType.MONASTERY: return "monastery"
		PropertyType.RIVER: return "river"
		_: return "unknown property type"

static func orientation_to_string(value: Orientation) -> String:
	match value:
		Orientation.TOP: return "TOP"
		Orientation.RIGHT: return "RIGHT"
		Orientation.BOTTOM: return "BOTTOM"
		Orientation.LEFT: return "LEFT"
		_: return "incorrect orientation"

#Function to apply internal_connection data (calling from TileDeck.gd)
func apply_segment_data():
	match self.name:
		"city4":
			internal_connections = {"city_0": [0, 1, 2, 3]}
			has_shield = true
		"city3":
			internal_connections = {"city_0": [0, 1, 3], "field_0": [3, 4, 5, 6]}
		"city3sr":
			internal_connections = {"city_0": [0, 1, 3], "road_0": [2], "field_0": [3, 4], "field_1": [5, 6]}
			has_shield = true
		"city3s":
			internal_connections = {"city_0": [0, 1, 3], "field_0": [3, 4, 5, 6]}
			has_shield = true
		"city3r":
			internal_connections = {"city_0": [0, 1, 3], "road_0": [2], "field_0": [3, 4], "field_1": [5, 6]}
		"city2wes":
			internal_connections = {"city_0": [1, 3], "field_0": [0, 1, 2, 7], "field_1": [3, 4, 5, 6]}
			has_shield = true
		"city2we":
			internal_connections = {"city_0": [1, 3], "field_0": [0, 1, 2, 7], "field_1": [3, 4, 5, 6]}
		"city2nwsr":
			internal_connections = {"city_0": [0, 3], "road_0": [1, 2], "field_0": [1, 2, 5, 6], "field_1": [3, 4]}
			has_shield = true
		"city2nws":
			internal_connections = {"city_0": [0, 3], "field_0": [1, 2, 3, 4, 5, 6]}
			has_shield = true
		"city2nwr":
			internal_connections = {"city_0": [0, 3], "road_0": [1, 2], "field_0": [1, 2, 5, 6], "field_1": [3, 4]}
		"city2nw":
			internal_connections = {"city_0": [0, 3], "field_0": [1, 2, 3, 4, 5, 6]}
		"city1rwe":
			internal_connections = {"city_0": [0], "road_0": [1, 3], "field_0": [0, 1, 2, 7], "field_1": [3, 4, 5, 6]}
		"city1rswe":
			internal_connections = {"city_0": [0], "road_0": [1], "road_1": [2], "road_2": [3], "field_0": [0, 1, 2, 7], "field_1": [3, 4], "field_2": [5, 6]}
		"city1rsw":
			internal_connections = {"city_0": [0], "road_0": [2, 3], "field_0": [0, 1, 2, 3, 4, 7], "field_1": [5, 6]}
		"city1rse":
			internal_connections = {"city_0": [0], "road_0": [1, 2], "field_0": [0, 1, 2, 5, 6, 7], "field_1": [3, 4]}
		"city1":
			internal_connections = {"city_0": [0], "field_0": [0, 1, 2, 3, 4, 5, 6, 7]}
		"city11ne":
			internal_connections = {"city_0": [0], "city_1": [1], "field_0": [0, 3, 4, 5, 6, 7]}
		"city11we":
			internal_connections = {"city_0": [1], "city_1": [3], "field_0": [0, 1, 2, 3, 4, 5, 6, 7]}
		"cloister":
			internal_connections = {"field_0": [0, 1, 2, 3, 4, 5, 6, 7]}
			is_monastery = true
		"cloisterr":
			internal_connections = {"road_0": [2], "field_0": [0, 1, 2, 3, 4, 5, 6, 7]}
			is_monastery = true
		"start":
			internal_connections = {"city_0": [0], "road_0": [1, 3], "field_0": [0, 1, 2, 7], "field_1": [3, 4, 5, 6]}
		"road4":
			internal_connections = {"road_0": [0], "road_1": [1], "road_2": [2], "road_3": [3], "field_0": [1, 2], "field_1": [3, 4], "field_2": [5, 6], "field_3": [7, 0]}
		"road3":
			internal_connections = {"road_1": [1], "road_2": [2], "road_3": [3], "field_0": [7, 0, 1, 2], "field_1": [3, 4], "field_2": [5, 6]}
		"road2sw":
			internal_connections = {"road_0": [2, 3], "field_0": [0, 1, 2, 3, 4, 7], "field_1": [5, 6]}
		"road2ns":
			internal_connections = {"road_0": [0, 2], "field_0": [1, 2, 3, 4], "field_1": [5, 6, 7, 0]}
		_:
			push_warning("no segment data for tile '%s" % self.name)

# function which inverts y coordinate in the meeple_positions dictionary
# serves to fix the original bug of the wrong coordinate direction in the previous commit	
func invert_Y_meeple_positions() -> void:
	var temp : Dictionary[Vector2i, PropertyType] = {}
	for key in meeple_positions.keys():
		temp[Vector2i(key.x, -key.y)] = meeple_positions[key]
	meeple_positions = temp


## "private" functions
func _rotate_internal_connections_clockwise():
	for key in internal_connections:
		var edges: Array = internal_connections[key]
		for i in range(edges.size()):
			if key.begins_with("field_"):
				edges[i] = (edges[i] + 2) % 8  #mod 8 instead since fields have 8 halfedge
			else:
				edges[i] = (edges[i] + 1) % 4

func _rotate_internal_connections_counter_clockwise():
	for key in internal_connections:
		var edges: Array = internal_connections[key]
		for i in range(edges.size()):
			if key.begins_with("field_"):
				edges[i] = (edges[i] - 2 + 8) % 8  #mod 8 instead since fields have 8 halfedge
			else:
				edges[i] = (edges[i] - 1 + 4) % 4
			
func _rotate_meeple_positions_clockwise() -> void:
	var temp_dictionary: Dictionary[Vector2i, PropertyType] = {}
	for key in meeple_positions.keys() :
		var value : PropertyType = meeple_positions[key]
		var new_key = Vector2i(-key.y, key.x)
		temp_dictionary[new_key] = value
	meeple_positions = temp_dictionary
	
func _rotate_meeple_positions_counter_clockwise() -> void:
	var temp_dictionary: Dictionary[Vector2i, PropertyType] = {}
	for key in meeple_positions.keys() :
		var value : PropertyType = meeple_positions[key]
		var new_key = Vector2i(key.y, -key.x)
		temp_dictionary[new_key] = value
	meeple_positions = temp_dictionary

func _print_meeple_positions() -> void:
	print()
	for key in meeple_positions.keys():
		print(key, " -> ", property_type_to_string(meeple_positions[key]))
