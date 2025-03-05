extends Node

var current_level := 0
var players_finished := 0
var pending_player_state := {}  # Store state between scene changes
var timer: Timer
var timer_label: Label

# Add inventory system
var inventory: Array[String] = []
const REQUIRED_ITEMS := 1  # Number of items needed for transport

# Add after the inventory declaration
var inventory_sprites := {}

# Signal for inventory updates
signal inventory_updated(current_count: int, required_count: int)
signal transport_ready

# Add this near the other inventory variables
var curry_inventory: Array[String] = []  # Store curry recipes learned

# Update the timer constants
const LEVEL1_TIME := 90  # 1.5 minutes in seconds
const LEVEL2_TIME := 180  # 3 minutes in seconds
const VIEWPORT_WIDTH := 1056  # Base viewport width
const VIEWPORT_HEIGHT := 594  # Base viewport height (16:9 aspect ratio)
const VIEWPORT_SCALE := 1.0   # Base scale for viewport
const PIXEL_SIZE := 32.0  # Size of pixel blocks

# Add these constants for timer visual effects
const TIMER_START_SCALE := Vector2(1.0, 1.0)
const TIMER_END_SCALE := Vector2(1.5, 1.5)  # 50% larger at the end
const TIMER_START_COLOR := Color(1.0, 1.0, 1.0)  # White
const TIMER_END_COLOR := Color(1.0, 0.0, 0.0)    # Red

# Add camera position configurations
const CAMERA_CONFIGS := {
	"Level 0": Vector2(640, 360),  # Center of 1280x720
	"Level 1": Vector2(640, 360),  # Adjust these values based on your needs
	"Level 2": Vector2(640, 360),
	"death": Vector2(640, 360)
}

var background_music: AudioStreamPlayer
var death_sound: AudioStreamPlayer
var countdown_music: AudioStreamPlayer
var celebration_music: AudioStreamPlayer

# Add this as a class variable at the top
var is_changing_level := false

# Add these constants for sky colors
const SKY_CONFIGS := {
	"Level 0": {
		"top_color": Color(0.4, 0.6, 1.0),
		"bottom_color": Color(0.8, 0.9, 1.0)
	},
	"Level 1": {
		"top_color": Color(0.2, 0.1, 0.3),
		"bottom_color": Color(0.8, 0.3, 0.2)
	},
	"Level 2": {
		"top_color": Color(0.15, 0.05, 0.25),
		"bottom_color": Color(0.7, 0.2, 0.1)
	},
	"death": {
		"top_color": Color(0.1, 0.1, 0.1),
		"bottom_color": Color(0.3, 0.3, 0.3)
	}
}

var sky_background: ColorRect

# Add near the top with other variables
var completed_levels: Array[int] = []  # Store which levels have been completed

# Add near the top with other signals
signal level_completed(level_num: int)

# Add near other inventory variables
const LEVEL_CONFIGS := {
	1: {
		"required_items": 1,
		"recipe_name": "basic_curry",
		"ingredients": ["corn", "onion", "peppers", "tomato"]
	},
	2: {
		"required_items": 4,
		"recipe_name": "naan",
		"ingredients": ["garlic", "water", "oil", "flour"]
	}
}

# Add these constants near other constants 
const SAVE_FILE_PATH = "user://save_data.json"
const AUTO_SAVE = true  # Set to false to disable autosaving

# Add these variables for the reset feature
var backspace_held := false
var backspace_held_time := 0.0
const RESET_TIME := 10.0  # Seconds required to hold backspace for reset
var reset_border: ColorRect

