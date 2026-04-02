extends Camera2D

const SPEED: float = 900.0
const ZOOM_STEP: float = 0.1
const MIN_ZOOM: float = 0.4
const MAX_ZOOM: float = 2.0

func _process(delta):
	var camera_coord := Vector2.ZERO
	if Input.is_action_pressed("cam_left"):
		camera_coord.x -= 1
	if Input.is_action_pressed("cam_right"):
		camera_coord.x += 1
	if Input.is_action_pressed("cam_up"):
		camera_coord.y -= 1
	if Input.is_action_pressed("cam_down"):
		camera_coord.y += 1

	if camera_coord != Vector2.ZERO:
		camera_coord = camera_coord.normalized()
		global_position += camera_coord * SPEED * delta

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_apply_zoom(-ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_apply_zoom(ZOOM_STEP)
	#For touchpad zooming
	elif event is InputEventPanGesture:
		_apply_zoom(event.delta.y * ZOOM_STEP)
	elif event is InputEventMagnifyGesture:
		zoom = (zoom * event.factor).clamp(Vector2.ONE * MIN_ZOOM, Vector2.ONE * MAX_ZOOM)

#Applies zoom
func _apply_zoom(delta: float) -> void:
	zoom = (zoom + Vector2.ONE * delta).clamp(Vector2.ONE * MIN_ZOOM, Vector2.ONE * MAX_ZOOM)
