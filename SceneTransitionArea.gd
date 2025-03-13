extends Area2D

# Configuration
@export_file("*.tscn") var target_scene: String = "res://garden.tscn"
@export var interaction_prompt_offset: Vector2 = Vector2(0, -20)
@export var save_previous_position: bool = true
@export var preserve_scene_state: bool = true
@export var show_debug: bool = false
@export var action_label: String = "Travel"

# Player detection and control tracking
var players_in_area: Dictionary = {}
var reveal_controls: Node2D

# Called when the node enters the scene tree
func _ready() -> void:
	# Enable debug to see what's happening
	show_debug = true
	
	# Connect signals - Make sure these are properly connecting
	if not is_connected("body_entered", Callable(self, "_on_body_entered")):
		connect("body_entered", Callable(self, "_on_body_entered"))
		if show_debug:
			print("Connected body_entered signal")
	
	if not is_connected("body_exited", Callable(self, "_on_body_exited")):
		connect("body_exited", Callable(self, "_on_body_exited"))
		if show_debug:
			print("Connected body_exited signal")
	
	# Create reveal control component for key prompts
	reveal_controls = _create_reveal_controls()
	add_child(reveal_controls)
	
	if show_debug:
		print("SceneTransitionArea initialized at: ", global_position)
		print("Target scene: ", target_scene)
		
		# Show collision shape info
		var collision_shape = _find_collision_shape()
		if collision_shape:
			print("Collision shape found: ", collision_shape.name)
		else:
			print("WARNING: No collision shape found for area!")

# Create the key display controller
func _create_reveal_controls() -> Node2D:
	var controls = Node2D.new()
	controls.name = "RevealControls"
	
	# Add the script
	var script = load("res://RevealPlayerControls.gd")
	controls.set_script(script)
	
	# Configure the control display
	controls.detection_radius = 50  # Only show when precisely in area, not nearby
	
	# Position the indicator directly above the player's head
	controls.bubble_offset = Vector2(0, -10)  # Move it higher above player's head
	
	controls.bubble_size = Vector2(3, 3)
	controls.show_debug = show_debug
	
	# Get scene name for action description
	var scene_name = "another area"
	if target_scene:
		scene_name = target_scene.get_file().get_basename()
		scene_name = scene_name.capitalize()
	
	# Set action description
	controls.action_description = action_label + " to " + scene_name
	
	# The position of the RevealControls node should match the collision shape
	# but we don't need custom positioning for the bubbles which attach to players
	var collision_shape = _find_collision_shape()
	if collision_shape:
		controls.position = collision_shape.position
		
		# Set appropriate size based on collision shape
		if collision_shape is CollisionShape2D:
			var shape = collision_shape.shape
			if shape is RectangleShape2D:
				controls.bubble_size = shape.extents * 2  # Convert extents to full size
			elif shape is CircleShape2D:
				controls.bubble_size = Vector2(shape.radius * 2, shape.radius * 2)
	
	return controls

# Helper function to find a collision shape in the Area2D
func _find_collision_shape() -> Node:
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			return child
	return null

# Allow changing the target scene programmatically
func set_target_scene(new_scene_path: String) -> void:
	target_scene = new_scene_path
	
	# Update the action description
	if reveal_controls:
		var scene_name = target_scene.get_file().get_basename().capitalize()
		reveal_controls.action_description = action_label + " to " + scene_name

# Process key presses when players are in the area
func _process(_delta: float) -> void:
	if players_in_area.size() > 0 and show_debug and Engine.get_frames_drawn() % 60 == 0:
		print("Players in area: ", players_in_area.size(), " - Waiting for key press")
	
	# Check each player in area for key presses
	for player in players_in_area.keys():
		if not is_instance_valid(player):
			if show_debug:
				print("Player no longer valid, removing from tracking")
			players_in_area.erase(player)
			continue
			
		var key_name = players_in_area[player]
		var key_pressed = false
		
		# Check for appropriate key press based on player
		if key_name == "E":
			key_pressed = Input.is_physical_key_pressed(KEY_E)
			if show_debug and key_pressed:
				print("E key is pressed!")
		elif key_name == "L":
			key_pressed = Input.is_physical_key_pressed(KEY_L)
			if show_debug and key_pressed:
				print("L key is pressed!")
		
		# Track key press but don't transition yet
		if key_pressed and not player.get_meta("key_was_pressed", false):
			player.set_meta("key_was_pressed", true)
			if show_debug:
				print("Key pressed: ", key_name, " - Waiting for release")
		# Transition on key release (key up) after it was pressed
		elif not key_pressed and player.get_meta("key_was_pressed", false) == true:
			player.set_meta("key_was_pressed", false)
			if show_debug:
				print("Key released: ", key_name, " - Transitioning scenes")
			_transition_to_scene(player)
			break

# Save player state before transition
func _save_player_state(player: Node2D) -> void:
	if save_previous_position:
		# Store position for returning later
		var scene_path = get_tree().current_scene.scene_file_path
		
		# Try to get global controller with either possible name
		var global_controller = get_node_or_null("/root/game_global_controller")
		if not global_controller:
			global_controller = get_node_or_null("/root/GameGlobalController")
		
		# Store position data (either in global controller or locally)
		var state_data = {
			"position": player.global_position,
			"last_scene": scene_path
		}
		
		if global_controller:
			# Store in the global controller
			global_controller.set_meta("player_previous_state", state_data)
			if show_debug:
				print("Saved player position in global controller: ", player.global_position)
		else:
			# Local storage fallback - store in scene root
			var root = get_tree().current_scene
			if root:
				root.set_meta("player_previous_state", state_data)
				if show_debug:
					print("No global controller - saved player position in scene root: ", player.global_position)
	
	# If preserving scene state, save the entire scene
	if preserve_scene_state:
		_save_scene_state()