func _ready() -> void:
	# Load saved game data if it exists
	load_game()
	
	# Setup reset border
	setup_reset_border()
	
	# Add player count validation
	get_tree().node_added.connect(_on_node_added)
	
	# Connect to the tree_exiting signal to save when quitting
	get_tree().root.tree_exiting.connect(save_game)
	
	# Setup background music
	background_music = AudioStreamPlayer.new()
	add_child(background_music)
	var music = load("res://8bitAdventure.mp3")
	if music:
		background_music.stream = music
		background_music.volume_db = linear_to_db(0.1)  # Set volume to 30%
	
	# Setup countdown music
	countdown_music = AudioStreamPlayer.new()
	add_child(countdown_music)
	var countdown_audio = load("res://countdown.mp3")
	if countdown_audio:
		countdown_music.stream = countdown_audio
		countdown_music.volume_db = linear_to_db(0.05)  # Start at 5%
	
	# Setup celebration music
	celebration_music = AudioStreamPlayer.new()
	add_child(celebration_music)
	var celebration_audio = load("res://celebration.mp3")
	if celebration_audio:
		celebration_music.stream = celebration_audio
		celebration_music.volume_db = linear_to_db(0.3)  # Adjust volume as needed
	
	# Setup viewport scaling
	setup_viewport()
	
	# Add restart action if it doesn't exist
	if not InputMap.has_action("restart"):
		InputMap.add_action("restart")
		var event = InputEventKey.new()
		event.keycode = KEY_R
		InputMap.action_add_event("restart", event)
	
	# Setup death sound
	death_sound = AudioStreamPlayer.new()
	add_child(death_sound)
	var death_audio = load("res://death.mp3")
	if death_audio:
		death_sound.stream = death_audio
		death_sound.volume_db = linear_to_db(0.3)  # Adjust volume as needed
	
	# Start by loading screen sequence instead of level 0
	load_screen_sequence()
	
	# Start background music after delay
	if background_music and background_music.stream:
		var music_timer = get_tree().create_timer(5.0)
		music_timer.timeout.connect(func(): background_music.play())
	
	# Move sprite initialization to after level load
	print("Current level in _ready: ", current_level)  # Debug print

func setup_viewport() -> void:
	# Get the viewport
	var viewport = get_tree().root
	
	# Create a ColorRect for the background with shader
	sky_background = ColorRect.new()
	sky_background.name = "ViewportBackground"
	# Make it cover the entire window with proper anchors and margins
	sky_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky_background.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	sky_background.set_v_size_flags(Control.SIZE_EXPAND_FILL)
	# Put it behind everything
	sky_background.z_index = -1000
	sky_background.z_as_relative = false
	
	# Create and set the shader
	var shader_material = ShaderMaterial.new()
	var shader = load("res://sky_shader.gdshader")
	if shader == null:
		print("ERROR: Failed to load sky shader!")
		sky_background.color = Color(0.5, 0.7, 1.0)  # Fallback to light blue
	else:
		print("Successfully loaded sky shader")
		shader_material.shader = shader
		shader_material.set_shader_parameter("pixel_size", PIXEL_SIZE)
		sky_background.material = shader_material
	
	# Add to viewport's canvas layer to make it fixed to camera
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = -1  # Put it behind everything
	canvas_layer.add_child(sky_background)
	add_child(canvas_layer)
	
	# Enable viewport scaling
	viewport.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	viewport.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	
	# Set initial size
	viewport.set_content_scale_size(Vector2i(VIEWPORT_WIDTH, VIEWPORT_HEIGHT))
	
	# Connect to window size changes
	get_tree().root.size_changed.connect(_on_window_size_changed)
	
	# Initial update
	_on_window_size_changed()

func _on_window_size_changed() -> void:
	var window = get_tree().root
	var window_size = window.size
	
	# Calculate scale while maintaining aspect ratio
	var scale_x = window_size.x / VIEWPORT_WIDTH
	var scale_y = window_size.y / VIEWPORT_HEIGHT
	var scale = min(scale_x, scale_y)
	
	# Update viewport size
	var new_size = Vector2i(VIEWPORT_WIDTH, VIEWPORT_HEIGHT)
	window.set_content_scale_size(new_size)

func update_sky_colors(scene_name: String) -> void:
	if sky_background and sky_background.material:
		var colors = SKY_CONFIGS.get(scene_name, SKY_CONFIGS["Level 0"])
		sky_background.material.set_shader_parameter("top_color", colors.top_color)
		sky_background.material.set_shader_parameter("bottom_color", colors.bottom_color)

