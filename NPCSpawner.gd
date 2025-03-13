extends Node

# =============================================================================
# HOW TO USE THIS SCRIPT:
# =============================================================================
# 1. Attach this script to a Node in your scene
# 2. Assign the DoorController node to the "door_controller" property
# 3. Set the spawn_point to determine where NPCs will appear
# 4. Adjust other parameters as needed
#
# SETUP EXAMPLE:
# - Create a Node named "NPCSpawner"
# - Attach this script to that Node
# - Drag your DoorController node into the door_controller property
# - Set up a position for the NPCs to spawn
# =============================================================================

# Spawn configuration
@export var door_controller: Node  # Reference to the DoorController
@export var spawn_point: Vector2 = Vector2(0, 0)  # Where NPCs will spawn
@export var spawn_interval: float = 10.0  # Time between spawns in seconds
@export var max_npcs: int = 5  # Maximum number of NPCs at once
@export var auto_spawn: bool = true  # Whether to auto-spawn NPCs

# NPC movement configuration
@export_group("NPC Movement")
@export var test_movement: bool = false  # Whether NPCs should automatically start test movement
@export var movement_distance: float = 100.0  # How far NPCs will move in each direction
@export var movement_speed: float = 60.0  # Maximum movement speed
@export var acceleration_rate: float = 0.1  # How quickly NPCs accelerate (0-1)
@export var animation_fps: float = 10.0  # Animation frames per second

# NPC appearance configuration
@export_group("NPC Appearance") 
@export var npc_scale: Vector2 = Vector2(4, 4)  # Scale of the NPC sprite

# Preload the NPC sprite and script
var frog_texture = preload("res://FrogSprite.png")
var npc_script = preload("res://npcCustomerMovement.gd")

# Timer for spawning NPCs
var spawn_timer: Timer
var current_npcs: int = 0

# Called when the node enters the scene tree
func _ready() -> void:
	print("SPAWNER DEBUG: NPCSpawner ready")
	print("SPAWNER DEBUG: Auto-spawn is: ", auto_spawn)
	print("SPAWNER DEBUG: Test movement is: ", test_movement)
	print("SPAWNER DEBUG: Spawn point is: ", spawn_point)
	
	# Setup spawn timer
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)
	
	# Start timer if auto_spawn is enabled
	if auto_spawn:
		print("SPAWNER DEBUG: Starting auto-spawn timer with interval: ", spawn_interval)
		spawn_timer.start()

