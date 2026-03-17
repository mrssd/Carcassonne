extends Node2D

const CELL_SIZE := 96

func _ready():
    queue_redraw() 

func _draw():
    var color = Color(1, 1, 0, 0.8) 
    var thickness = 4
    draw_rect(Rect2(Vector2(-CELL_SIZE / 2, -CELL_SIZE / 2), Vector2(CELL_SIZE, CELL_SIZE)), color, false, thickness)
