extends CharacterBody2D

const SPEED = 400.0
const JUMP_VELOCITY = -350.0  # Slightly reduced initial jump
const DOUBLE_JUMP_MULTIPLIER = 1.3  # Second jump will be 30% higher
const FALL_GRAVITY_MULTIPLIER = 1.5  # Faster falling
const GRAVITY = Vector2(0, 980)
const MOMENTUM_DECAY = 0.95  # How quickly momentum decays
const MAX_JUMPS = 2  # Maximum number of jumps allowed
const PLAYER1_TEXTURE_PATH := "res://VeloSprite.png"
const FRAME_WIDTH := 16  # Width of each frame
const ANIMATION_SPEED := 10.0  # Frames per second

# Player configuration options
@export_category("Player Settings")
@export_group("Gameplay Options")
@export var disable_pickup: bool = false  # When checked, this player cannot pick up other players

# Add sprite reference
@onready var sprite = $player  # Make sure you have a Sprite2D node as a child named "Sprite2D"
var carry_position: Node2D  # Changed to regular var instead of @onready
var momentum: float = 0.0
var jumps_remaining: int = MAX_JUMPS  # Track remaining jumps
var carrying_player: CharacterBody2D = null  # Reference to carried player

@export var initial_position: Vector2  # Add this at the top with other constants
var is_active: bool = true  # Add this to track if player is still in game

@onready var collision_shape = $CollisionShape2D  # Add this at top with other onready vars
var original_size: Vector2 = Vector2.ZERO  # Changed from original_height

# Add these variables at the top with other vars
var is_being_carried: bool = false
var carrier: CharacterBody2D = null

# Add at top with other variables
var walk_sound: AudioStreamPlayer
var is_walking := false
var grab_sound: AudioStreamPlayer
var death_sound: AudioStreamPlayer
var jump_sound: AudioStreamPlayer
var launch_sound: AudioStreamPlayer
var animation_timer: float = 0.0
var current_frame: int = 0

# Add this signal at the top of the file with other constants
signal physics_process(player: CharacterBody2D)

func _ready() -> void:
	# Load and set Player1 texture with correct pixel art settings
	var texture = load(PLAYER1_TEXTURE_PATH)
	if texture:
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Set up sprite for animation
		sprite.hframes = 4  # 4 frames horizontally
		sprite.frame = 0  # Start with first frame
	else:
		push_error("Failed to load Player1 texture")
	
	# Create CarryPosition node if it doesn't exist
	carry_position = Node2D.new()
	carry_position.name = "CarryPosition"
	add_child(carry_position)
	carry_position.position = Vector2(0, -13)  # Adjusted for 16x16 sprite
	
	# Add player to the correct group based on its name
	if name == "Player1":
		add_to_group("player1")
	elif name == "Player2":
		add_to_group("player2")
	
	# Add input actions if they don't exist
	if not InputMap.has_action("w"):
		InputMap.add_action("w")
		var event = InputEventKey.new()
		event.keycode = KEY_W
		InputMap.action_add_event("w", event)
	
	if not InputMap.has_action("a"):
		InputMap.add_action("a")
		var event = InputEventKey.new()
		event.keycode = KEY_A
		InputMap.action_add_event("a", event)
	
	if not InputMap.has_action("d"):
		InputMap.add_action("d")
		var event = InputEventKey.new()
		event.keycode = KEY_D
		InputMap.action_add_event("d", event)

	if not InputMap.has_action("e"):
		InputMap.add_action("e")
		var event = InputEventKey.new()
		event.keycode = KEY_E
		InputMap.action_add_event("e", event)

	initial_position = global_position  # Store initial position

	# Store original collision size
	original_size = collision_shape.shape.size  # Changed from height

	# Setup walking sound
	walk_sound = AudioStreamPlayer.new()
	add_child(walk_sound)
	var sound = load("res://walk.mp3")
	if sound:
		walk_sound.stream = sound
		walk_sound.volume_db = linear_to_db(0.3)  # Adjust volume as needed

	# Setup grab sound
	grab_sound = AudioStreamPlayer.new()
	add_child(grab_sound)
	var grab_audio = load("res://grab.mp3")
	if grab_audio:
		grab_sound.stream = grab_audio
		grab_sound.volume_db = linear_to_db(0.3)  # Adjust volume as needed

	# Setup death sound
	death_sound = AudioStreamPlayer.new()
	add_child(death_sound)
	var death_audio = load("res://death.mp3")
	if death_audio:
		death_sound.stream = death_audio
		death_sound.volume_db = linear_to_db(0.3)  # Adjust volume as needed

	# Setup jump sound
	jump_sound = AudioStreamPlayer.new()
	add_child(jump_sound)
	var jump_audio = load("res://jump.mp3")
	if jump_audio:
		jump_sound.stream = jump_audio

	# Setup launch sound
	launch_sound = AudioStreamPlayer.new()
	add_child(launch_sound)
	var launch_audio = load("res://launch.mp3")
	if launch_audio:
		launch_sound.stream = launch_audio
		launch_sound.volume_db = linear_to_db(0.3)

