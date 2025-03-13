extends Node

# Simple global controller for basic scene management
# This script handles loading the initial scene and provides basic utility functions

# Constants
const DEFAULT_SCENE := "res://CurryHouse.tscn"
const GARDEN_SCENE := "res://garden.tscn"

# State tracking
var scene_transitions = {}
var current_scene_path = ""

func _ready() -> void:
	# Load the default scene when the game starts
	load_default_scene()

# Load the default curry house scene
func load_default_scene() -> void:
	print("Loading default scene: ", DEFAULT_SCENE)
	var error := get_tree().change_scene_to_file(DEFAULT_SCENE)
	
	if error != OK:
		push_error("Failed to load default scene: " + DEFAULT_SCENE)
		print("Error code: ", error)
	else:
		current_scene_path = DEFAULT_SCENE

# Function to change to any scene by path
func change_scene(scene_path: String) -> void:
	print("Changing scene to: ", scene_path)
	
	# Store the current scene path before changing
	var previous_scene = current_scene_path
	current_scene_path = scene_path
	
	var error := get_tree().change_scene_to_file(scene_path)
	
	if error != OK:
		push_error("Failed to load scene: " + scene_path)
		print("Error code: ", error)
		return
		
	# After successful scene change
	call_deferred("_handle_scene_loaded", scene_path, previous_scene)

# Handle any setup needed after the scene is loaded
func _handle_scene_loaded(new_scene: String, previous_scene: String) -> void:
	print("Scene loaded: ", new_scene)
	
	# Wait a frame to ensure scene is fully loaded
	await get_tree().process_frame
	
	# If we have previous state data, apply it
	if has_meta("player_previous_state"):
		var state_data = get_meta("player_previous_state")
		
		# Find the player in the scene
		var players = get_tree().get_nodes_in_group("players")
		if players.size() > 0:
			# Set player position if we're returning to a previous scene
			if state_data.last_scene == new_scene:
				players[0].global_position = state_data.position
				print("Restored player position: ", state_data.position) 
