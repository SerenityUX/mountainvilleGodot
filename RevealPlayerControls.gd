extends Node2D

# Configuration
@export var detection_radius: float = 100.0  # How close player needs to be to show key prompt
@export var key_texture: Texture2D  # Texture for the key to display (E, Space, etc.)
@export var key_name: String = "E"  # Name of the key (for default texture generation)
@export var bubble_offset: Vector2 = Vector2(0, -5)  # Position closer to player's head (lower)
@export var bubble_size: Vector2 = Vector2(2.5, 2.5)  # 50% smaller than before
@export var show_debug: bool = true  # Show debug info to track issues
@export var action_description: String = "Interact"  # What this key does

# Node references for each player bubble (will be created dynamically)
var player_bubbles = {}  # Dictionary to track bubbles for each player

# Pulse effect variables
var pulse_time: float = 0.0
var pulse_speed: float = 2.5  # Slow pulsing speed
var animation_offset: float = 4.0  # Minimal rise distance

# Called when the node enters the scene tree
func _ready() -> void:
	# Initially nothing to do until players come near
	pass

# Create a default key texture if none is provided
func _create_default_key_texture(key_name: String) -> Texture2D:
	# Create a higher resolution image for better detail
	var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	
	# Draw key-cap style background (rounded square)
	for x in range(16):
		for y in range(16):
			# Draw a square with rounded corners
			var center_x = 8
			var center_y = 8
			var half_size = 6
			var corner_radius = 2
			
			# Calculate distance from center
			var dx = abs(x - center_x)
			var dy = abs(y - center_y)
			
			# Basic square boundaries
			if dx <= half_size and dy <= half_size:
				# Check for rounded corners
				if dx > half_size - corner_radius and dy > half_size - corner_radius:
					# Distance from corner
					var corner_dx = dx - (half_size - corner_radius)
					var corner_dy = dy - (half_size - corner_radius)
					var corner_dist = sqrt(corner_dx * corner_dx + corner_dy * corner_dy)
					
					if corner_dist <= corner_radius:
						# Inside the rounded corner
						image.set_pixel(x, y, Color(0.25, 0.25, 0.25, 0.7)) # Gray with 70% opacity
					else:
						# Outside the corner radius
						image.set_pixel(x, y, Color(0, 0, 0, 0))
				else:
					# Inside the square but not in corner area
					image.set_pixel(x, y, Color(0.25, 0.25, 0.25, 0.7))
			else:
				# Outside the square
				image.set_pixel(x, y, Color(0, 0, 0, 0))
	
	# Draw key letter with white text
	var color = Color(1, 1, 1, 0.9)  # White text with 90% opacity
	
	# Higher resolution letter rendering
	if key_name == "E":
		# Draw E with more detail
		# Vertical line
		for y in range(4, 12):
			image.set_pixel(5, y, color)
			image.set_pixel(6, y, color)
		
		# Horizontal lines
		for x in range(6, 11):
			# Top
			image.set_pixel(x, 4, color)
			image.set_pixel(x, 5, color)
			
			# Middle
			image.set_pixel(x, 7, color)
			image.set_pixel(x, 8, color)
			
			# Bottom
			image.set_pixel(x, 11, color)
			image.set_pixel(x, 12, color)
			
	elif key_name == "L":
		# Draw L with more detail
		# Vertical line
		for y in range(4, 12):
			image.set_pixel(5, y, color)
			image.set_pixel(6, y, color)
		
		# Horizontal line (bottom)
		for x in range(6, 12):
			image.set_pixel(x, 11, color)
			image.set_pixel(x, 12, color)
	
	# Create the texture from the image
	var texture = ImageTexture.create_from_image(image)
	return texture

# Create a bubble for a player
func _create_bubble_for_player(player: Node2D) -> Node2D:
	var bubble = Node2D.new()
	bubble.name = "KeyPrompt"
	
	# Create bubble container at offset position
	bubble.position = bubble_offset
	
	# Set initial position with animation offset
	var current_position = Vector2(0, animation_offset)
	bubble.position += current_position
	
	# Track animation variables in the bubble
	bubble.set_meta("current_scale", 0.0)
	bubble.set_meta("target_scale", 0.0)
	bubble.set_meta("current_position", current_position)
	bubble.set_meta("target_position", Vector2.ZERO)
	bubble.set_meta("is_visible", false)
	bubble.set_meta("key_pressed", false)  # Track key press state
	
	# Create key sprite with background included
	var key_sprite = Sprite2D.new()
	key_sprite.name = "KeySprite"
	key_sprite.scale = Vector2(0.3, 0.3)  # 50% of previous 0.6 scale
	key_sprite.modulate.a = 0.9  # Slightly transparent by default
	
	# Use adapted key generation or texture
	var player_key = "E"  # Default key
	
	# Check player type
	var script_path = player.get_script().resource_path
	if "player2" in script_path.to_lower():
		player_key = "L"  # Player 2 uses L key
	else:
		player_key = "E"  # Player 1 uses E key
		
	# Store the key for input detection
	bubble.set_meta("key_name", player_key)
	
	if key_texture:
		key_sprite.texture = key_texture
	else:
		key_sprite.texture = _create_default_key_texture(player_key)
		
	key_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	# No shader material - removing shader to silence errors
	
	# Add child nodes
	bubble.add_child(key_sprite)
	
	# Set initial scale and visibility
	bubble.scale = Vector2.ZERO
	bubble.z_index = 10  # Above most elements
	bubble.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	return bubble

