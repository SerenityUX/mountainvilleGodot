extends Node

@export_category("Navigation")
@export_file("*.tscn") var target_scene: String = ""  # Scene to transition to when Escape is pressed
@export var transition_delay: float = 0.1  # Short delay before scene change (in seconds)
@export var enable_escape: bool = true  # Toggle to enable/disable the escape functionality
@export var preserve_scene_state: bool = true  # Whether to preserve scene state when leaving

# Optional parameters
@export_group("Additional Options")
@export var show_transition_effect: bool = false  # Whether to show a transition effect
@export var play_sound_effect: bool = false  # Whether to play a sound effect
@export var show_debug: bool = false  # Whether to print debug information

# Internal variables
var _timer: Timer
var _sound_player: AudioStreamPlayer
var _current_scene_path: String = ""

func _ready() -> void:
	if target_scene.is_empty():
		push_warning("escapeToGoBack: No target scene set. Please set a target scene in the inspector.")
	
	# Create timer for delayed transition
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = transition_delay
	_timer.timeout.connect(_change_scene)
	add_child(_timer)
	
	# Create audio player for sound effect if needed
	if play_sound_effect:
		_sound_player = AudioStreamPlayer.new()
		add_child(_sound_player)
		# Try to load a default click sound
		var sound = load("res://click.mp3")
		if sound:
			_sound_player.stream = sound
	
	# Store current scene path for state management
	_current_scene_path = get_tree().current_scene.scene_file_path
	if show_debug:
		print("escapeToGoBack: Current scene is ", _current_scene_path)

func _input(event: InputEvent) -> void:
	if enable_escape and event.is_action_pressed("ui_cancel"):  # ui_cancel is mapped to Escape by default
		_handle_escape()
		# Consume the event so it doesn't propagate
		get_viewport().set_input_as_handled()

func _handle_escape() -> void:
	if target_scene.is_empty():
		push_warning("escapeToGoBack: Cannot navigate - target scene is empty")
		return
	
	if play_sound_effect and _sound_player and _sound_player.stream:
		_sound_player.play()
	
	if show_transition_effect:
		# Optional: Add a simple fade transition here
		# You could use a ColorRect with animation or Godot's built-in transitions
		pass
	
	# Save scene state before leaving if enabled
	if preserve_scene_state:
		_save_scene_state()
	
	# Prepare players for transport
	_prepare_players_for_transport()
	
	# Start the timer for delayed scene change
	_timer.start()

func _change_scene() -> void:
	# Try to get the global controller with either name
	var global_controller = get_node_or_null("/root/game_global_controller")
	if not global_controller:
		global_controller = get_node_or_null("/root/GameGlobalController")
	
	if global_controller and global_controller.has_method("change_scene"):
		if show_debug:
			print("escapeToGoBack: Using global controller to change to ", target_scene)
		global_controller.change_scene(target_scene)
	else:
		if show_debug:
			print("escapeToGoBack: Using direct scene change to ", target_scene)
		# Use the SceneTree to change the scene
		var err = get_tree().change_scene_to_file(target_scene)
		if err != OK:
			push_error("escapeToGoBack: Failed to change scene to: " + target_scene)

# Public method to programmatically change target scene
func set_target_scene(scene_path: String) -> void:
	target_scene = scene_path

# Save the current state of the scene
func _save_scene_state() -> void:
	if show_debug:
		print("escapeToGoBack: Saving scene state for ", _current_scene_path)
	
	# First try to get the global controller - try both names
	var global_controller = get_node_or_null("/root/game_global_controller")
	if not global_controller:
		global_controller = get_node_or_null("/root/GameGlobalController")
	
	if not global_controller:
		# Create a simple local cache in the scene if no global controller
		var root = get_tree().current_scene
		if root:
			if show_debug:
				print("escapeToGoBack: No global controller, using scene root for storage")
			
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
			push_warning("escapeToGoBack: No global controller found and couldn't access scene root")
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
				"is_active": player.get("is_active") if player.get("is_active") != null else true,
				"carrying_player": player.is_involved_in_carrying() if player.has_method("is_involved_in_carrying") else false
			}
			player_states[player.name] = player_state
	
	# Get other important scene objects (with "persistent" group or similar tagging)
	var persistent_objects = get_tree().get_nodes_in_group("persistent")
	var object_states = {}
	
	for obj in persistent_objects:
		if is_instance_valid(obj):
			var obj_state = {
				"position": obj.global_position if obj is Node2D else Vector2.ZERO,
				"visible": obj.visible,
				"properties": {}  # Custom properties can be added here
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
			if show_debug:
				print("escapeToGoBack: Preparing player for transport: ", player.name)
			
			# Try to transport player, catch any errors
			if player:
				player.transport()
				
	# Backup: If players aren't in the 'players' group, look for them by name
	var root = get_tree().current_scene
	if root:
		var player1 = root.get_node_or_null("Player1") if root.has_node("Player1") else root.get_node_or_null("Player")
		var player2 = root.get_node_or_null("Player2")
		
		if player1 and player1.has_method("transport") and not player1.is_in_group("players"):
			if show_debug:
				print("escapeToGoBack: Found Player1 by name, transporting")
			player1.transport()
			
		if player2 and player2.has_method("transport") and not player2.is_in_group("players"):
			if show_debug:
				print("escapeToGoBack: Found Player2 by name, transporting")
			player2.transport()