func _physics_process(delta: float) -> void:
	if !is_active:
		return
		
	# Add this line at the start of the function
	physics_process.emit(self)

	if is_being_carried:
		# Only check for breaking free - don't do any physics
		if Input.is_action_just_pressed("w") or Input.is_action_just_pressed("a") or Input.is_action_just_pressed("d"):
			var carrier_velocity = carrier.velocity  # Store carrier velocity before breaking free
			stop_being_carried()
			launch_sound.play()  # Play launch sound when breaking free
			# Super boost jump - multiply both horizontal and vertical momentum
			velocity += Vector2(carrier_velocity.x * 2.0, carrier_velocity.y * 2.0 - 500)  # Double both components and add upward boost
		return  # Skip all other physics while being carried

	# Check for pickup action
	if Input.is_action_just_pressed("e") and !disable_pickup:
		if !carrying_player:  # If not carrying anyone
			var players = get_tree().get_nodes_in_group("players")
			for player in players:
				if player != self and player.is_active:
					var distance = global_position.distance_to(player.global_position)
					print("Distance to player: ", distance)  # Debug print
					if distance < 75:  # Increased from 50 to 75
						# Try nudging to find a safe spot for pickup
						var safe_pos = _find_safe_pickup_position(player)
						if safe_pos:
							# Move to safe position before pickup
							global_position = safe_pos
							carrying_player = player
							player.being_carried_by(self)
							# Play grab sound
							grab_sound.play()
							# Double the collision height when carrying
							var current_size = collision_shape.shape.size
							collision_shape.shape.size = Vector2(current_size.x, current_size.y * 2)
							# Move collision shape up to account for new height
							collision_shape.position.y = -current_size.y / 2
						else:
							print("Cannot pickup - could not find safe position")
						break

	var can_move_up = true
	# Check carried player collisions before moving
	if carrying_player:
		# Update carried player position
		carrying_player.global_position = carry_position.global_position
		carrying_player.velocity = velocity
		
		# Emergency drop if we're stuck
		if Input.is_action_just_pressed("w") and Input.is_action_pressed("e"):
			print("Emergency drop activated!")
			stop_carrying()
		
		# Try to nudge out if we're stuck
		_try_nudge_when_carrying()

	# Add gravity with higher fall speed
	if not is_on_floor():
		var gravity_multiplier = FALL_GRAVITY_MULTIPLIER if velocity.y > 0 else 1.0
		velocity += GRAVITY * gravity_multiplier * delta
		momentum = velocity.length()
	else:
		momentum *= MOMENTUM_DECAY
		jumps_remaining = MAX_JUMPS

	# Handle variable jump height - check if we can move up first
	if Input.is_action_just_pressed("w") and jumps_remaining > 0 and can_move_up:
		var jump_power = JUMP_VELOCITY
		if jumps_remaining < MAX_JUMPS:
			jump_power *= DOUBLE_JUMP_MULTIPLIER
			# Second jump - higher volume
			jump_sound.volume_db = linear_to_db(0.5)
		else:
			# First jump - lower volume
			jump_sound.volume_db = linear_to_db(0.3)
		
		jump_sound.play()  # Play the jump sound
		velocity.y = jump_power
		momentum = abs(jump_power)
		jumps_remaining -= 1
	# Cut the jump short if button is released
	if Input.is_action_just_released("w") and velocity.y < 0:
		velocity.y *= 0.5

	# Get the input direction and handle the movement/deceleration.
	var direction := Input.get_axis("a", "d")
	if direction:
		velocity.x = direction * SPEED
		momentum = abs(velocity.x)
		sprite.flip_h = direction > 0
		
		# Update animation
		is_walking = true
		animation_timer += delta * ANIMATION_SPEED
		if animation_timer >= 1.0:
			animation_timer = 0.0
			current_frame = (current_frame + 1) % 4
			sprite.frame = current_frame
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * delta * 10)
		momentum *= MOMENTUM_DECAY
		# Reset to idle frame when not walking
		is_walking = false
		current_frame = 0
		sprite.frame = 0
		animation_timer = 0.0

	# Handle walking sound
	if direction and is_on_floor():
		if !is_walking:
			is_walking = true
			walk_sound.play()
	else:
		is_walking = false
		walk_sound.stop()

	move_and_slide()

