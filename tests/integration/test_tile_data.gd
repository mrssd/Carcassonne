extends GutTest

var tile_data: CarcassonneTileData

func before_each():
    tile_data = CarcassonneTileData.new()
    tile_data.edge = [
        CarcassonneTileData.PropertyType.ROAD, #top
        CarcassonneTileData.PropertyType.CITY,  #right
        CarcassonneTileData.PropertyType.FIELD, #bottom
        CarcassonneTileData.PropertyType.NONE #left
    ]

func test_rotate_clockwise_shifts_edges():
    tile_data.rotate_clockwise()
    assert_eq(tile_data.edge[0], CarcassonneTileData.PropertyType.NONE) #left to top
    assert_eq(tile_data.edge[1], CarcassonneTileData.PropertyType.ROAD) #top to right
    assert_eq(tile_data.edge[2], CarcassonneTileData.PropertyType.CITY) #right to bottom
    assert_eq(tile_data.edge[3], CarcassonneTileData.PropertyType.FIELD) #bottom to left

func test_four_rotations_returns_to_original():                                                                                                                                                                
    var original = tile_data.edge.duplicate()                                                                                                                                                                  
    for i in range(4):                                                                                                                                                                                         
        tile_data.rotate_clockwise()                                                                                                                                                                           
    assert_eq(tile_data.edge, original)                                                                                                                                                                        
                                                                                                                                                                                                                 
func test_clockwise_then_counterclockwise_is_identity():                                                                                                                                                       
      var original = tile_data.edge.duplicate()                                                                                                                                                                  
      tile_data.rotate_clockwise()                                                                                                                                                                               
      tile_data.rotate_counter_clockwise()                                                                                                                                                                       
      assert_eq(tile_data.edge, original)                                                                                                                                                                        
                                                                                                                                                                                                                 
func test_internal_connections_rotate_with_edges():                                                                                                                                                            
      tile_data.internal_connections = {"road_0": [0, 2]}  #top and bottom                                                                                                                                      
      tile_data.rotate_clockwise()                                                                                                                                                                               
      #edge index 0 → 1 edge index 2 → 3                                                                                                                                                                       
      assert_true(tile_data.internal_connections["road_0"].has(1))                                                                                                                                               
      assert_true(tile_data.internal_connections["road_0"].has(3))     