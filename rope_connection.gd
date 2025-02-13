extends Node2D

@export var player1_path: NodePath = "../../Node2D/Player1"
@export var player2_path: NodePath = "../../Node2D/Player2"
@export var max_length: float = 500.0
@export var pull_strength: float = 5000.0
@export var momentum_threshold: float = 50.0  # Minimum speed to be considered "moving"
@export var retraction_speed: float = 300.0  # Speed at which the rope retracts
@export var min_rope_length: float = 20.0  # Minimum rope length (decreased from 50)

var player1: CharacterBody2D
var player2: CharacterBody2D
var p1_momentum: float = 0.0
var p2_momentum: float = 0.0
var current_max_length: float  # Current maximum length of the rope
var is_left_shift_pressed: bool = false
var is_right_shift_pressed: bool = false
var is_broken: bool = false
var drag_sound: AudioStreamPlayer

# Line2D node to visualize the rope
@onready var rope_visual: Line2D = $Line2D

# Replace the single DRAG_SOUND constant with an array
const DRAG_SOUNDS = [
	preload("res://drag_1.mp3"),
	preload("res://drag_2.mp3"),
	preload("res://drag_3.mp3")
]

# Add texture-related constants
const ROPE_TEXTURE = preload("res://Rope.png")
const TEXTURE_MODE = Line2D.LINE_TEXTURE_TILE
const TEXTURE_REPEAT = CanvasItem.TEXTURE_REPEAT_ENABLED  # Use the correct enum value

func _ready() -> void:
	if player1_path.is_empty() or player2_path.is_empty():
		push_error("Player paths not set in RopeConnection!")
		return
		
	player1 = get_node_or_null(player1_path)
	player2 = get_node_or_null(player2_path)
	
	if !player1:
		push_error("Player1 not found at path: " + str(player1_path))
	if !player2:
		push_error("Player2 not found at path: " + str(player2_path))
	
	# Configure the existing Line2D node
	print("Loading rope texture...")
	var texture = load("res://Rope.png")
	print("Texture loaded: ", texture != null)
	
	rope_visual.width = 8.0
	rope_visual.texture = texture
	print("Texture assigned to rope: ", rope_visual.texture != null)
	rope_visual.texture_mode = Line2D.LINE_TEXTURE_TILE
	rope_visual.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	rope_visual.default_color = Color.WHITE
	
	current_max_length = max_length  # Initialize current length
	add_to_group("rope")
	
	# Setup drag sound
	drag_sound = AudioStreamPlayer.new()
	add_child(drag_sound)
	
	if DRAG_SOUNDS.size() > 0:
		print("Successfully loaded drag sounds")
	else:
		push_error("No drag sounds available!")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_SHIFT:
		match event.location:
			KEY_LOCATION_LEFT:
				is_left_shift_pressed = event.pressed
			KEY_LOCATION_RIGHT:
				is_right_shift_pressed = event.pressed

func _physics_process(delta: float) -> void:
	if is_broken or !player1 or !player2:
		return

	# Check if either player is involved in carrying
	if player1.is_involved_in_carrying() or player2.is_involved_in_carrying():
		# Skip rope pulling logic but still update rope visual
		rope_visual.clear_points()
		rope_visual.add_point(player1.global_position)
		rope_visual.add_point(player2.global_position)
		return

	# Calculate rope direction and actual distance between players
	var direction: Vector2 = player2.global_position - player1.global_position
	var actual_distance: float = direction.length()

	# Handle rope retraction input with looping sound
	if is_left_shift_pressed or is_right_shift_pressed:  # If either shift is pressed
		if !drag_sound.playing:
			print("Attempting to play drag sound")
			if DRAG_SOUNDS.size() > 0:
				# Pick a random sound from the array
				drag_sound.stream = DRAG_SOUNDS[randi() % DRAG_SOUNDS.size()]
				drag_sound.play()
				print("Play command sent. Playing state: ", drag_sound.playing)
			else:
				print("No drag sounds available!")
	else:
		drag_sound.stop()

	# Handle rope retraction mechanics
	if is_left_shift_pressed:  # Left Shift pulls Player2 to Player1
		current_max_length = max(actual_distance - retraction_speed * delta, min_rope_length)
		var pull_dir = (player1.global_position - player2.global_position).normalized()
		player2.velocity += pull_dir * pull_strength * delta
		
		# Apply gravity reduction when pulling up
		if pull_dir.y < 0:  # If being pulled upward
			player2.velocity.y *= 0.8  # Reduce gravity influence
		
	elif is_right_shift_pressed:  # Right Shift pulls Player1 to Player2
		current_max_length = max(actual_distance - retraction_speed * delta, min_rope_length)
		var pull_dir = (player2.global_position - player1.global_position).normalized()
		player1.velocity += pull_dir * pull_strength * delta
		
		# Apply gravity reduction when pulling up
		if pull_dir.y < 0:  # If being pulled upward
			player1.velocity.y *= 0.8  # Reduce gravity influence
	else:
		current_max_length = min(actual_distance, max_length)
	
	# Update rope visual
	rope_visual.clear_points()
	rope_visual.add_point(player1.global_position)
	rope_visual.add_point(player2.global_position)
	
	# Only apply constraint forces if not being pulled by shift keys
	if actual_distance > current_max_length and !is_left_shift_pressed and !is_right_shift_pressed:
		direction = direction.normalized()
		
		# Apply forces to both players equally
		var excess_distance = actual_distance - current_max_length
		var correction = excess_distance * pull_strength * delta * 0.5
		
		var p1_to_p2 = direction
		var p2_to_p1 = -direction
		
		player1.velocity += p1_to_p2 * correction
		player2.velocity += p2_to_p1 * correction
		
		# Reduce gravity effect when being pulled up for both players
		if p1_to_p2.y < 0:  # If player1 is being pulled upward
			player1.velocity.y *= 0.8
		if p2_to_p1.y < 0:  # If player2 is being pulled upward
			player2.velocity.y *= 0.8

	# Update momentum values
	p1_momentum = player1.get_momentum()
	p2_momentum = player2.get_momentum()
	
	# Preserve gravity for grounded players
	if player1.is_on_floor():
		player1.velocity.y = max(player1.velocity.y, 0)
	if player2.is_on_floor():
		player2.velocity.y = max(player2.velocity.y, 0)

		# Additional constraint to try to maintain exact rope length
		var post_velocity_p1 = player1.global_position + player1.velocity * delta
		var post_velocity_p2 = player2.global_position + player2.velocity * delta
		var post_distance = post_velocity_p1.distance_to(post_velocity_p2)
		
		if abs(post_distance - actual_distance) > 1.0:  # Allow 1 pixel tolerance
			var correction = (post_distance - actual_distance) * 0.5
			var correction_dir = (post_velocity_p2 - post_velocity_p1).normalized()
			
			if !player1.is_on_floor():
				player1.velocity += correction_dir * correction
			if !player2.is_on_floor():
				player2.velocity -= correction_dir * correction 

func break_connection() -> void:
	is_broken = true
	rope_visual.visible = false  # Hide the rope
	if drag_sound:
		drag_sound.stop()
	set_physics_process(false)  # Stop processing physics 
