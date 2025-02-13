extends CharacterBody2D

const SPEED = 400.0
const JUMP_VELOCITY = -350.0  # Slightly reduced initial jump
const DOUBLE_JUMP_MULTIPLIER = 1.3  # Second jump will be 30% higher
const FALL_GRAVITY_MULTIPLIER = 1.5  # Faster falling
const GRAVITY = Vector2(0, 980)
const MOMENTUM_DECAY = 0.95  # How quickly momentum decays
const MAX_JUMPS = 2  # Maximum number of jumps allowed

# Add sprite reference
@onready var sprite = $player  # Make sure you have a Sprite2D node as a child named "Sprite2D"
var momentum: float = 0.0
var jumps_remaining: int = MAX_JUMPS  # Track remaining jumps
var is_being_carried: bool = false
var carrier: CharacterBody2D = null

@export var initial_position: Vector2  # Add this at the top with other constants
var is_active: bool = true  # Add this to track if player is still in game

@onready var collision_shape = $CollisionShape2D
var original_size: Vector2 = Vector2.ZERO  # Changed from original_height
var carry_position: Node2D
var carrying_player: CharacterBody2D = null

# Add at top with other variables
var walk_sound: AudioStreamPlayer
var is_walking := false
var grab_sound: AudioStreamPlayer
var death_sound: AudioStreamPlayer
var jump_sound: AudioStreamPlayer
var launch_sound: AudioStreamPlayer

# Near the top with other constants
const PLAYER2_TEXTURE_PATH := "res://Player2.png"

# Add these constants for the trail effect
const TRAIL_LIFETIME := 0.5  # How long each trail particle lasts
const TRAIL_FREQUENCY := 0.05  # How often to emit trail particles
const TRAIL_AMOUNT := 3  # How many particles to emit each time

# Add these variables with other vars
var trail_particles: GPUParticles2D
var trail_timer: Timer
var is_trailing := false

func _ready() -> void:
	# Add this before other _ready code
	# Load and set Player2 texture
	var texture = load(PLAYER2_TEXTURE_PATH)
	if texture:
		sprite.texture = texture
	else:
		push_error("Failed to load Player2 texture")
	
	# Create CarryPosition node
	carry_position = Node2D.new()
	carry_position.name = "CarryPosition"
	add_child(carry_position)
	carry_position.position = Vector2(0, -19)
	
	# Store original collision size
	original_size = collision_shape.shape.size  # Changed from height
	
	# Add L key input action
	if not InputMap.has_action("l_key"):
		InputMap.add_action("l_key")
		var event = InputEventKey.new()
		event.keycode = KEY_L
		InputMap.action_add_event("l_key", event)
	
	initial_position = global_position

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

	# Setup trail particles
	setup_trail_particles()
	
	# Setup trail timer
	trail_timer = Timer.new()
	trail_timer.wait_time = TRAIL_FREQUENCY
	trail_timer.one_shot = false
	trail_timer.timeout.connect(_on_trail_timer_timeout)
	add_child(trail_timer)