func get_momentum() -> float:
	return momentum

# Add these new functions
func hit_water() -> void:
	# Play death sound
	death_sound.play()
	
	global_position = initial_position
	velocity = Vector2.ZERO
	momentum = 0
	jumps_remaining = MAX_JUMPS
	
	# Signal other player to respawn
	get_tree().call_group("players", "force_respawn")

func force_respawn() -> void:
	global_position = initial_position
	velocity = Vector2.ZERO
	momentum = 0
	jumps_remaining = MAX_JUMPS

func hit_door() -> void:
	is_active = false
	get_tree().call_group("rope", "break_connection")
	# Disable collisions
	set_collision_layer_value(1, false)  # Disable player collision layer
	set_collision_layer_value(2, false)  # Disable environment collision layer
	set_collision_mask_value(1, false)   # Disable player collision mask
	set_collision_mask_value(2, false)   # Disable environment collision mask
	call_deferred("_complete_door_hit")

func _complete_door_hit() -> void:
	set_physics_process(false)
	hide()
	get_node("/root/Root").player_finished()

func _enter_tree() -> void:
	add_to_group("players")

func stop_carrying() -> void:
	if carrying_player:
		# Reset collision shape to original size
		collision_shape.shape.size = original_size  # Changed from height
		collision_shape.position.y = 0
		# Use same super boost as jumping off
		carrying_player.velocity += Vector2(velocity.x * 2.0, velocity.y * 2.0 - 500)
		carrying_player.stop_being_carried()
		carrying_player = null

func being_carried_by(new_carrier: CharacterBody2D) -> void:
	is_being_carried = true
	carrier = new_carrier
	# Only disable collision with other players while being carried
	set_collision_layer_value(1, false)  # Don't collide with other players
	set_collision_mask_value(1, false)   # Don't detect other players
	velocity = Vector2.ZERO

func stop_being_carried() -> void:
	if carrier:
		var temp_carrier = carrier
		carrier = null
		is_being_carried = false
		# Re-enable collision
		set_collision_layer_value(1, true)
		set_collision_mask_value(1, true)
		# Then tell the carrier to stop
		temp_carrier.stop_carrying()

func transport() -> void:
	# Reset state but don't deactivate
	velocity = Vector2.ZERO
	momentum = 0
	jumps_remaining = MAX_JUMPS
	
	# Stop any carrying interactions
	stop_carrying()
	stop_being_carried()
	
	# Reset collision shape size just in case
	if collision_shape:
		collision_shape.shape.size = original_size
		collision_shape.position.y = 0
		
	# Reset to initial position when transported to new scene
	if initial_position != Vector2.ZERO:
		global_position = initial_position

func is_involved_in_carrying() -> bool:
	return is_being_carried or carrying_player != null