# Process animation and player detection
func _process(delta: float) -> void:
	# Update time for animations
	pulse_time += delta * pulse_speed
	
	# Get all active players
	var players = get_tree().get_nodes_in_group("players")
	
	# Debug: Print player count when debug is enabled
	if show_debug and Engine.get_frames_drawn() % 60 == 0:  # Once per second
		print("RevealPlayerControls: Found ", players.size(), " players")
		print("Current object position: ", global_position)
	
	var player_distances = {}
	
	# Check each player's distance to this object
	for player in players:
		if player.is_active:
			var distance = global_position.distance_to(player.global_position)
			player_distances[player] = distance
			
			# Debug distance when debug is enabled
			if show_debug and Engine.get_frames_drawn() % 60 == 0:  # Once per second
				print("Player distance: ", distance, " (detection radius: ", detection_radius, ")")
			
			# Create a bubble for this player if it doesn't exist yet
			if not player_bubbles.has(player):
				var bubble = _create_bubble_for_player(player)
				player.add_child(bubble)
				player_bubbles[player] = bubble
				
				if show_debug:
					print("Created bubble for player with script: ", player.get_script().resource_path)
	
	# Update each bubble based on player distance
	var to_remove = []
	for player in player_bubbles.keys():
		if not is_instance_valid(player) or not player.is_active:
			# Player is no longer valid, mark for removal
			to_remove.append(player)
			continue
			
		var bubble = player_bubbles[player]
		var distance = player_distances.get(player, INF)
		
		# Set target scale based on distance
		var target_scale = 1.0 if distance <= detection_radius else 0.0
		var target_position = Vector2.ZERO if distance <= detection_radius else Vector2(0, animation_offset)
		
		# Update bubble meta values
		bubble.set_meta("target_scale", target_scale)
		bubble.set_meta("target_position", target_position)
		
		# Update key sprite reference
		var key_sprite = bubble.get_node_or_null("KeySprite")
		
		# Apply simple pulsing effect via modulation instead of shader
		if key_sprite:
			var pulse = (sin(pulse_time * 0.4) * 0.5 + 0.5) * 0.2
			var base_color = Color(1.0, 1.0, 1.0)
			var highlight_color = Color(0.8, 0.9, 1.0)
			key_sprite.modulate = base_color.lerp(highlight_color, pulse)
		
		# Check if the player's key is pressed
		var key_name = bubble.get_meta("key_name")
		var key_pressed = false
		
		if key_name == "E":
			key_pressed = Input.is_action_pressed("ui_accept") or Input.is_key_pressed(KEY_E)
		elif key_name == "L":
			key_pressed = Input.is_key_pressed(KEY_L)
		
		# Update opacity based on key press
		if key_sprite:
			if key_pressed:
				key_sprite.modulate.a = 1.0  # Full opacity when pressed
			else:
				key_sprite.modulate.a = 0.9  # Default opacity
		
		# Store key press state
		bubble.set_meta("key_pressed", key_pressed)
		
		# Get current values
		var current_scale = bubble.get_meta("current_scale")
		var current_position = bubble.get_meta("current_position")
		
		# Animate scale
		if abs(current_scale - target_scale) > 0.01:
			current_scale = lerp(current_scale, target_scale, delta * 8.0)
			bubble.scale = Vector2(current_scale, current_scale)
			bubble.set_meta("current_scale", current_scale)
			bubble.set_meta("is_visible", current_scale > 0.01)
		elif target_scale < 0.01 and current_scale < 0.01:
			current_scale = 0.0
			bubble.scale = Vector2.ZERO
			bubble.set_meta("current_scale", current_scale)
			
		# Animate position
		if current_position.distance_to(target_position) > 0.1:
			current_position = current_position.lerp(target_position, delta * 6.0)
			bubble.position = bubble_offset + current_position
			bubble.set_meta("current_position", current_position)
			
		# Apply breathing effect when fully visible
		if current_scale > 0.95 and abs(current_position.y) < 1.0:
			var ripple_phase = pulse_time * 0.7
			var ripple_timing_raw = sin(ripple_phase * 0.5) * 0.5 + 0.5
			var t = ripple_timing_raw
			var ripple_timing = 4.0 * t * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 3.0) / 2.0
			
			# Almost imperceptible breathing effect
			var breathe_amount = 0.02 + ripple_timing * 0.03  # Extremely subtle
			
			if key_sprite:
				# Minimal effect on the key sprite
				key_sprite.scale = Vector2(0.3 + (breathe_amount * 0.1), 0.3 + (breathe_amount * 0.1))
	
	# Clean up removed players
	for player in to_remove:
		if player_bubbles.has(player):
			var bubble = player_bubbles[player]
			if is_instance_valid(bubble):
				bubble.queue_free()
			player_bubbles.erase(player)

# Called when the node is about to be destroyed
func _exit_tree() -> void:
	# Clean up all created bubbles
	for player in player_bubbles.keys():
		if is_instance_valid(player):
			var bubble = player_bubbles[player]
			if is_instance_valid(bubble):
				bubble.queue_free()

# Remove a player from tracking
func remove_tracked_player(player: Node2D) -> void:
	if player_bubbles.has(player):
		# Get and destroy the bubble
		var bubble = player_bubbles[player]
		if is_instance_valid(bubble):
			bubble.queue_free()
		
		# Remove from tracking dictionary
		player_bubbles.erase(player)
		
		if show_debug:
			print("Removed player from bubble tracking") 
