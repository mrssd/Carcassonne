# class wraper to keep TileData and number of copies in one typed array
class_name TileDeckEntry extends Resource

@export var carcassone_tile_data: CarcassonneTileData
# number of identical tiles, cannot be less than 0 and more than 9
# as Carcassonne does not feature tiles with that number of copies
# less than 0 because if you do not set 1 explicitly, it is not included in resources
@export_range(0, 9) var number_of_copies: int