func _physics_process(delta: float) -> void:
	if !is_active:
		return

	# Check for pickup action with L key
	if Input.is_action_just_pressed("l_key"):
		if !carrying_player:
			var players = get_tree().get_nodes_in_group("players")
			for player in players:
				if player != self and player.is_active:
					var distance = global_position.distance_to(player.global_position)
					print("Distance to player: ", distance)  # Debug print
					if distance < 75:  # Increased from 50 to 75
						carrying_player = player
						player.being_carried_by(self)
						# Play grab sound
						grab_sound.play()
						# Double the collision height when carrying
						var current_size = collision_shape.shape.size
						collision_shape.shape.size = Vector2(current_size.x, current_size.y * 2)
						# Move collision shape up to account for new height
						collision_shape.position.y = -current_size.y / 2
						break

	if carrying_player:
		carrying_player.global_position = carry_position.global_position
		carrying_player.velocity = velocity

	if is_being_carried:
		# Only check for breaking free - don't do any physics
		if Input.is_action_just_pressed("ui_left") or Input.is_action_just_pressed("ui_right") or Input.is_action_just_pressed("ui_up"):
			var carrier_velocity = carrier.velocity  # Store carrier velocity before breaking free
			stop_being_carried()
			launch_sound.play()  # Play launch sound when breaking free
			# Super boost jump - multiply both horizontal and vertical momentum
			velocity += Vector2(carrier_velocity.x * 2.0, carrier_velocity.y * 2.0 - 500)  # Double both components and add upward boost
		return  # Skip all other physics while being carried

	# Add gravity with higher fall speed
	if not is_on_floor():
		var gravity_multiplier = FALL_GRAVITY_MULTIPLIER if velocity.y > 0 else 1.0
		velocity += GRAVITY * gravity_multiplier * delta
		momentum = velocity.length()
	else:
		momentum *= MOMENTUM_DECAY
		jumps_remaining = MAX_JUMPS  # Reset jumps when touching ground

	# Handle variable jump height
	if Input.is_action_just_pressed("ui_up") and jumps_remaining > 0:
		var jump_power = JUMP_VELOCITY
		if jumps_remaining < MAX_JUMPS:  # If this is the second jump
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
	if Input.is_action_just_released("ui_up") and velocity.y < 0:
		velocity.y *= 0.5

	# Get the input direction and handle the movement/deceleration.
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
		momentum = abs(velocity.x)
		sprite.scale.x = 1 if direction < 0 else -1
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * delta * 10)
		momentum *= MOMENTUM_DECAY

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
	set_physics_process(false)  # Stop processing physics
	hide()
	get_node("/root/Root").player_finished()

func _enter_tree() -> void:
	add_to_group("players")

func being_carried_by(new_carrier: CharacterBody2D) -> void:
	is_being_carried = true
	carrier = new_carrier
	# Only disable collision with other players while being carried
	# Assuming layer 1 is for player collision and layer 2 is for environment
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
		# Start trail effect when launching
		start_trail_effect()
		# Then tell the carrier to stop
		temp_carrier.stop_carrying()

func stop_carrying() -> void:
	if carrying_player:
		# Reset collision shape to original size
		collision_shape.shape.size = original_size  # Changed from height
		collision_shape.position.y = 0
		# Use same super boost as jumping off
		carrying_player.velocity += Vector2(velocity.x * 2.0, velocity.y * 2.0 - 500)
		carrying_player.stop_being_carried()
		carrying_player = null

func is_involved_in_carrying() -> bool:
	return is_being_carried or carrying_player != null

func setup_trail_particles() -> void:
	trail_particles = GPUParticles2D.new()
	add_child(trail_particles)
	
	# Create particle material
	var particle_material = ParticleProcessMaterial.new()
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	particle_material.particle_flag_disable_z = true
	particle_material.gravity = Vector3(0, 0, 0)
	particle_material.initial_velocity_min = 0
	particle_material.initial_velocity_max = 0
	particle_material.orbit_velocity_min = 0
	particle_material.orbit_velocity_max = 0
	particle_material.damping_min = 0.5
	particle_material.damping_max = 1.0
	particle_material.scale_min = 1.0
	particle_material.scale_max = 1.0
	particle_material.lifetime_randomness = 0.2
	
	# Set up the particles
	trail_particles.process_material = particle_material
	trail_particles.amount = 50
	trail_particles.lifetime = TRAIL_LIFETIME
	trail_particles.one_shot = false
	trail_particles.explosiveness = 0
	trail_particles.local_coords = false
	
	# Create sprite for particles
	var sprite = sprite.duplicate()  # Duplicate the player sprite
	sprite.scale = Vector2(1, 1)  # Reset scale
	trail_particles.texture = sprite.texture
	trail_particles.emitting = false

func start_trail_effect() -> void:
	is_trailing = true
	trail_particles.emitting = true
	trail_timer.start()

func stop_trail_effect() -> void:
	is_trailing = false
	trail_particles.emitting = false
	trail_timer.stop()

func _on_trail_timer_timeout() -> void:
	if is_trailing:
		trail_particles.restart()
		trail_particles.emit_particle(transform, velocity, Color.WHITE, Color.WHITE, TRAIL_AMOUNT)
		# Stop trailing if velocity is too low
		if velocity.length() < 200:
			stop_trail_effect()
