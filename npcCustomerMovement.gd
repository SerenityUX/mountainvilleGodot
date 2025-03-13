extends Node2D

# ----------------------------------------
# HOW TO USE THIS SCRIPT:
# ----------------------------------------
# 1. Attach this script to a Node2D that will represent your frog NPC
# 2. Add a Sprite2D as a child (named "Sprite2D") or the script will create one
# 3. Set the sprite_sheet property to your 16x64 sprite sheet (with 4 frames of 16x16)
# 
# EXPORTED PARAMETERS:
# - movement_speed: How fast the character moves
# - sprite_sheet: Your 16x64 animation sprite sheet
# - animation_fps: How fast the animation plays
# - test_animation: Enable for automatic back-and-forth movement test
# - test_distance: How far to move during testing
#
# CALLING FROM OTHER SCRIPTS:
# ```
# # Get a reference to the NPC
# var frog = get_node("Path/To/Frog")
#
# # Move right for 2 seconds
# frog.move_right(2.0)
#
# # Move left indefinitely
# frog.move_left()
#
# # Stop movement manually
# frog.stop_moving()
# ```
# ----------------------------------------

# Movement parameters
@export var movement_speed: float = 100.0
@export var sprite_sheet: Texture
@export var animation_fps: float = 8.0
@export var test_animation: bool = false
@export var test_distance: float = 100.0

# Node references
var sprite: Sprite2D

# Animation variables
var current_frame: int = 0
var frame_time: float = 0.0
var moving: bool = false
var move_direction: Vector2 = Vector2.ZERO
var test_moving_right: bool = true
var initial_position: Vector2
var initialized: bool = false
var frame_count: int = 0  # For debugging animation frames

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("NPC DEBUG: _ready called for node: ", name, " at position: ", position)
	print("NPC DEBUG: test_animation is: ", test_animation)
	print("NPC DEBUG: movement_speed is: ", movement_speed)
	
	# Handle the sprite safely
	_initialize_sprite()
	
	# Store initial position for testing
	initial_position = position
	print("NPC DEBUG: Initial position set to: ", initial_position)
	
	# Calculate frame time based on animation_fps
	frame_time = 1.0 / animation_fps
	print("NPC DEBUG: Frame time set to: ", frame_time)
	
	# Mark as initialized
	initialized = true
	print("NPC DEBUG: Marked as initialized")
	
	# Debugging - dump tree
	print("NPC DEBUG: Node hierarchy:")
	_print_node_tree(self, 0)
	
	# Initialize test animation if enabled
	if test_animation:
		print("NPC DEBUG: Test animation enabled at _ready, starting now")
		_start_test_animation()
	else:
		print("NPC DEBUG: Test animation not enabled at _ready")

# Debug function to print node tree
func _print_node_tree(node: Node, indent: int) -> void:
	var indent_str = ""
	for i in range(indent):
		indent_str += "  "
	
	print(indent_str + node.name + " (" + node.get_class() + ")")
	
	for child in node.get_children():
		_print_node_tree(child, indent + 1)

# Safely initialize the sprite
func _initialize_sprite() -> void:
	print("NPC DEBUG: Initializing sprite...")
	
	# Check if sprite already exists
	if sprite:
		print("NPC DEBUG: Sprite already exists, reusing")
		return
	
	# Try to get the child sprite
	sprite = get_node_or_null("Sprite2D")
	
	# Create a Sprite2D if it doesn't exist
	if not sprite:
		print("NPC DEBUG: No Sprite2D found, creating new one")
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)
	else:
		print("NPC DEBUG: Found existing Sprite2D")
	
	# Apply sprite sheet if provided
	if sprite_sheet:
		print("NPC DEBUG: Applied sprite sheet: ", sprite_sheet)
		sprite.texture = sprite_sheet
	else:
		print("NPC DEBUG: !!! NO SPRITE SHEET PROVIDED !!!")
	
	# Set up the sprite's region for animation frames
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, 16, 16)
	
	# Make sure the sprite is visible
	sprite.visible = true
	print("NPC DEBUG: Sprite visibility set to: ", sprite.visible)
	print("NPC DEBUG: Sprite setup complete with rect: ", sprite.region_rect)

# Start test animation
func _start_test_animation() -> void:
	print("NPC DEBUG: Starting test animation")
	test_moving_right = true
	moving = true
	move_direction = Vector2.RIGHT
	
	if sprite:
		sprite.flip_h = false
		print("NPC DEBUG: Set sprite flip_h to false")
	else:
		print("NPC DEBUG: !!! Sprite is null when trying to set flip_h !!!")