# Save comprehensive scene state
func _save_scene_state() -> void:
	var scene_path = get_tree().current_scene.scene_file_path
	
	if show_debug:
		print("Saving complete scene state for ", scene_path)
	
	# Prepare scene state data
	var players = get_tree().get_nodes_in_group("players")
	var player_states = {}
	
	for player in players:
		if is_instance_valid(player):
			# Save player position, momentum, and other important state
			var player_state = {
				"position": player.global_position,
				"velocity": player.get("velocity") if player.get("velocity") != null else Vector2.ZERO,
				"is_active": player.get("is_active") if player.get("is_active") != null else true,
				"jumps_remaining": player.get("jumps_remaining") if player.get("jumps_remaining") != null else 0,
				"momentum": player.get_momentum() if player.has_method("get_momentum") else 0.0,
				"carrying_player": player.is_involved_in_carrying() if player.has_method("is_involved_in_carrying") else false
			}
			player_states[player.name] = player_state
	
	# Get other important scene objects (with "persistent" group)
	var persistent_objects = get_tree().get_nodes_in_group("persistent")
	var object_states = {}
	
	for obj in persistent_objects:
		if is_instance_valid(obj):
			var obj_state = {
				"position": obj.global_position if obj is Node2D else Vector2.ZERO,
				"visible": obj.visible,
				"properties": {}  # Custom properties
			}
			
			# Store any custom properties marked for persistence
			if obj.has_method("get_persistent_properties"):
				obj_state["properties"] = obj.get_persistent_properties()
			
			object_states[obj.get_path()] = obj_state
	
	# Create complete scene state
	var scene_state = {
		"players": player_states,
		"objects": object_states,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	# Try to get global controller with either possible name
	var global_controller = get_node_or_null("/root/game_global_controller")
	if not global_controller:
		global_controller = get_node_or_null("/root/GameGlobalController")
	
	# Use global controller if available, otherwise use scene root for storage
	if global_controller:
		if global_controller.has_method("save_scene_state"):
			global_controller.save_scene_state(scene_path, scene_state)
		else:
			# Fallback to using metadata with safe key formatting
			var safe_key = "scene_state_" + scene_path.replace("/", "_").replace(":", "_").replace(".", "_")
			global_controller.set_meta(safe_key, scene_state)
			global_controller.set_meta("previous_scene", scene_path)
	else:
		# Store in autoload or scene root as fallback
		var root = get_tree().current_scene
		if root:
			# Create a local storage key with safe formatting
			var safe_key = "scene_state_" + scene_path.replace("/", "_").replace(":", "_").replace(".", "_")
			root.set_meta(safe_key, scene_state)
			root.set_meta("previous_scene", scene_path)
			
			if show_debug:
				print("No global controller - saved scene state in scene root")

# Transition to the new scene
func _transition_to_scene(player: Node2D) -> void:
	if not target_scene or target_scene.is_empty():
		push_error("No target scene specified for SceneTransitionArea")
		return
		
	if show_debug:
		print("Transitioning to: ", target_scene)
	
	# Save player state
	_save_player_state(player)
	
	# Reset player state for transport
	for tracked_player in get_tree().get_nodes_in_group("players"):
		if is_instance_valid(tracked_player) and tracked_player.has_method("transport"):
			tracked_player.transport()
	
	# Prevent multiple transition attempts - this is critical
	players_in_area.clear()  # Clear all players to prevent additional transition attempts
	
	# Try to get the global controller with either name
	var global_controller = get_node_or_null("/root/game_global_controller")
	if not global_controller:
		global_controller = get_node_or_null("/root/GameGlobalController")
	
	if global_controller and global_controller.has_method("change_scene"):
		# Call scene change directly
		global_controller.change_scene(target_scene)
	else:
		# Fallback to direct scene change if no global controller exists
		if show_debug:
			print("No global controller found, using direct scene change")
		var err = get_tree().change_scene_to_file(target_scene)
		if err != OK:
			push_error("Failed to change scene to: " + target_scene)

# Handle player entering the area
func _on_body_entered(body: Node2D) -> void:
	if show_debug:
		print("Body entered area: ", body.name)
		print("Body groups: ", body.get_groups())
		print("Is body a player? ", body.is_in_group("players"))
		
	# Check if this is a player - more lenient check for Player2
	var is_player = false
	
	if body.name == "Player" or body.name == "Player2":
		is_player = true
	elif body.is_in_group("players"):
		is_player = true
	
	if is_player:
		# Determine which key to use based on player name or script
		var key_name = "E"  # Default
		
		if body.name == "Player2" or (body.has_method("get_script") and "player2" in body.get_script().resource_path.to_lower()):
			key_name = "L"
			
		# Add to tracking dictionary
		players_in_area[body] = key_name
		
		# Explicitly show controls when player enters the area
		if reveal_controls:
			if reveal_controls.has_method("add_tracked_player"):
				reveal_controls.add_tracked_player(body)
			elif show_debug:
				print("ERROR: RevealControls doesn't have add_tracked_player method")
		
		if show_debug:
			print("Player entered area. Key: ", key_name, " (Position: ", body.global_position, ")")

# Handle player exiting the area
func _on_body_exited(body: Node2D) -> void:
	# Remove from tracking
	if players_in_area.has(body):
		players_in_area.erase(body)
		
		# Explicitly hide controls when player exits the area
		if reveal_controls:
			if reveal_controls.has_method("remove_tracked_player"):
				reveal_controls.remove_tracked_player(body)
			elif show_debug:
				print("WARNING: RevealControls doesn't have remove_tracked_player method")
		
		if show_debug:
			print("Player exited area") 
