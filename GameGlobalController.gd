extends Node

# This is a Global Controller singleton that manages scene transitions
# and preserves state between scenes.
#
# To use:
# 1. Add this script to an autoload/singleton in your project settings
# 2. Access it from any script with: var global = get_node("/root/GameGlobalController")

# State management
var _scene_states = {}
var _current_scene_path = ""
var _prev_scene_path = ""
@export var show_debug: bool = false

# Scene transition control
@export var transition_effects: bool = false

# Called when the node enters the scene tree
func _ready() -> void:
	# Get initial scene
	await get_tree().process_frame
	_current_scene_path = get_tree().current_scene.scene_file_path
	if show_debug:
		print("GameGlobalController: Initial scene is ", _current_scene_path)

# Change to a new scene, preserving current scene state
func change_scene(new_scene_path: String) -> void:
	if show_debug:
		print("GameGlobalController: Changing from ", _current_scene_path, " to ", new_scene_path)
	
	# Store the previous scene path
	_prev_scene_path = _current_scene_path
	
	# Load the new scene
	var err = get_tree().change_scene_to_file(new_scene_path)
	if err != OK:
		push_error("GameGlobalController: Failed to change scene to: " + new_scene_path)
		return
		
	# Update current scene path after we've changed
	call_deferred("_update_current_scene_path", new_scene_path)

# Helper method to update scene path after scene change
func _update_current_scene_path(new_path: String) -> void:
	_current_scene_path = new_path
	if show_debug:
		print("GameGlobalController: Current scene updated to ", _current_scene_path)
	
	# Apply saved state if available
	call_deferred("_apply_scene_state")

# Save state for a specific scene
func save_scene_state(scene_path: String, state_data: Dictionary) -> void:
	if show_debug:
		print("GameGlobalController: Saving state for scene ", scene_path)
	_scene_states[scene_path] = state_data

# Get previously saved state for a scene
func get_scene_state(scene_path: String) -> Dictionary:
	if _scene_states.has(scene_path):
		return _scene_states[scene_path]
	return {}

# Apply saved state to the current scene
func _apply_scene_state() -> void:
	if !_scene_states.has(_current_scene_path):
		if show_debug:
			print("GameGlobalController: No saved state for ", _current_scene_path)
		return
		
	var state = _scene_states[_current_scene_path]
	if show_debug:
		print("GameGlobalController: Applying saved state to ", _current_scene_path)
	
	# Apply player states
	if state.has("players"):
		_apply_player_states(state["players"])
		
	# Apply object states
	if state.has("objects"):
		_apply_object_states(state["objects"])

# Apply saved player states
func _apply_player_states(player_states: Dictionary) -> void:
	var players = get_tree().get_nodes_in_group("players")
	
	for player in players:
		if player_states.has(player.name):
			var player_state = player_states[player.name]
			
			# Position player
			player.global_position = player_state["position"]
			
			# Apply velocity if applicable
			if player_state.has("velocity"):
				player.set("velocity", player_state["velocity"])
				
			# Apply active state
			if player_state.has("is_active"):
				player.set("is_active", player_state["is_active"])
				
			# Apply jumps remaining
			if player_state.has("jumps_remaining"):
				player.set("jumps_remaining", player_state["jumps_remaining"])
				
			if show_debug:
				print("GameGlobalController: Restored state for ", player.name, " at ", player.global_position)

# Apply saved object states
func _apply_object_states(object_states: Dictionary) -> void:
	for object_path_str in object_states.keys():
		var object_path = NodePath(object_path_str)
		var obj = get_node_or_null(object_path)
		
		if obj:
			var obj_state = object_states[object_path_str]
			
			# Position object if it's a Node2D
			if obj is Node2D and obj_state.has("position"):
				obj.global_position = obj_state["position"]
				
			# Set visibility
			if obj_state.has("visible"):
				obj.visible = obj_state["visible"]
				
			# Apply custom properties
			if obj_state.has("properties"):
				var props = obj_state["properties"]
				for prop_name in props.keys():
					obj.set(prop_name, props[prop_name])
					
			if show_debug:
				print("GameGlobalController: Restored state for object ", object_path)

# Get previous scene path
func get_previous_scene() -> String:
	return _prev_scene_path

# Check if a scene has saved state
func has_saved_state(scene_path: String) -> bool:
	return _scene_states.has(scene_path) 