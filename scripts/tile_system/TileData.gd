class_name Tile

enum PropertyType {
	NONE, FIELD, ROAD, CITY, MONASTERY, RIVER
}

enum Orientation {
	TOP, RIGHT, BOTTOM, LEFT
}

## Array for tile edges. Array indexing:
## 0 - top
## 1 - right
## 2 - bottom
## 3 - left
var edge : Array[PropertyType] = [
	PropertyType.NONE,
	PropertyType.NONE,
	PropertyType.NONE,
	PropertyType.NONE
]

## Dictionary for maintaining edges of the graph as pairs of numbers
## 0 - 3 are fields
## 4 - 7 roads
## 8 - 11 cities
## 12 - 13 river
var internal_connections : Dictionary[int, Array] = {
	## example T road
	0 : [0, 1, 0, 3, 1, 3],
	1 : [1, 2],
	2 : [2, 3],
	4 : [1, 1],
	5 : [2, 2],
	6 : [3, 3] 
}

## "public" functions
func rotate_clockwise():
	var tmp = edge[0]
	edge[0] = edge[3]
	edge[3] = edge[2]
	edge[2] = edge[1]
	edge[1] = tmp
	_rotate_edges_clockwise()

func rotate_counter_clockwise():
	var tmp = edge[0]
	edge[0] = edge[1]
	edge[1] = edge[2]
	edge[2] = edge[3]
	edge[3] = tmp
	_rotate_edges_counter_clockwise()

## "private" functions
func _rotate_edges_clockwise():
	for key in internal_connections:
		var edges : Array = internal_connections[key]
		for i in edges:
			edges[i] = (edges[i] + 1) % 4

func _rotate_edges_counter_clockwise():
	for key in internal_connections:
		var edges : Array = internal_connections[key]
		for i in edges:
			edges[i] = (edges[i] - 1) % 4
