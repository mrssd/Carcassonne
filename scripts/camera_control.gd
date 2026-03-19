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
	if event.is_action_pressed("zoom_in"):
		zoom = (zoom - Vector2.ONE * ZOOM_STEP).clamp(Vector2.ONE * MIN_ZOOM, Vector2.ONE * MAX_ZOOM)
	if event.is_action_pressed("zoom_out"):
		zoom = (zoom + Vector2.ONE * ZOOM_STEP).clamp(Vector2.ONE * MIN_ZOOM, Vector2.ONE * MAX_ZOOM)
	
	# Keyboard shortcuts for zoom with + and - keys
	if event is InputEventKey and event.pressed:
		if event.physical_keycode == KEY_MINUS:
			zoom = (zoom - Vector2.ONE * ZOOM_STEP).clamp(Vector2.ONE * MIN_ZOOM, Vector2.ONE * MAX_ZOOM)
		elif event.physical_keycode == KEY_PLUS or event.physical_keycode == KEY_EQUAL:
			zoom = (zoom + Vector2.ONE * ZOOM_STEP).clamp(Vector2.ONE * MIN_ZOOM, Vector2.ONE * MAX_ZOOM)
