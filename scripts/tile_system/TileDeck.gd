class_name TileDeck extends Resource

## Class variables

# resource array to be filled in the editor with tile data and number of copies for each tile type
@export var tiles: Array[TileDeckEntry] = []
# internal arrays to manage the draw and discard piles - initialized in load_deck_from_array
var _draw_pile: Array[CarcassonneTileData]
var _discard_pile: Array[CarcassonneTileData]

## Call this once at game start to initialize the tile deck

# to create a deck, simply follow the following initialization pattern:
# var tile_deck: TileDeck = TileDeck.load_deck_from_resource("res://resources/tile_deck.tres")
static func load_deck_from_resource(path: String) -> TileDeck:
	var deck: TileDeck = load(path)
	if deck == null:
		push_error("TileDeck: Failed to load deck from path: " + path)
		return null
	return deck.load_deck_from_array(deck.tiles)

func load_deck_from_array(tile_resources: Array[TileDeckEntry]) -> TileDeck:
	# Always create fresh arrays to avoid shared reference issues with Resources
	_draw_pile = []
	_discard_pile = []
	
	if tile_resources.is_empty():
		push_error("TileDeck: tile_resources array is empty!")
		return self
	
	for i in range(tile_resources.size() - 1):
		var single_tile_entry: TileDeckEntry = tile_resources[i]
		if single_tile_entry == null:
			push_warning("TileDeck: tile_resources[%d] is null, skipping" % i)
			continue
		if single_tile_entry.carcassone_tile_data == null:
			push_warning("TileDeck: tile_resources[%d].carcassone_tile_data is null, skipping" % i)
			continue
		for j in range(single_tile_entry.number_of_copies):
			_draw_pile.append(single_tile_entry.carcassone_tile_data.duplicate(true))
	
	_draw_pile.shuffle()
	
	# add the starting tile on top of the pile
	# starting tile should always come last in the TileDeck resource file
	var starting_entry: TileDeckEntry = tile_resources[-1]
	if starting_entry != null and starting_entry.carcassone_tile_data != null:
		_draw_pile.append(starting_entry.carcassone_tile_data.duplicate(true))
	else:
		push_error("TileDeck: Starting tile (last entry) is null or has no tile data!")
	
	print("TileDeck initialized with %d tiles" % _draw_pile.size())
	return self

## Most useful class methods

# pops a tile from the draw pile and adds it to the discard pile, returns the drawn tile
func draw_next_tile() -> CarcassonneTileData:
	if _draw_pile.is_empty():
		print("Error! Cannot draw next tile, _draw_pile is empty.")
		return null
	var tile = _draw_pile.pop_back()
	_discard_pile.append(tile)
	return tile

# returns the next tile without modifying the piles
func peek_next_tile() -> CarcassonneTileData:
	if _draw_pile.is_empty():
		return null
	return _draw_pile.back()

# returns an unplaceable tile to the bottom of the draw pile
# use if the tile was drawn prior
func return_drawn_tile(tile: CarcassonneTileData) -> void:
	_discard_pile.pop_back()
	_draw_pile.push_front(tile)

# use if the next tile in the draw pile cannot be placed
func return_peeked_tile() -> void:
	_draw_pile.push_front(_draw_pile.pop_back())

func get_draw_pile_size() -> int:
	return _draw_pile.size()

func get_discard_pile_size() -> int:
	return _discard_pile.size()

## Debugging function
func print_draw_pile() -> void:
	print("Size of the draw pile: ", get_draw_pile_size())
	print("Size of the discard pile: ", get_discard_pile_size())
	print("Content of the _draw_pile:")
	var i:int = 0
	for tile in _draw_pile:
		print(" > #", i)
		i += 1
		tile.print_debug()
