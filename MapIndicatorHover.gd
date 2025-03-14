extends Sprite2D

# Export variables for easy configuration in the inspector
@export var toggle_node_path: NodePath = "ItemsSlide"  # Default to "ItemsSlide" but can be changed in editor
@export var area2d_path: NodePath = "Area2D"          # Path to the Area2D node
@export var hover_area_size_multiplier: float = 1.0    # Adjust collision area size
@export var debug_mode: bool = true                    # Enable/disable debug prints
@export var show_collision_shape: bool = true         # Visualize the collision shape for debugging

# Reference to the node that will be toggled
var toggle_node = null
var click_area = null

func _ready():
	# Make sure input processing is enabled
	set_process_input(true)
	
	# Get the node to toggle based on the provided path
	if not toggle_node_path.is_empty():
		toggle_node = get_node_or_null(toggle_node_path)
	
	# Make sure the toggle node exists and hide it by default
	if toggle_node:
		toggle_node.visible = false
		if debug_mode:
			print("Toggle node found and hidden by default: ", toggle_node_path)
	else:
		push_error("Toggle node not found at path: " + str(toggle_node_path) + ". Please set a valid node path in the inspector.")
	
	# Find or create a click detection Area2D
	_setup_click_area()

func _setup_click_area():
	# First, try to get the Area2D from the specified path
	if not area2d_path.is_empty():
		click_area = get_node_or_null(area2d_path)
		if click_area and click_area is Area2D:
			if debug_mode:
				print("Found Area2D at specified path: ", area2d_path)
		else:
			push_error("Area2D not found at path: " + str(area2d_path) + ". Please set a valid Area2D path.")
			click_area = null
			
	# If no valid Area2D found, create one as a fallback
	if click_area == null:
		if debug_mode:
			print("No valid Area2D found, creating one...")
		click_area = Area2D.new()
		click_area.name = "ClickArea"
		
		# Add collision shape that matches the sprite size
		var collision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		
		# Make sure we have a texture before trying to get its size
		if texture:
			# Get texture size and apply scale for proper collision area
			var texture_size = texture.get_size() * scale
			# Apply the size multiplier for easier clicking
			shape.size = texture_size * hover_area_size_multiplier
		else:
			# Fallback size if texture is not available
			shape.size = Vector2(50, 50) * hover_area_size_multiplier
		
		collision.shape = shape
		click_area.add_child(collision)
		add_child(click_area)
		
		if debug_mode:
			print("Created fallback Area2D with size: ", shape.size)
	
	# Critical settings for Area2D to detect clicks
	click_area.input_pickable = true
	click_area.monitoring = true
	click_area.monitorable = true
	
	# Show collision shape for debugging if needed
	if show_collision_shape and click_area.get_child_count() > 0:
		for child in click_area.get_children():
			if child is CollisionShape2D:
				child.debug_color = Color(1, 0, 0, 0.5)  # Red with transparency
				child.visible = true
	
	# Connect signal for input events (disconnect first to avoid duplicates)
	if click_area.is_connected("input_event", Callable(self, "_on_click_area_input_event")):
		click_area.disconnect("input_event", Callable(self, "_on_click_area_input_event"))
	
	click_area.connect("input_event", Callable(self, "_on_click_area_input_event"))
	
	# Connect additional signals for debugging
	if debug_mode:
		click_area.connect("mouse_entered", Callable(self, "_on_mouse_entered"))
		click_area.connect("mouse_exited", Callable(self, "_on_mouse_exited"))
	
	if debug_mode:
		print("Click detection area ready with settings: input_pickable=", click_area.input_pickable,
			  ", monitoring=", click_area.monitoring, ", monitorable=", click_area.monitorable)

func _on_click_area_input_event(_viewport, event, _shape_idx):
	if debug_mode:
		print("Input event received: ", event)
		
	# Check for mouse button click event
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if debug_mode:
			print("Click detected on area")
		# Toggle the visibility of the node
		if toggle_node:
			toggle_node.visible = !toggle_node.visible
			if debug_mode:
				print("Toggled visibility to: ", toggle_node.visible)

func _on_mouse_entered():
	if debug_mode:
		print("Mouse entered area")

func _on_mouse_exited():
	if debug_mode:
		print("Mouse exited area")

# Fallback for direct input if Area2D signals aren't working
func _input(event):
	if click_area == null:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Check if mouse is over the sprite
		var local_mouse_pos = get_global_transform().affine_inverse() * event.global_position
		var sprite_size = texture.get_size() * scale / 2  # Half size for center-based check
		
		if abs(local_mouse_pos.x) < sprite_size.x and abs(local_mouse_pos.y) < sprite_size.y:
			if debug_mode:
				print("Direct sprite click detected at: ", local_mouse_pos)
			
			if toggle_node:
				toggle_node.visible = !toggle_node.visible
				if debug_mode:
					print("Toggled visibility (direct) to: ", toggle_node.visible)

# Don't need to dynamically update the Area2D if it's manually added in the editor
func _process(delta):
	# Only resize the collision shape if we created it programmatically
	if click_area == null or click_area.get_parent() != self: # Fix the condition
		return
		
	if click_area.get_child_count() > 0:
		var collision = click_area.get_child(0)
		if collision is CollisionShape2D and collision.shape is RectangleShape2D:
			if texture:
				# Update collision shape size based on current texture and scale
				var current_texture_size = texture.get_size() * scale
				collision.shape.size = current_texture_size * hover_area_size_multiplier 