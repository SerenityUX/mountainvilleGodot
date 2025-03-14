extends Sprite2D

# Export variables for easy configuration in the inspector
@export var area2d_path: NodePath = "Area2D"          # Path to the Area2D node for click detection
@export var debug_mode: bool = true                   # Enable/disable debug prints
@export var mountains_scene_path: String = "res://Mountains.tscn"  # Path to the mountains scene
@export var transition_delay: float = 0.1            # Short delay before scene change (in seconds)
@export var preserve_scene_state: bool = true        # Whether to preserve scene state when leaving

# Reference to the area for click detection
var click_area = null
var _timer: Timer
var _current_scene_path: String = ""

func _ready():
	# Make sure input processing is enabled
	set_process_input(true)
	
	# Create timer for delayed transition
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = transition_delay
	_timer.timeout.connect(_change_scene)
	add_child(_timer)
	
	# Store current scene path for state management
	_current_scene_path = get_tree().current_scene.scene_file_path
	if debug_mode:
		print("MountainTransport: Current scene is ", _current_scene_path)
	
	# Find or get the Area2D for click detection
	_setup_click_area()

func _setup_click_area():
	# First, try to get the Area2D from the specified path
	if not area2d_path.is_empty():
		click_area = get_node_or_null(area2d_path)
		if click_area and click_area is Area2D:
			if debug_mode:
				print("MountainTransport: Found Area2D at specified path: ", area2d_path)
		else:
			push_error("MountainTransport: Area2D not found at path: " + str(area2d_path) + ". Please set a valid Area2D path.")
			click_area = null
	
	# Make sure the Area2D is set up for input
	if click_area:
		# Critical settings for Area2D to detect clicks
		click_area.input_pickable = true
		click_area.monitoring = true
		click_area.monitorable = true
		
		# Connect signal for input events (disconnect first to avoid duplicates)
		if click_area.is_connected("input_event", Callable(self, "_on_click_area_input_event")):
			click_area.disconnect("input_event", Callable(self, "_on_click_area_input_event"))
		
		click_area.connect("input_event", Callable(self, "_on_click_area_input_event"))
		
		if debug_mode:
			print("MountainTransport: Click detection area ready")

func _on_click_area_input_event(_viewport, event, _shape_idx):
	# Check for mouse button click event
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if debug_mode:
			print("MountainTransport: Click detected, transporting to Mountains")
		
		# Handle the transport
		_handle_transport()

# Fallback for direct input if Area2D signals aren't working
func _input(event):
	if click_area == null or not is_visible():
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Check if mouse is over the sprite
		var local_mouse_pos = get_global_transform().affine_inverse() * event.global_position
		var sprite_size = texture.get_size() * scale / 2  # Half size for center-based check
		
		if abs(local_mouse_pos.x) < sprite_size.x and abs(local_mouse_pos.y) < sprite_size.y:
			if debug_mode:
				print("MountainTransport: Direct click detected, transporting to Mountains")
			
			# Handle the transport
			_handle_transport()

# Main function to initiate transport
func _handle_transport() -> void:
	if mountains_scene_path.is_empty():
		push_warning("MountainTransport: Cannot navigate - target scene is empty")
		return
	
	# Save scene state before leaving if enabled
	if preserve_scene_state:
		_save_scene_state()
	
	# Prepare players for transport
	_prepare_players_for_transport()
	
	# Start the timer for delayed scene change
	_timer.start()

# Function to handle the actual scene change
func _change_scene() -> void:
	# Try to get the global controller with either name
	var global_controller = get_node_or_null("/root/game_global_controller")
	if not global_controller:
		global_controller = get_node_or_null("/root/GameGlobalController")
	
	if global_controller and global_controller.has_method("change_scene"):
		if debug_mode:
			print("MountainTransport: Using global controller to change to ", mountains_scene_path)
		global_controller.change_scene(mountains_scene_path)
	else:
		if debug_mode:
			print("MountainTransport: Using direct scene change to ", mountains_scene_path)
		# Use the SceneTree to change the scene
		var err = get_tree().change_scene_to_file(mountains_scene_path)
		if err != OK:
			push_error("MountainTransport: Failed to change scene to: " + mountains_scene_path)

# Save the current state of the scene
func _save_scene_state() -> void:
	if debug_mode:
		print("MountainTransport: Saving scene state for ", _current_scene_path)
	
	# First try to get the global controller - try both names
	var global_controller = get_node_or_null("/root/game_global_controller")
	if not global_controller:
		global_controller = get_node_or_null("/root/GameGlobalController")
	
	if not global_controller:
		# Create a simple local cache in the scene if no global controller
		var root = get_tree().current_scene
		if root:
			if debug_mode:
				print("MountainTransport: No global controller, using scene root for storage")
			
			# Store the player positions at least
			var local_players = get_tree().get_nodes_in_group("players")
			var player_positions = {}
			
			for player in local_players:
				if is_instance_valid(player):
					player_positions[player.name] = player.global_position
			
			# Store the minimal state we need to preserve
			var minimal_state = {
				"player_positions": player_positions,
				"timestamp": Time.get_unix_time_from_system()
			}
			
			# Use a safe key format for metadata
			var safe_key = "minimal_state_" + _current_scene_path.replace("/", "_").replace(":", "_").replace(".", "_")
			root.set_meta(safe_key, minimal_state)
			
			return
		else:
			push_warning("MountainTransport: No global controller found and couldn't access scene root")
			return
	
	# Get all players
	var players = get_tree().get_nodes_in_group("players")
	var player_states = {}
	
	for player in players:
		if is_instance_valid(player):
			# Save player position, momentum, and other important state
			var player_state = {
				"position": player.global_position,
				"velocity": player.get("velocity") if player.get("velocity") != null else Vector2.ZERO,
				"is_active": player.get("is_active") if player.get("is_active") != null else true
			}
			player_states[player.name] = player_state
	
	# Create complete scene state
	var scene_state = {
		"players": player_states,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	# Store in the global controller
	if global_controller.has_method("save_scene_state"):
		global_controller.save_scene_state(_current_scene_path, scene_state)
	else:
		# Fallback to using metadata with a safe key format
		var safe_key = "scene_state_" + _current_scene_path.replace("/", "_").replace(":", "_").replace(".", "_")
		global_controller.set_meta(safe_key, scene_state)
		
		# Also store the current scene as the previous scene
		global_controller.set_meta("previous_scene", _current_scene_path)

# Prepare players for scene transition
func _prepare_players_for_transport() -> void:
	# Reset player state for transport
	for player in get_tree().get_nodes_in_group("players"):
		if is_instance_valid(player) and player.has_method("transport"):
			if debug_mode:
				print("MountainTransport: Preparing player for transport: ", player.name)
			
			# Try to transport player, catch any errors
			if player:
				player.transport()
				
	# Backup: If players aren't in the 'players' group, look for them by name
	var root = get_tree().current_scene
	if root:
		var player1 = root.get_node_or_null("Player1") if root.has_node("Player1") else root.get_node_or_null("Player")
		var player2 = root.get_node_or_null("Player2")
		
		if player1 and player1.has_method("transport") and not player1.is_in_group("players"):
			if debug_mode:
				print("MountainTransport: Found Player1 by name, transporting")
			player1.transport()
			
		if player2 and player2.has_method("transport") and not player2.is_in_group("players"):
			if debug_mode:
				print("MountainTransport: Found Player2 by name, transporting")
			player2.transport() 