func load_level(level: int) -> void:
	current_level = level
	players_finished = 0
	
	print("Loading level: ", level)  # Debug print
	
	# Remove the automatic music start for level 0
	if level != 0:
		if background_music and background_music.playing:
			background_music.stop()
	
	# Load the appropriate level scene as a child of root
	var scene_name = ""
	if level == 0:
		scene_name = "curry_house_outside"
	elif level == -1:  # Special case for death scene
		scene_name = "death"
	else:
		scene_name = "level_" + str(level)
	
	# Update sky colors before loading the new scene
	update_sky_colors("Level " + str(level) if level >= 0 else "death")
	
	var level_scene = load("res://" + scene_name + ".tscn").instantiate()
	get_tree().root.call_deferred("add_child", level_scene)
	
	# Wait for scene to be ready
	await get_tree().process_frame
	
	# Apply camera configuration if it exists
	var camera = level_scene.get_node_or_null("Camera2D")
	if camera and CAMERA_CONFIGS.has(level_scene.name):
		camera.position = CAMERA_CONFIGS[level_scene.name]
		camera.reset_smoothing()  # Ensure camera snaps to position
	
	# Setup timer for level 1 or 2
	if level == 1 or level == 2:
		setup_timer(level)
	
	# Initialize inventory sprites after level is loaded
	if level == 1:
		print("Initializing inventory sprites for level 1")
		for veg in ["Corn", "Onion", "Peppers", "Tomato"]:
			var sprite = get_tree().root.get_node_or_null("Level 1/Camera2D/" + veg)
			print("Looking for sprite: ", veg, " - Found: ", sprite != null)  # Debug print
			if sprite:
				sprite.modulate.a = 0.1  # Set initial opacity to 10%
				inventory_sprites[veg.to_lower()] = sprite
				print("Set opacity for ", veg, " to 0.1")  # Debug print

func setup_timer(level: int) -> void:
	var level_node = get_tree().root.get_node_or_null("Level " + str(level))
	if not level_node:
		return
		
	timer = level_node.get_node_or_null("Camera2D/GameTimer")
	timer_label = level_node.get_node_or_null("Camera2D/TimerLabel")
	
	if timer and timer_label:
		# Set time based on level
		var time = LEVEL2_TIME if level == 2 else LEVEL1_TIME
		timer.wait_time = time
		timer.one_shot = true
		timer.timeout.connect(_on_timer_timeout)
		timer.start()
		update_timer_display(time)
		
		# Initialize inventory sprites for the level
		if LEVEL_CONFIGS.has(level):
			print("Initializing inventory sprites for level ", level)
			for ingredient in LEVEL_CONFIGS[level].ingredients:
				var sprite = get_tree().root.get_node_or_null("Level " + str(level) + "/Camera2D/" + ingredient.capitalize())
				print("Looking for sprite: ", ingredient, " - Found: ", sprite != null)
				if sprite:
					sprite.modulate.a = 0.1  # Set initial opacity to 10%
					inventory_sprites[ingredient.to_lower()] = sprite
					print("Set opacity for ", ingredient, " to 0.1")
		
		# Start countdown music
		if countdown_music:
			countdown_music.play()

func _process(delta: float) -> void:
	# Add player count validation in process
	var players := get_tree().get_nodes_in_group("players")
	if players.size() > 2:
		push_warning("Too many players detected in process! Removing excess players.")
		for i in range(2, players.size()):
			if is_instance_valid(players[i]):
				players[i].queue_free()
	
	# Check if any player has fallen too far
	for player in players:  # Use the same players array from above
		if player.global_position.y > 2000:  # Adjust this value based on your levels
			print("Player fell off the map!")
			if death_sound:
				death_sound.play()
			# Wait for sound to start
			await get_tree().create_timer(0.1).timeout
			change_level(current_level)
			break
	
	if (current_level == 1 or current_level == 2) and timer and timer_label:
		# Add validity checks
		if is_instance_valid(timer) and is_instance_valid(timer_label):
			update_timer_display(timer.time_left)
			
			# Update countdown music volume
			if countdown_music and countdown_music.playing:
				var time = LEVEL2_TIME if current_level == 2 else LEVEL1_TIME
				var progress = 1.0 - (timer.time_left / time)  # 0.0 to 1.0
				var volume = lerp(0.05, 0.2, progress)
				countdown_music.volume_db = linear_to_db(volume)

	# Handle backspace hold for reset
	if backspace_held:
		backspace_held_time += delta
		var progress = min(backspace_held_time / RESET_TIME, 1.0)
		
		# Update border width based on hold time
		reset_border.material.set_shader_parameter("border_width", progress)
		
		# Also update the opacity
		reset_border.color = Color(1.0, 0.0, 0.0, 0.5 * progress)
		
		# Check if held long enough
		if backspace_held_time >= RESET_TIME:
			reset_game()