# Spawns a new NPC
func spawn_npc() -> void:
	print("\n=== SPAWNER DEBUG: Attempting to spawn NPC ===")
	
	# Check if we've hit the max number of NPCs
	if current_npcs >= max_npcs:
		print("SPAWNER DEBUG: Maximum NPCs reached: ", current_npcs, "/", max_npcs)
		return
	
	# Open the door using DoorController
	if door_controller:
		print("SPAWNER DEBUG: Opening door via controller: ", door_controller.name)
		door_controller.open_door()
	else:
		push_error("Door controller not assigned to NPCSpawner")
		return
	
	# Create a small delay to let the door animation play
	print("SPAWNER DEBUG: Waiting for door animation")
	await get_tree().create_timer(0.5).timeout
	
	print("SPAWNER DEBUG: Creating NPC with npcCustomerMovement script")
	
	# Create the parent Node2D
	var npc = Node2D.new()
	npc.name = "FrogNPC_" + str(current_npcs)
	npc.position = spawn_point
	npc.z_index = 2
	print("SPAWNER DEBUG: Created Node2D: ", npc.name, " at position: ", npc.position)
	
	# Create the Sprite2D as a child named "Sprite2D"
	var sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = frog_texture
	
	# Setup the sprite
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, 16, 16)
	sprite.scale = npc_scale
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	print("SPAWNER DEBUG: Created Sprite2D with texture: ", frog_texture != null)
	
	# Add the sprite as a child of the NPC Node2D
	npc.add_child(sprite)
	print("SPAWNER DEBUG: Added Sprite2D as child of: ", npc.name)
	
	# Add the NPC to the scene before attaching the script
	add_child(npc)
	print("SPAWNER DEBUG: Added NPC to scene hierarchy")
	
	# Print scene tree for debugging
	print("SPAWNER DEBUG: Scene hierarchy for NPC:")
	_print_node_tree(npc, 0)
	
	# Now attach the script
	print("SPAWNER DEBUG: Attaching npcCustomerMovement script")
	npc.set_script(npc_script)
	
	# Set important properties
	print("SPAWNER DEBUG: Setting sprite_sheet")
	npc.sprite_sheet = frog_texture
	
	# Set movement properties from exported variables
	npc.movement_speed = movement_speed
	npc.test_distance = movement_distance
	print("SPAWNER DEBUG: Set movement_speed to: ", npc.movement_speed)
	print("SPAWNER DEBUG: Set test_distance to: ", npc.test_distance)
	
	# Initialize the sprite manually - critical fix!
	print("SPAWNER DEBUG: Manually initializing sprite")
	if npc.has_method("_initialize_sprite"):
		npc.call("_initialize_sprite")
	
	# Set test animation after ensuring sprite is initialized
	if test_movement:
		print("SPAWNER DEBUG: Test movement is enabled")
		print("SPAWNER DEBUG: Setting test_animation to true")
		npc.test_animation = true
		
		# Initialize position tracking for the test movement
		npc.initial_position = npc.position
		
		# Force movement with absolute implementation
		print("SPAWNER DEBUG: Implementing direct movement control")
		
		# Create a special control script to manage movement - use a high framerate
		var movement_controller = Timer.new()
		movement_controller.name = "MovementController"
		movement_controller.wait_time = 0.016  # ~60fps for smoother movement
		movement_controller.autostart = true
		
		# Create movement data dictionary using the customized parameters
		var movement_data = {
			"direction": 1,  # Start moving right
			"current_speed": 0.0,  # Current speed
			"anim_timer": 0.0,  # Animation timer
			"frame": 0  # Current frame
		}
		movement_controller.set_meta("movement_data", movement_data)
		
		# Connect the timer to a lambda that moves the NPC
		movement_controller.timeout.connect(func():
			# Get movement data
			var data = movement_controller.get_meta("movement_data")
			var direction = data["direction"]
			
			# Toggle direction when reaching limits
			if npc.position.x > npc.initial_position.x + movement_distance:
				# Turn left
				data["direction"] = -1
				direction = -1
				if npc.sprite:
					npc.sprite.flip_h = true
			elif npc.position.x < npc.initial_position.x - movement_distance:
				# Turn right
				data["direction"] = 1
				direction = 1
				if npc.sprite:
					npc.sprite.flip_h = false
			
			# Smooth acceleration using the customized acceleration rate
			if data["current_speed"] < movement_speed:
				data["current_speed"] += acceleration_rate * movement_speed
			
			# Apply smooth movement
			npc.position.x += direction * data["current_speed"] * movement_controller.wait_time
			
			# Handle animation with frame-rate independent timing
			data["anim_timer"] += movement_controller.wait_time
			var frame_duration = 1.0 / animation_fps
			if data["anim_timer"] >= frame_duration:
				data["anim_timer"] = 0.0
				data["frame"] = (data["frame"] + 1) % 4
				if npc.sprite:
					npc.sprite.region_rect.position.y = data["frame"] * 16
		)
		
		# Add the controller to the NPC
		npc.add_child(movement_controller)
		print("SPAWNER DEBUG: Added direct movement controller")
	
	# Add the request bubble functionality
	var request_node = Node2D.new()
	request_node.name = "RequestBubble"
	request_node.set_script(load("res://WhenNearShowRequest.gd"))
	npc.add_child(request_node)
	
	# Add key prompts to the NPC
	_add_key_prompts_to_npc(npc)
	
	current_npcs += 1
	print("SPAWNER DEBUG: Current NPC count: ", current_npcs)
	print("=== SPAWNER DEBUG: NPC spawn complete ===\n")

# Debug function to print node tree
func _print_node_tree(node: Node, indent: int) -> void:
	var indent_str = ""
	for i in range(indent):
		indent_str += "  "
	
	print(indent_str + node.name + " (" + node.get_class() + ")")
	
	for child in node.get_children():
		_print_node_tree(child, indent + 1)

# Called when spawn timer expires
func _on_spawn_timer_timeout() -> void:
	print("SPAWNER DEBUG: Spawn timer timeout")
	spawn_npc()

# Called when an NPC leaves
func _on_npc_left() -> void:
	current_npcs -= 1
	print("SPAWNER DEBUG: NPC left, current count: ", current_npcs)

# Manually spawn an NPC
func trigger_spawn() -> void:
	print("SPAWNER DEBUG: Manual spawn triggered")
	spawn_npc()

# Set the spawn interval and restart the timer
func set_spawn_interval(interval: float) -> void:
	spawn_interval = interval
	spawn_timer.wait_time = interval
	print("SPAWNER DEBUG: Spawn interval set to: ", interval)
	if spawn_timer.is_stopped() == false:
		spawn_timer.start() 

# Add key prompts to an NPC
func _add_key_prompts_to_npc(npc_instance):
	# Create the key prompt controller
	var key_prompts = load("res://RevealPlayerControls.gd").new()
	key_prompts.name = "KeyPrompts"
	
	# Configure the key prompt properties
	key_prompts.detection_radius = 60.0  # Reduced from 120.0 to make players need to be 50% closer
	key_prompts.bubble_offset = Vector2(0, -10)  # Lower position above NPC's head
	key_prompts.show_debug = true  # Enable for debugging, set to false later
	key_prompts.action_description = "Talk"  # What pressing the key will do
	
	# Add the key prompt controller to the NPC
	npc_instance.add_child(key_prompts)
	
	# Optional: print debug info
	print("Added key prompts to NPC: ", npc_instance.name) 