# Public function to move the frog left
func move_left(duration: float = 0.0) -> void:
	# Make sure sprite is initialized
	if not initialized:
		print("NPC DEBUG: Initializing in move_left")
		_initialize_sprite()
	
	print("NPC DEBUG: Moving left")
	moving = true
	move_direction = Vector2.LEFT
	
	if sprite:
		sprite.flip_h = true
	else:
		print("NPC DEBUG: !!! Sprite is null in move_left !!!")
	
	if duration > 0:
		var timer = get_tree().create_timer(duration)
		await timer.timeout
		stop_moving()

# Public function to move the frog right
func move_right(duration: float = 0.0) -> void:
	# Make sure sprite is initialized
	if not initialized:
		print("NPC DEBUG: Initializing in move_right")
		_initialize_sprite()
	
	print("NPC DEBUG: Moving right")
	moving = true
	move_direction = Vector2.RIGHT
	
	if sprite:
		sprite.flip_h = false
	else:
		print("NPC DEBUG: !!! Sprite is null in move_right !!!")
	
	if duration > 0:
		var timer = get_tree().create_timer(duration)
		await timer.timeout
		stop_moving()

# Stop the frog from moving
func stop_moving() -> void:
	print("NPC DEBUG: Stopping movement")
	moving = false
	move_direction = Vector2.ZERO
	# Reset to first frame when stopped
	update_animation_frame(0)

# Update the animation frame
func update_animation_frame(frame: int) -> void:
	if not sprite:
		print("NPC DEBUG: !!! Sprite is null in update_animation_frame !!!")
		return
	
	current_frame = frame
	# Update the region rect to show the correct frame
	# Each frame is 16x16, stacked vertically in the sprite sheet
	sprite.region_rect = Rect2(0, current_frame * 16, 16, 16)
	
	# Debug every 30 frames to avoid console spam
	frame_count += 1
	if frame_count % 30 == 0:
		print("NPC DEBUG: Updated animation frame to: ", current_frame)
		print("NPC DEBUG: Sprite region rect is now: ", sprite.region_rect)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Ensure sprite is initialized
	if not initialized:
		print("NPC DEBUG: Initializing in _process")
		_initialize_sprite()
		initialized = true
	
	# Handle movement
	if moving:
		var old_position = position
		position += move_direction * movement_speed * delta
		
		# Debug movement every 30 frames to avoid console spam
		frame_count += 1
		if frame_count % 30 == 0:
			print("NPC DEBUG: Moving from ", old_position, " to ", position, " with direction ", move_direction)
		
		# Handle animation timing
		frame_time -= delta
		if frame_time <= 0:
			frame_time = 1.0 / animation_fps
			# Cycle through frames 0-3
			current_frame = (current_frame + 1) % 4
			update_animation_frame(current_frame)
	
	# Test animation if enabled
	if test_animation:
		_handle_test_animation(delta)

# Handle the testing animation
func _handle_test_animation(delta: float) -> void:
	# Debug every 30 frames to avoid console spam
	frame_count += 1
	if frame_count % 30 == 0:
		print("NPC DEBUG: In _handle_test_animation - moving: ", moving, " test_moving_right: ", test_moving_right)
	
	if not moving and test_animation:
		print("NPC DEBUG: Not moving but test_animation is true, starting animation")
		_start_test_animation()
		return
	
	if test_moving_right:
		move_direction = Vector2.RIGHT
		if sprite:
			sprite.flip_h = false
		
		# If moved far enough to the right, switch direction
		if position.x >= initial_position.x + test_distance:
			print("NPC DEBUG: Reached right limit, switching to left")
			test_moving_right = false
			move_direction = Vector2.LEFT
			if sprite:
				sprite.flip_h = true
	else:
		move_direction = Vector2.LEFT
		if sprite:
			sprite.flip_h = true
		
		# If moved far enough to the left, switch direction
		if position.x <= initial_position.x - test_distance:
			print("NPC DEBUG: Reached left limit, switching to right")
			test_moving_right = true
			move_direction = Vector2.RIGHT
			if sprite:
				sprite.flip_h = false

# Property setter for test_animation
func set_test_animation(value: bool) -> void:
	print("NPC DEBUG: Setting test_animation to: ", value)
	test_animation = value
	if test_animation and initialized:
		print("NPC DEBUG: test_animation set to true and initialized, starting animation")
		_start_test_animation()
	elif test_animation:
		print("NPC DEBUG: test_animation set to true but not initialized yet") 
