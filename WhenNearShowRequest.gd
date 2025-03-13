extends Node2D

# Configuration
@export var detection_radius: float = 150.0  # How close player needs to be to show request
@export var requested_item_texture: Texture2D  # The item being requested
@export var default_texture_path: String = "res://basic_curry.png"  # Default item if none provided
@export var bubble_offset: Vector2 = Vector2(0, -38)  # Moved up by 4px from previous -34
@export var bubble_size: Vector2 = Vector2(48, 48)  # Size of the request bubble
@export var show_debug: bool = false  # Show debug info

# Node references
var bubble_sprite: Sprite2D
var item_sprite: Sprite2D
var particles: Node2D
var is_visible: bool = false
var current_scale: float = 0.0
var target_scale: float = 0.0
var current_position: Vector2 = Vector2(0, 0)
var target_position: Vector2 = Vector2(0, 0)
var animation_offset: float = 20.0  # How far the bubble rises from its starting point

# Pulse effect variables - adjusted for deeper, slower ripples
var pulse_time: float = 0.0
var pulse_speed: float = 2.5  # Slowed down from 4.0 for slower ripple
var pulse_amount: float = 0.1  # How much to pulse (10% size change)

# Particle effect variables
var particles_active: bool = false
var particle_list = []
const MAX_PARTICLES = 10
const PARTICLE_LIFETIME = 1.0  # seconds
const PARTICLE_SPEED = 20.0

# Called when the node enters the scene tree
func _ready() -> void:
	# Set initial position offset from the final position (below the bubble)
	current_position = Vector2(0, animation_offset)
	target_position = Vector2(0, 0)  # Target is at the offset position
	position = bubble_offset + current_position
	
	# Create particles node (behind the bubble)
	particles = Node2D.new()
	particles.name = "Particles"
	particles.z_index = -1  # Behind everything
	add_child(particles)
	
	# Create bubble background sprite
	bubble_sprite = Sprite2D.new()
	bubble_sprite.name = "BubbleSprite"
	var bubble_texture = _create_default_bubble()
	bubble_sprite.texture = bubble_texture
	bubble_sprite.scale = Vector2(1, 1)
	# Set nearest neighbor filtering for pixelated look
	bubble_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(bubble_sprite)
	
	# Create and apply the pulsing yellow shader to the bubble
	var shader_material = ShaderMaterial.new()
	shader_material.shader = _create_pulse_shader()
	bubble_sprite.material = shader_material
	
	# Create item sprite (the requested item)
	item_sprite = Sprite2D.new()
	item_sprite.name = "ItemSprite"
	
	# Load requested item texture or use default
	if requested_item_texture:
		item_sprite.texture = requested_item_texture
	else:
		var default_texture = load(default_texture_path)
		if default_texture:
			item_sprite.texture = default_texture
		else:
			push_error("Failed to load default item texture: " + default_texture_path)
	
	# Position the item sprite in the center of the bubble
	item_sprite.position = Vector2(0, 0)
	item_sprite.scale = Vector2(1, 1)
	# Set nearest neighbor filtering for pixelated look
	item_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(item_sprite)
	
	# Set nearest filter mode for the parent node as well to affect all children
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	# Initially hide the bubble
	scale = Vector2.ZERO
	current_scale = 0.0
	is_visible = false
	show()  # Actually show the node but with zero scale
	
	# Set z-index to be above NPC
	z_index = 10

# Create a default bubble texture if none is provided
func _create_default_bubble() -> Texture2D:
	# Use smaller dimensions for the image
	var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	
	# Fill with white background
	for x in range(32):
		for y in range(32):
			# Draw a smaller white circle with soft edges
			var center_x = 16
			var center_y = 16
			var radius = 14  # Much smaller radius
			var dist = sqrt(pow(x - center_x, 2) + pow(y - center_y, 2))
			
			if dist <= radius:
				# Full opacity in the center, fading out at the edges
				var alpha = 1.0 - (dist / radius) * 0.5
				image.set_pixel(x, y, Color(1, 1, 1, alpha))
			else:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
	
	# Create the texture from the image
	var texture = ImageTexture.create_from_image(image)
	return texture

