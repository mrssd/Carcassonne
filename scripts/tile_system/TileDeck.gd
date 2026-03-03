extends Resource

class_name TileDeck

# resource arrays for tile deck
# CarcassineTileData object is followed by the 
@export var tiles: Array[TileDeckEntry] = []

var _draw_pile: Array[CarcassonneTileData] = []
var _discard_pile: Array[CarcassonneTileData] = []

## Call this once at game start, passing all your loaded .tres tile resources
func load_deck(tile_resources: Array[TileDeckEntry]) -> void:
	_draw_pile.clear()
	_discard_pile.clear()
	for single_tile_entry in tile_resources:
		for i in single_tile_entry.number_of_tiles:
			_draw_pile.append(single_tile_entry.carcassone_tile_data.duplicate(true))
	_draw_pile.shuffle()

func pop_tile() -> CarcassonneTileData:
	if _draw_pile.is_empty():
		return null
	var tile = _draw_pile.pop_back()
	_discard_pile.append(tile)
	return tile

## Return an unplaceable tile to the bottom of the draw pile.
func return_tile(tile: CarcassonneTileData) -> void:
	_draw_pile.push_front(tile)

func get_remaining_tiles() -> int:
	return _draw_pile.size()
	
func get_discard_pile() -> Array[CarcassonneTileData]:
	return _discard_pile

func next_tile() -> CarcassonneTileData:
	if _draw_pile.is_empty():
		return null
	return _draw_pile.back()

func print_draw_pile() -> void:
	print("Content of the _draw_pile:")
	for tile in _draw_pile:
		tile.print_debug()

func _shuffle() -> void:
	_draw_pile.shuffle()
