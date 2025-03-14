extends Node

var map_open = false
var map_ui = null
var click_detector = null
var map_canvas_layer = null

# Path to the map UI scene
const MAP_UI_SCENE_PATH = "res://MapUI.tscn"

# Base resolution for scaling calculations (typical 16:9 resolution)
@export var base_resolution := Vector2(1280, 720) 

# Original scales and positions defined in the scene
var original_map_scale := Vector2(6.0, 6.0)
var original_indicator_scale := Vector2(1.0, 1.0)
var original_map_position := Vector2.ZERO
var original_indicator_position := Vector2.ZERO

func _ready():
	# Initialize the script
	set_process_input(true)
	print("Map controller initialized. Press X or M to open map.")
	
	# Create a canvas layer for the map (will always be on top)
	map_canvas_layer = CanvasLayer.new()
	map_canvas_layer.layer = 100
	add_child(map_canvas_layer)
	
	# Create a click detector for this node
	_create_click_detector()
	
	# Preload the map UI scene
	var map_scene = load(MAP_UI_SCENE_PATH)
	if not map_scene:
		push_error("Failed to load map UI scene from " + MAP_UI_SCENE_PATH)
	
	# Connect to window resize signal to handle fullscreen changes
	get_tree().root.size_changed.connect(_on_window_size_changed)
	
func _create_click_detector():
	# Create an Area2D to detect clicks
	click_detector = Area2D.new()
	click_detector.name = "MapClickDetector"
	
	# Add a collision shape
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(50, 50)  # Default size, adjust as needed for your object
	collision.shape = shape
	
	# Make it pick up input events
	click_detector.input_pickable = true
	click_detector.connect("input_event", Callable(self, "_on_click_detector_input_event"))
	
	# Add to scene
	click_detector.add_child(collision)
	add_child(click_detector)
	
	print("Map click detector created")
	
func _on_click_detector_input_event(_viewport, event, _shape_idx):
	# Detect click/tap on the detector
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Map area clicked!")
		toggle_map()
		get_viewport().set_input_as_handled()
	
func _input(event):
	# Check for X or M key press
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_X or event.keycode == KEY_M:
			toggle_map()

func _on_window_size_changed():
	# Update map scaling if it's visible
	if map_open and map_ui != null:
		_adjust_map_scaling()

func _adjust_map_scaling():
	if map_ui == null:
		return
		
	# Get window size
	var window_size = get_viewport().get_visible_rect().size
	
	# Calculate scale factor based on window size compared to base resolution
	var scale_factor_x = window_size.x / base_resolution.x
	var scale_factor_y = window_size.y / base_resolution.y
	
	# Use the smaller factor to ensure the map fits on screen
	var scale_factor = min(scale_factor_x, scale_factor_y)
	
	# Center the UI based on the new window size
	var center_container = map_ui.get_node_or_null("CenterContainer")
	if center_container and center_container is Control:
		center_container.custom_minimum_size = window_size
		center_container.size = window_size
	
	# Find the map sprite and adjust its scale
	var map_sprite = map_ui.get_node_or_null("CenterContainer/MapSprite")
	if map_sprite:
		# Apply proportional scaling to the original scale
		map_sprite.scale = original_map_scale * scale_factor
		# Reset to the center of the screen
		map_sprite.position = Vector2(window_size.x / 2, window_size.y / 2)
	
	# Find the indicator and adjust its scale
	var map_indicator = map_ui.get_node_or_null("CenterContainer/MapIndicator") 
	if map_indicator:
		# Apply the same scale factor to maintain proportions
		map_indicator.scale = original_indicator_scale * scale_factor
		
		# Adjust indicator position based on its relation to the map
		# Calculate the vector from map center to indicator
		var offset = original_indicator_position - original_map_position
		# Apply the scale factor to maintain the same relative position
		map_indicator.position = map_sprite.position + (offset * scale_factor)

func toggle_map():
	if map_open:
		close_map()
	else:
		open_map()

func find_active_camera():
	# Try to find the active camera in the scene
	var viewport = get_viewport()
	if viewport.get_camera_2d():
		return viewport.get_camera_2d()
	
	# If no camera found via the viewport, search for a Camera2D node
	var cameras = get_tree().get_nodes_in_group("Camera2D")
	if cameras.size() > 0:
		return cameras[0]
		
	# Fallback: search for any Camera2D in the scene
	var all_cameras = []
	find_nodes_of_type(get_tree().get_root(), "Camera2D", all_cameras)
	
	if all_cameras.size() > 0:
		return all_cameras[0]
		
	print("No Camera2D found in the scene!")
	return null

func find_nodes_of_type(node, type_name, result_array):
	if node.get_class() == type_name:
		result_array.append(node)
	
	for child in node.get_children():
		find_nodes_of_type(child, type_name, result_array)

func open_map():
	# Instance the map UI scene
	var map_scene = load(MAP_UI_SCENE_PATH)
	if not map_scene:
		push_error("Failed to load map UI scene from " + MAP_UI_SCENE_PATH)
		return
		
	map_ui = map_scene.instantiate()
	
	# Add the map UI to the canvas layer - this will appear on top regardless of camera
	map_canvas_layer.add_child(map_ui)
	
	# Store original scales and positions
	var map_sprite = map_ui.get_node_or_null("CenterContainer/MapSprite")
	var map_indicator = map_ui.get_node_or_null("CenterContainer/MapIndicator")
	
	if map_sprite:
		original_map_scale = map_sprite.scale
		original_map_position = map_sprite.position
	
	if map_indicator:
		original_indicator_scale = map_indicator.scale
		original_indicator_position = map_indicator.position
	
	# Apply adaptive scaling for current window size
	_adjust_map_scaling()
	
	print("Map opened with adaptive scaling")
	map_open = true

func close_map():
	# Remove the map UI when closing
	if map_ui != null:
		map_ui.queue_free()
		map_ui = null
	
	print("Map closed")
	map_open = false
