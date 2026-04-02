extends PanelContainer

# Status colors
var online_color: Color = Color(0.2, 1.0, 0.3, 1.0) # Green
var offline_color: Color = Color(1.0, 0.4, 0.4, 1.0) # Red
var connecting_color: Color = Color(1.0, 0.9, 0.2, 1.0) # Yellow

var indicator_circle: ColorRect
var status_label: Label
var message_label: Label
var is_online: bool = false
var glow_intensity: float = 0.0
var glow_speed: float = 2.0

func _ready() -> void:
	indicator_circle = %IndicatorCircle
	status_label = %StatusLabel
	message_label = %MessageLabel
	
	# Make the circle actually round
	indicator_circle.custom_minimum_size = Vector2(20, 20)
	
	# Set initial state
	set_status(false, "Offline")

func _process(delta: float) -> void:
	# Animate the glow effect
	if is_online:
		glow_intensity = sin(get_tree().get_frame() * glow_speed * 0.03) * 0.5 + 0.5
		_update_glow()

# Sets the status with a color and message
func set_status(online: bool, message: String) -> void:
	is_online = online
	var color = online_color if online else offline_color
	
	# Update indicator circle
	indicator_circle.color = color
	
	# Update labels
	status_label.add_theme_color_override("font_color", color)
	status_label.text = "Online" if online else "Offline"
	message_label.text = message
	
	glow_intensity = 0.0

# Updates the glow shadow effect
func _update_glow() -> void:
	# Create a subtle outer glow effect using modulation
	var glow_color = indicator_circle.color
	glow_color.a = glow_intensity * 0.6
	
	# Optional: You can add a CanvasItem shader for better glow
	# For now, we'll use a simpler approach with child nodes

# Set to connecting state (yellow, pulsing)
func set_connecting() -> void:
	is_online = false
	indicator_circle.color = connecting_color
	status_label.add_theme_color_override("font_color", connecting_color)
	status_label.text = "Connecting..."
	message_label.text = "Searching for host..."
	glow_speed = 3.0

# Set to online state (green, glowing)
func set_online() -> void:
	set_status(true, "Connected to LAN")
	glow_speed = 2.0

# Set to offline state (red, no glow)
func set_offline() -> void:
	set_status(false, "Connection lost")
	glow_speed = 0.0
