extends Node2D

const TileScene = preload("res://scenes/tile/tile.tscn")

var current_tile: Tile

func _ready() -> void:
	#temporal place of tile deck initialization 
	var tile_deck: TileDeck = TileDeck.load_deck_from_resource("res://resources/tile_deck.tres")
	tile_deck.print_draw_pile()
	
	# starting tile is always on top of the generated pile of tiles
	_spawn_tile(tile_deck.draw_next_tile())
	

func _spawn_tile(data: CarcassonneTileData) -> void:
	if current_tile:
		current_tile.queue_free()
	current_tile = TileScene.instantiate() # duplicate so rotations don't mutate the resource
	current_tile.position = get_viewport_rect().size / 2 # center of screen
	current_tile.tile_data = data
	add_child(current_tile)
	_print_debug()

func _input(event: InputEvent) -> void:
	if not current_tile:
		return
	if event.is_action_pressed("ui_right"): # → key: rotate clockwise
		current_tile.rotate_clockwise()
		_print_debug()
	elif event.is_action_pressed("ui_left"): # ← key: rotate counter-clockwise
		current_tile.rotate_counter_clockwise()
		_print_debug()

func _print_debug() -> void:
	var d = current_tile.tile_data
	print("--- Tile: %s | rotation: %d ---" % [d.name, current_tile.rotation_count])
	print("  TOP:    %s" % CarcassonneTileData.PropertyType.keys()[d.edge[0]])
	print("  RIGHT:  %s" % CarcassonneTileData.PropertyType.keys()[d.edge[1]])
	print("  BOTTOM: %s" % CarcassonneTileData.PropertyType.keys()[d.edge[2]])
	print("  LEFT:   %s" % CarcassonneTileData.PropertyType.keys()[d.edge[3]])
	print("top edge: ", CarcassonneTileData.property_type_to_string(current_tile.get_edge(0)))