# Add this new function to check if pickup is safe
func _can_safely_pickup(player_to_pickup: CharacterBody2D) -> bool:
	# Save original state
	var original_size = collision_shape.shape.size
	var original_offset = collision_shape.position
	
	# Temporarily modify collision shape to test the stacked position
	var test_size = Vector2(original_size.x, original_size.y * 2)
	collision_shape.shape.size = test_size
	collision_shape.position.y = -original_size.y / 2
	
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	query.set_shape(collision_shape.shape)
	query.collision_mask = collision_mask
	query.exclude = [self, player_to_pickup]
	
	# Check current position
	var transform = Transform2D(0, global_position)
	query.transform = transform
	var result = space_state.intersect_shape(query)
	
	if result.size() > 0:
		# Restore original shape and return false if we collide right away
		collision_shape.shape.size = original_size
		collision_shape.position = original_offset
		return false
	
	# Check above for ceilings (important for jumps)
	var ceiling_check = Transform2D(0, global_position + Vector2(0, -20))
	query.transform = ceiling_check
	result = space_state.intersect_shape(query)
	
	if result.size() > 0:
		# Restore original shape and return false if ceiling is too low
		collision_shape.shape.size = original_size
		collision_shape.position = original_offset
		return false
	
	# Check multiple directions to ensure there's room to move
	var directions = [
		Vector2(original_size.x, 0),  # Right
		Vector2(-original_size.x, 0), # Left
		Vector2(0, original_size.y),  # Down
		Vector2(original_size.x, -original_size.y),  # Up-right
		Vector2(-original_size.x, -original_size.y)  # Up-left
	]
	
	for dir in directions:
		var pos_check = Transform2D(0, global_position + dir)
		query.transform = pos_check
		result = space_state.intersect_shape(query)
		
		if result.size() > 0:
			# If we can't move in important directions, don't pick up
			collision_shape.shape.size = original_size
			collision_shape.position = original_offset
			return false
	
	# Restore original collision shape
	collision_shape.shape.size = original_size
	collision_shape.position = original_offset
	
	# We've checked multiple positions and they're all clear
	return true

# Add this function to handle nudging when stuck
func _try_nudge_when_carrying() -> bool:
	if !carrying_player:
		return false
		
	# First, check if we're actually in a collision state
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	query.set_shape(collision_shape.shape)
	query.collision_mask = collision_mask
	query.exclude = [self, carrying_player]
	query.transform = Transform2D(0, global_position)
	
	# If no collision detected, no need to nudge
	if space_state.intersect_shape(query).size() == 0:
		return false
		
	# We're in a collision, try to nudge in several directions
	print("Detecting collision while carrying, attempting to nudge...")
	
	# Try nudging in multiple directions with increasing distance
	var nudge_directions = [
		Vector2(16, 0),    # Right
		Vector2(-16, 0),   # Left
		Vector2(32, 0),    # Further right
		Vector2(-32, 0),   # Further left
		Vector2(0, -16),   # Up
		Vector2(0, -32)    # Further up
	]
	
	for nudge in nudge_directions:
		# Test position after nudge
		query.transform = Transform2D(0, global_position + nudge)
		if space_state.intersect_shape(query).size() == 0:
			# Found safe position, move there
			global_position += nudge
			print("Successfully nudged to avoid collision")
			return true
	
	# If we get here, we couldn't find a safe spot
	print("Could not find safe position, dropping player")
	stop_carrying()
	return false

# Add this function to find a safe pickup position
func _find_safe_pickup_position(player_to_pickup: CharacterBody2D) -> Vector2:
	# Check current position first
	if _can_safely_pickup(player_to_pickup):
		return global_position
	
	# Try positions nearby
	var original_pos = global_position
	var nudge_directions = [
		Vector2(16, 0),    # Right
		Vector2(-16, 0),   # Left
		Vector2(0, -16),   # Up
		Vector2(16, -16),  # Up-right
		Vector2(-16, -16), # Up-left
		Vector2(32, 0),    # Further right
		Vector2(-32, 0)    # Further left
	]
	
	for nudge in nudge_directions:
		var test_pos = original_pos + nudge
		global_position = test_pos
		if _can_safely_pickup(player_to_pickup):
			global_position = original_pos  # Reset position
			return test_pos
	
	# No safe position found
	global_position = original_pos  # Reset position
	return Vector2.ZERO