func update_timer_display(time_left: float) -> void:
	var minutes: int = int(floor(time_left / 60))
	var seconds: int = int(time_left) % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]
	
	# Calculate progress (0.0 to 1.0, where 1.0 is start and 0.0 is end)
	var progress: float = time_left / LEVEL1_TIME
	
	# Interpolate scale
	var current_scale = TIMER_START_SCALE.lerp(TIMER_END_SCALE, 1.0 - progress)
	timer_label.scale = current_scale
	
	# Interpolate color
	var current_color = TIMER_START_COLOR.lerp(TIMER_END_COLOR, 1.0 - progress)
	timer_label.modulate = current_color

func _on_timer_timeout() -> void:
	if current_level == 1 or current_level == 2:
		print("Time's up!")
		# Stop countdown music
		if countdown_music:
			countdown_music.stop()
		# Play death sound
		death_sound.play()
		# Return to map instead of death scene
		await get_tree().create_timer(0.5).timeout  # Short delay for death sound
		load_map_navigation()

func player_finished() -> void:
	players_finished += 1
	if players_finished == 2:  # Both players have finished
		match current_level:
			0: switch_to_level_1()
			1: 
				print("Level 1 completed, adding basic curry")
				if not curry_inventory.has("basic_curry"):
					curry_inventory.append("basic_curry")
					print("Added basic_curry to inventory:", curry_inventory)
				change_to_dialogue("curry_house_inside")
			2:
				print("Level 2 completed, adding naan")
				if not curry_inventory.has("naan"):
					curry_inventory.append("naan")
					print("Added naan to inventory:", curry_inventory)
				change_to_dialogue("curry_house_inside")

func switch_to_level_1() -> void:
	change_level(1)

func switch_to_level_2() -> void:
	# Play celebration music
	if celebration_music:
		celebration_music.play()
	change_level(2)

func change_level(new_level: int) -> void:
	# Prevent multiple simultaneous level changes
	if is_changing_level:
		return
	is_changing_level = true
	
	# Clear inventory when changing levels
	clear_inventory()
	
	# Stop music when leaving level 0
	if current_level == 0 and background_music and background_music.playing:
		background_music.stop()
	
	if current_level == 1:
		if timer and is_instance_valid(timer):
			timer.stop()
		if countdown_music:
			countdown_music.stop()
		timer = null
		timer_label = null
	
	# Remove all existing players
	var players = get_tree().get_nodes_in_group("players")
	for player in players:
		if is_instance_valid(player):
			player.queue_free()
	
	# Remove current level - look for any node that might be the level
	for node in get_tree().root.get_children():
		# Skip ourselves (the game manager) and any built-in nodes
		if node != self and not node.name.begins_with("Auto"):
			if is_instance_valid(node):
				node.queue_free()
	
	# Wait a frame to ensure cleanup
	await get_tree().process_frame
	
	# Stop celebration music when leaving level 2
	if current_level == 2 and celebration_music and celebration_music.playing:
		celebration_music.stop()
	
	# Load new level
	load_level(new_level)
	is_changing_level = false

func save_players_state() -> Dictionary:
	var state = {}
	var players = get_tree().get_nodes_in_group("players")
	for player in players:
		state[player.name] = {
			"momentum": player.momentum,
			"is_active": player.is_active,
			"velocity": player.velocity,
			"jumps_remaining": player.jumps_remaining
		}
	return state

func restore_players_state(state: Dictionary) -> void:
	# Wait a frame to ensure scene is loaded
	await get_tree().process_frame
	
	var players = get_tree().get_nodes_in_group("players")
	for player in players:
		if state.has(player.name):
			var player_state = state[player.name]
			player.momentum = player_state.momentum
			player.is_active = true
			player.velocity = Vector2.ZERO  # Reset velocity for clean start
			player.jumps_remaining = player.MAX_JUMPS
			player.show()
			player.set_physics_process(true)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		# Prevent restart spam
		if is_changing_level:
			return
			
		print("Restart pressed on level: ", current_level)  # Debug print
		
		# If in level 1 or 2, return to map navigation instead of restarting
		if current_level == 1 or current_level == 2:
			load_map_navigation()
		else:
			change_level(current_level)

	# Add escape key to return to restaurant from map
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		# Check if we're on the map navigation screen
		var map_node = get_tree().root.get_node_or_null("Node2D")
		if map_node != null and map_node.get_node_or_null("Map") != null and !is_changing_level:
			print("Escape pressed on map, returning to restaurant")
			change_to_dialogue("curry_house_inside")
			
	# Add save functionality with Ctrl+S
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_S and event.is_command_or_control_pressed():
			save_game()
			# Optional: Show save notification to player
			print("Game manually saved")

	# Track backspace for reset
	if event is InputEventKey:
		if event.keycode == KEY_BACKSPACE:
			if event.pressed and !backspace_held:
				backspace_held = true
				backspace_held_time = 0.0
				reset_border.show()
				reset_border.material.set_shader_parameter("border_width", 0.0)
			elif !event.pressed and backspace_held:
				backspace_held = false
				reset_border.hide()