# Create a shader that creates pixel ripples from center to edge
func _create_pulse_shader() -> Shader:
	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	
	uniform float pulse_phase;
	
	// Return a fire color based on intensity (0.0 to 1.0)
	vec3 fire_gradient(float intensity) {
		// Yellow to orange to red gradient
		vec3 yellow = vec3(1.0, 0.9, 0.2);
		vec3 orange = vec3(1.0, 0.5, 0.0);
		vec3 red = vec3(0.9, 0.1, 0.1);
		
		if (intensity > 0.7) {
			// Yellow to orange
			return mix(yellow, orange, (intensity - 0.7) / 0.3);
		} else if (intensity > 0.3) {
			// Orange to red
			return mix(orange, red, (intensity - 0.3) / 0.4);
		} else {
			// Red with lower intensity
			return red * (intensity / 0.3);
		}
	}
	
	// Ease in-out cubic function for smoother transitions
	float ease_in_out(float t) {
		return t < 0.5 ? 4.0 * t * t * t : 1.0 - pow(-2.0 * t + 2.0, 3.0) / 2.0;
	}
	
	void fragment() {
		// Force pixelated sampling of texture (emulates TEXTURE_FILTER_NEAREST)
		float pixel_size = 0.05; // Larger value = more pixelated
		vec2 pixelated_uv = floor(UV / pixel_size) * pixel_size;
		vec4 original_color = texture(TEXTURE, pixelated_uv);
		
		// Calculate distance from center (0.0 to 1.0)
		vec2 centered_uv = UV - 0.5;
		float distance_from_center = length(centered_uv) * 2.0; // Scale to full 0-1 range
		
		// Create ripples from center at slower speed
		float ripple_speed = 0.8;  // Slower
		float ripple_frequency = 0.5; // Slower frequency
		
		// Calculate ripples moving outward - adjusted to reach edge
		float ripple_phase = pulse_phase * ripple_speed;
		
		// Floor the distance for more pixelated rings
		float pixelated_distance = floor(distance_from_center * 10.0) / 10.0;
		float ripple = sin(pixelated_distance * 10.0 - ripple_phase);
		
		// Create sharp-edged ripples with step function
		float ripple_edge = step(0.2, ripple);
		
		// Create ripple timing with ease in-out for smoother transitions
		float ripple_timing_raw = sin(ripple_phase * ripple_frequency) * 0.5 + 0.5;
		float ripple_timing = ease_in_out(ripple_timing_raw);
		
		// Calculate the final ripple effect with pixelated steps
		float ripple_mask = ripple_edge * ripple_timing;
		ripple_mask = floor(ripple_mask * 5.0) / 5.0; // Increased steps for more visible pixels
		
		// Get color based on distance from center
		// Floor the distance for more pixelated color bands
		float color_distance = floor(distance_from_center * 8.0) / 8.0;
		vec3 fire_color = fire_gradient(1.0 - color_distance);
		
		// Apply color where the ripple is active
		vec3 final_color = mix(original_color.rgb, fire_color, ripple_mask);
		
		// Output with original alpha but quantized for pixelated look
		COLOR = vec4(floor(final_color * 8.0) / 8.0, original_color.a);
	}
	"""
	return shader

# Handle custom animation in process
func _process(delta: float) -> void:
	# First check player distance
	var players = get_tree().get_nodes_in_group("players")
	var closest_distance = INF
	
	for player in players:
		if player.is_active:  # Only consider active players
			var distance = global_position.distance_to(player.global_position)
			closest_distance = min(closest_distance, distance)
	
	# Set target scale and position based on distance
	if closest_distance <= detection_radius:
		target_scale = 1.0  # Show bubble
		target_position = Vector2(0, 0)  # Final position
		
		# Update pulse when visible
		pulse_time += delta * pulse_speed
		
		# Apply pulse phase to shader
		if is_visible and bubble_sprite.material:
			bubble_sprite.material.set_shader_parameter("pulse_phase", pulse_time)
			
		# Apply breathing that syncs with ripples when fully visible
		if current_scale > 0.95 and abs(current_position.y) < 1.0:
			# Calculate ripple timing that matches shader, with easing
			var ripple_phase = pulse_time * 0.8  # Match slower shader speed
			var ripple_timing_raw = sin(ripple_phase * 0.5) * 0.5 + 0.5
			
			# Apply cubic easing function for smoother transitions - using GDScript ternary format
			var t = ripple_timing_raw
			var ripple_timing = 4.0 * t * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 3.0) / 2.0
			
			# Deeper breathing effect - 20% to 40% scale change
			var breathe_amount = 0.2 + ripple_timing * 0.2
			bubble_sprite.scale = Vector2(1.0 + breathe_amount, 1.0 + breathe_amount)
			
			# Scale item sprite slightly to maintain proportions but at a reduced rate
			item_sprite.scale = Vector2(1.0 + (breathe_amount * 0.3), 1.0 + (breathe_amount * 0.3))
	else:
		target_scale = 0.0  # Hide bubble
		target_position = Vector2(0, animation_offset)  # Move back down when hiding
		
		# Reset bubble scale when hiding
		bubble_sprite.scale = Vector2(1.0, 1.0)
		item_sprite.scale = Vector2(1.0, 1.0)
	
	# Animate scale smoothly
	if abs(current_scale - target_scale) > 0.01:
		# Interpolate toward target scale
		current_scale = lerp(current_scale, target_scale, delta * 8.0)  # Slightly slower than before
		scale = Vector2(current_scale, current_scale)
		
		# Update visibility state
		is_visible = current_scale > 0.01
	elif target_scale < 0.01 and current_scale < 0.01:
		# Ensure exact zero when fully hidden
		current_scale = 0.0
		scale = Vector2.ZERO
	
	# Animate position smoothly
	if current_position.distance_to(target_position) > 0.1:
		# Interpolate toward target position
		current_position = current_position.lerp(target_position, delta * 6.0)
		position = bubble_offset + current_position

# Spawn a new particle
func _spawn_particle() -> void:
	var particle = {
		"position": Vector2.ZERO,
		"velocity": Vector2.from_angle(randf() * 2.0 * PI) * PARTICLE_SPEED * (0.5 + randf() * 0.5),
		"life": PARTICLE_LIFETIME,
		"size": 2.0 + randf() * 2.0,
		"offset": Vector2(randf() * 10.0 - 5.0, randf() * 10.0 - 5.0)  # Random initial offset
	}
	
	particle_list.append(particle)

# Update all particles
func _update_particles(delta: float) -> void:
	# Process existing particles
	var i = 0
	while i < particle_list.size():
		var p = particle_list[i]
		p.life -= delta
		
		if p.life <= 0:
			# Remove dead particles
			particle_list.remove_at(i)
		else:
			# Update particle position
			p.position += p.velocity * delta
			i += 1
	
	# Force redraw
	queue_redraw()

# Custom draw for particles - this happens at the Node2D level now
func _draw() -> void:
	if not particles_active or not is_visible:
		return
		
	# Draw each particle as a yellow square that fades out
	for p in particle_list:
		var alpha = p.life / PARTICLE_LIFETIME
		var color = Color(1.0, 0.9, 0.2, alpha * 0.7)  # Yellow glow with less opacity
		var size = p.size * alpha  # Particles get smaller as they fade
		
		# Draw from the bubble's center with offset
		draw_rect(Rect2(p.position.x - size/2 + p.offset.x, 
					   p.position.y - size/2 + p.offset.y, 
					   size, size), 
				  color)

# Set a new requested item texture
func set_requested_item(texture: Texture2D) -> void:
	requested_item_texture = texture
	
	if item_sprite:
		item_sprite.texture = texture
