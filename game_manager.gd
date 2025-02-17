extends Node

var current_level := 0
var players_finished := 0
var pending_player_state := {}  # Store state between scene changes
var timer: Timer
var timer_label: Label

# Add inventory system
var inventory: Array[String] = []
const REQUIRED_ITEMS := 3  # Number of items needed for transport

# Signal for inventory updates
signal inventory_updated(current_count: int, required_count: int)
signal transport_ready

const LEVEL1_TIME := 90  # 2 minutes in seconds
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

func _ready() -> void:
	# Add player count validation
	get_tree().node_added.connect(_on_node_added)
	
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
	
	# Remove the automatic music start for level 0
	if level != 0:
		if background_music and background_music.playing:
			background_music.stop()
	
	# Load the appropriate level scene as a child of root
	var scene_name = "level_" + str(level)
	if level == -1:  # Special case for death scene
		scene_name = "death"
	
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
	
	# Setup timer for level 1
	if level == 1:
		setup_timer()

func setup_timer() -> void:
	timer = get_tree().root.get_node("Level 1/Camera2D/GameTimer")
	timer_label = get_tree().root.get_node("Level 1/Camera2D/TimerLabel")
	
	if timer and timer_label:
		timer.wait_time = LEVEL1_TIME
		timer.one_shot = true
		timer.timeout.connect(_on_timer_timeout)
		timer.start()
		update_timer_display(LEVEL1_TIME)
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
	
	if current_level == 1 and timer and timer_label:
		# Add validity checks
		if is_instance_valid(timer) and is_instance_valid(timer_label):
			update_timer_display(timer.time_left)
			
			# Update countdown music volume
			if countdown_music and countdown_music.playing:
				var progress = 1.0 - (timer.time_left / LEVEL1_TIME)  # 0.0 to 1.0
				var volume = lerp(0.05, 0.2, progress)
				countdown_music.volume_db = linear_to_db(volume)

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
	if current_level == 1:
		print("Time's up!")
		# Stop countdown music
		if countdown_music:
			countdown_music.stop()
		# Play death sound
		death_sound.play()
		# Load death scene instead of resetting level
		load_death_scene()

func player_finished() -> void:
	players_finished += 1
	if players_finished == 2:  # Both players have finished
		match current_level:
			0: switch_to_level_1()
			1: switch_to_level_2()
			2: print("Game Complete!")

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
		
		# If in death scene or level 2, return to level 0
		var current_scene = get_tree().root.get_children().back()
		if current_scene.name == "death" or current_level == 2:
			change_level(0)
		else:
			change_level(current_level)

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
	var scene = load("res://screen_sequence.tscn")
	if scene == null:
		push_error("Failed to load screen_sequence.tscn! Make sure the file exists in the res:// directory")
		# Fallback to loading level 0
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
	
	# Emit signal with current counts
	inventory_updated.emit(inventory.size(), REQUIRED_ITEMS)
	
	# Check if we have enough items
	if inventory.size() >= REQUIRED_ITEMS:
		print("Transport ready! Collected all required items!")
		transport_ready.emit()

func clear_inventory() -> void:
	inventory.clear()
	inventory_updated.emit(0, REQUIRED_ITEMS)