func load_death_scene() -> void:
	# Stop and clean up timer
	if timer:
		timer.stop()
		timer = null
		timer_label = null
	
	# Remove all existing players
	var players = get_tree().get_nodes_in_group("players")
	for player in players:
		player.queue_free()
	
	# Remove current level
	for node in get_tree().root.get_children():
		if node != self and not node.name.begins_with("Auto"):
			node.queue_free()
	
	# Load death scene
	var scene_path = "res://death.tscn"
	print("Attempting to load death scene from: ", scene_path)
	var scene = load(scene_path)
	if scene == null:
		print("ERROR: Could not load death scene!")
		return
		
	var death_scene = scene.instantiate()
	get_tree().root.add_child(death_scene)
	
	# Apply death scene camera configuration
	await get_tree().process_frame
	var camera = death_scene.get_node_or_null("Camera2D")
	if camera and CAMERA_CONFIGS.has("death"):
		camera.position = CAMERA_CONFIGS["death"]
		camera.reset_smoothing()

# Add this new function to validate player count
func _on_node_added(node: Node) -> void:
	if node.is_in_group("players"):
		var players = get_tree().get_nodes_in_group("players")
		if players.size() > 2:
			push_warning("Too many players detected! Removing excess player.")
			node.queue_free()

func load_screen_sequence() -> void:
	print("Attempting to load screen sequence...")
	
	# If we have saved data, skip intro and go to appropriate scene
	if current_level > 0 or completed_levels.size() > 1:
		print("Loading saved game state instead of intro")
		load_map_navigation()
		return
		
	var scene = load("res://screen_sequence.tscn")
	if scene == null:
		push_error("Failed to load screen_sequence.tscn! Make sure the file exists in the res:// directory")
		# Fallback to loading curry_house_outside
		load_level(0)
		return
		
	var screen_scene = scene.instantiate()
	if screen_scene == null:
		push_error("Failed to instantiate screen sequence scene!")
		load_level(0)
		return
		
	print("Successfully loaded screen sequence")
	get_tree().root.add_child(screen_scene)

func add_to_inventory(item_name: String) -> void:
	inventory.append(item_name)
	print("Added ", item_name, " to inventory. Current inventory: ", inventory)
	
	# Update corresponding sprite opacity if it exists
	if inventory_sprites.has(item_name):
		inventory_sprites[item_name].modulate.a = 1.0  # Set to full opacity
	
	# Get current level config
	var level_config = LEVEL_CONFIGS.get(current_level)
	if not level_config:
		return
		
	var required_items = level_config.required_items
	var required_ingredients = level_config.ingredients
	
	# Check if we have all required ingredients for this level
	var has_all_required = true
	for ingredient in required_ingredients:
		if not inventory.has(ingredient):
			has_all_required = false
			break
	
	# Emit signal with current counts
	inventory_updated.emit(inventory.size(), required_items)
	
	# Check if we have enough items
	if has_all_required:
		print("Transport ready! Collected all required items!")
		transport_ready.emit()
		# Mark level as completed when all items are collected
		if current_level in [1, 2]:
			complete_level(current_level)
			# Add the recipe to inventory
			var recipe = level_config.recipe_name
			if not curry_inventory.has(recipe):
				curry_inventory.append(recipe)
				print("Added " + recipe + " to curry inventory:", curry_inventory)
			# Transport back to curry house inside
			change_to_dialogue("curry_house_inside")

func clear_inventory() -> void:
	inventory.clear()
	# Reset all sprite opacities
	for sprite in inventory_sprites.values():
		if is_instance_valid(sprite):
			sprite.modulate.a = 0.1
	inventory_sprites.clear()
	inventory_updated.emit(0, REQUIRED_ITEMS)

