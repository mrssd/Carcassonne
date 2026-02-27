extends Resource
class_name TileDeck

var _draw_pile = Array[CarcassonneTileData] = []
var _discard_pile = Array[CarcassonneTileData] = []

## Call this once at game start, passing all your loaded .tres tile resources
func load_deck(tile_resources: Array[CarcassonneTileData]) -> void:
    _draw_pile.clear()
    _discard_pile.clear()
    for tile_data in tile_resources:
        for i in tile_data.count:
            _draw_pile.append(tile_data.duplicate())
    shuffle()

func pop_tile() -> CarcassonneTileData:
    if _draw_pile.empty():
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
    if _draw_pile.empty():
        return null
    return _draw_pile.back()

func _shuffle() -> void:
    _draw_pile.shuffle()