func change_to_dialogue(dialogue_scene: String) -> void:
	# Prevent multiple simultaneous level changes
	if is_changing_level:
		return
	is_changing_level = true
	
	# Stop any playing music
	if background_music and background_music.playing:
		background_music.stop()
	if countdown_music and countdown_music.playing:
		countdown_music.stop()
	
	# Remove all existing players
	var players = get_tree().get_nodes_in_group("players")
	for player in players:
		if is_instance_valid(player):
			player.queue_free()
	
	# Remove current level
	for node in get_tree().root.get_children():
		if node != self and not node.name.begins_with("Auto"):
			if is_instance_valid(node):
				node.queue_free()
	
	# Wait a frame to ensure cleanup
	await get_tree().process_frame
	
	# Load dialogue scene
	var scene_path = "res://" + dialogue_scene + ".tscn"
	print("Loading dialogue scene from: ", scene_path)  # Debug print
	var scene = load(scene_path)
	if scene:
		var dialogue_instance = scene.instantiate()
		get_tree().root.add_child(dialogue_instance)
		print("Successfully loaded dialogue scene")  # Debug print
		
		# Update sky colors for dialogue
		update_sky_colors("Level 0")  # Use level 0 colors for dialogue
		
		# Wait for scene to be fully ready
		await get_tree().process_frame  
		await get_tree().process_frame  
		
		print("Checking curry inventory:", curry_inventory)
		
		# Handle both basic_curry and naan sprites
		for recipe in ["basic_curry", "naan"]:
			var recipe_sprite = get_tree().root.get_node_or_null(dialogue_scene + "/Camera2D/" + recipe)
			if recipe_sprite:
				recipe_sprite.modulate.a = 0.0  # Set initial opacity to 0%
				if curry_inventory.has(recipe):
					recipe_sprite.modulate.a = 1.0
					print("Set " + recipe + " opacity to 1.0")
				else:
					print(recipe + " not in inventory, opacity at 0.0")
			else:
				print("Could not find " + recipe + " sprite in Camera2D")
		
		is_changing_level = false
	else:
		print("Failed to load dialogue scene!")  # Debug print

# Add this new function to handle curry removal
func remove_curry_from_inventory(curry_type: String) -> void:
	if curry_inventory.has(curry_type):
		curry_inventory.erase(curry_type)
		
		# Find and update curry sprite opacity in all possible locations
		var root = get_tree().root
		# Try current scene's camera
		var curry_sprite = root.get_node_or_null("Level 1/Camera2D/" + curry_type)
		if curry_sprite:
			curry_sprite.modulate.a = 0.0
		
		# Try dialogue scene's camera
		curry_sprite = root.get_node_or_null("curry_house_inside/Camera2D/" + curry_type)
		if curry_sprite:
			curry_sprite.modulate.a = 0.0
		
		# Try map navigation's camera
		curry_sprite = root.get_node_or_null("map_navigation/Camera2D/" + curry_type)
		if curry_sprite:
			curry_sprite.modulate.a = 0.0
		
		print("Removed " + curry_type + " from inventory and updated sprites")

func load_map_navigation() -> void:
	# Prevent multiple simultaneous scene changes
	if is_changing_level:
		return
	is_changing_level = true
	
	# Clear inventory when returning to map
	clear_inventory()
	
	# Stop background music if playing
	if background_music and background_music.playing:
		background_music.stop()
	
	# Remove all existing players
	var players = get_tree().get_nodes_in_group("players")
	for player in players:
		if is_instance_valid(player):
			player.queue_free()
	
	# Remove current level
	for node in get_tree().root.get_children():
		if node != self and not node.name.begins_with("Auto"):
			if is_instance_valid(node):
				node.queue_free()
	
	# Wait a frame to ensure cleanup
	await get_tree().process_frame
	
	# Load map navigation scene
	var scene_path = "res://map_navigation.tscn"
	print("Loading map navigation from: ", scene_path)
	var scene = load(scene_path)
	if scene:
		var map_nav = scene.instantiate()
		get_tree().root.add_child(map_nav)
		print("Successfully loaded map navigation")
		
		# Update sky colors (using Level 0 colors for map navigation)
		update_sky_colors("Level 0")
	else:
		print("Failed to load map navigation scene!")
	
	is_changing_level = false

# Modify the complete_level function
func complete_level(level_num: int) -> void:
	if not completed_levels.has(level_num):
		completed_levels.append(level_num)
		print("Level ", level_num, " completed! Completed levels: ", completed_levels)
		level_completed.emit(level_num)  # Emit signal when level is completed
		
		# Save the game whenever a level is completed to ensure progress is persisted
		save_game()

# Add this new function
func is_level_completed(level_num: int) -> bool:
	return completed_levels.has(level_num)

func save_game() -> void:
	if not AUTO_SAVE:
		return
		
	var save_data = {
		"current_level": current_level,
		"completed_levels": completed_levels,
		"curry_inventory": curry_inventory,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		print("Game saved successfully")
	else:
		push_error("Could not save game: " + str(FileAccess.get_open_error()))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		print("No save file found, starting new game")
		# Make sure level 0 is accessible for new games
		completed_levels.append(0)  # Level 0 (curry house) starts as accessible
		return
		
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if not file:
		push_error("Could not load save file: " + str(FileAccess.get_open_error()))
		return
		
	var json_string = file.get_as_text()
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("Error parsing save data: " + json.get_error_message())
		return
		
	var save_data = json.data
	
	# Load game state
	if save_data.has("current_level"):
		current_level = save_data.current_level
	
	if save_data.has("completed_levels"):
		# Convert generic Array to Array[int]
		completed_levels.clear()
		for level in save_data.completed_levels:
			completed_levels.append(int(level))
	
	if save_data.has("curry_inventory"):
		# Convert generic Array to Array[String]
		curry_inventory.clear()
		for item in save_data.curry_inventory:
			curry_inventory.append(String(item))
		
	print("Game loaded successfully. Current level: ", current_level)

func setup_reset_border() -> void:
	# Create reset border
	reset_border = ColorRect.new()
	reset_border.name = "ResetBorder"
	
	# Make it cover the entire screen
	reset_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Set initial color (red with alpha 0)
	reset_border.color = Color(1.0, 0.0, 0.0, 0.0)
	
	# Create a hole in the middle using a shader
	var shader_material = ShaderMaterial.new()
	var shader_code = """
	shader_type canvas_item;
	
	uniform float border_width : hint_range(0.0, 1.0) = 0.1;
	
	void fragment() {
		vec2 center = vec2(0.5, 0.5);
		float dist = distance(UV, center) * 2.0;
		
		// Create hollow effect
		float alpha = smoothstep(1.0 - border_width - 0.01, 1.0 - border_width, dist);
		COLOR.a *= alpha;
	}
	"""
	
	var shader = Shader.new()
	shader.code = shader_code
	shader_material.shader = shader
	reset_border.material = shader_material
	
	# Add to a canvas layer to ensure it's always on top
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100  # Very high layer to be on top of everything
	canvas_layer.add_child(reset_border)
	add_child(canvas_layer)
	
	# Hide initially
	reset_border.hide()

func reset_game() -> void:
	print("Resetting game...")
	
	# Delete save file
	if FileAccess.file_exists(SAVE_FILE_PATH):
		var dir = DirAccess.open("user://")
		if dir:
			dir.remove(SAVE_FILE_PATH)
			print("Save file deleted")
	
	# Reset game state
	current_level = 0
	completed_levels.clear()
	completed_levels.append(0)  # Reset to only having level 0 accessible
	curry_inventory.clear()
	inventory.clear()
	inventory_sprites.clear()
	
	# Reset visual elements
	backspace_held = false
	reset_border.hide()
	
	# Stop any playing music
	if background_music and background_music.playing:
		background_music.stop()
	if countdown_music and countdown_music.playing:
		countdown_music.stop()
	if celebration_music and celebration_music.playing:
		celebration_music.stop()
	
	# Make sure we're not already changing level
	is_changing_level = true
	
	# Remove all existing players
	var players = get_tree().get_nodes_in_group("players")
	for player in players:
		if is_instance_valid(player):
			player.queue_free()
	
	# Thoroughly remove all scene nodes (except game manager)
	for node in get_tree().root.get_children():
		if node != self and not node.name.begins_with("Auto"):
			if is_instance_valid(node):
				node.queue_free()
	
	# Wait for screen to fully clear
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Load screen sequence to restart game
	print("Restarting game from beginning...")
	is_changing_level = false  # Ensure we can change level
	load_screen_sequence()
